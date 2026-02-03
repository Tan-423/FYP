import 'package:flutter/material.dart';

import 'accommodation_models.dart';
import 'accommodation_widgets.dart';

class HomeView extends StatefulWidget {
  const HomeView({
    required this.searchQuery,
    required this.onSearchChanged,
    required this.onExplore,
    required this.onQuickCity,
    super.key,
  });

  final String searchQuery;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onExplore;
  final ValueChanged<String> onQuickCity;

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  DateTimeRange? _dateRange;
  int _guestCount = 1;

  String _formatDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  String _formatDateRange(DateTimeRange? range) {
    if (range == null) return 'Date';
    return '${_formatDate(range.start)} - ${_formatDate(range.end)}';
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 2),
      initialDateRange: _dateRange,
    );
    if (picked == null) return;
    setState(() => _dateRange = picked);
  }

  Future<void> _pickGuests() async {
    int tempCount = _guestCount;
    await showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Guests',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Number of guests'),
                      Row(
                        children: [
                          IconButton(
                            onPressed:
                                tempCount > 1
                                    ? () => setSheetState(() => tempCount -= 1)
                                    : null,
                            icon: const Icon(Icons.remove_circle_outline),
                          ),
                          Text(
                            '$tempCount',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          IconButton(
                            onPressed:
                                () => setSheetState(() => tempCount += 1),
                            icon: const Icon(Icons.add_circle_outline),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        'Done',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    if (tempCount != _guestCount) {
      setState(() => _guestCount = tempCount);
    }
  }

  @override
  Widget build(BuildContext context) {
    final destinations = [
      {
        'city': 'Kuala Lumpur',
        'image': 'lib/accommodation/destination_image/Kuala Lumpur.jpg',
      },
      {
        'city': 'Penang',
        'image': 'lib/accommodation/destination_image/Penang.webp',
      },
      {
        'city': 'Langkawi',
        'image': 'lib/accommodation/destination_image/Langkawi.jpg',
      },
      {
        'city': 'Melaka',
        'image': 'lib/accommodation/destination_image/Melaka.jpg',
      },
      {
        'city': 'Johor Bahru',
        'image': 'lib/accommodation/destination_image/Johor Bahru.jpg',
      },
      {
        'city': 'Kota Kinabalu',
        'image': 'lib/accommodation/destination_image/Kota Kinabalu.jpg',
      },
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
        CardContainer(
          child: Column(
            children: [
              InputField(
                icon: Icons.location_on_rounded,
                hint: 'Where are you going?',
                value: widget.searchQuery,
                onChanged: widget.onSearchChanged,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: _pickDateRange,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.calendar_today_rounded,
                              color: Color(0xFF2563EB),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _formatDateRange(_dateRange),
                                style: const TextStyle(color: Colors.black54),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: _pickGuests,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.person_rounded,
                              color: Color(0xFF2563EB),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '$_guestCount Guest${_guestCount > 1 ? 's' : ''}',
                                style: const TextStyle(color: Colors.black54),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: widget.onExplore,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Search Accommodation',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
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
          itemCount: destinations.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.1,
          ),
          itemBuilder: (context, index) {
            final destination = destinations[index];
            final city = destination['city']!;
            final image = destination['image']!;
            return GestureDetector(
              onTap: () => widget.onQuickCity(city),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset(image, fit: BoxFit.cover),
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

class OwnerAuthView extends StatelessWidget {
  const OwnerAuthView({
    required this.onBack,
    required this.onContinueAsGuest,
    required this.onOwnerLogin,
    super.key,
  });

  final VoidCallback onBack;
  final VoidCallback onContinueAsGuest;
  final VoidCallback onOwnerLogin;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: onBack,
                icon: const Icon(Icons.chevron_left),
                label: const Text('Back to Main Menu'),
              ),
            ),
            const SizedBox(height: 8),
            const Icon(Icons.apartment, size: 64, color: Color(0xFF2563EB)),
            const SizedBox(height: 16),
            const Text(
              'Accommodation Portal',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onContinueAsGuest,
                icon: const Icon(Icons.person),
                label: const Text('Continue as Guest'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onOwnerLogin,
                icon: const Icon(Icons.lock_outline),
                label: const Text('Login as Owner'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class OwnerLoginView extends StatelessWidget {
  const OwnerLoginView({
    required this.emailController,
    required this.passwordController,
    required this.isLoading,
    required this.showPassword,
    required this.onTogglePassword,
    required this.onBack,
    required this.onLogin,
    super.key,
  });

  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool isLoading;
  final bool showPassword;
  final VoidCallback onTogglePassword;
  final VoidCallback onBack;
  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextButton.icon(
              onPressed: onBack,
              icon: const Icon(Icons.chevron_left),
              label: const Text('Back'),
            ),
            const SizedBox(height: 8),
            const Text(
              'Owner Login',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            FormFieldContainer(
              label: 'Email',
              child: TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  hintText: 'owner@email.com',
                  border: InputBorder.none,
                ),
              ),
            ),
            const SizedBox(height: 12),
            FormFieldContainer(
              label: 'Password',
              child: TextField(
                controller: passwordController,
                obscureText: !showPassword,
                decoration: InputDecoration(
                  hintText: 'Enter password',
                  border: InputBorder.none,
                  suffixIcon: IconButton(
                    onPressed: onTogglePassword,
                    icon: Icon(
                      showPassword ? Icons.visibility_off : Icons.visibility,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isLoading ? null : onLogin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child:
                    isLoading
                        ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                        : const Text('Login as Owner'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ExploreView extends StatelessWidget {
  const ExploreView({
    required this.filter,
    required this.onFilterChanged,
    required this.onBack,
    required this.items,
    required this.onOpenDetail,
    super.key,
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
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 18,
                    ),
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
          child:
              items.isEmpty
                  ? EmptyState(onClear: () => onFilterChanged('All'))
                  : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 16),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return GestureDetector(
                        onTap: () => onOpenDetail(item),
                        child: CardContainer(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: Stack(
                                  children: [
                                    AspectRatio(
                                      aspectRatio: 16 / 9,
                                      child: AccommodationImage(
                                        imageUrl: item.image,
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
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(
                                              Icons.star,
                                              size: 14,
                                              color: Colors.amber,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              item.rating.toStringAsFixed(1),
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      bottom: 12,
                                      left: 12,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF2563EB),
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
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
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
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
                                            const Icon(
                                              Icons.location_on,
                                              size: 14,
                                              color: Colors.black54,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              item.location,
                                              style: const TextStyle(
                                                color: Colors.black54,
                                              ),
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
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.black38,
                                        ),
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

class DetailView extends StatelessWidget {
  const DetailView({
    required this.item,
    required this.onBack,
    required this.onBook,
    super.key,
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
                  child: AccommodationImage(
                    imageUrl: item!.image,
                    fit: BoxFit.cover,
                  ),
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
                                const Icon(
                                  Icons.location_on,
                                  size: 16,
                                  color: Color(0xFF2563EB),
                                ),
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
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
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
                    children:
                        item!.facilities
                            .map(
                              (fac) => Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF3F4F6),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: const Color(0xFFE5E7EB),
                                  ),
                                ),
                                child: Text(
                                  fac,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.black54,
                                  ),
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
                  const RuleItem('Check-in: 3:00 PM'),
                  const RuleItem('Check-out: 12:00 PM'),
                  const RuleItem('No smoking inside rooms'),
                  const RuleItem('Pets are not allowed'),
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Book Now',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
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

class BookingView extends StatefulWidget {
  const BookingView({
    required this.item,
    required this.onBack,
    required this.onPay,
    required this.isProcessing,
    super.key,
  });

  final AccommodationItem? item;
  final VoidCallback onBack;
  final ValueChanged<BookingRequest> onPay;
  final bool isProcessing;

  @override
  State<BookingView> createState() => _BookingViewState();
}

class _BookingViewState extends State<BookingView> {
  String? _selectedRoomLabel;
  DateTime? _checkIn;
  DateTime? _checkOut;
  int _roomCount = 1;
  int _peopleCount = 1;
  int _childCount = 0;
  int _infantCount = 0;
  bool _extraBed = false;
  final TextEditingController _guestNameController = TextEditingController();
  final TextEditingController _guestEmailController = TextEditingController();

  @override
  void dispose() {
    _guestNameController.dispose();
    _guestEmailController.dispose();
    super.dispose();
  }

  int get _nights {
    if (_checkIn == null || _checkOut == null) return 0;
    final diff = _checkOut!.difference(_checkIn!).inDays;
    return diff <= 0 ? 0 : diff;
  }

  List<_RoomTypeOption> _roomOptions(AccommodationItem item) {
    final entries =
        item.roomTypes.entries.where((entry) => entry.value > 0).toList();
    if (entries.isEmpty) {
      return const [
        _RoomTypeOption(
          label: 'Standard Room',
          multiplier: 1.0,
          description: 'Comfortable essentials for 2 guests',
          available: null,
        ),
        _RoomTypeOption(
          label: 'Deluxe Room',
          multiplier: 1.4,
          description: 'More space + city view',
          available: null,
        ),
        _RoomTypeOption(
          label: 'Suite',
          multiplier: 1.9,
          description: 'Separate living area + premium amenities',
          available: null,
        ),
      ];
    }
    return entries.map((entry) {
      final label = entry.key;
      return _RoomTypeOption(
        label: label,
        multiplier: _multiplierForType(label),
        description: _descriptionForType(label),
        available: entry.value,
      );
    }).toList();
  }

  double _multiplierForType(String label) {
    final key = label.toLowerCase();
    if (key.contains('suite')) return 1.9;
    if (key.contains('deluxe')) return 1.4;
    if (key.contains('family')) return 1.5;
    return 1.0;
  }

  String _descriptionForType(String label) {
    final key = label.toLowerCase();
    if (key.contains('suite'))
      return 'Separate living area + premium amenities';
    if (key.contains('deluxe')) return 'More space + city view';
    if (key.contains('family')) return 'Ideal for families and groups';
    return 'Comfortable essentials for 2 guests';
  }

  double _pricePerNight(double basePrice) {
    final option = _selectedRoomOption;
    return basePrice * (option?.multiplier ?? 1.0);
  }

  int? get _availableRooms {
    final option = _selectedRoomOption;
    return option?.available;
  }

  int _capacityPerRoom() {
    final item = _currentItem;
    if (item == null || _selectedRoomLabel == null) return 0;
    final configured = item.roomCapacities[_selectedRoomLabel!];
    if (configured != null && configured > 0) return configured;
    final key = _selectedRoomLabel!.toLowerCase();
    if (key.contains('suite')) return 4;
    if (key.contains('deluxe')) return 3;
    if (key.contains('family')) return 4;
    return 2;
  }

  bool _capacityOk() {
    final adultsChildren = _peopleCount + _childCount;
    final perRoom = _capacityPerRoom();
    final extra = _extraBed ? 1 : 0;
    return adultsChildren <= _roomCount * (perRoom + extra);
  }

  _RoomTypeOption? get _selectedRoomOption {
    if (_selectedRoomLabel == null) return null;
    return _roomOptions(_currentItem!).firstWhere(
      (option) => option.label == _selectedRoomLabel,
      orElse: () => _roomOptions(_currentItem!).first,
    );
  }

  AccommodationItem? _currentItem;

  String _formatDate(DateTime? date) {
    if (date == null) return 'Select date';
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  Future<void> _pickCheckIn() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _checkIn ?? now,
      firstDate: now,
      lastDate: DateTime(now.year + 2),
    );
    if (picked == null) return;
    setState(() {
      _checkIn = picked;
      if (_checkOut != null && !_checkOut!.isAfter(picked)) {
        _checkOut = null;
      }
    });
  }

  Future<void> _pickCheckOut() async {
    final baseDate = _checkIn ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _checkOut ?? baseDate.add(const Duration(days: 1)),
      firstDate: baseDate.add(const Duration(days: 1)),
      lastDate: DateTime(baseDate.year + 2),
    );
    if (picked == null) return;
    setState(() => _checkOut = picked);
  }

  void _submitPayment(double basePrice) {
    final name = _guestNameController.text.trim();
    final email = _guestEmailController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your full name.')),
      );
      return;
    }

    // Validate name: no digits allowed
    if (name.contains(RegExp(r'[0-9]'))) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name cannot contain digits.')),
      );
      return;
    }

    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your email address.')),
      );
      return;
    }

    // Validate email format
    final emailRegex = RegExp(r'^[\w\.-]+@[\w\.-]+\.\w+$');
    if (!emailRegex.hasMatch(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid email address.')),
      );
      return;
    }
    if (_checkIn == null || _checkOut == null || _nights <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select check-in and check-out dates.'),
        ),
      );
      return;
    }
    if (_selectedRoomLabel == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a room type.')),
      );
      return;
    }
    if (_roomCount < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Room quantity must be at least 1.')),
      );
      return;
    }
    if (_peopleCount < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('People count must be at least 1.')),
      );
      return;
    }
    final available = _availableRooms;
    if (available != null && _roomCount > available) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selected rooms exceed availability.')),
      );
      return;
    }
    if (!_capacityOk()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Guests exceed room capacity. Adjust rooms or guests.'),
        ),
      );
      return;
    }
    final item = _currentItem;
    if (item == null) {
      return;
    }
    final pricePerNight = _pricePerNight(basePrice);
    final extraBedFee = _extraBed ? item.extraBedFee * _roomCount : 0;
    final total = pricePerNight * _nights * _roomCount + extraBedFee;
    widget.onPay(
      BookingRequest(
        roomType: _selectedRoomLabel!,
        checkIn: _checkIn!,
        checkOut: _checkOut!,
        nights: _nights,
        pricePerNight: pricePerNight,
        roomCount: _roomCount,
        peopleCount: _peopleCount,
        childCount: _childCount,
        infantCount: _infantCount,
        extraBed: _extraBed,
        extraBedFee: item.extraBedFee,
        totalPrice: total,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    if (item == null) {
      return const Center(child: Text('No accommodation selected.'));
    }
    _currentItem = item;
    final options = _roomOptions(item);
    _selectedRoomLabel ??= options.first.label;
    final basePrice = item.price;
    final pricePerNight = _pricePerNight(basePrice);
    final extraBedFee = _extraBed ? item.extraBedFee * _roomCount : 0;
    final total =
        _nights > 0
            ? pricePerNight * _nights * _roomCount + extraBedFee
            : pricePerNight + extraBedFee;

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
              'Review & Pay',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 16),
        CardContainer(
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SizedBox(
                  width: 88,
                  height: 88,
                  child: AccommodationImage(
                    imageUrl: item.image,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item.location,
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'RM${item.price.toStringAsFixed(0)}',
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
          'Room Type',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
            color: Colors.black45,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _selectedRoomLabel,
          decoration: const InputDecoration(
            filled: true,
            fillColor: Color(0xFFF3F4F6),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(16)),
              borderSide: BorderSide.none,
            ),
          ),
          items:
              options
                  .map(
                    (option) => DropdownMenuItem(
                      value: option.label,
                      child: Text(
                        option.available == null
                            ? option.label
                            : '${option.label} (${option.available} available)',
                      ),
                    ),
                  )
                  .toList(),
          onChanged: (value) {
            if (value == null) return;
            setState(() => _selectedRoomLabel = value);
          },
        ),
        const SizedBox(height: 8),
        Text(
          _selectedRoomOption?.description ?? '',
          style: const TextStyle(fontSize: 12, color: Colors.black54),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFE0F2FE),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF0369A1).withOpacity(0.2)),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.info_outline,
                size: 16,
                color: Color(0xFF0369A1),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Room Capacity: ${_capacityPerRoom()} guest${_capacityPerRoom() > 1 ? 's' : ''} per room${item.extraBedFee > 0 ? ' (+1 with extra bed)' : ''}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF0369A1),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Guests & Rooms',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
            color: Colors.black45,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _CountSelector(
                label: 'People',
                value: _peopleCount,
                onDecrement:
                    _peopleCount > 1
                        ? () => setState(() => _peopleCount -= 1)
                        : null,
                onIncrement: () => setState(() => _peopleCount += 1),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _CountSelector(
                label: 'Rooms',
                value: _roomCount,
                helperText:
                    _availableRooms == null
                        ? null
                        : 'Available: $_availableRooms',
                onDecrement:
                    _roomCount > 1
                        ? () => setState(() => _roomCount -= 1)
                        : null,
                onIncrement: () {
                  final available = _availableRooms;
                  if (available != null && _roomCount >= available) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('No more rooms available.')),
                    );
                    return;
                  }
                  setState(() => _roomCount += 1);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _CountSelector(
                label: 'Kids',
                value: _childCount,
                onDecrement:
                    _childCount > 0
                        ? () => setState(() => _childCount -= 1)
                        : null,
                onIncrement: () => setState(() => _childCount += 1),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _CountSelector(
                label: 'Infants',
                value: _infantCount,
                helperText: 'Under 2 not counted',
                onDecrement:
                    _infantCount > 0
                        ? () => setState(() => _infantCount -= 1)
                        : null,
                onIncrement: () => setState(() => _infantCount += 1),
              ),
            ),
          ],
        ),
        if (item.extraBedFee > 0) ...[
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Extra bed (+1 guest per room)'),
            subtitle: Text('RM${item.extraBedFee.toStringAsFixed(0)} per room'),
            value: _extraBed,
            onChanged: (value) => setState(() => _extraBed = value),
          ),
        ],
        const SizedBox(height: 16),
        const Text(
          'Dates',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
            color: Colors.black45,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _pickCheckIn,
                icon: const Icon(Icons.calendar_today_rounded),
                label: Text('Check-in: ${_formatDate(_checkIn)}'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _pickCheckOut,
                icon: const Icon(Icons.calendar_today_outlined),
                label: Text('Check-out: ${_formatDate(_checkOut)}'),
              ),
            ),
          ],
        ),
        if (_nights > 0) ...[
          const SizedBox(height: 8),
          Text(
            '$_nights night${_nights > 1 ? 's' : ''} selected',
            style: const TextStyle(color: Colors.black54, fontSize: 12),
          ),
        ],
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
        InputField(
          icon: Icons.person_rounded,
          hint: 'Full Name',
          value: '',
          controller: _guestNameController,
          onChanged: (_) {},
        ),
        const SizedBox(height: 12),
        InputField(
          icon: Icons.email_outlined,
          hint: 'Email Address',
          value: '',
          controller: _guestEmailController,
          onChanged: (_) {},
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
        const PaymentTile(
          icon: Icons.credit_card_rounded,
          title: 'PayPal',
          active: true,
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed:
              widget.isProcessing ? null : () => _submitPayment(basePrice),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2563EB),
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child:
              widget.isProcessing
                  ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                  : Text(
                    'Pay RM${total.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
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

class TripsView extends StatelessWidget {
  const TripsView({
    required this.bookings,
    required this.failedPayments,
    required this.onRetryPayment,
    required this.onCancelPayment,
    required this.onDeletePayment,
    required this.onCancel,
    required this.onExplore,
    super.key,
  });

  final List<BookingItem> bookings;
  final List<AccommodationPaymentRecord> failedPayments;
  final ValueChanged<AccommodationPaymentRecord> onRetryPayment;
  final ValueChanged<AccommodationPaymentRecord> onCancelPayment;
  final ValueChanged<AccommodationPaymentRecord> onDeletePayment;
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
        if (failedPayments.isNotEmpty) ...[
          const Text(
            'Pending/Failed Payments',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          ...failedPayments.map((payment) {
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    payment.accommodationName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'RM ${payment.amount.toStringAsFixed(2)}',
                    style: const TextStyle(color: Colors.black54),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${payment.roomType} • ${payment.nights} night${payment.nights > 1 ? 's' : ''}',
                    style: const TextStyle(color: Colors.black45, fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${payment.roomCount} room${payment.roomCount > 1 ? 's' : ''} • ${payment.peopleCount} guest${payment.peopleCount > 1 ? 's' : ''}',
                    style: const TextStyle(color: Colors.black45, fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Status: ${payment.status}',
                    style: const TextStyle(color: Colors.black45, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      ElevatedButton(
                        onPressed: () => onRetryPayment(payment),
                        child: const Text('Try Again'),
                      ),
                      const SizedBox(width: 8),
                      if (payment.status != 'CANCELLED')
                        TextButton(
                          onPressed: () => onCancelPayment(payment),
                          child: const Text('Cancel'),
                        )
                      else
                        TextButton(
                          onPressed: () => onDeletePayment(payment),
                          child: const Text('Remove'),
                        ),
                    ],
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 16),
        ],
        if (bookings.isEmpty)
          EmptyTrips(onExplore: onExplore)
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
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
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
                          child: SizedBox(
                            width: 64,
                            height: 64,
                            child: AccommodationImage(
                              imageUrl: book.accommodation.image,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                book.accommodation.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.location_on,
                                    size: 12,
                                    color: Colors.black54,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    book.accommodation.location,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.black54,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                book.roomType,
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Colors.black54,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${book.roomCount} room${book.roomCount > 1 ? 's' : ''} • ${book.peopleCount} guest${book.peopleCount > 1 ? 's' : ''}',
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Colors.black45,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Check-in',
                                        style: TextStyle(
                                          fontSize: 9,
                                          color: Colors.black45,
                                        ),
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Check-out',
                                        style: TextStyle(
                                          fontSize: 9,
                                          color: Colors.black45,
                                        ),
                                      ),
                                      Text(
                                        book.checkOut,
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
                                        style: TextStyle(
                                          fontSize: 9,
                                          color: Colors.black45,
                                        ),
                                      ),
                                      Text(
                                        'RM${book.totalPaid.toStringAsFixed(0)}',
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
                    icon: const Icon(
                      Icons.delete_outline,
                      size: 16,
                      color: Colors.redAccent,
                    ),
                    label: const Text(
                      'Cancel Booking',
                      style: TextStyle(
                        color: Colors.redAccent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }
}

class _RoomTypeOption {
  const _RoomTypeOption({
    required this.label,
    required this.multiplier,
    required this.description,
    required this.available,
  });

  final String label;
  final double multiplier;
  final String description;
  final int? available;
}

class _CountSelector extends StatelessWidget {
  const _CountSelector({
    required this.label,
    required this.value,
    required this.onDecrement,
    required this.onIncrement,
    this.helperText,
  });

  final String label;
  final int value;
  final VoidCallback? onDecrement;
  final VoidCallback onIncrement;
  final String? helperText;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Colors.black45,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: onDecrement,
                icon: const Icon(Icons.remove_circle_outline),
              ),
              Text(
                value.toString(),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              IconButton(
                onPressed: onIncrement,
                icon: const Icon(Icons.add_circle_outline),
              ),
            ],
          ),
          if (helperText != null) ...[
            const SizedBox(height: 4),
            Text(
              helperText!,
              style: const TextStyle(fontSize: 10, color: Colors.black45),
            ),
          ],
        ],
      ),
    );
  }
}

class OwnerView extends StatelessWidget {
  const OwnerView({
    required this.accommodations,
    required this.onPublish,
    required this.onEdit,
    required this.activeBookings,
    this.ownerId,
    super.key,
  });

  final List<AccommodationItem> accommodations;
  final VoidCallback onPublish;
  final ValueChanged<AccommodationItem> onEdit;
  final int activeBookings;
  final String? ownerId;

  @override
  Widget build(BuildContext context) {
    final listings =
        ownerId == null
            ? accommodations
            : accommodations.where((a) => a.ownerId == ownerId).toList();
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
              BoxShadow(
                color: Color(0x22000000),
                blurRadius: 14,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Active Bookings',
                    style: TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '$activeBookings',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    activeBookings == 0
                        ? 'No active bookings yet'
                        : 'Keep an eye on upcoming stays',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
              const Icon(
                Icons.apartment_rounded,
                color: Colors.white24,
                size: 40,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        OutlinedButton(
          onPressed: onPublish,
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 20),
            side: const BorderSide(
              color: Color(0xFFE5E7EB),
              style: BorderStyle.solid,
              width: 1.4,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
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
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.black54,
                ),
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
        if (listings.isEmpty)
          InfoEmptyState(
            icon: Icons.apartment_outlined,
            title: 'No listings yet.',
            subtitle: 'Publish your first accommodation to see it here.',
            actionLabel: 'Publish Property',
            onAction: onPublish,
          )
        else
          ...listings.map((item) {
            final roomSummary = item.roomTypes.entries
                .where((entry) => entry.value > 0)
                .map((entry) => '${entry.key}: ${entry.value}')
                .join(', ');
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
                    child: SizedBox(
                      width: 64,
                      height: 64,
                      child: AccommodationImage(
                        imageUrl: item.image,
                        fit: BoxFit.cover,
                      ),
                    ),
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
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Row(
                              children: [
                                IconButton(
                                  onPressed: () => onEdit(item),
                                  icon: const Icon(
                                    Icons.edit,
                                    size: 16,
                                    color: Color(0xFF2563EB),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
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
                        if (roomSummary.isNotEmpty)
                          Text(
                            roomSummary,
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.black45,
                            ),
                          ),
                        if (roomSummary.isNotEmpty) const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(
                              Icons.location_on,
                              size: 12,
                              color: Colors.black54,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                item.location,
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Colors.black45,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }
}

class PublishFormView extends StatefulWidget {
  const PublishFormView({
    required this.onBack,
    required this.onPublish,
    required this.isPublishing,
    this.initialItem,
    super.key,
  });

  final VoidCallback onBack;
  final ValueChanged<NewPropertyForm> onPublish;
  final bool isPublishing;
  final AccommodationItem? initialItem;

  @override
  State<PublishFormView> createState() => PublishFormViewState();
}

class PublishFormViewState extends State<PublishFormView> {
  final _nameController = TextEditingController();
  final _locationController = TextEditingController();
  final _priceController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _facilitiesController = TextEditingController();
  final _standardRoomController = TextEditingController();
  final _deluxeRoomController = TextEditingController();
  final _suiteRoomController = TextEditingController();
  final _standardCapController = TextEditingController();
  final _deluxeCapController = TextEditingController();
  final _suiteCapController = TextEditingController();
  final _extraBedFeeController = TextEditingController();
  String _type = 'Luxury';

  @override
  void initState() {
    super.initState();
    final item = widget.initialItem;
    if (item != null) {
      _nameController.text = item.name;
      _locationController.text = item.location;
      _priceController.text = item.price.toStringAsFixed(0);
      _descriptionController.text = item.description;
      _facilitiesController.text = item.facilities.join(', ');
      _type = item.type.isEmpty ? 'Luxury' : item.type;
      _standardRoomController.text =
          (item.roomTypes['Standard Room'] ?? 0).toString();
      _deluxeRoomController.text =
          (item.roomTypes['Deluxe Room'] ?? 0).toString();
      _suiteRoomController.text = (item.roomTypes['Suite'] ?? 0).toString();
      _standardCapController.text =
          (item.roomCapacities['Standard Room'] ?? 2).toString();
      _deluxeCapController.text =
          (item.roomCapacities['Deluxe Room'] ?? 3).toString();
      _suiteCapController.text = (item.roomCapacities['Suite'] ?? 4).toString();
      _extraBedFeeController.text = item.extraBedFee.toStringAsFixed(0);
    } else {
      _standardCapController.text = '2';
      _deluxeCapController.text = '3';
      _suiteCapController.text = '4';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
    _facilitiesController.dispose();
    _standardRoomController.dispose();
    _deluxeRoomController.dispose();
    _suiteRoomController.dispose();
    _standardCapController.dispose();
    _deluxeCapController.dispose();
    _suiteCapController.dispose();
    _extraBedFeeController.dispose();
    super.dispose();
  }

  void _submit() {
    final price = double.tryParse(_priceController.text.trim()) ?? 0;
    final facilities =
        _facilitiesController.text
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
    final standardCount =
        int.tryParse(_standardRoomController.text.trim()) ?? 0;
    final deluxeCount = int.tryParse(_deluxeRoomController.text.trim()) ?? 0;
    final suiteCount = int.tryParse(_suiteRoomController.text.trim()) ?? 0;
    final standardCap = int.tryParse(_standardCapController.text.trim()) ?? 2;
    final deluxeCap = int.tryParse(_deluxeCapController.text.trim()) ?? 3;
    final suiteCap = int.tryParse(_suiteCapController.text.trim()) ?? 4;
    final extraBedFee =
        double.tryParse(_extraBedFeeController.text.trim()) ?? 0;
    final roomTypes = <String, int>{
      if (standardCount > 0) 'Standard Room': standardCount,
      if (deluxeCount > 0) 'Deluxe Room': deluxeCount,
      if (suiteCount > 0) 'Suite': suiteCount,
    };
    final roomCapacities = <String, int>{
      'Standard Room': standardCap,
      'Deluxe Room': deluxeCap,
      'Suite': suiteCap,
    };
    widget.onPublish(
      NewPropertyForm(
        name: _nameController.text.trim(),
        type: _type,
        location: _locationController.text.trim(),
        price: price,
        description: _descriptionController.text.trim(),
        facilities: facilities,
        roomTypes: roomTypes,
        roomCapacities: roomCapacities,
        extraBedFee: extraBedFee,
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
        FormFieldContainer(
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
        FormFieldContainer(
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
              child: FormFieldContainer(
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
              child: FormFieldContainer(
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
        FormFieldContainer(
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
        FormFieldContainer(
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
        const Text(
          'Room Types',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
            color: Colors.black45,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: FormFieldContainer(
                label: 'Standard',
                child: TextField(
                  controller: _standardRoomController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    hintText: '0',
                    border: InputBorder.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FormFieldContainer(
                label: 'Deluxe',
                child: TextField(
                  controller: _deluxeRoomController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    hintText: '0',
                    border: InputBorder.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FormFieldContainer(
                label: 'Suite',
                child: TextField(
                  controller: _suiteRoomController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    hintText: '0',
                    border: InputBorder.none,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        const Text(
          'Enter available rooms for each type.',
          style: TextStyle(color: Colors.black45, fontSize: 11),
        ),
        const SizedBox(height: 16),
        const Text(
          'Capacity per Room',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
            color: Colors.black45,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: FormFieldContainer(
                label: 'Standard',
                child: TextField(
                  controller: _standardCapController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    hintText: '2',
                    border: InputBorder.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FormFieldContainer(
                label: 'Deluxe',
                child: TextField(
                  controller: _deluxeCapController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    hintText: '3',
                    border: InputBorder.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FormFieldContainer(
                label: 'Suite',
                child: TextField(
                  controller: _suiteCapController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    hintText: '4',
                    border: InputBorder.none,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        FormFieldContainer(
          label: 'Extra Bed Fee (per room)',
          child: TextField(
            controller: _extraBedFeeController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              hintText: '0',
              border: InputBorder.none,
            ),
          ),
        ),
        const SizedBox(height: 14),
        ElevatedButton(
          onPressed: widget.isPublishing ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2563EB),
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child:
              widget.isPublishing
                  ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                  : const Text(
                    'Publish Property',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
        ),
      ],
    );
  }
}
