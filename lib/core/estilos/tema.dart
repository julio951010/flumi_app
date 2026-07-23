import 'package:flutter/material.dart';

class FlumiTema {
  static const Color colorPrimario = Color(0xFF3D9DF2);
  static const Color colorSecundario = Color(0xFFFF6B8A);
  static const Color colorFondo = Color(0xFFF5F7FA);

  static ThemeData tema = ThemeData(
    colorSchemeSeed: colorPrimario,
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: colorFondo,
    appBarTheme: const AppBarTheme(
      centerTitle: true,
      elevation: 0,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
  );
}
