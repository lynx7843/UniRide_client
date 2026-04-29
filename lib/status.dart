import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'home.dart';
import 'schedule.dart';
import 'profile.dart';

void main() => runApp(const UniRideApp());

class UniRideApp extends StatelessWidget {
  const UniRideApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'UniRide',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.black),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: const ShuttleStatusScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

enum ShuttleMode { onRoute, stopped, waiting, traffic, breakDown }

class ShuttleStatusScreen extends StatefulWidget {
  const ShuttleStatusScreen({super.key});

  @override
  State<ShuttleStatusScreen> createState() => _ShuttleStatusScreenState();
}

class _ShuttleStatusScreenState extends State<ShuttleStatusScreen> {
  ShuttleMode _selectedMode = ShuttleMode.onRoute;
  int _selectedNavIndex = 2;
  bool _isUpdating = false;

  final List<_StatusOption> _statusOptions = const [
    _StatusOption(
      mode: ShuttleMode.onRoute,
      label: 'ON ROUTE',
      icon: Icons.check_circle_outline,
    ),
    _StatusOption(
      mode: ShuttleMode.stopped,
      label: 'STOPPED',
      icon: Icons.pause_circle_outline,
    ),
    _StatusOption(
      mode: ShuttleMode.waiting,
      label: 'WAITING',
      icon: Icons.hourglass_empty,
    ),
    _StatusOption(
      mode: ShuttleMode.traffic,
      label: 'TRAFFIC',
      icon: Icons.traffic_outlined,
    ),
    _StatusOption(
      mode: ShuttleMode.breakDown,
      label: 'BREAK DOWN',
      icon: Icons.warning_amber_rounded,
      isBreakdown: true,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _fetchInitialStatus();
  }

  Future<void> _fetchInitialStatus() async {
    setState(() => _isUpdating = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final driverId = prefs.getString('userId') ?? '';
      if (driverId.isEmpty) return;

      final shuttleApiUrl = dotenv.env['SHUTTLE_API'];
      if (shuttleApiUrl == null) return;

      final shuttleRes = await http.get(Uri.parse(shuttleApiUrl));
      if (shuttleRes.statusCode != 200) return;
      
      final dynamic decodedShuttle = jsonDecode(shuttleRes.body);
      final List<dynamic> shuttleData = decodedShuttle is List
          ? decodedShuttle
          : (decodedShuttle['Items'] ?? decodedShuttle['items'] ?? []);
          
      final shuttle = shuttleData.firstWhere(
        (s) => s['driverId']?.toString() == driverId,
        orElse: () => null,
      );

      if (shuttle == null) return;

      final shuttleId = shuttle['shuttleId']?.toString();
      if (shuttleId == null || shuttleId.isEmpty) return;

      final getStatusApiUrl = dotenv.env['GetShuttleStatus_API'];
      if (getStatusApiUrl == null) return;

      final statusRes = await http.get(Uri.parse('$getStatusApiUrl?shuttleId=$shuttleId'));
      if (statusRes.statusCode == 200) {
        final dynamic statusData = jsonDecode(statusRes.body);
        final String statusStr = statusData['status']?.toString().toLowerCase() ?? '';
        
        ShuttleMode fetchedMode = ShuttleMode.onRoute; // default fallback
        if (statusStr == 'stopped' || statusStr == 'offline') fetchedMode = ShuttleMode.stopped;
        else if (statusStr == 'waiting') fetchedMode = ShuttleMode.waiting;
        else if (statusStr == 'traffic') fetchedMode = ShuttleMode.traffic;
        else if (statusStr == 'break down') fetchedMode = ShuttleMode.breakDown;
        
        if (mounted) {
          setState(() => _selectedMode = fetchedMode);
        }
      }
    } catch (e) {
      debugPrint('Error fetching initial status: $e');
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  Future<void> _updateStatusAPI(ShuttleMode mode, String label) async {
    setState(() => _isUpdating = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final driverId = prefs.getString('userId') ?? '';
      if (driverId.isEmpty) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Driver ID not found. Please log in again.')));
        return;
      }

      final shuttleApiUrl = dotenv.env['SHUTTLE_API'];
      if (shuttleApiUrl == null) throw Exception('SHUTTLE_API not found in .env');

      final shuttleRes = await http.get(Uri.parse(shuttleApiUrl));
      if (shuttleRes.statusCode != 200) throw Exception('Failed to fetch shuttles');
      
      final dynamic decodedShuttle = jsonDecode(shuttleRes.body);
      final List<dynamic> shuttleData = decodedShuttle is List
          ? decodedShuttle
          : (decodedShuttle['Items'] ?? decodedShuttle['items'] ?? []);
          
      final shuttle = shuttleData.firstWhere(
        (s) => s['driverId']?.toString() == driverId,
        orElse: () => null,
      );

      if (shuttle == null) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No shuttle assigned to this driver.')));
        return;
      }

      final shuttleId = shuttle['shuttleId']?.toString();
      if (shuttleId == null || shuttleId.isEmpty) throw Exception('Shuttle ID is missing.');

      final updateApiUrl = dotenv.env['UpdateShuttleStatus_API'];
      if (updateApiUrl == null) throw Exception('UpdateShuttleStatus_API not found in .env');

      String formattedStatus = label;
      if (mode == ShuttleMode.onRoute) formattedStatus = 'On Route';
      else if (mode == ShuttleMode.stopped) formattedStatus = 'Stopped';
      else if (mode == ShuttleMode.waiting) formattedStatus = 'Waiting';
      else if (mode == ShuttleMode.traffic) formattedStatus = 'Traffic';
      else if (mode == ShuttleMode.breakDown) formattedStatus = 'Break Down';

      final response = await http.post(
        Uri.parse(updateApiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'shuttleId': shuttleId,
          'status': formattedStatus,
        }),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Status updated to $formattedStatus')));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update status: ${response.body}')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F2),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        automaticallyImplyLeading: false,
        title: const Text(
          'SHUTTLE STATUS',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 15,
            letterSpacing: 1.2,
            color: Colors.black,
          ),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            color: Colors.white,
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'UPDATE LIVE STATE',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 1.4,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'SHUTTLE\nSTATUS',
                      style: TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.w900,
                        height: 1.0,
                        letterSpacing: -0.5,
                        color: Colors.black,
                      ),
                    ),
                    if (_isUpdating)
                      const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2.5),
                      ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Status Options
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _statusOptions.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final option = _statusOptions[index];
                final isSelected = _selectedMode == option.mode;
                return _StatusTile(
                  option: option,
                  isSelected: isSelected,
                  onTap: () {
                    if (_isUpdating) return;
                    setState(() => _selectedMode = option.mode);
                    _updateStatusAPI(option.mode, option.label);
                  },
                );
              },
            ),
          ),

          // Shift Log Footer
          Container(
            color: Colors.white,
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Text(
              'SHIFT LOG: 06:42 AM — PRESENT',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                letterSpacing: 1.1,
                color: Colors.grey[600],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedNavIndex,
        onTap: (i) {
          if (i == _selectedNavIndex) return;
          if (i == 0) {
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const HomeScreen()));
          } else if (i == 1) {
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const ScheduleScreen()));
          } else if (i == 2) {
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const ShuttleStatusScreen()));
          } else if (i == 3) {
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const ProfileScreen()));
          }
        },
        backgroundColor: Colors.white,
        selectedItemColor: Colors.black,
        unselectedItemColor: Colors.grey[500],
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
        type: BottomNavigationBarType.fixed,
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

class _StatusOption {
  final ShuttleMode mode;
  final String label;
  final IconData icon;
  final bool isBreakdown;

  const _StatusOption({
    required this.mode,
    required this.label,
    required this.icon,
    this.isBreakdown = false,
  });
}

class _StatusTile extends StatelessWidget {
  final _StatusOption option;
  final bool isSelected;
  final VoidCallback onTap;

  const _StatusTile({
    required this.option,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color bgColor = isSelected ? Colors.black : Colors.white;
    final Color textColor = isSelected
        ? Colors.white
        : option.isBreakdown
            ? const Color(0xFFCC2200)
            : Colors.black;
    final Color iconColor = isSelected
        ? Colors.white
        : option.isBreakdown
            ? const Color(0xFFCC2200)
            : Colors.grey[400]!;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  )
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  )
                ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              option.label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
                color: textColor,
              ),
            ),
            Icon(option.icon, color: iconColor, size: 26),
          ],
        ),
      ),
    );
  }
}