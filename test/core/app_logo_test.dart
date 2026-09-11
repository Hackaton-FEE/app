import 'package:fee_app/core/widgets/app_logo.dart';
import 'package:fee_app/core/widgets/logo_loading_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppLogo', () {
    testWidgets('renders the app icon by default in light theme', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          themeMode: ThemeMode.light,
          home: Scaffold(body: Center(child: AppLogo(size: 40))),
        ),
      );

      final image = tester.widget<Image>(find.byType(Image));
      expect(
        (image.image as AssetImage).assetName,
        'assets/logo/raster/osisnt_app_icon.png',
      );
      expect(tester.getSize(find.byType(AppLogo)), const Size(40, 40));
    });

    testWidgets('keeps the app icon in dark theme', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          darkTheme: ThemeData.dark(),
          themeMode: ThemeMode.dark,
          home: const Scaffold(body: Center(child: AppLogo(size: 40))),
        ),
      );

      final image = tester.widget<Image>(find.byType(Image));
      expect(
        (image.image as AssetImage).assetName,
        'assets/logo/raster/osisnt_app_icon.png',
      );
    });

    testWidgets('respects explicit isDarkMode override', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(child: AppLogo(size: 32, isDarkMode: true)),
          ),
        ),
      );

      final svg = tester.widget<SvgPicture>(find.byType(SvgPicture));
      final loader = svg.bytesLoader as SvgAssetLoader;
      expect(loader.assetName, 'assets/logo/vector/logo_dark_white.svg');
    });

    testWidgets('loads cropped vector when useOriginalColors is true', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(child: AppLogo(size: 32, useOriginalColors: true)),
          ),
        ),
      );

      final svg = tester.widget<SvgPicture>(find.byType(SvgPicture));
      final loader = svg.bytesLoader as SvgAssetLoader;
      expect(loader.assetName, 'assets/logo/vector/logo_cropped.svg');
    });

    testWidgets('keeps the app icon square when height is supplied', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: Center(child: AppLogo(height: 100))),
        ),
      );

      expect(tester.getSize(find.byType(AppLogo)), const Size(100, 100));
    });

    testWidgets('exposes accessible semantics when semanticLabel is provided', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: AppLogo(size: 32, semanticLabel: "Logo de prueba"),
            ),
          ),
        ),
      );

      expect(find.bySemanticsLabel('Logo de prueba'), findsOneWidget);
    });
  });

  group('LogoLoadingIndicator', () {
    testWidgets('adapts automatically to context theme brightness', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          darkTheme: ThemeData.dark(),
          themeMode: ThemeMode.dark,
          home: const Scaffold(
            body: Center(
              child: LogoLoadingIndicator(size: 64, useFrames: false),
            ),
          ),
        ),
      );

      final svg = tester.widget<SvgPicture>(find.byType(SvgPicture));
      final loader = svg.bytesLoader as SvgAssetLoader;
      expect(loader.assetName, 'assets/logo/standalone/logo_loading_white.svg');
    });
  });
}
