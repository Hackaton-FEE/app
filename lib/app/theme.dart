import 'package:flutter/material.dart';

ThemeData buildAppTheme() {
  final colors = ColorScheme.fromSeed(
    seedColor: const Color(0xFF167569),
    brightness: Brightness.light,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colors,
    scaffoldBackgroundColor: const Color(0xFFF5F7F8),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFFF5F7F8),
      scrolledUnderElevation: 0,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(minimumSize: const Size(48, 52)),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(minimumSize: const Size(48, 52)),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      border: OutlineInputBorder(),
      filled: true,
    ),
  );
}
