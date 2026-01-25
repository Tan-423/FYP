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
  String? _currentUserRole;
  String? _currentUserId;
  String _currentUserName = 'Guest';

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final CollectionReference<Map<String, dynamic>> _organizersRef =
      FirebaseFirestore.instance.collection('Organizer');

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
      _titleController.text = event.name;
      _locationController.text = event.location;
      _priceController.text = event.price.toStringAsFixed(2);
      _descriptionController.text = event.description;
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
    _newEventCategory = 'Food';
    _newEventDate = '';
    _newEventImageRef = null;
    _newEventImageFile = null;
    _editingEventId = null;
    _editingEventImageUrl = null;
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
    final newEvent = <String, dynamic>{
      'ID': eventId,
      'Name': _titleController.text.trim(),
      'Location': _locationController.text.trim(),
      'Date': parsedDate == null ? _newEventDate : Timestamp.fromDate(parsedDate),
      'Price': price,
      'Type': _newEventCategory,
      'Description': _descriptionController.text.trim(),
      'ImageUrl': resolvedImageUrl,
      'OrganizerId': _currentUserId ?? 'org_wanderease',
      'OrganizerName': _currentUserName,
    };

    try {
      await _eventsRef.doc(eventId).set(newEvent);
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
