// ─────────────────────────────────────────────────────────────
//  UniRide – Home / Map Screen
//
//  Dependencies (add to pubspec.yaml):
//
//  dependencies:
//    flutter:
//      sdk: flutter
//    geolocator: ^11.0.0
//    maplibre_gl: ^0.25.0
//
//  Android – android/app/src/main/AndroidManifest.xml
//    <uses-permission android:name="android.permission.INTERNET"/>
//    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
//    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
//
//  iOS – ios/Runner/Info.plist
//    <key>NSLocationWhenInUseUsageDescription</key>
//    <string>UniRide needs your location to show nearby shuttles.</string>
//
//  Replace YOUR_STADIA_API_KEY below with your actual key from
//  https://client.stadiamaps.com/
// ─────────────────────────────────────────────────────────────

import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:maplibre_gl/maplibre_gl.dart';
import 'schedule.dart';
import 'profile.dart';
import 'status.dart';

// ── Constants ──────────────────────────────────────────────────────────────

String get _stadiaApiKey => dotenv.env['STADIA_API_KEY'] ?? '';

/// MapLibre demo style with built-in glyphs and sprites.
/// Stadia’s Stamen style can include MapLibre symbols whose glyphs are
/// missing on the native side and can crash with C++ std::out_of_range.
const String _defaultMapStyle =
    'https://basemaps.cartocdn.com/gl/positron-gl-style/style.json';

String get _mapStyleUrl =>
    dotenv.env['MAP_STYLE_URL']?.isNotEmpty == true
        ? dotenv.env['MAP_STYLE_URL']!
        : _defaultMapStyle;

/// Initial camera position – centre of a generic university campus.
/// Set to Colombo, Sri Lanka.
const LatLng _campusCenter = LatLng(6.9271, 79.8612);

// ── Entry point ────────────────────────────────────────────────────────────

void main() => runApp(const UniRideApp());

class UniRideApp extends StatelessWidget {
  const UniRideApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'UniRide',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.black),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

// ── Data Models ────────────────────────────────────────────────────────────

class ShuttleDetails {
  const ShuttleDetails({
    required this.shuttleId,
    required this.capacity,
    required this.destination,
    required this.deviceId,
    required this.driverId,
    required this.vehicleNumber,
    required this.driverName,
    required this.driverPhone,
  });

  final String shuttleId;
  final int capacity;
  final String destination;
  final String deviceId;
  final String driverId;
  final String vehicleNumber;
  final String driverName;
  final String driverPhone;
}

