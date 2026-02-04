import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'auth/login_screen.dart';
import 'accommodation/accommodation_screen.dart';
import 'bill_tracking/bill_tracking_screen.dart';
import 'chatbot/chatbot_screen.dart';
import 'event_management/event_management.dart';
import 'community/community_screen.dart';
import 'payment/payment_screen.dart';

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
  await FirebaseAuth.instance.signOut();
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
        if (snapshot.hasData) {
          return const MainShell();
        }
        return const LoginScreen();
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
  String _searchQuery = '';

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
      id: 'explore',
      label: 'Explore',
      icon: Icons.explore_rounded,
      color: Color(0xFF3B82F6),
      subtitle: 'Discover places',
      features: [
        'Top destinations and highlights',
        'City details and attractions',
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
      label: 'Transport',
      icon: Icons.directions_bus_rounded,
      color: Color(0xFFFBBF24),
      subtitle: 'Bus & car rental',
      features: ['Bus booking and tickets', 'Car rental booking'],
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
    final pages = [
      HomeView(
        notificationCount: _notificationCount,
        onClearNotifications: () => setState(() => _notificationCount = 0),
        searchQuery: _searchQuery,
        onSearchChanged: (value) => setState(() => _searchQuery = value),
        onModuleTap: _openModule,
        moduleCatalog: _moduleCatalog,
      ),
      const ExploreView(),
      TripsView(
        onOpenBills: () {
          final bills = _moduleCatalog.firstWhere((m) => m.id == 'bills');
          _openModule(bills);
        },
      ),
      const ProfileView(),
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
        onDestinationSelected: (index) => setState(() => _tabIndex = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_rounded), label: 'Home'),
          NavigationDestination(
            icon: Icon(Icons.explore_rounded),
            label: 'Explore',
          ),
          NavigationDestination(icon: Icon(Icons.map_rounded), label: 'Trips'),
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
    required this.searchQuery,
    required this.onSearchChanged,
    required this.onModuleTap,
    required this.moduleCatalog,
  });

  final int notificationCount;
  final VoidCallback onClearNotifications;
  final String searchQuery;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<ModuleItem> onModuleTap;
  final List<ModuleItem> moduleCatalog;

  @override
  Widget build(BuildContext context) {
    final quickModules =
        [
          _quickItem('explore'),
          _quickItem('trips'),
          _quickItem('accommodation'),
          _quickItem('transport'),
          _quickItem('events'),
          _quickItem('bills'),
          _quickItem('payment'),
          _quickItem('community'),
        ].whereType<ModuleItem>().toList();

    final filtered =
        quickModules
            .where(
              (m) => m.label.toLowerCase().contains(
                searchQuery.toLowerCase().trim(),
              ),
            )
            .toList();

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
          _SearchField(value: searchQuery, onChanged: onSearchChanged),
          const SizedBox(height: 16),
          if (searchQuery.isEmpty) const _HeroCard(),
          if (searchQuery.isEmpty) const SizedBox(height: 16),
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
              for (final item in filtered)
                _ModuleTile(module: item, onTap: () => onModuleTap(item)),
            ],
          ),
          const SizedBox(height: 16),
          _CommunityCard(
            onTap: () {
              final community = moduleCatalog.firstWhere(
                (m) => m.id == 'community',
              );
              onModuleTap(community);
            },
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

class ExploreView extends StatelessWidget {
  const ExploreView({super.key});

  @override
  Widget build(BuildContext context) {
    final cities = const [
      _CityCard(title: 'Kyoto', color: Color(0xFFFBCFE8)),
      _CityCard(title: 'Bali', color: Color(0xFF99F6E4)),
      _CityCard(title: 'Iceland', color: Color(0xFFBFDBFE)),
      _CityCard(title: 'Rome', color: Color(0xFFFED7AA)),
      _CityCard(title: 'Paris', color: Color(0xFFE9D5FF)),
      _CityCard(title: 'New York', color: Color(0xFFE5E7EB)),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Explore World',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            children: cities,
          ),
        ],
      ),
    );
  }
}

class TripsView extends StatelessWidget {
  const TripsView({super.key, required this.onOpenBills});

  final VoidCallback onOpenBills;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'My Trips',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _TripCard(
            title: 'Tokyo Adventure',
            dateRange: 'Oct 15 - Oct 22',
            status: 'UPCOMING',
            statusColor: const Color(0xFFDBEAFE),
            statusTextColor: const Color(0xFF2563EB),
            primaryAction: 'Itinerary',
            secondaryAction: 'Budget',
            onSecondaryTap: onOpenBills,
          ),
          const SizedBox(height: 12),
          const _TripCard(
            title: 'Paris Weekend',
            dateRange: 'Sep 05 - Sep 07',
            status: 'PAST',
            statusColor: Color(0xFFE5E7EB),
            statusTextColor: Color(0xFF6B7280),
            isDisabled: true,
          ),
        ],
      ),
    );
  }
}

class ProfileView extends StatefulWidget {
  const ProfileView({super.key});

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  final TextEditingController _nameController = TextEditingController();
  bool _isSaving = false;
  String? _statusMessage;
  String _lastLoadedName = '';

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _syncName(User? user) {
    final name = _displayNameFor(user);
    final currentText = _nameController.text.trim();
    if (currentText.isEmpty || currentText == _lastLoadedName) {
      _nameController.text = name;
      _lastLoadedName = name;
    }
  }

