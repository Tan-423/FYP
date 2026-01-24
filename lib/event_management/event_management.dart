import 'dart:math';

import 'package:flutter/material.dart';

enum EventView { explore, detail, tickets, organize }

class EventModel {
  EventModel({
    required this.id,
    required this.name,
    required this.location,
    required this.date,
    required this.price,
    required this.category,
    required this.description,
    required this.imageUrl,
    required this.organizer,
  });

  final String id;
  final String name;
  final String location;
  final String date;
  final double price;
  final String category;
  final String description;
  final String imageUrl;
  final String organizer;
}

class TicketModel {
  TicketModel({
    required this.ticketId,
    required this.purchaseDate,
    required this.event,
  });

  final String ticketId;
  final String purchaseDate;
  final EventModel event;
}

class EventManagementScreen extends StatefulWidget {
  const EventManagementScreen({super.key});

  @override
  State<EventManagementScreen> createState() => _EventManagementScreenState();
}

class _EventManagementScreenState extends State<EventManagementScreen> {
  final List<EventModel> _events = [
    EventModel(
      id: '1',
      name: 'KL Food Festival 2025',
      location: 'Bukit Bintang, KL',
      date: '2025-09-15',
      price: 15.00,
      category: 'Food',
      description:
          'Experience the best of Malaysian street food in one place. Over 100 stalls featuring heritage recipes and modern fusion dishes.',
      imageUrl:
          'https://images.unsplash.com/photo-1555939594-58d7cb561ad1?auto=format&fit=crop&w=800&q=80',
      organizer: 'WanderEase',
    ),
    EventModel(
      id: '2',
      name: 'Borneo Cultural Night',
      location: 'Kuching, Sarawak',
      date: '2025-10-20',
      price: 45.00,
      category: 'Culture',
      description:
          'A magical evening of traditional dances, music, and storytelling from the diverse ethnic groups of Sarawak.',
      imageUrl:
          'https://images.unsplash.com/photo-1533174072545-7a4b6ad7a6c3?auto=format&fit=crop&w=800&q=80',
      organizer: 'Sarawak Arts',
    ),
    EventModel(
      id: '3',
      name: 'Mandopop Live Tour',
      location: 'Axiata Arena, KL',
      date: '2025-11-05',
      price: 288.00,
      category: 'Music',
      description:
          'Join the biggest stars of Asian pop for a one-night-only spectacular performance with high-tech visual effects.',
      imageUrl:
          'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?auto=format&fit=crop&w=800&q=80',
      organizer: 'Star Events',
    ),
  ];

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

