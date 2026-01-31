import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../theme/ayu_theme.dart';
import '../api/api_config.dart';
import 'onboarding_screen.dart';
import 'login_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passController = TextEditingController();
  bool _isLoading = false;

  Future<void> _handleRegister() async {
    if (_phoneController.text.isEmpty || _passController.text.isEmpty) return;
    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse(ApiConfig.register),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "fullname": _nameController.text,
          "phone": _phoneController.text,
          "password": _passController.text,
        }),
      );

      if (response.statusCode == 200) {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (c) => OnboardingScreen(userPhone: _phoneController.text)),
          );
        }
      } else if (response.statusCode == 400) {
        _showError("Phone already exists. Please login.");
      }
    } catch (e) {
      _showError("Server Connection Failed");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AyuTheme.primaryGradient),
        child: Padding(
          padding: const EdgeInsets.all(30.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.spa_outlined, size: 80, color: Colors.white),
              const Text("AYU-EAT", style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
              const SizedBox(height: 30),
              _buildField(_nameController, "Full Name", Icons.person),
              const SizedBox(height: 10),
              _buildField(_phoneController, "Phone", Icons.phone, isPhone: true),
              const SizedBox(height: 10),
              _buildField(_passController, "Password", Icons.lock, isPass: true),
              const SizedBox(height: 20),
              _isLoading 
                ? const CircularProgressIndicator(color: Colors.white)
                : ElevatedButton(onPressed: _handleRegister, child: const Text("REGISTER")),
              TextButton(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const LoginScreen())),
                child: const Text("Already have an account? Login", style: TextStyle(color: Colors.white70)),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField(TextEditingController ctrl, String hint, IconData icon, {bool isPass = false, bool isPhone = false}) {
    return TextField(
      controller: ctrl,
      obscureText: isPass,
      keyboardType: isPhone ? TextInputType.phone : TextInputType.text,
      decoration: InputDecoration(filled: true, fillColor: Colors.white, hintText: hint, prefixIcon: Icon(icon, color: AyuTheme.darkGreen)),
    );
  }
}