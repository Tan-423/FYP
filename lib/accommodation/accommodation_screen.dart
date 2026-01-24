import 'dart:async';

import 'package:flutter/material.dart';

class AccommodationScreen extends StatefulWidget {
  const AccommodationScreen({super.key});

  @override
  State<AccommodationScreen> createState() => _AccommodationScreenState();
}

class _AccommodationScreenState extends State<AccommodationScreen> {
  AccommodationView _currentView = AccommodationView.home;
  final List<AccommodationItem> _accommodations = List.of(_initialAccommodations);
  AccommodationItem? _selectedItem;
  final List<BookingItem> _bookings = [];
  String _filter = 'All';
  String _searchQuery = '';
  final List<_NotificationItem> _notifications = [];
  bool _isProcessing = false;

  final Set<AccommodationView> _hideNavViews = {
    AccommodationView.detail,
    AccommodationView.booking,
    AccommodationView.publish,
  };

  List<AccommodationItem> get _filteredList {
    return _accommodations.where((item) {
      final matchesType = _filter == 'All' || item.type == _filter;
      final searchLower = _searchQuery.toLowerCase();
      final matchesSearch = item.name.toLowerCase().contains(searchLower) ||
          item.location.toLowerCase().contains(searchLower);
      return matchesType && matchesSearch;
    }).toList();
  }

  void _addNotification(String message) {
    final note = _NotificationItem(
      id: DateTime.now().millisecondsSinceEpoch,
      message: message,
    );
    setState(() => _notifications.insert(0, note));
    Timer(const Duration(seconds: 4), () {
      if (!mounted) return;
      setState(() => _notifications.removeWhere((n) => n.id == note.id));
    });
  }

  Future<void> _handleBook(AccommodationItem item) async {
    setState(() => _isProcessing = true);
    await Future.delayed(const Duration(milliseconds: 1500));
    final booking = BookingItem(
      bookingId: 'BK-${1000 + DateTime.now().millisecondsSinceEpoch % 9000}',
      status: 'Confirmed',
      checkIn: '2025-12-20',
      accommodation: item,
    );
    setState(() {
      _bookings.add(booking);
      _isProcessing = false;
      _currentView = AccommodationView.trips;
    });
    _addNotification('Booking confirmed for ${item.name}!');
  }

  void _handleCancel(String bookingId) {
    final target = _bookings.firstWhere((b) => b.bookingId == bookingId);
    setState(() => _bookings.removeWhere((b) => b.bookingId == bookingId));
    _addNotification('Reservation for ${target.accommodation.name} cancelled.');
  }

  void _handlePublish(NewPropertyForm form) {
    final property = AccommodationItem(
      id: _accommodations.length + 1,
      name: form.name,
      location: form.location,
      price: form.price,
      type: form.type,
      rating: 0,
      description: form.description,
      facilities: form.facilities,
      image:
          'https://images.unsplash.com/photo-1445019980597-93fa8acb246c?auto=format&fit=crop&w=800&q=80',
    );
    setState(() {
      _accommodations.add(property);
      _currentView = AccommodationView.owner;
    });
    _addNotification('Successfully published ${property.name}!');
  }

