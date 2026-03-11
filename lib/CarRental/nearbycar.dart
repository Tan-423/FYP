import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'dart:math' show cos, sqrt, asin, pi;

// ⭐ HELPER: Forces the app to strictly follow Malaysia Time (UTC+8)
DateTime getRealTime() {
  return DateTime.now().toUtc().add(const Duration(hours: 8));
}

// ==========================================
// 1. DATA MODEL
// ==========================================
class CarModel {
  final String id;
  final String name;
  final String type;
  final double price;
  final String imageUrl;
  final List<String> features;
  final String tag;
  final String status;
  final double lat;
  final double lng;
  double distanceFromUser;
  final List<String> bookedDates;

  CarModel({
    required this.id,
    required this.name,
    required this.type,
    required this.price,
    required this.imageUrl,
    required this.features,
    required this.tag,
    required this.status,
    required this.lat,
    required this.lng,
    this.distanceFromUser = 0.0,
    required this.bookedDates,
  });

  factory CarModel.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;

    List<String> bDates = List<String>.from(data['bookedDates'] ?? []);

    String todayStr = DateFormat('yyyy-MM-dd').format(getRealTime());

    String dbStatus = (data['status'] ?? 'available').toString().toLowerCase();
    String calculatedStatus = dbStatus;

    if (dbStatus != 'maintenance' && dbStatus != 'unavailable') {
      calculatedStatus = bDates.contains(todayStr) ? 'rented' : 'available';
    }

    return CarModel(
      id: doc.id,
      name: data['name'] ?? 'Unknown Car',
      type: data['type'] ?? 'Standard',
      price: (data['price'] ?? 0.0).toDouble(),
      imageUrl: data['imageUrl'] ?? '',
      features: List<String>.from(data['features'] ?? []),
      tag: data['tag'] ?? '',
      status: calculatedStatus,
      lat: (data['lat'] ?? 0.0).toDouble(),
      lng: (data['lng'] ?? 0.0).toDouble(),
      bookedDates: bDates,
    );
  }
}

// ==========================================
// 2. MAIN NEARBY CARS SCREEN
// ==========================================
class NearbyCarsScreen extends StatefulWidget {
  const NearbyCarsScreen({super.key});

  @override
  State<NearbyCarsScreen> createState() => _NearbyCarsScreenState();
}

