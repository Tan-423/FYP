import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geocoding/geocoding.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../CarRental/carreturn.dart';
import '../CarRental/Carcancel_booking.dart';
import '../CarRental/report_incident.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
        stream: FirebaseAuth.instance.userChanges(),
        builder: (context, authSnapshot) {
          final User? currentUser = authSnapshot.data ?? FirebaseAuth.instance.currentUser;
          final String userEmail = currentUser?.email ?? 'guest@example.com';
          final String userId = currentUser?.uid ?? '';
          final String displayName = (currentUser?.displayName?.trim().isNotEmpty == true)
              ? currentUser!.displayName!
              : userEmail.split('@').first;

          return Scaffold(
            backgroundColor: const Color(0xFFF6F7F8),
            appBar: AppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              title: const Text("My Profile", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
              actions: [
                IconButton(
                    icon: const Icon(Icons.logout, color: Colors.red),
                    onPressed: () {
                      showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text("Log Out"),
                            content: const Text("Are you sure you want to log out?"),
                            actions: [
                              TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text("Cancel")
                              ),
                              ElevatedButton(
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                                  onPressed: () async {
                                    await FirebaseAuth.instance.signOut();
                                    if (context.mounted) {
                                      Navigator.of(context).popUntil((route) => route.isFirst);
                                    }
                                  },
                                  child: const Text("Log Out")
                              ),
                            ],
                          )
                      );
                    }
                )
              ],
            ),
            body: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                      width: double.infinity,
                      color: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: Column(
                          children: [
                            Container(width: 100, height: 100, decoration: BoxDecoration(color: Colors.blue.shade100, shape: BoxShape.circle), child: Icon(Icons.person, size: 60, color: Colors.blue.shade700)),
                            const SizedBox(height: 16),
                            Text(displayName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)),
                            const SizedBox(height: 4),
                            Text(userEmail, style: TextStyle(fontSize: 14, color: Colors.grey.shade600))
                          ]
                      )
                  ),
                  const SizedBox(height: 24),

                  // PERSONAL INFO SECTION
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24),
                    child: _PersonalInfoCard(),
                  ),
                  const SizedBox(height: 24),

                  // BUS TICKETS SECTION
                  _buildBusTicketsSection(userId),

                  const SizedBox(height: 32),
                  // CAR RENTALS SECTION
                  CarRentalsSection(userEmail: userEmail),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          );
        }
    );
  }

  // ==========================================
  // BUS TICKETS DATA FETCHING
  // ==========================================
  Widget _buildBusTicketsSection(String userId) {
    if (userId.isEmpty) {
      return const Padding(
          padding: EdgeInsets.symmetric(horizontal: 24),
          child: Text("Please log in to view bus trips.", style: TextStyle(color: Colors.grey))
      );
    }

    return StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('tickets').where('userId', isEqualTo: userId).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Padding(padding: const EdgeInsets.symmetric(horizontal: 24), child: Text("Error loading tickets: ${snapshot.error}", style: const TextStyle(color: Colors.red)));
          }

          var docs = snapshot.data?.docs ?? [];

          docs.sort((a, b) {
            Timestamp? tA = (a.data() as Map<String, dynamic>)['timestamp'] as Timestamp?;
            Timestamp? tB = (b.data() as Map<String, dynamic>)['timestamp'] as Timestamp?;
            if (tA == null) return 1; if (tB == null) return -1;
            return tB.compareTo(tA);
          });

          DateTime realNow = DateTime.now().toUtc().add(const Duration(hours: 8));
          DateTime todayStart = DateTime(realNow.year, realNow.month, realNow.day);

          List<QueryDocumentSnapshot> upcomingTrips = [];
          List<QueryDocumentSnapshot> pastTrips = [];

          for (var doc in docs) {
            var data = doc.data() as Map<String, dynamic>;

            DateTime tripDate;
            try {
              String dateString = data['date'] ?? '';
              List<String> parts = dateString.split('-');
              if (parts.length == 3) {
                tripDate = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
              } else {
                tripDate = todayStart;
              }
            } catch (e) {
              tripDate = todayStart;
            }

            if (tripDate.isBefore(todayStart)) {
              pastTrips.add(doc);
            } else {
              upcomingTrips.add(doc);
            }
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(padding: EdgeInsets.symmetric(horizontal: 24), child: Text("Upcoming Bus Trips", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
              const SizedBox(height: 12),
              if (upcomingTrips.isEmpty)
                Padding(padding: const EdgeInsets.symmetric(horizontal: 24), child: Text("No upcoming bus trips.", style: TextStyle(color: Colors.grey.shade500)))
              else
                SizedBox(
                    height: 165,
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      scrollDirection: Axis.horizontal,
                      itemCount: upcomingTrips.length,
                      itemBuilder: (context, index) => _buildBusCard(context, upcomingTrips[index], isPast: false),
                    )
                ),

              const SizedBox(height: 32),

              const Padding(padding: EdgeInsets.symmetric(horizontal: 24), child: Text("Past Bus Trips", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
              const SizedBox(height: 12),
              if (pastTrips.isEmpty)
                Padding(padding: const EdgeInsets.symmetric(horizontal: 24), child: Text("No past bus trips.", style: TextStyle(color: Colors.grey.shade500)))
              else
                SizedBox(
                    height: 165,
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      scrollDirection: Axis.horizontal,
                      itemCount: pastTrips.length,
                      itemBuilder: (context, index) => _buildBusCard(context, pastTrips[index], isPast: true),
                    )
                ),
            ],
          );
        }
    );
  }

  Widget _buildBusCard(BuildContext context, QueryDocumentSnapshot doc, {required bool isPast}) {
    var data = doc.data() as Map<String, dynamic>;
    String busName = data['busName'] ?? 'Unknown Bus';
    String busId = data['busId'] ?? '';
    String dateStr = data['date'] ?? 'Unknown Date';
    List<String> seats = List<String>.from(data['seats'] ?? []);
    String qrData = data['qrData'] ?? 'NO_QR_DATA';
    bool isRated = data['isRated'] ?? false;

    return Container(
        width: 260,
        margin: const EdgeInsets.only(right: 16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))]),
        child: Row(
            children: [
              Expanded(
                  flex: 2,
                  child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(color: isPast ? Colors.grey.shade200 : Colors.blue.shade50, borderRadius: BorderRadius.circular(4)),
                                child: Text(
                                    isPast ? "COMPLETED" : "UPCOMING",
                                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isPast ? Colors.grey : Colors.blue)
                                )
                            ),
                            const SizedBox(height: 8),
                            Text(busName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16), maxLines: 1, overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 4),
                            Row(children: [Icon(Icons.calendar_month, size: 12, color: Colors.grey.shade500), const SizedBox(width: 4), Text(dateStr, style: TextStyle(fontSize: 11, color: Colors.grey.shade500))]),
                            const SizedBox(height: 12),
                            const Text("SEAT(S)", style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Wrap(
                                spacing: 6, runSpacing: 6,
                                children: seats.map((seat) => Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(6)), child: Text(seat, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)))).toList()
                            )
                          ]
                      )
                  )
              ),
              Container(width: 1, color: Colors.grey.shade200),
              Expanded(
                  flex: 1,
                  child: GestureDetector(
                    onTap: () {
                      if (!isPast) {
                        _showQRCodeDialog(context, qrData, busName, dateStr, seats);
                      } else {
                        if (!isRated) {
                          _showRateTripDialog(context, doc.id, busId, busName);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("You have already rated this trip. Thank you!")));
                        }
                      }
                    },
                    child: Container(
                      color: Colors.transparent,
                      child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                                !isPast ? Icons.qr_code : (isRated ? Icons.star : Icons.star_border),
                                color: !isPast ? const Color(0xFF137FEC) : (isRated ? Colors.amber : Colors.orange),
                                size: 32
                            ),
                            const SizedBox(height: 8),
                            Text(
                                !isPast ? "View QR" : (isRated ? "Rated" : "Rate Trip"),
                                style: TextStyle(
                                    color: !isPast ? const Color(0xFF137FEC) : (isRated ? Colors.amber.shade700 : Colors.orange.shade700),
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold
                                )
                            )
                          ]
                      ),
                    ),
                  )
              )
            ]
        )
    );
  }

  // ⭐ FIXED FUNCTION: NORMALIZES NAMES AND SYNCS ALL ROUTES
  void _showRateTripDialog(BuildContext context, String ticketId, String busId, String busName) {
    int selectedRating = 0;
    bool isSubmitting = false;

    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return StatefulBuilder(
              builder: (context, setState) {
                return Dialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  backgroundColor: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text("Rate Your Trip", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black)),
                        const SizedBox(height: 8),
                        Text(busName, style: const TextStyle(fontSize: 16, color: Colors.black87, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
                        const SizedBox(height: 24),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(5, (index) {
                            return IconButton(
                              icon: Icon(
                                index < selectedRating ? Icons.star_rounded : Icons.star_border_rounded,
                                color: Colors.amber,
                                size: 40,
                              ),
                              onPressed: () {
                                setState(() {
                                  selectedRating = index + 1;
                                });
                              },
                            );
                          }),
                        ),

                        const SizedBox(height: 16),
                        Text(
                            selectedRating == 0 ? "Tap a star to rate" : "$selectedRating out of 5",
                            style: TextStyle(fontSize: 14, color: Colors.grey.shade600)
                        ),
                        const SizedBox(height: 32),

                        if (isSubmitting)
                          const CircularProgressIndicator()
                        else
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => Navigator.pop(context),
                                  style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                                  ),
                                  child: const Text("Cancel"),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: selectedRating == 0 ? null : () async {
                                    setState(() => isSubmitting = true);

                                    try {
                                      final ticketRef = FirebaseFirestore.instance.collection('tickets').doc(ticketId);

                                      // ⭐ FETCH ALL ROUTES REGARDLESS OF NAME (We will filter manually)
                                      final routesSnapshot = await FirebaseFirestore.instance.collection('bus_routes').get();

                                      // Convert the target name to completely lowercase for safe matching
                                      String targetNameLower = busName.toLowerCase().trim();

                                      List<DocumentSnapshot> matchingRoutes = [];
                                      int maxCount = 0;
                                      double currentTotal = 0.0;

                                      // ⭐ MANUALLY FIND ALL MATCHES
                                      for (var doc in routesSnapshot.docs) {
                                        var data = doc.data();
                                        String dbName = (data['Busname'] ?? data['busName'] ?? '').toString().toLowerCase().trim();

                                        if (dbName == targetNameLower) {
                                          matchingRoutes.add(doc);
                                          int docCount = data['ratingCount'] ?? 0;
                                          if (docCount >= maxCount) {
                                            maxCount = docCount;
                                            currentTotal = (data['totalRatingScore'] ?? 0).toDouble();
                                          }
                                        }
                                      }

                                      // Calculate new overall average
                                      double newTotal = currentTotal + selectedRating;
                                      int newCount = maxCount + 1;
                                      double newAverage = newTotal / newCount;

                                      // Use WriteBatch to update everything safely
                                      WriteBatch batch = FirebaseFirestore.instance.batch();

                                      // Mark ticket as rated
                                      batch.update(ticketRef, {
                                        'isRated': true,
                                        'ratingGiven': selectedRating
                                      });

                                      // ⭐ UPDATE ALL MATCHING ROUTES
                                      for (var doc in matchingRoutes) {
                                        batch.update(doc.reference, {
                                          'ratingCount': newCount,
                                          'totalRatingScore': newTotal,
                                          'rating': newAverage,
                                        });
                                      }

                                      await batch.commit();

                                      if (context.mounted) {
                                        Navigator.pop(context);
                                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Thank you for your feedback!"), backgroundColor: Colors.green));
                                      }
                                    } catch (e) {
                                      setState(() => isSubmitting = false);
                                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error submitting rating: $e")));
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF137FEC),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                                  ),
                                  child: const Text("Submit", style: TextStyle(fontWeight: FontWeight.bold)),
                                ),
                              ),
                            ],
                          )
                      ],
                    ),
                  ),
                );
              }
          );
        }
    );
  }

  void _showQRCodeDialog(BuildContext context, String qrData, String busName, String dateStr, List<String> seats) {
    showDialog(
        context: context,
        builder: (context) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("Boarding Pass", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black)),
                const SizedBox(height: 8),
                Text(busName, style: const TextStyle(fontSize: 16, color: Colors.black87, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
                const SizedBox(height: 4),
                Text("Date: $dateStr  •  Seats: ${seats.join(', ')}", style: TextStyle(fontSize: 14, color: Colors.grey.shade700)),

                const SizedBox(height: 32),

                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade300, width: 2),
                  ),
                  child: QrImageView(
                    data: qrData,
                    version: QrVersions.auto,
                    size: 200.0,
                    backgroundColor: Colors.white,
                  ),
                ),

                const SizedBox(height: 24),
                Text("Please present this QR code to the driver upon boarding.", textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF137FEC),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                    ),
                    child: const Text("Close", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                )
              ],
            ),
          ),
        )
    );
  }
}

