import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'buspayment.dart';
import 'bus_firebase.dart';

class SeatSelectionScreen extends StatefulWidget {
  final String busId;
  final String busName;
  final String price;
  final String travelDate;
  final int maxSeatsAllowed; // Kept so it doesn't break the previous screen's navigation

  const SeatSelectionScreen({
    super.key,
    required this.busId,
    this.busName = "Bus Name",
    this.price = "25.00",
    this.travelDate = '',
    this.maxSeatsAllowed = 1,
  });

  @override
  State<SeatSelectionScreen> createState() => _SeatSelectionScreenState();
}

class _SeatSelectionScreenState extends State<SeatSelectionScreen> {
  final Set<String> _selectedSeats = {};
  Set<String> _occupiedSeats = {};
  // Booked seats tracked in the primary project (reliable fallback)
  Set<String> _primaryBookedSeats = {};
  late double _pricePerSeat;
  StreamSubscription<DocumentSnapshot>? _primarySeatsSubscription;

  @override
  void initState() {
    super.initState();
    String cleanPrice = widget.price.replaceAll(RegExp(r'[^0-9.]'), '');
    _pricePerSeat = double.tryParse(cleanPrice) ?? 25.00;
    _listenToPrimaryBookedSeats();
  }

  /// Listens to the primary Firebase project for booked seats.
  /// This is a reliable source that doesn't depend on the secondary project's
  /// Firestore security rules allowing writes.
  void _listenToPrimaryBookedSeats() {
    _primarySeatsSubscription = FirebaseFirestore.instance
        .collection('bus_seats')
        .doc(widget.busId)
        .snapshots()
        .listen((snapshot) {
      if (!mounted) return;
      if (snapshot.exists) {
        final data = snapshot.data();
        final rawSeats = (data?['bookedSeats'] as List<dynamic>?) ?? [];
        setState(() {
          _primaryBookedSeats = rawSeats.map((s) => s.toString()).toSet();
        });
      }
    });
  }

  @override
  void dispose() {
    _primarySeatsSubscription?.cancel();
    super.dispose();
  }

  void _goToPayment() {
    if (_selectedSeats.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please select at least one seat."))
      );
      return;
    }

