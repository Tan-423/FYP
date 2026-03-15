import 'dart:async';
import 'dart:convert';
import 'dart:math' show cos, sqrt, asin, pi;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import '../main.dart';

class TripSchedulePage extends StatefulWidget {
  final SeasonalTrip? tripTemplate;
  final String? savedTripId;

  const TripSchedulePage({super.key, this.tripTemplate, this.savedTripId});

  @override
  State<TripSchedulePage> createState() => _TripSchedulePageState();
}

class _TripSchedulePageState extends State<TripSchedulePage> {
  int _selectedDay = 0;
  bool _isSaving = false;
  bool _isOptimizing = false;

  Map<String, dynamic> _savedItinerary = {};
  String _savedTitle = "";
  DateTime? _savedStartDate;
  DateTime? _savedEndDate;

  // Dynamic center location
  double _tripCenterLat = 3.140853;
  double _tripCenterLng = 101.693207;

  @override
  void initState() {
    super.initState();
    if (widget.savedTripId != null) {
      _loadSavedTrip();
    }
  }

  Future<void> _loadSavedTrip() async {
    try {
      var doc =
          await FirebaseFirestore.instance
              .collection('trips')
              .doc(widget.savedTripId)
              .get();
      if (doc.exists) {
        var data = doc.data()!;
        setState(() {
          _savedTitle = data['tripName'] ?? 'My Trip';
          _savedItinerary = data['itinerary'] ?? {};
          _savedStartDate = (data['startDate'] as Timestamp).toDate();
          _savedEndDate = (data['endDate'] as Timestamp).toDate();

          _tripCenterLat = data['defaultLat'] ?? 3.140853;
          _tripCenterLng = data['defaultLng'] ?? 101.693207;
        });
      }
    } catch (e) {
      debugPrint("Error loading saved trip: $e");
    }
  }

