import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart'; // ⭐ REQUIRED FOR DATE ERASING

class CarReturnScreen extends StatefulWidget {
  final String bookingId;
  final String carId;

  const CarReturnScreen({super.key, required this.bookingId, required this.carId});

  @override
  State<CarReturnScreen> createState() => _CarReturnScreenState();
}

class _CarReturnScreenState extends State<CarReturnScreen> {
  // Photos
  File? _frontPhoto;
  File? _backPhoto;
  File? _driverPhoto;
  File? _passengerPhoto;

  bool _isSubmitting = false;

  // Location Verification Variables
  double? _targetLat;
  double? _targetLng;
  String _destinationAddress = "Locating address...";

  bool _isVerifyingLocation = true;
  bool _isLocationVerified = false;
  double _distanceInMeters = 0.0;
  final double _allowedRadiusInMeters = 100.0;

  @override
  void initState() {
    super.initState();
    _fetchLocationAndVerify();
  }

  // FETCH CAR LOCATION & VERIFY USER GPS
  Future<void> _fetchLocationAndVerify() async {
    setState(() => _isVerifyingLocation = true);

    try {
      var carDoc = await FirebaseFirestore.instance.collection('rental_cars').doc(widget.carId).get();
      if (carDoc.exists) {
        _targetLat = carDoc['lat'];
        _targetLng = carDoc['lng'];
      }

      if (_targetLat == null || _targetLng == null) throw Exception("Car location missing");

      String coordString = "(${_targetLat!.toStringAsFixed(5)}, ${_targetLng!.toStringAsFixed(5)})";
      try {
        List<Placemark> placemarks = await placemarkFromCoordinates(_targetLat!, _targetLng!);
        if (placemarks.isNotEmpty) {
          Placemark place = placemarks.first;
          List<String> parts = [];
          if (place.name != null && place.name!.isNotEmpty) parts.add(place.name!);
          if (place.street != null && place.street!.isNotEmpty) parts.add(place.street!);
          if (place.locality != null && place.locality!.isNotEmpty) parts.add(place.locality!);
          parts = parts.toSet().toList();

          _destinationAddress = (parts.isNotEmpty ? parts.join(", ") : "Map Location") + "\nCoords: $coordString";
        } else {
          _destinationAddress = "Map Location\nCoords: $coordString";
        }
      } catch (e) {
        _destinationAddress = "Map Location\nCoords: $coordString";
      }

      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) throw Exception("GPS is disabled.");

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) throw Exception("Location permissions denied.");
      }

      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);

      double distance = Geolocator.distanceBetween(
          position.latitude, position.longitude,
          _targetLat!, _targetLng!
      );

      if (mounted) {
        setState(() {
          _distanceInMeters = distance;
          _isLocationVerified = distance <= _allowedRadiusInMeters;
          _isVerifyingLocation = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isVerifyingLocation = false;
          _isLocationVerified = false;
          _destinationAddress = "Location Unavailable";
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _launchNavigation() async {
    if (_targetLat == null || _targetLng == null) return;

    final Uri googleMapsUrl = Uri.parse("https://www.google.com/maps/dir/?api=1&destination=$_targetLat,$_targetLng");

    try {
      await launchUrl(googleMapsUrl, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("Could not open maps. Please ensure you have a browser or map app installed."),
            backgroundColor: Colors.red
        ));
      }
    }
  }

  Future<void> _takePhoto(String slot) async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 30);
    if (pickedFile != null) {
      setState(() {
        if (slot == "Front") _frontPhoto = File(pickedFile.path);
        else if (slot == "Back") _backPhoto = File(pickedFile.path);
        else if (slot == "Driver Side") _driverPhoto = File(pickedFile.path);
        else if (slot == "Passenger Side") _passengerPhoto = File(pickedFile.path);
      });
    }
  }

  // ⭐ FULLY UPDATED RETURN LOGIC (Clears Dates from DB!)
  Future<void> _submitReturn() async {
    if (!_isLocationVerified) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("You must be at the drop-off location to return the vehicle."), backgroundColor: Colors.red));
      return;
    }

    if (_frontPhoto == null || _backPhoto == null || _driverPhoto == null || _passengerPhoto == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please take all 4 photos before returning."), backgroundColor: Colors.red));
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // 1. Mark Booking as Completed
      await FirebaseFirestore.instance.collection('car_bookings').doc(widget.bookingId).update({'status': 'Completed'});

      // 2. Fetch the booking details to know exactly which dates to erase
      var bookingDoc = await FirebaseFirestore.instance.collection('car_bookings').doc(widget.bookingId).get();
      List<String> datesToRemove = [];
      String carName = "";

      if (bookingDoc.exists && bookingDoc.data() != null) {
        carName = bookingDoc.data()!['carName'] ?? "";
        String startStr = bookingDoc.data()!['startDate'] ?? "";
        String endStr = bookingDoc.data()!['endDate'] ?? "";

        if (startStr.isNotEmpty && endStr.isNotEmpty) {
          DateTime start = DateTime.parse(startStr);
          DateTime end = DateTime.parse(endStr);
          DateTime current = DateTime(start.year, start.month, start.day);
          DateTime last = DateTime(end.year, end.month, end.day);

          while (!current.isAfter(last)) {
            datesToRemove.add(DateFormat('yyyy-MM-dd').format(current));
            current = current.add(const Duration(days: 1));
          }
        }
      }

      // ⭐ ALWAYS ensure today is removed, just in case they return early!
      String todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
      if (!datesToRemove.contains(todayStr)) {
        datesToRemove.add(todayStr);
      }

      // 3. Aggressive sweep to clear dates out of the car database
      if (carName.isNotEmpty) {
        var carQuery = await FirebaseFirestore.instance.collection('rental_cars').where('name', isEqualTo: carName).get();
        for (var doc in carQuery.docs) {
          List<dynamic> dbDates = List.from(doc.data()['bookedDates'] ?? []);
          dbDates.removeWhere((d) => datesToRemove.contains(d.toString())); // Erase the calendar blocks

          await FirebaseFirestore.instance.collection('rental_cars').doc(doc.id).update({
            'bookedDates': dbDates,
            'status': 'available'
          });
        }
      } else if (widget.carId.isNotEmpty) {
        // Fallback if carName was somehow missing
        var carDoc = await FirebaseFirestore.instance.collection('rental_cars').doc(widget.carId).get();
        if (carDoc.exists) {
          List<dynamic> dbDates = List.from(carDoc.data()?['bookedDates'] ?? []);
          dbDates.removeWhere((d) => datesToRemove.contains(d.toString()));
          await FirebaseFirestore.instance.collection('rental_cars').doc(widget.carId).update({
            'bookedDates': dbDates,
            'status': 'available'
          });
        }
      }

      if (mounted) {
        showDialog(
            context: context, barrierDismissible: false,
            builder: (c) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text("Vehicle Returned!"),
              content: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 64), SizedBox(height: 16),
                  Text("Thank you! The vehicle inspection is complete and the car is now returned.", textAlign: TextAlign.center),
                ],
              ),
              actionsAlignment: MainAxisAlignment.center,
              actions: [
                ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF137FEC), foregroundColor: Colors.white),
                    onPressed: () { Navigator.pop(c); Navigator.pop(context); },
                    child: const Text("Back to Profile")
                )
              ],
            )
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const primaryColor = Color(0xFF137FEC);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF101922) : const Color(0xFFF6F7F8),
      appBar: AppBar(
        leading: Center(
          child: Container(
            width: 40, height: 40,
            decoration: BoxDecoration(shape: BoxShape.circle, color: isDark ? Colors.grey[800] : Colors.grey[200]),
            child: IconButton(
              padding: EdgeInsets.zero,
              icon: Icon(Icons.arrow_back, size: 20, color: isDark ? Colors.white : const Color(0xFF111418)),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ),
        title: Text("Return Vehicle", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF111418))),
        centerTitle: true,
      ),
      body: _isSubmitting
          ? const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [CircularProgressIndicator(), SizedBox(height: 16), Text("Processing return...")]))
          : Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Full Address UI
                  Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("1. Drop-off Location", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF111418))),
                          const SizedBox(height: 8),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.location_pin, color: primaryColor, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                    _destinationAddress,
                                    style: TextStyle(fontSize: 13, color: isDark ? Colors.grey[400] : const Color(0xFF617589), fontWeight: FontWeight.w600, height: 1.4)
                                ),
                              ),
                            ],
                          )
                        ],
                      )
                  ),

                  // REAL INTERACTIVE MAP CARD
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    height: 200, width: double.infinity, clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))]),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (_targetLat != null && _targetLng != null)
                          GoogleMap(
                            initialCameraPosition: CameraPosition(target: LatLng(_targetLat!, _targetLng!), zoom: 15),
                            markers: { Marker(markerId: const MarkerId('dropoff'), position: LatLng(_targetLat!, _targetLng!), icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed)) },
                            zoomControlsEnabled: false, mapToolbarEnabled: false, myLocationEnabled: true,
                          )
                        else
                          Container(color: Colors.grey.shade300, child: const Center(child: CircularProgressIndicator())),

                        Container(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [Colors.black.withOpacity(0.5), Colors.transparent]))),

                        Positioned(
                          bottom: 12, right: 12,
                          child: ElevatedButton.icon(
                            onPressed: _launchNavigation,
                            icon: const Icon(Icons.near_me, size: 18), label: const Text("Navigate"),
                            style: ElevatedButton.styleFrom(backgroundColor: primaryColor, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), elevation: 4),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // DYNAMIC LOCATION STATUS VERIFICATION
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: isDark ? const Color(0xFF1A242D) : Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 2, offset: const Offset(0, 1))]),
                    child: Row(
                      children: [
                        Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                                color: _isVerifyingLocation ? Colors.grey.withOpacity(0.2) : (_isLocationVerified ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2)),
                                shape: BoxShape.circle
                            ),
                            child: Icon(
                                _isVerifyingLocation ? Icons.hourglass_empty : (_isLocationVerified ? Icons.check_circle : Icons.error),
                                color: _isVerifyingLocation ? Colors.grey : (_isLocationVerified ? Colors.green : Colors.red), size: 24
                            )
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                    _isVerifyingLocation ? "Verifying Location..." : (_isLocationVerified ? "Location Verified" : "Location Not Verified"),
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF111418))
                                ),
                                const SizedBox(height: 2),
                                Text(
                                    _isVerifyingLocation ? "Checking GPS..." : (_isLocationVerified ? "You are in the designated drop-off zone." : "You are ${_distanceInMeters.toStringAsFixed(0)}m away from the drop-off zone."),
                                    style: TextStyle(fontSize: 13, color: isDark ? Colors.grey[400] : const Color(0xFF617589))
                                )
                              ]
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.refresh, color: primaryColor),
                          onPressed: _fetchLocationAndVerify,
                        )
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Section 2: Vehicle Condition
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("2. Vehicle Condition", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF111418))),
                        const SizedBox(height: 8),
                        Text("Please upload photos of the vehicle to document its condition and avoid any dispute fees.", style: TextStyle(fontSize: 14, color: isDark ? Colors.grey[400] : const Color(0xFF617589), height: 1.5)),
                        const SizedBox(height: 16),

                        GridView.count(
                          crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 4 / 3,
                          children: [
                            _buildPhotoSlot(label: "Front", file: _frontPhoto),
                            _buildPhotoSlot(label: "Back", file: _backPhoto),
                            _buildPhotoSlot(label: "Driver Side", file: _driverPhoto),
                            _buildPhotoSlot(label: "Passenger Side", file: _passengerPhoto),
                          ],
                        ),
                        const SizedBox(height: 16),

                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: isDark ? Colors.blue[900]!.withOpacity(0.2) : Colors.blue[50], borderRadius: BorderRadius.circular(8)),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.info_outline, size: 20, color: isDark ? Colors.blue[300] : Colors.blue[700]), const SizedBox(width: 12),
                              Expanded(child: Text("Make sure the license plate is visible in the Front and Back photos.", style: TextStyle(fontSize: 14, color: isDark ? Colors.blue[300] : Colors.blue[700]))),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // --- Sticky Footer ---
          Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            decoration: BoxDecoration(color: isDark ? const Color(0xFF1A242D) : Colors.white, border: Border(top: BorderSide(color: isDark ? const Color(0xFF2D3748) : const Color(0xFFE5E7EB))), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6, offset: const Offset(0, -4))]),
            child: SizedBox(
              width: double.infinity, height: 48,
              child: ElevatedButton(
                onPressed: _submitReturn, // Triggers DB update!
                style: ElevatedButton.styleFrom(
                    backgroundColor: _isLocationVerified ? primaryColor : Colors.grey, // Grey out if not verified
                    foregroundColor: Colors.white, elevation: 2, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: EdgeInsets.zero
                ),
                child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_isLocationVerified ? "Confirm Return" : "Must be at Location", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward, size: 20)
                    ]
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDot(Color color) => Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle));

  Widget _buildPhotoSlot({required String label, File? file}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const primaryColor = Color(0xFF137FEC);

    if (file != null) {
      return Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.file(file, fit: BoxFit.cover)),
          Container(decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: Colors.black.withOpacity(0.3))),
          Positioned(bottom: 8, left: 12, child: Text(label.toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 0.5))),
          Positioned(top: 8, right: 8, child: Container(padding: const EdgeInsets.all(4), decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle), child: const Icon(Icons.check, color: Colors.white, size: 16))),
        ],
      );
    } else {
      return CustomPaint(
        painter: _DashedBorderPainter(color: isDark ? Colors.grey[700]! : Colors.grey[300]!, strokeWidth: 2, radius: 12, gap: 6),
        child: InkWell(
          onTap: () => _takePhoto(label),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            decoration: BoxDecoration(color: isDark ? const Color(0xFF1A242D) : Colors.white, borderRadius: BorderRadius.circular(12)),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: isDark ? primaryColor.withOpacity(0.1) : Colors.grey[100], shape: BoxShape.circle), child: Icon(Icons.camera_alt_outlined, color: Colors.grey[400], size: 24)),
                const SizedBox(height: 8),
                Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF111418))),
              ],
            ),
          ),
        ),
      );
    }
  }
}

class _DashedBorderPainter extends CustomPainter {
  final Color color; final double strokeWidth; final double radius; final double gap;
  _DashedBorderPainter({required this.color, required this.strokeWidth, required this.radius, required this.gap});

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()..color = color..strokeWidth = strokeWidth..style = PaintingStyle.stroke;
    final Path path = Path()..addRRect(RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, size.width, size.height), Radius.circular(radius)));
    final Path dashedPath = Path();
    double distance = 0.0;
    for (final PathMetric metric in path.computeMetrics()) {
      while (distance < metric.length) {
        dashedPath.addPath(metric.extractPath(distance, distance + gap), Offset.zero);
        distance += gap * 2;
      }
    }
    canvas.drawPath(dashedPath, paint);
  }
  @override bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}