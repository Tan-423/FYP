part of 'event_management.dart';

mixin EventManagementActions on State<EventManagementScreen> {
  static const String _emailJsServiceId = 'service_duet1ff';
  static const String _emailJsTemplateId = 'template_ifgo794';
  static const String _emailJsPublicKey = 'IUJGANEaedb8T2n1N';
  static const String _defaultEventImageUrl =
      'lib/event_management/event_image/Food Festival.webp';

  final CollectionReference<Map<String, dynamic>> _eventsRef = FirebaseFirestore
      .instance
      .collection('Event');
  final CollectionReference<Map<String, dynamic>> _paymentsRef =
      FirebaseFirestore.instance.collection('EventPayment');
  final CollectionReference<Map<String, dynamic>> _ticketsRef =
      FirebaseFirestore.instance.collection('EventTicket');
  final CollectionReference<Map<String, dynamic>> _eventSeatsRef =
      FirebaseFirestore.instance.collection('EventSeat');

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
  EventModel? _seatSelectionEvent;
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
  bool _isFinalizingSeatSelection = false;
  bool _paymentCompleted = false;

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
  int? _editingEventTicketsSold;
  bool _seatSelectionEnabled = false;
  String? _currentUserRole;
  String? _currentUserId;
  String _currentUserName = 'Guest';

  final FirebaseAuth _auth = FirebaseAuth.instance;
  FirebaseAuth? _secondaryAuth;
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
  String? _activePaymentRecordId;
  List<String> _pendingSeatIds = [];
  double? _pendingSeatTotal;
  String? _pendingSeatEventId;
  final Set<String> _selectedSeatIds = {};

  static const List<SeatTypeOption> _seatTypeOptions = [
    SeatTypeOption(type: 'VIP', priceDelta: 30),
    SeatTypeOption(type: 'Premium', priceDelta: 15),
    SeatTypeOption(type: 'Standard', priceDelta: 0),
  ];
  static const Duration _seatHoldDuration = Duration(minutes: 10);

  String get _fallbackImageUrl => _defaultEventImageUrl;
  bool get _isOrganizer => _currentUserRole == 'organizer';
  bool get _isLoggedIn => _currentUserRole != null;

  String _travelerDisplayName() {
    final user = _auth.currentUser;
    final display = user?.displayName?.trim();
    if (display != null && display.isNotEmpty) return display;
    final email = user?.email?.trim();
    if (email != null && email.isNotEmpty) return email.split('@').first;
    return 'Traveler';
  }

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
    final firebaseUid = _auth.currentUser?.uid;

    // Build a set of possible user IDs to match tickets created in any session.
    // Covers cases where Firebase Auth UID differs from the locally stored ID.
    final userIds = <String>{userId};
    if (firebaseUid != null && firebaseUid.isNotEmpty) {
      userIds.add(firebaseUid);
    }

    return _ticketsRef
        .where('UserId', whereIn: userIds.toList())
        .snapshots()
        .map((snapshot) {
      final tickets = <TicketModel>[];
      for (final doc in snapshot.docs) {
        final ticket = _ticketFromDoc(doc);
        if (ticket != null) {
          tickets.add(ticket);
        }
      }
      return tickets;
    });
  }

  Stream<List<PaymentRecord>> _failedPaymentsStream() {
    final userId = _currentUserId ?? 'guest';
    final firebaseUid = _auth.currentUser?.uid;

    final userIds = <String>{userId};
    if (firebaseUid != null && firebaseUid.isNotEmpty) {
      userIds.add(firebaseUid);
    }

    return _paymentsRef
        .where('UserId', whereIn: userIds.toList())
        .where(
          'Status',
          whereIn: ['FAILED', 'CREATED', 'RETRYING', 'CANCELLED'],
        )
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

  Stream<List<EventSeat>> _eventSeatsStream(String eventId) {
    return _eventSeatsRef.where('EventId', isEqualTo: eventId).snapshots().map((
      snapshot,
    ) {
      final seatMap = <String, EventSeat>{};
      for (final doc in snapshot.docs) {
        _clearHeldSeatStatus(doc);
        final seat = _seatFromDoc(doc);
        if (seat != null) {
          final existing = seatMap[seat.seatId];
          if (existing == null) {
            seatMap[seat.seatId] = seat;
            continue;
          }
          final existingStatus = existing.status.trim().toUpperCase();
          final nextStatus = seat.status.trim().toUpperCase();
          if (existingStatus == 'SOLD') {
            continue;
          }
          if (nextStatus == 'SOLD') {
            seatMap[seat.seatId] = seat;
            continue;
          }
          if (existingStatus == 'HELD') {
            continue;
          }
          if (nextStatus == 'HELD') {
            seatMap[seat.seatId] = seat;
            continue;
          }
          seatMap[seat.seatId] = seat;
        }
      }
      final seats = seatMap.values.toList();
      seats.sort(_compareSeats);
      return seats;
    });
  }

  EventModel? _eventFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    if (data == null) {
      return null;
    }
    final normalized = _normalizedKeys(data);
    final category =
        _asString(normalized['type']) ??
        _asString(normalized['category']) ??
        _asString(data['Type']) ??
        _asString(data['Category']) ??
        '';
    final imageRef =
        _asString(normalized['imageurl']) ??
        _asString(data['ImageUrl']) ??
        _fallbackImageRefForCategory(category) ??
        _defaultEventImageUrl;
    final name =
        _asString(normalized['name']) ??
        _asString(data['Name']) ??
        _asString(data['name']) ??
        '';
    final location =
        _asString(normalized['location']) ??
        _asString(data['Location']) ??
        _asString(data['location']) ??
        '';
    final organizerId =
        _asString(normalized['organizerid']) ??
        _asString(data['OrganizerId']) ??
        _asString(data['OrganizerID']) ??
        '';
    final organizerName =
        _asString(normalized['organizername']) ??
        _asString(data['OrganizerName']) ??
        _asString(normalized['organizer']) ??
        _asString(data['Organizer']) ??
        '';
    final ticketTotal =
        _asInt(normalized['tickettotal']) ??
        _asInt(data['TicketTotal']) ??
        _asInt(normalized['totaltickets']) ??
        _asInt(data['TotalTickets']);
    final ticketsRemaining =
        _asInt(normalized['ticketsremaining']) ??
        _asInt(data['TicketsRemaining']) ??
        _asInt(normalized['remainingtickets']) ??
        _asInt(data['RemainingTickets']) ??
        ticketTotal;
    final ticketsSold =
        _asInt(normalized['ticketssold']) ??
        _asInt(data['TicketsSold']) ??
        (ticketTotal != null && ticketsRemaining != null
            ? (ticketTotal - ticketsRemaining)
            : null);
    final seatEnabled =
        (normalized['seatselectionenabled'] as bool?) ??
        (data['SeatSelectionEnabled'] as bool?) ??
        false;
    return EventModel(
      id: _asString(normalized['id']) ?? _asString(data['ID']) ?? doc.id,
      name: name.trim().isEmpty ? 'Untitled Event' : name,
      location: location.trim().isEmpty ? 'Location TBC' : location,
      date: _formatDateValue(normalized['date'] ?? data['Date']),
      price: _asDouble(normalized['price'] ?? data['Price']),
      category: category,
      description:
          _asString(normalized['description']) ??
          _asString(data['Description']) ??
          '',
      imageUrl: imageRef,
      organizerId: organizerId,
      organizerName:
          organizerName.trim().isEmpty ? 'WanderEase' : organizerName,
      ticketTotal: ticketTotal,
      ticketsRemaining: ticketsRemaining,
      ticketsSold: ticketsSold,
      seatSelectionEnabled: seatEnabled,
    );
  }

  EventSeat? _seatFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    if (data == null) {
      return null;
    }
    final normalized = _normalizedKeys(data);
    final eventId =
        _asString(normalized['eventid']) ?? _asString(data['EventId']);
    final seatId = _asString(normalized['seatid']) ?? _asString(data['SeatId']);
    if (eventId == null || seatId == null) {
      return null;
    }
    final type =
        _asString(normalized['seattype']) ??
        _asString(data['SeatType']) ??
        'Standard';
    final status =
        (_asString(normalized['status']) ??
                _asString(data['Status']) ??
                'AVAILABLE')
            .trim()
            .toUpperCase();
    final price = _asDouble(normalized['price'] ?? data['Price']);
    final heldBy = _asString(normalized['heldby']) ?? _asString(data['HeldBy']);
    final heldUntil = _asTimestamp(
      normalized['helduntil'] ?? data['HeldUntil'],
    );
    return EventSeat(
      docId: doc.id,
      eventId: eventId,
      seatId: seatId,
      type: type,
      price: price,
      status: status,
      heldBy: heldBy,
      heldUntil: heldUntil?.toDate(),
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
    final eventLocation =
        _asString(normalized['eventlocation']) ??
        _asString(data['EventLocation']) ??
        _asString(normalized['location']) ??
        _asString(data['Location']);
    final eventDate =
        _asString(normalized['eventdate']) ??
        _asString(data['EventDate']) ??
        _asString(normalized['date']) ??
        _asString(data['Date']);
    final eventImageUrl =
        _asString(normalized['eventimageurl']) ??
        _asString(data['EventImageUrl']) ??
        _asString(normalized['imageurl']) ??
        _asString(data['ImageUrl']);
    final eventName =
        _asString(normalized['eventname']) ??
        _asString(data['EventName']) ??
        _asString(normalized['name']) ??
        _asString(data['Name']);
    final eventCategory =
        _asString(normalized['eventcategory']) ??
        _asString(data['EventCategory']) ??
        _asString(normalized['category']) ??
        _asString(data['Category']);
    final organizerId =
        _asString(normalized['organizerid']) ??
        _asString(data['OrganizerId']) ??
        _asString(normalized['organizerid']) ??
        _asString(data['OrganizerID']);
    final organizerName =
        _asString(normalized['organizername']) ??
        _asString(data['OrganizerName']) ??
        _asString(normalized['organizer']) ??
        _asString(data['Organizer']);
    final seatEnabled =
        (normalized['seatselectionenabled'] as bool?) ??
        (data['SeatSelectionEnabled'] as bool?) ??
        false;
    final ticketTotal =
        _asInt(normalized['tickettotal']) ?? _asInt(data['TicketTotal']);
    final ticketsRemaining =
        _asInt(normalized['ticketsremaining']) ??
        _asInt(data['TicketsRemaining']);
    final ticketsSold =
        _asInt(normalized['ticketssold']) ??
        _asInt(data['TicketsSold']) ??
        (ticketTotal != null && ticketsRemaining != null
            ? (ticketTotal - ticketsRemaining)
            : null);
    final seatIdsRaw =
        (normalized['seatids'] ?? data['SeatIds']) as List<dynamic>?;
    final seatIds =
        seatIdsRaw
            ?.map((item) => item.toString())
            .where((value) => value.trim().isNotEmpty)
            .toList() ??
        <String>[];
    final seatTypesRaw =
        (normalized['seattypes'] ?? data['SeatTypes']) as List<dynamic>?;
    var seatTypes =
        seatTypesRaw
            ?.map((item) => item.toString())
            .where((value) => value.trim().isNotEmpty)
            .toList() ??
        <String>[];
    if (seatTypes.isEmpty && seatIds.isNotEmpty) {
      seatTypes = seatIds.map(_seatTypeForSeatId).toList();
    }
    final seatCount =
        _asInt(normalized['seatcount'] ?? data['SeatCount']) ??
        (seatIds.isNotEmpty ? seatIds.length : 1);
    final status =
        _asString(normalized['status']) ??
        _asString(data['Status']) ??
        'ACTIVE';

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
      description:
          _asString(normalized['eventdescription']) ??
          _asString(data['EventDescription']) ??
          '',
      imageUrl: eventImageUrl ?? _fallbackImageUrl,
      organizerId: organizerId ?? '',
      organizerName: organizerName ?? '',
      ticketTotal: ticketTotal,
      ticketsRemaining: ticketsRemaining,
      ticketsSold: ticketsSold,
      seatSelectionEnabled: seatEnabled,
    );
    return TicketModel(
      ticketId:
          _asString(normalized['ticketid']) ??
          _asString(data['TicketId']) ??
          doc.id,
      purchaseDate:
          _asString(normalized['purchasedate']) ??
          _asString(data['PurchaseDate']) ??
          '',
      event: event,
      seatIds: seatIds,
      seatTypes: seatTypes,
      seatCount: seatCount,
      status: status,
    );
  }

  PaymentRecord? _paymentFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    if (data == null) {
      return null;
    }
    final normalized = _normalizedKeys(data);
    final paymentId =
        _asString(normalized['paymentid']) ??
        _asString(data['PaymentId']) ??
        doc.id;
    final eventId =
        _asString(normalized['eventid']) ?? _asString(data['EventId']) ?? '';
    if (eventId.isEmpty) {
      return null;
    }
    final eventName =
        _asString(normalized['eventname']) ??
        _asString(data['EventName']) ??
        'Event';
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

  Timestamp? _asTimestamp(dynamic value) {
    if (value is Timestamp) {
      return value;
    }
    return null;
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

  int? _remainingTickets(EventModel event) {
    final total = event.ticketTotal;
    if (total == null) {
      return null;
    }
    final sold =
        event.ticketsSold ??
        (event.ticketsRemaining != null ? total - event.ticketsRemaining! : 0);
    final remaining = total - sold;
    return remaining < 0 ? 0 : remaining;
  }

  String _seatDocId(String eventId, String seatId) {
    return '${eventId}_$seatId';
  }

  Future<DocumentReference<Map<String, dynamic>>?> _seatRefForId(
    String eventId,
    String seatId,
  ) async {
    var seatRef = _eventSeatsRef.doc(_seatDocId(eventId, seatId));
    final snapshot = await seatRef.get();
    if (snapshot.exists) {
      return seatRef;
    }
    final querySnapshot =
        await _eventSeatsRef
            .where('EventId', isEqualTo: eventId)
            .where('SeatId', isEqualTo: seatId)
            .limit(1)
            .get();
    if (querySnapshot.docs.isEmpty) {
      return null;
    }
    seatRef = querySnapshot.docs.first.reference;
    return seatRef;
  }

  int _compareSeats(EventSeat a, EventSeat b) {
    final rowA = a.seatId.isNotEmpty ? a.seatId[0] : 'Z';
    final rowB = b.seatId.isNotEmpty ? b.seatId[0] : 'Z';
    if (rowA != rowB) {
      return rowA.compareTo(rowB);
    }
    final colA = int.tryParse(a.seatId.substring(1)) ?? 0;
    final colB = int.tryParse(b.seatId.substring(1)) ?? 0;
    return colA.compareTo(colB);
  }

  double _seatPriceForType(EventModel event, String type) {
    final base = event.price;
    if (base <= 0) {
      return 0;
    }
    final option = _seatTypeOptions.firstWhere(
      (item) => item.type == type,
      orElse: () => const SeatTypeOption(type: 'Standard', priceDelta: 0),
    );
    return (base + option.priceDelta).clamp(0, 999999);
  }

  List<String> _seatRowsForCount(int count, {int perRow = 6}) {
    final totalRows = (count / perRow).ceil();
    final rows = <String>[];
    for (var i = 0; i < totalRows && i < 26; i++) {
      rows.add(String.fromCharCode('A'.codeUnitAt(0) + i));
    }
    return rows;
  }

  List<String> _seatIdsForTotal(int totalSeats, {int perRow = 6}) {
    final rows = _seatRowsForCount(totalSeats, perRow: perRow);
    final seatIds = <String>[];
    for (final row in rows) {
      for (var col = 1; col <= perRow; col++) {
        if (seatIds.length >= totalSeats) {
          break;
        }
        seatIds.add('$row$col');
      }
    }
    return seatIds;
  }

  String _seatTypeForRow(String row) {
    switch (row) {
      case 'A':
        return 'VIP';
      case 'B':
      case 'C':
        return 'Premium';
      default:
        return 'Standard';
    }
  }

  String _seatTypeForSeatId(String seatId) {
    final trimmed = seatId.trim();
    if (trimmed.isEmpty) {
      return 'Standard';
    }
    final row = trimmed.substring(0, 1).toUpperCase();
    return _seatTypeForRow(row);
  }

  Future<void> _ensureSeatInventory(EventModel event) async {
    try {
      final totalSeats = event.ticketTotal ?? event.ticketsRemaining ?? 0;
      if (totalSeats <= 0) {
        return;
      }
      final existingSnapshot =
          await _eventSeatsRef.where('EventId', isEqualTo: event.id).get();
      final existingSeats = existingSnapshot.docs;
      final existingIds =
          existingSeats
              .map((doc) {
                final data = doc.data();
                final normalized = _normalizedKeys(data);
                return _asString(normalized['seatid']) ??
                    _asString(data['SeatId']);
              })
              .whereType<String>()
              .toSet();
      final targetSeatIds = _seatIdsForTotal(totalSeats).toSet();

      final batch = FirebaseFirestore.instance.batch();
      var created = 0;
      var deleted = 0;

      // Delete extra AVAILABLE seats when total decreases.
      for (final doc in existingSeats) {
        final data = doc.data();
        final seatId = data['SeatId']?.toString();
        if (seatId == null || targetSeatIds.contains(seatId)) {
          continue;
        }
        final normalized = _normalizedKeys(data);
        final status =
            _asString(normalized['status']) ??
            _asString(data['Status']) ??
            'AVAILABLE';
        if (status == 'AVAILABLE') {
          batch.delete(doc.reference);
          deleted += 1;
        }
      }

      // Create missing seats when total increases.
      for (final seatId in targetSeatIds) {
        if (existingIds.contains(seatId)) {
          continue;
        }
        final row = seatId.substring(0, 1);
        final type = _seatTypeForRow(row);
        final price = _seatPriceForType(event, type);
        final docId = _seatDocId(event.id, seatId);
        batch.set(_eventSeatsRef.doc(docId), {
          'EventId': event.id,
          'SeatId': seatId,
          'SeatType': type,
          'Price': price,
          'Status': 'AVAILABLE',
          'HeldBy': null,
          'HeldUntil': null,
          'UpdatedAt': FieldValue.serverTimestamp(),
        });
        created += 1;
      }

      if (created > 0 || deleted > 0) {
        await batch.commit();
      }
    } catch (_) {
      // Best effort: seat inventory will be created on demand.
    }
  }

  bool _isSeatHeldByOther(EventSeat seat) {
    final status = seat.status.toUpperCase();
    if (status != 'HELD') {
      return false;
    }
    final heldUntil = seat.heldUntil;
    if (heldUntil == null) {
      return false;
    }
    if (heldUntil.isBefore(DateTime.now())) {
      return false;
    }
    final heldBy = seat.heldBy;
    if (heldBy == null || heldBy.trim().isEmpty) {
      return false;
    }
    final currentUser = _currentUserId ?? 'guest';
    return heldBy != currentUser;
  }

  bool _isSeatSold(EventSeat seat) =>
      seat.status.trim().toUpperCase() == 'SOLD';

  Future<void> _openSeatSelection(EventModel event) async {
    if (event.ticketTotal == null || event.ticketTotal! <= 0) {
      _showNotification(
        'Please set total tickets before enabling seat selection.',
        isError: true,
      );
      return;
    }
    setState(() {
      _seatSelectionEvent = event;
      _selectedSeatIds.clear();
      _pendingSeatIds = [];
      _pendingSeatTotal = null;
      _view = EventView.seatSelection;
    });
    await _ensureSeatInventory(event);
  }

  Future<void> _exitSeatSelection() async {
    final event = _seatSelectionEvent;
    final seatIds = _selectedSeatIds.toList();
    setState(() {
      _seatSelectionEvent = null;
      _selectedSeatIds.clear();
      _view = EventView.detail;
    });
    if (event != null && seatIds.isNotEmpty) {
      await _releaseSeatHolds(event.id, seatIds);
    }
  }

  Future<void> _toggleSeatSelection(EventSeat seat) async {
    if (_isSeatSold(seat) || _isSeatHeldByOther(seat)) {
      _showNotification('Seat is not available.', isError: true);
      return;
    }
    if (_selectedSeatIds.contains(seat.seatId)) {
      final released = await _releaseSeat(seat);
      if (released && mounted) {
        setState(() => _selectedSeatIds.remove(seat.seatId));
      }
      return;
    }
    final held = await _holdSeat(seat);
    if (held && mounted) {
      setState(() => _selectedSeatIds.add(seat.seatId));
    } else {
      _showNotification('Seat was taken by another user.', isError: true);
    }
  }

  Future<bool> _holdSeat(EventSeat seat) async {
    if (_isSeatSold(seat)) {
      return false;
    }
    final currentUser = _currentUserId ?? 'guest';
    final holdUntil = Timestamp.fromDate(DateTime.now().add(_seatHoldDuration));
    final seatRef = _eventSeatsRef.doc(seat.docId);
    try {
      return await FirebaseFirestore.instance.runTransaction<bool>((
        transaction,
      ) async {
        final snapshot = await transaction.get(seatRef);
        final data = snapshot.data();
        if (data == null) {
          return false;
        }
        final normalized = _normalizedKeys(data);
        final status =
            (_asString(normalized['status']) ??
                    _asString(data['Status']) ??
                    'AVAILABLE')
                .trim()
                .toUpperCase();
        if (status == 'SOLD') {
          return false;
        }
        if (status == 'HELD') {
          final heldBy =
              _asString(normalized['heldby']) ?? _asString(data['HeldBy']);
          final heldUntil =
              _asTimestamp(
                normalized['helduntil'] ?? data['HeldUntil'],
              )?.toDate();
          if (heldUntil != null &&
              heldUntil.isAfter(DateTime.now()) &&
              heldBy != null &&
              heldBy.isNotEmpty &&
              heldBy != currentUser) {
            return false;
          }
        }
        transaction.update(seatRef, {
          'Status': 'HELD',
          'HeldBy': currentUser,
          'HeldUntil': holdUntil,
          'UpdatedAt': FieldValue.serverTimestamp(),
        });
        return true;
      });
    } catch (_) {
      return false;
    }
  }

  Future<bool> _releaseSeat(EventSeat seat) async {
    final currentUser = _currentUserId ?? 'guest';
    final seatRef = _eventSeatsRef.doc(seat.docId);
    try {
      return await FirebaseFirestore.instance.runTransaction<bool>((
        transaction,
      ) async {
        final snapshot = await transaction.get(seatRef);
        final data = snapshot.data();
        if (data == null) {
          return false;
        }
        final normalized = _normalizedKeys(data);
        final status =
            (_asString(normalized['status']) ??
                    _asString(data['Status']) ??
                    'AVAILABLE')
                .trim()
                .toUpperCase();
        if (status == 'SOLD') {
          return false;
        }
        final heldBy =
            _asString(normalized['heldby']) ?? _asString(data['HeldBy']);
        if (status == 'HELD' &&
            heldBy != null &&
            heldBy.isNotEmpty &&
            heldBy != currentUser) {
          return false;
        }
        transaction.update(seatRef, {
          'Status': 'AVAILABLE',
          'HeldBy': null,
          'HeldUntil': null,
          'UpdatedAt': FieldValue.serverTimestamp(),
        });
        return true;
      });
    } catch (_) {
      return false;
    }
  }

  Future<void> _releaseSeatHolds(String eventId, List<String> seatIds) async {
    if (seatIds.isEmpty) {
      return;
    }
    final currentUser = _currentUserId ?? 'guest';
    for (final seatId in seatIds) {
      try {
        final seatRef = await _seatRefForId(eventId, seatId);
        if (seatRef == null) {
          continue;
        }
        final snapshot = await seatRef.get();
        final data = snapshot.data();
        if (data == null) {
          continue;
        }
        final normalized = _normalizedKeys(data);
        final status =
            (_asString(normalized['status']) ??
                    _asString(data['Status']) ??
                    'AVAILABLE')
                .toUpperCase();
        final heldBy =
            _asString(normalized['heldby']) ?? _asString(data['HeldBy']);
        if (status == 'SOLD') {
          continue;
        }
        if (status == 'HELD' &&
            heldBy != null &&
            heldBy.isNotEmpty &&
            heldBy != currentUser) {
          continue;
        }
        await seatRef.update({
          'Status': 'AVAILABLE',
          'HeldBy': null,
          'HeldUntil': null,
          'UpdatedAt': FieldValue.serverTimestamp(),
          'ReleasedBy': currentUser,
        });
      } catch (_) {
        // Ignore individual release failures.
      }
    }
  }

  double _totalForSelectedSeats(List<EventSeat> seats) {
    var total = 0.0;
    for (final seat in seats) {
      if (_selectedSeatIds.contains(seat.seatId)) {
        total += seat.price;
      }
    }
    return total;
  }

  Future<List<String>> _fetchAvailableSeatIds(String eventId, int count) async {
    if (count <= 0) {
      return [];
    }
    try {
      final snapshot =
          await _eventSeatsRef
              .where('EventId', isEqualTo: eventId)
              .where('Status', isEqualTo: 'AVAILABLE')
              .limit(count)
              .get();
      return snapshot.docs
          .map((doc) => doc.data()['SeatId']?.toString())
          .whereType<String>()
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _confirmSeatSelection(List<EventSeat> seats) async {
    final event = _seatSelectionEvent;
    if (event == null) {
      return;
    }
    if (_selectedSeatIds.isEmpty) {
      _showNotification('Select at least one seat.', isError: true);
      return;
    }
    if (_isFinalizingSeatSelection) {
      return;
    }
    setState(() => _isFinalizingSeatSelection = true);
    final total = _totalForSelectedSeats(seats);
    final selected = _selectedSeatIds.toList();
    debugPrint('🎫 _confirmSeatSelection: selected seats = $selected');
    final selectedSeats =
        seats.where((seat) => _selectedSeatIds.contains(seat.seatId)).toList();
    final refreshed = await _refreshSeatHolds(selectedSeats);
    if (!refreshed) {
      if (mounted) {
        setState(() => _isFinalizingSeatSelection = false);
      }
      _showNotification(
        'Selected seats are no longer available.',
        isError: true,
      );
      return;
    }
    setState(() {
      _pendingSeatIds = selected;
      _pendingSeatTotal = total;
      _pendingSeatEventId = event.id;
    });
    debugPrint('🎫 _confirmSeatSelection: _pendingSeatIds = $_pendingSeatIds');
    try {
      if (total > 0) {
        await _startPayPalCheckout(event, amount: total);
      } else {
        await _confirmTicketPurchase(
          event,
          seatIds: selected,
          totalAmount: total,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isFinalizingSeatSelection = false);
      }
    }
  }

  Future<WebViewController> _initializePayPalWebView(String approvalUrl) async {
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
          ..loadRequest(Uri.parse(approvalUrl));
    return controller;
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

  Future<void> _sendEventReceiptEmail({
    required EventModel event,
    required String paymentId,
    required double amount,
    String? payerEmail,
  }) async {
    final email = (_auth.currentUser?.email ?? payerEmail ?? '').trim();
    if (email.isEmpty) {
      return;
    }
    final rows = <String>[
      '<tr><td>Event</td><td>${_escapeHtml(event.name)}</td></tr>',
      if (event.date.isNotEmpty)
        '<tr><td>Event Date</td><td>${_escapeHtml(event.date)}</td></tr>',
      if (event.location.isNotEmpty)
        '<tr><td>Event Location</td><td>${_escapeHtml(event.location)}</td></tr>',
      '<tr><td>Payment ID</td><td>${_escapeHtml(paymentId)}</td></tr>',
      '<tr><td>Total Paid</td><td>MYR ${amount.toStringAsFixed(2)}</td></tr>',
    ];
    final html = '''
<h2>Event Payment Receipt</h2>
<p>Thank you for your payment. Here are your receipt details:</p>
<table cellpadding="6" cellspacing="0" border="1">
${rows.join()}
</table>
''';
    final text =
        'Receipt for ${event.name}. '
        'Payment ID: $paymentId. Total: MYR ${amount.toStringAsFixed(2)}.';
    await _sendEmailViaEmailJs(
      to: email,
      subject: 'Event Payment Receipt',
      html: html,
      text: text,
    );
  }

  Future<void> _sendEventCancellationEmail({
    required EventModel event,
    required String ticketId,
    String? payerEmail,
  }) async {
    final email = (_auth.currentUser?.email ?? payerEmail ?? '').trim();
    if (email.isEmpty) {
      return;
    }
    final rows = <String>[
      '<tr><td>Event</td><td>${_escapeHtml(event.name)}</td></tr>',
      if (event.date.isNotEmpty)
        '<tr><td>Event Date</td><td>${_escapeHtml(event.date)}</td></tr>',
      if (event.location.isNotEmpty)
        '<tr><td>Event Location</td><td>${_escapeHtml(event.location)}</td></tr>',
      '<tr><td>Ticket ID</td><td>${_escapeHtml(ticketId)}</td></tr>',
    ];
    final html = '''
<h2>Ticket Cancellation</h2>
<p>Your ticket has been cancelled. If eligible, a refund will be processed.</p>
<table cellpadding="6" cellspacing="0" border="1">
${rows.join()}
</table>
''';
    final text =
        'Your ticket for ${event.name} has been cancelled. '
        'Ticket ID: $ticketId.';
    await _sendEmailViaEmailJs(
      to: email,
      subject: 'Ticket Cancellation Confirmation',
      html: html,
      text: text,
    );
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
      final matchesSearch =
          event.name.toLowerCase().contains(query) ||
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

  void _exitToMainMenu() {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
      return;
    }
    _selectView(EventView.auth);
  }

  void _loginAsTraveler() {
    final name = _travelerDisplayName();
    setState(() {
      _currentUserRole = 'traveler';
      _currentUserId = _auth.currentUser?.uid ?? 'traveler';
      _currentUserName = name;
      _view = EventView.explore;
    });
    _showNotification('Logged in as $name.');
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
      final secondaryAuth = await getSecondaryAuth();
      _secondaryAuth = secondaryAuth;
      final credential = await secondaryAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = credential.user;
      if (user == null) {
        throw FirebaseAuthException(code: 'user-not-found');
      }
      final organizerProfile = await _organizersRef.doc(user.uid).get();
      final profileData = organizerProfile.data();
      final profileName = _asString(profileData?['name'])?.trim();
      final displayName = user.displayName?.trim();
      final derivedName =
          (profileName != null && profileName.isNotEmpty)
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
      _showNotification('Unable to sign in. Please try again.', isError: true);
    }
  }

  void _logout() {
    _secondaryAuth?.signOut();
    setState(() {
      _currentUserRole = null;
      _currentUserId = null;
      _currentUserName = 'Guest';
      _selectedEvent = null;
      _seatSelectionEvent = null;
      _selectedSeatIds.clear();
      _pendingSeatIds = [];
      _pendingSeatTotal = null;
      _pendingSeatEventId = null;
      _view = EventView.auth;
    });
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
      _showNotification(
        'You already have a ticket for this event.',
        isError: true,
      );
      return;
    }
    final remaining = _remainingTickets(event);
    if (remaining != null && remaining <= 0) {
      _showNotification('This event is sold out.', isError: true);
      return;
    }
    if (event.seatSelectionEnabled) {
      await _openSeatSelection(event);
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
    bool sendReceipt = false,
    List<String> seatIds = const [],
    double? totalAmount,
  }) async {
    debugPrint('🎫 _confirmTicketPurchase: received seatIds = $seatIds');
    debugPrint(
      '🎫 _confirmTicketPurchase: event.seatSelectionEnabled = ${event.seatSelectionEnabled}',
    );
    var seatAssignmentPending = false;
    var resolvedSeatIds = seatIds;
    debugPrint(
      '🎫 _confirmTicketPurchase: initial resolvedSeatIds = $resolvedSeatIds',
    );
    if (event.seatSelectionEnabled && resolvedSeatIds.isEmpty) {
      resolvedSeatIds = await _fetchAvailableSeatIds(event.id, 1);
      if (resolvedSeatIds.isEmpty) {
        _showNotification(
          'Unable to reserve seat. Payment captured; please contact support.',
          isError: true,
        );
        return;
      }
      if (paymentId != null && paymentId.trim().isNotEmpty) {
        await _paymentsRef.doc(paymentId).set({
          'SeatIds': resolvedSeatIds,
          'SeatEventId': event.id,
        }, SetOptions(merge: true));
      }
    }
    final seatCount = resolvedSeatIds.isEmpty ? 1 : resolvedSeatIds.length;
    debugPrint(
      '🎫 _confirmTicketPurchase: attempting to reserve seatCount=$seatCount, resolvedSeatIds=$resolvedSeatIds',
    );
    var reserved = await _reserveTickets(event.id, seatCount, resolvedSeatIds);
    debugPrint('🎫 _confirmTicketPurchase: reservation result = $reserved');
    if (!reserved) {
      if (resolvedSeatIds.isNotEmpty) {
        await _releaseSeatHolds(event.id, resolvedSeatIds);
      }
      if (event.seatSelectionEnabled &&
          paymentId != null &&
          paymentId.trim().isNotEmpty) {
        final fallbackSeatIds = await _fetchAvailableSeatIds(
          event.id,
          seatCount,
        );
        if (fallbackSeatIds.length == seatCount) {
          final fallbackReserved = await _reserveTickets(
            event.id,
            seatCount,
            fallbackSeatIds,
          );
          if (fallbackReserved) {
            resolvedSeatIds = fallbackSeatIds;
            await _paymentsRef.doc(paymentId).set({
              'SeatIds': resolvedSeatIds,
              'SeatEventId': event.id,
            }, SetOptions(merge: true));
            reserved = true;
            _showNotification(
              'Selected seats were unavailable. New seats assigned.',
            );
          }
        }
      }
      if (!reserved &&
          event.seatSelectionEnabled &&
          paymentId != null &&
          paymentId.trim().isNotEmpty) {
        final pendingReserved = await _reserveTickets(
          event.id,
          seatCount,
          const [],
        );
        if (pendingReserved) {
          resolvedSeatIds = [];
          seatAssignmentPending = true;
          await _paymentsRef.doc(paymentId).set({
            'SeatIds': [],
            'SeatEventId': event.id,
            'SeatAssignmentStatus': 'PENDING',
          }, SetOptions(merge: true));
          reserved = true;
          _showNotification('Payment captured. Seat assignment pending.');
        }
      }
      if (!reserved) {
        _showNotification(
          event.seatSelectionEnabled
              ? (paymentId != null && paymentId.trim().isNotEmpty
                  ? 'Payment captured; seats are no longer available.'
                  : 'Selected seats are no longer available.')
              : 'This event is sold out.',
          isError: true,
        );
        return;
      }
    }
    final ticketId = _generateTicketId();
    final purchaseDate = DateTime.now().toLocal().toString().split(' ').first;
    final total =
        totalAmount ??
        (resolvedSeatIds.isEmpty ? event.price : (event.price * seatCount));
    final ticketStatus = seatAssignmentPending ? 'PENDING_SEAT' : 'ACTIVE';
    final seatTypes = resolvedSeatIds.map(_seatTypeForSeatId).toList();
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
      'Price': total,
      'SeatIds': resolvedSeatIds,
      'SeatTypes': seatTypes,
      'SeatCount': seatCount,
      'PaymentId': paymentId,
      'PayerEmail': payerEmail,
      'Status': ticketStatus,
      'CreatedAt': FieldValue.serverTimestamp(),
    };
    try {
      await _ticketsRef.doc(ticketId).set(ticketData);
    } catch (_) {
      _showNotification(
        'Failed to save ticket. Please try again.',
        isError: true,
      );
      return;
    }
    if (!seatAssignmentPending && event.seatSelectionEnabled) {
      await _finalizeSeatAssignment(
        event: event,
        ticketId: ticketId,
        seatCount: seatCount,
        preferredSeatIds: resolvedSeatIds,
        paymentId: paymentId,
      );
    }
    setState(() {
      _tickets.add(
        TicketModel(
          ticketId: ticketId,
          purchaseDate: purchaseDate,
          event: event,
          seatIds: resolvedSeatIds,
          seatTypes: seatTypes,
          seatCount: seatCount,
          status: ticketStatus,
        ),
      );
      _view = EventView.tickets;
    });
    setState(() {
      _selectedSeatIds.clear();
      _pendingSeatIds = [];
      _pendingSeatTotal = null;
      _pendingSeatEventId = null;
    });
    if (sendReceipt && paymentId != null && paymentId.trim().isNotEmpty) {
      try {
        await _sendEventReceiptEmail(
          event: event,
          paymentId: paymentId,
          amount: total,
          payerEmail: payerEmail,
        );
      } catch (_) {
        // Ignore email failures.
      }
    }
    _showNotification('Successfully joined ${event.name}!');
  }

  Future<bool> _reserveTickets(
    String eventId,
    int count,
    List<String> seatIds,
  ) async {
    debugPrint(
      '🎫 _reserveTickets: eventId=$eventId, count=$count, seatIds=$seatIds',
    );
    final eventRef = _eventsRef.doc(eventId);
    final seatRefs = <String, DocumentReference<Map<String, dynamic>>>{};
    if (seatIds.isNotEmpty) {
      for (final seatId in seatIds) {
        final seatRef = await _seatRefForId(eventId, seatId);
        if (seatRef == null) {
          debugPrint('🎫 _reserveTickets: seatRef is null for seatId=$seatId');
          return false;
        }
        seatRefs[seatId] = seatRef;
      }
      debugPrint('🎫 _reserveTickets: successfully found all seat refs');
    }
    try {
      return await FirebaseFirestore.instance.runTransaction<bool>((
        transaction,
      ) async {
        // CRITICAL: Read ALL documents first before any writes
        final snapshot = await transaction.get(eventRef);
        final data = snapshot.data();
        if (data == null) {
          return false;
        }

        // Read all seat documents first
        final seatSnapshots = <String, Map<String, dynamic>>{};
        for (final seatId in seatIds) {
          final seatRef = seatRefs[seatId];
          if (seatRef == null) {
            debugPrint(
              '🎫 _reserveTickets: seatRef is null in transaction for seatId=$seatId',
            );
            return false;
          }
          final seatSnap = await transaction.get(seatRef);
          final seatData = seatSnap.data();
          if (seatData == null) {
            debugPrint(
              '🎫 _reserveTickets: seatData is null for seatId=$seatId',
            );
            return false;
          }
          seatSnapshots[seatId] = seatData;
        }

        // Now validate all reads before any writes
        final normalized = _normalizedKeys(data);
        final total =
            _asInt(normalized['tickettotal']) ??
            _asInt(data['TicketTotal']) ??
            _asInt(normalized['totaltickets']) ??
            _asInt(data['TotalTickets']);
        final remaining =
            _asInt(normalized['ticketsremaining']) ??
            _asInt(data['TicketsRemaining']) ??
            _asInt(normalized['remainingtickets']) ??
            _asInt(data['RemainingTickets']);
        final sold =
            _asInt(normalized['ticketssold']) ??
            _asInt(data['TicketsSold']) ??
            (total != null && remaining != null ? (total - remaining) : 0);
        if (total != null) {
          final nextRemaining = total - sold - count;
          if (nextRemaining < 0) {
            return false;
          }
        }

        // Validate all seats are available
        for (final entry in seatSnapshots.entries) {
          final seatId = entry.key;
          final seatData = entry.value;
          final seatNormalized = _normalizedKeys(seatData);
          final status =
              (_asString(seatNormalized['status']) ??
                      _asString(seatData['Status']) ??
                      'AVAILABLE')
                  .toUpperCase();
          debugPrint('🎫 _reserveTickets: seatId=$seatId, status=$status');
          if (status == 'SOLD') {
            debugPrint(
              '🎫 _reserveTickets: seat is already SOLD, returning false',
            );
            return false;
          }
        }

        // All reads complete and validated - now perform all writes
        if (total != null) {
          final nextRemaining = total - sold - count;
          transaction.update(eventRef, {
            'TicketsSold': sold + count,
            'TicketsRemaining': nextRemaining,
          });
        }

        for (final seatId in seatIds) {
          final seatRef = seatRefs[seatId];
          if (seatRef != null) {
            transaction.update(seatRef, {
              'Status': 'SOLD',
              'HeldBy': null,
              'HeldUntil': null,
              'UpdatedAt': FieldValue.serverTimestamp(),
            });
            debugPrint('🎫 _reserveTickets: marked seatId=$seatId as SOLD');
          }
        }
        debugPrint(
          '🎫 _reserveTickets: transaction successful, returning true',
        );
        return true;
      });
    } catch (e) {
      debugPrint('🎫 _reserveTickets: transaction failed with error: $e');
      return false;
    }
  }

  Future<bool> _refreshSeatHolds(List<EventSeat> seats) async {
    if (seats.isEmpty) {
      return true;
    }
    final seatIds = seats.map((seat) => seat.seatId).toList();
    for (final seat in seats) {
      final held = await _holdSeat(seat);
      if (!held) {
        await _releaseSeatHolds(seat.eventId, seatIds);
        return false;
      }
    }
    return true;
  }

  Future<void> _markSeatsSold(String eventId, List<String> seatIds) async {
    if (seatIds.isEmpty) {
      return;
    }
    for (final seatId in seatIds) {
      try {
        final seatRef = await _seatRefForId(eventId, seatId);
        if (seatRef == null) {
          continue;
        }
        await seatRef.update({
          'Status': 'SOLD',
          'HeldBy': null,
          'HeldUntil': null,
          'UpdatedAt': FieldValue.serverTimestamp(),
        });
      } catch (_) {
        // Ignore individual seat update failures.
      }
    }
  }

  Future<void> _finalizeSeatAssignment({
    required EventModel event,
    required String ticketId,
    required int seatCount,
    List<String> preferredSeatIds = const [],
    String? paymentId,
  }) async {
    var resolvedSeatIds =
        preferredSeatIds.where((value) => value.trim().isNotEmpty).toList();
    String seatEventId = event.id;

    if (resolvedSeatIds.isEmpty && paymentId != null && paymentId.isNotEmpty) {
      try {
        final paymentDoc = await _paymentsRef.doc(paymentId).get();
        final raw = paymentDoc.data() ?? <String, dynamic>{};
        final normalized = _normalizedKeys(raw);
        final seatIdsRaw =
            (normalized['seatids'] ?? raw['SeatIds']) as List<dynamic>?;
        resolvedSeatIds =
            seatIdsRaw
                ?.map((item) => item.toString())
                .where((value) => value.trim().isNotEmpty)
                .toList() ??
            <String>[];
        seatEventId =
            _asString(normalized['seateventid']) ??
            _asString(raw['SeatEventId']) ??
            seatEventId;
      } catch (_) {
        // Ignore payment doc failures.
      }
    }

    if (resolvedSeatIds.isEmpty) {
      final currentUser = _currentUserId ?? 'guest';
      try {
        final heldSnapshot =
            await _eventSeatsRef
                .where('EventId', isEqualTo: seatEventId)
                .where('Status', isEqualTo: 'HELD')
                .where('HeldBy', isEqualTo: currentUser)
                .limit(seatCount)
                .get();
        resolvedSeatIds =
            heldSnapshot.docs
                .map((doc) {
                  final data = doc.data();
                  final normalized = _normalizedKeys(data);
                  return _asString(normalized['seatid']) ??
                      _asString(data['SeatId']);
                })
                .whereType<String>()
                .where((value) => value.trim().isNotEmpty)
                .toList();
      } catch (_) {
        // Ignore held seat lookup failures.
      }
    }

    if (resolvedSeatIds.isEmpty) {
      resolvedSeatIds = await _fetchAvailableSeatIds(seatEventId, seatCount);
    }

    if (resolvedSeatIds.isEmpty) {
      return;
    }

    final seatTypes = resolvedSeatIds.map(_seatTypeForSeatId).toList();
    await _ticketsRef.doc(ticketId).set({
      'SeatIds': resolvedSeatIds,
      'SeatTypes': seatTypes,
      'SeatCount': resolvedSeatIds.length,
      'Status': 'ACTIVE',
    }, SetOptions(merge: true));
    await _markSeatsSold(seatEventId, resolvedSeatIds);
  }

  void _clearHeldSeatStatus(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    if (data == null) {
      return;
    }
    final normalized = _normalizedKeys(data);
    final status =
        (_asString(normalized['status']) ?? _asString(data['Status']) ?? '')
            .trim()
            .toUpperCase();
    if (status != 'HELD') {
      return;
    }
    final heldUntil =
        _asTimestamp(normalized['helduntil'] ?? data['HeldUntil'])?.toDate();
    if (heldUntil != null && heldUntil.isAfter(DateTime.now())) {
      return;
    }
    doc.reference.update({
      'Status': 'AVAILABLE',
      'HeldBy': null,
      'HeldUntil': null,
      'UpdatedAt': FieldValue.serverTimestamp(),
      'ReleasedBy': 'system',
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

  Future<void> _startPayPalCheckout(
    EventModel event, {
    String? paymentRecordId,
    double? amount,
  }) async {
    if (_isCreatingPayment) {
      return;
    }
    setState(() {
      _pendingPaymentEvent = event;
      _paymentApprovalUrl = null;
      _paymentOrderId = null;
      _activePaymentRecordId = paymentRecordId;
      _isCreatingPayment = true;
      _paymentCompleted = false;
      _view = EventView.payment;
    });
    try {
      final checkoutAmount = amount ?? event.price;
      final response = await http.post(
        Uri.parse('$_paypalBaseUrl/createPayPalOrder'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'amount': checkoutAmount.toStringAsFixed(2),
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
      final recordId = paymentRecordId ?? orderId;
      debugPrint(
        '🎫 _startPayPalCheckout: creating payment doc with _pendingSeatIds = $_pendingSeatIds',
      );
      await _paymentsRef.doc(recordId).set({
        'PaymentId': recordId,
        'PayPalOrderId': orderId,
        'EventId': event.id,
        'EventName': event.name,
        'EventDate': event.date,
        'EventLocation': event.location,
        'UserId': _currentUserId ?? 'guest',
        'Amount': checkoutAmount,
        'Currency': 'MYR',
        'Status': 'CREATED',
        'SeatIds': _pendingSeatIds,
        'SeatEventId': _pendingSeatEventId ?? event.id,
        'CreatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      debugPrint('🎫 _startPayPalCheckout: payment doc created');
      if (!mounted) {
        return;
      }
      setState(() {
        _paymentApprovalUrl = approvalUrl;
        _paymentOrderId = orderId;
        _activePaymentRecordId = recordId;
        _isCreatingPayment = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _isCreatingPayment = false;
          _view = EventView.detail;
        });
      }
      _showNotification('Unable to start PayPal checkout.', isError: true);
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
      final recordId = _activePaymentRecordId;
      List<String> seatIds = _pendingSeatIds;
      debugPrint('🎫 _capturePayPalOrder: initial seatIds = $seatIds');
      debugPrint('🎫 _capturePayPalOrder: _pendingSeatIds = $_pendingSeatIds');
      double? seatTotal = _pendingSeatTotal;
      String? seatEventId = _pendingSeatEventId;
      if (recordId != null && recordId.isNotEmpty) {
        try {
          final paymentDoc = await _paymentsRef.doc(recordId).get();
          final raw = paymentDoc.data() ?? <String, dynamic>{};
          debugPrint('🎫 _capturePayPalOrder: payment doc data = $raw');
          final normalized = _normalizedKeys(raw);
          final seatIdsRaw =
              (normalized['seatids'] ?? raw['SeatIds']) as List<dynamic>?;
          debugPrint(
            '🎫 _capturePayPalOrder: seatIdsRaw from payment doc = $seatIdsRaw',
          );
          if (seatIdsRaw != null && seatIds.isEmpty) {
            seatIds = seatIdsRaw.map((item) => item.toString()).toList();
          }
          seatEventId =
              _asString(normalized['seateventid']) ??
              _asString(raw['SeatEventId']) ??
              seatEventId;
          if (seatTotal == null) {
            seatTotal = _asDouble(normalized['amount'] ?? raw['Amount']);
          }
          debugPrint(
            '🎫 _capturePayPalOrder: final seatIds after reading payment doc = $seatIds',
          );
        } catch (_) {
          // Ignore payment doc fetch failures; fallback to local state.
        }
      }
      setState(() {
        _isCapturingPayment = false;
        _paymentApprovalUrl = null;
        _paymentOrderId = null;
        _pendingPaymentEvent = null;
        _activePaymentRecordId = null;
        _pendingSeatEventId = null;
        _paymentCompleted = true;
      });
      if (event != null) {
        EventModel? ticketEvent = event;
        if (seatEventId != null && seatEventId != event.id) {
          final fetched = await _getEventById(seatEventId);
          if (fetched != null) {
            ticketEvent = fetched;
          }
        }
        if (recordId != null && recordId.isNotEmpty) {
          await _paymentsRef.doc(recordId).set({
            'PaymentId': recordId,
            'PayPalOrderId': orderId,
            'Status': 'CAPTURED',
            'CapturedAt': FieldValue.serverTimestamp(),
            'PayerEmail': payerEmail,
          }, SetOptions(merge: true));
        }
        await _confirmTicketPurchase(
          ticketEvent,
          paymentId: recordId ?? orderId,
          payerEmail: payerEmail,
          sendReceipt: true,
          seatIds: seatIds,
          totalAmount: seatTotal,
        );
      } else {
        EventModel? fallbackEvent;
        if (seatEventId != null && seatEventId.isNotEmpty) {
          fallbackEvent = await _getEventById(seatEventId);
        }
        if (fallbackEvent == null && recordId != null) {
          try {
            final paymentDoc = await _paymentsRef.doc(recordId).get();
            final raw = paymentDoc.data() ?? <String, dynamic>{};
            final normalized = _normalizedKeys(raw);
            final eventId =
                _asString(normalized['eventid']) ?? _asString(raw['EventId']);
            if (eventId != null && eventId.isNotEmpty) {
              fallbackEvent = await _getEventById(eventId);
            }
          } catch (_) {
            // Ignore fallback failures.
          }
        }
        if (fallbackEvent != null) {
          await _confirmTicketPurchase(
            fallbackEvent,
            paymentId: recordId ?? orderId,
            payerEmail: payerEmail,
            sendReceipt: true,
            seatIds: seatIds,
            totalAmount: seatTotal,
          );
        } else {
          _showNotification('Unable to finalize ticket.', isError: true);
          _selectView(EventView.explore);
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isCapturingPayment = false);
      }
      final recordId = _activePaymentRecordId;
      if (recordId != null && recordId.isNotEmpty) {
        _paymentsRef.doc(recordId).set({
          'PaymentId': recordId,
          'PayPalOrderId': _paymentOrderId,
          'Status': 'FAILED',
          'UpdatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
      _showNotification(
        'Payment not completed. Please try again.',
        isError: true,
      );
    }
  }

  Future<void> _resumePaymentFromId(String paymentId) async {
    if (paymentId.trim().isEmpty) {
      return;
    }
    if (_isOrganizer || !_isLoggedIn) {
      _loginAsTraveler();
    }
    try {
      final doc = await _paymentsRef.doc(paymentId).get();
      if (!doc.exists) {
        _showNotification('Payment record not found.', isError: true);
        return;
      }
      final payment = _paymentFromDoc(doc);
      if (payment == null) {
        _showNotification('Unable to resume payment.', isError: true);
        return;
      }
      final raw = doc.data() ?? <String, dynamic>{};
      final normalized = _normalizedKeys(raw);
      final seatIdsRaw =
          (normalized['seatids'] ?? raw['SeatIds']) as List<dynamic>?;
      final seatIds =
          seatIdsRaw == null
              ? <String>[]
              : seatIdsRaw.map((item) => item.toString()).toList();
      setState(() {
        _pendingSeatIds = seatIds;
        _pendingSeatTotal = payment.amount;
        _pendingSeatEventId =
            _asString(normalized['seateventid']) ??
            _asString(raw['SeatEventId']) ??
            payment.eventId;
      });
      final status = payment.status.toUpperCase();
      if (status == 'CAPTURED') {
        _showNotification('Payment already completed.');
        return;
      }
      await _retryFailedPayment(payment);
    } catch (_) {
      _showNotification('Unable to resume payment.', isError: true);
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
    _startPayPalCheckout(
      event,
      paymentRecordId: payment.paymentId,
      amount: payment.amount,
    );
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
    if (_isCapturingPayment || _paymentCompleted) {
      _showNotification('Finalizing payment. Please wait.');
      return;
    }
    final recordId = _activePaymentRecordId;
    if (recordId != null && recordId.isNotEmpty) {
      _paymentsRef.doc(recordId).set({
        'PaymentId': recordId,
        'PayPalOrderId': _paymentOrderId,
        'Status': 'CANCELLED',
        'UpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
    final eventId = _pendingPaymentEvent?.id;
    final seatIds = _pendingSeatIds;
    if (eventId != null && seatIds.isNotEmpty) {
      _releaseSeatHolds(eventId, seatIds);
    }
    setState(() {
      _pendingPaymentEvent = null;
      _paymentApprovalUrl = null;
      _paymentOrderId = null;
      _activePaymentRecordId = null;
      _pendingSeatIds = [];
      _pendingSeatTotal = null;
      _pendingSeatEventId = null;
      _isCreatingPayment = false;
      _isCapturingPayment = false;
      _view = EventView.detail;
    });
    _showNotification('Payment cancelled.', isError: true);
  }

  Future<bool> _confirmCancelTicket() async {
    final result = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
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
    final eventDate = DateTime.tryParse(ticket.event.date);
    if (eventDate != null) {
      final today = DateTime.now();
      final todayOnly = DateTime(today.year, today.month, today.day);
      final eventOnly = DateTime(eventDate.year, eventDate.month, eventDate.day);
      final daysUntilEvent = eventOnly.difference(todayOnly).inDays;
      if (daysUntilEvent < 3) {
        _showNotification(
          'Cancellation is not allowed within 3 days of the event.',
          isError: true,
        );
        return;
      }
    }

    final confirmed = await _confirmCancelTicket();
    if (!confirmed) {
      return;
    }
    final ticketId = ticket.ticketId;
    try {
      final ticketDoc = await _ticketsRef.doc(ticketId).get();
      final data = ticketDoc.data();
      final normalized =
          data == null ? <String, dynamic>{} : _normalizedKeys(data);
      final paymentId =
          _asString(normalized['paymentid']) ?? _asString(data?['PaymentId']);
      final payerEmail =
          _asString(normalized['payeremail']) ?? _asString(data?['PayerEmail']);
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
          final total =
              _asInt(normalizedEvent['tickettotal']) ??
              _asInt(eventData['TicketTotal']) ??
              _asInt(normalizedEvent['totaltickets']) ??
              _asInt(eventData['TotalTickets']);
          final remaining =
              _asInt(normalizedEvent['ticketsremaining']) ??
              _asInt(eventData['TicketsRemaining']) ??
              _asInt(normalizedEvent['remainingtickets']) ??
              _asInt(eventData['RemainingTickets']);
          final sold =
              _asInt(normalizedEvent['ticketssold']) ??
              _asInt(eventData['TicketsSold']) ??
              (total != null && remaining != null ? (total - remaining) : 0);
          if (total == null) {
            return;
          }
          final nextSold = sold <= 0 ? 0 : sold - 1;
          final nextRemaining = total - nextSold;
          transaction.update(eventRef, {
            'TicketsSold': nextSold,
            'TicketsRemaining': nextRemaining,
          });
        });
      }

      if (mounted) {
        setState(() {
          _tickets.removeWhere((item) => item.ticketId == ticketId);
        });
      }
      try {
        await _sendEventCancellationEmail(
          event: ticket.event,
          ticketId: ticket.ticketId,
          payerEmail: payerEmail,
        );
      } catch (_) {
        // Ignore email failures.
      }
      _showNotification('Ticket cancelled. Refund will be processed.');
    } catch (_) {
      _showNotification(
        'Failed to cancel ticket. Please try again.',
        isError: true,
      );
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
      _editingEventTicketsSold = event.ticketsSold;
      _seatSelectionEnabled = event.seatSelectionEnabled;
      _titleController.text = event.name;
      _locationController.text = event.location;
      _priceController.text = event.price.toStringAsFixed(2);
      _descriptionController.text = event.description;
      _ticketTotalController.text =
          event.ticketTotal == null ? '' : event.ticketTotal.toString();
      _newEventCategory = event.category.isEmpty ? 'Food' : event.category;
      _newEventDate = event.date;
      _newEventImageRef =
          event.imageUrl.startsWith('http')
              ? null
              : event.imageUrl.isNotEmpty
              ? event.imageUrl
              : null;
      _newEventImageFile = null;
      _view = EventView.edit;
    });
  }

  Future<bool> _confirmDeleteEvent() async {
    final result = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete Event?'),
            content: const Text(
              'This will permanently delete the event and all associated data. '
              'This action cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Delete'),
              ),
            ],
          ),
    );
    return result ?? false;
  }

  Future<void> _deleteEvent(String eventId) async {
    // Block deletion if any tickets have already been sold for this event.
    try {
      final ticketSnapshot =
          await _ticketsRef
              .where('EventId', isEqualTo: eventId)
              .limit(1)
              .get();
      if (ticketSnapshot.docs.isNotEmpty) {
        _showNotification(
          'Cannot delete: tickets have already been sold for this event.',
          isError: true,
        );
        return;
      }
    } catch (_) {
      // If the check fails, fall through and let the confirmation dialog proceed.
    }

    final confirmed = await _confirmDeleteEvent();
    if (!confirmed) {
      return;
    }
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
    _editingEventTicketsSold = null;
    _seatSelectionEnabled = false;
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
        'email': _secondaryAuth?.currentUser?.email ?? _auth.currentUser?.email,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Denormalized update for event organizer name.
      final snapshot =
          await _eventsRef
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
    
    // Validate required fields
    final title = _titleController.text.trim();
    final location = _locationController.text.trim();
    final priceText = _priceController.text.trim();
    final ticketTotalText = _ticketTotalController.text.trim();
    
    // Check for empty required fields
    if (title.isEmpty) {
      _showNotification('Event title is required.', isError: true);
      return;
    }
    
    if (location.isEmpty) {
      _showNotification('Location is required.', isError: true);
      return;
    }
    
    if (_newEventDate.isEmpty) {
      _showNotification('Event date is required.', isError: true);
      return;
    }
    
    // Validate that title and location don't contain numbers
    if (RegExp(r'\d').hasMatch(title)) {
      _showNotification(
        'Event title should not contain numbers.',
        isError: true,
      );
      return;
    }
    
    if (RegExp(r'\d').hasMatch(location)) {
      _showNotification(
        'Location should not contain numbers.',
        isError: true,
      );
      return;
    }
    
    // Validate price field contains only numbers
    if (priceText.isNotEmpty && !RegExp(r'^[0-9.]+$').hasMatch(priceText)) {
      _showNotification(
        'Price must contain only numbers.',
        isError: true,
      );
      return;
    }
    
    // Validate total tickets contains only numbers
    if (ticketTotalText.isNotEmpty && 
        !RegExp(r'^[0-9]+$').hasMatch(ticketTotalText)) {
      _showNotification(
        'Total tickets must contain only numbers.',
        isError: true,
      );
      return;
    }

    setState(() => _isPublishing = true);
    final double price = double.tryParse(priceText) ?? 0;
    final int? ticketTotal =
        ticketTotalText.isEmpty ? null : int.tryParse(ticketTotalText);
    if (ticketTotalText.isNotEmpty && ticketTotal == null) {
      _showNotification('Total tickets must be a number.', isError: true);
      setState(() => _isPublishing = false);
      return;
    }
    if (_seatSelectionEnabled && (ticketTotal == null || ticketTotal <= 0)) {
      _showNotification(
        'Seat selection requires a total ticket count.',
        isError: true,
      );
      setState(() => _isPublishing = false);
      return;
    }
    final DateTime? parsedDate = DateTime.tryParse(_newEventDate);
    final isEditing = _editingEventId != null;
    final eventId =
        isEditing
            ? _editingEventId!
            : DateTime.now().millisecondsSinceEpoch.toString();
    final uploadedImageUrl = await _uploadEventImage(eventId);
    if (_newEventImageFile != null && uploadedImageUrl == null) {
      if (mounted) {
        setState(() => _isPublishing = false);
      }
      _showNotification(
        'Failed to upload image. Please try again.',
        isError: true,
      );
      return;
    }
    final imageRef =
        (_newEventImageRef == null || _newEventImageRef!.trim().isEmpty)
            ? (_fallbackImageRefForCategory(_newEventCategory) ??
                _defaultEventImageUrl)
            : _newEventImageRef!.trim();
    final resolvedImageUrl =
        uploadedImageUrl ?? _editingEventImageUrl ?? imageRef;
    int? ticketsRemaining;
    int ticketsSold;
    if (!isEditing) {
      ticketsSold = 0;
    } else {
      final previousTotal = _editingEventTicketTotal;
      final previousRemaining = _editingEventTicketsRemaining;
      ticketsSold =
          _editingEventTicketsSold ??
          (previousTotal != null && previousRemaining != null
              ? (previousTotal - previousRemaining)
              : 0);
    }
    if (ticketTotal != null) {
      // When editing, prevent reducing the ticket count if any have been sold.
      if (isEditing && ticketsSold > 0) {
        final previousTotal = _editingEventTicketTotal;
        if (previousTotal != null && ticketTotal < previousTotal) {
          _showNotification(
            '$ticketsSold ticket(s) already sold — you can only increase the total ticket count, not decrease it.',
            isError: true,
          );
          setState(() => _isPublishing = false);
          return;
        }
      }
      if (ticketsSold > ticketTotal) {
        _showNotification(
          'Total tickets cannot be less than tickets sold.',
          isError: true,
        );
        setState(() => _isPublishing = false);
        return;
      }
      ticketsRemaining = ticketTotal - ticketsSold;
    } else {
      ticketsRemaining = null;
    }
    final newEvent = <String, dynamic>{
      'ID': eventId,
      'Name': title,
      'Location': location,
      'Date':
          parsedDate == null ? _newEventDate : Timestamp.fromDate(parsedDate),
      'Price': price,
      'Type': _newEventCategory,
      'Description': _descriptionController.text.trim(),
      'ImageUrl': resolvedImageUrl,
      'SeatSelectionEnabled': _seatSelectionEnabled,
      if (ticketTotal != null) 'TicketsSold': ticketsSold,
      if (ticketTotal != null) 'TicketTotal': ticketTotal,
      if (ticketsRemaining != null) 'TicketsRemaining': ticketsRemaining,
      if (isEditing && ticketTotal == null) 'TicketsSold': FieldValue.delete(),
      if (isEditing && ticketTotal == null) 'TicketTotal': FieldValue.delete(),
      if (isEditing && ticketTotal == null)
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
        isEditing
            ? 'Event updated successfully!'
            : 'Event published successfully!',
      );
    } catch (error) {
      if (mounted) {
        setState(() => _isPublishing = false);
      }
      _showNotification(
        'Failed to publish event. Please try again.',
        isError: true,
      );
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
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final picked = await showDatePicker(
      context: context,
      initialDate: tomorrow,
      firstDate: tomorrow,
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
