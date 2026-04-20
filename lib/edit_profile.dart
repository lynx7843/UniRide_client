import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const CampusTransitApp());
}

class CampusTransitApp extends StatelessWidget {
  const CampusTransitApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'UNIRIDE Client',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.black),
        useMaterial3: true,
        fontFamily: 'SF Pro Display',
      ),
      home: const EditProfileScreen(),
    );
  }
}

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  int _currentIndex = 2;

  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _currentPasswordController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  bool _isLoading = false;

  bool _checkPasswordsMatch() {
    return _passwordController.text == _confirmPasswordController.text;
  }

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _fullNameController.text = prefs.getString('userName') ?? '';
        _emailController.text = prefs.getString('userEmail') ?? '';
        _phoneController.text = prefs.getString('userPhone') ?? '';
      });
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _currentPasswordController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _onUpdateProfilePressed() async {
    final name = _fullNameController.text.trim();
    final phone = _phoneController.text.trim();
    final currentPassword = _currentPasswordController.text;
    final newPassword = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (name.isEmpty || phone.isEmpty || currentPassword.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all required fields (Current Password is required).')),
      );
      return;
    }

    if (newPassword.isNotEmpty && newPassword != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('New passwords do not match.')),
      );
      return;
    }

    final updateApiUrl = dotenv.env['Update_Profile_API'];
    if (updateApiUrl == null || updateApiUrl.isEmpty) {
      debugPrint('Error: Update_Profile_API is not defined in .env');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      // Fallback securely to the logged-in email from preferences
      final email = prefs.getString('userEmail') ?? _emailController.text.trim();

      final requestBody = {
        'email': email,
        'currentPassword': currentPassword,
        'name': name,
        'phone': phone,
      };
      if (newPassword.isNotEmpty) {
        requestBody['password'] = newPassword;
      }

      final response = await http.post(
        Uri.parse(updateApiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        // Update the locally cached user data
        await prefs.setString('userName', name);
        await prefs.setString('userPhone', phone);
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully!')),
        );
        
        _currentPasswordController.clear();
        _passwordController.clear();
        _confirmPasswordController.clear();
      } else {
        final decoded = jsonDecode(response.body);
        final message = decoded['message'] ?? 'Failed to update profile.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error connecting to server: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: _buildAppBar(),
      body: _buildBody(),
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFFF5F5F5),
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.black, size: 24),
        onPressed: () => Navigator.of(context).maybePop(),
      ),
      title: const Text(
        'UNIRIDE CLIENT',
        style: TextStyle(
          color: Colors.black,
          fontSize: 18,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
        ),
      ),
      centerTitle: false,
      titleSpacing: 0,
    );
  }

  Widget _buildBody() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 24),
          _buildAvatarSection(),
          const SizedBox(height: 20),
          _buildProfileTitle(),
          const SizedBox(height: 32),
          _buildFormField(
            label: 'FULL NAME',
            controller: _fullNameController,
            hintText: 'Dilan Amantha',
          ),
          const SizedBox(height: 20),
          _buildFormField(
            label: 'EMAIL',
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            hintText: 'dilan.amantha@nsbm.ac.lk',
            enabled: false, // Ensures users do not edit the email representing the Partition Key
          ),
          const SizedBox(height: 20),
          _buildFormField(
            label: 'PHONE NUMBER',
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            hintText: '+94 71 123 4567',
          ),
          const SizedBox(height: 20),
          _buildFormField(
            label: 'CURRENT PASSWORD',
            controller: _currentPasswordController,
            obscureText: true,
            hintText: '••••••••',
          ),
          const SizedBox(height: 20),
          _buildFormField(
            label: 'NEW PASSWORD',
            controller: _passwordController,
            obscureText: true,
            hintText: '••••••••',
          ),
          const SizedBox(height: 20),
          _buildFormField(
            label: 'CONFIRM NEW PASSWORD',
            controller: _confirmPasswordController,
            obscureText: true,
            hintText: '••••••••',
          ),
          const SizedBox(height: 32),
          _buildUpdateButton(),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildAvatarSection() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 110,
          height: 110,
          decoration: BoxDecoration(
            color: const Color(0xFF2C2C2C),
            borderRadius: BorderRadius.circular(12),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: _buildAvatarPlaceholder(),
          ),
        ),
        Positioned(
          bottom: -8,
          right: -8,
          child: GestureDetector(
            onTap: () {
              // Handle photo upload
            },
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.camera_alt,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAvatarPlaceholder() {
    return CustomPaint(
      painter: _AvatarPainter(),
      child: const SizedBox(width: 110, height: 110),
    );
  }

  Widget _buildProfileTitle() {
    return Column(
      children: [
        const Text(
          'Edit Profile',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: Colors.black,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'PERSONAL CREDENTIALS',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.grey[500],
            letterSpacing: 1.8,
          ),
        ),
      ],
    );
  }

  Widget _buildUpdateButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _onUpdateProfilePressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: _isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.5,
                ),
              )
            : const Text(
                'UPDATE PROFILE',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2.0,
                ),
              ),
      ),
    );
  }

  Widget _buildFormField({
    required String label,
    required TextEditingController controller,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    bool obscureText = false,
    String? hintText,
    bool enabled = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Colors.grey[600],
            letterSpacing: 1.4,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          obscureText: obscureText,
          enabled: enabled,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w400,
            color: Colors.black87,
          ),
          decoration: InputDecoration(
          hintText: hintText,
          hintStyle: const TextStyle(color: Colors.black38, fontSize: 15),
            filled: true,
            fillColor: const Color(0xFFEEEEEE),
            contentPadding: EdgeInsets.symmetric(
              horizontal: 16,
              vertical: maxLines > 1 ? 14 : 16,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.black, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomNavBar() {
    final items = [
      _NavItem(icon: Icons.home_outlined, activeIcon: Icons.home, label: 'HOME'),
      _NavItem(
          icon: Icons.calendar_today_outlined,
          activeIcon: Icons.calendar_today,
          label: 'SCHEDULE'),
      _NavItem(
          icon: Icons.person_outline,
          activeIcon: Icons.person,
          label: 'PROFILE'),
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(items.length, (index) {
              final item = items[index];
              final isActive = _currentIndex == index;
              return GestureDetector(
                onTap: () => setState(() => _currentIndex = index),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 6),
                  decoration: isActive
                      ? BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(10),
                        )
                      : null,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isActive ? item.activeIcon : item.icon,
                        color: isActive ? Colors.black : Colors.grey[500],
                        size: 24,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.label,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: isActive
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: isActive ? Colors.black : Colors.grey[500],
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}

/// Custom painter to draw a simple avatar (suit + face) inside the profile box
class _AvatarPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFF3A3A3A);

    // Background already handled by container color

    // Head
    final headPaint = Paint()..color = const Color(0xFFBDBDBD);
    canvas.drawCircle(
      Offset(size.width / 2, size.height * 0.35),
      size.width * 0.18,
      headPaint,
    );

    // Neck
    final neckRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(size.width / 2, size.height * 0.54),
        width: size.width * 0.14,
        height: size.height * 0.1,
      ),
      const Radius.circular(4),
    );
    canvas.drawRRect(neckRect, headPaint);

    // Suit body
    final suitPaint = Paint()..color = const Color(0xFF1E1E1E);
    final suitPath = Path()
      ..moveTo(size.width * 0.2, size.height)
      ..lineTo(size.width * 0.2, size.height * 0.65)
      ..lineTo(size.width * 0.38, size.height * 0.6)
      ..lineTo(size.width / 2, size.height * 0.62)
      ..lineTo(size.width * 0.62, size.height * 0.6)
      ..lineTo(size.width * 0.8, size.height * 0.65)
      ..lineTo(size.width * 0.8, size.height)
      ..close();
    canvas.drawPath(suitPath, suitPaint);

    // White shirt
    final shirtPaint = Paint()..color = const Color(0xFFE0E0E0);
    final shirtPath = Path()
      ..moveTo(size.width * 0.43, size.height * 0.6)
      ..lineTo(size.width / 2, size.height * 0.63)
      ..lineTo(size.width * 0.57, size.height * 0.6)
      ..lineTo(size.width * 0.55, size.height)
      ..lineTo(size.width * 0.45, size.height)
      ..close();
    canvas.drawPath(shirtPath, shirtPaint);

    // Tie
    final tiePaint = Paint()..color = const Color(0xFF424242);
    final tiePath = Path()
      ..moveTo(size.width / 2 - 5, size.height * 0.62)
      ..lineTo(size.width / 2 + 5, size.height * 0.62)
      ..lineTo(size.width / 2 + 7, size.height * 0.78)
      ..lineTo(size.width / 2, size.height * 0.82)
      ..lineTo(size.width / 2 - 7, size.height * 0.78)
      ..close();
    canvas.drawPath(tiePath, tiePaint);

    // Left lapel
    final lapelPath = Path()
      ..moveTo(size.width * 0.38, size.height * 0.6)
      ..lineTo(size.width * 0.43, size.height * 0.6)
      ..lineTo(size.width * 0.35, size.height * 0.74)
      ..lineTo(size.width * 0.28, size.height * 0.7)
      ..close();
    canvas.drawPath(lapelPath, suitPaint);

    // Right lapel
    final rLapelPath = Path()
      ..moveTo(size.width * 0.62, size.height * 0.6)
      ..lineTo(size.width * 0.57, size.height * 0.6)
      ..lineTo(size.width * 0.65, size.height * 0.74)
      ..lineTo(size.width * 0.72, size.height * 0.7)
      ..close();
    canvas.drawPath(rLapelPath, suitPaint);

    // Eyes
    final eyePaint = Paint()..color = const Color(0xFF616161);
    canvas.drawCircle(
        Offset(size.width * 0.44, size.height * 0.33), 2.5, eyePaint);
    canvas.drawCircle(
        Offset(size.width * 0.56, size.height * 0.33), 2.5, eyePaint);

    // Mouth
    final mouthPaint = Paint()
      ..color = const Color(0xFF757575)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(size.width / 2, size.height * 0.37),
        width: 14,
        height: 7,
      ),
      0,
      3.14,
      false,
      mouthPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
