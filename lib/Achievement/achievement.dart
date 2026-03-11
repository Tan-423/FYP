import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; // ⭐ Added for Auth

class AchievementScreen extends StatefulWidget {
  const AchievementScreen({super.key});

  @override
  State<AchievementScreen> createState() => _AchievementScreenState();
}

class _AchievementScreenState extends State<AchievementScreen> {
  // ⭐ THE FIX: DYNAMICALLY FETCH THE CURRENT LOGGED-IN USER'S EMAIL
  String get userEmail =>
      FirebaseAuth.instance.currentUser?.email ?? 'guest@example.com';

  // DYNAMIC EXPLORATION PLAN (5 States x 5 Landmarks)
  final List<Map<String, dynamic>> explorationQuests = [
    {
      "id": "kl",
      "title": "Kuala Lumpur Explorer",
      "description": "Visit 5 iconic landmarks in the heart of Malaysia.",
      "total": 5,
      "badgeName": "KL Skyrise Master",
      "badgeIcon": Icons.location_city,
      "badgeColor": Colors.amber,
      "image":
          "https://images.unsplash.com/photo-1596422846543-74c6e27a69c5?auto=format&fit=crop&w=600&q=80",
      "targets": [
        {"name": "Petronas Twin Towers", "lat": 3.1578, "lng": 101.7115},
        {"name": "Batu Caves", "lat": 3.2379, "lng": 101.6830},
        {"name": "KL Tower", "lat": 3.1528, "lng": 101.7038},
        {"name": "Merdeka 118", "lat": 3.1390, "lng": 101.7000},
        {"name": "Sultan Abdul Samad Building", "lat": 3.1486, "lng": 101.6945},
      ],
    },
    {
      "id": "penang",
      "title": "Penang Heritage Trail",
      "description": "Discover the street art and history of Penang.",
      "total": 5,
      "badgeName": "Heritage Curator",
      "badgeIcon": Icons.brush_rounded,
      "badgeColor": Colors.cyan,
      "image":
          "https://images.unsplash.com/photo-1520111166318-68740c0b1154?auto=format&fit=crop&w=600&q=80",
      "targets": [
        {"name": "Kek Lok Si Temple", "lat": 5.3995, "lng": 100.2736},
        {"name": "Penang Hill", "lat": 5.4222, "lng": 100.2690},
        {"name": "Georgetown Street Art", "lat": 5.4140, "lng": 100.3370},
        {"name": "Clan Jetties", "lat": 5.4124, "lng": 100.3398},
        {"name": "Batu Ferringhi Beach", "lat": 5.4749, "lng": 100.2450},
      ],
    },
    {
      "id": "johor",
      "title": "Johor Southern Charm",
      "description": "Explore the vibrant landmarks of Southern Malaysia.",
      "total": 5,
      "badgeName": "Southern Guardian",
      "badgeIcon": Icons.castle_rounded,
      "badgeColor": Colors.deepPurple,
      "image":
          "https://images.unsplash.com/photo-1620600293189-e771e06d9539?auto=format&fit=crop&w=600&q=80",
      "targets": [
        {"name": "Legoland Malaysia", "lat": 1.4274, "lng": 103.6299},
        {"name": "Sultan Abu Bakar Mosque", "lat": 1.4560, "lng": 103.7583},
        {
          "name": "Arulmigu Sri Rajakaliamman Temple",
          "lat": 1.4678,
          "lng": 103.7590,
        },
        {"name": "Istana Besar", "lat": 1.4542, "lng": 103.7569},
        {"name": "Desaru Beach", "lat": 1.5600, "lng": 104.2500},
      ],
    },
    {
      "id": "kedah",
      "title": "Kedah Jewel of the North",
      "description": "Unlock the beauty of Kedah and Langkawi.",
      "total": 5,
      "badgeName": "Crown of Kedah",
      "badgeIcon": Icons.terrain_rounded,
      "badgeColor": Colors.green,
      "image":
          "https://images.unsplash.com/photo-1667468649887-a06ae663d27d?auto=format&fit=crop&w=600&q=80",
      "targets": [
        {"name": "Langkawi Sky Bridge", "lat": 6.3860, "lng": 99.6620},
        {"name": "Eagle Square (Dataran Lang)", "lat": 6.3090, "lng": 99.8510},
        {"name": "Alor Setar Tower", "lat": 6.1242, "lng": 100.3663},
        {"name": "Zahir Mosque", "lat": 6.1189, "lng": 100.3667},
        {"name": "Lembah Bujang Museum", "lat": 5.7369, "lng": 100.4136},
      ],
    },
    {
      "id": "ipoh",
      "title": "Ipoh Historic Journey",
      "description": "Experience the caves and castles of Perak.",
      "total": 5,
      "badgeName": "Ipoh Cavern King",
      "badgeIcon": Icons.landscape_rounded,
      "badgeColor": Colors.orange,
      "image":
          "https://images.unsplash.com/photo-1658406730303-34e40e6ae96e?auto=format&fit=crop&w=600&q=80",
      "targets": [
        {"name": "Kellie's Castle", "lat": 4.4750, "lng": 101.1130},
        {"name": "Perak Cave Temple", "lat": 4.6290, "lng": 101.0880},
        {"name": "Ipoh Railway Station", "lat": 4.5970, "lng": 101.0730},
        {"name": "Concubine Lane", "lat": 4.5960, "lng": 101.0780},
        {"name": "Sam Poh Tong Temple", "lat": 4.5610, "lng": 101.1130},
      ],
    },
  ];

