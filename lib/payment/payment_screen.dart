import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:webview_flutter/webview_flutter.dart';

import '../accommodation/accommodation_screen.dart';
import '../event_management/event_management.dart';

part 'payment_models.dart';
part 'payment_views.dart';

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  String _activeTab = 'payment';
  String _paymentStep = 'selection';
  BookingItem? _selectedBooking;
  String? _paymentApprovalUrl;
  String? _paymentOrderId;
  String? _activePaymentRecordId;
  String? _activePaymentSource;
  bool _isCreatingPayment = false;

  final String _paypalBaseUrl =
      'https://us-central1-fyp-project-7199d.cloudfunctions.net';
  final String _paypalReturnUrl =
      'https://us-central1-fyp-project-7199d.cloudfunctions.net/paypalSuccess';
  final String _paypalCancelUrl =
      'https://us-central1-fyp-project-7199d.cloudfunctions.net/paypalCancel';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late final CollectionReference<Map<String, dynamic>> _eventPaymentsRef =
      _firestore.collection('eventpayment');
  late final CollectionReference<Map<String, dynamic>>
  _accommodationPaymentsRef = _firestore.collection('AccommodationPayments');
  static const List<String> _pendingStatuses = [
    'FAILED',
    'CREATED',
    'RETRYING',
    'CANCELLED',
  ];

  double _totalSpentFor(List<TransactionItem> history) =>
      history.fold(0, (sum, item) => sum + item.amount);

  Stream<List<BookingItem>> _pendingEventPaymentsStream() {
    final userId = _auth.currentUser?.uid ?? 'traveler';
    return _eventPaymentsRef
        .where('UserId', isEqualTo: userId)
        .where('Status', whereIn: _pendingStatuses)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map(
                (doc) => BookingItem.fromEventPayment(doc.data(), id: doc.id),
              )
              .toList();
        });
  }

  Stream<List<BookingItem>> _pendingAccommodationPaymentsStream() {
    final userId = _auth.currentUser?.uid ?? 'guest';
    return _accommodationPaymentsRef
        .where('UserId', isEqualTo: userId)
        .where('Status', whereIn: _pendingStatuses)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map(
                (doc) => BookingItem.fromAccommodationPayment(
                  doc.data(),
                  id: doc.id,
                ),
              )
              .toList();
        });
  }

  Stream<List<TransactionItem>> _eventHistoryStream() {
    final userId = _auth.currentUser?.uid ?? 'traveler';
    return _eventPaymentsRef
        .where('UserId', isEqualTo: userId)
        .where('Status', isEqualTo: 'CAPTURED')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map(
                (doc) =>
                    TransactionItem.fromEventPayment(doc.data(), id: doc.id),
              )
              .toList();
        });
  }

  Stream<List<TransactionItem>> _accommodationHistoryStream() {
    final userId = _auth.currentUser?.uid ?? 'guest';
    return _accommodationPaymentsRef
        .where('UserId', isEqualTo: userId)
        .where('Status', isEqualTo: 'CAPTURED')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map(
                (doc) => TransactionItem.fromAccommodationPayment(
                  doc.data(),
                  id: doc.id,
                ),
              )
              .toList();
        });
  }

  Future<void> _handleContinueCheckout(BookingItem booking) async {
    if (booking.canRetry) {
      await _startRetryCheckout(booking);
      return;
    }
    final retryPaymentId = booking.canRetry ? booking.id : null;
    if (booking.source == 'event') {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => EventManagementScreen(retryPaymentId: retryPaymentId),
        ),
      );
      return;
    }
    if (booking.source == 'accommodation') {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => AccommodationScreen(retryPaymentId: retryPaymentId),
        ),
      );
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Unable to open checkout module.')),
    );
  }

  double _asDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  Future<void> _startRetryCheckout(BookingItem booking) async {
    if (_isCreatingPayment) {
      return;
    }
    setState(() {
      _selectedBooking = booking;
      _paymentStep = 'processing';
      _isCreatingPayment = true;
    });
    final ref =
        booking.source == 'event'
            ? _eventPaymentsRef.doc(booking.id)
            : _accommodationPaymentsRef.doc(booking.id);
    try {
      final doc = await ref.get();
      if (!doc.exists) {
        throw Exception('Payment record missing');
      }
      final data = doc.data() ?? {};
      final amount = _asDouble(data['Amount']);
      final currency = (data['Currency'] ?? 'MYR').toString();
      final eventId =
          (data['EventId'] ?? data['AccommodationId'] ?? '').toString();
      if (eventId.trim().isEmpty) {
        throw Exception('Missing reference ID');
      }
      await ref.set({
        'PaymentId': booking.id,
        'Status': 'RETRYING',
        'UpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      final response = await http.post(
        Uri.parse('$_paypalBaseUrl/createPayPalOrder'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'amount': amount.toStringAsFixed(2),
          'currency': currency,
          'return_url': _paypalReturnUrl,
          'cancel_url': _paypalCancelUrl,
          'event_id': eventId,
        }),
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('Order create failed');
      }
      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      final approvalUrl = payload['approvalUrl']?.toString();
      final orderId = payload['orderId']?.toString();
      if (approvalUrl == null || orderId == null) {
        throw Exception('Missing approval data');
      }
      await ref.set({
        'PaymentId': booking.id,
        'PayPalOrderId': orderId,
        'Status': 'CREATED',
        'UpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (!mounted) return;
      setState(() {
        _paymentApprovalUrl = approvalUrl;
        _paymentOrderId = orderId;
        _activePaymentRecordId = booking.id;
        _activePaymentSource = booking.source;
        _paymentStep = 'paypal';
        _isCreatingPayment = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _paymentStep = 'selection';
        _isCreatingPayment = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to start PayPal checkout.')),
      );
    }
  }

  Future<void> _capturePayPalOrder() async {
    if (_paymentOrderId == null || _activePaymentRecordId == null) {
      return;
    }
    setState(() => _paymentStep = 'processing');
    final recordId = _activePaymentRecordId!;
    final ref =
        _activePaymentSource == 'event'
            ? _eventPaymentsRef.doc(recordId)
            : _accommodationPaymentsRef.doc(recordId);
    try {
      final response = await http.post(
        Uri.parse('$_paypalBaseUrl/capturePayPalOrder'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'orderId': _paymentOrderId}),
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('Capture failed');
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final payerEmail = data['data']?['payer']?['email_address']?.toString();
      await ref.set({
        'PaymentId': recordId,
        'PayPalOrderId': _paymentOrderId,
        'Status': 'CAPTURED',
        'CapturedAt': FieldValue.serverTimestamp(),
        'PayerEmail': payerEmail,
      }, SetOptions(merge: true));
      if (!mounted) return;
      setState(() {
        _paymentStep = 'success';
        _paymentApprovalUrl = null;
        _paymentOrderId = null;
        _activePaymentRecordId = null;
        _activePaymentSource = null;
      });
    } catch (_) {
      await ref.set({
        'PaymentId': recordId,
        'PayPalOrderId': _paymentOrderId,
        'Status': 'FAILED',
        'UpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (!mounted) return;
      setState(() {
        _paymentStep = 'selection';
        _paymentApprovalUrl = null;
        _paymentOrderId = null;
        _activePaymentRecordId = null;
        _activePaymentSource = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Payment not completed. Please try again.'),
        ),
      );
    }
  }

  Future<void> _cancelPayPalCheckout() async {
    final recordId = _activePaymentRecordId;
    if (recordId != null) {
      final ref =
          _activePaymentSource == 'event'
              ? _eventPaymentsRef.doc(recordId)
              : _accommodationPaymentsRef.doc(recordId);
      await ref.set({
        'PaymentId': recordId,
        'PayPalOrderId': _paymentOrderId,
        'Status': 'CANCELLED',
        'UpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
    if (!mounted) return;
    setState(() {
      _paymentStep = 'selection';
      _paymentApprovalUrl = null;
      _paymentOrderId = null;
      _activePaymentRecordId = null;
      _activePaymentSource = null;
    });
  }

  void _closeSuccess() {
    setState(() {
      _paymentStep = 'selection';
      _selectedBooking = null;
      _activeTab = 'history';
    });
  }

  Future<void> _showReceiptDialog({TransactionItem? historyItem}) {
    final booking = _selectedBooking;
    final item = historyItem;

    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return Dialog(
          insetPadding: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Receipt Details',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF2FF),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: const Icon(
                    Icons.credit_card_rounded,
                    size: 36,
                    color: Color(0xFF2563EB),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'WanderEase',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Travel Payment Receipt',
                  style: TextStyle(
                    fontSize: 11,
                    color: Color(0xFF93C5FD),
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.4,
                  ),
                ),
                const SizedBox(height: 20),
                _ReceiptRow(label: 'Recipient:', value: 'Tan Lai Heng'),
                _ReceiptRow(
                  label: 'Service:',
                  value: item?.name ?? booking?.name ?? '-',
                ),
                _ReceiptRow(
                  label: 'Payment ID:',
                  value: item?.id ?? booking?.id ?? '-',
                  isMono: true,
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'FINAL AMOUNT PAID',
                        style: TextStyle(
                          fontSize: 10,
                          letterSpacing: 2.0,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFFDBEAFE),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'RM ${(item?.amount ?? booking?.amount ?? 0).toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F172A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    icon: const Icon(Icons.download_rounded),
                    label: const Text(
                      'Download PDF',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEFF6FF),
      body: SafeArea(
        child: Column(
          children: [
            _Header(
              canGoBack: _paymentStep == 'selection',
              onBack: () => Navigator.of(context).maybePop(),
            ),
            if (_paymentStep == 'selection')
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: _TabBar(
                  activeTab: _activeTab,
                  onTabChanged: (tab) => setState(() => _activeTab = tab),
                ),
              ),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: _buildBody(),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: null,
    );
  }

  Widget _buildBody() {
    if (_paymentStep == 'processing') {
      return _ProcessingView();
    }
    if (_paymentStep == 'paypal') {
      final approvalUrl = _paymentApprovalUrl;
      if (approvalUrl == null) {
        return const Center(child: CircularProgressIndicator());
      }
      return _PayPalCheckoutView(
        approvalUrl: approvalUrl,
        returnUrl: _paypalReturnUrl,
        cancelUrl: _paypalCancelUrl,
        onApproved: _capturePayPalOrder,
        onCancelled: _cancelPayPalCheckout,
      );
    }
    if (_paymentStep == 'success') {
      return _SuccessView(
        booking: _selectedBooking,
        onReceipt: () => _showReceiptDialog(),
        onContinue: _closeSuccess,
      );
    }

    return _activeTab == 'payment' ? _buildPaymentTab() : _buildHistoryTab();
  }

  Widget _buildPaymentTab() {
    return StreamBuilder<List<BookingItem>>(
      stream: _pendingEventPaymentsStream(),
      builder: (context, eventSnapshot) {
        return StreamBuilder<List<BookingItem>>(
          stream: _pendingAccommodationPaymentsStream(),
          builder: (context, accommodationSnapshot) {
            final isLoading =
                (eventSnapshot.connectionState == ConnectionState.waiting ||
                    accommodationSnapshot.connectionState ==
                        ConnectionState.waiting) &&
                eventSnapshot.data == null &&
                accommodationSnapshot.data == null;
            if (isLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            final bookings = <BookingItem>[
              ...?eventSnapshot.data,
              ...?accommodationSnapshot.data,
            ];
            bookings.sort((a, b) {
              final aTime =
                  a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
              final bTime =
                  b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
              return bTime.compareTo(aTime);
            });
            final notice =
                (eventSnapshot.hasError || accommodationSnapshot.hasError)
                    ? 'Unable to load checkouts. Please try again.'
                    : (eventSnapshot.data == null ||
                        accommodationSnapshot.data == null)
                    ? 'Fetching checkouts from server...'
                    : null;
            return _PaymentSelectionView(
              bookings: bookings,
              onPayNow: _handleContinueCheckout,
              notice: notice,
            );
          },
        );
      },
    );
  }

  Widget _buildHistoryTab() {
    return StreamBuilder<List<TransactionItem>>(
      stream: _eventHistoryStream(),
      builder: (context, eventSnapshot) {
        return StreamBuilder<List<TransactionItem>>(
          stream: _accommodationHistoryStream(),
          builder: (context, accommodationSnapshot) {
            final isLoading =
                (eventSnapshot.connectionState == ConnectionState.waiting ||
                    accommodationSnapshot.connectionState ==
                        ConnectionState.waiting) &&
                eventSnapshot.data == null &&
                accommodationSnapshot.data == null;
            if (isLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            final history = <TransactionItem>[
              ...?eventSnapshot.data,
              ...?accommodationSnapshot.data,
            ];
            history.sort((a, b) {
              final aTime =
                  a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
              final bTime =
                  b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
              return bTime.compareTo(aTime);
            });
            final notice =
                (eventSnapshot.hasError || accommodationSnapshot.hasError)
                    ? 'Unable to load history. Please try again.'
                    : (eventSnapshot.data == null ||
                        accommodationSnapshot.data == null)
                    ? 'Fetching history from server...'
                    : null;
            return _HistoryView(
              history: history,
              totalSpent: _totalSpentFor(history),
              onViewReceipt: (item) => _showReceiptDialog(historyItem: item),
              notice: notice,
            );
          },
        );
      },
    );
  }
}
