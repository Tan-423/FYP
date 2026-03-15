import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'BusBooking.dart';
import 'bus_firebase.dart';

// ==========================================
// 1. BUS SCHEDULE PAGE (MAIN SCREEN)
// ==========================================
class BusSchedulePage extends StatefulWidget {
  const BusSchedulePage({super.key});

  @override
  State<BusSchedulePage> createState() => _BusSchedulePageState();
}

class _BusSchedulePageState extends State<BusSchedulePage> {
  final TextEditingController _fromController = TextEditingController();
  final TextEditingController _toController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();

  Stream<QuerySnapshot>? _busStream;
  FirebaseFirestore? _db;

  // --- RECOMMENDATION ENGINE VARIABLES ---
  String? _preferredOperator;
  bool _isLoadingPreferences = true;

  // --- PRIMARY SEATS (authoritative source from primary Firebase) ---
  Map<String, Set<String>> _primarySeatsMap = {};
  StreamSubscription<QuerySnapshot>? _primarySeatsSubscription;

  final Set<String> _validSeats = {
    '1A', '1B', '1C', '1D',
    '2A', '2B', '2C', '2D',
    '3A', '3B', '3C', '3D',
    '4A', '4B', '4C', '4D',
    '5A', '5B', '5C', '5D'
  };

  @override
  void initState() {
    super.initState();
    DateTime now = DateTime.now();
    String todayFormatted = "${now.year}-${now.month}-${now.day}";
    _dateController.text = todayFormatted;
    _initFirestore(todayFormatted);
    _listenToPrimarySeats();
  }

