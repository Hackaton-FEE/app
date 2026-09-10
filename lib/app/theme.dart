import 'package:flutter/material.dart';

import 'palette.dart';

ThemeData buildAppTheme() {
  // Explicit roles preserve the official values instead of generating a
  // different tonal palette from a seed.
  const colors = ColorScheme(
    brightness: Brightness.light,
    primary: AppPalette.deepOlive,
    onPrimary: AppPalette.paleCream,
    primaryContainer: AppPalette.paleCream,
    onPrimaryContainer: AppPalette.deepOlive,
    primaryFixed: AppPalette.paleCream,
    primaryFixedDim: AppPalette.sandGold,
    onPrimaryFixed: AppPalette.black,
    onPrimaryFixedVariant: AppPalette.deepOlive,
    secondary: AppPalette.olive,
    onSecondary: AppPalette.card,
    secondaryContainer: AppPalette.sandGold,
    onSecondaryContainer: AppPalette.black,
    secondaryFixed: AppPalette.paleCream,
    secondaryFixedDim: AppPalette.sandGold,
    onSecondaryFixed: AppPalette.black,
    onSecondaryFixedVariant: AppPalette.deepOlive,
    tertiary: AppPalette.warmKhaki,
    onTertiary: AppPalette.black,
    tertiaryContainer: AppPalette.paleCream,
    onTertiaryContainer: AppPalette.deepOlive,
    tertiaryFixed: AppPalette.paleCream,
    tertiaryFixedDim: AppPalette.sandGold,
    onTertiaryFixed: AppPalette.black,
    onTertiaryFixedVariant: AppPalette.deepOlive,
    error: AppPalette.error,
    onError: AppPalette.black,
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
    onInverseSurface: AppPalette.paleCream,
    inversePrimary: AppPalette.sandGold,
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
      indicatorColor: AppPalette.paleCream,
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
      selectionColor: AppPalette.sandGold.withValues(alpha: 0.45),
      selectionHandleColor: AppPalette.deepOlive,
    ),
  );
}
