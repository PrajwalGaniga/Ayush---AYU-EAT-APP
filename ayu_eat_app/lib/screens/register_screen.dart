import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../theme/ayu_theme.dart';
import '../api/api_config.dart';
import 'onboarding_screen.dart';
import 'login_screen.dart'; // Navigates here for existing users

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
  bool _obscureText = true; // UX: Password visibility toggle

  // --- LOGIC: PRODUCTION-READY HANDLER ---
  Future<void> _handleRegister() async {
    if (_nameController.text.isEmpty || _phoneController.text.isEmpty || _passController.text.isEmpty) {
      _showError("Please fill all fields to begin your journey.");
      return;
    }

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
        _showError("This phone number is already registered. Please login.");
      } else {
        _showError("Registration failed. Please try again later.");
      }
    } catch (e) {
      _showError("Connection Failed. Check your internet or server status.");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AyuTheme.warningRed),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(gradient: AyuTheme.primaryGradient),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 30),
            child: Column(
              children: [
                const SizedBox(height: 40),
                
                // 1. BRANDING AREA (Consistent with Login)
                const Icon(Icons.spa_rounded, size: 80, color: Colors.white),
                const SizedBox(height: 10),
                const Text(
                  "AYU-EAT",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 36,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                  ),
                ),
                const Text(
                  "Begin your Ayurvedic journey",
                  style: TextStyle(color: Colors.white70, fontSize: 16, fontStyle: FontStyle.italic),
                ),
                
                const SizedBox(height: 40),

                // 2. REGISTRATION CARD
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.95),
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      )
                    ],
                  ),
                  child: Column(
                    children: [
                      Text(
                        "Create Account",
                        style: TextStyle(
                          color: AyuTheme.darkGreen,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 25),
                      
                      // Full Name Field
                      _buildTextField(
                        controller: _nameController,
                        hint: "Full Name",
                        icon: Icons.person_outline_rounded,
                      ),
                      const SizedBox(height: 15),

                      // Phone Field
                      _buildTextField(
                        controller: _phoneController,
                        hint: "Phone Number",
                        icon: Icons.phone_android_rounded,
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 15),
                      
                      // Password Field
                      _buildTextField(
                        controller: _passController,
                        hint: "Create Password",
                        icon: Icons.lock_outline_rounded,
                        obscureText: _obscureText,
                        isPassword: true,
                        toggleVisibility: () => setState(() => _obscureText = !_obscureText),
                      ),
                      
                      const SizedBox(height: 30),

                      // Register Button
                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _handleRegister,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AyuTheme.darkGreen,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                            elevation: 2,
                          ),
                          child: _isLoading 
                            ? const SizedBox(
                                height: 20, width: 20, 
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Text("REGISTER", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 30),

                // 3. LOGIN LINK (For existing users)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("Already have an account?", style: TextStyle(color: Colors.white70)),
                    TextButton(
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const LoginScreen())),
                      child: const Text(
                        "Login Now",
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, decoration: TextDecoration.underline),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Helper Widget for Clean & Reusable Inputs
  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscureText = false,
    bool isPassword = false,
    VoidCallback? toggleVisibility,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(15),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        style: const TextStyle(color: Colors.black87, fontSize: 15),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
          prefixIcon: Icon(icon, color: AyuTheme.darkGreen, size: 20),
          suffixIcon: isPassword 
              ? IconButton(
                  icon: Icon(obscureText ? Icons.visibility_off : Icons.visibility, color: Colors.grey, size: 20),
                  onPressed: toggleVisibility,
                ) 
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
        ),
      ),
    );
  }
}