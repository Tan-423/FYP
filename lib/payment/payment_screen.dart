import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:webview_flutter/webview_flutter.dart';

part 'payment_models.dart';
part 'payment_views.dart';

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  static const String _emailJsServiceId = 'service_duet1ff';
  static const String _emailJsTemplateId = 'template_ifgo794';
  static const String _emailJsPublicKey = 'IUJGANEaedb8T2n1N';
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
      _firestore.collection('EventPayment');
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
    await _startRetryCheckout(booking);
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
      final booking = _selectedBooking;
      if (booking != null) {
        try {
          await _sendReceiptEmail(
            booking: booking,
            paymentId: recordId,
            amount: booking.amount,
            currency: booking.currency,
            payerEmail: payerEmail,
          );
        } catch (_) {
          // Ignore email failures to avoid blocking checkout.
        }
      }
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

  String _currentUserName() {
    final user = _auth.currentUser;
    final display = user?.displayName?.trim();
    if (display != null && display.isNotEmpty) {
      return display;
    }
    final email = user?.email?.trim();
    if (email != null && email.isNotEmpty) {
      return email.split('@').first;
    }
    return 'Traveler';
  }

  String _escapeHtml(String value) {
    return value
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
  }

  Future<void> _sendEmailViaEmailJs({
    required String to,
    required String subject,
    required String html,
    String? text,
  }) async {
    final trimmedTo = to.trim();
    if (trimmedTo.isEmpty) {
      return;
    }
    final response = await http.post(
      Uri.parse('https://api.emailjs.com/api/v1.0/email/send'),
      headers: {
        'origin': 'http://localhost',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'service_id': _emailJsServiceId,
        'template_id': _emailJsTemplateId,
        'user_id': _emailJsPublicKey,
        'template_params': {
          'to_email': trimmedTo,
          'subject': subject,
          'message_html': html,
          if (text != null) 'message_text': text,
        },
      }),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('EmailJS send failed');
    }
  }

  Future<void> _sendReceiptEmail({
    required BookingItem booking,
    required String paymentId,
    required double amount,
    required String currency,
    String? payerEmail,
  }) async {
    final email = (_auth.currentUser?.email ?? payerEmail ?? '').trim();
    if (email.isEmpty) {
      return;
    }
    final receiptType =
        booking.source == 'accommodation' ? 'Accommodation' : 'Event';
    final serviceName = booking.name.trim().isEmpty ? '-' : booking.name.trim();
    final paymentDate = booking.date.trim();
    final eventDate = (booking.eventDate ?? '').trim();
    final eventLocation = (booking.eventLocation ?? '').trim();
    final checkIn = (booking.checkIn ?? '').trim();
    final checkOut = (booking.checkOut ?? '').trim();
    final stayLocation = (booking.accommodationLocation ?? '').trim();
    final roomType = (booking.roomType ?? '').trim();
    final roomCount = booking.roomCount;
    final peopleCount = booking.peopleCount ?? 0;
    final childCount = booking.childCount ?? 0;
    final infantCount = booking.infantCount ?? 0;
    final totalGuests = peopleCount + childCount + infantCount;
    final nights = booking.nights;
    final rows = <String>[
      '<tr><td>Service</td><td>${_escapeHtml(serviceName)}</td></tr>',
      if (receiptType == 'Event' && eventDate.isNotEmpty)
        '<tr><td>Event Date</td><td>${_escapeHtml(eventDate)}</td></tr>',
      if (receiptType == 'Event' && eventLocation.isNotEmpty)
        '<tr><td>Event Location</td><td>${_escapeHtml(eventLocation)}</td></tr>',
      if (receiptType == 'Accommodation' && stayLocation.isNotEmpty)
        '<tr><td>Location</td><td>${_escapeHtml(stayLocation)}</td></tr>',
      if (receiptType == 'Accommodation' && roomType.isNotEmpty)
        '<tr><td>Room Type</td><td>${_escapeHtml(roomType)}</td></tr>',
      if (receiptType == 'Accommodation' && roomCount != null)
        '<tr><td>Rooms</td><td>$roomCount</td></tr>',
      if (receiptType == 'Accommodation' && totalGuests > 0)
        '<tr><td>Guests</td><td>$totalGuests</td></tr>',
      if (receiptType == 'Accommodation' && checkIn.isNotEmpty)
        '<tr><td>Check-in</td><td>${_escapeHtml(checkIn)}</td></tr>',
      if (receiptType == 'Accommodation' && checkOut.isNotEmpty)
        '<tr><td>Check-out</td><td>${_escapeHtml(checkOut)}</td></tr>',
      if (receiptType == 'Accommodation' && nights != null)
        '<tr><td>Nights</td><td>$nights</td></tr>',
      '<tr><td>Payment ID</td><td>${_escapeHtml(paymentId)}</td></tr>',
      if (paymentDate.isNotEmpty)
        '<tr><td>Payment Date</td><td>${_escapeHtml(paymentDate)}</td></tr>',
      '<tr><td>Total Paid</td><td>$currency ${amount.toStringAsFixed(2)}</td></tr>',
    ];
    final html = '''
<h2>$receiptType Receipt</h2>
<p>Thank you for your payment. Here are your receipt details:</p>
<table cellpadding="6" cellspacing="0" border="1">
${rows.join()}
</table>
''';
    final text =
        'Receipt for $receiptType: $serviceName. '
        'Payment ID: $paymentId. Total: $currency ${amount.toStringAsFixed(2)}.';
    await _sendEmailViaEmailJs(
      to: email,
      subject: '$receiptType Payment Receipt',
      html: html,
      text: text,
    );
  }

  String _safeFileName(String value) {
    final cleaned =
        value
            .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
            .replaceAll(RegExp(r'\s+'), '_')
            .trim();
    return cleaned.isEmpty ? 'receipt' : cleaned;
  }

  Future<Map<String, String>> _fetchEventInfo(String eventId) async {
    if (eventId.trim().isEmpty) {
      return const {'date': '', 'location': ''};
    }
    try {
      final doc = await _firestore.collection('Event').doc(eventId).get();
      final data = doc.data();
      if (data == null) {
        return const {'date': '', 'location': ''};
      }
      final date = BookingItem._dateStringFromValue(data['Date']);
      final location = BookingItem._stringFrom(data['Location']);
      return {'date': date, 'location': location};
    } catch (_) {
      return const {'date': '', 'location': ''};
    }
  }

  Future<String> _fetchAccommodationLocation(String accommodationId) async {
    if (accommodationId.trim().isEmpty) {
      return '';
    }
    try {
      final doc =
          await _firestore
              .collection('accommodations')
              .doc(accommodationId)
              .get();
      final data = doc.data();
      if (data == null) {
        return '';
      }
      return BookingItem._stringFrom(data['location']);
    } catch (_) {
      return '';
    }
  }

  Future<void> _downloadReceiptPdf({TransactionItem? historyItem}) async {
    final booking = _selectedBooking;
    final item = historyItem;
    final receiptType =
        (item?.source ?? booking?.source) == 'accommodation'
            ? 'Accommodation'
            : 'Event';
    final recipient = _currentUserName();
    final serviceName = item?.name ?? booking?.name ?? '-';
    final paymentId = item?.id ?? booking?.id ?? '-';
    final amount = item?.amount ?? booking?.amount ?? 0;
    final paymentDate = (item?.date ?? booking?.date ?? '').trim();

    final eventDate = (item?.eventDate ?? booking?.eventDate ?? '').trim();
    final eventLocation =
        (item?.eventLocation ?? booking?.eventLocation ?? '').trim();

    final stayCheckIn = (item?.checkIn ?? booking?.checkIn ?? '').trim();
    final stayCheckOut = (item?.checkOut ?? booking?.checkOut ?? '').trim();
    final stayLocation =
        (item?.accommodationLocation ?? booking?.accommodationLocation ?? '')
            .trim();
    final roomType = (item?.roomType ?? booking?.roomType ?? '').trim();
    final roomCount = item?.roomCount ?? booking?.roomCount;
    final peopleCount = item?.peopleCount ?? booking?.peopleCount ?? 0;
    final childCount = item?.childCount ?? booking?.childCount ?? 0;
    final infantCount = item?.infantCount ?? booking?.infantCount ?? 0;
    final totalGuests = peopleCount + childCount + infantCount;
    final nights = item?.nights ?? booking?.nights;

    pw.Widget row(String label, String value) {
      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 4),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              flex: 2,
              child: pw.Text(
                label,
                style: pw.TextStyle(
                  color: PdfColor.fromHex('#64748B'),
                  fontSize: 10,
                ),
              ),
            ),
            pw.Expanded(
              flex: 3,
              child: pw.Text(
                value,
                textAlign: pw.TextAlign.right,
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 10,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        margin: const pw.EdgeInsets.all(24),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Receipt Details',
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 6),
              pw.Text(
                '$receiptType • Travel Payment Receipt',
                style: pw.TextStyle(
                  fontSize: 11,
                  color: PdfColor.fromHex('#93C5FD'),
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 16),
              row('Recipient', recipient),
              row('Service', serviceName),
              if (receiptType == 'Event')
                row('Event Date', eventDate.isEmpty ? '-' : eventDate),
              if (receiptType == 'Event')
                row(
                  'Event Location',
                  eventLocation.isEmpty ? '-' : eventLocation,
                ),
              if (receiptType == 'Accommodation')
                row('Location', stayLocation.isEmpty ? '-' : stayLocation),
              if (receiptType == 'Accommodation')
                row('Room Type', roomType.isEmpty ? '-' : roomType),
              if (receiptType == 'Accommodation')
                row('Rooms', roomCount == null ? '-' : '$roomCount'),
              if (receiptType == 'Accommodation')
                row('Guests', totalGuests == 0 ? '-' : '$totalGuests'),
              if (receiptType == 'Accommodation')
                row('Check-in', stayCheckIn.isEmpty ? '-' : stayCheckIn),
              if (receiptType == 'Accommodation')
                row('Check-out', stayCheckOut.isEmpty ? '-' : stayCheckOut),
              if (receiptType == 'Accommodation')
                row('Nights', nights == null ? '-' : '$nights'),
              row('Payment ID', paymentId),
              if (paymentDate.isNotEmpty) row('Payment Date', paymentDate),
              pw.SizedBox(height: 16),
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#2563EB'),
                  borderRadius: pw.BorderRadius.circular(14),
                ),
                child: pw.Column(
                  children: [
                    pw.Text(
                      'FINAL AMOUNT PAID',
                      style: pw.TextStyle(
                        fontSize: 9,
                        letterSpacing: 1.6,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColor.fromHex('#DBEAFE'),
                      ),
                    ),
                    pw.SizedBox(height: 6),
                    pw.Text(
                      'RM ${amount.toStringAsFixed(2)}',
                      style: pw.TextStyle(
                        fontSize: 22,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );

    try {
      final fileName = 'receipt_${_safeFileName(paymentId)}.pdf';
      Directory? targetDir;
      if (Platform.isAndroid) {
        targetDir = Directory('/storage/emulated/0/Download');
      } else {
        targetDir = await getDownloadsDirectory();
      }
      targetDir ??= await getApplicationDocumentsDirectory();
      if (!await targetDir.exists()) {
        await targetDir.create(recursive: true);
      }
      final file = File('${targetDir.path}${Platform.pathSeparator}$fileName');
      await file.writeAsBytes(await doc.save());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Receipt saved in ${targetDir.path}')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to save receipt PDF.')),
      );
    }
  }

  Future<void> _showReceiptDialog({TransactionItem? historyItem}) {
    final booking = _selectedBooking;
    final item = historyItem;
    final receiptType =
        (item?.source ?? booking?.source) == 'accommodation'
            ? 'Accommodation'
            : 'Event';
    final eventDate = (item?.eventDate ?? booking?.eventDate ?? '').trim();
    final eventLocation =
        (item?.eventLocation ?? booking?.eventLocation ?? '').trim();
    final eventId = (item?.eventId ?? booking?.eventId ?? '').trim();
    final needsEventLookup =
        receiptType == 'Event' &&
        (eventDate.isEmpty || eventLocation.isEmpty) &&
        eventId.isNotEmpty;
    final stayCheckIn = (item?.checkIn ?? booking?.checkIn ?? '').trim();
    final stayCheckOut = (item?.checkOut ?? booking?.checkOut ?? '').trim();
    final stayLocation =
        (item?.accommodationLocation ?? booking?.accommodationLocation ?? '')
            .trim();
    final accommodationId =
        (item?.accommodationId ?? booking?.accommodationId ?? '').trim();
    final needsAccommodationLookup =
        receiptType == 'Accommodation' &&
        stayLocation.isEmpty &&
        accommodationId.isNotEmpty;
    final roomType = (item?.roomType ?? booking?.roomType ?? '').trim();
    final roomCount = item?.roomCount ?? booking?.roomCount;
    final peopleCount = item?.peopleCount ?? booking?.peopleCount ?? 0;
    final childCount = item?.childCount ?? booking?.childCount ?? 0;
    final infantCount = item?.infantCount ?? booking?.infantCount ?? 0;
    final totalGuests = peopleCount + childCount + infantCount;
    final nights = item?.nights ?? booking?.nights;

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
                Text(
                  receiptType,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                  ),
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
                _ReceiptRow(label: 'Recipient:', value: _currentUserName()),
                _ReceiptRow(
                  label: 'Service:',
                  value: item?.name ?? booking?.name ?? '-',
                ),
                if (receiptType == 'Accommodation' && !needsAccommodationLookup)
                  _ReceiptRow(
                    label: 'Location:',
                    value: stayLocation.isEmpty ? '-' : stayLocation,
                  ),
                if (receiptType == 'Accommodation' && needsAccommodationLookup)
                  FutureBuilder<String>(
                    future: _fetchAccommodationLocation(accommodationId),
                    builder: (context, snapshot) {
                      final resolvedLocation =
                          snapshot.data?.trim().isNotEmpty == true
                              ? snapshot.data!.trim()
                              : stayLocation;
                      return _ReceiptRow(
                        label: 'Location:',
                        value:
                            resolvedLocation.isEmpty ? '-' : resolvedLocation,
                      );
                    },
                  ),
                if (receiptType == 'Accommodation')
                  _ReceiptRow(
                    label: 'Room Type:',
                    value: roomType.isEmpty ? '-' : roomType,
                  ),
                if (receiptType == 'Accommodation')
                  _ReceiptRow(
                    label: 'Rooms:',
                    value: roomCount == null ? '-' : '$roomCount',
                  ),
                if (receiptType == 'Accommodation')
                  _ReceiptRow(
                    label: 'Guests:',
                    value: totalGuests == 0 ? '-' : '$totalGuests',
                  ),
                if (receiptType == 'Accommodation')
                  _ReceiptRow(
                    label: 'Check-in:',
                    value: stayCheckIn.isEmpty ? '-' : stayCheckIn,
                  ),
                if (receiptType == 'Accommodation')
                  _ReceiptRow(
                    label: 'Check-out:',
                    value: stayCheckOut.isEmpty ? '-' : stayCheckOut,
                  ),
                if (receiptType == 'Accommodation')
                  _ReceiptRow(
                    label: 'Nights:',
                    value: nights == null ? '-' : '$nights',
                  ),
                if (receiptType == 'Event' && !needsEventLookup)
                  _ReceiptRow(
                    label: 'Event Date:',
                    value: eventDate.isEmpty ? '-' : eventDate,
                  ),
                if (receiptType == 'Event' && !needsEventLookup)
                  _ReceiptRow(
                    label: 'Event Location:',
                    value: eventLocation.isEmpty ? '-' : eventLocation,
                  ),
                if (receiptType == 'Event' && needsEventLookup)
                  FutureBuilder<Map<String, String>>(
                    future: _fetchEventInfo(eventId),
                    builder: (context, snapshot) {
                      final fetched = snapshot.data;
                      final resolvedDate = fetched?['date'] ?? eventDate;
                      final resolvedLocation =
                          fetched?['location'] ?? eventLocation;
                      return Column(
                        children: [
                          _ReceiptRow(
                            label: 'Event Date:',
                            value: resolvedDate.isEmpty ? '-' : resolvedDate,
                          ),
                          _ReceiptRow(
                            label: 'Event Location:',
                            value:
                                resolvedLocation.isEmpty
                                    ? '-'
                                    : resolvedLocation,
                          ),
                        ],
                      );
                    },
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
                    onPressed: () async {
                      await _downloadReceiptPdf(historyItem: item);
                      if (context.mounted) {
                        Navigator.of(context).pop();
                      }
                    },
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
