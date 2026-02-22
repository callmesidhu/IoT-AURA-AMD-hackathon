import 'package:flutter/material.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Simulate loading and navigate to login
    Future.delayed(const Duration(seconds: 2), () {
      Navigator.pushReplacementNamed(context, '/login');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: const Icon(
                Icons.shield_outlined, // Placeholder for the actual logo asset
                size: 64,
                color: Color(0xFFE65C00), // Orange shield color
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'A U R A',
              style: TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.w400,
                letterSpacing: 8,
                color: Color(0xFF1B2333),
              ),
            ),
            const SizedBox(height: 16),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 40),
              child: Divider(color: Color(0xFFE5E7EB)),
            ),
            const SizedBox(height: 16),
            const Text(
              'ADAPTIVE UNCERTAINTY &\nRESILIENCE\nARCHITECTURE',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                fontWeight: FontWeight.w500,
                letterSpacing: 1.2,
                color: Color(0xFF6B7280),
              ),
            ),
            const Spacer(),
            const Text(
              'V2.0.0 • SYSTEM SECURE',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 1,
                color: Color(0xFF9CA3AF),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
