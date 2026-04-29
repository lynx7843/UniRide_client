import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'home.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  runApp(const UniRideApp());
}

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
        fontFamily: 'sans-serif',
      ),
      home: const SignInScreen(),
    );
  }
}

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _onLoginPressed() async {
    final email = _emailController.text;
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter both email and password.')),
      );
      return;
    }

    final driverApiUrl = dotenv.env['DRIVER_API'];
    if (driverApiUrl == null || driverApiUrl.isEmpty) {
      debugPrint('Error: DRIVER_API is not defined in .env');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Changed from POST to GET to match your other screens' usage
      final response = await http.get(Uri.parse(driverApiUrl));

      if (!mounted) return;

      if (response.statusCode == 200) {
        // Parse the user data from the response and save it locally
        try {
          debugPrint('LOGIN RESPONSE BODY: ${response.body}');
          dynamic decoded = jsonDecode(response.body);

          // AWS API Gateway sometimes wraps the JSON in a stringified "body" property
          if (decoded is Map<String, dynamic> && decoded.containsKey('body') && decoded['body'] is String) {
            decoded = jsonDecode(decoded['body']);
          }

          final List<dynamic> allDrivers = decoded is List
              ? decoded
              : (decoded['Items'] ?? decoded['items'] ?? []);

          final driverData = allDrivers.firstWhere(
            (d) => d['email']?.toString() == email && d['password']?.toString() == password,
            orElse: () => null,
          );

          if (driverData == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Invalid email or password.')),
            );
            setState(() {
              _isLoading = false;
            });
            return;
          }

          debugPrint('PARSED DRIVER DATA: $driverData');

          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('userName', driverData['driverName']?.toString() ?? 'Unknown Driver');
          await prefs.setString('userId', driverData['driverId']?.toString() ?? 'N/A');
          await prefs.setString('userEmail', driverData['email']?.toString() ?? 'N/A');
          await prefs.setString('userPhone', driverData['phoneNumber']?.toString() ?? '');
          await prefs.setString('licenseNumber', driverData['licenseNumber']?.toString() ?? '');
          await prefs.setString('nic', driverData['nic']?.toString() ?? '');
        } catch (e) {
          debugPrint('Error saving user data to SharedPreferences: $e');
        }

        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to fetch data from server.')),
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
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
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
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 80),

                // ── Sign In heading ──
                const Text(
                  'Sign In',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 8),

                // ── Subtitle ──
                const Text(
                  'Access your UniRide client dashboard.',
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.black54,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 40),

                // ── Email Address label ──
                const Text(
                  'EMAIL ADDRESS',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.4,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),

                // ── Email text field ──
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(fontSize: 15, color: Colors.black),
                  decoration: InputDecoration(
                    hintText: 'your@email.com',
                    hintStyle: const TextStyle(
                      color: Colors.black38,
                      fontSize: 15,
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF5F5F5),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 18,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: const BorderSide(
                        color: Colors.black,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // ── Password label ──
                const Text(
                  'PASSWORD',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.4,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),

                // ── Password text field ──
                TextField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  style: const TextStyle(fontSize: 15, color: Colors.black),
                  decoration: InputDecoration(
                    hintText: '••••••••',
                    hintStyle: const TextStyle(
                      color: Colors.black38,
                      fontSize: 18,
                      letterSpacing: 3,
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF5F5F5),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 18,
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: Colors.black45,
                        size: 20,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: const BorderSide(
                        color: Colors.black,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 28),

                // ── Login button ──
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _onLoginPressed,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    child: const Text(
                      'LOGIN',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2.0,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
