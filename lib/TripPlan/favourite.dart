import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'createtrip.dart';
import 'tripschedule.dart';

// --- DATA MODEL ---
class TripPlan {
  final String id;
  final String title;
  final DateTime startDate;
  final DateTime endDate;
  final String status;
  final String imageUrl;

  TripPlan({
    required this.id,
    required this.title,
    required this.startDate,
    required this.endDate,
    required this.status,
    required this.imageUrl,
  });

  String get dateRangeFormatted {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    String startStr = "${months[startDate.month - 1]} ${startDate.day.toString().padLeft(2, '0')}";
    String endStr = "${months[endDate.month - 1]} ${endDate.day.toString().padLeft(2, '0')}";
    return "$startStr - $endStr, ${endDate.year}";
  }
}

class SavedPlansScreen extends StatefulWidget {
  const SavedPlansScreen({super.key});

  @override
  State<SavedPlansScreen> createState() => _SavedPlansScreenState();
}

class _SavedPlansScreenState extends State<SavedPlansScreen> {
  int _selectedTabIndex = 0;
  final List<String> _tabs = ["All", "Current", "Past"];

  // ==========================================
  // 🔴 DELETE TRIP LOGIC
  // ==========================================
  Future<void> _deleteTrip(String tripId) async {
    try {
      await FirebaseFirestore.instance.collection('trips').doc(tripId).delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Trip deleted successfully"), backgroundColor: Colors.redAccent),
        );
      }
    } catch (e) {
      debugPrint("Error deleting trip: $e");
    }
  }

  void _showDeleteConfirmation(String tripId, String tripName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Trip?"),
        content: Text("Are you sure you want to delete '$tripName'? This cannot be undone."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteTrip(tripId);
            },
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = const Color(0xFF135BEC);
    final String userId = FirebaseAuth.instance.currentUser?.uid ?? "anonymous_user";

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF101622) : const Color(0xFFF6F6F8),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const CreateTripScreen())),
        backgroundColor: primaryColor,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text("Create New Plan", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // --- HEADER ---
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text("Saved Plans", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
            ),
            // --- TABS ---
            Row(
              children: List.generate(_tabs.length, (index) {
                bool isActive = _selectedTabIndex == index;
                return GestureDetector(
                  onTap: () => setState(() => _selectedTabIndex = index),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(border: Border(bottom: BorderSide(color: isActive ? primaryColor : Colors.transparent, width: 2))),
                    child: Text(_tabs[index], style: TextStyle(color: isActive ? primaryColor : Colors.grey, fontWeight: FontWeight.bold)),
                  ),
                );
              }),
            ),
            // --- LIST ---
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('trips').where('userId', isEqualTo: userId).snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                  var allTrips = snapshot.data!.docs.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    return TripPlan(
                      id: doc.id,
                      title: data['tripName'] ?? 'Untitled',
                      startDate: (data['startDate'] as Timestamp).toDate(),
                      endDate: (data['endDate'] as Timestamp).toDate(),
                      status: "Planned",
                      imageUrl: "https://images.unsplash.com/photo-1476514525535-07fb3b4ae5f1?auto=format&fit=crop&w=500",
                    );
                  }).toList()
                  ..sort((a, b) => b.startDate.compareTo(a.startDate));

                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: allTrips.length,
                    itemBuilder: (context, index) => _buildTripCard(allTrips[index], primaryColor, isDark),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTripCard(TripPlan trip, Color primaryColor, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Planned", style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 12)),
                    // ⭐ DELETE BUTTON ADDED HERE
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                      onPressed: () => _showDeleteConfirmation(trip.id, trip.title),
                    ),
                  ],
                ),
                Text(trip.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(trip.dateRangeFormatted, style: const TextStyle(color: Colors.grey, fontSize: 13)),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => TripSchedulePage(savedTripId: trip.id))),
                  style: ElevatedButton.styleFrom(backgroundColor: primaryColor, foregroundColor: Colors.white),
                  child: const Text("View Details"),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(trip.imageUrl, width: 100, height: 100, fit: BoxFit.cover),
          ),
        ],
      ),
    );
  }
}