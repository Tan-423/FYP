import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:webview_flutter/webview_flutter.dart';

import 'accommodation_models.dart';
import 'accommodation_views.dart';
import 'accommodation_widgets.dart';

class AccommodationScreen extends StatefulWidget {
  const AccommodationScreen({super.key, this.retryPaymentId});

  final String? retryPaymentId;

  @override
  State<AccommodationScreen> createState() => _AccommodationScreenState();
}

class _AccommodationScreenState extends State<AccommodationScreen> {
  static const String _emailJsServiceId = 'service_duet1ff';
  static const String _emailJsTemplateId = 'template_ifgo794';
  static const String _emailJsPublicKey = 'IUJGANEaedb8T2n1N';
  bool _didResumePayment = false;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final CollectionReference<Map<String, dynamic>> _paymentsRef =
      FirebaseFirestore.instance.collection('AccommodationPayments');
  final CollectionReference<Map<String, dynamic>> _bookingsRef =
      FirebaseFirestore.instance.collection('AccommodationBookings');
  final CollectionReference<Map<String, dynamic>> _ownersRef =
      FirebaseFirestore.instance.collection('Owner');
  AccommodationView _currentView = AccommodationView.auth;
  AccommodationItem? _selectedItem;
  AccommodationItem? _editingItem;
  String _filter = 'All';
  String _searchQuery = '';
  final List<NotificationItem> _notifications = [];
  bool _isProcessing = false;
  bool _isPublishing = false;
  bool _isAuthenticating = false;
  bool _showOwnerPassword = false;
  bool _isGuest = false;
  bool _isCreatingPayment = false;
  bool _isCapturingPayment = false;
  bool _isOwnerLoggedIn = false;
  bool _isUpdatingOwnerProfile = false;
  AccommodationItem? _pendingPaymentItem;
  BookingRequest? _pendingBookingRequest;
  String? _paymentApprovalUrl;
  String? _paymentOrderId;
  String _currentOwnerName = '';

  final String _paypalBaseUrl =
      'https://us-central1-fyp-project-7199d.cloudfunctions.net';
  final String _paypalReturnUrl =
      'https://us-central1-fyp-project-7199d.cloudfunctions.net/paypalSuccess';
  final String _paypalCancelUrl =
      'https://us-central1-fyp-project-7199d.cloudfunctions.net/paypalCancel';
  final TextEditingController _ownerEmailController = TextEditingController();
  final TextEditingController _ownerPasswordController =
      TextEditingController();
  final TextEditingController _ownerProfileNameController =
      TextEditingController();

  final Set<AccommodationView> _hideNavViews = {
    AccommodationView.detail,
    AccommodationView.booking,
    AccommodationView.payment,
    AccommodationView.publish,
    AccommodationView.auth,
    AccommodationView.ownerLogin,
    AccommodationView.ownerProfile,
  };

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

  Future<void> _sendAccommodationReceiptEmail({
    required AccommodationItem item,
    required BookingRequest request,
    required String paymentId,
    required double amount,
    String? payerEmail,
  }) async {
    final email = (_auth.currentUser?.email ?? payerEmail ?? '').trim();
    if (email.isEmpty) {
      return;
    }
    final rows = <String>[
      '<tr><td>Accommodation</td><td>${_escapeHtml(item.name)}</td></tr>',
      if (item.location.isNotEmpty)
        '<tr><td>Location</td><td>${_escapeHtml(item.location)}</td></tr>',
      '<tr><td>Room Type</td><td>${_escapeHtml(request.roomType)}</td></tr>',
      '<tr><td>Rooms</td><td>${request.roomCount}</td></tr>',
      '<tr><td>Guests</td><td>${request.peopleCount + request.childCount + request.infantCount}</td></tr>',
      '<tr><td>Check-in</td><td>${_escapeHtml(_formatDate(request.checkIn))}</td></tr>',
      '<tr><td>Check-out</td><td>${_escapeHtml(_formatDate(request.checkOut))}</td></tr>',
      '<tr><td>Nights</td><td>${request.nights}</td></tr>',
      '<tr><td>Payment ID</td><td>${_escapeHtml(paymentId)}</td></tr>',
      '<tr><td>Total Paid</td><td>MYR ${amount.toStringAsFixed(2)}</td></tr>',
    ];
    final html = '''
<h2>Accommodation Payment Receipt</h2>
<p>Thank you for your payment. Here are your receipt details:</p>
<table cellpadding="6" cellspacing="0" border="1">
${rows.join()}
</table>
''';
    final text = 'Receipt for ${item.name}. '
        'Payment ID: $paymentId. Total: MYR ${amount.toStringAsFixed(2)}.';
    await _sendEmailViaEmailJs(
      to: email,
      subject: 'Accommodation Payment Receipt',
      html: html,
      text: text,
    );
  }

