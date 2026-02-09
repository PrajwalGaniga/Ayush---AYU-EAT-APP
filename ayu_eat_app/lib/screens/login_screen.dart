import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async'; 
import '../theme/ayu_theme.dart';
import '../api/api_config.dart';
import 'onboarding_screen.dart';
import 'dashboard_screen.dart';
import 'register_screen.dart'; // Added for the register link

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneController = TextEditingController();
  final _passController = TextEditingController();
  bool _isLoading = false;
  bool _obscureText = true; // UX: Toggle for password visibility

  // --- LOGIC: MAINTAINED WITHOUT CHANGE ---
  Future<void> _handleLogin() async {
    if (_phoneController.text.isEmpty || _passController.text.isEmpty) {
      _showSnack("Please enter credentials");
      return;
    }

    setState(() => _isLoading = true);
    try {
      final loginUrl = Uri.parse(ApiConfig.login);
      debugPrint("🚀 Attempting Login at: $loginUrl"); 
      
      final response = await http.post(
        loginUrl,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "phone": _phoneController.text, 
          "password": _passController.text
        }),
      ).timeout(const Duration(seconds: 30));

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
        _showSnack("Login Failed (${response.statusCode}): ${response.body}");
      }
    } on TimeoutException {
      _showSnack("Server wake-up took too long. Please try again in a moment.");
    } catch (e) {
      debugPrint("❌ Connection Error: $e");
      _showSnack("Network Error: Ensure your phone has internet and the URL is correct.");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnack(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // resizeToAvoidBottomInset ensures UI pushes up when keyboard appears
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
                const SizedBox(height: 60),
                
                // 1. BRANDING AREA
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
                  "Nourish your soul",
                  style: TextStyle(color: Colors.white70, fontSize: 16, fontStyle: FontStyle.italic),
                ),
                
                const SizedBox(height: 50),

                // 2. LOGIN FORM CARD
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
                        "Welcome Back",
                        style: TextStyle(
                          color: AyuTheme.darkGreen,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 25),
                      
                      // Phone Input
                      _buildTextField(
                        controller: _phoneController,
                        hint: "Phone Number",
                        icon: Icons.phone_android_rounded,
                        keyboardType: TextInputType.phone,
                      ),
                      
                      const SizedBox(height: 15),
                      
                      // Password Input
                      _buildTextField(
                        controller: _passController,
                        hint: "Password",
                        icon: Icons.lock_outline_rounded,
                        obscureText: _obscureText,
                        isPassword: true,
                        toggleVisibility: () => setState(() => _obscureText = !_obscureText),
                      ),
                      
                      const SizedBox(height: 30),

                      // Login Button
                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _handleLogin,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AyuTheme.darkGreen,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                            elevation: 2,
                          ),
                          child: _isLoading 
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text("LOGIN", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 40),

                // 3. REGISTER LINK
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("Don't have an account?", style: TextStyle(color: Colors.white70)),
                    TextButton(
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const RegisterScreen())),
                      child: const Text(
                        "Register Now",
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

  // Helper Widget for Clean Inputs
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
        style: const TextStyle(color: Colors.black87),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.grey),
          prefixIcon: Icon(icon, color: AyuTheme.darkGreen),
          suffixIcon: isPassword 
              ? IconButton(
                  icon: Icon(obscureText ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
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