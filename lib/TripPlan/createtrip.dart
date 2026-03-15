import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geocoding/geocoding.dart'; // ⭐ NEW: To find the coordinates of typed destinations
import 'tripschedule.dart';

class CreateTripScreen extends StatefulWidget {
  const CreateTripScreen({super.key});

  @override
  State<CreateTripScreen> createState() => _CreateTripScreenState();
}

class _CreateTripScreenState extends State<CreateTripScreen> {
  static const LatLng _malaysiaCenter = LatLng(4.2105, 101.9758);

  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};

  final TextEditingController _tripNameController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  DateTimeRange? _selectedDateRange;
  final List<String> _destinations = ["Pahang, Malaysia"]; // Example default
  String? _selectedTransport;
  bool _isSaving = false;

  final List<String> _transportOptions = ['Walking', 'Car'];

  Future<void> _pickTravelDates() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF3B82F6),
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDateRange) {
      setState(() => _selectedDateRange = picked);
    }
  }

  void _onMapTapped(LatLng location) {
    setState(() {
      _markers.clear();
      _markers.add(
        Marker(
          markerId: const MarkerId('selected_dest'),
          position: location,
          infoWindow: const InfoWindow(title: 'New Destination'),
        ),
      );
    });
  }

  // ==========================================
  // CREATE TRIP LOGIC (WITH DYNAMIC MAP CENTERING)
  // ==========================================
  Future<void> _createAndOptimizeTrip() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Please log in to create a trip.",
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_tripNameController.text.trim().isEmpty || _selectedDateRange == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Please enter a Trip Name and Travel Dates.",
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      // ⭐ 1. DYNAMIC MAP CENTERING: Figure out where the trip actually is!
      double centerLat = _malaysiaCenter.latitude;
      double centerLng = _malaysiaCenter.longitude;

      // If they typed a destination (like "Pahang"), convert it to coordinates!
      if (_destinations.isNotEmpty) {
        try {
          List<Location> locations = await locationFromAddress(
            _destinations.first,
          );
          if (locations.isNotEmpty) {
            centerLat = locations.first.latitude;
            centerLng = locations.first.longitude;
          }
        } catch (e) {
          // If typing failed, fallback to where they dropped the map pin
          if (_markers.isNotEmpty) {
            centerLat = _markers.first.position.latitude;
            centerLng = _markers.first.position.longitude;
          }
        }
      }

      int durationDays =
          _selectedDateRange!.end.difference(_selectedDateRange!.start).inDays +
          1;
      Map<String, dynamic> generatedItinerary = {};

      for (int i = 0; i < durationDays; i++) {
        if (i == 0 && _destinations.isNotEmpty) {
          generatedItinerary['day_$i'] =
              _destinations.map((destName) {
                return {
                  'placeName': destName,
                  'description': 'Added from Map/Search',
                  'imageUrl':
                      'https://images.unsplash.com/photo-1476514525535-07fb3b4ae5f1?auto=format&fit=crop&w=600',
                  'stayMinutes': 60,
                  'duration': '60 min',
                  'lat': centerLat, // Use the new dynamic center
                  'lng': centerLng,
                };
              }).toList();
        } else {
          generatedItinerary['day_$i'] = [];
        }
      }

      // 2. Save to Firebase, including the calculated Map Center
      DocumentReference docRef = await FirebaseFirestore.instance
          .collection('trips')
          .add({
            'userId': user.uid,
            'tripName': _tripNameController.text.trim(),
            'startDate': Timestamp.fromDate(_selectedDateRange!.start),
            'endDate': Timestamp.fromDate(_selectedDateRange!.end),
            'transportMode': _selectedTransport ?? 'Car',
            'itinerary': generatedItinerary,
            'defaultLat': centerLat, // ⭐ Saves the center point of the trip!
            'defaultLng': centerLng,
            'createdAt': FieldValue.serverTimestamp(),
          });

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => TripSchedulePage(savedTripId: docRef.id),
          ),
        );
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error creating trip: $e"),
            backgroundColor: Colors.red,
          ),
        );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = const Color(0xFF3B82F6);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Create Trip",
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                height: 200,
                width: double.infinity,
                child: Stack(
                  children: [
                    GoogleMap(
                      initialCameraPosition: const CameraPosition(
                        target: _malaysiaCenter,
                        zoom: 5.5,
                      ),
                      onMapCreated: (controller) => _mapController = controller,
                      onTap: _onMapTapped,
                      markers: _markers,
                      myLocationButtonEnabled: false,
                      zoomControlsEnabled: true,
                    ),
                    Positioned(
                      top: 12,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.touch_app,
                                size: 16,
                                color: Colors.black87,
                              ),
                              SizedBox(width: 6),
                              Text(
                                "Tap map to drop a pin",
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            const Text(
              "Trip Name",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _tripNameController,
              decoration: InputDecoration(
                hintText: "e.g. Exploring Pahang",
                hintStyle: TextStyle(color: Colors.grey.shade400),
                prefixIcon: Icon(
                  Icons.edit,
                  color: Colors.grey.shade400,
                  size: 20,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: primaryColor, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 24),

            const Text(
              "Travel Dates",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: _pickTravelDates,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      color: Colors.grey.shade400,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _selectedDateRange == null
                          ? "Start Date  -  End Date"
                          : "${DateFormat('MMM d, yyyy').format(_selectedDateRange!.start)}  -  ${DateFormat('MMM d, yyyy').format(_selectedDateRange!.end)}",
                      style: TextStyle(
                        color:
                            _selectedDateRange == null
                                ? Colors.grey.shade400
                                : Colors.black87,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            const Text(
              "Destinations",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8.0,
              runSpacing: 8.0,
              children:
                  _destinations.map((dest) {
                    return Chip(
                      label: Text(
                        dest,
                        style: TextStyle(
                          color: primaryColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      backgroundColor: primaryColor.withOpacity(0.1),
                      deleteIcon: Icon(
                        Icons.close,
                        color: primaryColor,
                        size: 16,
                      ),
                      onDeleted:
                          () => setState(() => _destinations.remove(dest)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: const BorderSide(color: Colors.transparent),
                      ),
                    );
                  }).toList(),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: "Search & Add Destination",
                hintStyle: TextStyle(color: Colors.grey.shade400),
                prefixIcon: Icon(Icons.search, color: Colors.grey.shade400),
                filled: true,
                fillColor: const Color(0xFFF9FAFB),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onSubmitted: (value) {
                if (value.trim().isNotEmpty) {
                  setState(() {
                    _destinations.add(value.trim());
                    _searchController.clear();
                  });
                }
              },
            ),
            const SizedBox(height: 24),

            const Text(
              "Transportation",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _selectedTransport,
              hint: Text(
                "Select transport mode",
                style: TextStyle(color: Colors.grey.shade400),
              ),
              icon: Icon(Icons.arrow_drop_down, color: Colors.grey.shade400),
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
              ),
              items:
                  _transportOptions
                      .map(
                        (String mode) =>
                            DropdownMenuItem(value: mode, child: Text(mode)),
                      )
                      .toList(),
              onChanged:
                  (String? newValue) =>
                      setState(() => _selectedTransport = newValue),
            ),

            const SizedBox(height: 40),

            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _createAndOptimizeTrip,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
                icon:
                    _isSaving
                        ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                        : const Icon(
                          Icons.auto_awesome,
                          color: Colors.white,
                          size: 20,
                        ),
                label: Text(
                  _isSaving
                      ? "Creating Itinerary..."
                      : "Confirm & Optimize Trip",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