  Future<void> _sendAccommodationCancellationEmail({
    required String bookingId,
    required String accommodationName,
    required String location,
    required String checkIn,
    required String checkOut,
    required int roomCount,
    String? payerEmail,
  }) async {
    final email = (_auth.currentUser?.email ?? payerEmail ?? '').trim();
    if (email.isEmpty) {
      return;
    }
    final rows = <String>[
      '<tr><td>Accommodation</td><td>${_escapeHtml(accommodationName)}</td></tr>',
      if (location.isNotEmpty)
        '<tr><td>Location</td><td>${_escapeHtml(location)}</td></tr>',
      if (checkIn.isNotEmpty)
        '<tr><td>Check-in</td><td>${_escapeHtml(checkIn)}</td></tr>',
      if (checkOut.isNotEmpty)
        '<tr><td>Check-out</td><td>${_escapeHtml(checkOut)}</td></tr>',
      '<tr><td>Rooms</td><td>$roomCount</td></tr>',
      '<tr><td>Booking ID</td><td>${_escapeHtml(bookingId)}</td></tr>',
    ];
    final html = '''
<h2>Booking Cancellation</h2>
<p>Your booking has been cancelled. If eligible, a refund will be processed.</p>
<table cellpadding="6" cellspacing="0" border="1">
${rows.join()}
</table>
''';
    final text = 'Your booking for $accommodationName has been cancelled. '
        'Booking ID: $bookingId.';
    await _sendEmailViaEmailJs(
      to: email,
      subject: 'Booking Cancellation Confirmation',
      html: html,
      text: text,
    );
  }