  void _openDetail(AccommodationItem item) {
    setState(() {
      _selectedItem = item;
      _currentView = AccommodationView.detail;
    });
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
                Expanded(
                  child: _buildContent(),
                ),
                if (showNav) _buildBottomNav(),
              ],
            ),
            _NotificationOverlay(
              notifications: _notifications,
              onDismiss: (id) =>
                  setState(() => _notifications.removeWhere((n) => n.id == id)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    switch (_currentView) {
      case AccommodationView.home:
        return _HomeView(
          searchQuery: _searchQuery,
          onSearchChanged: (value) => setState(() => _searchQuery = value),
          onExplore: () => setState(() => _currentView = AccommodationView.explore),
          onQuickCity: (city) {
            setState(() {
              _searchQuery = city;
              _currentView = AccommodationView.explore;
            });
          },
        );
      case AccommodationView.explore:
        return _ExploreView(
          filter: _filter,
          onFilterChanged: (value) => setState(() => _filter = value),
          onBack: () => setState(() => _currentView = AccommodationView.home),
          items: _filteredList,
          onOpenDetail: _openDetail,
        );
      case AccommodationView.detail:
        return _DetailView(
          item: _selectedItem,
          onBack: () => setState(() => _currentView = AccommodationView.explore),
          onBook: () => setState(() => _currentView = AccommodationView.booking),
        );
      case AccommodationView.booking:
        return _BookingView(
          item: _selectedItem,
          onBack: () => setState(() => _currentView = AccommodationView.detail),
          isProcessing: _isProcessing,
          onPay: () {
            final item = _selectedItem;
            if (item == null) return;
            _handleBook(item);
          },
        );
      case AccommodationView.trips:
        return _TripsView(
          bookings: _bookings,
          onCancel: _handleCancel,
          onExplore: () => setState(() => _currentView = AccommodationView.explore),
        );
      case AccommodationView.owner:
        return _OwnerView(
          accommodations: _accommodations,
          onPublish: () => setState(() => _currentView = AccommodationView.publish),
        );
      case AccommodationView.publish:
        return _PublishFormView(
          onBack: () => setState(() => _currentView = AccommodationView.owner),
          onPublish: _handlePublish,
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
          _NavButton(
            label: 'Home',
            icon: Icons.home_rounded,
            active: _currentView == AccommodationView.home,
            onTap: () => setState(() => _currentView = AccommodationView.home),
          ),
          _NavButton(
            label: 'Explore',
            icon: Icons.search_rounded,
            active: _currentView == AccommodationView.explore,
            onTap: () => setState(() => _currentView = AccommodationView.explore),
          ),
          _NavButton(
            label: 'Trips',
            icon: Icons.work_rounded,
            active: _currentView == AccommodationView.trips,
            onTap: () => setState(() => _currentView = AccommodationView.trips),
          ),
          _NavButton(
            label: 'Owner',
            icon: Icons.add_circle_outline_rounded,
            active: _currentView == AccommodationView.owner,
            onTap: () => setState(() => _currentView = AccommodationView.owner),
          ),
        ],
      ),
    );
  }
}

enum AccommodationView { home, explore, detail, booking, trips, owner, publish }

class AccommodationItem {
  const AccommodationItem({
    required this.id,
    required this.name,
    required this.location,
    required this.price,
    required this.type,
    required this.rating,
    required this.description,
    required this.facilities,
    required this.image,
  });

  final int id;
  final String name;
  final String location;
  final double price;
  final String type;
  final double rating;
  final String description;
  final List<String> facilities;
  final String image;
}

class BookingItem {
  const BookingItem({
    required this.bookingId,
    required this.status,
    required this.checkIn,
    required this.accommodation,
  });

  final String bookingId;
  final String status;
  final String checkIn;
  final AccommodationItem accommodation;
}

class NewPropertyForm {
  const NewPropertyForm({
    required this.name,
    required this.type,
    required this.location,
    required this.price,
    required this.description,
    required this.facilities,
  });

  final String name;
  final String type;
  final String location;
  final double price;
  final String description;
  final List<String> facilities;
}

class _NotificationItem {
  const _NotificationItem({required this.id, required this.message});

  final int id;
  final String message;
}

class _NotificationOverlay extends StatelessWidget {
  const _NotificationOverlay({
    required this.notifications,
    required this.onDismiss,
  });

  final List<_NotificationItem> notifications;
  final ValueChanged<int> onDismiss;

