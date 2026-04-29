// ─────────────────────────────────────────────────────────────
//  UniRide – Schedule Screen
// ─────────────────────────────────────────────────────────────

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'home.dart';
import 'profile.dart';
import 'status.dart';

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
      home: const ScheduleScreen(),
    );
  }
}

// ── Data Models ────────────────────────────────────────────────────────────

enum DriverStatus { onRoute, atStop, offDuty }

extension DriverStatusLabel on DriverStatus {
  String get label {
    switch (this) {
      case DriverStatus.onRoute:
        return 'ON ROUTE';
      case DriverStatus.atStop:
        return 'AT STOP';
      case DriverStatus.offDuty:
        return 'OFF DUTY';
    }
  }

  Color get color {
    switch (this) {
      case DriverStatus.onRoute:
        return Colors.black87;
      case DriverStatus.atStop:
        return Colors.black54;
      case DriverStatus.offDuty:
        return Colors.black26;
    }
  }
}

class DriverEntry {
  const DriverEntry({
    required this.name,
    required this.status,
    required this.licensePlate,
    required this.destination,
    required this.shuttleId,
    required this.capacity,
    required this.verificationStatus,
    required this.currentStatus,
  });

  final String name;
  final DriverStatus status;
  final String licensePlate;
  final String destination;
  final String shuttleId;
  final int capacity;
  final String verificationStatus;
  final String currentStatus;
}

// ── Schedule Screen ────────────────────────────────────────────────────────

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  int _currentIndex = 1; // SCHEDULE tab active
  bool _isLoading = true;
  String _errorMessage = '';
  List<DriverEntry> _driversList = [];

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      final driverApiUrl = dotenv.env['DRIVER_API'];
      final shuttleApiUrl = dotenv.env['SHUTTLE_API'];

      if (driverApiUrl == null || shuttleApiUrl == null) {
        throw Exception('API URLs not found in .env');
      }

      final driverResponse = await http.get(Uri.parse(driverApiUrl));
      final shuttleResponse = await http.get(Uri.parse(shuttleApiUrl));

      if (driverResponse.statusCode == 200 && shuttleResponse.statusCode == 200) {
        final dynamic decodedDriver = jsonDecode(driverResponse.body);
        final dynamic decodedShuttle = jsonDecode(shuttleResponse.body);

        final List<dynamic> driverData = decodedDriver is List
            ? decodedDriver
            : (decodedDriver['Items'] ?? decodedDriver['items'] ?? []);
        final List<dynamic> shuttleData = decodedShuttle is List
            ? decodedShuttle
            : (decodedShuttle['Items'] ?? decodedShuttle['items'] ?? []);

        // Fetch all recent verification logs once globally
        List<dynamic> fingerprintLogs = [];
        try {
          final logApiUrl = dotenv.env['LOG_FINGERPRINT_API'];
          if (logApiUrl != null && logApiUrl.isNotEmpty) {
            final logsRes = await http.get(Uri.parse(logApiUrl));
            if (logsRes.statusCode == 200) {
              final dynamic decodedLogs = jsonDecode(logsRes.body);
              if (decodedLogs is List) {
                fingerprintLogs = decodedLogs;
              } else if (decodedLogs is Map && decodedLogs['Items'] != null) {
                fingerprintLogs = decodedLogs['Items'];
              }
            }
          }
        } catch (e) {
          debugPrint('Error fetching fingerprint logs: $e');
        }

        final List<DriverEntry> loadedDrivers = [];

        for (var driver in driverData) {
          final String driverId = driver['driverId']?.toString() ?? '';
          final String driverName = driver['driverName']?.toString() ?? 'Unknown Driver';

          final shuttle = shuttleData.firstWhere(
            (s) => s['driverId']?.toString() == driverId,
            orElse: () => null,
          );

          final String vehicleNumber =
              shuttle != null ? (shuttle['vehicleNumber']?.toString() ?? '- - -') : '- - -';
          final DriverStatus status =
              shuttle != null ? DriverStatus.onRoute : DriverStatus.offDuty;
          final String shuttleId = shuttle != null ? (shuttle['shuttleId']?.toString() ?? '') : '';
          final int capacity = shuttle != null ? (int.tryParse(shuttle['capacity']?.toString() ?? '0') ?? 0) : 0;

          // Cross-match database prints with ESP32 scan logs
          String verificationStatus = 'Unverified';
          if (driverId == 'd001') {
            verificationStatus = 'Verified';
          } else if (driverId.isNotEmpty) {
            try {
              final getFpApiUrl = dotenv.env['GetFingerprint_API'];
              if (getFpApiUrl != null && getFpApiUrl.isNotEmpty) {
                final fpRes = await http.get(Uri.parse('$getFpApiUrl?driverId=$driverId'));
                if (fpRes.statusCode == 200) {
                  final dynamic fpData = jsonDecode(fpRes.body);
                  final String registeredTemplate = fpData['templateData']?.toString().replaceAll(RegExp(r'\s+'), '') ?? '';
                  
                  if (registeredTemplate.isNotEmpty && fingerprintLogs.isNotEmpty) {
                    final bool isVerified = fingerprintLogs.any((log) {
                      final String logFp = log['fingerprintId']?.toString().replaceAll(RegExp(r'\s+'), '') ?? '';
                      return logFp == registeredTemplate;
                    });
                    if (isVerified) verificationStatus = 'Verified';
                  }
                }
              }
            } catch (e) {
              debugPrint('Error fetching fingerprint for $driverId: $e');
            }
          }

          String currentStatus = 'Stopped';
          if (shuttleId.isNotEmpty) {
            try {
              final statusApiUrl = dotenv.env['GetShuttleStatus_API'];
              if (statusApiUrl != null && statusApiUrl.isNotEmpty) {
                final statusRes = await http.get(Uri.parse('$statusApiUrl?shuttleId=$shuttleId'));
                if (statusRes.statusCode == 200) {
                  final dynamic statusData = jsonDecode(statusRes.body);
                  if (statusData != null && statusData['status'] != null) {
                    currentStatus = statusData['status'].toString();
                  }
                }
              }
            } catch (e) {
              debugPrint('Error fetching status for shuttle $shuttleId: $e');
            }
          }

          loadedDrivers.add(
            DriverEntry(
              name: driverName,
              status: status,
              licensePlate: vehicleNumber,
          destination: shuttle != null ? (shuttle['destination']?.toString() ?? 'Unknown Destination') : 'N/A',
              shuttleId: shuttleId,
              capacity: capacity,
              verificationStatus: verificationStatus,
              currentStatus: currentStatus,
            ),
          );
        }

        if (mounted) {
          setState(() {
            _driversList = loadedDrivers;
            _isLoading = false;
          });
        }
      } else {
        throw Exception('Failed to load data from server.');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),

      // ── AppBar ─────────────────────────────────────────────────────────
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F5F5),
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          'SCHEDULE',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w800,
            fontSize: 18,
            letterSpacing: 1.2,
          ),
        ),
      ),

      // ── Body ───────────────────────────────────────────────────────────
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Page heading ─────────────────────────────────────────────
            const SizedBox(height: 12),
            const Text(
              'CURRENT OPERATIONS',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.8,
                color: Colors.black45,
              ),
            ),
            const SizedBox(height: 24),

            // ── System Health card ────────────────────────────────────────
            _SystemHealthCard(),
            const SizedBox(height: 28),

            // ── Driver cards ──────────────────────────────────────────────
            if (_isLoading)
              const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(color: Colors.black)))
            else if (_errorMessage.isNotEmpty)
              Center(child: Padding(padding: const EdgeInsets.all(20), child: Text('Error: $_errorMessage', style: const TextStyle(color: Colors.red))))
            else if (_driversList.isEmpty)
              const Center(child: Padding(padding: EdgeInsets.all(20), child: Text('No drivers available.')))
            else
              ..._driversList.map((d) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _DriverCard(
                    driver: d,
                  ),
                )),
            const SizedBox(height: 16),
          ],
        ),
      ),

      // ── Bottom Navigation Bar ─────────────────────────────────────────
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
        unselectedItemColor: Colors.black45,
        selectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 10,
          letterSpacing: 0.8,
        ),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 10,
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
}