  @override
  void dispose() {
    _primarySeatsSubscription?.cancel();
    _fromController.dispose();
    _toController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  /// Listens to the primary Firebase project's bus_seats collection.
  /// This is the authoritative source for booked seats since secondary
  /// project writes can fail silently due to Firestore security rules.
  void _listenToPrimarySeats() {
    _primarySeatsSubscription = FirebaseFirestore.instance
        .collection('bus_seats')
        .snapshots()
        .listen((snapshot) {
      if (!mounted) return;
      final map = <String, Set<String>>{};
      for (var doc in snapshot.docs) {
        final raw = (doc.data()['bookedSeats'] as List<dynamic>?) ?? [];
        map[doc.id] = raw.map((s) => s.toString()).toSet();
      }
      setState(() => _primarySeatsMap = map);
    });
  }

  Future<void> _initFirestore(String todayFormatted) async {
    final db = await getBusFirestore();
    if (!mounted) return;
    setState(() {
      _db = db;
      _busStream = db
          .collection('bus_routes')
          .where('date', isEqualTo: todayFormatted)
          .snapshots();
    });
    await _loadUserPreferences(db);
  }

  // ==============================================================
  // RECOMMENDATION ENGINE LOGIC
  // ==============================================================
  Future<void> _loadUserPreferences(FirebaseFirestore db) async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoadingPreferences = false);
      return;
    }

    try {
      // Read tickets from PRIMARY project (where profile reads from)
      var ticketsSnapshot = await FirebaseFirestore.instance
          .collection('tickets')
          .where('userId', isEqualTo: user.uid)
          .get();

      Map<String, int> operatorFrequency = {};
      for (var doc in ticketsSnapshot.docs) {
        String busName = doc.data()['busName'] ?? '';
        if (busName.isNotEmpty) {
          operatorFrequency[busName] = (operatorFrequency[busName] ?? 0) + 1;
        }
      }

      if (operatorFrequency.isNotEmpty) {
        String topOperator = operatorFrequency.keys.first;
        int maxCount = operatorFrequency[topOperator]!;
        operatorFrequency.forEach((key, value) {
          if (value > maxCount) {
            topOperator = key;
            maxCount = value;
          }
        });
        _preferredOperator = topOperator;
      }
    } catch (e) {
      debugPrint("Error loading preferences: $e");
    }

    if (mounted) setState(() => _isLoadingPreferences = false);
  }

  DateTime? _parseDepartureTime(String dateStr, String timeStr) {
    try {
      if (dateStr.isEmpty || timeStr.isEmpty) return null;
      List<String> dParts = dateStr.split('-');
      int year = int.parse(dParts[0]);
      int month = int.parse(dParts[1]);
      int day = int.parse(dParts[2]);

      List<String> tParts = timeStr.split(' ');
      String time = tParts[0];
      String period = tParts[1].toUpperCase();

      List<String> hm = time.split(':');
      int hour = int.parse(hm[0]);
      int minute = int.parse(hm[1]);

      if (period == "PM" && hour != 12) hour += 12;
      if (period == "AM" && hour == 12) hour = 0;

      return DateTime(year, month, day, hour, minute);
    } catch (e) {
      return null;
    }
  }

  String _getRouteStatus(int remainingSeats, DateTime? departureDateTime) {
    if (departureDateTime != null && departureDateTime.isBefore(DateTime.now())) return 'DEPARTED';
    if (remainingSeats <= 0) return 'SOLD OUT';
    if (remainingSeats < 10) return 'LIMITED';
    return 'AVAILABLE';
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'DEPARTED': return Colors.grey;
      case 'SOLD OUT': return Colors.red;
      case 'LIMITED': return Colors.orange;
      default: return Colors.green;
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        _dateController.text = "${picked.year}-${picked.month}-${picked.day}";
      });
    }
  }

  void _performSearch() {
    if (_db == null) return;
    Query query = _db!.collection('bus_routes');

    String capitalize(String input) {
      if (input.isEmpty) return input;
      return input.split(' ').map((str) => str.isNotEmpty ? str[0].toUpperCase() + str.substring(1) : '').join(' ');
    }

    if (_fromController.text.isNotEmpty) {
      query = query.where('from', isEqualTo: capitalize(_fromController.text.trim()));
    }
    if (_toController.text.isNotEmpty) {
      query = query.where('to', isEqualTo: capitalize(_toController.text.trim()));
    }
    if (_dateController.text.isNotEmpty) {
      query = query.where('date', isEqualTo: _dateController.text.trim());
    }

    setState(() {
      _busStream = query.snapshots();
    });
  }

  void _clearFilters() {
    _fromController.clear();
    _toController.clear();
    _dateController.clear();
    FocusScope.of(context).unfocus();
    if (_db != null) {
      setState(() {
        _busStream = _db!.collection('bus_routes').snapshots();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgLight = const Color(0xFFF3F4F6);
    final bgDark = const Color(0xFF0F172A);
    final textSub = isDark ? const Color(0xFF94A3B8) : const Color(0xFF6B7280);

    return Scaffold(
      backgroundColor: isDark ? bgDark : bgLight,
      body: SafeArea(
        child: Column(
          children: [
            // --- Header ---
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 24, 16),
              child: Row(
                children: [
                  _buildIconBtn(Icons.arrow_back_ios_new, () => Navigator.pop(context)),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Bus Ticket', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF111827))),
                        Text('Find your route', style: GoogleFonts.inter(fontSize: 12, color: textSub)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: Column(
                children: [
                  // --- Search Card ---
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 4))],
                      ),
                      child: Column(
                        children: [
                          _buildInputField("From", Icons.directions_bus, "e.g. Kuala Lumpur", _fromController),
                          Divider(height: 1, color: isDark ? Colors.grey[800] : Colors.grey[200]),
                          _buildInputField("To", Icons.location_on, "e.g. Penang", _toController),
                          Divider(height: 1, color: isDark ? Colors.grey[800] : Colors.grey[200]),
                          InkWell(
                            onTap: () => _selectDate(context),
                            child: _buildInputField("Date", Icons.calendar_today, "Select Date", _dateController, enabled: false),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Row(
                              children: [
                                Expanded(
                                  child: SizedBox(
                                    height: 50,
                                    child: ElevatedButton(
                                      onPressed: _performSearch,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF2563EB),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                      child: Text("Search Buses", style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white)),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  height: 50, width: 50,
                                  decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(12)),
                                  child: IconButton(onPressed: _clearFilters, icon: const Icon(Icons.refresh, color: Colors.grey)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // --- Results List ---
                  Expanded(
                    child: _busStream == null
                        ? const Center(child: CircularProgressIndicator())
                        : StreamBuilder<QuerySnapshot>(
                      stream: _busStream,
                      builder: (context, snapshot) {
                        if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}"));
                        if (snapshot.connectionState == ConnectionState.waiting || _isLoadingPreferences) {
                          return const Center(child: CircularProgressIndicator());
                        }

                        final docs = snapshot.data!.docs;
                        if (docs.isEmpty) return const Center(child: Text("No buses found."));

                        List<Widget> recommendedBuses = [];
                        List<Widget> standardBuses = [];

                        for (var doc in docs) {
                          Map<String, dynamic> data = doc.data()! as Map<String, dynamic>;

                          List<dynamic> rawBookedList = data['bookedSeats'] ?? [];
                          Set<String> uniqueBookedSeats = rawBookedList.map((e) => e.toString()).toSet();
                          // Merge with primary Firebase seats (authoritative source)
                          Set<String> primarySeats = _primarySeatsMap[doc.id] ?? {};
                          uniqueBookedSeats = uniqueBookedSeats.union(primarySeats);
                          int actualBookedCount = uniqueBookedSeats.intersection(_validSeats).length;
                          int remainingSeats = 20 - actualBookedCount;

                          String busName = data['Busname'] ?? data['busName'] ?? '';
                          double rating = data['rating']?.toDouble() ?? 0.0;
                          int ratingCount = data['ratingCount']?.toInt() ?? 0;

                          String? badgeText;
                          Color? badgeColor;

                          if (_preferredOperator != null && busName == _preferredOperator) {
                            badgeText = "Based on your past trips";
                            badgeColor = const Color(0xFF2563EB);
                          } else if (rating >= 4.5 && ratingCount > 0) {
                            badgeText = "Highly rated by similar users";
                            badgeColor = Colors.orange;
                          }

                          Widget busCard = _buildBusTicketCard(context, data, doc.id, remainingSeats, rating, ratingCount, badgeText: badgeText, badgeColor: badgeColor);

                          if (badgeText != null) {
                            recommendedBuses.add(busCard);
                          } else {
                            standardBuses.add(busCard);
                          }
                        }

                        List<Widget> finalLayout = [];

                        if (recommendedBuses.isNotEmpty) {
                          finalLayout.add(
                            Padding(
                              padding: const EdgeInsets.only(left: 24, bottom: 12, top: 8),
                              child: Row(
                                children: [
                                  const Icon(Icons.auto_awesome, color: Colors.orange, size: 20),
                                  const SizedBox(width: 8),
                                  Text("Recommended for You", style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
                                ],
                              ),
                            ),
                          );
                          finalLayout.addAll(recommendedBuses);
                          if (standardBuses.isNotEmpty) {
                            finalLayout.add(
                              Padding(
                                padding: const EdgeInsets.only(left: 24, bottom: 12, top: 8),
                                child: Text("Other Available Buses", style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
                              ),
                            );
                          }
                        }

                        finalLayout.addAll(standardBuses);

                        return ListView(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          children: finalLayout,
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputField(String label, IconData icon, String hint, TextEditingController controller, {bool enabled = true}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                TextField(
                  controller: controller,
                  enabled: enabled,
                  style: TextStyle(fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black),
                  decoration: InputDecoration(hintText: hint, border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBusTicketCard(BuildContext context, Map<String, dynamic> data, String busId, int remainingSeats, double rating, int ratingCount, {String? badgeText, Color? badgeColor}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;

    String name = data['Busname'] ?? data['busName'] ?? 'Bus Service';
    String price = data['price']?.toString() ?? '--';
    String dep = data['departureTime'] ?? '--';
    String arr = data['arrivalTime'] ?? '--';
    String travelDate = data['date'] ?? '';

    DateTime? departureDateTime = _parseDepartureTime(travelDate, dep);
    String status = _getRouteStatus(remainingSeats, departureDateTime);
    Color statusColor = _getStatusColor(status);

    return InkWell(
      onTap: (status == 'SOLD OUT' || status == 'DEPARTED') ? null : () {
        Navigator.push(context, MaterialPageRoute(builder: (context) => SeatSelectionScreen(
          busId: busId,
          busName: name,
          price: price,
          travelDate: travelDate,
        )));
      },
      child: Stack(
        children: [
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: status == 'DEPARTED' ? cardColor.withOpacity(0.6) : cardColor,
              borderRadius: BorderRadius.circular(16),
              border: badgeText != null ? Border.all(color: badgeColor!.withOpacity(0.5), width: 1.5) : null,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))],
            ),
            child: Column(
              children: [
                if (badgeText != null) const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(name, style: GoogleFonts.inter(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: status == 'DEPARTED' ? Colors.grey : null,
                            )),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.orange.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.orange.withOpacity(0.3)),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.star, color: Colors.orange[400], size: 14),
                                  const SizedBox(width: 4),
                                  Text(
                                    rating == 0 ? "New" : rating.toStringAsFixed(1),
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.orange[800]),
                                  ),
                                  if (ratingCount > 0) ...[
                                    const SizedBox(width: 4),
                                    Text("($ratingCount)", style: TextStyle(fontSize: 10, color: Colors.orange[800])),
                                  ]
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(Icons.calendar_today, size: 12, color: Colors.grey[500]),
                            const SizedBox(width: 4),
                            Text(travelDate.isEmpty ? 'Unknown Date' : travelDate, style: TextStyle(fontSize: 12, color: Colors.grey[500], fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: statusColor)),
                      child: Text(status, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Departure", style: TextStyle(fontSize: 10, color: Colors.grey)),
                        Text(dep, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: status == 'DEPARTED' ? Colors.grey : null)),
                        Text(data['from'] ?? '', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                    Icon(Icons.arrow_forward, color: Colors.grey[400], size: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text("Arrival", style: TextStyle(fontSize: 10, color: Colors.grey)),
                        Text(arr, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: status == 'DEPARTED' ? Colors.grey : null)),
                        Text(data['to'] ?? '', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  ],
                ),
                const Divider(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(status == 'DEPARTED' ? "Trip Completed" : "$remainingSeats / 20 Seats Left",
                        style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w600)),
                    Text("\$$price", style: GoogleFonts.inter(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: status == 'DEPARTED' ? Colors.grey : const Color(0xFF2563EB)
                    )),
                  ],
                ),
              ],
            ),
          ),
          if (badgeText != null)
            Positioned(
              top: 0,
              left: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeColor,
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8)),
                ),
                child: Text(badgeText, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildIconBtn(IconData icon, VoidCallback onTap) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(color: isDark ? Colors.grey[800] : Colors.white, borderRadius: BorderRadius.circular(12)),
      child: IconButton(icon: Icon(icon, size: 18, color: isDark ? Colors.white : Colors.black), onPressed: onTap),
    );
  }
}
