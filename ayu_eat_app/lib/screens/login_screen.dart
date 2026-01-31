import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../theme/ayu_theme.dart';
import '../api/api_config.dart';
import 'onboarding_screen.dart';
import 'dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneController = TextEditingController();
  final _passController = TextEditingController();
  bool _isLoading = false;

  Future<void> _handleLogin() async {
  if (_phoneController.text.isEmpty || _passController.text.isEmpty) {
    _showSnack("Please enter credentials");
    return;
  }

  setState(() => _isLoading = true);
  try {
    debugPrint("🚀 Initiating Login for: ${_phoneController.text}");
    
    final response = await http.post(
      Uri.parse(ApiConfig.login),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"phone": _phoneController.text, "password": _passController.text}),
    ).timeout(const Duration(seconds: 10));

    debugPrint("📥 Login Response: ${response.statusCode}");

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (!mounted) return;

      if (data['prakriti_done'] == true) {
        Navigator.pushReplacement(
          context, 
          MaterialPageRoute(builder: (c) => DashboardScreen(userPhone: _phoneController.text))
        );
      } else {
        Navigator.pushReplacement(
          context, 
          MaterialPageRoute(builder: (c) => OnboardingScreen(userPhone: _phoneController.text))
        );
      }
    } else {
      _showSnack("Login Failed: ${response.statusCode}");
    }
  } catch (e) {
    debugPrint("❌ Login Error: $e");
    _showSnack("Connection Error: Check if server is running at ${ApiConfig.baseUrl}");
  } finally {
    if (mounted) setState(() => _isLoading = false);
  }
}

void _showSnack(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(gradient: AyuTheme.primaryGradient),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text("Login", style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
            const SizedBox(height: 30),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Column(
                children: [
                  TextField(controller: _phoneController, decoration: const InputDecoration(filled: true, fillColor: Colors.white, hintText: "Phone")),
                  const SizedBox(height: 10),
                  TextField(controller: _passController, obscureText: true, decoration: const InputDecoration(filled: true, fillColor: Colors.white, hintText: "Password")),
                  const SizedBox(height: 20),
                  _isLoading ? const CircularProgressIndicator() : ElevatedButton(onPressed: _handleLogin, child: const Text("LOGIN")),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}