// ── Home Screen ────────────────────────────────────────────────────────────

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  MaplibreMapController? _mapController;

  final TextEditingController _searchController = TextEditingController();

  List<Symbol> _shuttleSymbols = [];
  Timer? _shuttlesTimer;
  Map<String, String> _symbolIdToDeviceId = {};

  Line? _routeLine;
  Symbol? _destinationSymbol;
  final List<Circle> _stopCircles = [];
  final Map<String, List<LatLng>> _shuttleStopsCache = {};

  // State for shuttle details card
  ShuttleDetails? _selectedShuttleDetails;
  bool _isFetchingShuttleDetails = false;

  // ── Map callbacks ────────────────────────────────────────────────────────

  void _onMapCreated(MaplibreMapController controller) {
    _mapController = controller;
    controller.onSymbolTapped.add(_onSymbolTapped);
  }

  void _onStyleLoaded() async {
    // Using the official MapLibre demo style avoids Stadia/Stamen styles where
    // some symbol text-font references are missing in native glyph store.
    // This prevents the MapLibre native crash:
    //   std::out_of_range: basic_string
    //
    // Further app logic can be added here if needed.

    // Add static marking for NSBM
    _mapController?.addCircle(
      const CircleOptions(
        geometry: LatLng(6.821584762454514, 80.04158362528202),
        circleColor: '#000000',
        circleRadius: 6.0,
        circleStrokeWidth: 2.0,
        circleStrokeColor: '#FFFFFF',
      ),
    );
    _mapController?.addSymbol(
      const SymbolOptions(
        geometry: LatLng(6.821584762454514, 80.04158362528202),
        textField: 'NSBM',
        textSize: 14.0,
        textColor: '#000000',
        textHaloColor: '#FFFFFF',
        textHaloWidth: 2.0,
        textOffset: Offset(0, 1.2),
      ),
    );

    _goToUserLocation();

    _fetchShuttles();
    _shuttlesTimer = Timer.periodic(const Duration(seconds: 10), (_) => _fetchShuttles());
  }

  void _onSymbolTapped(Symbol symbol) {
    final deviceId = _symbolIdToDeviceId[symbol.id];
    if (deviceId != null && !_isFetchingShuttleDetails) {
      _fetchAndShowShuttleDetails(deviceId, symbol.options.geometry);
    }
  }

  Future<void> _fetchAndShowShuttleDetails(String deviceId, LatLng? shuttleLocation) async {
    setState(() {
      _isFetchingShuttleDetails = true;
      _selectedShuttleDetails = null;
    });

    try {
      final shuttleApiUrl = dotenv.env['SHUTTLE_API'];
      final driverApiUrl = dotenv.env['DRIVER_API'];
      if (shuttleApiUrl == null || shuttleApiUrl.isEmpty) {
        throw Exception('SHUTTLE_API not found in .env');
      }
      if (driverApiUrl == null || driverApiUrl.isEmpty) {
        throw Exception('DRIVER_API not found in .env');
      }

      final response = await http.get(Uri.parse(shuttleApiUrl));
      final driverResponse = await http.get(Uri.parse(driverApiUrl));
      if (!mounted) return;

      if (response.statusCode == 200 && driverResponse.statusCode == 200) {
        final dynamic decoded = jsonDecode(response.body);
        final dynamic decodedDrivers = jsonDecode(driverResponse.body);
        
        final List<dynamic> shuttleData =
            decoded is List ? decoded : (decoded['Items'] ?? decoded['items'] ?? []);
        final List<dynamic> driverData =
            decodedDrivers is List ? decodedDrivers : (decodedDrivers['Items'] ?? decodedDrivers['items'] ?? []);

        final shuttleInfo = shuttleData.firstWhere(
          (s) => s['deviceId']?.toString() == deviceId,
          orElse: () => null,
        );

        if (shuttleInfo != null) {
          final driverId = shuttleInfo['driverId']?.toString() ?? 'N/A';
          final dynamic driverInfo = driverData.firstWhere((d) => d is Map && d['driverId']?.toString() == driverId, orElse: () => null);

          final details = ShuttleDetails(
            shuttleId: shuttleInfo['shuttleId']?.toString() ?? 'N/A',
            capacity: int.tryParse(shuttleInfo['capacity']?.toString() ?? '0') ?? 0,
            destination: shuttleInfo['destination']?.toString() ?? 'N/A',
            deviceId: shuttleInfo['deviceId']?.toString() ?? 'N/A',
            driverId: driverId,
            vehicleNumber: shuttleInfo['vehicleNumber']?.toString() ?? 'N/A',
            driverName: driverInfo != null ? (driverInfo['driverName']?.toString() ?? 'Unknown') : 'Unknown',
            driverPhone: driverInfo != null ? (driverInfo['phoneNumber']?.toString() ?? 'Unknown') : 'Unknown',
          );
          setState(() {
            _selectedShuttleDetails = details;
          });

          if (shuttleLocation != null) {
            final shuttleStopsApiUrl = dotenv.env['SHUTTLE_STOPS_API'];
            
            List<LatLng> stops = [];
            
            if (details.shuttleId == 's001') {
              stops = const [
                LatLng(6.855245514556124, 80.05865701824928),
                LatLng(6.8585403000705725, 80.09122540616569),
                LatLng(6.908931195765443, 80.0825102621184),
                LatLng(6.947475561303212, 80.09407315229855),
                LatLng(6.975026901546493, 80.11811965850465),
              ];
            } else if (_shuttleStopsCache.containsKey(details.shuttleId)) {
              stops = _shuttleStopsCache[details.shuttleId]!;
            } else if (shuttleStopsApiUrl != null && shuttleStopsApiUrl.isNotEmpty) {
               try {
                 final stopsResponse = await http.get(Uri.parse('$shuttleStopsApiUrl?shuttleId=${details.shuttleId}'));
                 if (stopsResponse.statusCode == 200) {
                   dynamic decodedStops = jsonDecode(stopsResponse.body);
                   
                   // 1. Unwrap API Gateway body wrapper if present
                   if (decodedStops is Map && decodedStops.containsKey('body') && decodedStops['body'] is String) {
                     decodedStops = jsonDecode(decodedStops['body']);
                   }

                   // 2. Unwrap DynamoDB "L" (List) wrapper if data was inserted via raw AWS SDK format
                   if (decodedStops is Map && decodedStops.containsKey('stops')) {
                     decodedStops = decodedStops['stops'];
                   }
                   if (decodedStops is Map && decodedStops.containsKey('L')) {
                     decodedStops = decodedStops['L'];
                   }

                   if (decodedStops is List) {
                     for (var stop in decodedStops) {
                       var latRaw = stop is Map ? stop['lat'] : null;
                       var lngRaw = stop is Map ? stop['lng'] : null;

                       // Fallback for raw DynamoDB format
                       if (latRaw == null && stop is Map && stop['M'] != null) {
                         latRaw = stop['M']['lat']?['N'] ?? stop['M']['lat'];
                         lngRaw = stop['M']['lng']?['N'] ?? stop['M']['lng'];
                       }

                       final lat = double.tryParse(latRaw?.toString() ?? '');
                       final lng = double.tryParse(lngRaw?.toString() ?? '');
                       if (lat != null && lng != null) {
                         stops.add(LatLng(lat, lng));
                       }
                     }
                     _shuttleStopsCache[details.shuttleId] = stops;
                   }
                   debugPrint('Loaded ${stops.length} shuttle stops from API.');
                 }
               } catch (e) {
                 debugPrint('Error fetching shuttle stops: $e');
               }
            }

            // Pass the populated stops to the route drawing function
            await _showShuttleRoute(shuttleLocation, stops);
          }

        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Shuttle details not found.')),
          );
        }
      } else {
        throw Exception('Failed to load shuttle or driver data from server.');
      }
    } catch (e) {
      debugPrint('Error fetching shuttle details: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching shuttle details: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isFetchingShuttleDetails = false;
        });
      }
    }
  }

  void _closeShuttleCard() {
    setState(() {
      _selectedShuttleDetails = null;
    });
    if (_routeLine != null) {
      _mapController?.removeLine(_routeLine!);
      _routeLine = null;
    }
    for (var circle in _stopCircles) {
      _mapController?.removeCircle(circle);
    }
    _stopCircles.clear();
  }

  Future<void> _showShuttleRoute(LatLng start, List<LatLng> stops) async {
    if (_mapController == null) return;

    try {
      if (_routeLine != null) {
        await _mapController?.removeLine(_routeLine!);
        _routeLine = null;
      }
      for (var circle in _stopCircles) {
        await _mapController?.removeCircle(circle);
      }
      _stopCircles.clear();
      if (_destinationSymbol != null) {
        await _mapController?.removeSymbol(_destinationSymbol!);
        _destinationSymbol = null;
      }

      const nsbmLocation = LatLng(6.821584762454514, 80.04158362528202);

      // Force OSRM to calculate the route THROUGH the designated stops
      List<LatLng> allPoints = [start, ...stops, nsbmLocation];
      String coordinatesString = allPoints.map((p) => '${p.longitude},${p.latitude}').join(';');

      final routeUrl = Uri.parse(
          'https://router.project-osrm.org/route/v1/driving/$coordinatesString?geometries=geojson&overview=full');
      final routeResponse = await http.get(routeUrl);

      if (routeResponse.statusCode == 200) {
        final routeData = jsonDecode(routeResponse.body);
        if (routeData['routes'] != null && routeData['routes'].isNotEmpty) {
          final geometry = routeData['routes'][0]['geometry'];

          _routeLine = await _mapController?.addLine(
            LineOptions(
              geometry: [
                for (var coord in geometry['coordinates'])
                  LatLng((coord[1] as num).toDouble(), (coord[0] as num).toDouble())
              ],
              lineColor: '#2196F3', // Blue route path for shuttle
              lineWidth: 5.0,
              lineOpacity: 0.6,
            ),
          );

          // Mark each stop on the route with a highly visible black dot
          for (var stop in stops) {
            final circle = await _mapController?.addCircle(
              CircleOptions(
                geometry: stop,
                circleColor: '#000000', 
                circleRadius: 8.0, // Increased size slightly to stand out over the line
                circleStrokeWidth: 3.0,
                circleStrokeColor: '#FFFFFF',
              ),
            );
            if (circle != null) {
              _stopCircles.add(circle);
            }
          }

          // Focus the map on the shuttle location
          _mapController?.animateCamera(
            CameraUpdate.newCameraPosition(
              CameraPosition(target: start, zoom: 13.0),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Routing service is currently unavailable.')),
          );
        }
      }
    } catch (e) {
      debugPrint('Error calculating shuttle route: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error calculating shuttle route.')),
        );
      }
    }
  }

  Future<void> _fetchShuttles() async {
    if (_mapController == null) return;

    try {
      final apiUrl = dotenv.env['LOCATION_API'];
      if (apiUrl == null || apiUrl.isEmpty) {
        debugPrint('LOCATION_API not found in .env');
        return;
      }

      final response = await http.get(Uri.parse(apiUrl));
      if (response.statusCode == 200) {
        final dynamic decoded = jsonDecode(response.body);
        final List<dynamic> locationData = decoded is List
            ? decoded
            : (decoded['Items'] ?? decoded['items'] ?? []);

        // Clear old symbols and mapping
        for (final symbol in _shuttleSymbols) {
          await _mapController?.removeSymbol(symbol);
        }
        _shuttleSymbols.clear();
        _symbolIdToDeviceId.clear();

        if (locationData.isNotEmpty) {
          // Filter to get only the latest location per device
          Map<String, dynamic> latestLocations = {};
          for (var loc in locationData) {
            final deviceId = loc['deviceId']?.toString();
            if (deviceId == null) continue;

            final currentTsStr = loc['timestamp']?.toString() ?? '0';
            final currentTs = int.tryParse(currentTsStr) ?? 0;

            if (!latestLocations.containsKey(deviceId)) {
              latestLocations[deviceId] = loc;
            } else {
              final existingTsStr = latestLocations[deviceId]['timestamp']?.toString() ?? '0';
              final existingTs = int.tryParse(existingTsStr) ?? 0;
              if (currentTs > existingTs) {
                latestLocations[deviceId] = loc;
              }
            }
          }

          for (var loc in latestLocations.values) {
            final latStr = loc['lat']?.toString();
            final lngStr = loc['lng']?.toString();
            final deviceId = loc['deviceId']?.toString();

            if (latStr != null && lngStr != null && deviceId != null) {
              final lat = double.tryParse(latStr);
              final lng = double.tryParse(lngStr);

              if (lat != null && lng != null) {
                final pos = LatLng(lat, lng);

                final symbol = await _mapController?.addSymbol(
                  SymbolOptions(
                    geometry: pos,
                    textField: '^', // Standard ASCII caret acts as a safe navigation icon
                    textSize: 40.0, // Increased size for visibility
                    textColor: '#808080', // Gray
                    textHaloColor: '#FFFFFF',
                    textHaloWidth: 2.0,
                  ),
                );
                if (symbol != null) {
                  _shuttleSymbols.add(symbol);
                  _symbolIdToDeviceId[symbol.id] = deviceId;
                }
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error fetching shuttles: $e');
    }
  }

  Future<void> _goToUserLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location services are disabled.')),
        );
      }
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permission denied.')),
        );
      }
      return;
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permissions are permanently denied.')),
        );
      }
      return;
    }

    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // Enable map's native tracking mode
      await _mapController?.updateMyLocationTrackingMode(MyLocationTrackingMode.tracking);

      // Zoom in closer on the current location
      _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(position.latitude, position.longitude), 
            zoom: 17.5,
          ),
        ),
      );
    } catch (e) {
      debugPrint('Error getting location: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not fetch current location.')),
        );
      }
    }
  }

  Future<void> _searchLocation(String query) async {
    if (query.isEmpty || _mapController == null) return;

    FocusScope.of(context).unfocus(); // Dismiss keyboard

    try {
      if (_routeLine != null) {
        await _mapController?.removeLine(_routeLine!);
        _routeLine = null;
      }
      for (var circle in _stopCircles) {
        await _mapController?.removeCircle(circle);
      }
      _stopCircles.clear();
      if (_destinationSymbol != null) {
        await _mapController?.removeSymbol(_destinationSymbol!);
        _destinationSymbol = null;
      }

      // 1. Get destination coordinates
      final geoUrl = Uri.parse(
          'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query)}&format=json&limit=1');
      final geoResponse = await http.get(
        geoUrl,
        headers: {'User-Agent': 'UniRide/1.0.0'},
      );

      if (geoResponse.statusCode == 200) {
        final geoData = jsonDecode(geoResponse.body);
        if (geoData.isNotEmpty) {
          final lat = double.parse(geoData[0]['lat']);
          final lon = double.parse(geoData[0]['lon']);
          final destination = LatLng(lat, lon);

          const nsbmLocation = LatLng(6.821584762454514, 80.04158362528202);

          // 2. Fetch routing path from NSBM to Destination
          final routeUrl = Uri.parse(
              'https://router.project-osrm.org/route/v1/driving/${nsbmLocation.longitude},${nsbmLocation.latitude};${destination.longitude},${destination.latitude}?geometries=geojson&overview=full');
          final routeResponse = await http.get(routeUrl);

          if (routeResponse.statusCode == 200) {
            final routeData = jsonDecode(routeResponse.body);
            if (routeData['routes'] != null && routeData['routes'].isNotEmpty) {
              final geometry = routeData['routes'][0]['geometry'];

              _destinationSymbol = await _mapController?.addSymbol(
                SymbolOptions(
                  geometry: destination,
                  textField: query,
                  textSize: 14.0,
                  textColor: '#FFFFFF',
                  textHaloColor: '#000000',
                  textHaloWidth: 2.0,
                  textOffset: const Offset(0, 1.5),
                ),
              );

              _routeLine = await _mapController?.addLine(
                LineOptions(
                  geometry: [
                    for (var coord in geometry['coordinates'])
                      LatLng((coord[1] as num).toDouble(), (coord[0] as num).toDouble())
                  ],
                  lineColor: '#000000', // Black route path
                  lineWidth: 5.0,
                  lineOpacity: 0.4, // Lower opacity prevents hiding text underneath
                ),
              );

              // Focus the map on the searched destination
              _mapController?.animateCamera(
                CameraUpdate.newCameraPosition(
                  CameraPosition(target: destination, zoom: 15.0),
                ),
              );
            }
          }
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location not found')),
          );
        }
      }
    } catch (e) {
      debugPrint('Error searching location or routing: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error finding route')),
        );
      }
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      // ── AppBar ────────────────────────────────────────────────────────────
      appBar: AppBar(
        backgroundColor: const Color(0xFFEEEEEE),
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        titleSpacing: 20,
        title: const Text(
          'UNIRIDE CLIENT',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            letterSpacing: 2.5,
            color: Colors.black,
          ),
        ),
      ),

      // ── Body – map fills the space between AppBar and BottomNav ──────────
      body: Stack(
        children: [
          // ── MapLibre map ──────────────────────────────────────────────────
          MaplibreMap(
            styleString: _mapStyleUrl,
            initialCameraPosition: const CameraPosition(
              target: _campusCenter,
              zoom: 14,
            ),
            onMapCreated: _onMapCreated,
            onStyleLoadedCallback: _onStyleLoaded,
            minMaxZoomPreference: const MinMaxZoomPreference(7.0, 20.0),
            myLocationEnabled: true,
            myLocationTrackingMode: MyLocationTrackingMode.none,
            myLocationRenderMode: MyLocationRenderMode.normal,
            trackCameraPosition: true,
            compassEnabled: false,
            attributionButtonMargins: const Point(-100, -100), // hide default
            logoViewMargins: const Point(-100, -100),          // hide default
          ),

          // ── Search bar ────────────────────────────────────────────────────
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: _SearchBar(
              controller: _searchController,
              onSearch: _searchLocation,
            ),
          ),

          // ── Re-center / location FAB ──────────────────────────────────────
          Positioned(
            right: 16,
            bottom: 16,
            child: _LocationFab(onTap: _goToUserLocation),
          ),

          // -- Shuttle details card ─────────────────────────────────────────
          if (_selectedShuttleDetails != null || _isFetchingShuttleDetails)
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: _ShuttleDetailsCard(
                details: _selectedShuttleDetails,
                isLoading: _isFetchingShuttleDetails,
                onClose: _closeShuttleCard,
              ),
            ),
        ],
      ),

      // ── Bottom navigation bar ─────────────────────────────────────────────
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) {
          if (i == _currentIndex) return;
          if (i == 0) {
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const HomeScreen()));
          } else if (i == 1) {
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const ScheduleScreen()));
          } else if (i == 2) {
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const ShuttleStatusScreen()));
          } else if (i == 2) {
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const ProfileScreen()));
          }
        },
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: Colors.black,
        unselectedItemColor: Colors.black54,
        selectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 11,
          letterSpacing: 0.8,
        ),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 11,
          letterSpacing: 0.8,
        ),
        elevation: 8,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.map_outlined),
            activeIcon: Icon(Icons.map),
            label: 'HOME',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today_outlined),
            activeIcon: Icon(Icons.calendar_today),
            label: 'SCHEDULE',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.directions_bus_outlined),
            activeIcon: Icon(Icons.directions_bus),
            label: 'STATUS',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'PROFILE',
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _shuttlesTimer?.cancel();
    super.dispose();
  }
}