  @override
  void initState() {
    super.initState();
    final retryId = widget.retryPaymentId;
    if (retryId != null && retryId.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _didResumePayment) return;
        _didResumePayment = true;
        _resumePaymentFromId(retryId);
      });
    }
  }

  @override
  void dispose() {
    _ownerEmailController.dispose();
    _ownerPasswordController.dispose();
    _ownerProfileNameController.dispose();
    super.dispose();
  }

  List<AccommodationItem> _filteredList(List<AccommodationItem> source) {
    return source.where((item) {
      final matchesType = _filter == 'All' || item.type == _filter;
      final searchLower = _searchQuery.toLowerCase();
      final matchesSearch =
          item.name.toLowerCase().contains(searchLower) ||
          item.location.toLowerCase().contains(searchLower);
      return matchesType && matchesSearch;
    }).toList();
  }

  Stream<List<AccommodationItem>> _accommodationsStream() {
    return _firestore
        .collection('accommodations')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map(
                    (doc) => AccommodationItem.fromMap(doc.data(), id: doc.id),
                  )
                  .toList(),
        );
  }

  Stream<List<AccommodationPaymentRecord>> _failedPaymentsStream() {
    final userId = _auth.currentUser?.uid ?? 'guest';
    return _paymentsRef
        .where('UserId', isEqualTo: userId)
        .where(
          'Status',
          whereIn: ['FAILED', 'CREATED', 'RETRYING', 'CANCELLED'],
        )
        .snapshots()
        .map((snapshot) {
          final payments = <AccommodationPaymentRecord>[];
          for (final doc in snapshot.docs) {
            final payment = _paymentFromDoc(doc);
            if (payment != null) {
              payments.add(payment);
            }
          }
          return payments;
        });
  }

  Stream<int> _ownerActiveBookingsCount() {
    if (!_isOwnerLoggedIn) return Stream.value(0);
    final ownerId = _auth.currentUser?.uid;
    if (ownerId == null) return Stream.value(0);
    return _bookingsRef
        .where('OwnerId', isEqualTo: ownerId)
        .where('Status', isEqualTo: 'Confirmed')
        .snapshots()
        .map((snapshot) => snapshot.size);
  }

  Stream<List<BookingItem>> _userBookingsStream() {
    final userId = _auth.currentUser?.uid ?? 'guest';
    return _bookingsRef
        .where('UserId', isEqualTo: userId)
        .where('Status', isEqualTo: 'Confirmed')
        .snapshots()
        .asyncMap((snapshot) async {
          final bookings = <BookingItem>[];
          for (final doc in snapshot.docs) {
            final data = doc.data();
            final accommodationId = data['AccommodationId'] as String?;
            if (accommodationId == null) continue;

            final accommodation = await _fetchAccommodationById(
              accommodationId,
            );
            if (accommodation == null) continue;

            final checkInValue = data['CheckIn'];
            final checkOutValue = data['CheckOut'];
            final checkIn =
                checkInValue is Timestamp ? checkInValue.toDate() : null;
            final checkOut =
                checkOutValue is Timestamp ? checkOutValue.toDate() : null;

            if (checkIn == null || checkOut == null) continue;

            bookings.add(
              BookingItem(
                bookingId: data['BookingId'] as String? ?? doc.id,
                status: data['Status'] as String? ?? 'Confirmed',
                checkIn: _formatDate(checkIn),
                checkOut: _formatDate(checkOut),
                roomType: data['RoomType'] as String? ?? '',
                roomCount: (data['RoomCount'] as num?)?.toInt() ?? 1,
                peopleCount: (data['PeopleCount'] as num?)?.toInt() ?? 1,
                childCount: (data['ChildCount'] as num?)?.toInt() ?? 0,
                infantCount: (data['InfantCount'] as num?)?.toInt() ?? 0,
                extraBed: data['ExtraBed'] as bool? ?? false,
                extraBedFee: (data['ExtraBedFee'] as num?)?.toDouble() ?? 0,
                totalPaid: (data['TotalPaid'] as num?)?.toDouble() ?? 0,
                accommodation: accommodation,
              ),
            );
          }
          // Sort by creation date in memory (newest first)
          bookings.sort((a, b) {
            // If we have creation timestamp in the future, use it
            // For now, sort by booking ID (which includes timestamp)
            return b.bookingId.compareTo(a.bookingId);
          });
          return bookings;
        });
  }

  void _exitToMainMenu() {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
      return;
    }
    setState(() => _currentView = AccommodationView.auth);
  }

  void _addNotification(String message) {
    final note = NotificationItem(
      id: DateTime.now().millisecondsSinceEpoch,
      message: message,
    );
    setState(() => _notifications.insert(0, note));
    Timer(const Duration(seconds: 4), () {
      if (!mounted) return;
      setState(() => _notifications.removeWhere((n) => n.id == note.id));
    });
  }

  Future<void> _confirmBooking(
    AccommodationItem item,
    BookingRequest request, {
    String? paymentId,
    String? payerEmail,
    bool sendReceipt = false,
  }) async {
    setState(() => _isProcessing = true);
    await Future.delayed(const Duration(milliseconds: 1500));
    final bookingId =
        'BK-${1000 + DateTime.now().millisecondsSinceEpoch % 9000}';
    final booking = BookingItem(
      bookingId: bookingId,
      status: 'Confirmed',
      checkIn: _formatDate(request.checkIn),
      checkOut: _formatDate(request.checkOut),
      roomType: request.roomType,
      roomCount: request.roomCount,
      peopleCount: request.peopleCount,
      childCount: request.childCount,
      infantCount: request.infantCount,
      extraBed: request.extraBed,
      extraBedFee: request.extraBedFee,
      totalPaid: request.totalPrice,
      accommodation: item,
    );
    try {
      await _firestore.runTransaction((transaction) async {
        final accommodationRef = _firestore
            .collection('accommodations')
            .doc(item.id);
        final accommodationSnap = await transaction.get(accommodationRef);
        final data = accommodationSnap.data();
        if (data == null) {
          throw Exception('Accommodation missing');
        }
        final roomTypesRaw = data['roomTypes'];
        final current =
            roomTypesRaw is Map
                ? (roomTypesRaw[request.roomType] as num?)?.toInt() ?? 0
                : 0;
        final next = current - request.roomCount;
        if (next < 0) {
          throw Exception('Insufficient availability');
        }
        transaction.update(accommodationRef, {
          'roomTypes.${request.roomType}': next,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        transaction.set(_bookingsRef.doc(bookingId), {
          'BookingId': booking.bookingId,
          'Status': booking.status,
          'UserId': _auth.currentUser?.uid ?? 'guest',
          'AccommodationId': item.id,
          'AccommodationName': item.name,
          'AccommodationLocation': item.location,
          'AccommodationImage': item.image,
          'OwnerId': item.ownerId,
          'RoomType': request.roomType,
          'CheckIn': Timestamp.fromDate(request.checkIn),
          'CheckOut': Timestamp.fromDate(request.checkOut),
          'Nights': request.nights,
          'PricePerNight': request.pricePerNight,
          'RoomCount': request.roomCount,
          'PeopleCount': request.peopleCount,
          'ChildCount': request.childCount,
          'InfantCount': request.infantCount,
          'ExtraBed': request.extraBed,
          'ExtraBedFee': request.extraBedFee,
          'TotalPaid': request.totalPrice,
          'PaymentId': paymentId,
          'PayerEmail': payerEmail,
          'CreatedAt': FieldValue.serverTimestamp(),
        });
      });
    } catch (_) {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
      _addNotification(
        'Unable to confirm booking due to availability. Please try again.',
      );
      return;
    }
    setState(() {
      _isProcessing = false;
      _currentView = AccommodationView.trips;
    });
    if (sendReceipt &&
        paymentId != null &&
        paymentId.trim().isNotEmpty &&
        request.totalPrice > 0) {
      try {
        await _sendAccommodationReceiptEmail(
          item: item,
          request: request,
          paymentId: paymentId,
          amount: request.totalPrice,
          payerEmail: payerEmail,
        );
      } catch (_) {
        // Ignore email failures.
      }
    }
    _addNotification('Booking confirmed for ${item.name}!');
  }

  Future<void> _handleCancel(String bookingId) async {
    try {
      // First, fetch the booking data
      final bookingDoc = await _bookingsRef.doc(bookingId).get();
      final bookingData = bookingDoc.data();
      if (bookingData == null) {
        _addNotification('Booking not found.');
        return;
      }

      final accommodationId = bookingData['AccommodationId'] as String?;
      final roomType = bookingData['RoomType'] as String?;
      final roomCount = (bookingData['RoomCount'] as num?)?.toInt() ?? 1;
      final accommodationName = bookingData['AccommodationName'] as String?;
      final accommodationLocation =
          (bookingData['AccommodationLocation'] as String?) ?? '';
      final payerEmail = (bookingData['PayerEmail'] as String?) ?? '';
      final paymentId = (bookingData['PaymentId'] as String?) ?? '';
      final checkInValue = bookingData['CheckIn'];
      final checkOutValue = bookingData['CheckOut'];
      final checkIn =
          checkInValue is Timestamp ? _formatDate(checkInValue.toDate()) : '';
      final checkOut =
          checkOutValue is Timestamp ? _formatDate(checkOutValue.toDate()) : '';

      if (accommodationId == null) {
        _addNotification('Invalid booking: missing accommodation ID.');
        return;
      }

      if (roomType == null) {
        _addNotification('Invalid booking: missing room type.');
        return;
      }

      await _firestore.runTransaction((transaction) async {
        // STEP 1: Do ALL reads first (Firestore transaction rule)
        final accommodationRef = _firestore
            .collection('accommodations')
            .doc(accommodationId);
        final accommodationSnap = await transaction.get(accommodationRef);
        final data = accommodationSnap.data();
        if (data == null) {
          throw Exception('Accommodation not found');
        }

        // Calculate new room availability
        final roomTypesRaw = data['roomTypes'];
        final current =
            roomTypesRaw is Map
                ? (roomTypesRaw[roomType] as num?)?.toInt() ?? 0
                : 0;
        final next = current + roomCount;

        // STEP 2: Do ALL writes after reads
        final bookingRef = _bookingsRef.doc(bookingId);
        transaction.delete(bookingRef);

        transaction.update(accommodationRef, {
          'roomTypes.$roomType': next,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });
      try {
        await _sendAccommodationCancellationEmail(
          bookingId: bookingId,
          accommodationName: accommodationName ?? 'Accommodation',
          location: accommodationLocation,
          checkIn: checkIn,
          checkOut: checkOut,
          roomCount: roomCount,
          payerEmail: payerEmail,
        );
      } catch (_) {
        // Ignore email failures.
      }
      if (paymentId.trim().isNotEmpty) {
        try {
          await _paymentsRef.doc(paymentId).delete();
        } catch (_) {
          // Ignore payment cleanup failures.
        }
      }
      _addNotification(
        'Reservation for ${accommodationName ?? 'accommodation'} cancelled.',
      );
    } catch (e) {
      print('Error cancelling booking: $e');
      _addNotification('Failed to cancel booking. Please try again.');
    }
  }

  Future<void> _confirmCancelBooking(String bookingId) async {
    if (!mounted) return;
    final shouldCancel = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('Cancel booking?'),
            content: const Text(
              'Are you sure you want to cancel this booking? '
              'This action cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Keep Booking'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Cancel Booking'),
              ),
            ],
          ),
    );
    if (shouldCancel == true) {
      await _handleCancel(bookingId);
    }
  }

  Future<void> _handlePublish(NewPropertyForm form) async {
    if (!_isOwnerLoggedIn) {
      _addNotification('Please login as owner to publish.');
      setState(() => _currentView = AccommodationView.ownerLogin);
      return;
    }
    final name = form.name.trim();
    final location = form.location.trim();
    final description = form.description.trim();
    if (name.isEmpty || location.isEmpty || description.isEmpty) {
      _addNotification('Please fill in name, location, and description.');
      return;
    }
    if (_isPublishing) return;
    setState(() => _isPublishing = true);
    final ownerId = _isOwnerLoggedIn ? _auth.currentUser?.uid : null;
    final wasEditing = _editingItem != null;
    try {
      final payload = {
        'name': name,
        'location': location,
        'price': form.price,
        'type': form.type,
        'rating': 0,
        'description': description,
        'facilities': form.facilities,
        'roomTypes': form.roomTypes,
        'roomCapacities': form.roomCapacities,
        'extraBedFee': form.extraBedFee,
        'image': fallbackAccommodationImageUrl,
        'ownerId': ownerId,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (!wasEditing) {
        await _firestore.collection('accommodations').add({
          ...payload,
          'createdAt': FieldValue.serverTimestamp(),
        });
      } else {
        await _firestore
            .collection('accommodations')
            .doc(_editingItem!.id)
            .set(payload, SetOptions(merge: true));
      }
      if (!mounted) return;
      setState(() {
        _isPublishing = false;
        _editingItem = null;
        _currentView = AccommodationView.owner;
      });
      _addNotification(
        wasEditing
            ? 'Successfully updated $name!'
            : 'Successfully published $name!',
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _isPublishing = false);
      _addNotification('Failed to publish. Please try again.');
    }
  }

  Future<void> _handleDelete(AccommodationItem item) async {
    if (!_isOwnerLoggedIn) {
      _addNotification('Please login as owner to delete.');
      return;
    }
    
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Accommodation'),
        content: Text(
          'Are you sure you want to delete "${item.name}"? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFEF4444),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      // Delete from Firestore
      await _firestore.collection('accommodations').doc(item.id).delete();
      
      if (!mounted) return;
      _addNotification('Successfully deleted ${item.name}');
    } catch (e) {
      if (!mounted) return;
      _addNotification('Failed to delete accommodation. Please try again.');
    }
  }

  void _openDetail(AccommodationItem item) {
    setState(() {
      _selectedItem = item;
      _currentView = AccommodationView.detail;
    });
  }

  String _formatDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  DateTime? _dateFromValue(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) {
      return value;
    }
    if (value is String) {
      return DateTime.tryParse(value);
    }
    return null;
  }

  AccommodationPaymentRecord? _paymentFromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    if (data == null) return null;
    final paymentId = (data['PaymentId'] ?? doc.id).toString();
    final accommodationId = (data['AccommodationId'] ?? '').toString();
    if (accommodationId.isEmpty) return null;
    final name = (data['AccommodationName'] ?? 'Accommodation').toString();
    final amount = (data['Amount'] as num?)?.toDouble() ?? 0;
    final status = (data['Status'] ?? '').toString();
    final roomType = (data['RoomType'] ?? '').toString();
    final checkIn = _dateFromValue(data['CheckIn']);
    final checkOut = _dateFromValue(data['CheckOut']);
    final nights = (data['Nights'] as num?)?.toInt() ?? 0;
    final pricePerNight =
        (data['PricePerNight'] as num?)?.toDouble() ??
        (nights > 0 ? amount / nights : amount);
    final roomCount = (data['RoomCount'] as num?)?.toInt() ?? 1;
    final peopleCount = (data['PeopleCount'] as num?)?.toInt() ?? 1;
    final childCount = (data['ChildCount'] as num?)?.toInt() ?? 0;
    final infantCount = (data['InfantCount'] as num?)?.toInt() ?? 0;
    final extraBed = (data['ExtraBed'] as bool?) ?? false;
    final extraBedFee = (data['ExtraBedFee'] as num?)?.toDouble() ?? 0;
    if (checkIn == null || checkOut == null) return null;
    return AccommodationPaymentRecord(
      paymentId: paymentId,
      accommodationId: accommodationId,
      accommodationName: name,
      amount: amount,
      status: status,
      roomType: roomType,
      checkIn: checkIn,
      checkOut: checkOut,
      nights: nights,
      pricePerNight: pricePerNight,
      roomCount: roomCount,
      peopleCount: peopleCount,
      childCount: childCount,
      infantCount: infantCount,
      extraBed: extraBed,
      extraBedFee: extraBedFee,
    );
  }

  Future<AccommodationItem?> _fetchAccommodationById(String id) async {
    try {
      final doc = await _firestore.collection('accommodations').doc(id).get();
      final data = doc.data();
      if (data == null) return null;
      return AccommodationItem.fromMap(data, id: doc.id);
    } catch (_) {
      return null;
    }
  }

  Future<void> _resumePaymentFromId(String paymentId) async {
    if (paymentId.trim().isEmpty) {
      return;
    }
    try {
      final doc = await _paymentsRef.doc(paymentId).get();
      if (!doc.exists) {
        _addNotification('Payment record not found.');
        return;
      }
      final payment = _paymentFromDoc(doc);
      if (payment == null) {
        _addNotification('Unable to resume payment.');
        return;
      }
      final status = payment.status.toUpperCase();
      if (status == 'CAPTURED') {
        _addNotification('Payment already completed.');
        return;
      }
      await _retryFailedPayment(payment);
    } catch (_) {
      _addNotification('Unable to resume payment.');
    }
  }

  Future<void> _retryFailedPayment(AccommodationPaymentRecord payment) async {
    final item = await _fetchAccommodationById(payment.accommodationId);
    if (item == null) {
      _addNotification('Unable to load accommodation.');
      return;
    }
    // Delete the old payment record to prevent duplicates
    await _paymentsRef.doc(payment.paymentId).delete();

    final request = BookingRequest(
      roomType: payment.roomType,
      checkIn: payment.checkIn,
      checkOut: payment.checkOut,
      nights: payment.nights,
      pricePerNight: payment.pricePerNight,
      roomCount: payment.roomCount,
      peopleCount: payment.peopleCount,
      childCount: payment.childCount,
      infantCount: payment.infantCount,
      extraBed: payment.extraBed,
      extraBedFee: payment.extraBedFee,
      totalPrice: payment.amount,
    );
    _startPayPalCheckout(item, request);
  }

  Future<void> _cancelFailedPayment(AccommodationPaymentRecord payment) async {
    await _paymentsRef.doc(payment.paymentId).set({
      'PaymentId': payment.paymentId,
      'Status': 'CANCELLED',
      'UpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    _addNotification('Failed payment cancelled.');
  }

  Future<void> _deletePaymentRecord(AccommodationPaymentRecord payment) async {
    await _paymentsRef.doc(payment.paymentId).delete();
    _addNotification('Order removed from records.');
  }

  Future<void> _startPayPalCheckout(
    AccommodationItem item,
    BookingRequest request,
  ) async {
    if (_isCreatingPayment) {
      return;
    }
    setState(() {
      _pendingPaymentItem = item;
      _pendingBookingRequest = request;
      _paymentApprovalUrl = null;
      _paymentOrderId = null;
      _isCreatingPayment = true;
      _currentView = AccommodationView.payment;
    });
    try {
      final response = await http.post(
        Uri.parse('$_paypalBaseUrl/createPayPalOrder'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'amount': request.totalPrice.toStringAsFixed(2),
          'currency': 'MYR',
          'return_url': _paypalReturnUrl,
          'cancel_url': _paypalCancelUrl,
          'event_id': item.id,
        }),
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('Order create failed');
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final approvalUrl = data['approvalUrl']?.toString();
      final orderId = data['orderId']?.toString();
      if (approvalUrl == null || orderId == null) {
        throw Exception('Missing approval data');
      }
      await _paymentsRef.doc(orderId).set({
        'PaymentId': orderId,
        'AccommodationId': item.id,
        'AccommodationName': item.name,
        'AccommodationLocation': item.location,
        'UserId': _auth.currentUser?.uid ?? 'guest',
        'Amount': request.totalPrice,
        'Currency': 'MYR',
        'Status': 'CREATED',
        'RoomType': request.roomType,
        'CheckIn': Timestamp.fromDate(request.checkIn),
        'CheckOut': Timestamp.fromDate(request.checkOut),
        'Nights': request.nights,
        'PricePerNight': request.pricePerNight,
        'RoomCount': request.roomCount,
        'PeopleCount': request.peopleCount,
        'ChildCount': request.childCount,
        'InfantCount': request.infantCount,
        'ExtraBed': request.extraBed,
        'ExtraBedFee': request.extraBedFee,
        'CreatedAt': FieldValue.serverTimestamp(),
      });
      if (!mounted) {
        return;
      }
      setState(() {
        _paymentApprovalUrl = approvalUrl;
        _paymentOrderId = orderId;
        _isCreatingPayment = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _isCreatingPayment = false;
          _currentView = AccommodationView.trips;
        });
      }
      _addNotification('Unable to start PayPal checkout.');
    }
  }

  Future<void> _capturePayPalOrder() async {
    if (_paymentOrderId == null || _isCapturingPayment) {
      return;
    }
    setState(() => _isCapturingPayment = true);
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
      if (!mounted) {
        return;
      }
      final item = _pendingPaymentItem;
      final request = _pendingBookingRequest;
      final orderId = _paymentOrderId;
      setState(() {
        _isCapturingPayment = false;
        _paymentApprovalUrl = null;
        _paymentOrderId = null;
        _pendingPaymentItem = null;
        _pendingBookingRequest = null;
      });
      if (item != null && request != null) {
        if (orderId != null) {
          await _paymentsRef.doc(orderId).set({
            'PaymentId': orderId,
            'Status': 'CAPTURED',
            'CapturedAt': FieldValue.serverTimestamp(),
            'PayerEmail': payerEmail,
          }, SetOptions(merge: true));
        }
        await _confirmBooking(
          item,
          request,
          paymentId: orderId,
          payerEmail: payerEmail,
          sendReceipt: true,
        );
      } else {
        setState(() => _currentView = AccommodationView.explore);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isCapturingPayment = false);
      }
      if (_paymentOrderId != null) {
        _paymentsRef.doc(_paymentOrderId).set({
          'PaymentId': _paymentOrderId,
          'Status': 'FAILED',
          'UpdatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
      setState(() {
        _pendingPaymentItem = null;
        _pendingBookingRequest = null;
        _paymentApprovalUrl = null;
        _paymentOrderId = null;
        _isCreatingPayment = false;
        _isCapturingPayment = false;
        _currentView = AccommodationView.trips;
      });
      _addNotification('Payment not completed. Please try again.');
    }
  }

  void _cancelPayPalCheckout() {
    if (_paymentOrderId != null) {
      _paymentsRef.doc(_paymentOrderId).set({
        'PaymentId': _paymentOrderId,
        'Status': 'CANCELLED',
        'UpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
    setState(() {
      _pendingPaymentItem = null;
      _pendingBookingRequest = null;
      _paymentApprovalUrl = null;
      _paymentOrderId = null;
      _isCreatingPayment = false;
      _isCapturingPayment = false;
      _currentView = AccommodationView.trips;
    });
    _addNotification('Payment cancelled.');
  }

  Future<WebViewController> _initializeWebView() async {
    // Clear all cookies to force PayPal login every time
    final cookieManager = WebViewCookieManager();
    await cookieManager.clearCookies();

    final controller =
        WebViewController()
          ..setJavaScriptMode(JavaScriptMode.unrestricted)
          ..setNavigationDelegate(
            NavigationDelegate(
              onNavigationRequest: (request) {
                final url = request.url;
                if (url.startsWith(_paypalReturnUrl)) {
                  _capturePayPalOrder();
                  return NavigationDecision.prevent;
                }
                if (url.startsWith(_paypalCancelUrl)) {
                  _cancelPayPalCheckout();
                  return NavigationDecision.prevent;
                }
                return NavigationDecision.navigate;
              },
            ),
          )
          ..loadRequest(Uri.parse(_paymentApprovalUrl!));

    return controller;
  }

  Future<void> _handleOwnerLogin() async {
    setState(() => _isGuest = false);
    final email = _ownerEmailController.text.trim();
    final password = _ownerPasswordController.text;
    if (email.isEmpty || password.isEmpty) {
      _addNotification('Please enter email and password.');
      return;
    }
    if (_isAuthenticating) return;
    setState(() => _isAuthenticating = true);
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      if (!mounted) return;
      await _loadOwnerProfile();
      setState(() {
        _isAuthenticating = false;
        _isOwnerLoggedIn = true;
        _currentView = AccommodationView.owner;
      });
      _addNotification('Owner login successful.');
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      setState(() => _isAuthenticating = false);
      _addNotification(error.message ?? 'Login failed. Please try again.');
    } catch (_) {
      if (!mounted) return;
      setState(() => _isAuthenticating = false);
      _addNotification('Login failed. Please try again.');
    }
  }

  Future<void> _logoutOwner() async {
    if (!mounted) return;
    setState(() {
      _isOwnerLoggedIn = false;
      _isGuest = false;
      _isUpdatingOwnerProfile = false;
      _currentOwnerName = '';
      _ownerEmailController.clear();
      _ownerPasswordController.clear();
      _ownerProfileNameController.clear();
      _currentView = AccommodationView.auth;
    });
    _addNotification('Logged out.');
  }

  Future<void> _loadOwnerProfile() async {
    final ownerId = _auth.currentUser?.uid;
    if (ownerId == null) return;
    try {
      final ownerProfile = await _ownersRef.doc(ownerId).get();
      final data = ownerProfile.data();
      final name = (data?['name'] as String?)?.trim() ?? '';
      if (!mounted) return;
      setState(() {
        _currentOwnerName = name;
        _ownerProfileNameController.text = name;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _currentOwnerName = '';
        _ownerProfileNameController.clear();
      });
    }
  }

  Future<void> _handleUpdateOwnerProfile() async {
    if (_isUpdatingOwnerProfile) {
      return;
    }
    final name = _ownerProfileNameController.text.trim();
    if (name.isEmpty) {
      _addNotification('Organization name cannot be empty.');
      return;
    }
    final ownerId = _auth.currentUser?.uid;
    if (ownerId == null) {
      _addNotification('Please login again.');
      return;
    }
    setState(() => _isUpdatingOwnerProfile = true);
    try {
      await _ownersRef.doc(ownerId).set({
        'id': ownerId,
        'name': name,
        'email': _auth.currentUser?.email,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (!mounted) return;
      setState(() {
        _currentOwnerName = name;
        _isUpdatingOwnerProfile = false;
        _currentView = AccommodationView.owner;
      });
      _addNotification('Profile updated successfully.');
    } catch (_) {
      if (!mounted) return;
      setState(() => _isUpdatingOwnerProfile = false);
      _addNotification('Failed to update profile.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final showNav = !_hideNavViews.contains(_currentView);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7FB),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                Expanded(child: _buildContent()),
                if (showNav) _buildBottomNav(),
              ],
            ),
            NotificationOverlay(
              notifications: _notifications,
              onDismiss:
                  (id) => setState(
                    () => _notifications.removeWhere((n) => n.id == id),
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    switch (_currentView) {
      case AccommodationView.auth:
        return OwnerAuthView(
          onBack: _exitToMainMenu,
          onContinueAsGuest:
              () => setState(() {
                _isGuest = true;
                _isOwnerLoggedIn = false;
                _currentView = AccommodationView.home;
              }),
          onOwnerLogin:
              () => setState(() => _currentView = AccommodationView.ownerLogin),
        );
      case AccommodationView.ownerLogin:
        return OwnerLoginView(
          emailController: _ownerEmailController,
          passwordController: _ownerPasswordController,
          isLoading: _isAuthenticating,
          showPassword: _showOwnerPassword,
          onTogglePassword:
              () => setState(() => _showOwnerPassword = !_showOwnerPassword),
          onBack: _exitToMainMenu,
          onLogin: _handleOwnerLogin,
        );
      case AccommodationView.home:
        return HomeView(
          searchQuery: _searchQuery,
          onSearchChanged: (value) => setState(() => _searchQuery = value),
          onExplore:
              () => setState(() => _currentView = AccommodationView.explore),
          onQuickCity: (city) {
            setState(() {
              _searchQuery = city;
              _currentView = AccommodationView.explore;
            });
          },
        );
      case AccommodationView.explore:
        return StreamBuilder<List<AccommodationItem>>(
          stream: _accommodationsStream(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return const InfoEmptyState(
                icon: Icons.error_outline,
                title: 'Unable to load accommodations.',
                subtitle: 'Please check your connection and try again.',
              );
            }
            final items = _filteredList(snapshot.data ?? []);
            return ExploreView(
              filter: _filter,
              onFilterChanged: (value) => setState(() => _filter = value),
              onBack:
                  () => setState(() => _currentView = AccommodationView.home),
              items: items,
              onOpenDetail: _openDetail,
            );
          },
        );
      case AccommodationView.detail:
        return DetailView(
          item: _selectedItem,
          onBack:
              () => setState(() => _currentView = AccommodationView.explore),
          onBook:
              () => setState(() => _currentView = AccommodationView.booking),
        );
      case AccommodationView.booking:
        return BookingView(
          item: _selectedItem,
          onBack: () => setState(() => _currentView = AccommodationView.detail),
          isProcessing: _isProcessing,
          onPay: (request) {
            final item = _selectedItem;
            if (item == null) return;
            if (request.totalPrice <= 0) {
              _confirmBooking(item, request);
            } else {
              _startPayPalCheckout(item, request);
            }
          },
        );
      case AccommodationView.payment:
        final item = _pendingPaymentItem;
        final request = _pendingBookingRequest;
        if (item == null || request == null) {
          return InfoEmptyState(
            icon: Icons.payment,
            title: 'No payment in progress.',
            actionLabel: 'Back to My Bookings',
            onAction:
                () => setState(() => _currentView = AccommodationView.trips),
          );
        }
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: _cancelPayPalCheckout,
                    icon: const Icon(Icons.chevron_left),
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    'Pay with PayPal',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Card(
                child: ListTile(
                  title: Text(item.name),
                  subtitle: Text(item.location),
                  trailing: Text(
                    'RM ${request.totalPrice.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child:
                  _paymentApprovalUrl == null
                      ? const Center(child: CircularProgressIndicator())
                      : FutureBuilder(
                        future: _initializeWebView(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }
                          return ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: WebViewWidget(controller: snapshot.data!),
                          );
                        },
                      ),
            ),
            if (_isCapturingPayment)
              const Padding(
                padding: EdgeInsets.all(12),
                child: Text('Capturing payment...'),
              ),
          ],
        );
      case AccommodationView.trips:
        return StreamBuilder<List<BookingItem>>(
          stream: _userBookingsStream(),
          builder: (context, bookingsSnapshot) {
            if (bookingsSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (bookingsSnapshot.hasError) {
              return const InfoEmptyState(
                icon: Icons.error_outline,
                title: 'Unable to load bookings.',
              );
            }
            return StreamBuilder<List<AccommodationPaymentRecord>>(
              stream: _failedPaymentsStream(),
              builder: (context, paymentsSnapshot) {
                if (paymentsSnapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (paymentsSnapshot.hasError) {
                  return const InfoEmptyState(
                    icon: Icons.error_outline,
                    title: 'Unable to load payments.',
                  );
                }
                return TripsView(
                  bookings: bookingsSnapshot.data ?? [],
                  failedPayments: paymentsSnapshot.data ?? [],
                  onRetryPayment: _retryFailedPayment,
                  onCancelPayment: _cancelFailedPayment,
                  onDeletePayment: _deletePaymentRecord,
                  onCancel: _confirmCancelBooking,
                  onExplore:
                      () => setState(
                        () => _currentView = AccommodationView.explore,
                      ),
                );
              },
            );
          },
        );
      case AccommodationView.owner:
        if (_isGuest) {
          return const InfoEmptyState(
            icon: Icons.lock_outline,
            title: 'Owner access required.',
            subtitle: 'Guest mode cannot access owner tools.',
          );
        }
        if (!_isOwnerLoggedIn) {
          return InfoEmptyState(
            icon: Icons.lock_outline,
            title: 'Owner access required.',
            subtitle: 'Please login as owner to manage listings.',
            actionLabel: 'Owner Login',
            onAction:
                () =>
                    setState(() => _currentView = AccommodationView.ownerLogin),
          );
        }
        return StreamBuilder<List<AccommodationItem>>(
          stream: _accommodationsStream(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return const InfoEmptyState(
                icon: Icons.error_outline,
                title: 'Unable to load listings.',
              );
            }
            return StreamBuilder<int>(
              stream: _ownerActiveBookingsCount(),
              builder: (context, countSnapshot) {
                return OwnerView(
                  accommodations: snapshot.data ?? [],
                  ownerId: _isOwnerLoggedIn ? _auth.currentUser?.uid : null,
                  activeBookings: countSnapshot.data ?? 0,
                  ownerName: _currentOwnerName,
                  onEdit:
                      (item) => setState(() {
                        _editingItem = item;
                        _currentView = AccommodationView.publish;
                      }),
                  onDelete: _handleDelete,
                  onPublish:
                      () => setState(() {
                        _editingItem = null;
                        _currentView = AccommodationView.publish;
                      }),
                  onProfile:
                      () => setState(
                        () => _currentView = AccommodationView.ownerProfile,
                      ),
                );
              },
            );
          },
        );
      case AccommodationView.publish:
        return PublishFormView(
          onBack:
              () => setState(() {
                _editingItem = null;
                _currentView = AccommodationView.owner;
              }),
          onPublish: _handlePublish,
          isPublishing: _isPublishing,
          initialItem: _editingItem,
        );
      case AccommodationView.ownerProfile:
        if (_isGuest || !_isOwnerLoggedIn) {
          return const InfoEmptyState(
            icon: Icons.lock_outline,
            title: 'Owner access required.',
            subtitle: 'Please login as owner to update your profile.',
          );
        }
        return OwnerProfileView(
          nameController: _ownerProfileNameController,
          isSaving: _isUpdatingOwnerProfile,
          onBack: () => setState(() => _currentView = AccommodationView.owner),
          onSave: _handleUpdateOwnerProfile,
        );
    }
  }

  Widget _buildBottomNav() {
    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFECEFF4))),
        boxShadow: [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 12,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          NavButton(
            label: 'Home',
            icon: Icons.home_rounded,
            active: _currentView == AccommodationView.home,
            onTap: () => setState(() => _currentView = AccommodationView.home),
          ),
          NavButton(
            label: 'Explore',
            icon: Icons.search_rounded,
            active: _currentView == AccommodationView.explore,
            onTap:
                () => setState(() => _currentView = AccommodationView.explore),
          ),
          if (!_isOwnerLoggedIn)
            NavButton(
              label: 'Trips',
              icon: Icons.work_rounded,
              active: _currentView == AccommodationView.trips,
              onTap:
                  () => setState(() => _currentView = AccommodationView.trips),
            ),
          if (!_isGuest)
            NavButton(
              label: 'Owner',
              icon: Icons.add_circle_outline_rounded,
              active: _currentView == AccommodationView.owner,
              onTap: () {
                if (!_isOwnerLoggedIn) {
                  setState(() => _currentView = AccommodationView.ownerLogin);
                } else {
                  setState(() => _currentView = AccommodationView.owner);
                }
              },
            ),
          NavButton(
            label: 'Logout',
            icon: Icons.logout,
            active: false,
            onTap: _logoutOwner,
          ),
        ],
      ),
    );
  }
}
