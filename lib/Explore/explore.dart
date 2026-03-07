import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geocoding/geocoding.dart'; // ⭐ NEW: Added for map tapping

// ==========================================
// 1. DATA MODELS
// ==========================================
class Viewpoint {
  final String id;
  final String title;
  final String category;
  final double distance;
  final double rating;
  final int reviews;
  final String imageUrl;
  final LatLng location;
  final List<String> tags;

  Viewpoint({
    required this.id,
    required this.title,
    required this.category,
    required this.distance,
    required this.rating,
    required this.reviews,
    required this.imageUrl,
    required this.location,
    required this.tags,
  });
}

class RouteStep {
  final String instruction;
  final List<LatLng> points;

  RouteStep({required this.instruction, required this.points});
}

// ==========================================
// 2. EXPLORE SCREEN
// ==========================================
class MapViewScreen extends StatefulWidget {
  const MapViewScreen({super.key});

  @override
  State<MapViewScreen> createState() => _MapViewScreenState();
}

class _MapViewScreenState extends State<MapViewScreen> {
  final String _googleMapsApiKey = "AIzaSyDBJEa2AqdPURKVJKFTDxAV7VJVQUtFkN4"; // ⚠️ Replace with your API key

  final Completer<GoogleMapController> _mapController = Completer();
  final TextEditingController _searchController = TextEditingController();

  final FlutterTts _flutterTts = FlutterTts();
  bool _isVoiceOn = true;
  int _lastSpokenStepIndex = -1;

  LatLng _currentLocation = const LatLng(3.1412, 101.6865);
  bool _isLoadingLocation = true;
  bool _isLoadingPlaces = false;
  bool _isCustomLocation = false;

  String _selectedFilter = "For You";
  bool _isOfflineMode = false;
  Viewpoint? _selectedViewpoint;
  List<Viewpoint> _allViewpoints = [];

  // LIVE NAVIGATION VARIABLES
  bool _isNavigating = false;
  StreamSubscription<Position>? _positionStream;
  LatLng? _carLocation;
  double _distanceRemaining = 0.0;

  Set<Polyline> _polylines = {};
  List<RouteStep> _navigationSteps = [];
  int _currentStepIndex = 0;
  String _currentInstruction = "Calculating route...";

  @override
  void initState() {
    super.initState();
    _initializeRealTimeData();
    _initTTS();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _positionStream?.cancel();
    _flutterTts.stop();
    super.dispose();
  }

