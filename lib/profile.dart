// ─────────────────────────────────────────────────────────────
//  UniRide – Profile Screen
// ─────────────────────────────────────────────────────────────

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'home.dart';
import 'schedule.dart';
import 'contact.dart';
import 'signin.dart';
import 'edit_profile.dart';

void main() => runApp(const UniRideApp());

class UniRideApp extends StatelessWidget {
  const UniRideApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'UniRide Client',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.black),
        useMaterial3: true,
      ),
      home: const ProfileScreen(),
    );
  }
}

// ── Profile Screen ─────────────────────────────────────────────────────────

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  int _currentIndex = 2; // PROFILE tab active
  bool _isLoading = true;
  String _errorMessage = '';
  String _userName = 'Loading...';
  String _userId = '...';
  String _email = 'Update contact and personal info';
  String _licenseNumber = '...';
  String _nic = '...';
  String _phoneNumber = '...';

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('userId') ?? '';

      final driverApiUrl = dotenv.env['DRIVER_API'];
      if (driverApiUrl != null && driverApiUrl.isNotEmpty && userId.isNotEmpty) {
        final response = await http.get(Uri.parse(driverApiUrl));
        if (response.statusCode == 200) {
          final dynamic decoded = jsonDecode(response.body);
          final List<dynamic> driverData = decoded is List
              ? decoded
              : (decoded['Items'] ?? decoded['items'] ?? []);

          final driverInfo = driverData.firstWhere(
            (d) => d['driverId']?.toString() == userId,
            orElse: () => null,
          );

          if (driverInfo != null) {
            if (mounted) {
              setState(() {
                _userName = driverInfo['driverName']?.toString() ?? 'Unknown User';
                _userId = driverInfo['driverId']?.toString() ?? 'N/A';
                _email = driverInfo['email']?.toString() ?? 'N/A';
                _licenseNumber = driverInfo['licenseNumber']?.toString() ?? 'N/A';
                _nic = driverInfo['nic']?.toString() ?? 'N/A';
                _phoneNumber = driverInfo['phoneNumber']?.toString() ?? 'N/A';
                _isLoading = false;
              });
            }
            return;
          }
        }
      }

      if (mounted) {
        setState(() {
          _userName = prefs.getString('userName') ?? 'Unknown User';
          _userId = userId.isEmpty ? 'N/A' : userId;
          _email = prefs.getString('userEmail') ?? 'Update contact and personal info';
          _licenseNumber = prefs.getString('licenseNumber') ?? 'N/A';
          _nic = prefs.getString('nic') ?? 'N/A';
          _phoneNumber = prefs.getString('userPhone') ?? 'N/A';
          _isLoading = false;
        });
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

  void _onMenuTap(String item) {
    if (item == 'Edit Profile') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const EditProfileScreen()),
      );
    } else if (item == 'About Us') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const ContactScreen()),
      );
    } else {
      debugPrint('$item tapped');
    }
  }

  void _onLogout() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text(
          'Log Out',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel',
                style: TextStyle(color: Colors.black54)),
          ),
          TextButton(
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.clear();

              if (!context.mounted) return;
              Navigator.pop(context);
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const SignInScreen()),
              );
            },
            child: const Text('Log Out',
                style: TextStyle(
                    color: Colors.red, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
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
        centerTitle: true,
        title: const Text(
          'UNIRIDE',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            letterSpacing: 2.5,
            color: Colors.black,
          ),
        ),
      ),

      // ── Body ───────────────────────────────────────────────────────────
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 32),

            // ── Avatar ──────────────────────────────────────────────────
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: const Color(0xFF3D6B74),
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Teal gradient background
                    Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0xFF4A8A96), Color(0xFF2D5F6A)],
                        ),
                      ),
                    ),
                    // Avatar illustration placeholder
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Head
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFD5B0),
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: Colors.white.withOpacity(0.3),
                                width: 1),
                          ),
                          child: const Icon(Icons.person,
                              color: Color(0xFF5A3E28), size: 32),
                        ),
                        const SizedBox(height: 4),
                        // Shirt/body
                        Container(
                          width: 60,
                          height: 28,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A1A2E),
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(30),
                              topRight: Radius.circular(30),
                            ),
                          ),
                          child: Center(
                            child: Container(
                              width: 6,
                              height: 16,
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    // Bottom label bar
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        color: Colors.black.withOpacity(0.45),
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: const Text(
                          'SAFE VEHICLE • DRIVER PROFILE',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 5.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // ── Name ────────────────────────────────────────────────────
            if (_errorMessage.isNotEmpty)
              Padding(padding: const EdgeInsets.only(bottom: 8), child: Text('Error: $_errorMessage', style: const TextStyle(color: Colors.red, fontSize: 12))),
            Text(
              _userName,
              style: const TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w800,
                color: Colors.black,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: 6),

            // ── Driver Details ──────────────────────────────────────────
            Text(
              'DRIVER ID: $_userId',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.4,
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'LICENSE: $_licenseNumber  •  NIC: $_nic',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.0,
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'PHONE: $_phoneNumber',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.0,
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 36),

            // ── Menu items card ─────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    _ProfileMenuItem(
                      icon: Icons.edit_outlined,
                      title: 'EDIT PROFILE',
                      subtitle: _email,
                      onTap: () => _onMenuTap('Edit Profile'),
                      showDivider: true,
                    ),
                    _ProfileMenuItem(
                      icon: Icons.info_outline,
                      title: 'ABOUT US',
                      subtitle: 'Learn more about UniRide',
                      onTap: () => _onMenuTap('About Us'),
                      showDivider: false,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ── Divider ─────────────────────────────────────────────────
            const Divider(
              height: 1,
              color: Color(0xFFDDDDDD),
              indent: 20,
              endIndent: 20,
            ),
            const SizedBox(height: 16),

            // ── Log Out ─────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: InkWell(
                onTap: _onLogout,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.logout_rounded,
                          color: Colors.red,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'LOG OUT',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.2,
                              color: Colors.red,
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            'Securely sign out of your account',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.black45,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 48),

            // ── Version footer ──────────────────────────────────────────
            const Text(
              'V 4.2.0 - S T A B L E  |  C A M P U S  O P S',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w500,
                letterSpacing: 1.0,
                color: Colors.black26,
              ),
            ),
            const SizedBox(height: 28),
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
            // Already in profile
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
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'PROFILE',
          ),
        ],
      ),
    );
  }
}

// ── Profile Menu Item ──────────────────────────────────────────────────────

class _ProfileMenuItem extends StatelessWidget {
  const _ProfileMenuItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.showDivider,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                // Icon box
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEEEEE),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 22, color: Colors.black),
                ),
                const SizedBox(width: 16),
                // Text
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.black45,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.black38,
                  size: 22,
                ),
              ],
            ),
          ),
        ),
        if (showDivider)
          const Divider(
            height: 1,
            color: Color(0xFFEEEEEE),
            indent: 76,
            endIndent: 16,
          ),
      ],
    );
  }
}