// ── Shuttle Details Card Widget ────────────────────────────────────────────

class _ShuttleDetailsCard extends StatelessWidget {
  const _ShuttleDetailsCard({
    this.details,
    required this.isLoading,
    required this.onClose,
  });

  final ShuttleDetails? details;
  final bool isLoading;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    // Use a LayoutBuilder to constrain the height to a fraction of the map view.
    return LayoutBuilder(builder: (context, constraints) {
      return ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height / 3.5,
        ),
        child: Card(
          elevation: 4.0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                child: isLoading
                    ? const Center(child: CircularProgressIndicator(color: Colors.black))
                    : details == null
                        ? const Center(child: Text('Shuttle details not available.'))
                        : _buildDetailsContent(),
              ),
              Positioned(
                top: 4,
                right: 4,
                child: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: onClose,
                  iconSize: 20,
                  color: Colors.black54,
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildDetailsContent() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'SHUTTLE DETAILS',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.8,
            color: Colors.black45,
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [
                _buildDetailRow('Vehicle No.', details!.vehicleNumber),
                _buildDetailRow('Destination', details!.destination),
                    _buildDetailRow('Driver Name', details!.driverName),
                    _buildDetailRow('Phone Number', details!.driverPhone),
                _buildDetailRow('Capacity', details!.capacity.toString()),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 14, color: Colors.black87)),
          Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black)),
        ],
      ),
    );
  }
}

// ── Search Bar Widget ──────────────────────────────────────────────────────

class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.controller, required this.onSearch});
  final TextEditingController controller;
  final Function(String) onSearch;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          const SizedBox(width: 14),
          const Icon(Icons.search, color: Colors.black54, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              onSubmitted: onSearch,
              style: const TextStyle(fontSize: 15, color: Colors.black87),
              decoration: const InputDecoration(
                hintText: 'Where are you going?',
                hintStyle: TextStyle(color: Colors.black38, fontSize: 15),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          // Vertical divider
          Container(
            width: 1,
            height: 24,
            color: Colors.black12,
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: () => onSearch(controller.text),
            child: Icon(Icons.near_me, color: Colors.black.withOpacity(0.7), size: 20),
          ),
          const SizedBox(width: 14),
        ],
      ),
    );
  }
}

// ── Location / Re-center FAB ───────────────────────────────────────────────

class _LocationFab extends StatelessWidget {
  const _LocationFab({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.25),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Icon(
          Icons.my_location_rounded,
          color: Colors.white,
          size: 26,
        ),
      ),
    );
  }
}