  Future<void> _initTTS() async {
    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);
  }

  Future<void> _speakInstruction(String text) async {
    if (_isVoiceOn) {
      await _flutterTts.speak(text);
    }
  }

  Future<void> _initializeRealTimeData() async {
    setState(() {
      _isLoadingLocation = true;
      _isCustomLocation = false;
      _searchController.clear();
    });

    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _fallbackToDummyData();
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _fallbackToDummyData();
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _fallbackToDummyData();
      return;
    }

    Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);

    setState(() {
      _currentLocation = LatLng(position.latitude, position.longitude);
      _isLoadingLocation = false;
    });

    _moveCamera(_currentLocation, zoom: 14.0);
    _fetchLivePlacesFromGoogle(_selectedFilter);
  }

  Future<void> _fetchLivePlacesFromGoogle(String filter, {String searchQuery = ""}) async {
    if (_googleMapsApiKey == "YOUR_API_KEY_HERE" || _googleMapsApiKey.isEmpty) {
      _fallbackToDummyData(searchQuery);
      return;
    }

    setState(() => _isLoadingPlaces = true);
    String url = '';

    if (searchQuery.isNotEmpty) {
      url = 'https://maps.googleapis.com/maps/api/place/textsearch/json?query=${Uri.encodeComponent(searchQuery)}&key=$_googleMapsApiKey';
    } else {
      String type = 'tourist_attraction';
      int radius = 5000;
      if (filter == "Nature") type = 'park';
      if (filter == "Nearby") { type = 'point_of_interest'; radius = 1500; }
      if (filter == "Top Rated") type = 'museum';

      url = 'https://maps.googleapis.com/maps/api/place/nearbysearch/json?location=${_currentLocation.latitude},${_currentLocation.longitude}&radius=$radius&type=$type&key=$_googleMapsApiKey';
    }

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'OK') {
          List<dynamic> results = data['results'];
          List<Viewpoint> fetchedSpots = [];

          if (searchQuery.isNotEmpty && results.isNotEmpty) {
            double lat = results.first['geometry']['location']['lat'];
            double lng = results.first['geometry']['location']['lng'];
            LatLng newCenter = LatLng(lat, lng);

            setState(() {
              _currentLocation = newCenter;
              _isCustomLocation = true;
            });
            _moveCamera(newCenter, zoom: 13.0);
          }

          for (var place in results) {
            String photoUrl = "https://images.unsplash.com/photo-1476514525535-07fb3b4ae5f1?auto=format&fit=crop&w=600";
            if (place['photos'] != null && place['photos'].isNotEmpty) {
              String photoRef = place['photos'][0]['photo_reference'];
              photoUrl = "https://maps.googleapis.com/maps/api/place/photo?maxwidth=600&photoreference=$photoRef&key=$_googleMapsApiKey";
            }

            double distanceInMeters = Geolocator.distanceBetween(
                _currentLocation.latitude, _currentLocation.longitude,
                place['geometry']['location']['lat'], place['geometry']['location']['lng']
            );

            String displayCategory = "ATTRACTION";
            if (place['types'] != null && (place['types'] as List).isNotEmpty) {
              displayCategory = place['types'][0].toString().replaceAll('_', ' ').toUpperCase();
            }

            fetchedSpots.add(Viewpoint(
              id: place['place_id'],
              title: place['name'],
              category: displayCategory,
              distance: double.parse((distanceInMeters / 1000).toStringAsFixed(1)),
              rating: (place['rating'] ?? 0.0).toDouble(),
              reviews: place['user_ratings_total'] ?? 0,
              location: LatLng(place['geometry']['location']['lat'], place['geometry']['location']['lng']),
              imageUrl: photoUrl,
              tags: ["#explore"],
            ));
          }

          if (filter == "Top Rated" && searchQuery.isEmpty) {
            fetchedSpots.sort((a, b) => b.rating.compareTo(a.rating));
          }

          setState(() => _allViewpoints = fetchedSpots);
        } else {
          setState(() => _allViewpoints = []);
        }
      }
    } catch (e) {
      debugPrint("Error fetching places: $e");
    }

    setState(() => _isLoadingPlaces = false);
  }

  void _fallbackToDummyData([String searchQuery = ""]) {
    setState(() {
      _isLoadingLocation = false;
      _isLoadingPlaces = false;
      _allViewpoints = [
        Viewpoint(id: "1", title: "KLCC Park", category: "Nature", distance: 1.2, rating: 4.8, reviews: 1240, imageUrl: "https://images.unsplash.com/photo-1596422846543-75c6fc197f0a?auto=format&fit=crop&w=600&q=80", location: const LatLng(3.1556, 101.7144), tags: ["#nature"]),
      ];
    });
  }

  // ==============================================================
  // ⭐ NEW: ARBITRARY MAP TAP (CUSTOM DESTINATION CREATION)
  // ==============================================================
  Future<void> _handleMapTap(LatLng latLng) async {
    if (_isNavigating) return;

    setState(() {
      _isLoadingPlaces = true;
      _selectedViewpoint = null;
    });

    String resolvedName = "Selected Location";
    String resolvedCategory = "CUSTOM DESTINATION";
    bool foundPOI = false;

    // 1. Try Google Places API to snap to a business or park
    if (_googleMapsApiKey != "YOUR_API_KEY_HERE" && _googleMapsApiKey.isNotEmpty) {
      try {
        final url = 'https://maps.googleapis.com/maps/api/place/nearbysearch/json?location=${latLng.latitude},${latLng.longitude}&radius=30&key=$_googleMapsApiKey';
        final response = await http.get(Uri.parse(url));
        final data = json.decode(response.body);

        if (data['status'] == 'OK' && data['results'].isNotEmpty) {
          resolvedName = data['results'][0]['name'];
          if (data['results'][0]['types'] != null && data['results'][0]['types'].isNotEmpty) {
            resolvedCategory = data['results'][0]['types'][0].toString().replaceAll('_', ' ').toUpperCase();
          }
          foundPOI = true;
        }
      } catch (e) {
        debugPrint("Places API failed: $e");
      }
    }

    // 2. Fallback to standard Street Geocoding if it's an empty road
    if (!foundPOI) {
      try {
        List<Placemark> placemarks = await placemarkFromCoordinates(latLng.latitude, latLng.longitude);
        if (placemarks.isNotEmpty) {
          Placemark place = placemarks.first;
          String pName = place.name?.trim() ?? "";
          String pStreet = place.street?.trim() ?? "";
          String pThoroughfare = place.thoroughfare?.trim() ?? "";

          bool startsWithNumber = RegExp(r'^\d').hasMatch(pName);
          if (startsWithNumber || pName.length <= 3) {
            if (pThoroughfare.isNotEmpty && !pName.toLowerCase().contains(pThoroughfare.toLowerCase())) {
              resolvedName = "$pName $pThoroughfare";
            } else if (pStreet.isNotEmpty && pName.length <= 3) {
              resolvedName = pStreet;
            } else {
              resolvedName = pName.isNotEmpty ? pName : "Selected Location";
            }
          } else {
            resolvedName = pName;
          }
        }
      } catch (e) {
        resolvedName = "Dropped Pin";
      }
    }

    // Calculate distance from current user location to tapped point
    double distanceInMeters = Geolocator.distanceBetween(
        _currentLocation.latitude, _currentLocation.longitude,
        latLng.latitude, latLng.longitude
    );

    // Generate a temporary Viewpoint to allow navigation!
    Viewpoint customPoint = Viewpoint(
      id: "custom_${DateTime.now().millisecondsSinceEpoch}",
      title: resolvedName,
      category: resolvedCategory,
      distance: double.parse((distanceInMeters / 1000).toStringAsFixed(1)),
      rating: 0.0,
      reviews: 0,
      imageUrl: "https://images.unsplash.com/photo-1524661135-423995f22d0b?auto=format&fit=crop&w=600",
      location: latLng,
      tags: ["#custom_destination"],
    );

    setState(() {
      _isLoadingPlaces = false;
      _selectedViewpoint = customPoint;
    });

    _moveCamera(latLng, zoom: 16.0);
  }

  // ==============================================================
  // 🗺️ ROUTE DRAWING & DECODING
  // ==============================================================
  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> poly = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      poly.add(LatLng((lat / 1E5).toDouble(), (lng / 1E5).toDouble()));
    }
    return poly;
  }

  Future<void> _fetchDirectionsAndStart() async {
    if (_selectedViewpoint == null) return;

    setState(() {
      _isNavigating = true;
      _carLocation = _currentLocation;
      _currentInstruction = "Calculating route...";
      _lastSpokenStepIndex = -1;
    });

    String url = 'https://maps.googleapis.com/maps/api/directions/json?'
        'origin=${_currentLocation.latitude},${_currentLocation.longitude}'
        '&destination=${_selectedViewpoint!.location.latitude},${_selectedViewpoint!.location.longitude}'
        '&key=$_googleMapsApiKey';

    try {
      var response = await http.get(Uri.parse(url));
      var data = jsonDecode(response.body);

      if (data['status'] == 'OK') {
        var route = data['routes'][0];
        var leg = route['legs'][0];

        List<RouteStep> parsedSteps = [];
        List<LatLng> allRoutePoints = [];

        for (var step in leg['steps']) {
          String rawInstruction = step['html_instructions'].replaceAll(RegExp(r'<[^>]*>'), '');
          List<LatLng> points = _decodePolyline(step['polyline']['points']);

          parsedSteps.add(RouteStep(instruction: rawInstruction, points: points));
          allRoutePoints.addAll(points);
        }

        setState(() {
          _navigationSteps = parsedSteps;
          _polylines = {
            Polyline(
              polylineId: const PolylineId('route'),
              color: Colors.blueAccent,
              width: 6,
              points: allRoutePoints,
            )
          };
          if (_navigationSteps.isNotEmpty) {
            _currentInstruction = _navigationSteps[0].instruction;
          }
        });

        _speakInstruction("Starting route. ${_currentInstruction}");
        _startLiveTracking();

      } else {
        _stopNavigation();
        String googleError = data['error_message'] ?? data['status'] ?? "Unknown Error";
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Routing Failed: $googleError"), backgroundColor: Colors.red, duration: const Duration(seconds: 5))
        );
      }
    } catch (e) {
      _stopNavigation();
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Network error while calculating route."), backgroundColor: Colors.red)
      );
    }
  }

  // ==============================================================
  // 🚗 LIVE GPS TRACKING
  // ==============================================================
  void _startLiveTracking() {
    _currentStepIndex = 0;
    _positionStream?.cancel();

    _positionStream = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 2,
        )
    ).listen((Position position) {
      if (!mounted || !_isNavigating) return;

      LatLng newPos = LatLng(position.latitude, position.longitude);

      double bearing = Geolocator.bearingBetween(
          _carLocation!.latitude, _carLocation!.longitude,
          newPos.latitude, newPos.longitude
      );

      setState(() {
        _carLocation = newPos;
        _currentLocation = newPos;

        if (_selectedViewpoint != null) {
          _distanceRemaining = Geolocator.distanceBetween(
              newPos.latitude, newPos.longitude,
              _selectedViewpoint!.location.latitude, _selectedViewpoint!.location.longitude
          );
        }

        if (_navigationSteps.isNotEmpty && _currentStepIndex < _navigationSteps.length) {
          var currentStep = _navigationSteps[_currentStepIndex];
          LatLng targetPoint = currentStep.points.last;

          double distToTurn = Geolocator.distanceBetween(
              newPos.latitude, newPos.longitude,
              targetPoint.latitude, targetPoint.longitude
          );

          if (distToTurn < 25) {
            _currentStepIndex++;
            if (_currentStepIndex < _navigationSteps.length) {
              _currentInstruction = _navigationSteps[_currentStepIndex].instruction;
            }
          } else {
            _currentInstruction = currentStep.instruction;
          }

          if (_currentStepIndex != _lastSpokenStepIndex) {
            _speakInstruction(_currentInstruction);
            _lastSpokenStepIndex = _currentStepIndex;
          }
        }
      });

      if (_distanceRemaining < 30) {
        _finishNavigation();
      } else {
        _moveCamera(newPos, zoom: 19.0, tilt: 60.0, bearing: bearing, animate: true);
      }
    });
  }

  void _finishNavigation() {
    _stopNavigation();
    _speakInstruction("You have arrived at your destination.");
    showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text("You've Arrived!", textAlign: TextAlign.center),
          content: const Icon(Icons.flag_circle, color: Colors.green, size: 64),
          actions: [
            Center(
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor),
                child: const Text("Awesome", style: TextStyle(color: Colors.white)),
              ),
            )
          ],
        )
    );
  }

  void _stopNavigation() {
    _positionStream?.cancel();
    _flutterTts.stop();
    setState(() {
      _isNavigating = false;
      _carLocation = null;
      _polylines.clear();
      _selectedViewpoint = null;
    });
    _moveCamera(_currentLocation, zoom: 14.0, tilt: 0.0, bearing: 0.0, animate: true);
  }

  Set<Marker> _buildMarkers() {
    Set<Marker> markers = _allViewpoints.map((vp) {
      return Marker(
        markerId: MarkerId(vp.id),
        position: vp.location,
        infoWindow: InfoWindow(title: vp.title),
        icon: BitmapDescriptor.defaultMarkerWithHue(
          vp.category.contains("PARK") || vp.category.contains("NATURE") ? BitmapDescriptor.hueGreen : BitmapDescriptor.hueRed,
        ),
        onTap: () {
          if (!_isNavigating) {
            setState(() => _selectedViewpoint = vp);
            _moveCamera(vp.location, zoom: 16.0);
          }
        },
      );
    }).toSet();

    // Show Custom Pin if the user tapped arbitrarily on the map
    if (_selectedViewpoint != null && _selectedViewpoint!.id.startsWith("custom_")) {
      markers.add(Marker(
        markerId: MarkerId(_selectedViewpoint!.id),
        position: _selectedViewpoint!.location,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueMagenta), // Unique color for custom pins
        infoWindow: InfoWindow(title: _selectedViewpoint!.title),
      ));
    }

    if (_isCustomLocation && !_isNavigating) {
      markers.add(Marker(
        markerId: const MarkerId("custom_search"),
        position: _currentLocation,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        infoWindow: const InfoWindow(title: "Search Area"),
      ));
    }

    if (_isNavigating && _carLocation != null) {
      markers.add(Marker(
        markerId: const MarkerId("car"),
        position: _carLocation!,
        zIndex: 2,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
      ));
    }

    return markers;
  }

  Future<void> _moveCamera(LatLng target, {double zoom = 14.0, double tilt = 0.0, double bearing = 0.0, bool animate = true}) async {
    final GoogleMapController controller = await _mapController.future;
    final cameraPosition = CameraPosition(target: target, zoom: zoom, tilt: tilt, bearing: bearing);

    if (animate) {
      controller.animateCamera(CameraUpdate.newCameraPosition(cameraPosition));
    } else {
      controller.moveCamera(CameraUpdate.newCameraPosition(cameraPosition));
    }
  }

  void _onMapLongPress(LatLng newLocation) {
    if (_isNavigating) return;

    setState(() {
      _currentLocation = newLocation;
      _isCustomLocation = true;
      _selectedViewpoint = null;
      _searchController.clear();
    });

    _moveCamera(newLocation, zoom: 14.0);
    _fetchLivePlacesFromGoogle(_selectedFilter);
  }

  void _onFilterChanged(String label) {
    setState(() {
      _selectedFilter = label;
      _selectedViewpoint = null;
    });
    _fetchLivePlacesFromGoogle(label, searchQuery: _searchController.text.trim());
  }

  void _performTextSearch() {
    FocusScope.of(context).unfocus();
    String query = _searchController.text.trim();
    if (query.isNotEmpty) {
      _fetchLivePlacesFromGoogle(_selectedFilter, searchQuery: query);
    }
  }

  // ==========================================
  // RATING LOGIC (CROSS-ACCOUNT)
  // ==========================================
  Future<void> _showRatingDialog(Viewpoint vp) async {
    int selectedStars = 0;

    await showDialog(
        context: context,
        builder: (context) {
          return StatefulBuilder(
              builder: (context, setDialogState) {
                return AlertDialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  title: Text("Rate ${vp.title}", textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold)),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text("How was your experience?"),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(5, (index) {
                          return IconButton(
                            icon: Icon(
                              index < selectedStars ? Icons.star : Icons.star_border,
                              color: Colors.amber,
                              size: 36,
                            ),
                            onPressed: () {
                              setDialogState(() {
                                selectedStars = index + 1;
                              });
                            },
                          );
                        }),
                      ),
                    ],
                  ),
                  actionsAlignment: MainAxisAlignment.center,
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
                    ),
                    ElevatedButton(
                      onPressed: selectedStars > 0 ? () {
                        Navigator.pop(context);
                        _submitRatingToFirebase(vp, selectedStars);
                      } : null,
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).primaryColor,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                      ),
                      child: const Text("Submit", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ],
                );
              }
          );
        }
    );
  }

  Future<void> _submitRatingToFirebase(Viewpoint vp, int newRating) async {
    final docRef = FirebaseFirestore.instance.collection('places').doc(vp.id);

    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);

        if (!snapshot.exists) {
          double totalScore = (vp.rating * vp.reviews) + newRating;
          int newReviews = vp.reviews + 1;

          transaction.set(docRef, {
            'rating': totalScore / newReviews,
            'reviews': newReviews,
            'totalScore': totalScore,
            'name': vp.title,
          });
        } else {
          int currentReviews = snapshot.data()?['reviews'] ?? 0;
          double currentTotalScore = (snapshot.data()?['totalScore'] ?? 0).toDouble();

          int newReviews = currentReviews + 1;
          double newTotalScore = currentTotalScore + newRating;

          transaction.update(docRef, {
            'rating': newTotalScore / newReviews,
            'reviews': newReviews,
            'totalScore': newTotalScore,
          });
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Thank you! Your rating has been saved."), backgroundColor: Colors.green)
        );
      }
    } catch (e) {
      debugPrint("Failed to save rating: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          Positioned.fill(
            child: _isLoadingLocation
                ? const Center(child: CircularProgressIndicator())
                : GoogleMap(
              initialCameraPosition: CameraPosition(target: _currentLocation, zoom: 14.0),
              markers: _buildMarkers(),
              polylines: _polylines,
              myLocationEnabled: !_isNavigating,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              mapToolbarEnabled: false,
              onMapCreated: (GoogleMapController controller) {
                if (!_mapController.isCompleted) {
                  _mapController.complete(controller);
                }
              },
              onTap: _handleMapTap, // ⭐ CONNECTED: Tapping anywhere builds a custom route!
              onLongPress: _onMapLongPress,
            ),
          ),

          if (_isOfflineMode)
            Positioned(
              top: MediaQuery.of(context).padding.top + 70,
              left: 0, right: 0,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 60),
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(color: Colors.orange.shade800, borderRadius: BorderRadius.circular(20), boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)]),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.cloud_off, color: Colors.white, size: 16),
                    SizedBox(width: 8),
                    Text("Offline Map Active", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                  ],
                ),
              ),
            ),

          if (_isCustomLocation && !_isNavigating)
            Positioned(
              top: MediaQuery.of(context).padding.top + 130,
              right: 16,
              child: FloatingActionButton.small(
                backgroundColor: theme.primaryColor,
                foregroundColor: Colors.white,
                onPressed: _initializeRealTimeData,
                child: const Icon(Icons.my_location),
              ),
            ),

          if (!_isNavigating)
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(top: 12, left: 16, right: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 50,
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E293B) : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))],
                            ),
                            child: TextField(
                              controller: _searchController,
                              textInputAction: TextInputAction.search,
                              onSubmitted: (_) => _performTextSearch(),
                              decoration: InputDecoration(
                                hintText: "Search places or cities...",
                                hintStyle: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[500], fontSize: 14),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                suffixIcon: IconButton(
                                  icon: Icon(Icons.search, color: theme.primaryColor),
                                  onPressed: _performTextSearch,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        GestureDetector(
                          onTap: () {
                            setState(() => _isOfflineMode = !_isOfflineMode);
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_isOfflineMode ? "Region downloaded for offline use." : "Reconnected to live map.")));
                          },
                          child: Container(
                            height: 50, width: 50,
                            decoration: BoxDecoration(color: _isOfflineMode ? Colors.green : (isDark ? const Color(0xFF1E293B) : Colors.white), borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10)]),
                            child: Icon(_isOfflineMode ? Icons.download_done : Icons.download_for_offline, color: _isOfflineMode ? Colors.white : theme.primaryColor),
                          ),
                        )
                      ],
                    ),
                    const SizedBox(height: 12),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildFilterChip("For You", Icons.auto_awesome),
                          _buildFilterChip("Top Rated", Icons.star),
                          _buildFilterChip("Nearby", Icons.near_me),
                          _buildFilterChip("Nature", Icons.park),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

          if (_isNavigating && _selectedViewpoint != null)
            Positioned(
              top: 0, left: 0, right: 0,
              child: Container(
                padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 16, bottom: 24, left: 24, right: 24),
                decoration: BoxDecoration(
                  color: Colors.green.shade700,
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 15)],
                ),
                child: Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Icon(Icons.directions, color: Colors.white, size: 42),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                  _distanceRemaining > 1000
                                      ? "${(_distanceRemaining / 1000).toStringAsFixed(1)} km to destination"
                                      : "${_distanceRemaining.toStringAsFixed(0)} meters to destination",
                                  style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500)
                              ),
                              const SizedBox(height: 4),
                              Text(
                                  _currentInstruction,
                                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        GestureDetector(
                          onTap: () {
                            setState(() => _isVoiceOn = !_isVoiceOn);
                            if (_isVoiceOn) {
                              _speakInstruction("Voice navigation enabled");
                            } else {
                              _flutterTts.stop();
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                                color: _isVoiceOn ? Colors.black26 : Colors.redAccent.withOpacity(0.8),
                                borderRadius: BorderRadius.circular(20)
                            ),
                            child: Row(
                                children: [
                                  Icon(_isVoiceOn ? Icons.volume_up : Icons.volume_off, color: Colors.white, size: 16),
                                  const SizedBox(width: 6),
                                  Text(_isVoiceOn ? "Voice On" : "Muted", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
                                ]
                            ),
                          ),
                        ),
                        ElevatedButton(
                          onPressed: _stopNavigation,
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
                          child: const Text("Exit"),
                        )
                      ],
                    )
                  ],
                ),
              ),
            ),

          if (!_isNavigating)
            DraggableScrollableSheet(
              initialChildSize: _selectedViewpoint == null ? 0.4 : 0.35,
              minChildSize: 0.15,
              maxChildSize: 0.85,
              builder: (context, scrollController) {
                return Container(
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : Colors.white,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, -5))],
                  ),
                  child: Column(
                    children: [
                      Center(child: Container(margin: const EdgeInsets.symmetric(vertical: 12), width: 48, height: 6, decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(3)))),

                      if (_isLoadingPlaces)
                        Expanded(child: Center(child: CircularProgressIndicator(color: theme.primaryColor)))
                      else if (_selectedViewpoint != null)
                        _buildViewpointDetailsPanel(isDark)
                      else
                        Expanded(child: _buildExploreList(scrollController, isDark)),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildExploreList(ScrollController scrollController, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_isCustomLocation ? "Search Results" : "$_selectedFilter Viewpoints", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
              Text("See all", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Theme.of(context).primaryColor)),
            ],
          ),
        ),
        Expanded(
          child: _allViewpoints.isEmpty
              ? const Center(child: Text("No places found nearby."))
              : GridView.builder(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 16, mainAxisSpacing: 16, childAspectRatio: 0.75),
            itemCount: _allViewpoints.length,
            itemBuilder: (context, index) {
              final vp = _allViewpoints[index];
              return _ViewpointCard(
                viewpoint: vp,
                onTap: () {
                  setState(() => _selectedViewpoint = vp);
                  _moveCamera(vp.location, zoom: 16.0);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildViewpointDetailsPanel(bool isDark) {
    final vp = _selectedViewpoint!;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: Text(vp.title, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87))),
              IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => setState(() => _selectedViewpoint = null) // 👈 Dismisses the custom drop pin easily!
              ),
            ],
          ),
          const SizedBox(height: 4),

          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance.collection('places').doc(vp.id).snapshots(),
            builder: (context, snapshot) {
              double displayRating = vp.rating;
              int displayReviews = vp.reviews;

              if (snapshot.hasData && snapshot.data!.exists) {
                displayRating = (snapshot.data!['rating'] ?? vp.rating).toDouble();
                displayReviews = snapshot.data!['reviews'] ?? vp.reviews;
              }

              return Row(
                children: [
                  const Icon(Icons.star, color: Colors.amber, size: 18),
                  const SizedBox(width: 4),
                  Text(displayReviews == 0 ? "New" : displayRating.toStringAsFixed(1), style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text(" ($displayReviews reviews)", style: TextStyle(color: Colors.grey[500])),
                  const SizedBox(width: 16),
                  Icon(Icons.directions_walk, color: Colors.grey[500], size: 18),
                  const SizedBox(width: 4),
                  Text("${vp.distance} km", style: TextStyle(color: Colors.grey[500])),
                ],
              );
            },
          ),

          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: vp.tags.map((tag) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: Theme.of(context).primaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
              child: Text(tag, style: TextStyle(fontSize: 12, color: Theme.of(context).primaryColor, fontWeight: FontWeight.w600)),
            )).toList(),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _fetchDirectionsAndStart,
                  icon: const Icon(Icons.navigation),
                  label: const Text("Start Nav", style: TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(12)),
                child: IconButton(
                  icon: const Icon(Icons.star_rate, color: Colors.amber),
                  tooltip: "Rate this place",
                  onPressed: () => _showRatingDialog(vp),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(12)),
                child: IconButton(icon: const Icon(Icons.bookmark_border), onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Saved to wishlist!")));
                }),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, IconData icon) {
    bool isSelected = _selectedFilter == label && _searchController.text.isEmpty;
    return GestureDetector(
      onTap: () => _onFilterChanged(label),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Theme.of(context).primaryColor : (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E293B) : Colors.white),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? Theme.of(context).primaryColor : Colors.grey.withOpacity(0.3)),
          boxShadow: [if (!isSelected) BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))],
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: isSelected ? Colors.white : Colors.grey[500]),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isSelected ? Colors.white : (Theme.of(context).brightness == Brightness.dark ? Colors.grey[300] : Colors.grey[700]))),
          ],
        ),
      ),
    );
  }
}

