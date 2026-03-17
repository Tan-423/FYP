import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'Login/login_page.dart';
import 'Login/auth_state.dart';
import 'accommodation/accommodation_screen.dart';
import 'bill_tracking/bill_tracking_screen.dart';
import 'chatbot/chatbot_screen.dart';
import 'event_management/event_management.dart';
import 'community/community_screen.dart';
import 'payment/payment_screen.dart';
import 'Translate/translate_screen.dart';
import 'Achievement/achievement.dart';
import 'Bus/BusSchedule.dart';
import 'CarRental/nearbycar.dart';
import 'TripPlan/tripschedule.dart';
import 'TripPlan/favourite.dart';
import 'TripPlan/createtrip.dart';
import 'Explore/explore.dart';
import 'Profile/profile.dart';

String _displayNameFor(User? user) {
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

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await FirebaseAuth.instance.signOut(); // force login on every app start
  runApp(const FypApp());
}

class FypApp extends StatelessWidget {
  const FypApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Trip Planning',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.indigo,
        fontFamilyFallback: const ['Segoe UI', 'Roboto'],
      ),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasData && !otpInProgress) {
          return const MainShell();
        }
        return const LoginPage();
      },
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _tabIndex = 0;
  int _notificationCount = 3;
  final Set<int> _visitedTabs = {0};

  final List<ModuleItem> _moduleCatalog = const [
    ModuleItem(
      id: 'community',
      label: 'Community',
      icon: Icons.people_alt_rounded,
      color: Color(0xFF00B8D4),
      subtitle: 'Blogs, groups, polls',
      features: [
        'Post blog with images and location tagging',
        'Private/public travel group with invite code',
        'Create and publish vote pages',
        'Real-time likes, comments, and vote result',
        'In-app group chat + notifications',
      ],
    ),
    ModuleItem(
      id: 'bills',
      label: 'Bill Tracking',
      icon: Icons.receipt_long_rounded,
      color: Color(0xFF22C55E),
      subtitle: 'Split costs',
      features: [
        'Manual bill with SST/service charges',
        'AI receipt scanner with item recognition',
        'Live currency conversion to MYR',
        'User-based splitting by item',
        'Bill history by group',
      ],
    ),
    ModuleItem(
      id: 'chatbot',
      label: 'Real-time Chatbot',
      icon: Icons.smart_toy_rounded,
      color: Color(0xFF6366F1),
      subtitle: 'Dialogflow + voice',
      features: [
        'NLP with Dialogflow for travel Q&A',
        'Voice-to-text input',
        'Multilanguage support (EN/BM/中文)',
        'Weather API integration',
        'Location-aware suggestions',
      ],
    ),
    ModuleItem(
      id: 'accommodation',
      label: 'Accommodation',
      icon: Icons.bed_rounded,
      color: Color(0xFFFB7185),
      subtitle: 'Book stays',
      features: [
        'Filter by budget and preferences',
        'Add/Register accommodation listing',
        'Publish listing to public search',
        'Book and cancel accommodation',
        'Push notifications for status',
      ],
    ),
    ModuleItem(
      id: 'payment',
      label: 'Payment',
      icon: Icons.credit_card_rounded,
      color: Color(0xFFF59E0B),
      subtitle: 'PayPal SDK',
      features: [
        'PayPal SDK with 3D Secure',
        'PDF receipt generation',
        'Transaction history',
        'Email e-receipt with invoice',
      ],
    ),
    ModuleItem(
      id: 'events',
      label: 'Event Management',
      icon: Icons.event_available_rounded,
      color: Color(0xFF8B5CF6),
      subtitle: 'Discover & join',
      features: [
        'Filter event by category',
        'QR code ticket in-app',
        'Event reminder notifications',
        'Add/Register & publish event',
        'Join and cancel event',
      ],
    ),
    ModuleItem(
      id: 'trips',
      label: 'Trip Planner',
      icon: Icons.map_rounded,
      color: Color(0xFF6366F1),
      subtitle: 'Your itinerary',
      features: ['View and manage trip plans', 'Budget and itinerary overview'],
    ),
    ModuleItem(
      id: 'transport',
      label: 'Bus',
      icon: Icons.directions_bus_rounded,
      color: Color(0xFFFBBF24),
      subtitle: 'Bus tickets & routes',
      features: ['Bus booking and tickets', 'View routes and schedules'],
    ),
    ModuleItem(
      id: 'car_rental',
      label: 'Car Rental',
      icon: Icons.car_rental,
      color: Color(0xFFEF4444),
      subtitle: 'Rent a vehicle',
      features: [
        'Browse available vehicles',
        'Book and manage rentals',
        'View rental history',
      ],
    ),
    ModuleItem(
      id: 'translate',
      label: 'Translate',
      icon: Icons.translate_rounded,
      color: Color(0xFF14B8A6),
      subtitle: 'Language translation',
      features: [
        'Real-time text translation',
        'Support for multiple languages',
        'Camera-based text translation',
        'Saved phrases and history',
      ],
    ),
    ModuleItem(
      id: 'achievement',
      label: 'Achievement',
      icon: Icons.emoji_events_rounded,
      color: Color(0xFFF59E0B),
      subtitle: 'Badges & milestones',
      features: [
        'Earn badges for travel milestones',
        'Track your travel streaks',
        'Leaderboard with other travelers',
        'Unlock rewards and perks',
      ],
    ),
  ];

  void _openModule(ModuleItem module) {
    final rootContext = context;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder:
          (context) => ModuleSheet(
            module: module,
            onOpenModule: () {
              Navigator.of(context).pop();
              if (module.id == 'bills') {
                Navigator.of(rootContext).push(
                  MaterialPageRoute(builder: (_) => const BillTrackingScreen()),
                );
              } else if (module.id == 'payment') {
                Navigator.of(rootContext).push(
                  MaterialPageRoute(builder: (_) => const PaymentScreen()),
                );
              } else if (module.id == 'events') {
                Navigator.of(rootContext).push(
                  MaterialPageRoute(
                    builder: (_) => const EventManagementScreen(),
                  ),
                );
              } else if (module.id == 'chatbot') {
                Navigator.of(rootContext).push(
                  MaterialPageRoute(builder: (_) => const ChatbotScreen()),
                );
              } else if (module.id == 'accommodation') {
                Navigator.of(rootContext).push(
                  MaterialPageRoute(
                    builder: (_) => const AccommodationScreen(),
                  ),
                );
              } else if (module.id == 'community') {
                Navigator.of(rootContext).push(
                  MaterialPageRoute(builder: (_) => const CommunityScreen()),
                );
              } else if (module.id == 'translate') {
                Navigator.of(rootContext).push(
                  MaterialPageRoute(builder: (_) => const TranslateScreen()),
                );
              } else if (module.id == 'achievement') {
                Navigator.of(rootContext).push(
                  MaterialPageRoute(builder: (_) => const AchievementScreen()),
                );
              } else if (module.id == 'transport') {
                Navigator.of(rootContext).push(
                  MaterialPageRoute(builder: (_) => const BusSchedulePage()),
                );
              } else if (module.id == 'car_rental') {
                Navigator.of(rootContext).push(
                  MaterialPageRoute(builder: (_) => const NearbyCarsScreen()),
                );
              } else if (module.id == 'trips') {
                Navigator.of(rootContext).push(
                  MaterialPageRoute(builder: (_) => const CreateTripScreen()),
                );
              } else {
                ScaffoldMessenger.of(rootContext).showSnackBar(
                  SnackBar(content: Text('${module.label} module coming soon')),
                );
              }
            },
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Build each tab only once it has been visited, avoiding eager initialization
    // of heavy screens like MapViewScreen (GPS + Maps API) and ProfileScreen (Firestore).
    Widget _lazyTab(int index, Widget Function() builder) {
      if (!_visitedTabs.contains(index)) return const SizedBox.shrink();
      return builder();
    }

    final pages = [
      HomeView(
        notificationCount: _notificationCount,
        onClearNotifications: () => setState(() => _notificationCount = 0),
        onModuleTap: _openModule,
        moduleCatalog: _moduleCatalog,
        onNavigateToTrips: () => setState(() {
          _tabIndex = 2;
          _visitedTabs.add(2);
        }),
      ),
      _lazyTab(1, () => const MapViewScreen()),
      _lazyTab(2, () => const SavedPlansScreen()),
      _lazyTab(3, () => const ProfileScreen()),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      body: SafeArea(child: IndexedStack(index: _tabIndex, children: pages)),
      floatingActionButton: _AiGuideButton(
        onPressed: () {
          final chatbot = _moduleCatalog.firstWhere((m) => m.id == 'chatbot');
          _openModule(chatbot);
        },
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: (index) => setState(() {
          _tabIndex = index;
          _visitedTabs.add(index);
        }),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_rounded), label: 'Home'),
          NavigationDestination(
            icon: Icon(Icons.explore_rounded),
            label: 'Explore',
          ),
          NavigationDestination(icon: Icon(Icons.favorite_rounded), label: 'Saved'),
          NavigationDestination(
            icon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class _AiGuideButton extends StatelessWidget {
  const _AiGuideButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'AI Guide',
      button: true,
      child: Material(
        color: Colors.transparent,
        elevation: 8,
        shape: const CircleBorder(),
        shadowColor: const Color(0x4D3B82F6),
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: Ink(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [Color(0xFF2563EB), Color(0xFF60A5FA)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: const Center(
              child: Icon(
                Icons.auto_awesome_rounded,
                color: Colors.white,
                size: 26,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class HomeView extends StatelessWidget {
  const HomeView({
    super.key,
    required this.notificationCount,
    required this.onClearNotifications,
    required this.onModuleTap,
    required this.moduleCatalog,
    required this.onNavigateToTrips,
  });

  final int notificationCount;
  final VoidCallback onClearNotifications;
  final ValueChanged<ModuleItem> onModuleTap;
  final List<ModuleItem> moduleCatalog;
  final VoidCallback onNavigateToTrips;

  @override
  Widget build(BuildContext context) {
    final quickModules =
        [
          _quickItem('trips'),
          _quickItem('accommodation'),
          _quickItem('transport'),
          _quickItem('car_rental'),
          _quickItem('events'),
          _quickItem('bills'),
          _quickItem('payment'),
          _quickItem('community'),
          _quickItem('translate'),
          _quickItem('achievement'),
        ].whereType<ModuleItem>().toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Header(
            notificationCount: notificationCount,
            onClearNotifications: onClearNotifications,
          ),
          const SizedBox(height: 16),
          _SeasonTripsSection(onNavigateToTrips: onNavigateToTrips),
          const SizedBox(height: 16),
          Text(
            'Main Modules',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 8,
            mainAxisSpacing: 12,
            children: [
              for (final item in quickModules)
                _ModuleTile(module: item, onTap: () => onModuleTap(item)),
            ],
          ),
        ],
      ),
    );
  }

  ModuleItem? _quickItem(String id) {
    for (final item in moduleCatalog) {
      if (item.id == id) return item;
    }
    return null;
  }
}

class ModuleSheet extends StatelessWidget {
  const ModuleSheet({
    super.key,
    required this.module,
    required this.onOpenModule,
  });

  final ModuleItem module;
  final VoidCallback onOpenModule;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        8,
        20,
        24 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: module.color.withOpacity(0.15),
                child: Icon(module.icon, color: module.color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      module.label,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      module.subtitle,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: Colors.black54),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Key Functions',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ...module.features.map(
            (feature) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.check_circle, size: 18, color: Colors.green),
                  const SizedBox(width: 8),
                  Expanded(child: Text(feature)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onOpenModule,
              child: const Text('Open Module'),
            ),
          ),
        ],
      ),
    );
  }
}