  @override
  Widget build(BuildContext context) {
    if (notifications.isEmpty) return const SizedBox.shrink();
    return Positioned(
      top: 16,
      left: 16,
      right: 16,
      child: Column(
        children: notifications
            .map(
              (note) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xF21F2937),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white24),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        note.message,
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => onDismiss(note.id),
                      child: const Icon(Icons.close, size: 18, color: Colors.white54),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _HomeView extends StatelessWidget {
  const _HomeView({
    required this.searchQuery,
    required this.onSearchChanged,
    required this.onExplore,
    required this.onQuickCity,
  });

  final String searchQuery;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onExplore;
  final ValueChanged<String> onQuickCity;

  @override
  Widget build(BuildContext context) {
    final cities = [
      'Kuala Lumpur',
      'Penang',
      'Langkawi',
      'Melaka',
      'Johor Bahru',
      'Kota Kinabalu',
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 100),
      children: [
        const Text(
          'Find your stay',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        const Text(
          'Explore the best places to rest in Malaysia',
          style: TextStyle(color: Colors.black54),
        ),
        const SizedBox(height: 20),
        _CardContainer(
          child: Column(
            children: [
              _InputField(
                icon: Icons.location_on_rounded,
                hint: 'Where are you going?',
                value: searchQuery,
                onChanged: onSearchChanged,
              ),
              const SizedBox(height: 12),
              Row(
                children: const [
                  Expanded(
                    child: _InputField(
                      icon: Icons.calendar_today_rounded,
                      hint: 'Date',
                      value: '',
                      onChanged: null,
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: _InputField(
                      icon: Icons.person_rounded,
                      hint: '1 Guest',
                      value: '',
                      onChanged: null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onExplore,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Search Accommodation',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Popular Destinations',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        GridView.builder(
          itemCount: cities.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.1,
          ),
          itemBuilder: (context, index) {
            final city = cities[index];
            return GestureDetector(
              onTap: () => onQuickCity(city),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.network(
                      'https://images.unsplash.com/photo-1540959733332-eab4deabeeaf?auto=format&fit=crop&w=400&q=80',
                      fit: BoxFit.cover,
                    ),
                    Container(color: Colors.black26),
                    Align(
                      alignment: Alignment.bottomLeft,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          city,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _ExploreView extends StatelessWidget {
  const _ExploreView({
    required this.filter,
    required this.onFilterChanged,
    required this.onBack,
    required this.items,
    required this.onOpenDetail,
  });

  final String filter;
  final ValueChanged<String> onFilterChanged;
  final VoidCallback onBack;
  final List<AccommodationItem> items;
  final ValueChanged<AccommodationItem> onOpenDetail;

  @override
  Widget build(BuildContext context) {
    const filters = ['All', 'Luxury', 'Mid-range', 'Budget'];

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          decoration: const BoxDecoration(
            color: Colors.white,
            boxShadow: [BoxShadow(color: Color(0x11000000), blurRadius: 10)],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: onBack,
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Explore Stays',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 40,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemBuilder: (context, index) {
                    final value = filters[index];
                    final active = value == filter;
                    return ChoiceChip(
                      label: Text(value),
                      selected: active,
                      onSelected: (_) => onFilterChanged(value),
                      selectedColor: const Color(0xFF2563EB),
                      labelStyle: TextStyle(
                        color: active ? Colors.white : Colors.black54,
                        fontWeight: FontWeight.w600,
                      ),
                    );
                  },
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemCount: filters.length,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: items.isEmpty
              ? _EmptyState(
                  onClear: () => onFilterChanged('All'),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 16),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return GestureDetector(
                      onTap: () => onOpenDetail(item),
                      child: _CardContainer(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Stack(
                                children: [
                                  AspectRatio(
                                    aspectRatio: 16 / 9,
                                    child: Image.network(
                                      item.image,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  Positioned(
                                    top: 12,
                                    right: 12,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.9),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.star, size: 14, color: Colors.amber),
                                          const SizedBox(width: 4),
                                          Text(
                                            item.rating.toStringAsFixed(1),
                                            style: const TextStyle(fontWeight: FontWeight.bold),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    bottom: 12,
                                    left: 12,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF2563EB),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        item.type.toUpperCase(),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.name,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          const Icon(Icons.location_on, size: 14, color: Colors.black54),
                                          const SizedBox(width: 4),
                                          Text(
                                            item.location,
                                            style: const TextStyle(color: Colors.black54),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      'RM${item.price.toStringAsFixed(0)}',
                                      style: const TextStyle(
                                        color: Color(0xFF2563EB),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                      ),
                                    ),
                                    const Text(
                                      'per night',
                                      style: TextStyle(fontSize: 10, color: Colors.black38),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _DetailView extends StatelessWidget {
  const _DetailView({
    required this.item,
    required this.onBack,
    required this.onBook,
  });

  final AccommodationItem? item;
  final VoidCallback onBack;
  final VoidCallback onBook;

  @override
  Widget build(BuildContext context) {
    if (item == null) {
      return const Center(child: Text('No accommodation selected.'));
    }

    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.only(bottom: 140),
          children: [
            Stack(
              children: [
                AspectRatio(
                  aspectRatio: 16 / 10,
                  child: Image.network(item!.image, fit: BoxFit.cover),
                ),
                Positioned(
                  top: 16,
                  left: 16,
                  child: CircleAvatar(
                    backgroundColor: Colors.black54,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: onBack,
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item!.name,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(Icons.location_on, size: 16, color: Color(0xFF2563EB)),
                                const SizedBox(width: 4),
                                Text(
                                  item!.location,
                                  style: const TextStyle(color: Colors.black54),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE0F2FE),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          item!.type,
                          style: const TextStyle(
                            color: Color(0xFF0369A1),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Description',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item!.description,
                    style: const TextStyle(color: Colors.black54, height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Facilities',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: item!.facilities
                        .map(
                          (fac) => Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF3F4F6),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFE5E7EB)),
                            ),
                            child: Text(
                              fac,
                              style: const TextStyle(fontSize: 12, color: Colors.black54),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Location Rules',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  const _RuleItem('Check-in: 3:00 PM'),
                  const _RuleItem('Check-out: 12:00 PM'),
                  const _RuleItem('No smoking inside rooms'),
                  const _RuleItem('Pets are not allowed'),
                ],
              ),
            ),
          ],
        ),
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Color(0xFFECEFF4))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Total',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.black45,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                    Row(
                      children: [
                        Text(
                          'RM${item!.price.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2563EB),
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          '/night',
                          style: TextStyle(color: Colors.black45, fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
                ElevatedButton(
                  onPressed: onBook,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Book Now',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _BookingView extends StatelessWidget {
  const _BookingView({
    required this.item,
    required this.onBack,
    required this.onPay,
    required this.isProcessing,
  });

  final AccommodationItem? item;
  final VoidCallback onBack;
  final VoidCallback onPay;
  final bool isProcessing;

  @override
  Widget build(BuildContext context) {
    if (item == null) {
      return const Center(child: Text('No accommodation selected.'));
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
      children: [
        Row(
          children: [
            IconButton(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
            ),
            const SizedBox(width: 8),
            const Text(
              'Review & Pay',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _CardContainer(
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(item!.image, width: 88, height: 88, fit: BoxFit.cover),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item!.name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item!.location,
                      style: const TextStyle(color: Colors.black54, fontSize: 12),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'RM${item!.price.toStringAsFixed(0)}',
                      style: const TextStyle(
                        color: Color(0xFF2563EB),
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Guest Details',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
            color: Colors.black45,
          ),
        ),
        const SizedBox(height: 8),
        const _InputField(
          icon: Icons.person_rounded,
          hint: 'Full Name',
          value: '',
          onChanged: null,
        ),
        const SizedBox(height: 12),
        const _InputField(
          icon: Icons.email_outlined,
          hint: 'Email Address',
          value: '',
          onChanged: null,
        ),
        const SizedBox(height: 20),
        const Text(
          'Payment Method',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
            color: Colors.black45,
          ),
        ),
        const SizedBox(height: 8),
        _PaymentTile(
          icon: Icons.credit_card_rounded,
          title: 'PayPal / Credit Card',
          active: true,
        ),
        const SizedBox(height: 10),
        const _PaymentTile(
          icon: Icons.account_balance_rounded,
          title: 'Bank Transfer',
          active: false,
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: isProcessing ? null : onPay,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2563EB),
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: isProcessing
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text(
                  'Continue Payment',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
        ),
        const SizedBox(height: 12),
        const Center(
          child: Text(
            'Secured by PayPal SDK Integration',
            style: TextStyle(fontSize: 11, color: Colors.black45),
          ),
        ),
      ],
    );
  }
}

class _TripsView extends StatelessWidget {
  const _TripsView({
    required this.bookings,
    required this.onCancel,
    required this.onExplore,
  });

  final List<BookingItem> bookings;
  final ValueChanged<String> onCancel;
  final VoidCallback onExplore;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
      children: [
        const Text(
          'My Bookings',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        if (bookings.isEmpty)
          _EmptyTrips(onExplore: onExplore)
        else
          ...bookings.map((book) {
            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFF1F5F9)),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          book.bookingId,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.black45,
                            letterSpacing: 1,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDCFCE7),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            book.status.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF15803D),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            book.accommodation.image,
                            width: 64,
                            height: 64,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                book.accommodation.name,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(Icons.location_on, size: 12, color: Colors.black54),
                                  const SizedBox(width: 4),
                                  Text(
                                    book.accommodation.location,
                                    style: const TextStyle(fontSize: 11, color: Colors.black54),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Check-in',
                                        style: TextStyle(fontSize: 9, color: Colors.black45),
                                      ),
                                      Text(
                                        book.checkIn,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      const Text(
                                        'Paid',
                                        style: TextStyle(fontSize: 9, color: Colors.black45),
                                      ),
                                      Text(
                                        'RM${book.accommodation.price.toStringAsFixed(0)}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF2563EB),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => onCancel(book.bookingId),
                    icon: const Icon(Icons.delete_outline, size: 16, color: Colors.redAccent),
                    label: const Text(
                      'Cancel Booking',
                      style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
      ],
    );
  }
}

class _OwnerView extends StatelessWidget {
  const _OwnerView({
    required this.accommodations,
    required this.onPublish,
  });

  final List<AccommodationItem> accommodations;
  final VoidCallback onPublish;

  @override
  Widget build(BuildContext context) {
    final listings = accommodations.where((a) => a.id > 4 || a.id == 1).toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Property Owner',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            Stack(
              children: const [
                Icon(Icons.notifications_none_rounded, color: Colors.black45),
                Positioned(
                  right: 0,
                  top: 0,
                  child: CircleAvatar(radius: 4, backgroundColor: Colors.red),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF2563EB),
            borderRadius: BorderRadius.circular(24),
            boxShadow: const [
              BoxShadow(color: Color(0x22000000), blurRadius: 14, offset: Offset(0, 8)),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text('Active Bookings', style: TextStyle(color: Colors.white70)),
                  SizedBox(height: 6),
                  Text(
                    '12',
                    style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'You have 2 new requests today',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
              const Icon(Icons.apartment_rounded, color: Colors.white24, size: 40),
            ],
          ),
        ),
        const SizedBox(height: 16),
        OutlinedButton(
          onPressed: onPublish,
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 20),
            side: const BorderSide(color: Color(0xFFE5E7EB), style: BorderStyle.solid, width: 1.4),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          ),
          child: Column(
            children: const [
              CircleAvatar(
                backgroundColor: Color(0xFFE0F2FE),
                child: Icon(Icons.add, color: Color(0xFF2563EB)),
              ),
              SizedBox(height: 8),
              Text(
                'Publish New Accommodation',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black54),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'My Listings',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        ...listings.map((item) {
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFF1F5F9)),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(item.image, width: 64, height: 64, fit: BoxFit.cover),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              item.name,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDCFCE7),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'PUBLISHED',
                              style: TextStyle(
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF15803D),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'RM${item.price.toStringAsFixed(0)} / night',
                        style: const TextStyle(
                          color: Color(0xFF2563EB),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: const [
                          Text('5 Bookings', style: TextStyle(fontSize: 10, color: Colors.black45)),
                          SizedBox(width: 12),
                          Text('4.8 Rating', style: TextStyle(fontSize: 10, color: Colors.black45)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }
}

class _PublishFormView extends StatefulWidget {
  const _PublishFormView({
    required this.onBack,
    required this.onPublish,
  });

  final VoidCallback onBack;
  final ValueChanged<NewPropertyForm> onPublish;

  @override
  State<_PublishFormView> createState() => _PublishFormViewState();
}

class _PublishFormViewState extends State<_PublishFormView> {
  final _nameController = TextEditingController();
  final _locationController = TextEditingController();
  final _priceController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _facilitiesController = TextEditingController();
  String _type = 'Luxury';

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
    _facilitiesController.dispose();
    super.dispose();
  }

  void _submit() {
    final price = double.tryParse(_priceController.text.trim()) ?? 0;
    final facilities = _facilitiesController.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    widget.onPublish(
      NewPropertyForm(
        name: _nameController.text.trim(),
        type: _type,
        location: _locationController.text.trim(),
        price: price,
        description: _descriptionController.text.trim(),
        facilities: facilities,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
      children: [
        Row(
          children: [
            IconButton(
              onPressed: widget.onBack,
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
            ),
            const SizedBox(width: 8),
            const Text(
              'New Property',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _FormField(
          label: 'Property Name',
          child: TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              hintText: 'e.g. Tropical Beach Villa',
              border: InputBorder.none,
            ),
          ),
        ),
        const SizedBox(height: 12),
        _FormField(
          label: 'Category',
          child: DropdownButtonFormField<String>(
            value: _type,
            decoration: const InputDecoration(border: InputBorder.none),
            items: const [
              DropdownMenuItem(value: 'Luxury', child: Text('Luxury')),
              DropdownMenuItem(value: 'Mid-range', child: Text('Mid-range')),
              DropdownMenuItem(value: 'Budget', child: Text('Budget')),
            ],
            onChanged: (value) => setState(() => _type = value ?? 'Luxury'),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _FormField(
                label: 'Price (RM)',
                child: TextField(
                  controller: _priceController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    hintText: '0.00',
                    border: InputBorder.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _FormField(
                label: 'Location',
                child: TextField(
                  controller: _locationController,
                  decoration: const InputDecoration(
                    hintText: 'City',
                    border: InputBorder.none,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _FormField(
          label: 'Description',
          child: TextField(
            controller: _descriptionController,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText: 'Describe your property details...',
              border: InputBorder.none,
            ),
          ),
        ),
        const SizedBox(height: 12),
        _FormField(
          label: 'Facilities (comma separated)',
          child: TextField(
            controller: _facilitiesController,
            decoration: const InputDecoration(
              hintText: 'WiFi, Pool, Gym',
              border: InputBorder.none,
            ),
          ),
        ),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2563EB),
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          child: const Text(
            'Publish Property',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}

class _FormField extends StatelessWidget {
  const _FormField({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 10,
              color: Colors.black45,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }
}

class _InputField extends StatelessWidget {
  const _InputField({
    required this.icon,
    required this.hint,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String hint;
  final String value;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF2563EB)),
          const SizedBox(width: 8),
          Expanded(
            child: TextFormField(
              enabled: onChanged != null,
              initialValue: value,
              onChanged: onChanged,
              decoration: InputDecoration(
                hintText: hint,
                border: InputBorder.none,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentTile extends StatelessWidget {
  const _PaymentTile({
    required this.icon,
    required this.title,
    required this.active,
  });

  final IconData icon;
  final String title;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: active ? const Color(0xFFE0F2FE) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: active ? const Color(0xFF2563EB) : const Color(0xFFE5E7EB),
          width: active ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: active ? const Color(0xFF2563EB) : Colors.black38),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: active ? const Color(0xFF1E3A8A) : Colors.black54,
              ),
            ),
          ),
          if (active) const Icon(Icons.check_circle, color: Color(0xFF2563EB)),
        ],
      ),
    );
  }
}

class _RuleItem extends StatelessWidget {
  const _RuleItem(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.circle, size: 6, color: Colors.black38),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: Colors.black54),
          ),
        ),
      ],
    );
  }
}

class _CardContainer extends StatelessWidget {
  const _CardContainer({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onClear});

  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: Column(
          children: [
            const Icon(Icons.info_outline, size: 40, color: Colors.black26),
            const SizedBox(height: 8),
            const Text('No accommodations found matching filters.'),
            TextButton(
              onPressed: onClear,
              child: const Text('Clear Filters'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyTrips extends StatelessWidget {
  const _EmptyTrips({required this.onExplore});

  final VoidCallback onExplore;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 40),
        const Icon(Icons.explore, size: 50, color: Colors.black26),
        const SizedBox(height: 12),
        const Text('No active bookings found.'),
        TextButton(
          onPressed: onExplore,
          child: const Text('Start exploring'),
        ),
      ],
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: active ? const Color(0xFF2563EB) : Colors.black38),
            const SizedBox(height: 4),
            Text(
              label.toUpperCase(),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: active ? const Color(0xFF2563EB) : Colors.black38,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

const List<AccommodationItem> _initialAccommodations = [
  AccommodationItem(
    id: 1,
    name: 'Luxury Sky Suite',
    location: 'Kuala Lumpur',
    price: 450,
    type: 'Luxury',
    rating: 4.8,
    description:
        'A breathtaking view of the Petronas Twin Towers with high-end amenities and infinity pool access. This suite offers a master bedroom with a king-sized bed, a modern living area, and a private balcony overlooking the city skyline. Guests also enjoy 24-hour concierge service and premium lounge access.',
    facilities: ['WiFi', 'Pool', 'Gym', 'AirCon', 'Kitchen', 'Bathtub', 'Parking'],
    image:
        'https://images.unsplash.com/photo-1566073771259-6a8506099945?auto=format&fit=crop&w=800&q=80',
  ),
  AccommodationItem(
    id: 2,
    name: 'Heritage Boutique Hotel',
    location: 'Penang',
    price: 280,
    type: 'Mid-range',
    rating: 4.5,
    description:
        'Located in the heart of George Town, this restored heritage building offers a unique cultural stay. Each room is uniquely decorated with local antiques and artwork, blending traditional architecture with modern comfort. Enjoy our courtyard breakfast and easy walking distance to famous street art.',
    facilities: ['WiFi', 'Breakfast', 'AirCon', 'Cafe', 'Bicycle Rental'],
    image:
        'https://images.unsplash.com/photo-1542314831-068cd1dbfeeb?auto=format&fit=crop&w=800&q=80',
  ),
  AccommodationItem(
    id: 3,
    name: 'Backpackers Haven',
    location: 'Langkawi',
    price: 85,
    type: 'Budget',
    rating: 4.2,
    description:
        'Clean, social environment perfect for solo travelers. Close to Pantai Cenang beach. We offer dormitory-style beds as well as private pods, a shared common room for movie nights, and a fully equipped communal kitchen. Great for making friends and exploring the island on a budget.',
    facilities: ['WiFi', 'Shared Kitchen', 'Lounge', 'Laundry', 'Lockers'],
    image:
        'https://images.unsplash.com/photo-1555854817-2b226f1753fd?auto=format&fit=crop&w=800&q=80',
  ),
  AccommodationItem(
    id: 4,
    name: 'The Ritz Residence',
    location: 'Kuala Lumpur',
    price: 600,
    type: 'Luxury',
    rating: 4.9,
    description:
        'Five-star service and ultra-modern interiors for the discerning traveler. Located in the Golden Triangle, this residence provides seamless access to the city\'s premier shopping and dining destinations. Experience unparalleled luxury with our signature spa treatments and world-class dining options.',
    facilities: ['WiFi', 'Spa', 'Valet', 'Pool', 'Bar', 'Meeting Rooms'],
    image:
        'https://images.unsplash.com/photo-1582719508461-905c673771fd?auto=format&fit=crop&w=800&q=80',
  ),
];