  final List<Map<String, dynamic>> availableRewards = [
    {
      "id": "1",
      "title": "RM 10 Grab Ride Discount",
      "cost": 500,
      "image":
          "https://images.unsplash.com/photo-1549317661-bd32c8ce0db2?auto=format&fit=crop&w=400&q=80",
      "description":
          "Get RM 10 off your next ride to any landmark. Valid for 30 days.",
    },
    {
      "id": "2",
      "title": "Free Coffee at KLCC",
      "cost": 300,
      "image":
          "https://images.unsplash.com/photo-1497935586351-b67a49e012bf?auto=format&fit=crop&w=400&q=80",
      "description":
          "Redeem a free regular coffee at participating cafes near KLCC.",
    },
  ];

  // ========================================================
  // DATABASE SAVING LOGIC
  // ========================================================

  // Creates a starting database profile if it doesn't exist
  Future<void> _initializeDatabase() async {
    final docRef = FirebaseFirestore.instance
        .collection('user_achievements')
        .doc(userEmail);
    final docSnap = await docRef.get();
    if (!docSnap.exists) {
      await docRef.set({
        'points': 100, // Give 100 starting points
        'verifiedLandmarks': [],
        'completedStates': [],
      });
      _showMessage("Database Initialized!");
    }
  }

  // Deducts points when redeeming
  Future<void> _redeemRewardFromDB(
    Map<String, dynamic> reward,
    int currentPoints,
  ) async {
    if (currentPoints >= reward['cost']) {
      await FirebaseFirestore.instance
          .collection('user_achievements')
          .doc(userEmail)
          .update({
            'points': FieldValue.increment(-reward['cost']), // Deduct points
          });
      Navigator.pop(context);
      _showSuccessDialog(
        "Reward Redeemed!",
        "You have successfully claimed: ${reward['title']}",
      );
    } else {
      _showMessage("Not enough points to redeem this reward.");
    }
  }

