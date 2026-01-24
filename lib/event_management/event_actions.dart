part of 'event_management.dart';

mixin EventManagementActions on State<EventManagementScreen> {
  static const String _defaultEventImageUrl =
      'lib/event_management/event_image/Food Festival.webp';

  final CollectionReference<Map<String, dynamic>> _eventsRef =
      FirebaseFirestore.instance.collection('Event');

  final List<TicketModel> _tickets = [];

  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  EventView _view = EventView.explore;
  EventModel? _selectedEvent;
  String _activeCategory = 'All';
  String _newEventCategory = 'Food';
  String _newEventDate = '';
  String _notificationMessage = '';
  bool _notificationIsError = false;

  final List<String> _categories = ['All', 'Food', 'Culture', 'Music'];

  String get _fallbackImageUrl => _defaultEventImageUrl;

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
    final imageRef =
        _fallbackImageRefForCategory(category) ?? _defaultEventImageUrl;
    final name = _asString(normalized['name']) ??
        _asString(data['Name']) ??
        _asString(data['name']) ??
        '';
    final location = _asString(normalized['location']) ??
        _asString(data['Location']) ??
        _asString(data['location']) ??
        '';
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
      organizer:
          _asString(normalized['organizer']) ?? _asString(data['Organizer']) ?? '',
    );
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

  void _openEvent(EventModel event) {
    setState(() {
      _selectedEvent = event;
      _view = EventView.detail;
    });
  }

  void _joinEvent(EventModel event) {
    final alreadyJoined = _tickets.any((ticket) => ticket.event.id == event.id);
    if (alreadyJoined) {
      _showNotification('You already have a ticket for this event.',
          isError: true);
      return;
    }

    final ticketId = _generateTicketId();
    final purchaseDate =
        DateTime.now().toLocal().toString().split(' ').first;
    setState(() {
      _tickets.add(
        TicketModel(ticketId: ticketId, purchaseDate: purchaseDate, event: event),
      );
      _view = EventView.tickets;
    });
    _showNotification('Successfully joined ${event.name}!');
  }

  void _cancelTicket(String ticketId) {
    setState(() {
      _tickets.removeWhere((ticket) => ticket.ticketId == ticketId);
    });
    _showNotification('Participation cancelled successfully.');
  }

  Future<void> _publishEvent() async {
    if (_titleController.text.trim().isEmpty ||
        _locationController.text.trim().isEmpty ||
        _newEventDate.isEmpty) {
      _showNotification('Please fill in all required fields.', isError: true);
      return;
    }

    final double price = double.tryParse(_priceController.text.trim()) ?? 0;
    final DateTime? parsedDate = DateTime.tryParse(_newEventDate);
    final imageRef =
        _fallbackImageRefForCategory(_newEventCategory) ??
            _defaultEventImageUrl;
    final eventId = DateTime.now().millisecondsSinceEpoch.toString();
    final newEvent = <String, dynamic>{
      'ID': eventId,
      'Name': _titleController.text.trim(),
      'Location': _locationController.text.trim(),
      'Date': parsedDate == null ? _newEventDate : Timestamp.fromDate(parsedDate),
      'Price': price,
      'Type': _newEventCategory,
      'Description': _descriptionController.text.trim(),
      'ImageUrl': imageRef,
      'Organizer': 'WanderEase',
    };

    try {
      await _eventsRef.doc(eventId).set(newEvent);
      if (!mounted) {
        return;
      }
      setState(() {
        _titleController.clear();
        _locationController.clear();
        _priceController.clear();
        _descriptionController.clear();
        _newEventCategory = 'Food';
        _newEventDate = '';
        _view = EventView.explore;
      });
      _showNotification('Event published and now searchable!');
    } catch (error) {
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