class _ViewpointCard extends StatelessWidget {
  final Viewpoint viewpoint;
  final VoidCallback onTap;

  const _ViewpointCard({required this.viewpoint, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              children: [
                Container(
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), color: Colors.grey[300], image: DecorationImage(image: NetworkImage(viewpoint.imageUrl), fit: BoxFit.cover)),
                ),
                Positioned(
                  top: 8, right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: Colors.black.withOpacity(0.7), borderRadius: BorderRadius.circular(8)),
                    child: StreamBuilder<DocumentSnapshot>(
                        stream: FirebaseFirestore.instance.collection('places').doc(viewpoint.id).snapshots(),
                        builder: (context, snapshot) {
                          double displayRating = viewpoint.rating;
                          if (snapshot.hasData && snapshot.data!.exists) {
                            displayRating = (snapshot.data!['rating'] ?? viewpoint.rating).toDouble();
                          }
                          return Row(
                              children: [
                                const Icon(Icons.star, color: Colors.amber, size: 12),
                                const SizedBox(width: 2),
                                Text(displayRating == 0 ? "New" : displayRating.toStringAsFixed(1), style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))
                              ]
                          );
                        }
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(viewpoint.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: isDark ? Colors.white : Colors.black87)),
          const SizedBox(height: 2),
          Text("${viewpoint.category} • ${viewpoint.distance} km", style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[600]), maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}