  // Adds points and records the landmark visit
  Future<void> _verifyLandmarkVisit(
    int questIndex,
    List<dynamic> verifiedList,
  ) async {
    Map<String, dynamic> quest = explorationQuests[questIndex];
    int currentProgress =
        quest['targets'].where((t) => verifiedList.contains(t['name'])).length;

    if (currentProgress >= quest['total']) {
      _showMessage("You have already completed this state's badge!");
      return;
    }

    // Find the next unvisited target
    Map<String, dynamic>? assignedTarget;
    for (var t in quest['targets']) {
      if (!verifiedList.contains(t['name'])) {
        assignedTarget = t;
        break;
      }
    }

    if (assignedTarget == null) return;

    _showProcessingDialog("Acquiring GPS Location...");

    try {
      // 1. Check GPS Services
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        Navigator.pop(context);
        _showMessage("Please enable GPS/Location services.");
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          Navigator.pop(context);
          _showMessage("Location permissions are denied.");
          return;
        }
      }

      // 2. Get Device Location & Calculate Distance
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      Navigator.pop(context); // Close GPS Dialog

      double distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        assignedTarget['lat'],
        assignedTarget['lng'],
      );

      if (distance > 500.0) {
        _showErrorDialog(
          "Wrong Location",
          "Your target is ${assignedTarget['name']}.\nYou are ${distance.toStringAsFixed(0)} meters away. You must be within 500m to verify.",
        );
        return;
      }

      // 3. GPS MATCHED! Prompt for Camera
      final ImagePicker picker = ImagePicker();
      final XFile? photo = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
      );

      if (photo == null) {
        _showMessage("Verification cancelled. Photo proof is required.");
        return;
      }

      // 4. Simulated AI Vision Analysis
      _showProcessingDialog(
        "AI Vision: Identifying ${assignedTarget['name']}...",
      );
      await Future.delayed(const Duration(seconds: 3));
      Navigator.pop(context);

      // 5. ⭐ SAVE PROGRESS TO FIREBASE ⭐
      bool isStateComplete = (currentProgress + 1) >= quest['total'];

      final docRef = FirebaseFirestore.instance
          .collection('user_achievements')
          .doc(userEmail);
      final docSnap = await docRef.get();

      if (!docSnap.exists) {
        // Create doc if it somehow doesn't exist
        await docRef.set({
          'points': 200,
          'verifiedLandmarks': [assignedTarget['name']],
          'completedStates': isStateComplete ? [quest['id']] : [],
        });
      } else {
        // Update existing doc
        await docRef.update({
          'points': FieldValue.increment(200), // Add 200 points
          'verifiedLandmarks': FieldValue.arrayUnion([assignedTarget['name']]),
          if (isStateComplete)
            'completedStates': FieldValue.arrayUnion([quest['id']]),
        });
      }

      _showSuccessDialog(
        "Landmark Verified!",
        "AI recognized ${assignedTarget['name']}. You earned 200 points! (${currentProgress + 1}/${quest['total']} completed)",
      );
    } catch (e) {
      if (mounted) Navigator.pop(context);
      _showMessage("Error verifying location: $e");
    }
  }

  // ========================================================
  // UI BUILDERS
  // ========================================================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const primaryBlue = Color(0xFF3B82F6);
    final isDark = theme.brightness == Brightness.dark;

    // ⭐ STREAM BUILDER: Listens to the specific user's database in real-time
    return StreamBuilder<DocumentSnapshot>(
      stream:
          FirebaseFirestore.instance
              .collection('user_achievements')
              .doc(userEmail)
              .snapshots(),
      builder: (context, snapshot) {
        // Default values while loading
        int currentPoints = 0;
        List<dynamic> verifiedLandmarks = [];
        List<dynamic> completedStates = [];

        // Apply data from database if it exists
        if (snapshot.hasData && snapshot.data!.exists) {
          var data = snapshot.data!.data() as Map<String, dynamic>;
          currentPoints = data['points'] ?? 0;
          verifiedLandmarks = data['verifiedLandmarks'] ?? [];
          completedStates = data['completedStates'] ?? [];
        }

        // Generate list of completed badges dynamically based on DB data
        List<Map<String, dynamic>> earnedBadges =
            explorationQuests
                .where((q) => completedStates.contains(q['id']))
                .toList();

        return Scaffold(
          extendBody: true,
          backgroundColor:
              isDark ? const Color(0xFF111827) : const Color(0xFFF3F4F6),
          body: Stack(
            children: [
              SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(context),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Database Initializer (Helper Button if DB is empty for a new user)
                          if (!snapshot.hasData || !snapshot.data!.exists)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: Center(
                                child: TextButton(
                                  onPressed: _initializeDatabase,
                                  child: const Text(
                                    "Initialize Database Points",
                                  ),
                                ),
                              ),
                            ),

                          // Displays Live Points
                          _buildTotalPointsCard(
                            context,
                            primaryBlue,
                            currentPoints,
                          ),
                          const SizedBox(height: 32),

                          _buildSectionHeader(
                            context,
                            "State Explorations",
                            "View Map",
                            primaryBlue,
                          ),
                          const SizedBox(height: 16),

                          SizedBox(
                            height: 380,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              physics: const BouncingScrollPhysics(),
                              itemCount: explorationQuests.length,
                              itemBuilder: (context, index) {
                                return Padding(
                                  padding: const EdgeInsets.only(right: 16),
                                  child: SizedBox(
                                    width: 280,
                                    child: _buildActiveQuestCard(
                                      context,
                                      index,
                                      primaryBlue,
                                      verifiedLandmarks,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 32),

                          _buildSectionHeader(
                            context,
                            "Available Rewards",
                            "See all",
                            primaryBlue,
                          ),
                          const SizedBox(height: 16),
                          ...availableRewards
                              .map(
                                (reward) => _buildRewardListItem(
                                  context,
                                  reward,
                                  primaryBlue,
                                  currentPoints,
                                ),
                              )
                              .toList(),
                          const SizedBox(height: 32),

                          _buildSectionHeader(
                            context,
                            "Earned Badges",
                            "View Trophy Room",
                            primaryBlue,
                          ),
                          const SizedBox(height: 16),
                          earnedBadges.isEmpty
                              ? Padding(
                                padding: const EdgeInsets.all(16),
                                child: Center(
                                  child: Text(
                                    "Complete an exploration plan to earn badges.",
                                    style: TextStyle(color: Colors.grey[500]),
                                  ),
                                ),
                              )
                              : Column(
                                children:
                                    earnedBadges
                                        .map(
                                          (badgeData) => Padding(
                                            padding: const EdgeInsets.only(
                                              bottom: 12,
                                            ),
                                            child: _buildCompletedBadgeCard(
                                              context,
                                              badgeData,
                                            ),
                                          ),
                                        )
                                        .toList(),
                              ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        bottom: 16,
        left: 24,
        right: 24,
      ),
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => Navigator.pop(context),
            color: Theme.of(context).colorScheme.onSurface,
          ),
          Text(
            "Achievements",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.history_rounded),
            onPressed: () {},
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ],
      ),
    );
  }

  Widget _buildTotalPointsCard(
    BuildContext context,
    Color primaryColor,
    int pts,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primaryColor, primaryColor.withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 10),
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
                "Available Points",
                style: TextStyle(
                  color: Color(0xFFDBEAFE),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: "$pts ",
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const TextSpan(
                      text: "pts",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.normal,
                        color: Color(0xFFDBEAFE),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.stars_rounded,
              color: Colors.white,
              size: 40,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveQuestCard(
    BuildContext context,
    int index,
    Color primaryColor,
    List<dynamic> verifiedList,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    Map<String, dynamic> quest = explorationQuests[index];

    // Calculate progress directly from DB
    int progress =
        quest['targets'].where((t) => verifiedList.contains(t['name'])).length;
    int total = quest['total'];
    double progressPercent = progress / total;

    String currentTargetName = "All targets visited!";
    for (var t in quest['targets']) {
      if (!verifiedList.contains(t['name'])) {
        currentTargetName = t['name'];
        break;
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Stack(
            children: [
              Container(
                height: 140,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[800] : Colors.grey[300],
                ),
                child: Image.network(
                  quest['image'],
                  fit: BoxFit.cover,
                  errorBuilder:
                      (context, error, stackTrace) => const Center(
                        child: Icon(
                          Icons.location_city,
                          size: 50,
                          color: Colors.grey,
                        ),
                      ),
                ),
              ),
              if (progress >= total)
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      "Completed",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    quest['title'],
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Next Target: $currentTargetName\nMust be within 500m.",
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Spacer(),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Milestone Progress",
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      Text(
                        "$progress/$total Verified",
                        style: TextStyle(
                          fontSize: 12,
                          color: primaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: progressPercent,
                      minHeight: 8,
                      backgroundColor:
                          isDark ? Colors.grey[700] : Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation<Color>(
                        progress == total ? Colors.green : primaryColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed:
                          progress >= total
                              ? null
                              : () => _verifyLandmarkVisit(index, verifiedList),
                      icon: const Icon(Icons.camera_alt_rounded, size: 16),
                      label: Text(
                        progress >= total ? "Badge Earned!" : "Check-In & Snap",
                        style: const TextStyle(fontSize: 12),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.green.withOpacity(0.5),
                        disabledForegroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRewardListItem(
    BuildContext context,
    Map<String, dynamic> reward,
    Color primaryColor,
    int currentPoints,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bool canAfford = currentPoints >= reward['cost'];

    return GestureDetector(
      onTap:
          () => _showRewardDetailSheet(
            context,
            reward,
            primaryColor,
            currentPoints,
          ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
          ),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                reward['image'],
                width: 70,
                height: 70,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    reward['title'],
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        Icons.stars_rounded,
                        size: 16,
                        color: canAfford ? Colors.orange[400] : Colors.grey,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        "${reward['cost']} pts",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: canAfford ? Colors.orange[600] : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  void _showRewardDetailSheet(
    BuildContext context,
    Map<String, dynamic> reward,
    Color primaryColor,
    int currentPoints,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bool canAfford = currentPoints >= reward['cost'];

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1F2937) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[400],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(
                  reward['image'],
                  width: double.infinity,
                  height: 180,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                reward['title'],
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                reward['description'],
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Required Points:",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                  Text(
                    "${reward['cost']} pts",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange[600],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed:
                      canAfford
                          ? () => _redeemRewardFromDB(reward, currentPoints)
                          : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    disabledBackgroundColor: Colors.grey[400],
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    canAfford ? "Redeem Reward" : "Insufficient Points",
                    style: const TextStyle(
                      fontSize: 16,
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
  }

  Widget _buildCompletedBadgeCard(
    BuildContext context,
    Map<String, dynamic> badgeData,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: (badgeData['badgeColor'] as Color).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              badgeData['badgeIcon'] as IconData,
              size: 36,
              color: badgeData['badgeColor'] as Color,
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                badgeData['badgeName'],
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                "Milestone Reached!",
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(
    BuildContext context,
    String title,
    String actionText,
    Color primaryColor,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        Text(
          actionText,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: primaryColor,
          ),
        ),
      ],
    );
  }

  // --- Helper UI Functions ---
  void _showProcessingDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            content: Row(
              children: [
                const CircularProgressIndicator(),
                const SizedBox(width: 20),
                Expanded(child: Text(message)),
              ],
            ),
          ),
    );
  }

  void _showSuccessDialog(String title, String message) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Awesome!"),
              ),
            ],
          ),
    );
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.red),
                const SizedBox(width: 8),
                Text(title, style: const TextStyle(color: Colors.red)),
              ],
            ),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Understood"),
              ),
            ],
          ),
    );
  }

  void _showMessage(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}