// ==========================================
// PERSONAL INFO CARD
// ==========================================
class _PersonalInfoCard extends StatefulWidget {
  const _PersonalInfoCard();

  @override
  State<_PersonalInfoCard> createState() => _PersonalInfoCardState();
}

class _PersonalInfoCardState extends State<_PersonalInfoCard> {
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

  String _displayNameFor(User? user) {
    final display = user?.displayName?.trim();
    if (display != null && display.isNotEmpty) return display;
    final email = user?.email?.trim();
    if (email != null && email.isNotEmpty) return email.split('@').first;
    return 'Traveler';
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
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.userChanges(),
      builder: (context, snapshot) {
        final user = snapshot.data ?? FirebaseAuth.instance.currentUser;
        _syncName(user);
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10)],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Personal Info',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _nameController,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: 'Display name',
                  prefixIcon: Icon(Icons.person_rounded),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _isSaving ? null : () => _saveName(user),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF137FEC),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isSaving
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Save Name', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              if (_statusMessage != null) ...[
                const SizedBox(height: 8),
                Text(
                  _statusMessage!,
                  style: TextStyle(
                    color: _statusMessage == 'Name updated.' ? Colors.green : Colors.redAccent,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

// ==========================================
// CAR RENTALS SECTION
// ==========================================
class CarRentalsSection extends StatefulWidget {
  final String userEmail;
  const CarRentalsSection({super.key, required this.userEmail});

  @override
  State<CarRentalsSection> createState() => _CarRentalsSectionState();
}

class _CarRentalsSectionState extends State<CarRentalsSection> {
  int _selectedTab = 0;

  Widget _buildDynamicImage(String imageString) {
    if (imageString.isEmpty) return Container(color: Colors.grey[200], child: const Icon(Icons.directions_car, color: Colors.grey));
    if (imageString.startsWith('http')) return Image.network(imageString, fit: BoxFit.cover, errorBuilder: (c, e, s) => Container(color: Colors.grey[200]));
    try {
      String cleanBase64 = imageString.contains(',') ? imageString.split(',').last : imageString;
      return Image.memory(base64Decode(cleanBase64), fit: BoxFit.cover, errorBuilder: (c, e, s) => Container(color: Colors.grey[200]));
    } catch (e) { return Container(color: Colors.grey[200]); }
  }

  Future<String> _fetchCarAddress(String carId) async {
    try {
      var carDoc = await FirebaseFirestore.instance.collection('rental_cars').doc(carId).get();
      if (carDoc.exists && carDoc.data() != null) {
        double lat = carDoc['lat'];
        double lng = carDoc['lng'];
        String coordString = "\nCoords: ${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}";
        try {
          List<Placemark> placemarks = await placemarkFromCoordinates(lat, lng);
          if (placemarks.isNotEmpty) {
            Placemark place = placemarks.first;
            List<String> parts = [];
            if (place.name != null && place.name!.isNotEmpty) parts.add(place.name!);
            if (place.street != null && place.street!.isNotEmpty) parts.add(place.street!);
            if (place.locality != null && place.locality!.isNotEmpty) parts.add(place.locality!);
            parts = parts.toSet().toList();
            return (parts.isNotEmpty ? parts.join(", ") : "Location mapped") + coordString;
          }
        } catch (e) { return "Map Location$coordString"; }
        return "Map Location$coordString";
      }
    } catch (e) { return "Unknown Location"; }
    return "Unknown Location";
  }

  void _showManageBookingOptions(BuildContext context, QueryDocumentSnapshot doc) {
    var data = doc.data() as Map<String, dynamic>;
    String carId = data['carId'] ?? '';

    showModalBottomSheet(
        context: context,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (context) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 16), decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
                  const Text("Manage Booking", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  ListTile(
                    leading: const Icon(Icons.cancel_outlined, color: Colors.red),
                    title: const Text("Cancel Booking", style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (context) => CancelBookingScreen(bookingId: doc.id, carId: carId, carName: data['carName'] ?? 'Unknown Car', imageUrl: data['imageUrl'] ?? '', startDate: DateTime.tryParse(data['startDate'] ?? '') ?? DateTime.now(), endDate: DateTime.tryParse(data['endDate'] ?? '') ?? DateTime.now(), totalPrice: (data['totalPrice'] ?? 0).toDouble(), confirmationNo: doc.id.substring(0, 6).toUpperCase())));
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.assignment_return_outlined, color: Color(0xFF137FEC)),
                    title: const Text("Return Car", style: TextStyle(fontWeight: FontWeight.w600)),
                    onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (context) => CarReturnScreen(bookingId: doc.id, carId: carId))); },
                  ),
                  ListTile(
                    leading: const Icon(Icons.report_problem_outlined, color: Colors.orange),
                    title: const Text("Report Incident", style: TextStyle(fontWeight: FontWeight.w600)),
                    onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (context) => ReportIncidentScreen(bookingId: doc.id, carId: carId, carName: data['carName'] ?? 'Unknown Car'))); },
                  ),
                ],
              ),
            ),
          );
        }
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.userEmail.isEmpty) return const SizedBox();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('car_bookings').where('userEmail', isEqualTo: widget.userEmail).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Padding(padding: const EdgeInsets.symmetric(horizontal: 24), child: Text("Error: ${snapshot.error}", style: const TextStyle(color: Colors.red)));
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(padding: EdgeInsets.symmetric(horizontal: 24), child: Text("Car Rentals", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                const SizedBox(height: 12),
                Padding(padding: const EdgeInsets.symmetric(horizontal: 24), child: Text("No car rentals booked yet.", style: TextStyle(color: Colors.grey.shade500))),
              ]
          );
        }

        var allDocs = snapshot.data!.docs;
        allDocs.sort((a, b) {
          Timestamp? tA = (a.data() as Map<String, dynamic>)['bookedAt'] as Timestamp?; Timestamp? tB = (b.data() as Map<String, dynamic>)['bookedAt'] as Timestamp?;
          if (tA == null) return -1; if (tB == null) return 1; return tB.compareTo(tA);
        });

        var upcomingDocs = allDocs.where((d) => (d.data() as Map<String, dynamic>)['status'] == 'Upcoming').toList();
        var completedDocs = allDocs.where((d) => (d.data() as Map<String, dynamic>)['status'] == 'Completed').toList();
        var cancelledDocs = allDocs.where((d) {
          String status = (d.data() as Map<String, dynamic>)['status'] ?? '';
          return status == 'Cancelled' || status == 'Pending Cancellation' || status == 'Incident Reported';
        }).toList();

        QueryDocumentSnapshot? nextTripDoc = upcomingDocs.isNotEmpty ? upcomingDocs.first : null;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (nextTripDoc != null) ...[const Padding(padding: EdgeInsets.symmetric(horizontal: 24), child: Text("Your Next Car Rental", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF111418)))), const SizedBox(height: 16), _buildNextTripCard(nextTripDoc, context), const SizedBox(height: 24)],
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(12)),
                child: Row(
                  children: [
                    Expanded(child: GestureDetector(onTap: () => setState(() => _selectedTab = 0), child: Container(padding: const EdgeInsets.symmetric(vertical: 10), decoration: BoxDecoration(color: _selectedTab == 0 ? Colors.white : Colors.transparent, borderRadius: BorderRadius.circular(8), boxShadow: _selectedTab == 0 ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))] : []), alignment: Alignment.center, child: Text("Recent History", style: TextStyle(fontWeight: FontWeight.bold, color: _selectedTab == 0 ? Colors.black : Colors.grey.shade600, fontSize: 13))))),
                    Expanded(child: GestureDetector(onTap: () => setState(() => _selectedTab = 1), child: Container(padding: const EdgeInsets.symmetric(vertical: 10), decoration: BoxDecoration(color: _selectedTab == 1 ? Colors.white : Colors.transparent, borderRadius: BorderRadius.circular(8), boxShadow: _selectedTab == 1 ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))] : []), alignment: Alignment.center, child: Text("Cancelled", style: TextStyle(fontWeight: FontWeight.bold, color: _selectedTab == 1 ? Colors.black : Colors.grey.shade600, fontSize: 13))))),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_selectedTab == 1) cancelledDocs.isEmpty ? Padding(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16), child: Center(child: Text("No cancelled trips.", style: TextStyle(color: Colors.grey.shade500)))) : ListView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), padding: const EdgeInsets.symmetric(horizontal: 24), itemCount: cancelledDocs.length, itemBuilder: (context, index) => _buildHistoryCard(cancelledDocs[index]))
            else completedDocs.isEmpty ? Padding(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16), child: Center(child: Text("No past trips found.", style: TextStyle(color: Colors.grey.shade500)))) : ListView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), padding: const EdgeInsets.symmetric(horizontal: 24), itemCount: completedDocs.length, itemBuilder: (context, index) => _buildHistoryCard(completedDocs[index])),
          ],
        );
      },
    );
  }

  Widget _buildNextTripCard(QueryDocumentSnapshot doc, BuildContext context) {
    var data = doc.data() as Map<String, dynamic>;
    DateTime startDate = DateTime.tryParse(data['startDate'] ?? '') ?? DateTime.now();
    DateTime endDate = DateTime.tryParse(data['endDate'] ?? '') ?? DateTime.now();
    int days = endDate.difference(startDate).inDays + 1; if(days <= 0) days = 1;
    double totalPrice = (data['totalPrice'] ?? 0).toDouble(); double pricePerDay = totalPrice / days;
    String dateRange = "${DateFormat('MMM d').format(startDate)} – ${DateFormat('MMM d').format(endDate)}";
    String dayDetails = "$days Days • ${DateFormat('E, h:mm a').format(startDate)} Pickup";
    String confirmationNo = doc.id.substring(0, 6).toUpperCase();
    String carId = data['carId'] ?? '';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 16, offset: const Offset(0, 8))], border: Border.all(color: Colors.grey.shade100)),
      child: Column(
        children: [
          Stack(children: [SizedBox(height: 160, width: double.infinity, child: ClipRRect(borderRadius: const BorderRadius.vertical(top: Radius.circular(16)), child: _buildDynamicImage(data['imageUrl'] ?? ''))), Positioned(top: 12, right: 12, child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4)]), child: const Text("Upcoming", style: TextStyle(color: Color(0xFF137FEC), fontWeight: FontWeight.bold, fontSize: 12))))]),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, crossAxisAlignment: CrossAxisAlignment.end, children: [Expanded(child: Text(data['carName'] ?? 'Unknown Car', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF111418)), maxLines: 1, overflow: TextOverflow.ellipsis)), Text("\$${pricePerDay.toStringAsFixed(0)}/day", style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.w600, fontSize: 14))]), const SizedBox(height: 16),
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const Icon(Icons.calendar_today, color: Color(0xFF137FEC), size: 18), const SizedBox(width: 12), Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(dateRange, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF111418))), const SizedBox(height: 2), Text(dayDetails, style: TextStyle(color: Colors.grey.shade500, fontSize: 12))])]), const SizedBox(height: 16),
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const Icon(Icons.location_on, color: Color(0xFF137FEC), size: 18), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text("Return Location", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF111418))), const SizedBox(height: 2), FutureBuilder<String>(future: _fetchCarAddress(carId), builder: (context, snapshot) { if (snapshot.connectionState == ConnectionState.waiting) return Text("Loading address...", style: TextStyle(color: Colors.grey.shade500, fontSize: 12)); return Text(snapshot.data ?? "Location unavailable", style: TextStyle(color: Colors.grey.shade600, fontSize: 12, height: 1.4), maxLines: 4); })]))]),
                const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Divider(height: 1)),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text("Confirmation", style: TextStyle(color: Colors.grey.shade500, fontSize: 11)), Text("#$confirmationNo", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF111418)))]), ElevatedButton(onPressed: () => _showManageBookingOptions(context, doc), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF137FEC), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12), elevation: 0), child: const Text("Manage Booking", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)))])
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildHistoryCard(QueryDocumentSnapshot doc) {
    var data = doc.data() as Map<String, dynamic>;
    DateTime startDate = DateTime.tryParse(data['startDate'] ?? '') ?? DateTime.now();
    DateTime endDate = DateTime.tryParse(data['endDate'] ?? '') ?? DateTime.now();
    double totalPrice = (data['totalPrice'] ?? 0).toDouble();
    String status = data['status'] ?? 'Completed';
    String dateRange = "${DateFormat('MMM d').format(startDate)} - ${DateFormat('MMM d').format(endDate)}";

    Color badgeBgColor;
    Color badgeTextColor;
    String badgeText;

    if (status == 'Cancelled') { badgeBgColor = Colors.red.shade50; badgeTextColor = Colors.red.shade700; badgeText = 'CANCELLED'; }
    else if (status == 'Pending Cancellation') { badgeBgColor = Colors.orange.shade50; badgeTextColor = Colors.orange.shade700; badgeText = 'PENDING'; }
    else if (status == 'Incident Reported') { badgeBgColor = Colors.orange.shade50; badgeTextColor = Colors.orange.shade700; badgeText = 'INCIDENT'; }
    else { badgeBgColor = Colors.green.shade50; badgeTextColor = Colors.green.shade700; badgeText = 'COMPLETED'; }

    return Container(
      margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 2))]),
      child: Row(
        children: [
          SizedBox(width: 64, height: 64, child: ClipRRect(borderRadius: BorderRadius.circular(8), child: _buildDynamicImage(data['imageUrl'] ?? ''))), const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Expanded(child: Text(data['carName'] ?? 'Unknown Car', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF111418)), maxLines: 1, overflow: TextOverflow.ellipsis)), Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: badgeBgColor, borderRadius: BorderRadius.circular(4)), child: Text(badgeText, style: TextStyle(color: badgeTextColor, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.5)))]), const SizedBox(height: 4), Text("$dateRange • Kuala Lumpur", style: TextStyle(color: Colors.grey.shade500, fontSize: 12)), const SizedBox(height: 4), Text("\$${totalPrice.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF111418)))])),
          const Padding(padding: EdgeInsets.only(left: 8), child: Icon(Icons.chevron_right, color: Colors.grey, size: 20))
        ],
      ),
    );
  }
}