    final totalAmount = _selectedSeats.length * _pricePerSeat;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PaymentScreen(
          totalAmount: totalAmount,
          selectedSeats: _selectedSeats,
          busName: widget.busName,
          busId: widget.busId,
          date: widget.travelDate.isNotEmpty ? widget.travelDate : _todayDateString(),
          onPaymentSuccess: ({String? paymentId, String? payerEmail}) =>
              _finalizeBooking(paymentId: paymentId, payerEmail: payerEmail),
        ),
      ),
    );
  }

  String _todayDateString() {
    final now = DateTime.now();
    return "${now.year}-${now.month}-${now.day}";
  }

  Future<void> _finalizeBooking({String? paymentId, String? payerEmail}) async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      debugPrint("Error: User is not logged in.");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error: Not logged in. Please log in and contact support.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    try {
      final String travelDate = widget.travelDate.isNotEmpty
          ? widget.travelDate
          : _todayDateString();
      String ticketId = "TKT-${DateTime.now().millisecondsSinceEpoch}";

      // Save ticket to PRIMARY project (so it shows in profile)
      await FirebaseFirestore.instance.collection('tickets').add({
        'userId': user.uid,
        'ticketId': ticketId,
        'busName': widget.busName,
        'busId': widget.busId,
        'seats': _selectedSeats.toList(),
        'price': _selectedSeats.length * _pricePerSeat,
        'date': travelDate,
        'qrData': "BUS|$ticketId|${user.uid}",
        'paymentId': paymentId,
        'payerEmail': payerEmail,
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Write to PRIMARY project first — this is the reliable source of truth
      // and is not blocked by the secondary project's Firestore security rules.
      await FirebaseFirestore.instance
          .collection('bus_seats')
          .doc(widget.busId)
          .set({
        'bookedSeats': FieldValue.arrayUnion(_selectedSeats.toList())
      }, SetOptions(merge: true));

      // Also attempt to update the secondary (partner's) project so the
      // remaining seat count stays accurate. This may fail silently if
      // the partner's Firestore rules block external writes — that's OK
      // because the primary project is the authoritative seat source now.
      try {
        final busDb = await getBusFirestore();
        await busDb.collection('bus_routes').doc(widget.busId).set({
          'bookedSeats': FieldValue.arrayUnion(_selectedSeats.toList())
        }, SetOptions(merge: true));
      } catch (e) {
        debugPrint("Secondary project seat update failed (non-critical): $e");
      }

      debugPrint("Booking finalized successfully!");

    } catch (e) {
      debugPrint("Error saving booking: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment was received but ticket could not be saved. Please contact support. Error: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 8),
          ),
        );
      }
    }
  }

  void _toggleSeat(String seatId) {
    if (_occupiedSeats.contains(seatId)) return;

    setState(() {
      if (_selectedSeats.contains(seatId)) {
        _selectedSeats.remove(seatId);
      } else {
        _selectedSeats.add(seatId); // Users can now add as many as they want!
      }
    });
  }

  FirebaseFirestore? _db;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_db == null) {
      getBusFirestore().then((db) {
        if (mounted) setState(() => _db = db);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = const Color(0xFF4F46E5);

    if (_db == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return StreamBuilder<DocumentSnapshot>(
        stream: _db!.collection('bus_routes').doc(widget.busId).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Scaffold(body: Center(child: CircularProgressIndicator()));

          var data = snapshot.data!.data() as Map<String, dynamic>?;
          List<dynamic> bookedList = data != null && data.containsKey('bookedSeats') ? data['bookedSeats'] : [];
          // Merge seats from both secondary project (bus_routes) and
          // primary project (bus_seats) so seats are always marked occupied
          // even if the secondary project write failed.
          _occupiedSeats = {
            ...bookedList.map((e) => e.toString()),
            ..._primaryBookedSeats,
          };
          _selectedSeats.removeWhere((seat) => _occupiedSeats.contains(seat));

          final totalAmount = _selectedSeats.length * _pricePerSeat;

          return Scaffold(
            backgroundColor: isDark ? const Color(0xFF111827) : const Color(0xFFF3F4F6),
            body: SafeArea(
              child: Column(
                children: [
                  // --- Header ---
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildIconBtn(Icons.arrow_back_ios_new_rounded, () => Navigator.pop(context)),
                        Text(
                          "Select Seats",
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black),
                        ),
                        const SizedBox(width: 40),
                      ],
                    ),
                  ),

                  // --- Seat Counter ---
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      _selectedSeats.isEmpty ? "Select your seats" : "${_selectedSeats.length} Seat(s) Selected",
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: _selectedSeats.isNotEmpty ? Colors.green : Colors.grey
                      ),
                    ),
                  ),

                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        children: [
                          // --- Legend ---
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 24),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _buildLegendItem(context, "Available", SeatStatus.available),
                                const SizedBox(width: 24),
                                _buildLegendItem(context, "Selected", SeatStatus.selected),
                                const SizedBox(width: 24),
                                _buildLegendItem(context, "Occupied", SeatStatus.occupied),
                              ],
                            ),
                          ),

                          // --- Bus Layout ---
                          Container(
                            margin: const EdgeInsets.symmetric(horizontal: 40),
                            padding: const EdgeInsets.fromLTRB(16, 40, 16, 40),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1F2937) : Colors.white,
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
                              border: Border.all(color: isDark ? Colors.grey[800]! : Colors.grey[200]!),
                            ),
                            child: Column(
                              children: [
                                _buildSeatRow(1, ['A', 'B'], ['C', 'D']),
                                _buildSeatRow(2, ['A', 'B'], ['C', 'D']),
                                _buildSeatRow(3, ['A', 'B'], ['C', 'D']),
                                _buildSeatRow(4, ['A', 'B'], ['C', 'D']),
                                _buildSeatRow(5, ['A', 'B'], ['C', 'D']),

                                const SizedBox(height: 40),
                                Container(
                                  padding: const EdgeInsets.only(top: 20, right: 20),
                                  alignment: Alignment.centerRight,
                                  child: Icon(Icons.sports_motorsports_rounded, color: Colors.grey[400], size: 32),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 160),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // --- Bottom Sheet ---
            bottomSheet: Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1F2937) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, -5))],
              ),
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("SELECTED SEATS", style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text(
                            _selectedSeats.isEmpty ? "None" : _selectedSeats.join(", "),
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text("TOTAL PRICE", style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text("\$${totalAmount.toStringAsFixed(2)}",
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: primaryColor)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Button enables as soon as at least 1 seat is picked
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _selectedSeats.isNotEmpty ? _goToPayment : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.grey[400],
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                          _selectedSeats.isNotEmpty ? "Book ${_selectedSeats.length} Ticket(s)" : "Select a Seat",
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }
    );
  }

  // --- Helper Widgets ---

  Widget _buildSeatRow(int rowNum, List<String> left, List<String> right) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(children: left.map((char) => _buildSeat("$rowNum$char")).toList()),
          Row(children: right.map((char) => _buildSeat("$rowNum$char")).toList()),
        ],
      ),
    );
  }

  Widget _buildSeat(String seatId) {
    bool isSelected = _selectedSeats.contains(seatId);
    bool isOccupied = _occupiedSeats.contains(seatId);
    final primary = const Color(0xFF4F46E5);

    return GestureDetector(
      onTap: () => _toggleSeat(seatId),
      child: Container(
        width: 40,
        height: 40,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: isOccupied ? Colors.grey[300] : (isSelected ? primary : Colors.white),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isSelected ? primary : Colors.grey[300]!),
        ),
        alignment: Alignment.center,
        child: Text(
          seatId,
          style: TextStyle(
            color: isSelected ? Colors.white : (isOccupied ? Colors.grey[500] : Colors.black54),
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildLegendItem(BuildContext context, String label, SeatStatus status) {
    Color color;
    switch (status) {
      case SeatStatus.available: color = Colors.white; break;
      case SeatStatus.selected: color = const Color(0xFF4F46E5); break;
      case SeatStatus.occupied: color = Colors.grey[300]!; break;
    }
    return Row(
      children: [
        Container(
          width: 12, height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
            border: status == SeatStatus.available ? Border.all(color: Colors.grey[300]!) : null,
          ),
        ),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  Widget _buildIconBtn(IconData icon, VoidCallback onTap) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[800] : Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: IconButton(
        icon: Icon(icon, size: 18, color: isDark ? Colors.white : Colors.black),
        onPressed: onTap,
      ),
    );
  }
}

enum SeatStatus { available, selected, occupied }
