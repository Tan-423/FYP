import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';

import '../Bus/bus_firebase.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  /// Firestore instance pointing to the secondary bus project (fyp-project-2cb4d).
  FirebaseFirestore? _busDb;

  @override
  void initState() {
    super.initState();
    _initBusDb();
  }

  Future<void> _initBusDb() async {
    final db = await getBusFirestore();
    if (mounted) setState(() => _busDb = db);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const primaryColor = Color(0xFF137FEC);
    final bgLight = const Color(0xFFF6F7F8);
    final bgDark = const Color(0xFF101922);
    final cardLight = Colors.white;
    final cardDark = const Color(0xFF1E293B);
    final textDark = const Color(0xFF0F172A);
    final textLight = const Color(0xFFF1F5F9);

    final backgroundColor = isDark ? bgDark : bgLight;
    final cardColor = isDark ? cardDark : cardLight;
    final textColor = isDark ? textLight : textDark;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1024),
            child: Container(
              color: isDark ? const Color(0xFF0F172A) : Colors.white,
              child: Column(
                children: [
                  // --- TOP APP BAR ---
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    decoration: BoxDecoration(border: Border(bottom: BorderSide(color: borderColor))),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(width: 40, height: 40, decoration: BoxDecoration(color: primaryColor.withOpacity(0.1), shape: BoxShape.circle), child: const Icon(Icons.travel_explore, color: primaryColor)),
                            const SizedBox(width: 12),
                            Text("Admin Dashboard", style: GoogleFonts.plusJakartaSans(fontSize: 20, fontWeight: FontWeight.bold, color: textColor, letterSpacing: -0.5)),
                          ],
                        ),
                        Row(
                          children: [
                            const CircleAvatar(radius: 20, backgroundImage: NetworkImage('https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?auto=format&fit=crop&w=100&q=80')),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.logout),
                              color: Colors.grey[500],
                              onPressed: () async {
                                await FirebaseAuth.instance.signOut();
                                if (context.mounted) {
                                  Navigator.of(context).popUntil((route) => route.isFirst);
                                }
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                        stream: _busDb?.collection('bus_routes').snapshots(),
                        builder: (context, snapshot) {
                          String totalRoutes = _busDb == null
                              ? '...'
                              : snapshot.hasData
                                  ? snapshot.data!.docs.length.toString()
                                  : '...';

                          return SingleChildScrollView(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(children: [const Icon(Icons.analytics, color: primaryColor), const SizedBox(width: 8), Text("System Overview", style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.bold, color: textColor))]),
                                const SizedBox(height: 16),

                                // --- STAT CARDS ---
                                LayoutBuilder(builder: (context, constraints) {
                                  bool isWide = constraints.maxWidth > 600;
                                  return Flex(
                                    direction: isWide ? Axis.horizontal : Axis.vertical,
                                    children: [
                                      Expanded(flex: isWide ? 1 : 0, child: _buildStatCard("Total Routes", totalRoutes, "Live", cardColor, borderColor, textColor)),
                                      if (isWide) const SizedBox(width: 16) else const SizedBox(height: 16),

                                      // Active Rentals (Counts only "available" cars)
                                      Expanded(
                                        flex: isWide ? 1 : 0,
                                        child: StreamBuilder<QuerySnapshot>(
                                          stream: FirebaseFirestore.instance.collection('rental_cars').where('status', isEqualTo: 'available').snapshots(),
                                          builder: (context, carSnapshot) {
                                            String availableCarsCount = carSnapshot.hasData ? carSnapshot.data!.docs.length.toString() : "...";
                                            return _buildStatCard("Active Rentals", availableCarsCount, "Live", cardColor, borderColor, textColor);
                                          },
                                        ),
                                      ),
                                    ],
                                  );
                                }),

                                const SizedBox(height: 32),
                                Row(children: [const Icon(Icons.dashboard_customize, color: primaryColor), const SizedBox(width: 8), Text("Management Console", style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.bold, color: textColor))]),
                                const SizedBox(height: 16),

                                // --- MANAGEMENT CARDS GRID ---
                                LayoutBuilder(
                                    builder: (context, constraints) {
                                      bool isWide = constraints.maxWidth > 700;

                                      List<Widget> managementCards = [
                                        _buildManagementCard(
                                          title: "Bus Route Management", description: "Create, optimize and monitor intercity bus transit routes.", imageUrl: "https://images.unsplash.com/photo-1544620347-c4fd4a3d5957?auto=format&fit=crop&w=800", icon: Icons.directions_bus, statLabel: "Active Fleets", btnLabel: "Add New Route", cardColor: cardColor, borderColor: borderColor, textColor: textColor, primaryColor: primaryColor, isDark: isDark,
                                          statWidget: StreamBuilder<QuerySnapshot>(
                                            stream: _busDb?.collection('bus_routes').snapshots(),
                                            builder: (context, snapshot) {
                                              int count = snapshot.hasData ? snapshot.data!.docs.length : 0;
                                              return Text(count.toString(), style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: textColor, fontSize: 14));
                                            },
                                          ),
                                          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddBusRoutePage())),
                                        ),
                                        _buildManagementCard(
                                          title: "Car Rental Approvals", description: "Review and approve cars submitted by local hosts for renting.", imageUrl: "https://images.unsplash.com/photo-1560958089-b8a1929cea89?auto=format&fit=crop&w=800", icon: Icons.car_rental, statLabel: "Pending Approvals", btnLabel: "Review Requests", cardColor: cardColor, borderColor: borderColor, textColor: textColor, primaryColor: primaryColor, isDark: isDark,
                                          statWidget: StreamBuilder<QuerySnapshot>(
                                            stream: FirebaseFirestore.instance.collection('pending_cars').snapshots(),
                                            builder: (context, snapshot) {
                                              int count = snapshot.hasData ? snapshot.data!.docs.length : 0;
                                              return Text(count.toString(), style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: count > 0 ? Colors.red : textColor, fontSize: 14));
                                            },
                                          ),
                                          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PendingCarsAdminPage())),
                                        ),
                                        _buildManagementCard(
                                          title: "Cancellation Requests",
                                          description: "Review user-submitted vehicle damage reports and process cancellation refunds.",
                                          imageUrl: "https://images.unsplash.com/photo-1590362891991-f776e747a588?auto=format&fit=crop&w=800&q=80",
                                          icon: Icons.cancel_schedule_send,
                                          statLabel: "Pending Reviews",
                                          btnLabel: "Review Requests",
                                          cardColor: cardColor,
                                          borderColor: borderColor,
                                          textColor: textColor,
                                          primaryColor: Colors.orange.shade700,
                                          isDark: isDark,
                                          statWidget: StreamBuilder<QuerySnapshot>(
                                            stream: FirebaseFirestore.instance.collection('car_bookings').where('status', isEqualTo: 'Pending Cancellation').snapshots(),
                                            builder: (context, snapshot) {
                                              int count = snapshot.hasData ? snapshot.data!.docs.length : 0;
                                              return Text(count.toString(), style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: count > 0 ? Colors.orange.shade700 : textColor, fontSize: 14));
                                            },
                                          ),
                                          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CancellationRequestsAdminPage())),
                                        ),
                                        _buildManagementCard(
                                          title: "Vehicle Maintenance",
                                          description: "Review grounded vehicles and restore them to the active fleet.",
                                          imageUrl: "https://images.unsplash.com/photo-1605810230434-7631ac76ec81?auto=format&fit=crop&w=800",
                                          icon: Icons.car_repair,
                                          statLabel: "Grounded Cars",
                                          btnLabel: "Manage Fleet",
                                          cardColor: cardColor,
                                          borderColor: borderColor,
                                          textColor: textColor,
                                          primaryColor: Colors.red.shade600,
                                          isDark: isDark,
                                          statWidget: StreamBuilder<QuerySnapshot>(
                                            stream: FirebaseFirestore.instance.collection('rental_cars').where('status', whereIn: ['unavailable', 'maintenance']).snapshots(),
                                            builder: (context, snapshot) {
                                              int count = snapshot.hasData ? snapshot.data!.docs.length : 0;
                                              return Text(count.toString(), style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: count > 0 ? Colors.red.shade600 : textColor, fontSize: 14));
                                            },
                                          ),
                                          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UnavailableCarsAdminPage())),
                                        ),
                                      ];

                                      if (isWide) {
                                        return GridView.count(
                                          crossAxisCount: 2,
                                          shrinkWrap: true,
                                          physics: const NeverScrollableScrollPhysics(),
                                          mainAxisSpacing: 24,
                                          crossAxisSpacing: 24,
                                          childAspectRatio: 0.9,
                                          children: managementCards,
                                        );
                                      } else {
                                        return Column(
                                          children: managementCards.map((card) => Padding(
                                              padding: const EdgeInsets.only(bottom: 24),
                                              child: card
                                          )).toList(),
                                        );
                                      }
                                    }
                                ),
                                const SizedBox(height: 40),
                              ],
                            ),
                          );
                        }
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, String percent, Color cardColor, Color borderColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(12), border: Border.all(color: borderColor)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: GoogleFonts.plusJakartaSans(color: Colors.grey[500], fontSize: 14)),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(value, style: GoogleFonts.plusJakartaSans(fontSize: 24, fontWeight: FontWeight.bold, color: textColor)),
              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: Colors.green[50], borderRadius: BorderRadius.circular(999)), child: Text(percent, style: const TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildManagementCard({required String title, required String description, required String imageUrl, required IconData icon, required Widget statWidget, required String statLabel, required String btnLabel, required Color cardColor, required Color borderColor, required Color textColor, required Color primaryColor, required bool isDark, required VoidCallback onPressed}) {
    return Container(
      decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(12), border: Border.all(color: borderColor)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
              child: Image.network(
                imageUrl,
                height: 140,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(height: 140, color: Colors.grey[300], child: const Icon(Icons.broken_image, size: 50, color: Colors.grey)),
              )
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [Icon(icon, color: primaryColor, size: 22), const SizedBox(width: 10), Expanded(child: Text(title, style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)))]),
                const SizedBox(height: 8),
                Text(description, style: GoogleFonts.plusJakartaSans(fontSize: 13, color: isDark ? Colors.grey[400] : Colors.grey[600], height: 1.4), maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(children: [statWidget, const SizedBox(width: 4), Text(statLabel, style: TextStyle(color: Colors.grey[500], fontSize: 12))]),
                    ElevatedButton(onPressed: onPressed, style: ElevatedButton.styleFrom(backgroundColor: primaryColor, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))), child: Text(btnLabel, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                  ],
                )
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// ⭐ UNAVAILABLE CARS ADMIN PAGE
// ==========================================
class UnavailableCarsAdminPage extends StatelessWidget {
  const UnavailableCarsAdminPage({super.key});