class _NearbyCarsScreenState extends State<NearbyCarsScreen>
    with SingleTickerProviderStateMixin {
  final Completer<GoogleMapController> _mapController = Completer();
  final TextEditingController _searchController = TextEditingController();

  LatLng _userLocation = const LatLng(3.1412, 101.6865);
  final LatLng _defaultLocation = const LatLng(3.1412, 101.6865);
  String? _selectedCarId;

  final ClusterManager _carClusterManager = const ClusterManager(
    clusterManagerId: ClusterManagerId('car_cluster'),
  );

  Set<Marker> _markers = {};
  StreamSubscription<QuerySnapshot>? _carSubscription;
  List<CarModel> _allCarsFromDb = [];
  List<CarModel> _displayedCars = [];
  String _currentSort = 'Nearest';
  String _currentTypeFilter = 'All';

  @override
  void initState() {
    super.initState();
    _seedDatabaseIfEmpty();
    _listenToCars();
  }

  @override
  void dispose() {
    _carSubscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _searchLocation(String query) async {
    if (query.trim().isEmpty) return;
    FocusScope.of(context).unfocus();
    try {
      List<Location> locations = await locationFromAddress(query);
      if (locations.isNotEmpty) {
        setState(() {
          _userLocation = LatLng(
            locations.first.latitude,
            locations.first.longitude,
          );
          _selectedCarId = null;
        });
        final GoogleMapController controller = await _mapController.future;
        controller.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(target: _userLocation, zoom: 13.5),
          ),
        );
        _updateDistancesAndRefresh();
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Location not found."),
            backgroundColor: Colors.redAccent,
          ),
        );
    }
  }

  void _updateDistancesAndRefresh() {
    for (var car in _allCarsFromDb) {
      car.distanceFromUser = _calculateDistance(
        _userLocation.latitude,
        _userLocation.longitude,
        car.lat,
        car.lng,
      );
    }
    _applyFiltersAndSort();
  }

  void _listenToCars() {
    _carSubscription = FirebaseFirestore.instance
        .collection('rental_cars')
        .snapshots()
        .listen((snapshot) {
          if (!mounted) return;
          _allCarsFromDb =
              snapshot.docs.map((doc) {
                CarModel car = CarModel.fromFirestore(doc);
                car.distanceFromUser = _calculateDistance(
                  _userLocation.latitude,
                  _userLocation.longitude,
                  car.lat,
                  car.lng,
                );
                return car;
              }).toList();
          _applyFiltersAndSort();
        });
  }

  void _applyFiltersAndSort() {
    Map<String, CarModel> uniqueCars = {};
    for (var car in _allCarsFromDb) {
      if (!uniqueCars.containsKey(car.name)) {
        uniqueCars[car.name] = car;
      } else {
        if (car.status == 'available' &&
            uniqueCars[car.name]!.status != 'available') {
          uniqueCars[car.name] = car;
        }
      }
    }

    List<CarModel> temp = uniqueCars.values.toList();

    if (_currentTypeFilter != 'All')
      temp =
          temp.where((car) => car.type.contains(_currentTypeFilter)).toList();

    if (_currentSort == 'Price: Low to High')
      temp.sort((a, b) => a.price.compareTo(b.price));
    else if (_currentSort == 'Price: High to Low')
      temp.sort((a, b) => b.price.compareTo(a.price));
    else
      temp.sort((a, b) => a.distanceFromUser.compareTo(b.distanceFromUser));

    Set<Marker> newMarkers =
        temp.map((car) {
          bool isSelected = _selectedCarId == car.id;
          return Marker(
            markerId: MarkerId(car.id),
            position: LatLng(car.lat, car.lng),
            clusterManagerId: const ClusterManagerId('car_cluster'),
            infoWindow: InfoWindow(
              title: "\$${car.price.toInt()}/day",
              snippet: car.name,
            ),
            icon: BitmapDescriptor.defaultMarkerWithHue(
              isSelected ? BitmapDescriptor.hueAzure : BitmapDescriptor.hueRed,
            ),
            onTap: () => setState(() => _selectedCarId = car.id),
          );
        }).toSet();

    setState(() {
      _displayedCars = temp;
      _markers = newMarkers;
    });
  }

  Future<void> _seedDatabaseIfEmpty() async {
    final collection = FirebaseFirestore.instance.collection('rental_cars');

    final List<Map<String, dynamic>> allSampleCars = [
      {
        'name': 'Toyota Camry',
        'type': 'Standard Sedan',
        'price': 54.0,
        'imageUrl':
            'https://images.unsplash.com/photo-1621007947382-bb3c3994e3fd?auto=format&fit=crop&w=600',
        'features': ['Gas', 'Auto', '4 Seats'],
        'tag': 'Popular',
        'status': 'available',
        'lat': 3.1450,
        'lng': 101.6900,
        'bookedDates': [],
      },
      {
        'name': 'Honda Civic',
        'type': 'Compact',
        'price': 45.0,
        'imageUrl':
            'https://images.unsplash.com/photo-1606016159991-d17b67472545?auto=format&fit=crop&w=600',
        'features': ['Hybrid', 'Auto', '5 Seats'],
        'tag': 'Eco',
        'status': 'available',
        'lat': 3.1455,
        'lng': 101.6905,
        'bookedDates': [],
      },
      {
        'name': 'Tesla Model 3',
        'type': 'Electric',
        'price': 85.0,
        'imageUrl':
            'https://images.unsplash.com/photo-1560958089-b8a1929cea89?auto=format&fit=crop&w=600',
        'features': ['Electric', 'Auto', '5 Seats'],
        'tag': 'Premium',
        'status': 'available',
        'lat': 3.1460,
        'lng': 101.6890,
        'bookedDates': [],
      },
      {
        'name': 'Perodua Myvi',
        'type': 'Economy',
        'price': 30.0,
        'imageUrl':
            'https://images.unsplash.com/photo-1590362891991-f776e747a588?auto=format&fit=crop&w=600',
        'features': ['Gas', 'Auto', '5 Seats'],
        'tag': 'Budget',
        'status': 'available',
        'lat': 3.1300,
        'lng': 101.6950,
        'bookedDates': [],
      },
      {
        'name': 'BMW 3 Series',
        'type': 'Luxury Sedan',
        'price': 120.0,
        'imageUrl':
            'https://images.unsplash.com/photo-1555215695-3004980ad54e?auto=format&fit=crop&w=600',
        'features': ['Gas', 'Auto', '5 Seats'],
        'tag': 'Premium',
        'status': 'available',
        'lat': 3.1480,
        'lng': 101.6870,
        'bookedDates': [],
      },
      {
        'name': 'Toyota Vios',
        'type': 'Budget Sedan',
        'price': 38.0,
        'imageUrl':
            'https://images.unsplash.com/photo-1549317661-bd32c8ce0db2?auto=format&fit=crop&w=600',
        'features': ['Gas', 'Auto', '5 Seats'],
        'tag': 'Budget',
        'status': 'available',
        'lat': 3.1320,
        'lng': 101.6920,
        'bookedDates': [],
      },
      {
        'name': 'Proton X50',
        'type': 'SUV',
        'price': 65.0,
        'imageUrl':
            'https://images.unsplash.com/photo-1519641471654-76ce0107ad1b?auto=format&fit=crop&w=600',
        'features': ['Gas', 'Auto', '5 Seats'],
        'tag': 'Popular',
        'status': 'available',
        'lat': 3.1410,
        'lng': 101.6930,
        'bookedDates': [],
      },
    ];

    // Fetch existing car names to avoid duplicates
    final existingSnapshot = await collection.get();
    final existingNames =
        existingSnapshot.docs
            .map((doc) => (doc.data() as Map)['name']?.toString() ?? '')
            .toSet();

    for (var car in allSampleCars) {
      if (!existingNames.contains(car['name'])) {
        await collection.add(car);
      }
    }
  }

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

  Future<void> _focusAndOpenCar(CarModel car) async {
    setState(() => _selectedCarId = car.id);
    _applyFiltersAndSort();

    final GoogleMapController controller = await _mapController.future;
    controller.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: LatLng(car.lat, car.lng), zoom: 16.5, tilt: 45),
      ),
    );

    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CarAvailabilityScreen(car: car),
        ),
      );
    }
  }

  void _showSortOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Sort By",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              _buildSortTile('Nearest'),
              _buildSortTile('Price: Low to High'),
              _buildSortTile('Price: High to Low'),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSortTile(String sortName) {
    bool isSelected = _currentSort == sortName;
    return ListTile(
      title: Text(
        sortName,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? const Color(0xFF137FEC) : null,
        ),
      ),
      trailing:
          isSelected
              ? const Icon(Icons.check_circle, color: Color(0xFF137FEC))
              : null,
      onTap: () {
        setState(() => _currentSort = sortName);
        _applyFiltersAndSort();
        Navigator.pop(context);
      },
    );
  }

  void _showTypeOptions() {
    Set<String> uniqueTypes = {'All'};
    for (var car in _allCarsFromDb) {
      uniqueTypes.add(car.type);
    }
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Filter by Car Type",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ...uniqueTypes.map((type) => _buildTypeTile(type)).toList(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTypeTile(String typeName) {
    bool isSelected = _currentTypeFilter == typeName;
    return ListTile(
      title: Text(
        typeName,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? const Color(0xFF137FEC) : null,
        ),
      ),
      trailing:
          isSelected
              ? const Icon(Icons.check_circle, color: Color(0xFF137FEC))
              : null,
      onTap: () {
        setState(() => _currentTypeFilter = typeName);
        _applyFiltersAndSort();
        Navigator.pop(context);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const primaryColor = Color(0xFF137FEC);
    final bgColor = isDark ? const Color(0xFF101922) : const Color(0xFFF6F7F8);
    final cardColor = isDark ? const Color(0xFF1E2A36) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF111418);

    Set<Marker> allMapMarkers = Set.from(_markers);
    allMapMarkers.add(
      Marker(
        markerId: const MarkerId('user_location'),
        position: _userLocation,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: const InfoWindow(title: "Search Center"),
      ),
    );

    return Scaffold(
      extendBodyBehindAppBar: true,
      resizeToAvoidBottomInset: false,
      backgroundColor: bgColor,
      body: Stack(
        children: [
          Positioned.fill(
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: _userLocation,
                zoom: 12.0,
              ),
              markers: allMapMarkers,
              clusterManagers: {_carClusterManager},
              zoomControlsEnabled: false,
              myLocationButtonEnabled: false,
              mapToolbarEnabled: false,
              onMapCreated: (GoogleMapController controller) {
                _mapController.complete(controller);
              },
              onTap: (_) {
                setState(() => _selectedCarId = null);
                _applyFiltersAndSort();
              },
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 120,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black.withOpacity(0.5), Colors.transparent],
                ),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: cardColor,
                        child: IconButton(
                          icon: Icon(Icons.arrow_back, color: textColor),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          height: 48,
                          decoration: BoxDecoration(
                            color: cardColor,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              const SizedBox(width: 16),
                              Icon(
                                Icons.search,
                                color:
                                    isDark
                                        ? Colors.grey[400]
                                        : const Color(0xFF617589),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextField(
                                  controller: _searchController,
                                  textInputAction: TextInputAction.search,
                                  onSubmitted: _searchLocation,
                                  decoration: InputDecoration(
                                    hintText: "Search an area...",
                                    hintStyle: TextStyle(
                                      color:
                                          isDark
                                              ? Colors.grey[500]
                                              : const Color(0xFF617589),
                                      fontSize: 14,
                                    ),
                                    border: InputBorder.none,
                                    contentPadding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    suffixIcon: IconButton(
                                      icon: const Icon(Icons.close, size: 18),
                                      onPressed:
                                          () => _searchController.clear(),
                                    ),
                                  ),
                                  style: TextStyle(color: textColor),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      _buildActionChip(
                        context,
                        label:
                            _currentSort == 'Nearest'
                                ? 'Sort'
                                : _currentSort.replaceAll('Price: ', ''),
                        isActive: _currentSort != 'Nearest',
                        icon: Icons.sort,
                        onTap: _showSortOptions,
                        cardColor: cardColor,
                        textColor: textColor,
                        primaryColor: primaryColor,
                      ),
                      const SizedBox(width: 8),
                      _buildActionChip(
                        context,
                        label:
                            _currentTypeFilter == 'All'
                                ? 'Car Type'
                                : _currentTypeFilter,
                        isActive: _currentTypeFilter != 'All',
                        onTap: _showTypeOptions,
                        cardColor: cardColor,
                        textColor: textColor,
                        primaryColor: primaryColor,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Positioned(
            right: 16,
            bottom: MediaQuery.of(context).size.height * 0.48,
            child: FloatingActionButton.small(
              onPressed: () async {
                setState(() {
                  _userLocation = _defaultLocation;
                  _selectedCarId = null;
                  _searchController.clear();
                });
                _updateDistancesAndRefresh();
                final GoogleMapController controller =
                    await _mapController.future;
                controller.animateCamera(
                  CameraUpdate.newCameraPosition(
                    CameraPosition(target: _userLocation, zoom: 14.5),
                  ),
                );
              },
              backgroundColor: cardColor,
              foregroundColor: primaryColor,
              child: const Icon(Icons.my_location),
            ),
          ),

          // --- Draggable Bottom Sheet ---
          DraggableScrollableSheet(
            initialChildSize: 0.45,
            minChildSize: 0.2,
            maxChildSize: 0.85,
            builder: (context, scrollController) {
              return Container(
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 20,
                      offset: const Offset(0, -5),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Center(
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 12),
                        width: 48,
                        height: 4,
                        decoration: BoxDecoration(
                          color: isDark ? Colors.grey[700] : Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),

                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const AddNewCarScreen(),
                          ),
                        );
                      },
                      child: Container(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF137FEC), Color(0xFF0D57A5)],
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.car_rental,
                              color: Colors.white,
                              size: 32,
                            ),
                            const SizedBox(width: 16),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Do you want to rent your car to others?",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    "Click here to list your car and earn money!",
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.arrow_forward_ios,
                              color: Colors.white,
                              size: 16,
                            ),
                          ],
                        ),
                      ),
                    ),

                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 8,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _displayedCars.isEmpty
                                ? "No cars found"
                                : "${_displayedCars.length} cars nearby",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                          ),
                          Row(
                            children: [
                              GestureDetector(
                                onTap: () async {
                                  showDialog(
                                    context: context,
                                    builder:
                                        (_) => const Center(
                                          child: CircularProgressIndicator(),
                                        ),
                                  );
                                  var cars =
                                      await FirebaseFirestore.instance
                                          .collection('rental_cars')
                                          .get();
                                  for (var doc in cars.docs) {
                                    await doc.reference.update({
                                      'status': 'available',
                                      'bookedDates': [],
                                    });
                                  }
                                  if (context.mounted) {
                                    Navigator.pop(context);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          "Database Cleaned! All cars are available.",
                                        ),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade50,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: Colors.red.shade200,
                                    ),
                                  ),
                                  child: Row(
                                    children: const [
                                      Icon(
                                        Icons.cleaning_services,
                                        size: 14,
                                        color: Colors.red,
                                      ),
                                      SizedBox(width: 4),
                                      Text(
                                        "Fix Stuck Cars",
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.red,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Divider(
                      height: 1,
                      color: isDark ? Colors.grey[800] : Colors.grey[300],
                    ),

                    Expanded(
                      child:
                          _displayedCars.isEmpty
                              ? Center(
                                child: Text(
                                  "No cars match your filters.",
                                  style: TextStyle(color: Colors.grey[500]),
                                ),
                              )
                              : ListView.builder(
                                controller: scrollController,
                                padding: const EdgeInsets.all(16),
                                itemCount: _displayedCars.length,
                                itemBuilder: (context, index) {
                                  final car = _displayedCars[index];
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 16),
                                    child: GestureDetector(
                                      onTap: () => _focusAndOpenCar(car),
                                      child: _CarCard(
                                        car: car,
                                        isSelected: _selectedCarId == car.id,
                                        cardColor: cardColor,
                                        textColor: textColor,
                                      ),
                                    ),
                                  );
                                },
                              ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildActionChip(
    BuildContext context, {
    required String label,
    bool isActive = false,
    IconData? icon,
    required VoidCallback onTap,
    required Color cardColor,
    required Color textColor,
    required Color primaryColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: isActive ? primaryColor : cardColor,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            if (icon != null && !isActive) ...[
              Icon(icon, size: 14, color: textColor),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: isActive ? Colors.white : textColor,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.keyboard_arrow_down,
              size: 16,
              color: isActive ? Colors.white : textColor,
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 3. UI WIDGETS (CAR CARD)
// ==========================================
class _CarCard extends StatelessWidget {
  final CarModel car;
  final bool isSelected;
  final Color cardColor, textColor;

  const _CarCard({
    required this.car,
    this.isSelected = false,
    required this.cardColor,
    required this.textColor,
  });

  Widget _buildImage() {
    if (car.imageUrl.startsWith('http'))
      return Image.network(
        car.imageUrl,
        width: 96,
        height: 96,
        fit: BoxFit.cover,
        errorBuilder: (c, e, s) => Container(color: Colors.grey[200]),
      );
    if (car.imageUrl.isNotEmpty) {
      try {
        return Image.memory(
          base64Decode(car.imageUrl),
          width: 96,
          height: 96,
          fit: BoxFit.cover,
          errorBuilder: (c, e, s) => Container(color: Colors.grey[200]),
        );
      } catch (e) {
        return Container(
          width: 96,
          height: 96,
          color: Colors.grey[200],
          child: const Icon(Icons.broken_image),
        );
      }
    }
    return Container(width: 96, height: 96, color: Colors.grey[200]);
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF137FEC);
    Color statusColor;
    if (car.status == 'available') {
      statusColor = Colors.green;
    } else if (car.status == 'rented') {
      statusColor = Colors.orange;
    } else {
      statusColor = Colors.red;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border:
            isSelected
                ? Border.all(color: primaryColor, width: 2)
                : Border.all(color: Colors.transparent, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            height: 96,
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: _buildImage(),
                ),
                if (car.tag.isNotEmpty)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        car.tag,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        car.name,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: textColor,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          "\$${car.price.toInt()}",
                          style: TextStyle(
                            color: isSelected ? primaryColor : textColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        Text(
                          "/ day",
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Text(
                  "${car.type} • ${car.distanceFromUser.toStringAsFixed(1)} km away",
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children:
                      car.features
                          .take(2)
                          .map(
                            (f) => Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.check_circle_outline,
                                  size: 14,
                                  color: Colors.grey[500],
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  f,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[500],
                                  ),
                                ),
                              ],
                            ),
                          )
                          .toList(),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: statusColor.withOpacity(0.3)),
                  ),
                  child: Text(
                    car.status.toUpperCase(),
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// 4. CAR AVAILABILITY SCREEN
// ==========================================
class CarAvailabilityScreen extends StatefulWidget {
  final CarModel car;
  const CarAvailabilityScreen({super.key, required this.car});

  @override
  State<CarAvailabilityScreen> createState() => _CarAvailabilityScreenState();
}

class _CarAvailabilityScreenState extends State<CarAvailabilityScreen> {
  DateTime _currentMonth = DateTime(getRealTime().year, getRealTime().month, 1);
  DateTime? _selectedStart;
  DateTime? _selectedEnd;

  int get _calculatedDays {
    if (_selectedStart != null && _selectedEnd != null) {
      return _selectedEnd!.difference(_selectedStart!).inDays + 1;
    } else if (_selectedStart != null) {
      return 1;
    }
    return 0;
  }

  void _changeMonth(int offset) {
    setState(() {
      _currentMonth = DateTime(
        _currentMonth.year,
        _currentMonth.month + offset,
        1,
      );
    });
  }

  void _onDayTapped(DateTime date) {
    DateTime realNow = getRealTime();
    DateTime today = DateTime(realNow.year, realNow.month, realNow.day);

    if (date.isBefore(today)) return;

    String dateStr = DateFormat('yyyy-MM-dd').format(date);
    if (widget.car.bookedDates.contains(dateStr)) return;

    setState(() {
      if (_selectedStart == null ||
          (_selectedStart != null && _selectedEnd != null)) {
        _selectedStart = date;
        _selectedEnd = null;
      } else if (_selectedStart != null && _selectedEnd == null) {
        if (date.isBefore(_selectedStart!)) {
          _selectedStart = date;
        } else {
          bool hasConflict = false;
          for (int i = 1; i <= date.difference(_selectedStart!).inDays; i++) {
            DateTime intermediateDate = _selectedStart!.add(Duration(days: i));
            if (widget.car.bookedDates.contains(
              DateFormat('yyyy-MM-dd').format(intermediateDate),
            )) {
              hasConflict = true;
              break;
            }
          }
          if (hasConflict) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  "Selected range includes dates that are already booked.",
                ),
              ),
            );
            _selectedStart = date;
          } else {
            _selectedEnd = date;
          }
        }
      }
    });
  }

  List<Widget> _buildCalendarGrid() {
    List<Widget> dayWidgets = [];
    int daysInMonth =
        DateTime(_currentMonth.year, _currentMonth.month + 1, 0).day;
    int firstWeekday = _currentMonth.weekday;

    int emptySlots = firstWeekday == 7 ? 0 : firstWeekday;
    for (int i = 0; i < emptySlots; i++) {
      dayWidgets.add(const SizedBox());
    }

    DateTime realNow = getRealTime();
    DateTime today = DateTime(realNow.year, realNow.month, realNow.day);

    for (int i = 1; i <= daysInMonth; i++) {
      DateTime currentDay = DateTime(
        _currentMonth.year,
        _currentMonth.month,
        i,
      );
      String dateStr = DateFormat('yyyy-MM-dd').format(currentDay);
      String state = 'available';

      if (currentDay.isBefore(today)) {
        state = 'past';
      } else if (widget.car.bookedDates.contains(dateStr)) {
        state = 'booked';
      } else if (_selectedStart != null &&
          currentDay.isAtSameMomentAs(_selectedStart!)) {
        state = _selectedEnd == null ? 'start_single' : 'start';
        if (_selectedEnd != null &&
            _selectedStart!.isAtSameMomentAs(_selectedEnd!)) {
          state = 'start_single';
        }
      } else if (_selectedEnd != null &&
          currentDay.isAtSameMomentAs(_selectedEnd!)) {
        state = 'end';
      } else if (_selectedStart != null &&
          _selectedEnd != null &&
          currentDay.isAfter(_selectedStart!) &&
          currentDay.isBefore(_selectedEnd!)) {
        state = 'mid';
      }
      dayWidgets.add(_buildDayCell(i, state: state, date: currentDay));
    }
    return dayWidgets;
  }

  Widget _buildDynamicImage(String imageString) {
    if (imageString.startsWith('http'))
      return Image.network(
        imageString,
        fit: BoxFit.cover,
        errorBuilder: (c, e, s) => Container(color: Colors.grey[200]),
      );
    if (imageString.isNotEmpty) {
      try {
        return Image.memory(
          base64Decode(imageString),
          fit: BoxFit.cover,
          errorBuilder: (c, e, s) => Container(color: Colors.grey[200]),
        );
      } catch (e) {
        return Container(color: Colors.grey[200]);
      }
    }
    return Container(color: Colors.grey[200]);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const primaryColor = Color(0xFF137FEC);
    final bgColor = isDark ? const Color(0xFF101922) : const Color(0xFFF6F7F8);
    final surfaceColor = isDark ? const Color(0xFF1A2633) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF111418);
    final textMuted = isDark ? Colors.grey[400]! : Colors.grey[500]!;
    final borderColor = isDark ? Colors.grey[800]! : Colors.grey[100]!;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 450),
            child: Container(
              color: surfaceColor,
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    color: surfaceColor,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: Icon(Icons.arrow_back, color: textColor),
                          onPressed: () => Navigator.pop(context),
                        ),
                        Text(
                          "Availability",
                          style: TextStyle(
                            color: textColor,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.5,
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.share, color: textColor),
                          onPressed: () {},
                        ),
                      ],
                    ),
                  ),

                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.only(bottom: 40),
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                          child: Column(
                            children: [
                              AspectRatio(
                                aspectRatio: 16 / 9,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color:
                                        isDark
                                            ? Colors.grey[700]
                                            : Colors.grey[200],
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Stack(
                                    children: [
                                      Positioned.fill(
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          child: _buildDynamicImage(
                                            widget.car.imageUrl,
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        top: 12,
                                        right: 12,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color:
                                                isDark
                                                    ? Colors.black.withOpacity(
                                                      0.6,
                                                    )
                                                    : Colors.white.withOpacity(
                                                      0.9,
                                                    ),
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
                                            border: Border.all(
                                              color:
                                                  isDark
                                                      ? Colors.grey[700]!
                                                      : Colors.grey[100]!,
                                            ),
                                          ),
                                          child: Text(
                                            "4.9 ★ (120)",
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: textColor,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),

                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          widget.car.name,
                                          style: TextStyle(
                                            fontSize: 24,
                                            fontWeight: FontWeight.bold,
                                            color: textColor,
                                            height: 1.1,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          "${widget.car.type} • ${(widget.car.features.isNotEmpty) ? widget.car.features.first : 'Standard'}",
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                            color: textMuted,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        "\$${widget.car.price.toInt()}",
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: textColor,
                                        ),
                                      ),
                                      Text(
                                        "per day",
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: textMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        Divider(
                          color: borderColor,
                          height: 1,
                          indent: 16,
                          endIndent: 16,
                        ),

                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.chevron_left),
                                    color: textColor,
                                    onPressed: () => _changeMonth(-1),
                                  ),
                                  Text(
                                    DateFormat(
                                      'MMMM yyyy',
                                    ).format(_currentMonth),
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: textColor,
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.chevron_right),
                                    color: textColor,
                                    onPressed: () => _changeMonth(1),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),

                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceAround,
                                children:
                                    ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"]
                                        .map(
                                          (day) => Expanded(
                                            child: Text(
                                              day,
                                              textAlign: TextAlign.center,
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.grey,
                                              ),
                                            ),
                                          ),
                                        )
                                        .toList(),
                              ),
                              const SizedBox(height: 8),

                              GridView.count(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                crossAxisCount: 7,
                                childAspectRatio: 1.1,
                                mainAxisSpacing: 8,
                                children: _buildCalendarGrid(),
                              ),
                            ],
                          ),
                        ),

                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _buildLegendChip(
                                "Available",
                                isDark ? Colors.white : const Color(0xFF111418),
                                isDark ? Colors.grey[800]! : Colors.grey[50]!,
                                borderColor,
                              ),
                              _buildLegendChip(
                                "Unavailable",
                                isDark ? Colors.grey[600]! : Colors.grey[300]!,
                                isDark ? Colors.grey[800]! : Colors.grey[50]!,
                                borderColor,
                              ),
                              _buildLegendChip(
                                "Selected",
                                primaryColor,
                                primaryColor.withOpacity(0.1),
                                primaryColor.withOpacity(0.2),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  Container(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
                    decoration: BoxDecoration(
                      color: surfaceColor,
                      border: Border(top: BorderSide(color: borderColor)),
                      boxShadow:
                          isDark
                              ? []
                              : [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 20,
                                  offset: const Offset(0, -4),
                                ),
                              ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "RENTAL PERIOD",
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: textMuted,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Text(
                                      _selectedStart != null
                                          ? DateFormat(
                                            'MMM d',
                                          ).format(_selectedStart!)
                                          : "Select",
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: textColor,
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                      ),
                                      child: Icon(
                                        Icons.arrow_forward,
                                        size: 16,
                                        color: textMuted,
                                      ),
                                    ),
                                    Text(
                                      _selectedEnd != null
                                          ? DateFormat(
                                            'MMM d',
                                          ).format(_selectedEnd!)
                                          : (_selectedStart != null
                                              ? DateFormat(
                                                'MMM d',
                                              ).format(_selectedStart!)
                                              : "Select"),
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: textColor,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color:
                                            isDark
                                                ? Colors.grey[800]
                                                : Colors.grey[100],
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        "$_calculatedDays days",
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: textMuted,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  "TOTAL",
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: textMuted,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  "\$${(widget.car.price * _calculatedDays).toInt()}",
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: primaryColor,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        ElevatedButton(
                          onPressed: () {
                            if (widget.car.status == 'maintenance' ||
                                widget.car.status == 'unavailable') {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    "This car is locked for maintenance and cannot be booked.",
                                  ),
                                  backgroundColor: Colors.red,
                                ),
                              );
                              return;
                            }
                            if (_calculatedDays == 0) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    "Please select an available date range on the calendar.",
                                  ),
                                  backgroundColor: Colors.orange,
                                ),
                              );
                              return;
                            }

                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (context) => CarRentalPaymentScreen(
                                      car: widget.car,
                                      days: _calculatedDays,
                                      startDate: _selectedStart!,
                                    ),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(double.infinity, 48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 4,
                            shadowColor: primaryColor.withOpacity(0.4),
                          ),
                          child: const Text(
                            "Confirm Dates",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
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

  Widget _buildLegendChip(
    String label,
    Color dotColor,
    Color bgColor,
    Color borderColor,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color:
                  label == "Selected"
                      ? dotColor
                      : (isDark ? Colors.white : const Color(0xFF111418)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayCell(int? day, {required String state, DateTime? date}) {
    if (day == null || state == 'empty') return const SizedBox();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const primary = Color(0xFF137FEC);
    final stripColor =
        isDark ? primary.withOpacity(0.3) : primary.withOpacity(0.2);

    Widget innerWidget;

    if (state == 'past' || state == 'booked') {
      innerWidget = Center(
        child: Text(
          day.toString(),
          style: TextStyle(
            color: isDark ? Colors.grey[600] : Colors.grey[400],
            decoration: TextDecoration.lineThrough,
            fontSize: 14,
          ),
        ),
      );
    } else if (state == 'mid') {
      innerWidget = Container(
        color: stripColor,
        alignment: Alignment.center,
        child: Text(
          day.toString(),
          style: TextStyle(
            color: isDark ? Colors.blue[300] : primary,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      );
    } else if (state == 'start' || state == 'end' || state == 'start_single') {
      innerWidget = Stack(
        alignment: Alignment.center,
        children: [
          if (state != 'start_single')
            Row(
              children: [
                Expanded(
                  child: Container(
                    color: state == 'end' ? stripColor : Colors.transparent,
                  ),
                ),
                Expanded(
                  child: Container(
                    color: state == 'start' ? stripColor : Colors.transparent,
                  ),
                ),
              ],
            ),
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: primary,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: primary.withOpacity(0.3),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Text(
              day.toString(),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ],
      );
    } else {
      innerWidget = Center(
        child: Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: const BoxDecoration(shape: BoxShape.circle),
          child: Text(
            day.toString(),
            style: TextStyle(
              color: isDark ? Colors.white : const Color(0xFF111418),
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: () {
        if (date != null && state != 'past' && state != 'booked') {
          _onDayTapped(date);
        }
      },
      child: innerWidget,
    );
  }
}

// ==========================================
// 5. PAYMENT SCREEN
// ==========================================
class CarRentalPaymentScreen extends StatefulWidget {
  final CarModel car;
  final int days;
  final DateTime startDate;

  const CarRentalPaymentScreen({
    super.key,
    required this.car,
    required this.days,
    required this.startDate,
  });

  @override
  State<CarRentalPaymentScreen> createState() => _CarRentalPaymentScreenState();
}

class _CarRentalPaymentScreenState extends State<CarRentalPaymentScreen> {
  String _carAddress = "Locating vehicle...";
  bool _addInsurance = false;
  final double _insuranceRatePerDay = 15.0;

  static const String _paypalBaseUrl =
      'https://us-central1-fyp-project-7199d.cloudfunctions.net';
  static const String _paypalReturnUrl =
      'https://us-central1-fyp-project-7199d.cloudfunctions.net/paypalSuccess';
  static const String _paypalCancelUrl =
      'https://us-central1-fyp-project-7199d.cloudfunctions.net/paypalCancel';

  bool _isCreatingPayment = false;
  bool _isCapturingPayment = false;
  String? _paymentOrderId;
  double _pendingTotal = 0.0;
  WebViewController? _webViewController;

  final CollectionReference<Map<String, dynamic>> _paymentsRef =
      FirebaseFirestore.instance.collection('CarRentalPayments');

  @override
  void initState() {
    super.initState();
    _fetchAddress();
  }

  Future<void> _startPayPalCheckout(double total) async {
    if (_isCreatingPayment) return;
    setState(() {
      _isCreatingPayment = true;
      _pendingTotal = total;
    });

    try {
      final response = await http.post(
        Uri.parse('$_paypalBaseUrl/createPayPalOrder'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'amount': total.toStringAsFixed(2),
          'currency': 'MYR',
          'return_url': _paypalReturnUrl,
          'cancel_url': _paypalCancelUrl,
          'event_id': widget.car.id,
        }),
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('Order creation failed (${response.statusCode})');
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final approvalUrl = data['approvalUrl']?.toString();
      final orderId = data['orderId']?.toString();

      if (approvalUrl == null || orderId == null) {
        throw Exception('Missing approval data from server');
      }

      final user = FirebaseAuth.instance.currentUser;
      await _paymentsRef.doc(orderId).set({
        'PaymentId': orderId,
        'CarId': widget.car.id,
        'CarName': widget.car.name,
        'UserId': user?.uid ?? 'guest',
        'UserEmail': user?.email ?? 'guest@example.com',
        'Amount': total,
        'Currency': 'MYR',
        'RentalDays': widget.days,
        'StartDate': widget.startDate.toIso8601String(),
        'InsuranceAdded': _addInsurance,
        'Status': 'CREATED',
        'CreatedAt': FieldValue.serverTimestamp(),
      });

      final cookieManager = WebViewCookieManager();
      await cookieManager.clearCookies();

      final controller =
          WebViewController()
            ..setJavaScriptMode(JavaScriptMode.unrestricted)
            ..setNavigationDelegate(
              NavigationDelegate(
                onNavigationRequest: (request) {
                  final url = request.url;
                  if (url.startsWith(_paypalReturnUrl)) {
                    _capturePayPalOrder();
                    return NavigationDecision.prevent;
                  }
                  if (url.startsWith(_paypalCancelUrl)) {
                    _cancelPayPalCheckout();
                    return NavigationDecision.prevent;
                  }
                  return NavigationDecision.navigate;
                },
              ),
            )
            ..loadRequest(Uri.parse(approvalUrl));

      if (!mounted) return;
      setState(() {
        _paymentOrderId = orderId;
        _webViewController = controller;
        _isCreatingPayment = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isCreatingPayment = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unable to start PayPal checkout: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _capturePayPalOrder() async {
    if (_paymentOrderId == null || _isCapturingPayment) return;
    setState(() => _isCapturingPayment = true);

    try {
      final response = await http.post(
        Uri.parse('$_paypalBaseUrl/capturePayPalOrder'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'orderId': _paymentOrderId}),
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('Capture failed (${response.statusCode})');
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final payerEmail = data['data']?['payer']?['email_address']?.toString();
      final orderId = _paymentOrderId;

      await _paymentsRef.doc(orderId).set({
        'PaymentId': orderId,
        'Status': 'CAPTURED',
        'CapturedAt': FieldValue.serverTimestamp(),
        'PayerEmail': payerEmail,
      }, SetOptions(merge: true));

      if (!mounted) return;
      setState(() {
        _isCapturingPayment = false;
        _webViewController = null;
        _paymentOrderId = null;
      });

      await _saveCarBooking(orderId, payerEmail);
    } catch (e) {
      if (_paymentOrderId != null) {
        _paymentsRef.doc(_paymentOrderId).set({
          'PaymentId': _paymentOrderId,
          'Status': 'FAILED',
          'UpdatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
      if (mounted) {
        setState(() {
          _isCapturingPayment = false;
          _webViewController = null;
          _paymentOrderId = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment not completed. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _cancelPayPalCheckout() {
    if (_paymentOrderId != null) {
      _paymentsRef.doc(_paymentOrderId).set({
        'PaymentId': _paymentOrderId,
        'Status': 'CANCELLED',
        'UpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
    setState(() {
      _webViewController = null;
      _paymentOrderId = null;
      _isCreatingPayment = false;
      _isCapturingPayment = false;
    });
  }

  Future<void> _saveCarBooking(String? paymentId, String? payerEmail) async {
    try {
      String currentUserEmail =
          FirebaseAuth.instance.currentUser?.email ?? 'guest@example.com';

      List<String> datesToBook = [];
      for (int i = 0; i < widget.days; i++) {
        datesToBook.add(
          DateFormat(
            'yyyy-MM-dd',
          ).format(widget.startDate.add(Duration(days: i))),
        );
      }

      String todayStr = DateFormat('yyyy-MM-dd').format(getRealTime());
      bool startsToday = datesToBook.contains(todayStr);
      DateTime returnDate = widget.startDate.add(
        Duration(days: widget.days - 1),
      );

      await FirebaseFirestore.instance.collection('car_bookings').add({
        'userEmail': currentUserEmail,
        'carId': widget.car.id,
        'carName': widget.car.name,
        'imageUrl': widget.car.imageUrl,
        'startDate': widget.startDate.toIso8601String(),
        'endDate': returnDate.toIso8601String(),
        'totalPrice': _pendingTotal,
        'status': 'Upcoming',
        'paymentId': paymentId,
        'payerEmail': payerEmail,
        'bookedAt': FieldValue.serverTimestamp(),
      });

      await FirebaseFirestore.instance
          .collection('rental_cars')
          .doc(widget.car.id)
          .update({
            'bookedDates': FieldValue.arrayUnion(datesToBook),
            if (startsToday) 'status': 'rented',
          });

      if (mounted) {
        showDialog(
          context: context,
          builder:
              (c) => AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                title: const Text(
                  "Payment Successful!",
                  textAlign: TextAlign.center,
                ),
                content: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle, color: Colors.green, size: 64),
                    SizedBox(height: 16),
                    Text("Your car is booked and saved to your profile."),
                  ],
                ),
                actionsAlignment: MainAxisAlignment.center,
                actions: [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF137FEC),
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () {
                      Navigator.pop(c);
                      Navigator.pop(context);
                      Navigator.pop(context);
                    },
                    child: const Text("Done"),
                  ),
                ],
              ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Booking failed: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _fetchAddress() async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        widget.car.lat,
        widget.car.lng,
      );
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks.first;
        List<String> parts = [];
        if (place.street != null && place.street!.isNotEmpty)
          parts.add(place.street!);
        if (place.locality != null && place.locality!.isNotEmpty)
          parts.add(place.locality!);
        setState(() {
          _carAddress =
              parts.isNotEmpty
                  ? parts.join(", ")
                  : "Map Location (${widget.car.lat.toStringAsFixed(2)}, ${widget.car.lng.toStringAsFixed(2)})";
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _carAddress =
              "Map Location (${widget.car.lat.toStringAsFixed(2)}, ${widget.car.lng.toStringAsFixed(2)})";
        });
      }
    }
  }

  Widget _buildDynamicImage(String imageString) {
    if (imageString.startsWith('http'))
      return Image.network(
        imageString,
        fit: BoxFit.cover,
        errorBuilder: (c, e, s) => Container(color: Colors.grey[200]),
      );
    if (imageString.isNotEmpty) {
      try {
        return Image.memory(
          base64Decode(imageString),
          fit: BoxFit.cover,
          errorBuilder: (c, e, s) => Container(color: Colors.grey[200]),
        );
      } catch (e) {
        return Container(color: Colors.grey[200]);
      }
    }
    return Container(color: Colors.grey[200]);
  }

  Widget _buildPayPalLogo() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xFF003087),
            borderRadius: BorderRadius.circular(5),
          ),
          child: const Text(
            'Pay',
            style: TextStyle(
              color: Color(0xFF009CDE),
              fontWeight: FontWeight.bold,
              fontSize: 13,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
        const SizedBox(width: 2),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xFF009CDE),
            borderRadius: BorderRadius.circular(5),
          ),
          child: const Text(
            'Pal',
            style: TextStyle(
              color: Color(0xFF003087),
              fontWeight: FontWeight.bold,
              fontSize: 13,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const primaryColor = Color(0xFF137FEC);
    final bgColor = isDark ? const Color(0xFF101922) : const Color(0xFFF6F7F8);
    final surfaceColor = isDark ? const Color(0xFF1A2633) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF111418);
    final textMuted = isDark ? Colors.grey[400]! : const Color(0xFF617589);
    final borderColor =
        isDark ? const Color(0xFF2A3845) : const Color(0xFFE5E7EB);

    double subtotal = widget.car.price * widget.days;
    double taxes = subtotal * 0.10;
    double insuranceTotal =
        _addInsurance ? (_insuranceRatePerDay * widget.days) : 0.0;
    double total = subtotal + taxes + insuranceTotal;

    DateTime returnDate = widget.startDate.add(Duration(days: widget.days - 1));

    // Show PayPal WebView when order has been created
    if (_webViewController != null) {
      return Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(
          backgroundColor: surfaceColor,
          elevation: 0,
          title: Text(
            'PayPal Checkout',
            style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
          ),
          leading: IconButton(
            icon: Icon(Icons.close, color: textColor),
            onPressed: _cancelPayPalCheckout,
          ),
        ),
        body:
            _isCapturingPayment
                ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(color: primaryColor),
                      const SizedBox(height: 16),
                      Text(
                        'Confirming payment...',
                        style: TextStyle(color: textColor),
                      ),
                    ],
                  ),
                )
                : WebViewWidget(controller: _webViewController!),
      );
    }

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 450),
            child: Container(
              color: bgColor,
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      color: surfaceColor,
                      border: Border(bottom: BorderSide(color: borderColor)),
                    ),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Icon(Icons.arrow_back, color: textColor),
                        ),
                        Expanded(
                          child: Text(
                            "Review your booking",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: textColor,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ),
                        const SizedBox(width: 24),
                      ],
                    ),
                  ),

                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: surfaceColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: borderColor),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      widget.car.name,
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: textColor,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: primaryColor.withOpacity(
                                              0.1,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
                                          ),
                                          child: Text(
                                            widget.car.type,
                                            style: const TextStyle(
                                              color: primaryColor,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          "Standard",
                                          style: TextStyle(
                                            color: textMuted,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.verified_user,
                                          size: 14,
                                          color: textMuted,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          "Free Cancellation",
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: textMuted,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(
                                width: 100,
                                height: 75,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: _buildDynamicImage(
                                    widget.car.imageUrl,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        Container(
                          decoration: BoxDecoration(
                            color: surfaceColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: borderColor),
                          ),
                          child: Column(
                            children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  16,
                                  16,
                                  0,
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Column(
                                      children: [
                                        const Icon(
                                          Icons.flight_takeoff,
                                          color: primaryColor,
                                          size: 20,
                                        ),
                                        Container(
                                          width: 2,
                                          height: 40,
                                          margin: const EdgeInsets.symmetric(
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color:
                                                isDark
                                                    ? const Color(0xFF394B5A)
                                                    : const Color(0xFFDBE0E6),
                                            borderRadius: BorderRadius.circular(
                                              2,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            "PICKUP",
                                            style: TextStyle(
                                              color: textMuted,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              letterSpacing: 1.0,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            _carAddress,
                                            style: TextStyle(
                                              color: textColor,
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            "${DateFormat('MMM d, yyyy').format(widget.startDate)}, 10:00 AM",
                                            style: TextStyle(
                                              color: textMuted,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  0,
                                  16,
                                  16,
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Column(
                                      children: [
                                        Container(
                                          width: 2,
                                          height: 40,
                                          margin: const EdgeInsets.symmetric(
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color:
                                                isDark
                                                    ? const Color(0xFF394B5A)
                                                    : const Color(0xFFDBE0E6),
                                            borderRadius: BorderRadius.circular(
                                              2,
                                            ),
                                          ),
                                        ),
                                        const Icon(
                                          Icons.location_on,
                                          color: primaryColor,
                                          size: 20,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const SizedBox(height: 20),
                                          Text(
                                            "RETURN",
                                            style: TextStyle(
                                              color: textMuted,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              letterSpacing: 1.0,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            "Same Location",
                                            style: TextStyle(
                                              color: textColor,
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            "${DateFormat('MMM d, yyyy').format(returnDate)}, 10:00 AM",
                                            style: TextStyle(
                                              color: textMuted,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        Text(
                          "Add-ons",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 12),
                        GestureDetector(
                          onTap:
                              () => setState(
                                () => _addInsurance = !_addInsurance,
                              ),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color:
                                  _addInsurance
                                      ? primaryColor.withOpacity(
                                        isDark ? 0.1 : 0.05,
                                      )
                                      : surfaceColor,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color:
                                    _addInsurance ? primaryColor : borderColor,
                                width: _addInsurance ? 2 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.shield,
                                  color:
                                      _addInsurance ? primaryColor : textMuted,
                                  size: 28,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "Full Coverage Insurance",
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: textColor,
                                          fontSize: 14,
                                        ),
                                      ),
                                      Text(
                                        "\$${_insuranceRatePerDay.toInt()}/day • Covers damage & theft",
                                        style: TextStyle(
                                          color: textMuted,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Checkbox(
                                  value: _addInsurance,
                                  activeColor: primaryColor,
                                  onChanged:
                                      (v) => setState(
                                        () => _addInsurance = v ?? false,
                                      ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        Container(
                          decoration: BoxDecoration(
                            color: surfaceColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: borderColor),
                          ),
                          child: Theme(
                            data: Theme.of(
                              context,
                            ).copyWith(dividerColor: Colors.transparent),
                            child: ExpansionTile(
                              backgroundColor:
                                  isDark
                                      ? const Color(0xFF1F2B36)
                                      : Colors.grey[50],
                              collapsedBackgroundColor:
                                  isDark
                                      ? const Color(0xFF1F2B36)
                                      : Colors.grey[50],
                              title: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Total Price",
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: textColor,
                                    ),
                                  ),
                                  const Text(
                                    "Show breakdown",
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: primaryColor,
                                    ),
                                  ),
                                ],
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    "\$${total.toStringAsFixed(2)}",
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: textColor,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Icon(Icons.expand_more, color: textMuted),
                                ],
                              ),
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  color: surfaceColor,
                                  child: Column(
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            "Rate (${widget.days} days x \$${widget.car.price.toInt()})",
                                            style: TextStyle(
                                              color: textMuted,
                                              fontSize: 14,
                                            ),
                                          ),
                                          Text(
                                            "\$${subtotal.toStringAsFixed(2)}",
                                            style: TextStyle(
                                              color: textColor,
                                              fontWeight: FontWeight.w500,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            "Taxes & Fees",
                                            style: TextStyle(
                                              color: textMuted,
                                              fontSize: 14,
                                            ),
                                          ),
                                          Text(
                                            "\$${taxes.toStringAsFixed(2)}",
                                            style: TextStyle(
                                              color: textColor,
                                              fontWeight: FontWeight.w500,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ),

                                      if (_addInsurance) ...[
                                        const SizedBox(height: 8),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              "Insurance (${widget.days} days x \$${_insuranceRatePerDay.toInt()})",
                                              style: TextStyle(
                                                color: textMuted,
                                                fontSize: 14,
                                              ),
                                            ),
                                            Text(
                                              "\$${insuranceTotal.toStringAsFixed(2)}",
                                              style: TextStyle(
                                                color: textColor,
                                                fontWeight: FontWeight.w500,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],

                                      Divider(color: borderColor, height: 24),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            "Total due today",
                                            style: TextStyle(
                                              color: textColor,
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          Text(
                                            "\$${total.toStringAsFixed(2)}",
                                            style: const TextStyle(
                                              color: primaryColor,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        Text(
                          "Payment Method",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 12),

                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: primaryColor.withOpacity(
                              isDark ? 0.1 : 0.05,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: primaryColor, width: 2),
                          ),
                          child: Row(
                            children: [
                              _buildPayPalLogo(),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "PayPal",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: textColor,
                                        fontSize: 15,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      "You will be securely redirected to PayPal to complete your payment.",
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.check_circle,
                                color: primaryColor,
                                size: 22,
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.lock, size: 14, color: textMuted),
                            const SizedBox(width: 8),
                            Text(
                              "Payments are secure and encrypted",
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: textMuted,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: surfaceColor,
                      border: Border(top: BorderSide(color: borderColor)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, -4),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed:
                          _isCreatingPayment
                              ? null
                              : () => _startPayPalCheckout(total),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child:
                          _isCreatingPayment
                              ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                              : Text(
                                "Pay with PayPal • MYR ${total.toStringAsFixed(2)}",
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
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
}

// ==========================================
// 6. ADD NEW CAR SCREEN (HOST)
// ==========================================
class AddNewCarScreen extends StatefulWidget {
  const AddNewCarScreen({super.key});

  @override
  State<AddNewCarScreen> createState() => _AddNewCarScreenState();
}

class _AddNewCarScreenState extends State<AddNewCarScreen> {
  bool _isUploading = false;
  File? _imageFile;

  int _seatCount = 5;
  String _selectedYear = "2023";
  String? _selectedCarType;

  LatLng? _selectedLocation;
  String _locationDisplay = "Tap to select on map";

  final TextEditingController _modelController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _regController = TextEditingController();

  final List<String> _years = ["2024", "2023", "2022", "2021", "2020", "2019"];
  final List<String> _carTypes = [
    'Standard Sedan',
    'Compact',
    'Electric',
    'Economy',
    'SUV',
    'Luxury',
    'Van',
  ];

  Future<void> _pickImageFromCamera() async {
    final pickedFile = await ImagePicker().pickImage(
      source: ImageSource.camera,
      imageQuality: 20,
      maxWidth: 600,
    );
    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  Future<void> _openMapPicker() async {
    Position? currentPos;
    try {
      currentPos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (e) {
      debugPrint("No GPS");
    }

    LatLng initialTarget =
        currentPos != null
            ? LatLng(currentPos.latitude, currentPos.longitude)
            : const LatLng(3.1412, 101.6865);
    if (!mounted) return;

    final LatLng? pickedLatLng = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MapPickerScreen(initialLocation: initialTarget),
      ),
    );

    if (pickedLatLng != null) {
      setState(() => _selectedLocation = pickedLatLng);
      try {
        List<Placemark> placemarks = await placemarkFromCoordinates(
          pickedLatLng.latitude,
          pickedLatLng.longitude,
        );
        if (placemarks.isNotEmpty) {
          Placemark place = placemarks.first;
          List<String> addressParts = [];
          if (place.street != null && place.street!.isNotEmpty)
            addressParts.add(place.street!);
          if (place.subLocality != null && place.subLocality!.isNotEmpty)
            addressParts.add(place.subLocality!);
          if (place.locality != null && place.locality!.isNotEmpty)
            addressParts.add(place.locality!);
          setState(() {
            _locationDisplay =
                addressParts.isNotEmpty
                    ? addressParts.join(", ")
                    : "Location Saved";
          });
        }
      } catch (e) {
        setState(() => _locationDisplay = "Location Saved");
      }
    }
  }

  Future<void> _submitCarListing() async {
    if (_modelController.text.isEmpty ||
        _priceController.text.isEmpty ||
        _selectedCarType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please fill all required fields."),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    if (_selectedLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please select a pick-up location on the map."),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    if (_imageFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please take a photo of your car."),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isUploading = true);

    try {
      List<int> imageBytes = await _imageFile!.readAsBytes();
      String base64Image = base64Encode(imageBytes);

      List<String> featuresList = [
        _selectedYear,
        "$_seatCount Seats",
        "Reg: ${_regController.text.isNotEmpty ? _regController.text : 'N/A'}",
      ];

      await FirebaseFirestore.instance.collection('pending_cars').add({
        'name': _modelController.text.trim(),
        'type': _selectedCarType,
        'price': double.parse(_priceController.text.trim()),
        'features': featuresList,
        'imageUrl': base64Image,
        'tag': 'New',
        'status': 'available',
        'lat': _selectedLocation!.latitude,
        'lng': _selectedLocation!.longitude,
        'status_admin': 'pending',
        'submittedAt': FieldValue.serverTimestamp(),
        'bookedDates': [], // Initializes empty array
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Submitted for Admin Approval! ✨"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF111418)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Add New Car",
          style: TextStyle(
            color: Color(0xFF111418),
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body:
          _isUploading
              ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text("Processing Image & Uploading..."),
                  ],
                ),
              )
              : ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  _buildSectionHeader("Car Photos"),
                  const SizedBox(height: 16),
                  _buildPhotoGrid(),
                  const SizedBox(height: 24),
                  _buildSectionHeader("Vehicle Details"),
                  const SizedBox(height: 16),
                  _buildLabel("Car Model"),
                  _buildTextField(
                    controller: _modelController,
                    hint: "e.g. Honda City",
                    icon: Icons.directions_car_outlined,
                  ),
                  const SizedBox(height: 16),
                  _buildLabel("Car Type"),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedCarType,
                        hint: Text(
                          "Select Type",
                          style: TextStyle(color: Colors.grey.shade400),
                        ),
                        isExpanded: true,
                        items:
                            _carTypes
                                .map(
                                  (String value) => DropdownMenuItem<String>(
                                    value: value,
                                    child: Text(value),
                                  ),
                                )
                                .toList(),
                        onChanged: (val) {
                          setState(() => _selectedCarType = val);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLabel("Year"),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _selectedYear,
                                  isExpanded: true,
                                  items:
                                      _years
                                          .map(
                                            (String value) =>
                                                DropdownMenuItem<String>(
                                                  value: value,
                                                  child: Text(value),
                                                ),
                                          )
                                          .toList(),
                                  onChanged: (val) {
                                    setState(() => _selectedYear = val!);
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLabel("Seats"),
                            Container(
                              height: 48,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  IconButton(
                                    icon: const Icon(
                                      Icons.remove,
                                      color: Color(0xFF137FEC),
                                    ),
                                    onPressed: () {
                                      if (_seatCount > 1)
                                        setState(() => _seatCount--);
                                    },
                                  ),
                                  Text(
                                    _seatCount.toString(),
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.add,
                                      color: Color(0xFF137FEC),
                                    ),
                                    onPressed: () {
                                      setState(() => _seatCount++);
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildLabel("Registration Number"),
                  _buildTextField(
                    controller: _regController,
                    hint: "ABC-1234",
                    isUpperCase: true,
                  ),
                  const SizedBox(height: 24),
                  _buildSectionHeader("Rental Pick-up Location"),
                  const SizedBox(height: 16),
                  _buildLabel("Where will the renter pick up the car?"),
                  InkWell(
                    onTap: _openMapPicker,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color:
                              _selectedLocation == null
                                  ? Colors.red.shade200
                                  : Colors.grey.shade300,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.location_on,
                            color:
                                _selectedLocation == null
                                    ? Colors.redAccent
                                    : const Color(0xFF137FEC),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _locationDisplay,
                              style: TextStyle(
                                color:
                                    _selectedLocation == null
                                        ? Colors.grey.shade400
                                        : Colors.black87,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const Icon(Icons.map, color: Colors.grey),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildSectionHeader("Rental Pricing"),
                  const SizedBox(height: 16),
                  _buildLabel("Price per Day"),
                  Stack(
                    alignment: Alignment.centerLeft,
                    children: [
                      _buildTextField(
                        controller: _priceController,
                        hint: "0.00",
                        inputType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        contentPadding: const EdgeInsets.only(
                          left: 32,
                          right: 60,
                        ),
                      ),
                      const Positioned(
                        left: 16,
                        child: Text(
                          "\$",
                          style: TextStyle(
                            color: Colors.grey,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const Positioned(
                        right: 16,
                        child: Text(
                          "/ day",
                          style: TextStyle(color: Colors.grey, fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 40),
                  ElevatedButton(
                    onPressed: _submitCarListing,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF137FEC),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      "Submit for Approval",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
    );
  }

  Widget _buildSectionHeader(String title) => Text(
    title,
    style: const TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.bold,
      color: Color(0xFF111418),
    ),
  );
  Widget _buildLabel(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8.0),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: Color(0xFF111418),
      ),
    ),
  );
  Widget _buildTextField({
    required TextEditingController controller,
    String? hint,
    IconData? icon,
    bool isUpperCase = false,
    TextInputType inputType = TextInputType.text,
    EdgeInsets? contentPadding,
  }) {
    return TextField(
      controller: controller,
      keyboardType: inputType,
      textCapitalization:
          isUpperCase
              ? TextCapitalization.characters
              : TextCapitalization.sentences,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey.shade400),
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            contentPadding ??
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        suffixIcon:
            icon != null ? Icon(icon, color: Colors.grey.shade400) : null,
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
          borderSide: const BorderSide(color: Color(0xFF137FEC), width: 2),
        ),
      ),
    );
  }

  Widget _buildPhotoGrid() {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: _pickImageFromCamera,
            child: AspectRatio(
              aspectRatio: 1,
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF137FEC).withOpacity(0.5),
                    style: BorderStyle.solid,
                  ),
                  image:
                      _imageFile != null
                          ? DecorationImage(
                            image: FileImage(_imageFile!),
                            fit: BoxFit.cover,
                          )
                          : null,
                ),
                child:
                    _imageFile == null
                        ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF137FEC).withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.camera_alt,
                                color: Color(0xFF137FEC),
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              "Take Photo",
                              style: TextStyle(
                                color: Color(0xFF137FEC),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        )
                        : null,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: AspectRatio(
            aspectRatio: 1,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Icon(
                Icons.directions_car,
                color: Colors.grey.shade300,
                size: 32,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: AspectRatio(
            aspectRatio: 1,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Icon(
                Icons.directions_car,
                color: Colors.grey.shade300,
                size: 32,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ==========================================
// 7. MAP LOCATION PICKER SCREEN
// ==========================================
class MapPickerScreen extends StatefulWidget {
  final LatLng initialLocation;
  const MapPickerScreen({super.key, required this.initialLocation});

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  LatLng? _pickedLocation;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Select Pick-up Location",
          style: TextStyle(color: Colors.black, fontSize: 16),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: widget.initialLocation,
              zoom: 15,
            ),
            onTap: (latLng) {
              setState(() {
                _pickedLocation = latLng;
              });
            },
            markers:
                _pickedLocation == null
                    ? {}
                    : {
                      Marker(
                        markerId: const MarkerId('picked'),
                        position: _pickedLocation!,
                        icon: BitmapDescriptor.defaultMarkerWithHue(
                          BitmapDescriptor.hueBlue,
                        ),
                      ),
                    },
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            zoomControlsEnabled: false,
          ),
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Row(
                children: const [
                  Icon(Icons.touch_app, color: Color(0xFF137FEC)),
                  SizedBox(width: 8),
                  Text(
                    "Tap anywhere on the map to drop a pin.",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
          if (_pickedLocation != null)
            Positioned(
              bottom: 40,
              left: 20,
              right: 20,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF137FEC),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 6,
                ),
                onPressed: () => Navigator.pop(context, _pickedLocation),
                child: const Text(
                  "Confirm Location",
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
  }
}