  @override
  void dispose() {
    _searchController.dispose();
    _titleController.dispose();
    _locationController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
    super.dispose();
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

  void _publishEvent() {
    if (_titleController.text.trim().isEmpty ||
        _locationController.text.trim().isEmpty ||
        _newEventDate.isEmpty) {
      _showNotification('Please fill in all required fields.', isError: true);
      return;
    }

    final double price = double.tryParse(_priceController.text.trim()) ?? 0;
    final newEvent = EventModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: _titleController.text.trim(),
      location: _locationController.text.trim(),
      date: _newEventDate,
      price: price,
      category: _newEventCategory,
      description: _descriptionController.text.trim(),
      imageUrl:
          'https://images.unsplash.com/photo-1492684223066-81342ee5ff30?auto=format&fit=crop&w=800&q=80',
      organizer: 'WanderEase',
    );

    setState(() {
      _events.insert(0, newEvent);
      _titleController.clear();
      _locationController.clear();
      _priceController.clear();
      _descriptionController.clear();
      _newEventCategory = 'Food';
      _newEventDate = '';
      _view = EventView.explore;
    });

    _showNotification('Event published and now searchable!');
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

  List<EventModel> get _filteredEvents {
    final query = _searchController.text.trim().toLowerCase();
    return _events.where((event) {
      final matchesCategory =
          _activeCategory == 'All' || event.category == _activeCategory;
      final matchesSearch = event.name.toLowerCase().contains(query) ||
          event.location.toLowerCase().contains(query);
      return matchesCategory && matchesSearch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE5E7EB),
      body: SafeArea(
        child: Column(
          children: [
            _buildNotificationBar(),
            Expanded(child: _buildContent()),
            _buildBottomNav(),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationBar() {
    if (_notificationMessage.isEmpty) {
      return const SizedBox(height: 0);
    }

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _notificationIsError ? Colors.red : Colors.green,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(
            _notificationIsError ? Icons.error_outline : Icons.check_circle,
            color: Colors.white,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _notificationMessage,
              style: const TextStyle(color: Colors.white),
            ),
          ),
          IconButton(
            onPressed: () => setState(() => _notificationMessage = ''),
            icon: const Icon(Icons.close, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    switch (_view) {
      case EventView.explore:
        return _buildExploreView();
      case EventView.detail:
        return _buildDetailView();
      case EventView.tickets:
        return _buildTicketsView();
      case EventView.organize:
        return _buildOrganizeView();
    }
  }

  Widget _buildExploreView() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search events, locations...',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: const Color(0xFFF3F4F6),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (_) => setState(() {}),
          ),
        ),
        SizedBox(
          height: 44,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemBuilder: (context, index) {
              final category = _categories[index];
              final isActive = category == _activeCategory;
              return ChoiceChip(
                label: Text(category),
                selected: isActive,
                onSelected: (_) => setState(() => _activeCategory = category),
                selectedColor: Colors.blue,
                labelStyle: TextStyle(
                  color: isActive ? Colors.white : Colors.black54,
                  fontWeight: FontWeight.w600,
                ),
              );
            },
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemCount: _categories.length,
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _filteredEvents.isEmpty
              ? _buildEmptyState(
                  icon: Icons.search,
                  title: 'No events found for your criteria.',
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _filteredEvents.length,
                  itemBuilder: (context, index) {
                    final event = _filteredEvents[index];
                    return _buildEventCard(event);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildEventCard(EventModel event) {
    return GestureDetector(
      onTap: () => _openEvent(event),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Image.network(
                  event.imageUrl,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.location_on, size: 16, color: Colors.red),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          event.location,
                          style: const TextStyle(color: Colors.black54),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today,
                          size: 16, color: Colors.blue),
                      const SizedBox(width: 4),
                      Text(
                        event.date,
                        style: const TextStyle(color: Colors.black54),
                      ),
                      const Spacer(),
                      Text(
                        event.price > 0
                            ? 'RM ${event.price.toStringAsFixed(2)}'
                            : 'FREE',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailView() {
    final event = _selectedEvent;
    if (event == null) {
      return const SizedBox.shrink();
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              AspectRatio(
                aspectRatio: 16 / 9,
                child: Image.network(event.imageUrl, fit: BoxFit.cover),
              ),
              Positioned(
                top: 16,
                left: 16,
                child: CircleAvatar(
                  backgroundColor: Colors.white70,
                  child: IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: () => _selectView(EventView.explore),
                  ),
                ),
              ),
              Positioned(
                bottom: 16,
                left: 16,
                right: 16,
                child: Text(
                  event.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailRow(
                  icon: Icons.calendar_today,
                  label: 'DATE',
                  value: event.date,
                ),
                const SizedBox(height: 12),
                _buildDetailRow(
                  icon: Icons.location_on,
                  label: 'LOCATION',
                  value: event.location,
                ),
                const SizedBox(height: 16),
                const Text(
                  'About Event',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  event.description,
                  style: const TextStyle(color: Colors.black54),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Price per ticket',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        event.price > 0
                            ? 'RM ${event.price.toStringAsFixed(2)}'
                            : 'FREE',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _joinEvent(event),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(event.price > 0 ? 'Buy Ticket' : 'Register Now'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: Colors.white,
          child: Icon(icon, color: Colors.blue),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: Colors.black54,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTicketsView() {
    if (_tickets.isEmpty) {
      return _buildEmptyState(
        icon: Icons.confirmation_number,
        title: 'No Active Tickets',
        subtitle: 'Join events from the explore page to see them here.',
        actionLabel: 'Explore Events',
        onAction: () => _selectView(EventView.explore),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _tickets.length,
      itemBuilder: (context, index) {
        final ticket = _tickets[index];
        return _buildTicketCard(ticket);
      },
    );
  }

  Widget _buildTicketCard(TicketModel ticket) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ticket.event.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Joined on ${ticket.purchaseDate}',
                        style: const TextStyle(color: Colors.black54),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => _cancelTicket(ticket.ticketId),
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                ),
              ],
            ),
          ),
          _buildQrPlaceholder(ticket.ticketId),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.calendar_today, size: 16, color: Colors.blue),
                const SizedBox(width: 4),
                Text(ticket.event.date),
                const SizedBox(width: 16),
                const Icon(Icons.location_on, size: 16, color: Colors.red),
                const SizedBox(width: 4),
                Expanded(child: Text(ticket.event.location)),
                Text(
                  ticket.event.price > 0
                      ? 'RM ${ticket.event.price.toStringAsFixed(2)}'
                      : 'FREE',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQrPlaceholder(String value) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: GridView.builder(
              itemCount: 25,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 5,
                mainAxisSpacing: 2,
                crossAxisSpacing: 2,
              ),
              itemBuilder: (context, index) {
                final random = Random(index + value.hashCode);
                return Container(
                  decoration: BoxDecoration(
                    color: random.nextBool() ? Colors.black : Colors.transparent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              letterSpacing: 2,
              color: Colors.black54,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrganizeView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Publish New Event',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _titleController,
            label: 'Event Title*',
            hint: 'Give your event a clear name',
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildDropdownField(
                  label: 'Category*',
                  value: _newEventCategory,
                  items: _categories.where((item) => item != 'All').toList(),
                  onChanged: (value) {
                    if (value == null) {
                      return;
                    }
                    setState(() => _newEventCategory = value);
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildDatePickerField(
                  label: 'Date*',
                  value: _newEventDate,
                  onPressed: _selectDate,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildTextField(
            controller: _locationController,
            label: 'Location*',
            hint: 'Where is the venue?',
            prefixIcon: Icons.location_on,
          ),
          const SizedBox(height: 12),
          _buildTextField(
            controller: _priceController,
            label: 'Price (RM)',
            hint: '0.00 (leave 0 for free)',
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 12),
          _buildTextField(
            controller: _descriptionController,
            label: 'Description',
            hint: 'Tell travelers what to expect...',
            maxLines: 4,
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _publishEvent,
              icon: const Icon(Icons.add_circle_outline),
              label: const Text('Publish Event'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    int maxLines = 1,
    IconData? prefixIcon,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: prefixIcon == null ? null : Icon(prefixIcon),
            filled: true,
            fillColor: const Color(0xFFF9FAFB),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value: value,
          items: items
              .map(
                (item) => DropdownMenuItem(
                  value: item,
                  child: Text(item),
                ),
              )
              .toList(),
          onChanged: onChanged,
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFFF9FAFB),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDatePickerField({
    required String label,
    required String value,
    required VoidCallback onPressed,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        InkWell(
          onTap: onPressed,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today, size: 18),
                const SizedBox(width: 8),
                Text(
                  value.isEmpty ? 'Select date' : value,
                  style: TextStyle(
                    color: value.isEmpty ? Colors.black38 : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    String? subtitle,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: Colors.black12),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black54,
              ),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: const TextStyle(color: Colors.black45),
                textAlign: TextAlign.center,
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: onAction,
                child: Text(actionLabel),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 8,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavItem(
            icon: Icons.search,
            label: 'Explore',
            isActive: _view == EventView.explore || _view == EventView.detail,
            onTap: () => _selectView(EventView.explore),
          ),
          _buildNavItem(
            icon: Icons.confirmation_number,
            label: 'My Tickets',
            isActive: _view == EventView.tickets,
            onTap: () => _selectView(EventView.tickets),
            badgeCount: _tickets.length,
          ),
          _buildNavItem(
            icon: Icons.add_circle_outline,
            label: 'Organize',
            isActive: _view == EventView.organize,
            onTap: () => _selectView(EventView.organize),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
    int badgeCount = 0,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            children: [
              Icon(icon, color: isActive ? Colors.blue : Colors.black38),
              if (badgeCount > 0)
                Positioned(
                  right: 0,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      badgeCount.toString(),
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isActive ? Colors.blue : Colors.black38,
            ),
          ),
        ],
      ),
    );
  }
}
