import 'package:flutter/material.dart';

import 'palette.dart';

ThemeData buildAppTheme() {
  // Explicit roles preserve the official values instead of generating a
  // different tonal palette from a seed.
  const colors = ColorScheme(
    brightness: Brightness.light,
    primary: AppPalette.deepOlive,
    onPrimary: AppPalette.card,
    primaryContainer: AppPalette.surfaceBadge,
    onPrimaryContainer: AppPalette.deepOlive,
    primaryFixed: AppPalette.surfaceBadge,
    primaryFixedDim: AppPalette.surfaceBadgeSecondary,
    onPrimaryFixed: AppPalette.black,
    onPrimaryFixedVariant: AppPalette.deepOlive,
    secondary: AppPalette.olive,
    onSecondary: AppPalette.card,
    secondaryContainer: AppPalette.surfaceBadgeSecondary,
    onSecondaryContainer: AppPalette.textPrimary,
    secondaryFixed: AppPalette.surfaceBadge,
    secondaryFixedDim: AppPalette.surfaceBadgeSecondary,
    onSecondaryFixed: AppPalette.black,
    onSecondaryFixedVariant: AppPalette.deepOlive,
    tertiary: AppPalette.olive,
    onTertiary: AppPalette.card,
    tertiaryContainer: AppPalette.surfaceBadge,
    onTertiaryContainer: AppPalette.deepOlive,
    tertiaryFixed: AppPalette.surfaceBadge,
    tertiaryFixedDim: AppPalette.surfaceBadgeSecondary,
    onTertiaryFixed: AppPalette.black,
    onTertiaryFixedVariant: AppPalette.deepOlive,
    error: AppPalette.error,
    onError: AppPalette.card,
    errorContainer: AppPalette.errorContainer,
    onErrorContainer: AppPalette.textPrimary,
    surface: AppPalette.card,
    onSurface: AppPalette.textPrimary,
    surfaceDim: AppPalette.cardBorder,
    surfaceBright: AppPalette.card,
    surfaceContainerLowest: AppPalette.card,
    surfaceContainerLow: AppPalette.card,
    surfaceContainer: AppPalette.scaffold,
    surfaceContainerHigh: AppPalette.cardBorder,
    surfaceContainerHighest: AppPalette.cardBorder,
    // Slate 500 falls below 4.5:1 on the scaffold and cream panels.
    onSurfaceVariant: AppPalette.olive,
    outline: AppPalette.warmKhaki,
    outlineVariant: AppPalette.cardBorder,
    shadow: AppPalette.black,
    scrim: AppPalette.black,
    inverseSurface: AppPalette.deepOlive,
    onInverseSurface: AppPalette.card,
    inversePrimary: AppPalette.surfaceBadgeSecondary,
    surfaceTint: Colors.transparent,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colors,
    scaffoldBackgroundColor: AppPalette.scaffold,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppPalette.scaffold,
      foregroundColor: AppPalette.deepOlive,
      scrolledUnderElevation: 0,
      centerTitle: false,
    ),
    dividerTheme: const DividerThemeData(
      color: AppPalette.cardBorder,
      thickness: 1,
    ),
    navigationDrawerTheme: const NavigationDrawerThemeData(
      backgroundColor: AppPalette.scaffold,
      indicatorColor: AppPalette.surfaceBadge,
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
      color: AppPalette.card,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppPalette.cardBorder),
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppPalette.card,
      modalBackgroundColor: AppPalette.card,
      surfaceTintColor: Colors.transparent,
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: AppPalette.card,
      surfaceTintColor: Colors.transparent,
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
      fillColor: AppPalette.card,
      hintStyle: TextStyle(color: AppPalette.olive),
      labelStyle: TextStyle(color: AppPalette.olive),
      floatingLabelStyle: TextStyle(color: AppPalette.deepOlive),
      helperStyle: TextStyle(color: AppPalette.olive),
      errorStyle: TextStyle(color: AppPalette.textPrimary),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: AppPalette.warmKhaki),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: AppPalette.warmKhaki, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderSide: BorderSide(color: AppPalette.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderSide: BorderSide(color: AppPalette.error, width: 2),
      ),
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: AppPalette.deepOlive,
      selectionColor: AppPalette.deepOlive.withValues(alpha: 0.20),
      selectionHandleColor: AppPalette.deepOlive,
    ),
  );
}

