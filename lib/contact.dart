// ─────────────────────────────────────────────────────────────
//  UniRide – Contact Screen
//
//  Dependencies (add to pubspec.yaml):
//    flutter:
//      sdk: flutter
//    url_launcher: ^6.2.6
//
//  The transit station image is loaded from a free Unsplash URL.
//  Replace with a local asset if preferred:
//    Image.asset('assets/images/transit_station.jpg', ...)
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

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
        fontFamily: 'serif',
      ),
      home: const ContactScreen(),
    );
  }
}

// ── Contact Screen ─────────────────────────────────────────────────────────

class ContactScreen extends StatefulWidget {
  const ContactScreen({super.key});

  @override
  State<ContactScreen> createState() => _ContactScreenState();
}

class _ContactScreenState extends State<ContactScreen> {
  // ── Helpers ──────────────────────────────────────────────────────────────

  Future<void> _launchPhone(String number) async {
    final uri = Uri(scheme: 'tel', path: number.replaceAll(' ', ''));
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _launchEmail(String email) async {
    final uri = Uri(scheme: 'mailto', path: email);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$text copied to clipboard'),
        duration: const Duration(seconds: 2),
        backgroundColor: Colors.black,
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F5F5),
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: const BackButton(color: Colors.black),
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── About Us ────────────────────────────────────────────────────
            const SizedBox(height: 12),
            const Text(
              'ABOUT US',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.8,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'UniRide provides precision-engineered shuttle solutions for the modern academic environment. '
              'Our service bridges the gap between administrative logistical data and real-time student '
              'mobility, ensuring seamless transitions across the university infrastructure.',
              style: TextStyle(
                fontSize: 14.5,
                color: Colors.black87,
                height: 1.65,
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'By prioritizing reliability and transparent scheduling, we minimize transit friction, '
              'allowing the campus community to focus on excellence. Every route is optimized for '
              'efficiency, reflecting our commitment to sustainable and accessible transportation.',
              style: TextStyle(
                fontSize: 14.5,
                color: Colors.black87,
                height: 1.65,
              ),
            ),
            const SizedBox(height: 28),

            // ── Transit Station Image ────────────────────────────────────────
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                'https://images.unsplash.com/photo-1541336032412-2048a678540d'
                '?w=800&q=80&auto=format&fit=crop',
                width: double.infinity,
                height: 200,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return Container(
                    width: double.infinity,
                    height: 200,
                    color: Colors.black12,
                    child: const Center(
                      child: CircularProgressIndicator(color: Colors.black),
                    ),
                  );
                },
                errorBuilder: (_, __, ___) => Container(
                  width: double.infinity,
                  height: 200,
                  color: Colors.black12,
                  child: const Icon(Icons.image_not_supported,
                      color: Colors.black38, size: 48),
                ),
              ),
            ),
            const SizedBox(height: 32),

            // ── Contact Details ──────────────────────────────────────────────
            const Text(
              'CONTACT DETAILS',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.8,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 16),

            // Dispatch Office
            _ContactRow(
              icon: Icons.phone_outlined,
              label: 'DISPATCH OFFICE',
              value: '+94 11 234 5678',
              trailingIcon: Icons.north_east_rounded,
              onTap: () => _launchPhone('+94112345678'),
            ),
            _divider(),

            // Student Liaison
            _ContactRow(
              icon: Icons.support_agent_outlined,
              label: 'STUDENT LIAISON',
              value: '+94 77 722 6389',
              trailingIcon: Icons.north_east_rounded,
              onTap: () => _launchPhone('+94777226389'),
            ),
            _divider(),

            // After Hours Support
            _ContactRow(
              icon: Icons.emergency_outlined,
              label: 'AFTER HOURS SUPPORT',
              value: '+94 72 345 6789',
              trailingIcon: Icons.north_east_rounded,
              onTap: () => _launchPhone('+94723456789'),
            ),
            _divider(),

            // General Inquiries (email + copy button)
            _ContactRow(
              icon: Icons.mail_outline_rounded,
              label: 'GENERAL INQUIRIES',
              value: 'transit@university.edu',
              trailingIcon: Icons.copy_rounded,
              onTap: () => _launchEmail('uniride@nsbm.ac.lk'),
              onTrailingTap: () => _copyToClipboard('uniride@nsbm.ac.lk'),
            ),
            const SizedBox(height: 16),

            // ── Service Feedback banner ──────────────────────────────────────
            GestureDetector(
              onTap: () => _launchUrl('https://https://www.nsbm.ac.lk/'),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 18),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'SERVICE FEEDBACK',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.4,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Complaint Web Form',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.chat_bubble_outline_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),

            // ── Quote ────────────────────────────────────────────────────────
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 3,
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Text(
                      '"Find Greatness in Every Step."',
                      style: TextStyle(
                        fontSize: 14,
                        fontStyle: FontStyle.italic,
                        color: Colors.black87,
                        height: 1.55,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _divider() => const Divider(height: 1, color: Color(0xFFDDDDDD));
}

// ── Contact Row ────────────────────────────────────────────────────────────

class _ContactRow extends StatelessWidget {
  const _ContactRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.trailingIcon,
    required this.onTap,
    this.onTrailingTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final IconData trailingIcon;
  final VoidCallback onTap;
  final VoidCallback? onTrailingTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            // Leading icon
            Icon(icon, size: 22, color: Colors.black54),
            const SizedBox(width: 16),

            // Label + value
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                      color: Colors.black45,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Colors.black,
                    ),
                  ),
                ],
              ),
            ),

            // Trailing icon (tap separately if onTrailingTap provided)
            GestureDetector(
              onTap: onTrailingTap ?? onTap,
              child: Container(
                padding: const EdgeInsets.all(4),
                child: Icon(trailingIcon, size: 20, color: Colors.black54),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
