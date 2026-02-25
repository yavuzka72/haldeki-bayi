import 'package:flutter/material.dart';

const kPurple = Color(0xFF0D4631);
const kPurple2 = Color(0xFF0D4631);
const kOrange = Color(0xFF98F090);

const kBg = Color(0xFFF3F4FB);
const kCard = Color(0xFFFFFFFF);
const kLine = Color(0xFFE6E8F2);

const kText = Color(0xFF0F172A);
const kMuted = Color(0xFF64748B);

final ThemeData appTheme = ThemeData.light().copyWith(
  scaffoldBackgroundColor: kBg,
  colorScheme: const ColorScheme.light(
    primary: kPurple,
    secondary: kOrange,
    surface: kCard,
    background: kBg,
    onPrimary: Colors.white,
    onSecondary: Colors.black,
    onSurface: kText,
  ),
  cardTheme: CardTheme(
    color: kCard,
    elevation: 0,
    margin: EdgeInsets.zero,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
  ),
  dividerColor: kLine,
  textTheme: const TextTheme(
    titleLarge:
        TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: kText),
    titleMedium:
        TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: kText),
    bodyMedium: TextStyle(fontSize: 14, color: kText),
    bodySmall: TextStyle(fontSize: 12, color: kMuted),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: kPurple,
      foregroundColor: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      textStyle: const TextStyle(fontWeight: FontWeight.w900),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: kText,
      side: BorderSide(color: kLine),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      textStyle: const TextStyle(fontWeight: FontWeight.w800),
    ),
  ),
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: kPurple,
      textStyle: const TextStyle(fontWeight: FontWeight.w800),
    ),
  ),
  tabBarTheme: TabBarTheme(
    labelColor: kPurple,
    unselectedLabelColor: kMuted,
    indicatorColor: kPurple,
    labelStyle: const TextStyle(fontWeight: FontWeight.w900),
    unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700),
  ),
  iconTheme: const IconThemeData(color: kMuted),
);