ThemeData buildAppDarkTheme() {
  const colors = ColorScheme(
    brightness: Brightness.dark,
    primary: AppPalette.darkPrimary,
    onPrimary: AppPalette.black,
    primaryContainer: AppPalette.darkPrimaryContainer,
    onPrimaryContainer: AppPalette.darkTextPrimary,
    primaryFixed: AppPalette.darkPrimary,
    primaryFixedDim: AppPalette.darkSecondary,
    onPrimaryFixed: AppPalette.black,
    onPrimaryFixedVariant: AppPalette.black,
    secondary: AppPalette.darkSecondary,
    onSecondary: AppPalette.black,
    secondaryContainer: AppPalette.darkSecondaryContainer,
    onSecondaryContainer: AppPalette.darkTextPrimary,
    secondaryFixed: AppPalette.darkPrimary,
    secondaryFixedDim: AppPalette.darkSecondary,
    onSecondaryFixed: AppPalette.black,
    onSecondaryFixedVariant: AppPalette.black,
    tertiary: AppPalette.darkSecondary,
    onTertiary: AppPalette.black,
    tertiaryContainer: AppPalette.darkPrimaryContainer,
    onTertiaryContainer: AppPalette.darkTextPrimary,
    tertiaryFixed: AppPalette.darkSecondary,
    tertiaryFixedDim: AppPalette.darkSecondary,
    onTertiaryFixed: AppPalette.black,
    onTertiaryFixedVariant: AppPalette.black,
    error: AppPalette.error,
    onError: AppPalette.black,
    errorContainer: Color(0xFF451A1A),
    onErrorContainer: Color(0xFFFCA5A5),
    surface: AppPalette.darkCard,
    onSurface: AppPalette.darkTextPrimary,
    surfaceDim: AppPalette.darkCard,
    surfaceBright: AppPalette.darkCardBorder,
    surfaceContainerLowest: AppPalette.darkScaffold,
    surfaceContainerLow: AppPalette.darkCard,
    surfaceContainer: AppPalette.darkCard,
    surfaceContainerHigh: AppPalette.darkCardBorder,
    surfaceContainerHighest: AppPalette.darkCardBorder,
    onSurfaceVariant: AppPalette.darkTextSecondary,
    outline: AppPalette.darkSecondary,
    outlineVariant: AppPalette.darkCardBorder,
    shadow: AppPalette.black,
    scrim: AppPalette.black,
    inverseSurface: AppPalette.card,
    onInverseSurface: AppPalette.deepOlive,
    inversePrimary: AppPalette.deepOlive,
    surfaceTint: Colors.transparent,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colors,
    scaffoldBackgroundColor: AppPalette.darkScaffold,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppPalette.darkScaffold,
      foregroundColor: AppPalette.darkTextPrimary,
      scrolledUnderElevation: 0,
      centerTitle: false,
    ),
    dividerTheme: const DividerThemeData(
      color: AppPalette.darkCardBorder,
      thickness: 1,
    ),
    navigationDrawerTheme: const NavigationDrawerThemeData(
      backgroundColor: AppPalette.darkScaffold,
      indicatorColor: AppPalette.darkPrimaryContainer,
      elevation: 0,
    ),
    chipTheme: ChipThemeData(
      side: BorderSide.none,
      backgroundColor: colors.surfaceContainerHigh,
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
      color: AppPalette.darkCard,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppPalette.darkCardBorder),
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppPalette.darkCard,
      modalBackgroundColor: AppPalette.darkCard,
      surfaceTintColor: Colors.transparent,
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: AppPalette.darkCard,
      surfaceTintColor: Colors.transparent,
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
      fillColor: AppPalette.darkCard,
      hintStyle: TextStyle(color: AppPalette.darkTextMuted),
      labelStyle: TextStyle(color: AppPalette.darkTextSecondary),
      floatingLabelStyle: TextStyle(color: AppPalette.darkPrimary),
      helperStyle: TextStyle(color: AppPalette.darkTextSecondary),
      errorStyle: TextStyle(color: Color(0xFFFCA5A5)),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: AppPalette.darkCardBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: AppPalette.darkPrimary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderSide: BorderSide(color: AppPalette.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderSide: BorderSide(color: AppPalette.error, width: 2),
      ),
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: AppPalette.darkPrimary,
      selectionColor: AppPalette.darkPrimary.withValues(alpha: 0.35),
      selectionHandleColor: AppPalette.darkPrimary,
    ),
  );
}