class ModuleItem {
  const ModuleItem({
    required this.id,
    required this.label,
    required this.icon,
    required this.color,
    required this.subtitle,
    required this.features,
  });

  final String id;
  final String label;
  final IconData icon;
  final Color color;
  final String subtitle;
  final List<String> features;
}

// ── Seasonal Trip data models ──────────────────────────────────────────────

class TripActivity {
  final String title;
  final String subtitle;
  final String duration;
  final String imageUrl;

  TripActivity({
    required this.title,
    required this.subtitle,
    required this.duration,
    required this.imageUrl,
  });
}

class SeasonalTrip {
  final String title;
  final String location;
  final String tag;
  final String imageUrl;
  final int durationDays;
  final Map<String, List<TripActivity>> itinerary;

  SeasonalTrip({
    required this.title,
    required this.location,
    required this.tag,
    required this.imageUrl,
    required this.durationDays,
    required this.itinerary,
  });
}

// ── Season Trips Section widget ────────────────────────────────────────────

class _SeasonTripsSection extends StatelessWidget {
  const _SeasonTripsSection({required this.onNavigateToTrips});

  final VoidCallback onNavigateToTrips;

  static final List<SeasonalTrip> _trips = [
    SeasonalTrip(
      title: 'Penang Food & Heritage',
      location: 'Penang, Malaysia',
      tag: 'Cultural',
      imageUrl:
          'https://images.unsplash.com/photo-1596423735880-5f2a689b903e?auto=format&fit=crop&w=800&q=80',
      durationDays: 2,
      itinerary: {
        'day_0': [
          TripActivity(
            title: 'Georgetown Street Art Walk',
            subtitle: 'Explore famous murals and historic streets.',
            duration: '120 min',
            imageUrl:
                'https://images.unsplash.com/photo-1510155093557-41804f323a7e?auto=format&fit=crop&w=800&q=80',
          ),
          TripActivity(
            title: 'Clan Jetties Visit',
            subtitle: 'Experience the traditional water villages.',
            duration: '90 min',
            imageUrl:
                'https://images.unsplash.com/photo-1582236302061-07b1a1ddf4fa?auto=format&fit=crop&w=800&q=80',
          ),
        ],
        'day_1': [
          TripActivity(
            title: 'Penang Hill Funicular',
            subtitle: 'Ride up for a panoramic view of the island.',
            duration: '3 hours',
            imageUrl:
                'https://images.unsplash.com/photo-1601004113010-093f1cc43026?auto=format&fit=crop&w=800&q=80',
          ),
          TripActivity(
            title: 'Kek Lok Si Temple',
            subtitle: 'Visit the largest Buddhist temple in Malaysia.',
            duration: '2 hours',
            imageUrl:
                'https://images.unsplash.com/photo-1663085542385-d6a13db3065a?auto=format&fit=crop&w=800&q=80',
          ),
        ],
      },
    ),
    SeasonalTrip(
      title: 'KL City Escape',
      location: 'Kuala Lumpur, Malaysia',
      tag: 'Popular',
      imageUrl:
          'https://images.unsplash.com/photo-1513415564515-763d91423bdd?auto=format&fit=crop&w=800&q=80',
      durationDays: 2,
      itinerary: {
        'day_0': [
          TripActivity(
            title: 'Petronas Twin Towers',
            subtitle: 'Visit the iconic towers and KLCC park.',
            duration: '2 hours',
            imageUrl:
                'https://images.unsplash.com/photo-1584646098378-0874589d79b1?auto=format&fit=crop&w=800&q=80',
          ),
          TripActivity(
            title: 'Saloma Link Bridge',
            subtitle: 'Night walk with LED light views.',
            duration: '60 min',
            imageUrl:
                'https://images.unsplash.com/photo-1620600293189-e771e06d9539?auto=format&fit=crop&w=800&q=80',
          ),
        ],
        'day_1': [
          TripActivity(
            title: 'Batu Caves Exploration',
            subtitle: 'Climb the 272 colorful steps.',
            duration: '3 hours',
            imageUrl:
                'https://images.unsplash.com/photo-1544256608-f4ee0b59b1dc?auto=format&fit=crop&w=800&q=80',
          ),
          TripActivity(
            title: 'Jalan Alor Food Street',
            subtitle: 'Taste the best local street food.',
            duration: '2 hours',
            imageUrl:
                'https://images.unsplash.com/photo-1555939594-58d7cb561ad1?auto=format&fit=crop&w=800&q=80',
          ),
        ],
      },
    ),
    SeasonalTrip(
      title: 'Langkawi Island Retreat',
      location: 'Kedah, Malaysia',
      tag: 'Nature',
      imageUrl:
          'https://images.unsplash.com/photo-1518509562904-e7ef99cdcc86?auto=format&fit=crop&w=800&q=80',
      durationDays: 2,
      itinerary: {
        'day_0': [
          TripActivity(
            title: 'Langkawi Sky Bridge',
            subtitle: 'Walk above the rainforest canopy.',
            duration: '3 hours',
            imageUrl:
                'https://images.unsplash.com/photo-1540979844053-619f783d5a22?auto=format&fit=crop&w=800&q=80',
          ),
          TripActivity(
            title: 'Pantai Cenang Sunset',
            subtitle: 'Relax by the beach and watch the fire show.',
            duration: '2 hours',
            imageUrl:
                'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?auto=format&fit=crop&w=800&q=80',
          ),
        ],
        'day_1': [
          TripActivity(
            title: 'Island Hopping Tour',
            subtitle: 'Visit Dayang Bunting and Beras Basah.',
            duration: '4 hours',
            imageUrl:
                'https://images.unsplash.com/photo-1518509562904-e7ef99cdcc86?auto=format&fit=crop&w=800&q=80',
          ),
          TripActivity(
            title: 'Eagle Square',
            subtitle: 'Take photos at Dataran Lang.',
            duration: '60 min',
            imageUrl:
                'https://images.unsplash.com/photo-1618349275069-b4de8cfdfb24?auto=format&fit=crop&w=800&q=80',
          ),
        ],
      },
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Season Trip Plans',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            Text(
              'See All',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF2563EB),
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 300,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _trips.length,
            itemBuilder: (context, index) {
              final trip = _trips[index];
              return GestureDetector(
                onTap: () async {
                  final result = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => TripSchedulePage(tripTemplate: trip),
                    ),
                  );
                  if (result == true) onNavigateToTrips();
                },
                child: _buildCard(trip),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Click on a curated seasonal trip above to view its daily schedule and add it to your plans.',
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: Colors.black54),
        ),
      ],
    );
  }

  Widget _buildCard(SeasonalTrip trip) {
    return Container(
      width: 240,
      margin: const EdgeInsets.only(right: 14),
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(20),
        image: DecorationImage(
          image: CachedNetworkImageProvider(trip.imageUrl),
          fit: BoxFit.cover,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.black.withOpacity(0.75)],
                stops: const [0.5, 1.0],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    trip.tag,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  trip.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.place, color: Colors.white70, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      trip.location,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
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
  }
}

