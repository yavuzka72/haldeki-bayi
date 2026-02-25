import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData lightTheme(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(seedColor: const Color(0xFF0EA5E9));
    return ThemeData(
      colorScheme: colorScheme,
      useMaterial3: true,
      appBarTheme: const AppBarTheme(centerTitle: true),
      visualDensity: VisualDensity.standard,
    );
  }
}
