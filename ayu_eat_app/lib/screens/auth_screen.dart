import 'package:flutter/material.dart';
import '../theme/ayu_theme.dart';
import '../services/auth_service.dart';
import 'onboarding_screen.dart';

class AuthScreen extends StatefulWidget {
  @override
  _AuthScreenState createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool isLogin = true;
  final _phoneController = TextEditingController();
  final _nameController = TextEditingController();
  final _passController = TextEditingController();

  void _submit() async {
    // TODO: Connect to your FastAPI /login or /register
    // For Prototype: Simulate Success
    await AuthService.saveSession("123", _nameController.text, false);
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => OnboardingScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: AyuTheme.primaryGradient),
        child: Center(
          child: Card(
            margin: EdgeInsets.all(20),
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(isLogin ? "Login to Ayu-Eat" : "Create Account", 
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AyuTheme.darkGreen)),
                  if (!isLogin) TextField(controller: _nameController, decoration: InputDecoration(labelText: "Full Name")),
                  TextField(controller: _phoneController, decoration: InputDecoration(labelText: "Phone Number"), keyboardType: TextInputType.phone),
                  TextField(controller: _passController, decoration: InputDecoration(labelText: "Password"), obscureText: true),
                  SizedBox(height: 20),
                  ElevatedButton(onPressed: _submit, child: Text(isLogin ? "Login" : "Register")),
                  TextButton(
                    onPressed: () => setState(() => isLogin = !isLogin),
                    child: Text(isLogin ? "New here? Register" : "Already have an account? Login"),
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}