import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// Logodaki yeşile yakın bir ton (istersen tam HEX ver, ör: 0xFF00D05A)
const kBrandGreen = Color(0xFF00D05A);

ThemeData lightTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: kBrandGreen,
    brightness: Brightness.light,
  );
  final baseText = GoogleFonts.nunitoTextTheme();

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    textTheme: baseText.apply(
      bodyColor: scheme.onSurface,
      displayColor: scheme.onSurface,
    ),
    primaryTextTheme: baseText.apply(
      bodyColor: scheme.onSurface,
      displayColor: scheme.onSurface,
    ),
    fontFamily: GoogleFonts.nunito().fontFamily,

    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      elevation: 0,
    ),

    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: scheme.surface,
      selectedIconTheme: IconThemeData(color: scheme.primary),
      selectedLabelTextStyle: TextStyle(color: scheme.primary, fontWeight: FontWeight.w600),
      indicatorColor: scheme.primary.withOpacity(.12),
    ),

    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: scheme.surface,
      indicatorColor: scheme.primary.withOpacity(.12),
      labelTextStyle: const MaterialStatePropertyAll(TextStyle(fontWeight: FontWeight.w600)),
    ),

    chipTheme: ChipThemeData(
      color: MaterialStatePropertyAll(scheme.surfaceVariant),
      selectedColor: scheme.primary.withOpacity(.15),
      labelStyle: TextStyle(color: scheme.onSurface),
      secondaryLabelStyle: TextStyle(color: scheme.onSurface),
    ),

    dataTableTheme: DataTableThemeData(
      headingRowColor: MaterialStatePropertyAll(scheme.surfaceVariant),
      headingTextStyle: const TextStyle(fontWeight: FontWeight.w600),
      dataTextStyle: TextStyle(color: scheme.onSurface),
    ),

    filledButtonTheme: FilledButtonThemeData(
      style: ButtonStyle(
        backgroundColor: MaterialStatePropertyAll(scheme.primary),
        foregroundColor: MaterialStatePropertyAll(scheme.onPrimary),
      ),
    ),

    snackBarTheme: SnackBarThemeData(
      backgroundColor: scheme.inverseSurface,
      contentTextStyle: TextStyle(color: scheme.onInverseSurface),
      behavior: SnackBarBehavior.floating,
    ),
  );
}

ThemeData darkTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: kBrandGreen,
    brightness: Brightness.dark,
  );
  return ThemeData(useMaterial3: true, colorScheme: scheme);
}
