import 'package:flutter/material.dart';

class AyuTheme {
  static const Color darkGreen = Color(0xFF1B5E20);
  static const Color lightGreen = Color(0xFF4CAF50);
  static const Color accentSage = Color(0xFFF1F8E9);
  static const Color warningRed = Color(0xFFD32F2F);

  static const Gradient primaryGradient = LinearGradient(
    colors: [darkGreen, lightGreen],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static ThemeData get lightTheme => ThemeData(
    useMaterial3: true,
    primaryColor: darkGreen,
    colorScheme: ColorScheme.fromSeed(seedColor: darkGreen),
    scaffoldBackgroundColor: accentSage,
  );
}