  Widget _buildImage(String imageString) {
    if (imageString.isEmpty) return Container(width: 80, height: 80, color: Colors.grey[300], child: const Icon(Icons.directions_car, color: Colors.grey));
    if (imageString.startsWith('http')) return Image.network(imageString, width: 80, height: 80, fit: BoxFit.cover, errorBuilder: (c,e,s) => Container(width: 80, height: 80, color: Colors.grey[300], child: const Icon(Icons.broken_image)));
    try {
      String cleanBase64 = imageString.contains(',') ? imageString.split(',').last : imageString;
      return Image.memory(base64Decode(cleanBase64), width: 80, height: 80, fit: BoxFit.cover, errorBuilder: (c,e,s) => Container(width: 80, height: 80, color: Colors.grey[300], child: const Icon(Icons.broken_image)));
    } catch (e) { return Container(width: 80, height: 80, color: Colors.grey[300], child: const Icon(Icons.error)); }
  }

  // ⭐ THE FIX: CLEARS BOOKED DATES WHEN RESTORING CAR!
  Future<void> _markAvailable(String carId, BuildContext context) async {
    try {
      await FirebaseFirestore.instance.collection('rental_cars').doc(carId).update({
        'status': 'available',
        'bookedDates': [] // <--- This wipes the stuck calendar dates!
      });
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Car restored to active fleet!"), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Vehicle Maintenance"), backgroundColor: Colors.red.shade600, foregroundColor: Colors.white),
      backgroundColor: const Color(0xFFF6F7F8),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('rental_cars').where('status', whereIn: ['unavailable', 'maintenance']).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          if (snapshot.data!.docs.isEmpty) return const Center(child: Text("No vehicles currently grounded.", style: TextStyle(color: Colors.grey)));

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final doc = snapshot.data!.docs[index];
              final data = doc.data() as Map<String, dynamic>;

