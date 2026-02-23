import 'package:flutter/material.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _api = ApiService();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please fill all fields')));
      return;
    }

    setState(() => _isLoading = true);

    final result = await _api.loginUser(email, password);

    setState(() => _isLoading = false);

    if (result != null && result['status'] == 'success') {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('api_token', result['token']);

      if (result['user'] != null) {
        await prefs.setString('user_name', result['user']['name']);
        await prefs.setString('user_email', result['user']['email']);
        await prefs.setString('user_role', result['user']['role']);
        await prefs.setString('user_region', result['user']['region']);
        await prefs.setString('user_id', result['user']['id']);
      }
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/dashboard');
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result?['message'] ?? 'Login Failed. Try again.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 40),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.shield_outlined,
                  size: 48,
                  color: Color(0xFFE65C00),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'AURA',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1B2333),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'ADAPTIVE UNCERTAINTY & RESILIENCE',
                style: TextStyle(
                  fontSize: 12,
                  letterSpacing: 1.5,
                  color: Color(0xFF8C98A8),
                ),
              ),
              const SizedBox(height: 48),

              // Email Field
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'EMAIL ADDRESS',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF6B7A8F),
                    letterSpacing: 1,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  hintText: 'user@example.com',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 24),

              // Password Field
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'PASSWORD',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF6B7A8F),
                    letterSpacing: 1,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  hintText: '••••••••',
                  prefixIcon: Icon(Icons.lock_outline),
                  suffixIcon: Icon(Icons.visibility_outlined),
                ),
              ),
              const SizedBox(height: 12),

              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {},
                  child: const Text(
                    'Forgot Password?',
                    style: TextStyle(color: Color(0xFF8C98A8)),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Sign In Button
              ElevatedButton(
                onPressed: _isLoading ? null : _handleLogin,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 56),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Sign In'),
              ),

              const SizedBox(height: 32),
              Row(
                children: [
                  const Expanded(child: Divider(color: Color(0xFFE5E7EB))),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'OR CONTINUE WITH',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade400,
                      ),
                    ),
                  ),
                  const Expanded(child: Divider(color: Color(0xFFE5E7EB))),
                ],
              ),
              const SizedBox(height: 32),

              // Guest Button
              OutlinedButton(
                onPressed: () =>
                    Navigator.pushReplacementNamed(context, '/dashboard'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  side: const BorderSide(color: Color(0xFFE5E7EB)),
                  backgroundColor: Colors.white,
                ),
                child: const Text(
                  'Continue as\nGuest',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF1B2333)),
                ),
              ),
              const SizedBox(height: 40),

              // Create Account
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'New to Aura? ',
                    style: TextStyle(color: Color(0xFF6B7A8F)),
                  ),
                  GestureDetector(
                    onTap: () {},
                    child: const Text(
                      'Create Account',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1B2333),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
