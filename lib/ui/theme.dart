// lib/ui/theme.dart
import 'package:flutter/material.dart';

ThemeData buildHealthTheme() {
  const lightBlue = Color(0xFF5EC4FF);
  const lightBlue80 = Color(0xFF9ADAFD);
  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: lightBlue).copyWith(
      primary: lightBlue,
      secondaryContainer: lightBlue80,
      background: Colors.white,
      onPrimary: Colors.white,
    ),
    appBarTheme: const AppBarTheme(centerTitle: true, elevation: 0),
    cardTheme: const CardThemeData(margin: EdgeInsets.all(12), elevation: 1),
  );
}