  Future<void> _saveName(User? user) async {
    if (_isSaving) return;
    final trimmed = _nameController.text.trim();
    if (trimmed.isEmpty) {
      setState(() => _statusMessage = 'Name cannot be empty.');
      return;
    }
    if (user == null) {
      setState(() => _statusMessage = 'No signed-in user.');
      return;
    }
    setState(() {
      _isSaving = true;
      _statusMessage = null;
    });
    try {
      await user.updateDisplayName(trimmed);
      await user.reload();
      final refreshed = FirebaseAuth.instance.currentUser;
      _lastLoadedName = _displayNameFor(refreshed);
      setState(() => _statusMessage = 'Name updated.');
    } catch (_) {
      setState(() => _statusMessage = 'Unable to update name.');
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = [
      const _ProfileItem(
        icon: Icons.credit_card_rounded,
        label: 'Payment Methods',
      ),
      const _ProfileItem(icon: Icons.settings_rounded, label: 'Settings'),
      const _ProfileItem(icon: Icons.translate_rounded, label: 'Language'),
      _ProfileItem(
        icon: Icons.logout_rounded,
        label: 'Log Out',
        isDestructive: true,
        onTap: () async {
          await FirebaseAuth.instance.signOut();
        },
      ),
    ];

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.userChanges(),
      builder: (context, snapshot) {
        final user = snapshot.data ?? FirebaseAuth.instance.currentUser;
        _syncName(user);
        final displayName = _displayNameFor(user);
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const SizedBox(height: 16),
              const CircleAvatar(
                radius: 44,
                backgroundImage: NetworkImage(
                  'https://api.dicebear.com/7.x/avataaars/svg?seed=Alex',
                ),
                backgroundColor: Color(0xFFE5E7EB),
              ),
              const SizedBox(height: 12),
              Text(
                displayName,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                'Level 12 • Globe Trotter',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFFF59E0B),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 20),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Personal Info',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _nameController,
                        textInputAction: TextInputAction.done,
                        decoration: const InputDecoration(
                          labelText: 'Display name',
                          prefixIcon: Icon(Icons.person_rounded),
                        ),
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: _isSaving ? null : () => _saveName(user),
                        child:
                            _isSaving
                                ? const SizedBox(
                                  height: 16,
                                  width: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                                : const Text('Save Name'),
                      ),
                      if (_statusMessage != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          _statusMessage!,
                          style: TextStyle(
                            color:
                                _statusMessage == 'Name updated.'
                                    ? Colors.green
                                    : Colors.redAccent,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              for (final item in items) _ProfileTile(item: item),
            ],
          ),
        );
      },
    );
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
          backgroundImage: NetworkImage(
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

class _SearchField extends StatelessWidget {
  const _SearchField({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: 'Where to next? or Find a tool...',
        prefixIcon: const Icon(Icons.search_rounded),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Color(0xFF2563EB), Color(0xFF4F46E5)],
        ),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Upcoming',
                  style: TextStyle(color: Colors.white),
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Colors.white70),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Tokyo Adventure',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Oct 15 - Oct 22 • 4 Guests',
            style: TextStyle(color: Color(0xFFBFDBFE)),
          ),
          const SizedBox(height: 12),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF1D4ED8),
            ),
            onPressed: () {},
            child: const Text('View Itinerary'),
          ),
        ],
      ),
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

class _CommunityCard extends StatelessWidget {
  const _CommunityCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFCFFAFE),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.people_outline_rounded,
                color: Color(0xFF0891B2),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Community Hub',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "3 new posts in 'Solo Travelers'",
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: Colors.black54),
                  ),
                ],
              ),
            ),
            const CircleAvatar(radius: 12, backgroundColor: Color(0xFFE5E7EB)),
            const SizedBox(width: 4),
            const CircleAvatar(radius: 12, backgroundColor: Color(0xFFE5E7EB)),
            const SizedBox(width: 4),
            const CircleAvatar(radius: 12, backgroundColor: Color(0xFFE5E7EB)),
          ],
        ),
      ),
    );
  }
}

class _CityCard extends StatelessWidget {
  const _CityCard({required this.title, required this.color});

  final String title;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.08),
                borderRadius: BorderRadius.circular(18),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomLeft,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TripCard extends StatelessWidget {
  const _TripCard({
    required this.title,
    required this.dateRange,
    required this.status,
    required this.statusColor,
    required this.statusTextColor,
    this.primaryAction,
    this.secondaryAction,
    this.onSecondaryTap,
    this.isDisabled = false,
  });

  final String title;
  final String dateRange;
  final String status;
  final Color statusColor;
  final Color statusTextColor;
  final String? primaryAction;
  final String? secondaryAction;
  final VoidCallback? onSecondaryTap;
  final bool isDisabled;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isDisabled ? Colors.black45 : Colors.black87,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  status,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: statusTextColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(
                Icons.calendar_today_rounded,
                size: 16,
                color: Colors.black54,
              ),
              const SizedBox(width: 6),
              Text(
                dateRange,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.black54),
              ),
            ],
          ),
          if (!isDisabled && primaryAction != null && secondaryAction != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: () {},
                      child: Text(primaryAction!),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onSecondaryTap,
                      child: Text(secondaryAction!),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ProfileItem {
  const _ProfileItem({
    required this.icon,
    required this.label,
    this.isDestructive = false,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isDestructive;
  final Future<void> Function()? onTap;
}

class _ProfileTile extends StatelessWidget {
  const _ProfileTile({required this.item});

  final _ProfileItem item;

  @override
  Widget build(BuildContext context) {
    final color = item.isDestructive ? Colors.red : Colors.black87;
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        leading: Icon(item.icon, color: color),
        title: Text(item.label, style: TextStyle(color: color)),
        trailing: const Icon(
          Icons.chevron_right_rounded,
          color: Colors.black38,
        ),
        onTap:
            item.onTap == null
                ? null
                : () async {
                  await item.onTap?.call();
                },
      ),
    );
  }
}
