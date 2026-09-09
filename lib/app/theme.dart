import 'package:flutter/material.dart';

ThemeData buildAppTheme() {
  final colors = ColorScheme.fromSeed(
    seedColor: const Color(0xFF345E50),
    brightness: Brightness.light,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colors,
    scaffoldBackgroundColor: const Color(0xFFF7F9F6),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFFF7F9F6),
      scrolledUnderElevation: 0,
      centerTitle: false,
    ),
    dividerTheme: DividerThemeData(
      color: colors.outlineVariant.withValues(alpha: 0.5),
      thickness: 1,
    ),
    navigationDrawerTheme: NavigationDrawerThemeData(
      backgroundColor: const Color(0xFFF7F9F6),
      indicatorColor: colors.primaryContainer.withValues(alpha: 0.6),
      elevation: 0,
    ),
    chipTheme: ChipThemeData(
      side: BorderSide.none,
      backgroundColor: colors.surfaceContainerLow,
      selectedColor: colors.primaryContainer,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      shape: const StadiumBorder(),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(18)),
      ),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      border: OutlineInputBorder(),
      filled: true,
    ),
  );
}