// ──────────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({
    required this.notificationCount,
    required this.onClearNotifications,
  });

  final int notificationCount;
  final VoidCallback onClearNotifications;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const CircleAvatar(
          radius: 20,
          backgroundImage: CachedNetworkImageProvider(
            'https://api.dicebear.com/7.x/avataaars/svg?seed=Alex',
          ),
          backgroundColor: Color(0xFFDBEAFE),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Good Morning,',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.black54),
              ),
              StreamBuilder<User?>(
                stream: FirebaseAuth.instance.userChanges(),
                builder: (context, snapshot) {
                  final displayName = _displayNameFor(
                    snapshot.data ?? FirebaseAuth.instance.currentUser,
                  );
                  return Text(
                    displayName,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: onClearNotifications,
          icon: Badge(
            isLabelVisible: notificationCount > 0,
            label: Text(notificationCount.toString()),
            child: const Icon(Icons.notifications_none_rounded),
          ),
        ),
      ],
    );
  }
}


class _ModuleTile extends StatelessWidget {
  const _ModuleTile({required this.module, required this.onTap});

  final ModuleItem module;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 52,
            width: 52,
            decoration: BoxDecoration(
              color: module.color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(module.icon, color: module.color),
          ),
          const SizedBox(height: 6),
          Text(
            module.label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