              return Card(
                elevation: 0,
                color: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
                margin: const EdgeInsets.only(bottom: 16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: _buildImage(data['imageUrl']?.toString() ?? '')
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(data['name'] ?? 'Unknown', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text("Status: ${data['status']?.toString().toUpperCase()}", style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12)),
                            const SizedBox(height: 12),
                            ElevatedButton.icon(
                              onPressed: () => _markAvailable(doc.id, context), // Restores Car!
                              icon: const Icon(Icons.build_circle, size: 16),
                              label: const Text("Mark as Available"),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            )
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// --- CANCELLATION REQUESTS PAGE ---
class CancellationRequestsAdminPage extends StatelessWidget {
  const CancellationRequestsAdminPage({super.key});

  Future<void> _processCancellation(String bookingId, String carId, bool approve, BuildContext context) async {
    try {
      if (approve) {
        await FirebaseFirestore.instance.collection('car_bookings').doc(bookingId).update({'status': 'Cancelled'});
        await FirebaseFirestore.instance.collection('rental_cars').doc(carId).update({'status': 'unavailable'});
      } else {
        await FirebaseFirestore.instance.collection('car_bookings').doc(bookingId).update({'status': 'Upcoming'});
      }
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(approve ? "Cancellation Approved" : "Request Denied"), backgroundColor: approve ? Colors.green : Colors.red));
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Cancellation Reviews"), backgroundColor: Colors.orange.shade700, foregroundColor: Colors.white),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('car_bookings').where('status', isEqualTo: 'Pending Cancellation').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          if (snapshot.data!.docs.isEmpty) return const Center(child: Text("No requests pending review."));

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final data = snapshot.data!.docs[index].data() as Map<String, dynamic>;
              final id = snapshot.data!.docs[index].id;
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.warning, color: Colors.orange),
                  title: Text(data['carName'] ?? "Unknown Car"),
                  subtitle: Text("User: ${data['userEmail']}\nReason: ${data['cancellationReason']}"),
                  isThreeLine: true,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(icon: const Icon(Icons.check, color: Colors.green), onPressed: () => _processCancellation(id, data['carId'], true, context)),
                      IconButton(icon: const Icon(Icons.close, color: Colors.red), onPressed: () => _processCancellation(id, data['carId'], false, context)),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// --- PENDING CARS APPROVAL PAGE ---
class PendingCarsAdminPage extends StatelessWidget {
  const PendingCarsAdminPage({super.key});

  Widget _buildImage(String imageString) {
    if (imageString.isEmpty) return Container(width: 80, height: 80, color: Colors.grey[300], child: const Icon(Icons.directions_car, color: Colors.grey));
    if (imageString.startsWith('http')) return Image.network(imageString, width: 80, height: 80, fit: BoxFit.cover, errorBuilder: (c,e,s) => Container(width: 80, height: 80, color: Colors.grey[300], child: const Icon(Icons.broken_image)));
    try {
      String cleanBase64 = imageString.contains(',') ? imageString.split(',').last : imageString;
      return Image.memory(base64Decode(cleanBase64), width: 80, height: 80, fit: BoxFit.cover, errorBuilder: (c,e,s) => Container(width: 80, height: 80, color: Colors.grey[300], child: const Icon(Icons.broken_image)));
    } catch (e) { return Container(width: 80, height: 80, color: Colors.grey[300], child: const Icon(Icons.error)); }
  }

  Future<void> _approveCar(DocumentSnapshot doc, BuildContext context) async {
    final data = doc.data() as Map<String, dynamic>;
    await FirebaseFirestore.instance.collection('rental_cars').add({
      'name': data['name'], 'type': data['type'], 'price': data['price'],
      'features': data['features'], 'imageUrl': data['imageUrl'], 'tag': data['tag'],
      'lat': data['lat'], 'lng': data['lng'], 'status': 'available', 'bookedDates': []
    });
    await FirebaseFirestore.instance.collection('pending_cars').doc(doc.id).delete();
    if(context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Car Approved & Live on Map!"), backgroundColor: Colors.green));
  }

  Future<void> _rejectCar(String docId, BuildContext context) async {
    await FirebaseFirestore.instance.collection('pending_cars').doc(docId).delete();
    if(context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Request Rejected & Deleted."), backgroundColor: Colors.red));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Pending Host Approvals"), backgroundColor: const Color(0xFF137FEC), foregroundColor: Colors.white),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('pending_cars').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          if (snapshot.data!.docs.isEmpty) return const Center(child: Text("No pending cars right now."));

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final doc = snapshot.data!.docs[index];
              final data = doc.data() as Map<String, dynamic>;

              return Card(
                elevation: 4,
                margin: const EdgeInsets.only(bottom: 16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(borderRadius: BorderRadius.circular(8), child: _buildImage(data['imageUrl']?.toString() ?? '')),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(data['name'] ?? 'Unknown', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            Text("${data['type']}  •  \$${data['price']}/day", style: TextStyle(color: Colors.grey[600])),
                            const SizedBox(height: 8),
                            Text("Features: ${(data['features'] as List).join(', ')}", style: const TextStyle(fontSize: 12)),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(child: ElevatedButton(onPressed: () => _approveCar(doc, context), style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white), child: const Text("Approve"))),
                                const SizedBox(width: 8),
                                Expanded(child: OutlinedButton(onPressed: () => _rejectCar(doc.id, context), style: OutlinedButton.styleFrom(foregroundColor: Colors.red), child: const Text("Reject"))),
                              ],
                            )
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// --- ADD BUS ROUTE PAGE ---
class AddBusRoutePage extends StatefulWidget { const AddBusRoutePage({super.key}); @override State<AddBusRoutePage> createState() => _AddBusRoutePageState(); }
class _AddBusRoutePageState extends State<AddBusRoutePage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _fromController = TextEditingController();
  final TextEditingController _toController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();
  TimeOfDay? _departureTime;
  TimeOfDay? _arrivalTime;
  FirebaseFirestore? _busDb;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _initBusDb();
  }

  Future<void> _initBusDb() async {
    try {
      final db = await getBusFirestore();
      if (mounted) setState(() => _busDb = db);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to connect to bus database: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    DateTime? picked = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime.now(), lastDate: DateTime(2030));
    if (picked != null) setState(() => _dateController.text = "${picked.year}-${picked.month}-${picked.day}");
  }

  Future<void> _selectTime(BuildContext context, bool isDeparture) async {
    TimeOfDay? picked = await showTimePicker(context: context, initialTime: TimeOfDay.now());
    if (picked != null) setState(() { if (isDeparture) { _departureTime = picked; } else { _arrivalTime = picked; } });
  }

  Future<void> _saveRoute() async {
    if (_busDb == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Bus database is still connecting. Please try again."),
          backgroundColor: Colors.orange,
        ),
      );
      // Retry connecting
      _initBusDb();
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    if (_departureTime == null || _arrivalTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select both Departure and Arrival times.")),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      String formatTime(TimeOfDay time) {
        final hours = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
        final minutes = time.minute.toString().padLeft(2, '0');
        final period = time.period == DayPeriod.am ? "AM" : "PM";
        return "$hours:$minutes $period";
      }

      String capitalize(String input) {
        if (input.isEmpty) return input;
        return input.split(' ').map((str) => str.isNotEmpty ? str[0].toUpperCase() + str.substring(1) : '').join(' ');
      }

      await _busDb!.collection('bus_routes').add({
        'Busname': _nameController.text.trim(),
        'from': capitalize(_fromController.text.trim()),
        'to': capitalize(_toController.text.trim()),
        'price': double.parse(_priceController.text.trim()),
        'date': _dateController.text.trim(),
        'departureTime': formatTime(_departureTime!),
        'arrivalTime': formatTime(_arrivalTime!),
        'bookedSeats': [],
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Route Added Successfully! ✨"), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to save route: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Create New Bus Route")),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            TextFormField(controller: _nameController, decoration: const InputDecoration(labelText: "Bus Company Name", border: OutlineInputBorder()), validator: (v) => v!.isEmpty ? "Required" : null),
            const SizedBox(height: 16),
            TextFormField(controller: _fromController, decoration: const InputDecoration(labelText: "From (Origin City)", border: OutlineInputBorder()), validator: (v) => v!.isEmpty ? "Required" : null),
            const SizedBox(height: 16),
            TextFormField(controller: _toController, decoration: const InputDecoration(labelText: "To (Destination City)", border: OutlineInputBorder()), validator: (v) => v!.isEmpty ? "Required" : null),
            const SizedBox(height: 16),
            TextFormField(controller: _priceController, decoration: const InputDecoration(labelText: "Ticket Price (\$)", border: OutlineInputBorder()), keyboardType: TextInputType.number, validator: (v) => v!.isEmpty ? "Required" : null),
            const SizedBox(height: 16),
            InkWell(onTap: () => _selectDate(context), child: IgnorePointer(child: TextFormField(controller: _dateController, decoration: const InputDecoration(labelText: "Travel Date", border: OutlineInputBorder(), suffixIcon: Icon(Icons.calendar_month)), validator: (v) => v!.isEmpty ? "Required" : null))),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: InkWell(onTap: () => _selectTime(context, true), child: Container(padding: const EdgeInsets.symmetric(vertical: 16), decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(4)), child: Center(child: Text(_departureTime == null ? "Select Departure" : "Dep: ${_departureTime!.format(context)}"))))),
                const SizedBox(width: 16),
                Expanded(child: InkWell(onTap: () => _selectTime(context, false), child: Container(padding: const EdgeInsets.symmetric(vertical: 16), decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(4)), child: Center(child: Text(_arrivalTime == null ? "Select Arrival" : "Arr: ${_arrivalTime!.format(context)}"))))),
              ],
            ),
            const SizedBox(height: 32),
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveRoute,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF137FEC),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: const Color(0xFF137FEC).withOpacity(0.6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                      )
                    : const Text("Save Route to Database", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            )
          ],
        ),
      ),
    );
  }
}