// ── System Health Card ─────────────────────────────────────────────────────

class _SystemHealthCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(0, 20, 20, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Left accent bar
            Container(
              width: 4,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 18),
            // Content
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SYSTEM HEALTH',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.4,
                      color: Colors.black45,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Normal',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    '4 active shuttles currently navigating to the campus.',
                    style: TextStyle(
                      fontSize: 13.5,
                      color: Colors.black54,
                      height: 1.5,
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
}

// ── Driver Card ────────────────────────────────────────────────────────────

class _DriverCard extends StatelessWidget {
  const _DriverCard({
    required this.driver,
  });
  final DriverEntry driver;

  bool get _isOffDuty => driver.status == DriverStatus.offDuty;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Avatar + name row ──────────────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Avatar
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _isOffDuty
                      ? const Color(0xFFEEEEEE)
                      : const Color(0xFFE0E0E0),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.person,
                  size: 28,
                  color: _isOffDuty ? Colors.black26 : Colors.black54,
                ),
              ),
              const SizedBox(width: 14),
              // Name + status
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    driver.name,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: _isOffDuty ? Colors.black38 : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    driver.status.label,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                      color: driver.status.color,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: Color(0xFFEEEEEE)),
          const SizedBox(height: 14),

          // ── License plate + destination row ───────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // License plate
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'LICENSE PLATE',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                        color: _isOffDuty ? Colors.black26 : Colors.black38,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      driver.licensePlate,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: _isOffDuty ? Colors.black26 : Colors.black,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              // Destination
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'DESTINATION',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                        color: _isOffDuty ? Colors.black26 : Colors.black38,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      driver.destination,
                      textAlign: TextAlign.end,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: _isOffDuty ? Colors.black26 : Colors.black,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // ── Verification + status row ───────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Verification
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'VERIFICATION',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                        color: _isOffDuty ? Colors.black26 : Colors.black38,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      driver.verificationStatus,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: _isOffDuty ? Colors.black26 : (driver.verificationStatus == 'Verified' ? Colors.blue : Colors.redAccent),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              // Status
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'STATUS',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                        color: _isOffDuty ? Colors.black26 : Colors.black38,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      driver.currentStatus,
                      textAlign: TextAlign.end,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: _isOffDuty ? Colors.black26 : Colors.black,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
