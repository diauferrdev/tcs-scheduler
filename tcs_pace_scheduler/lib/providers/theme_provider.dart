import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Theme constants for easy access
class AppTheme {
  static const Color primaryBlack = Colors.black;
  static const Color primaryWhite = Colors.white;
}

class ThemeProvider with ChangeNotifier {
  static const String _themeKey = 'theme_mode';
  ThemeMode _themeMode = ThemeMode.dark;

  ThemeMode get themeMode => _themeMode;
  bool get isDark => _themeMode == ThemeMode.dark;

  ThemeProvider() {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final isDark = prefs.getBool(_themeKey) ?? true;
    _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }

  Future<void> toggleTheme() async {
    _themeMode =
        _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_themeKey, _themeMode == ThemeMode.dark);
  }

  // TCS Black & White Theme
  static ThemeData get darkTheme => ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black,
        primaryColor: Colors.white,
        fontFamily: 'BasisGrotesquePro',
        colorScheme: const ColorScheme.dark(
          primary: Colors.white,
          secondary: Colors.white,
          surface: Color(0xFF18181B), // zinc-900
          onSurface: Colors.white,
        ),
        textTheme: const TextTheme(
          displayLarge: TextStyle(fontFamily: 'HouschkaRoundedAlt', fontWeight: FontWeight.w500),
          displayMedium: TextStyle(fontFamily: 'HouschkaRoundedAlt', fontWeight: FontWeight.w500),
          displaySmall: TextStyle(fontFamily: 'HouschkaRoundedAlt', fontWeight: FontWeight.w500),
          headlineLarge: TextStyle(fontFamily: 'HouschkaRoundedAlt', fontWeight: FontWeight.w500),
          headlineMedium: TextStyle(fontFamily: 'HouschkaRoundedAlt', fontWeight: FontWeight.w500),
          headlineSmall: TextStyle(fontFamily: 'HouschkaRoundedAlt', fontWeight: FontWeight.w500),
          titleLarge: TextStyle(fontFamily: 'BasisGrotesquePro', fontWeight: FontWeight.w700),
          titleMedium: TextStyle(fontFamily: 'BasisGrotesquePro', fontWeight: FontWeight.w500),
          titleSmall: TextStyle(fontFamily: 'BasisGrotesquePro', fontWeight: FontWeight.w500),
          bodyLarge: TextStyle(fontFamily: 'BasisGrotesquePro', fontWeight: FontWeight.w400),
          bodyMedium: TextStyle(fontFamily: 'BasisGrotesquePro', fontWeight: FontWeight.w400),
          bodySmall: TextStyle(fontFamily: 'BasisGrotesquePro', fontWeight: FontWeight.w300),
          labelLarge: TextStyle(fontFamily: 'BasisGrotesquePro', fontWeight: FontWeight.w500),
          labelMedium: TextStyle(fontFamily: 'BasisGrotesquePro', fontWeight: FontWeight.w400),
          labelSmall: TextStyle(fontFamily: 'BasisGrotesquePro', fontWeight: FontWeight.w400),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          elevation: 0,
          titleTextStyle: TextStyle(
            fontFamily: 'HouschkaRoundedAlt',
            fontWeight: FontWeight.w500,
            fontSize: 20,
            color: Colors.white,
          ),
        ),
        cardTheme: const CardThemeData(
          color: Color(0xFF18181B),
          elevation: 0,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF09090B), // zinc-950
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF27272A)), // zinc-800
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF27272A)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Colors.white),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      );

  static ThemeData get lightTheme => ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF9FAFB), // gray-50
        primaryColor: Colors.black,
        fontFamily: 'BasisGrotesquePro',
        colorScheme: const ColorScheme.light(
          primary: Colors.black,
          secondary: Colors.black,
          surface: Colors.white,
          onSurface: Colors.black,
        ),
        textTheme: const TextTheme(
          displayLarge: TextStyle(fontFamily: 'HouschkaRoundedAlt', fontWeight: FontWeight.w500),
          displayMedium: TextStyle(fontFamily: 'HouschkaRoundedAlt', fontWeight: FontWeight.w500),
          displaySmall: TextStyle(fontFamily: 'HouschkaRoundedAlt', fontWeight: FontWeight.w500),
          headlineLarge: TextStyle(fontFamily: 'HouschkaRoundedAlt', fontWeight: FontWeight.w500),
          headlineMedium: TextStyle(fontFamily: 'HouschkaRoundedAlt', fontWeight: FontWeight.w500),
          headlineSmall: TextStyle(fontFamily: 'HouschkaRoundedAlt', fontWeight: FontWeight.w500),
          titleLarge: TextStyle(fontFamily: 'BasisGrotesquePro', fontWeight: FontWeight.w700),
          titleMedium: TextStyle(fontFamily: 'BasisGrotesquePro', fontWeight: FontWeight.w500),
          titleSmall: TextStyle(fontFamily: 'BasisGrotesquePro', fontWeight: FontWeight.w500),
          bodyLarge: TextStyle(fontFamily: 'BasisGrotesquePro', fontWeight: FontWeight.w400),
          bodyMedium: TextStyle(fontFamily: 'BasisGrotesquePro', fontWeight: FontWeight.w400),
          bodySmall: TextStyle(fontFamily: 'BasisGrotesquePro', fontWeight: FontWeight.w300),
          labelLarge: TextStyle(fontFamily: 'BasisGrotesquePro', fontWeight: FontWeight.w500),
          labelMedium: TextStyle(fontFamily: 'BasisGrotesquePro', fontWeight: FontWeight.w400),
          labelSmall: TextStyle(fontFamily: 'BasisGrotesquePro', fontWeight: FontWeight.w400),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
          titleTextStyle: TextStyle(
            fontFamily: 'HouschkaRoundedAlt',
            fontWeight: FontWeight.w500,
            fontSize: 20,
            color: Colors.black,
          ),
        ),
        cardTheme: const CardThemeData(
          color: Colors.white,
          elevation: 0,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFF9FAFB),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFE5E7EB)), // gray-200
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Colors.black),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      );
}
