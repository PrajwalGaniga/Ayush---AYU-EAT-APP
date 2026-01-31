import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'theme/ayu_theme.dart';
import 'screens/register_screen.dart';
import 'screens/dashboard_screen.dart';
import 'services/auth_service.dart';

void main() async {
  // Required for accessing native plugins before runApp
  WidgetsFlutterBinding.ensureInitialized();
  
  // Check if a user session exists
  final String? savedPhone = await AuthService.getSavedPhone();

  runApp(AyuEatApp(startPhone: savedPhone));
}

class AyuEatApp extends StatelessWidget {
  final String? startPhone;
  const AyuEatApp({super.key, this.startPhone});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AYU-EAT',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        primaryColor: AyuTheme.darkGreen,
        textTheme: GoogleFonts.montserratTextTheme(),
      ),
      // If phone is found, go to Dashboard. Otherwise, start at Register.
      home: startPhone != null 
          ? DashboardScreen(userPhone: startPhone!) 
          : const RegisterScreen(),
    );
  }
}