  // ==========================================
  // HAVERSINE DISTANCE FORMULA (KM)
  // ==========================================
  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    var p = pi / 180;
    var a =
        0.5 -
        cos((lat2 - lat1) * p) / 2 +
        cos(lat1 * p) * cos(lat2 * p) * (1 - cos((lon2 - lon1) * p)) / 2;
    return 12742 * asin(sqrt(a));
  }

  // ==========================================
  // AUTO-RIPPLE TIMES
  // ==========================================
  void _recalculateTimes(String dayKey) {
    List<dynamic> activities = List.from(_savedItinerary[dayKey] ?? []);
    if (activities.isEmpty) return;

    DateTime currentTime = DateTime(2024, 1, 1, 9, 0);

    for (int i = 0; i < activities.length; i++) {
      var act = activities[i];
      int stayMinutes = act['stayMinutes'] ?? 60;

      DateTime endTime = currentTime.add(Duration(minutes: stayMinutes));

      act['startTime'] = DateFormat('hh:mm a').format(currentTime);
      act['endTime'] = DateFormat('hh:mm a').format(endTime);
      act['duration'] = '$stayMinutes min';

      int travelMinutes = 15;
      if (i < activities.length - 1) {
        var nextAct = activities[i + 1];
        double lat1 = act['lat'] ?? _tripCenterLat;
        double lng1 = act['lng'] ?? _tripCenterLng;
        double lat2 = nextAct['lat'] ?? _tripCenterLat;
        double lng2 = nextAct['lng'] ?? _tripCenterLng;

        double distanceKm = _calculateDistance(lat1, lng1, lat2, lng2);
        travelMinutes = ((distanceKm / 30.0) * 60).round() + 5;
        if (travelMinutes < 10) travelMinutes = 10;
      }

      currentTime = endTime.add(Duration(minutes: travelMinutes));
      activities[i] = act;
    }

    _savedItinerary[dayKey] = activities;
  }

  // ==========================================
  // ROUTE OPTIMIZATION
  // ==========================================
  Future<void> _optimizeDaySchedule(String dayKey) async {
    setState(() => _isOptimizing = true);
    await Future.delayed(const Duration(milliseconds: 800));

    List<dynamic> dayActivities = List.from(_savedItinerary[dayKey] ?? []);
    if (dayActivities.length <= 1) {
      setState(() => _isOptimizing = false);
      return;
    }

    List<dynamic> optimizedRoute = [dayActivities.first];
    List<dynamic> unvisited = dayActivities.sublist(1);

    while (unvisited.isNotEmpty) {
      var current = optimizedRoute.last;
      double currentLat = current['lat'] ?? _tripCenterLat;
      double currentLng = current['lng'] ?? _tripCenterLng;

      var closestPlace = unvisited.first;
      double minDistance = double.infinity;

      for (var candidate in unvisited) {
        double candLat = candidate['lat'] ?? _tripCenterLat;
        double candLng = candidate['lng'] ?? _tripCenterLng;

        double distance = _calculateDistance(
          currentLat,
          currentLng,
          candLat,
          candLng,
        );
        if (distance < minDistance) {
          minDistance = distance;
          closestPlace = candidate;
        }
      }

      optimizedRoute.add(closestPlace);
      unvisited.remove(closestPlace);
    }

    _savedItinerary[dayKey] = optimizedRoute;
    _recalculateTimes(dayKey);

    await FirebaseFirestore.instance
        .collection('trips')
        .doc(widget.savedTripId)
        .update({'itinerary': _savedItinerary});

    setState(() => _isOptimizing = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("✨ Route optimized and schedules adjusted!"),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _editStayTime(
    String dayKey,
    int activityIndex,
    int currentMinutes,
  ) async {
    int selectedMinutes = currentMinutes;

    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.all(24),
              height: 300,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Set Stay Duration",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "How long do you plan to stay at this location?",
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Text(
                        "$selectedMinutes min",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                      Expanded(
                        child: Slider(
                          value: selectedMinutes.toDouble(),
                          min: 15,
                          max: 240,
                          divisions: 15,
                          activeColor: Theme.of(context).primaryColor,
                          onChanged:
                              (val) => setModalState(
                                () => selectedMinutes = val.toInt(),
                              ),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        "Save Duration",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (selectedMinutes != currentMinutes) {
      List<dynamic> dayActivities = List.from(_savedItinerary[dayKey] ?? []);
      dayActivities[activityIndex]['stayMinutes'] = selectedMinutes;
      dayActivities[activityIndex]['duration'] = '$selectedMinutes min';
      _savedItinerary[dayKey] = dayActivities;

      _recalculateTimes(dayKey);
      await FirebaseFirestore.instance
          .collection('trips')
          .doc(widget.savedTripId)
          .update({'itinerary': _savedItinerary});
      setState(() {});
    }
  }

  Future<void> _openCombinedAddMenu(String dayKey) async {
    final selectedPlace = await Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => GooglePlaceSearchScreen(
              initialLat: _tripCenterLat,
              initialLng: _tripCenterLng,
            ),
      ),
    );
    if (selectedPlace != null) {
      List<dynamic> dayActivities = List.from(_savedItinerary[dayKey] ?? []);
      dayActivities.add({
        'placeName': selectedPlace['name'],
        'description': selectedPlace['address'],
        'imageUrl': selectedPlace['imageUrl'],
        'lat': selectedPlace['lat'],
        'lng': selectedPlace['lng'],
        'stayMinutes': 60,
        'duration': '60 min',
      });

      _savedItinerary[dayKey] = dayActivities;
      _recalculateTimes(dayKey);

      await FirebaseFirestore.instance
          .collection('trips')
          .doc(widget.savedTripId)
          .update({'itinerary': _savedItinerary});
      setState(() {});
    }
  }

  Future<void> _implementPlan() async {
    if (widget.tripTemplate == null) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    setState(() => _isSaving = true);
    try {
      DateTime startDate = DateTime.now().add(const Duration(days: 14));
      DateTime endDate = startDate.add(
        Duration(days: widget.tripTemplate!.durationDays),
      );
      Map<String, dynamic> firebaseItinerary = {};
      widget.tripTemplate!.itinerary.forEach((dayKey, activities) {
        firebaseItinerary[dayKey] =
            activities
                .map(
                  (a) => {
                    'imageUrl': a.imageUrl,
                    'placeName': a.title,
                    'description': a.subtitle,
                    'duration': a.duration,
                    'stayMinutes': 60,
                    'lat': 3.140853,
                    'lng': 101.693207,
                  },
                )
                .toList();
      });
      await FirebaseFirestore.instance.collection('trips').add({
        'userId': user.uid,
        'tripName': widget.tripTemplate!.title,
        'startDate': Timestamp.fromDate(startDate),
        'endDate': Timestamp.fromDate(endDate),
        'itinerary': firebaseItinerary,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("🎉 '${widget.tripTemplate!.title}' saved!"),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _editDepartureDate() async {
    if (_savedStartDate == null || _savedEndDate == null) return;
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _savedStartDate!,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );
    if (picked != null && picked != _savedStartDate) {
      int durationDays = _savedEndDate!.difference(_savedStartDate!).inDays;
      DateTime newEnd = picked.add(Duration(days: durationDays));
      await FirebaseFirestore.instance
          .collection('trips')
          .doc(widget.savedTripId)
          .update({
            'startDate': Timestamp.fromDate(picked),
            'endDate': Timestamp.fromDate(newEnd),
          });
      setState(() {
        _savedStartDate = picked;
        _savedEndDate = newEnd;
      });
    }
  }

  Future<void> _deleteActivity(String dayKey, int activityIndex) async {
    List<dynamic> dayActivities = List.from(_savedItinerary[dayKey] ?? []);
    dayActivities.removeAt(activityIndex);
    _savedItinerary[dayKey] = dayActivities;
    _recalculateTimes(dayKey);

    await FirebaseFirestore.instance
        .collection('trips')
        .doc(widget.savedTripId)
        .update({'itinerary': _savedItinerary});
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = const Color(0xFFE85D3F);
    bool isSavedTrip = widget.savedTripId != null;

    String title =
        isSavedTrip
            ? _savedTitle
            : (widget.tripTemplate?.title ?? "Loading...");
    int durationDays =
        isSavedTrip
            ? (_savedEndDate != null && _savedStartDate != null
                ? _savedEndDate!.difference(_savedStartDate!).inDays + 1
                : 1)
            : (widget.tripTemplate?.durationDays ?? 1);

    DateTime baseDate =
        isSavedTrip && _savedStartDate != null
            ? _savedStartDate!
            : DateTime.now().add(const Duration(days: 14));

    String currentDayKey = 'day_$_selectedDay';
    List<dynamic> currentActivities =
        isSavedTrip
            ? (_savedItinerary[currentDayKey] ?? [])
            : (widget.tripTemplate?.itinerary[currentDayKey] ?? []);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        leadingWidth: 100,
        leading: TextButton.icon(
          onPressed: () => Navigator.pop(context),
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 20,
            color: primaryColor,
          ),
          label: Text(
            "Back",
            style: TextStyle(
              color: primaryColor,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        actions: [
          if (isSavedTrip)
            IconButton(
              icon: Icon(Icons.edit_calendar, color: primaryColor),
              tooltip: "Edit Departure Date",
              onPressed: _editDepartureDate,
            ),
        ],
      ),

      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton:
          !isSavedTrip
              ? SizedBox(
                width: MediaQuery.of(context).size.width * 0.9,
                height: 56,
                child: FloatingActionButton.extended(
                  onPressed: _isSaving ? null : _implementPlan,
                  backgroundColor: primaryColor,
                  icon:
                      _isSaving
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Icon(
                            Icons.download_done,
                            color: Colors.white,
                          ),
                  label: const Text(
                    "Implement Plan",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              )
              : null,

      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        child: Column(
          children: [
            Center(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
            ),

            if (isSavedTrip &&
                _savedStartDate != null &&
                _savedEndDate != null) ...[
              const SizedBox(height: 6),
              Center(
                child: Text(
                  "${DateFormat('MMM d').format(_savedStartDate!)} - ${DateFormat('MMM d, yyyy').format(_savedEndDate!)}",
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],

            const SizedBox(height: 24),

            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: List.generate(durationDays, (index) {
                  DateTime tabDate = baseDate.add(Duration(days: index));
                  String formattedDate = DateFormat('MMM d').format(tabDate);

                  return Padding(
                    padding: const EdgeInsets.only(right: 24.0),
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedDay = index),
                      child: _buildTab(
                        context,
                        "Day ${index + 1}",
                        formattedDate,
                        _selectedDay == index,
                        primaryColor,
                      ),
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 24),

            if (isSavedTrip && currentActivities.length > 1)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 24),
                child: ElevatedButton.icon(
                  onPressed:
                      _isOptimizing
                          ? null
                          : () => _optimizeDaySchedule(currentDayKey),
                  icon:
                      _isOptimizing
                          ? const SizedBox(
                            width: 16,
                            height: 16,
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
                  label: const Text(
                    "Optimize Route & Times",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 4,
                  ),
                ),
              ),

            if (currentActivities.isEmpty && !isSavedTrip)
              const Padding(
                padding: EdgeInsets.only(top: 40.0),
                child: Center(
                  child: Text(
                    "No activities planned.",
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              )
            else
              Stack(
                children: [
                  Positioned(
                    left: 15,
                    top: 32,
                    bottom: 40,
                    child: Container(
                      width: 2,
                      color: isDark ? Colors.grey[700] : Colors.grey[200],
                    ),
                  ),
                  Column(
                    children: [
                      for (int i = 0; i < currentActivities.length; i++) ...[
                        _buildTimelineItem(
                          context,
                          index: i + 1,
                          activity: currentActivities[i],
                          isSavedTrip: isSavedTrip,
                          dayKey: currentDayKey,
                          activityIndex: i,
                          primaryColor: primaryColor,
                        ),

                        if (i < currentActivities.length - 1)
                          _buildDistanceBadge(
                            currentActivities[i],
                            currentActivities[i + 1],
                          ),

                        if (i == currentActivities.length - 1)
                          const SizedBox(height: 24),
                      ],
                      if (isSavedTrip)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: _buildAddActivityButton(
                            context,
                            currentDayKey,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTab(
    BuildContext context,
    String title,
    String subtitle,
    bool isActive,
    Color primaryColor,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: isActive ? FontWeight.bold : FontWeight.w600,
            color:
                isActive
                    ? primaryColor
                    : (isDark
                        ? const Color(0xFF9CA3AF)
                        : const Color(0xFF6B7280)),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: isActive ? primaryColor.withOpacity(0.8) : Colors.grey,
          ),
        ),
        const SizedBox(height: 8),
        if (isActive)
          Container(
            height: 3,
            width: 40,
            decoration: BoxDecoration(
              color: primaryColor,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        if (!isActive) const SizedBox(height: 3),
      ],
    );
  }

  Widget _buildDistanceBadge(dynamic current, dynamic next) {
    double lat1 = 0, lng1 = 0, lat2 = 0, lng2 = 0;

    if (current is Map && current['lat'] != null && current['lng'] != null) {
      lat1 = current['lat'];
      lng1 = current['lng'];
    }
    if (next is Map && next['lat'] != null && next['lng'] != null) {
      lat2 = next['lat'];
      lng2 = next['lng'];
    }

    if (lat1 == 0 || lat2 == 0 || (lat1 == lat2 && lng1 == lng2))
      return const SizedBox(height: 24);

    double distance = _calculateDistance(lat1, lng1, lat2, lng2);
    int travelMins = ((distance / 30.0) * 60).round() + 5;
    if (travelMins < 10) travelMins = 10;

    return Row(
      children: [
        Container(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          margin: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.withOpacity(0.4)),
          ),
          child: Row(
            children: [
              Icon(Icons.directions_car, size: 14, color: Colors.grey[600]),
              const SizedBox(width: 6),
              Text(
                "${distance.toStringAsFixed(1)} km  •  $travelMins min",
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTimelineItem(
    BuildContext context, {
    required int index,
    required dynamic activity,
    required bool isSavedTrip,
    required String dayKey,
    required int activityIndex,
    required Color primaryColor,
  }) {
    String title = 'Activity';
    String subtitle = '';
    String imageUrl =
        'https://images.unsplash.com/photo-1476514525535-07fb3b4ae5f1?auto=format&fit=crop&w=600';
    String duration = '1 hr';
    int stayMinutes = 60;
    String? scheduledTime;

    if (isSavedTrip && activity is Map) {
      title =
          activity['placeName'] ??
          activity['name'] ??
          activity['title'] ??
          activity['destination'] ??
          'Activity';
      subtitle =
          activity['description'] ??
          activity['address'] ??
          activity['vicinity'] ??
          activity['details'] ??
          '';
      String? foundImage =
          activity['imageUrl'] ??
          activity['photoUrl'] ??
          activity['photo'] ??
          activity['image'];
      if (foundImage != null && foundImage.isNotEmpty) imageUrl = foundImage;
      duration = activity['duration'] ?? '1 hr';
      stayMinutes = activity['stayMinutes'] ?? 60;
      if (activity['startTime'] != null && activity['endTime'] != null)
        scheduledTime = "${activity['startTime']} - ${activity['endTime']}";
    } else if (!isSavedTrip && activity != null) {
      title = activity.title;
      subtitle = activity.subtitle;
      imageUrl = activity.imageUrl;
      duration = activity.duration;
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          margin: const EdgeInsets.only(top: 24),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            shape: BoxShape.circle,
            border: Border.all(color: primaryColor, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            "$index",
            style: TextStyle(
              color: primaryColor,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (scheduledTime != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.schedule,
                          size: 16,
                          color: Color(0xFF10B981),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          scheduledTime,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF10B981),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        imageUrl,
                        height: 160,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder:
                            (c, e, s) => Container(
                              height: 160,
                              color: Colors.grey[300],
                              child: const Icon(Icons.image),
                            ),
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: GestureDetector(
                        onTap: () {
                          if (isSavedTrip)
                            _editStayTime(dayKey, activityIndex, stayMinutes);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.75),
                            borderRadius: BorderRadius.circular(6),
                            border:
                                isSavedTrip
                                    ? Border.all(
                                      color: Colors.white.withOpacity(0.3),
                                      width: 1,
                                    )
                                    : null,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.timer,
                                color: Colors.white,
                                size: 12,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                duration,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (isSavedTrip) ...[
                                const SizedBox(width: 4),
                                const Icon(
                                  Icons.edit,
                                  color: Colors.white70,
                                  size: 10,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 4),
                          if (subtitle.isNotEmpty)
                            Text(
                              subtitle,
                              style: const TextStyle(
                                color: Colors.grey,
                                height: 1.4,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (isSavedTrip)
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.redAccent,
                        ),
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder:
                                (ctx) => AlertDialog(
                                  title: const Text("Delete Activity?"),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx),
                                      child: const Text("Cancel"),
                                    ),
                                    ElevatedButton(
                                      onPressed: () {
                                        Navigator.pop(ctx);
                                        _deleteActivity(dayKey, activityIndex);
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red,
                                      ),
                                      child: const Text(
                                        "Delete",
                                        style: TextStyle(color: Colors.white),
                                      ),
                                    ),
                                  ],
                                ),
                          );
                        },
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAddActivityButton(BuildContext context, String dayKey) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.grey, width: 2),
          ),
          child: const Icon(Icons.add, size: 16, color: Colors.grey),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: InkWell(
            onTap: () => _openCombinedAddMenu(dayKey),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade400, width: 2),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_location_alt, color: Colors.grey, size: 20),
                  SizedBox(width: 8),
                  Text(
                    "Add new activity",
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ==========================================
// COMBINED SEARCH & MAP SCREEN
// ==========================================
class GooglePlaceSearchScreen extends StatefulWidget {
  final double initialLat;
  final double initialLng;

  const GooglePlaceSearchScreen({
    super.key,
    required this.initialLat,
    required this.initialLng,
  });

  @override
  State<GooglePlaceSearchScreen> createState() =>
      _GooglePlaceSearchScreenState();
}

class _GooglePlaceSearchScreenState extends State<GooglePlaceSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isLoading = false;
  Timer? _debounce;

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    if (query.isEmpty) {
      setState(() => _searchResults = []);
      return;
    }

    setState(() => _isLoading = true);

    _debounce = Timer(const Duration(milliseconds: 600), () {
      List<Map<String, dynamic>> mockResults = [];
      if (query.toLowerCase().contains('cafe') ||
          query.toLowerCase().contains('coffee')) {
        mockResults = [
          {
            'name': 'VCR Cafe',
            'address': 'Jalan Galloway, Bukit Bintang',
            'imageUrl':
                'https://images.unsplash.com/photo-1554118811-1e0d58224f24?auto=format&fit=crop&w=600',
            'lat': 3.1438,
            'lng': 101.7061,
          },
          {
            'name': 'Feeka Coffee Roasters',
            'address': 'Jalan Mesui, Bukit Bintang',
            'imageUrl':
                'https://images.unsplash.com/photo-1497935586351-b67a49e012bf?auto=format&fit=crop&w=600',
            'lat': 3.1481,
            'lng': 101.7083,
          },
        ];
      } else if (query.toLowerCase().contains('kl') ||
          query.toLowerCase().contains('kuala')) {
        mockResults = [
          {
            'name': 'Petronas Twin Towers',
            'address': 'Kuala Lumpur City Centre',
            'imageUrl':
                'https://images.unsplash.com/photo-1596422846543-74c6e088876c?auto=format&fit=crop&w=600',
            'lat': 3.1579,
            'lng': 101.7116,
          },
          {
            'name': 'KL Tower',
            'address': 'Jalan P. Ramlee',
            'imageUrl':
                'https://images.unsplash.com/photo-1584646098378-0874589d76b1?auto=format&fit=crop&w=600',
            'lat': 3.1528,
            'lng': 101.7038,
          },
        ];
      } else {
        mockResults = [
          {
            'name': 'Batu Caves',
            'address': 'Gombak, Selangor',
            'imageUrl':
                'https://images.unsplash.com/photo-1605333830889-497793d5f308?auto=format&fit=crop&w=600',
            'lat': 3.2379,
            'lng': 101.6831,
          },
          {
            'name': 'Thean Hou Temple',
            'address': '65 Persiaran Endah',
            'imageUrl':
                'https://images.unsplash.com/photo-1616428782352-73a70e7e106a?auto=format&fit=crop&w=600',
            'lat': 3.1215,
            'lng': 101.6875,
          },
        ];
      }

      setState(() {
        _searchResults = mockResults;
        _isLoading = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = const Color(0xFFE85D3F);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: TextField(
          controller: _searchController,
          autofocus: true,
          onChanged: _onSearchChanged,
          decoration: InputDecoration(
            hintText: "Search places, hotels, cafes...",
            border: InputBorder.none,
            hintStyle: TextStyle(color: Colors.grey[400]),
          ),
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontSize: 18,
          ),
        ),
      ),
      body: Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 12,
            ),
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.map, color: Color(0xFF10B981)),
            ),
            title: const Text(
              "Choose on interactive map",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Color(0xFF10B981),
              ),
            ),
            subtitle: Text(
              "Drop a pin anywhere you want to go",
              style: TextStyle(color: Colors.grey[500]),
            ),
            onTap: () async {
              final selectedPlace = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder:
                      (context) => MapPickerScreen(
                        initialLat: widget.initialLat,
                        initialLng: widget.initialLng,
                      ),
                ),
              );
              if (selectedPlace != null) {
                if (context.mounted) Navigator.pop(context, selectedPlace);
              }
            },
          ),
          Divider(
            height: 1,
            color: isDark ? Colors.grey[800] : Colors.grey[200],
          ),

          Expanded(
            child:
                _isLoading
                    ? Center(
                      child: CircularProgressIndicator(color: primaryColor),
                    )
                    : _searchResults.isEmpty
                    ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search, size: 64, color: Colors.grey[300]),
                          const SizedBox(height: 16),
                          Text(
                            "Type to search locations",
                            style: TextStyle(color: Colors.grey[500]),
                          ),
                        ],
                      ),
                    )
                    : ListView.builder(
                      itemCount: _searchResults.length,
                      itemBuilder: (context, index) {
                        final place = _searchResults[index];
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 8,
                          ),
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: primaryColor.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.place, color: primaryColor),
                          ),
                          title: Text(
                            place['name'],
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          subtitle: Text(
                            place['address'],
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                          onTap: () => Navigator.pop(context, place),
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// ⭐ NEW: INTERACTIVE MAP PICKER (GOOGLE PLACES API INTEGRATION)
// ==========================================
class MapPickerScreen extends StatefulWidget {
  final double initialLat;
  final double initialLng;

  const MapPickerScreen({
    super.key,
    required this.initialLat,
    required this.initialLng,
  });

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  LatLng? _pickedLocation;
  bool _isFetchingName = false;
  String _resolvedName = "Selected Location";
  String _resolvedAddress = "";

  Future<void> _handleMapTap(LatLng latLng) async {
    setState(() {
      _pickedLocation = latLng;
      _isFetchingName = true;
    });

    // ⭐ FYP MAGIC: Use Google Places API to read the colored icons!
    // Paste your real API key here from your Google Cloud Console
    String apiKey = "YOUR_GOOGLE_MAPS_API_KEY_HERE";

    bool foundPOI = false;

    if (apiKey != "YOUR_GOOGLE_MAPS_API_KEY_HERE") {
      try {
        final String url =
            'https://maps.googleapis.com/maps/api/place/nearbysearch/json?location=${latLng.latitude},${latLng.longitude}&radius=30&key=$apiKey';

        final response = await http.get(Uri.parse(url));
        final data = json.decode(response.body);

        if (data['status'] == 'OK' && data['results'].isNotEmpty) {
          _resolvedName = data['results'][0]['name'];
          _resolvedAddress =
              data['results'][0]['vicinity'] ?? "Kuala Lumpur, Malaysia";
          foundPOI = true;
        }
      } catch (e) {
        debugPrint("Places API failed: $e");
      }
    }

    if (!foundPOI) {
      try {
        List<Placemark> placemarks = await placemarkFromCoordinates(
          latLng.latitude,
          latLng.longitude,
        );
        if (placemarks.isNotEmpty) {
          Placemark place = placemarks.first;
          String pName = place.name?.trim() ?? "";
          String pStreet = place.street?.trim() ?? "";
          String pThoroughfare = place.thoroughfare?.trim() ?? "";

          bool startsWithNumber = RegExp(r'^\d').hasMatch(pName);

          if (startsWithNumber || pName.length <= 3) {
            if (pThoroughfare.isNotEmpty &&
                !pName.toLowerCase().contains(pThoroughfare.toLowerCase())) {
              _resolvedName = "$pName $pThoroughfare";
            } else if (pStreet.isNotEmpty && pName.length <= 3) {
              _resolvedName = pStreet;
            } else {
              _resolvedName = pName.isNotEmpty ? pName : "Selected Location";
            }
          } else {
            _resolvedName = pName;
          }

          List<String> addressParts = [];
          if (place.subLocality != null && place.subLocality!.isNotEmpty)
            addressParts.add(place.subLocality!);
          if (place.locality != null && place.locality!.isNotEmpty)
            addressParts.add(place.locality!);
          _resolvedAddress =
              addressParts.isNotEmpty ? addressParts.join(", ") : "Dropped Pin";
        }
      } catch (e) {
        _resolvedName = "Dropped Pin";
        _resolvedAddress =
            "${latLng.latitude.toStringAsFixed(4)}, ${latLng.longitude.toStringAsFixed(4)}";
      }
    }

    setState(() => _isFetchingName = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Tap anywhere to add to trip",
          style: TextStyle(fontSize: 16),
        ),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: LatLng(widget.initialLat, widget.initialLng),
              zoom: 14,
            ),
            onTap: _handleMapTap,
            markers:
                _pickedLocation == null
                    ? {}
                    : {
                      Marker(
                        markerId: const MarkerId('picked_location'),
                        position: _pickedLocation!,
                        infoWindow: InfoWindow(title: _resolvedName),
                      ),
                    },
          ),
          if (_pickedLocation != null)
            Positioned(
              bottom: 40,
              left: 24,
              right: 24,
              child: Card(
                elevation: 12,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child:
                      _isFetchingName
                          ? const SizedBox(
                            height: 80,
                            child: Center(child: CircularProgressIndicator()),
                          )
                          : Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.place,
                                    color: Color(0xFFE85D3F),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _resolvedName,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Padding(
                                padding: const EdgeInsets.only(left: 32.0),
                                child: Text(
                                  _resolvedAddress,
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),
                              SizedBox(
                                width: double.infinity,
                                height: 48,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF135BEC),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  onPressed: () {
                                    Navigator.pop(context, {
                                      'name': _resolvedName,
                                      'address': _resolvedAddress,
                                      'lat': _pickedLocation!.latitude,
                                      'lng': _pickedLocation!.longitude,
                                      'imageUrl':
                                          'https://images.unsplash.com/photo-1524661135-423995f22d0b?auto=format&fit=crop&w=600',
                                    });
                                  },
                                  child: const Text(
                                    "Add to Trip Plan",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
