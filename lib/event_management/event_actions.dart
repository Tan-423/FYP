part of 'event_management.dart';

mixin EventManagementActions on State<EventManagementScreen> {
  static const String _defaultEventImageUrl =
      'lib/event_management/event_image/Food Festival.webp';

  final CollectionReference<Map<String, dynamic>> _eventsRef =
      FirebaseFirestore.instance.collection('Event');
  final CollectionReference<Map<String, dynamic>> _paymentsRef =
      FirebaseFirestore.instance.collection('eventpayment');
  final CollectionReference<Map<String, dynamic>> _ticketsRef =
      FirebaseFirestore.instance.collection('Tickets');

  final List<TicketModel> _tickets = [];

  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _ticketTotalController = TextEditingController();
  final TextEditingController _ticketRemainingController =
      TextEditingController();
  final TextEditingController _organizerEmailController =
      TextEditingController();
  final TextEditingController _organizerPasswordController =
      TextEditingController();
  final TextEditingController _newCategoryController = TextEditingController();
  final TextEditingController _profileNameController = TextEditingController();

  EventView _view = EventView.auth;
  EventModel? _selectedEvent;
  String _activeCategory = 'All';
  String _newEventCategory = 'Food';
  String? _newEventImageRef;
  String _newEventDate = '';
  String _notificationMessage = '';
  bool _notificationIsError = false;
  bool _showOrganizerPassword = false;
  bool _showNewCategoryField = false;
  bool _isAuthenticating = false;
  bool _isUpdatingProfile = false;
  bool _isCreatingPayment = false;
  bool _isCapturingPayment = false;

  final List<String> _categories = ['All', 'Food', 'Culture', 'Music'];
  final List<String> _eventImageOptions = [
    'lib/event_management/event_image/Food Festival.webp',
    'lib/event_management/event_image/Borneo Culture Night.jpg',
    'lib/event_management/event_image/Music Festa.jpg',
  ];
  final ImagePicker _imagePicker = ImagePicker();

  XFile? _newEventImageFile;
  bool _isPublishing = false;
  String? _editingEventId;
  String? _editingEventImageUrl;
  int? _editingEventTicketTotal;
  int? _editingEventTicketsRemaining;
  String? _currentUserRole;
  String? _currentUserId;
  String _currentUserName = 'Guest';

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final CollectionReference<Map<String, dynamic>> _organizersRef =
      FirebaseFirestore.instance.collection('Organizer');

  // TODO: Replace with your Cloud Function / backend base URL.
  final String _paypalBaseUrl =
      'https://us-central1-fyp-project-7199d.cloudfunctions.net';
  final String _paypalReturnUrl =
      'https://us-central1-fyp-project-7199d.cloudfunctions.net/paypalSuccess';
  final String _paypalCancelUrl =
      'https://us-central1-fyp-project-7199d.cloudfunctions.net/paypalCancel';

  EventModel? _pendingPaymentEvent;
  String? _paymentApprovalUrl;
  String? _paymentOrderId;

  String get _fallbackImageUrl => _defaultEventImageUrl;
  bool get _isOrganizer => _currentUserRole == 'organizer';
  bool get _isLoggedIn => _currentUserRole != null;

  Stream<List<EventModel>> _eventsStream() {
    return _eventsRef.snapshots().map((snapshot) {
      final events = <EventModel>[];
      for (final doc in snapshot.docs) {
        final event = _eventFromDoc(doc);
        if (event != null) {
          events.add(event);
        }
      }
      return events;
    });
  }

  Stream<List<TicketModel>> _ticketsStream() {
    final userId = _currentUserId ?? 'guest';
    return _ticketsRef.where('UserId', isEqualTo: userId).snapshots().map(
      (snapshot) {
        final tickets = <TicketModel>[];
        for (final doc in snapshot.docs) {
          final ticket = _ticketFromDoc(doc);
          if (ticket != null) {
            tickets.add(ticket);
          }
        }
        return tickets;
      },
    );
  }

  Stream<List<PaymentRecord>> _failedPaymentsStream() {
    final userId = _currentUserId ?? 'guest';
    return _paymentsRef
        .where('UserId', isEqualTo: userId)
        .where('Status', whereIn: ['FAILED', 'CREATED', 'RETRYING', 'CANCELLED'])
        .snapshots()
        .map((snapshot) {
          final payments = <PaymentRecord>[];
          for (final doc in snapshot.docs) {
            final payment = _paymentFromDoc(doc);
            if (payment != null) {
              payments.add(payment);
            }
          }
          return payments;
        });
  }

  EventModel? _eventFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    if (data == null) {
      return null;
    }
    final normalized = _normalizedKeys(data);
    final category = _asString(normalized['type']) ??
        _asString(normalized['category']) ??
        _asString(data['Type']) ??
        _asString(data['Category']) ??
        '';
    final imageRef = _asString(normalized['imageurl']) ??
        _asString(data['ImageUrl']) ??
        _fallbackImageRefForCategory(category) ??
        _defaultEventImageUrl;
    final name = _asString(normalized['name']) ??
        _asString(data['Name']) ??
        _asString(data['name']) ??
        '';
    final location = _asString(normalized['location']) ??
        _asString(data['Location']) ??
        _asString(data['location']) ??
        '';
    final organizerId = _asString(normalized['organizerid']) ??
        _asString(data['OrganizerId']) ??
        _asString(data['OrganizerID']) ??
        '';
    final organizerName = _asString(normalized['organizername']) ??
        _asString(data['OrganizerName']) ??
        _asString(normalized['organizer']) ??
        _asString(data['Organizer']) ??
        '';
    final ticketTotal = _asInt(normalized['tickettotal']) ??
        _asInt(data['TicketTotal']) ??
        _asInt(normalized['totaltickets']) ??
        _asInt(data['TotalTickets']);
    final ticketsRemaining = _asInt(normalized['ticketsremaining']) ??
        _asInt(data['TicketsRemaining']) ??
        _asInt(normalized['remainingtickets']) ??
        _asInt(data['RemainingTickets']) ??
        ticketTotal;
    return EventModel(
      id: _asString(normalized['id']) ?? _asString(data['ID']) ?? doc.id,
      name: name.trim().isEmpty ? 'Untitled Event' : name,
      location: location.trim().isEmpty ? 'Location TBC' : location,
      date: _formatDateValue(normalized['date'] ?? data['Date']),
      price: _asDouble(normalized['price'] ?? data['Price']),
      category: category,
      description: _asString(normalized['description']) ??
          _asString(data['Description']) ??
          '',
      imageUrl: imageRef,
      organizerId: organizerId,
      organizerName:
          organizerName.trim().isEmpty ? 'WanderEase' : organizerName,
      ticketTotal: ticketTotal,
      ticketsRemaining: ticketsRemaining,
    );
  }

  TicketModel? _ticketFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    if (data == null) {
      return null;
    }
    final normalized = _normalizedKeys(data);
    final eventId =
        _asString(normalized['eventid']) ?? _asString(data['EventId']) ?? '';
    final eventLocation = _asString(normalized['eventlocation']) ??
        _asString(data['EventLocation']) ??
        _asString(normalized['location']) ??
        _asString(data['Location']);
    final eventDate = _asString(normalized['eventdate']) ??
        _asString(data['EventDate']) ??
        _asString(normalized['date']) ??
        _asString(data['Date']);
    final eventImageUrl = _asString(normalized['eventimageurl']) ??
        _asString(data['EventImageUrl']) ??
        _asString(normalized['imageurl']) ??
        _asString(data['ImageUrl']);
    final eventName = _asString(normalized['eventname']) ??
        _asString(data['EventName']) ??
        _asString(normalized['name']) ??
        _asString(data['Name']);
    final eventCategory = _asString(normalized['eventcategory']) ??
        _asString(data['EventCategory']) ??
        _asString(normalized['category']) ??
        _asString(data['Category']);
    final organizerId = _asString(normalized['organizerid']) ??
        _asString(data['OrganizerId']) ??
        _asString(normalized['organizerid']) ??
        _asString(data['OrganizerID']);
    final organizerName = _asString(normalized['organizername']) ??
        _asString(data['OrganizerName']) ??
        _asString(normalized['organizer']) ??
        _asString(data['Organizer']);

    if (eventId.isNotEmpty &&
        (eventLocation == null ||
            eventDate == null ||
            eventImageUrl == null ||
            eventName == null)) {
      _backfillTicketEventData(ticketId: doc.id, eventId: eventId);
    }

    final event = EventModel(
      id: eventId,
      name: eventName ?? 'Untitled Event',
      location: eventLocation ?? 'Location TBC',
      date: eventDate ?? '',
      price: _asDouble(normalized['price'] ?? data['Price']),
      category: eventCategory ?? '',
      description: _asString(normalized['eventdescription']) ??
          _asString(data['EventDescription']) ??
          '',
      imageUrl: eventImageUrl ?? _fallbackImageUrl,
      organizerId: organizerId ?? '',
      organizerName: organizerName ?? '',
      ticketTotal: _asInt(normalized['tickettotal']) ??
          _asInt(data['TicketTotal']),
      ticketsRemaining: _asInt(normalized['ticketsremaining']) ??
          _asInt(data['TicketsRemaining']),
    );
    return TicketModel(
      ticketId: _asString(normalized['ticketid']) ??
          _asString(data['TicketId']) ??
          doc.id,
      purchaseDate: _asString(normalized['purchasedate']) ??
          _asString(data['PurchaseDate']) ??
          '',
      event: event,
    );
  }

  PaymentRecord? _paymentFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    if (data == null) {
      return null;
    }
    final normalized = _normalizedKeys(data);
    final paymentId =
        _asString(normalized['paymentid']) ?? _asString(data['PaymentId']) ?? doc.id;
    final eventId =
        _asString(normalized['eventid']) ?? _asString(data['EventId']) ?? '';
    if (eventId.isEmpty) {
      return null;
    }
    final eventName =
        _asString(normalized['eventname']) ?? _asString(data['EventName']) ?? 'Event';
    final amount = _asDouble(normalized['amount'] ?? data['Amount']);
    final status =
        _asString(normalized['status']) ?? _asString(data['Status']) ?? '';
    final createdAt = (data['CreatedAt'] as Timestamp?)?.toDate();
    return PaymentRecord(
      paymentId: paymentId,
      eventId: eventId,
      eventName: eventName,
      amount: amount,
      status: status,
      createdAt: createdAt,
    );
  }

  Future<void> _backfillTicketEventData({
    required String ticketId,
    required String eventId,
  }) async {
    try {
      final eventDoc = await _eventsRef.doc(eventId).get();
      final event = _eventFromDoc(eventDoc);
      if (event == null) {
        return;
      }
      await _ticketsRef.doc(ticketId).set({
        'EventName': event.name,
        'EventLocation': event.location,
        'EventDate': event.date,
        'EventImageUrl': event.imageUrl,
        'EventCategory': event.category,
        'OrganizerId': event.organizerId,
        'OrganizerName': event.organizerName,
      }, SetOptions(merge: true));
    } catch (_) {
      // Best-effort backfill; ignore failures.
    }
  }

  String? _asString(dynamic value) {
    if (value == null) {
      return null;
    }
    return value.toString();
  }

  Map<String, dynamic> _normalizedKeys(Map<String, dynamic> data) {
    final normalized = <String, dynamic>{};
    for (final entry in data.entries) {
      normalized[entry.key.trim().toLowerCase()] = entry.value;
    }
    return normalized;
  }

  double _asDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  int? _asInt(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value.toString());
  }

  String? _fallbackImageRefForCategory(String category) {
    switch (category.trim().toLowerCase()) {
      case 'food':
        return 'lib/event_management/event_image/Food Festival.webp';
      case 'culture':
        return 'lib/event_management/event_image/Borneo Culture Night.jpg';
      case 'music':
        return 'lib/event_management/event_image/Music Festa.jpg';
      default:
        return null;
    }
  }

  String _imageLabelFromPath(String path) {
    if (path.contains('Food Festival')) {
      return 'Food';
    }
    if (path.contains('Music Festa')) {
      return 'Music';
    }
    if (path.contains('Borneo Culture Night')) {
      return 'Culture';
    }
    final fileName = path.split('/').last;
    final dotIndex = fileName.lastIndexOf('.');
    if (dotIndex <= 0) {
      return fileName;
    }
    return fileName.substring(0, dotIndex);
  }

  String _formatDateValue(dynamic value) {
    DateTime? dateTime;
    if (value is Timestamp) {
      dateTime = value.toDate();
    } else if (value is DateTime) {
      dateTime = value;
    } else if (value is String) {
      dateTime = DateTime.tryParse(value);
    }
    if (dateTime == null) {
      return '';
    }
    final month = dateTime.month.toString().padLeft(2, '0');
    final day = dateTime.day.toString().padLeft(2, '0');
    return '${dateTime.year}-$month-$day';
  }

  List<EventModel> _filteredEventsFrom(List<EventModel> events) {
    final query = _searchController.text.trim().toLowerCase();
    return events.where((event) {
      final matchesCategory =
          _activeCategory == 'All' || event.category == _activeCategory;
      final matchesSearch = event.name.toLowerCase().contains(query) ||
          event.location.toLowerCase().contains(query);
      return matchesCategory && matchesSearch;
    }).toList();
  }

  void _showNotification(String message, {bool isError = false}) {
    setState(() {
      _notificationMessage = message;
      _notificationIsError = isError;
    });
    Future<void>.delayed(const Duration(seconds: 3), () {
      if (!mounted) {
        return;
      }
      setState(() {
        _notificationMessage = '';
      });
    });
  }

  void _selectView(EventView view) {
    setState(() {
      _view = view;
    });
  }

  void _loginAsTraveler() {
    setState(() {
      _currentUserRole = 'traveler';
      _currentUserId = 'traveler';
      _currentUserName = 'Traveler';
      _view = EventView.explore;
    });
    _showNotification('Logged in as traveler.');
  }

  void _openOrganizerLogin() {
    setState(() {
      _view = EventView.organizerLogin;
    });
  }

  void _openProfile() {
    if (!_isOrganizer) {
      _showNotification('Organizer access required.', isError: true);
      return;
    }
    _profileNameController.text = _currentUserName;
    setState(() {
      _view = EventView.profile;
    });
  }

  Future<void> _handleOrganizerLogin() async {
    if (_isAuthenticating) {
      return;
    }
    final email = _organizerEmailController.text.trim();
    final password = _organizerPasswordController.text.trim();
    if (email.isEmpty || password.isEmpty) {
      _showNotification('Please enter email and password.', isError: true);
      return;
    }
    setState(() => _isAuthenticating = true);
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = credential.user;
      if (user == null) {
        throw FirebaseAuthException(code: 'user-not-found');
      }
      final organizerProfile =
          await _organizersRef.doc(user.uid).get();
      final profileData = organizerProfile.data();
      final profileName =
          _asString(profileData?['name'])?.trim();
      final displayName = user.displayName?.trim();
      final derivedName = (profileName != null && profileName.isNotEmpty)
          ? profileName
          : (displayName != null && displayName.isNotEmpty)
              ? displayName
              : _nameFromEmail(user.email ?? email);
      if (!mounted) {
        return;
      }
      setState(() {
        _currentUserRole = 'organizer';
        _currentUserId = user.uid;
        _currentUserName = derivedName;
        _organizerEmailController.clear();
        _organizerPasswordController.clear();
        _showOrganizerPassword = false;
        _isAuthenticating = false;
        _view = EventView.explore;
      });
      _showNotification('Welcome ${_currentUserName.split(' ').first}!');
    } on FirebaseAuthException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _isAuthenticating = false);
      debugPrint(
        'Organizer login failed: code=${error.code} message=${error.message}',
      );
      debugPrint('Organizer login email: $email');
      _showNotification(_friendlyAuthError(error), isError: true);
    } catch (_) {
      if (mounted) {
        setState(() => _isAuthenticating = false);
      }
      _showNotification('Unable to sign in. Please try again.',
          isError: true);
    }
  }

  void _logout() {
    setState(() {
      _currentUserRole = null;
      _currentUserId = null;
      _currentUserName = 'Guest';
      _selectedEvent = null;
      _view = EventView.auth;
    });
    _auth.signOut();
    _showNotification('Logged out successfully.');
  }

  void _openEvent(EventModel event) {
    setState(() {
      _selectedEvent = event;
      _view = EventView.detail;
    });
  }

  Future<void> _joinEvent(EventModel event) async {
    final alreadyJoined = _tickets.any((ticket) => ticket.event.id == event.id);
    if (alreadyJoined) {
      _showNotification('You already have a ticket for this event.',
          isError: true);
      return;
    }
    final remaining = event.ticketsRemaining;
    if (remaining != null && remaining <= 0) {
      _showNotification('This event is sold out.', isError: true);
      return;
    }

    if (event.price > 0) {
      _startPayPalCheckout(event);
      return;
    }
    await _confirmTicketPurchase(event);
  }

  Future<void> _confirmTicketPurchase(
    EventModel event, {
    String? paymentId,
    String? payerEmail,
  }) async {
    final reserved = await _reserveTicket(event.id);
    if (!reserved) {
      _showNotification('This event is sold out.', isError: true);
      return;
    }
    final ticketId = _generateTicketId();
    final purchaseDate =
        DateTime.now().toLocal().toString().split(' ').first;
    final ticketData = <String, dynamic>{
      'TicketId': ticketId,
      'EventId': event.id,
      'EventName': event.name,
      'EventLocation': event.location,
      'EventDate': event.date,
      'EventImageUrl': event.imageUrl,
      'EventCategory': event.category,
      'OrganizerId': event.organizerId,
      'OrganizerName': event.organizerName,
      'UserId': _currentUserId ?? 'guest',
      'PurchaseDate': purchaseDate,
      'Price': event.price,
      'PaymentId': paymentId,
      'PayerEmail': payerEmail,
      'Status': 'ACTIVE',
      'CreatedAt': FieldValue.serverTimestamp(),
    };
    try {
      await _ticketsRef.doc(ticketId).set(ticketData);
    } catch (_) {
      _showNotification('Failed to save ticket. Please try again.',
          isError: true);
      return;
    }
    setState(() {
      _tickets.add(
        TicketModel(ticketId: ticketId, purchaseDate: purchaseDate, event: event),
      );
      _view = EventView.tickets;
    });
    _showNotification('Successfully joined ${event.name}!');
  }

  Future<bool> _reserveTicket(String eventId) async {
    final eventRef = _eventsRef.doc(eventId);
    return FirebaseFirestore.instance.runTransaction<bool>((transaction) async {
      final snapshot = await transaction.get(eventRef);
      final data = snapshot.data();
      if (data == null) {
        return false;
      }
      final normalized = _normalizedKeys(data);
      final remaining = _asInt(normalized['ticketsremaining']) ??
          _asInt(data['TicketsRemaining']) ??
          _asInt(normalized['remainingtickets']) ??
          _asInt(data['RemainingTickets']);
      if (remaining == null) {
        return true;
      }
      if (remaining <= 0) {
        return false;
      }
      transaction.update(eventRef, {'TicketsRemaining': remaining - 1});
      return true;
    });
  }

  Future<EventModel?> _getEventById(String eventId) async {
    try {
      final doc = await _eventsRef.doc(eventId).get();
      return _eventFromDoc(doc);
    } catch (_) {
      return null;
    }
  }

  Future<void> _startPayPalCheckout(EventModel event) async {
    if (_isCreatingPayment) {
      return;
    }
    setState(() {
      _pendingPaymentEvent = event;
      _paymentApprovalUrl = null;
      _paymentOrderId = null;
      _isCreatingPayment = true;
      _view = EventView.payment;
    });
    try {
      final response = await http.post(
        Uri.parse('$_paypalBaseUrl/createPayPalOrder'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'amount': event.price.toStringAsFixed(2),
          'currency': 'MYR',
          'return_url': _paypalReturnUrl,
          'cancel_url': _paypalCancelUrl,
          'event_id': event.id,
        }),
      );
      debugPrint(
        'PayPal create response: ${response.statusCode} ${response.body}',
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
        'EventId': event.id,
        'EventName': event.name,
        'UserId': _currentUserId ?? 'guest',
        'Amount': event.price,
        'Currency': 'MYR',
        'Status': 'CREATED',
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
          _view = EventView.detail;
        });
      }
      _showNotification('Unable to start PayPal checkout.',
          isError: true);
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
      debugPrint(
        'PayPal capture response: ${response.statusCode} ${response.body}',
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('Capture failed');
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final payerEmail = _asString(data['data']?['payer']?['email_address']);
      if (!mounted) {
        return;
      }
      final event = _pendingPaymentEvent;
      final orderId = _paymentOrderId;
      setState(() {
        _isCapturingPayment = false;
        _paymentApprovalUrl = null;
        _paymentOrderId = null;
        _pendingPaymentEvent = null;
      });
      if (event != null) {
        if (orderId != null) {
          await _paymentsRef.doc(orderId).set({
            'PaymentId': orderId,
            'Status': 'CAPTURED',
            'CapturedAt': FieldValue.serverTimestamp(),
            'PayerEmail': payerEmail,
          }, SetOptions(merge: true));
        }
        await _confirmTicketPurchase(event,
            paymentId: orderId, payerEmail: payerEmail);
      } else {
        _selectView(EventView.explore);
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
      _showNotification('Payment not completed. Please try again.',
          isError: true);
    }
  }

  Future<void> _retryFailedPayment(PaymentRecord payment) async {
    final event = await _getEventById(payment.eventId);
    if (event == null) {
      _showNotification('Unable to load event for payment.', isError: true);
      return;
    }
    await _paymentsRef.doc(payment.paymentId).set({
      'PaymentId': payment.paymentId,
      'Status': 'RETRYING',
      'UpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    _startPayPalCheckout(event);
  }

  Future<void> _cancelFailedPayment(PaymentRecord payment) async {
    await _paymentsRef.doc(payment.paymentId).set({
      'PaymentId': payment.paymentId,
      'Status': 'CANCELLED',
      'UpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    _showNotification('Failed payment cancelled.');
  }

  Future<void> _deletePaymentRecord(PaymentRecord payment) async {
    await _paymentsRef.doc(payment.paymentId).delete();
    _showNotification('Order removed from records.');
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
      _pendingPaymentEvent = null;
      _paymentApprovalUrl = null;
      _paymentOrderId = null;
      _isCreatingPayment = false;
      _isCapturingPayment = false;
      _view = EventView.detail;
    });
    _showNotification('Payment cancelled.', isError: true);
  }

  Future<bool> _confirmCancelTicket() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel ticket?'),
        content: const Text(
          'This will delete your ticket and payment record. '
          'A refund will be processed if applicable.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep ticket'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Cancel ticket'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _cancelTicket(TicketModel ticket) async {
    final confirmed = await _confirmCancelTicket();
    if (!confirmed) {
      return;
    }
    final ticketId = ticket.ticketId;
    try {
      final ticketDoc = await _ticketsRef.doc(ticketId).get();
      final data = ticketDoc.data();
      final normalized = data == null ? <String, dynamic>{} : _normalizedKeys(data);
      final paymentId =
          _asString(normalized['paymentid']) ?? _asString(data?['PaymentId']);
      final eventId =
          _asString(normalized['eventid']) ?? _asString(data?['EventId']);

      await _ticketsRef.doc(ticketId).delete();
      if (paymentId != null && paymentId.trim().isNotEmpty) {
        await _paymentsRef.doc(paymentId).delete();
      }

      if (eventId != null && eventId.trim().isNotEmpty) {
        final eventRef = _eventsRef.doc(eventId);
        await FirebaseFirestore.instance.runTransaction((transaction) async {
          final snapshot = await transaction.get(eventRef);
          final eventData = snapshot.data();
          if (eventData == null) {
            return;
          }
          final normalizedEvent = _normalizedKeys(eventData);
          final remaining = _asInt(normalizedEvent['ticketsremaining']) ??
              _asInt(eventData['TicketsRemaining']) ??
              _asInt(normalizedEvent['remainingtickets']) ??
              _asInt(eventData['RemainingTickets']);
          final total = _asInt(normalizedEvent['tickettotal']) ??
              _asInt(eventData['TicketTotal']) ??
              _asInt(normalizedEvent['totaltickets']) ??
              _asInt(eventData['TotalTickets']);
          if (remaining == null) {
            return;
          }
          final nextRemaining = total == null
              ? remaining + 1
              : (remaining + 1 > total ? total : remaining + 1);
          transaction.update(eventRef, {'TicketsRemaining': nextRemaining});
        });
      }

      if (mounted) {
        setState(() {
          _tickets.removeWhere((item) => item.ticketId == ticketId);
        });
      }
      _showNotification('Ticket cancelled. Refund will be processed.');
    } catch (_) {
      _showNotification('Failed to cancel ticket. Please try again.',
          isError: true);
    }
  }

  void _startNewEvent() {
    _resetEventForm();
    setState(() {
      _view = EventView.organize;
    });
  }

  void _startEditingEvent(EventModel event) {
    setState(() {
      _editingEventId = event.id;
      _editingEventImageUrl = event.imageUrl;
      _editingEventTicketTotal = event.ticketTotal;
      _editingEventTicketsRemaining = event.ticketsRemaining;
      _titleController.text = event.name;
      _locationController.text = event.location;
      _priceController.text = event.price.toStringAsFixed(2);
      _descriptionController.text = event.description;
      _ticketTotalController.text =
          event.ticketTotal == null ? '' : event.ticketTotal.toString();
      _ticketRemainingController.text = event.ticketsRemaining == null
          ? ''
          : event.ticketsRemaining.toString();
      _newEventCategory = event.category.isEmpty ? 'Food' : event.category;
      _newEventDate = event.date;
      _newEventImageRef = event.imageUrl.startsWith('http')
          ? null
          : event.imageUrl.isNotEmpty
              ? event.imageUrl
              : null;
      _newEventImageFile = null;
      _view = EventView.edit;
    });
  }

  Future<void> _deleteEvent(String eventId) async {
    try {
      await _eventsRef.doc(eventId).delete();
      _showNotification('Event removed permanently.');
    } catch (_) {
      _showNotification('Failed to delete event.', isError: true);
    }
  }

  void _resetEventForm() {
    _titleController.clear();
    _locationController.clear();
    _priceController.clear();
    _descriptionController.clear();
    _ticketTotalController.clear();
    _ticketRemainingController.clear();
    _newEventCategory = 'Food';
    _newEventDate = '';
    _newEventImageRef = null;
    _newEventImageFile = null;
    _editingEventId = null;
    _editingEventImageUrl = null;
    _editingEventTicketTotal = null;
    _editingEventTicketsRemaining = null;
    _showNewCategoryField = false;
    _newCategoryController.clear();
  }

  void _addNewCategory() {
    final name = _newCategoryController.text.trim();
    if (name.isEmpty) {
      _showNotification('Category name cannot be empty.', isError: true);
      return;
    }
    if (_categories.any((cat) => cat.toLowerCase() == name.toLowerCase())) {
      _showNotification('Category already exists.', isError: true);
      return;
    }
    setState(() {
      _categories.add(name);
      _newEventCategory = name;
      _showNewCategoryField = false;
      _newCategoryController.clear();
    });
  }

  Future<void> _handleUpdateProfile() async {
    if (_isUpdatingProfile) {
      return;
    }
    final name = _profileNameController.text.trim();
    if (name.isEmpty) {
      _showNotification('Organization name cannot be empty.', isError: true);
      return;
    }
    if (_currentUserId == null) {
      _showNotification('Please login again.', isError: true);
      return;
    }
    setState(() => _isUpdatingProfile = true);
    try {
      // Update organizer profile (structured like Firebase document update).
      await _organizersRef.doc(_currentUserId).set({
        'id': _currentUserId,
        'name': name,
        'email': _auth.currentUser?.email,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Denormalized update for event organizer name.
      final snapshot = await _eventsRef
          .where('OrganizerId', isEqualTo: _currentUserId)
          .get();
      final batch = FirebaseFirestore.instance.batch();
      for (final doc in snapshot.docs) {
        batch.update(doc.reference, {'OrganizerName': name});
      }
      await batch.commit();

      if (!mounted) {
        return;
      }
      setState(() {
        _currentUserName = name;
        _isUpdatingProfile = false;
        _view = EventView.manage;
      });
      _showNotification('Profile updated successfully.');
    } catch (_) {
      if (mounted) {
        setState(() => _isUpdatingProfile = false);
      }
      _showNotification('Failed to update profile.', isError: true);
    }
  }

  Future<void> _pickEventImage() async {
    try {
      final picked = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (picked == null) {
        return;
      }
      setState(() {
        _newEventImageFile = picked;
        _newEventImageRef = null;
      });
    } catch (_) {
      _showNotification('Unable to open photo gallery.', isError: true);
    }
  }

  Future<String?> _uploadEventImage(String eventId) async {
    final imageFile = _newEventImageFile;
    if (imageFile == null) {
      return null;
    }
    try {
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('event_images')
          .child('${eventId}_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await storageRef.putFile(File(imageFile.path));
      return await storageRef.getDownloadURL();
    } catch (_) {
      return null;
    }
  }

  Future<void> _publishEvent() async {
    if (_isPublishing) {
      return;
    }
    if (_titleController.text.trim().isEmpty ||
        _locationController.text.trim().isEmpty ||
        _newEventDate.isEmpty) {
      _showNotification('Please fill in all required fields.', isError: true);
      return;
    }

    setState(() => _isPublishing = true);
    final double price = double.tryParse(_priceController.text.trim()) ?? 0;
    final String ticketTotalText = _ticketTotalController.text.trim();
    final String ticketRemainingText = _ticketRemainingController.text.trim();
    final int? ticketTotal =
        ticketTotalText.isEmpty ? null : int.tryParse(ticketTotalText);
    final int? ticketRemainingInput = ticketRemainingText.isEmpty
        ? null
        : int.tryParse(ticketRemainingText);
    if (ticketTotalText.isNotEmpty && ticketTotal == null) {
      _showNotification('Total tickets must be a number.', isError: true);
      setState(() => _isPublishing = false);
      return;
    }
    if (ticketRemainingText.isNotEmpty && ticketRemainingInput == null) {
      _showNotification('Remaining tickets must be a number.', isError: true);
      setState(() => _isPublishing = false);
      return;
    }
    if (ticketRemainingInput != null && ticketTotal == null) {
      _showNotification('Please enter total tickets first.', isError: true);
      setState(() => _isPublishing = false);
      return;
    }
    if (ticketTotal != null &&
        ticketRemainingInput != null &&
        ticketRemainingInput > ticketTotal) {
      _showNotification(
        'Remaining tickets cannot exceed total tickets.',
        isError: true,
      );
      setState(() => _isPublishing = false);
      return;
    }
    final DateTime? parsedDate = DateTime.tryParse(_newEventDate);
    final isEditing = _editingEventId != null;
    final eventId =
        isEditing ? _editingEventId! : DateTime.now().millisecondsSinceEpoch.toString();
    final uploadedImageUrl = await _uploadEventImage(eventId);
    if (_newEventImageFile != null && uploadedImageUrl == null) {
      if (mounted) {
        setState(() => _isPublishing = false);
      }
      _showNotification('Failed to upload image. Please try again.',
          isError: true);
      return;
    }
    final imageRef = (_newEventImageRef == null ||
            _newEventImageRef!.trim().isEmpty)
        ? (_fallbackImageRefForCategory(_newEventCategory) ??
            _defaultEventImageUrl)
        : _newEventImageRef!.trim();
    final resolvedImageUrl = uploadedImageUrl ??
        _editingEventImageUrl ??
        imageRef;
    int? ticketsRemaining;
    if (!isEditing) {
      ticketsRemaining = ticketRemainingInput ?? ticketTotal;
    } else {
      if (ticketRemainingInput != null) {
        ticketsRemaining = ticketRemainingInput;
      } else if (ticketTotal != null) {
        final previousTotal = _editingEventTicketTotal;
        final previousRemaining = _editingEventTicketsRemaining;
        if (previousTotal != null && previousRemaining != null) {
          final sold = previousTotal - previousRemaining;
          final remainingAfter = ticketTotal - sold;
          ticketsRemaining = remainingAfter < 0 ? 0 : remainingAfter;
        } else {
          ticketsRemaining = ticketTotal;
        }
      } else {
        ticketsRemaining = null;
      }
    }
    final newEvent = <String, dynamic>{
      'ID': eventId,
      'Name': _titleController.text.trim(),
      'Location': _locationController.text.trim(),
      'Date': parsedDate == null ? _newEventDate : Timestamp.fromDate(parsedDate),
      'Price': price,
      'Type': _newEventCategory,
      'Description': _descriptionController.text.trim(),
      'ImageUrl': resolvedImageUrl,
      if (ticketTotal != null) 'TicketTotal': ticketTotal,
      if (ticketsRemaining != null) 'TicketsRemaining': ticketsRemaining,
      if (isEditing && ticketTotal == null && ticketRemainingInput == null)
        'TicketTotal': FieldValue.delete(),
      if (isEditing && ticketTotal == null && ticketRemainingInput == null)
        'TicketsRemaining': FieldValue.delete(),
      'OrganizerId': _currentUserId ?? 'org_wanderease',
      'OrganizerName': _currentUserName,
    };

    try {
      if (isEditing) {
        await _eventsRef.doc(eventId).set(newEvent, SetOptions(merge: true));
      } else {
        await _eventsRef.doc(eventId).set(newEvent);
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _resetEventForm();
        _isPublishing = false;
        _view = _isOrganizer ? EventView.manage : EventView.explore;
      });
      _showNotification(
        isEditing ? 'Event updated successfully!' : 'Event published successfully!',
      );
    } catch (error) {
      if (mounted) {
        setState(() => _isPublishing = false);
      }
      _showNotification('Failed to publish event. Please try again.',
          isError: true);
    }
  }

  String _generateTicketId() {
    final random = Random();
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final buffer = StringBuffer('TKT-');
    for (int i = 0; i < 9; i++) {
      buffer.write(chars[random.nextInt(chars.length)]);
    }
    return buffer.toString();
  }

  String _nameFromEmail(String email) {
    final trimmed = email.trim();
    if (trimmed.isEmpty) {
      return 'Organizer';
    }
    final namePart = trimmed.split('@').first;
    if (namePart.isEmpty) {
      return 'Organizer';
    }
    return namePart
        .split(RegExp(r'[^a-zA-Z0-9]+'))
        .where((chunk) => chunk.isNotEmpty)
        .map((chunk) => chunk[0].toUpperCase() + chunk.substring(1))
        .join(' ');
  }

  String _friendlyAuthError(FirebaseAuthException error) {
    switch (error.code) {
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'user-not-found':
        return 'No organizer found with this email.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password.';
      case 'too-many-requests':
        return 'Too many attempts. Try again later.';
      default:
        return 'Unable to sign in. Please try again.';
    }
  }

  Future<void> _selectDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: DateTime(now.year + 3),
    );
    if (picked == null) {
      return;
    }
    setState(() {
      _newEventDate = picked.toIso8601String().split('T').first;
    });
  }
}
