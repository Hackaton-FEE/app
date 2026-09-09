import 'dart:ui' show Tristate;

import 'package:fee_app/app/theme.dart';
import 'package:fee_app/features/accounts/data/demo_account_repository.dart';
import 'package:fee_app/features/accounts/domain/account_repository.dart';
import 'package:fee_app/features/accounts/domain/local_account.dart';
import 'package:fee_app/features/accounts/presentation/account_picker_page.dart';
import 'package:fee_app/features/accounts/presentation/accounts_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

// These tests check Flutter semantics, focus and layout. They do not replace
// TalkBack or VoiceOver use on a device or establish accessibility conformance.
void main() {
  late AccountsController controller;

  tearDown(() => controller.dispose());

  Future<void> start(
    WidgetTester tester, {
    AccountRepository? repository,
    Size size = const Size(390, 844),
    double textScale = 1,
  }) async {
    controller = AccountsController(repository ?? DemoAccountRepository());
    await controller.load();
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        locale: const Locale('es'),
        supportedLocales: const [Locale('es')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: AccountPickerPage(controller: controller),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> reveal(WidgetTester tester, Finder target) async {
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
    expect(target.hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  }

  Future<void> checkGuidelines(WidgetTester tester) async {
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
  }

  for (final viewport in [
    (const Size(390, 844), 1.0),
    (const Size(320, 640), 2.0),
  ]) {
    testWidgets('profile picker and marketing remain accessible at '
        '${viewport.$1.width} px and ${viewport.$2}x text', (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        await start(tester, size: viewport.$1, textScale: viewport.$2);
        final heading = find.text('Elige tu cuenta');
        expect(
          tester
              .getSemantics(heading)
              .getSemanticsData()
              .flagsCollection
              .isHeader,
          isTrue,
        );
        expect(tester.takeException(), isNull);
        await checkGuidelines(tester);

        for (final account in controller.accounts) {
          final button = find.byKey(Key('account-${account.id}'));
          await reveal(tester, button);
          final data = tester.getSemantics(button).getSemanticsData();
          expect(data.flagsCollection.isButton, isTrue);
          expect(data.label, contains(account.name));
          expect(data.label, contains(account.email));
          expect(tester.getSize(button).height, greaterThanOrEqualTo(48));
          await checkGuidelines(tester);
        }

        await reveal(tester, find.byKey(const Key('account-add-existing')));
        await checkGuidelines(tester);

        final discover = find.text("Descubre Osisn't");
        await reveal(tester, discover);
        await tester.tap(discover);
        await tester.pumpAndSettle();
        final marketingHeading = find.text('Menos dudas.\nMás control.');
        expect(marketingHeading.hitTestable(), findsOneWidget);
        expect(
          tester
              .getSemantics(marketingHeading)
              .getSemanticsData()
              .flagsCollection
              .isHeader,
          isTrue,
        );
        expect(find.byKey(const Key('account-marketing')), findsOneWidget);
        expect(tester.takeException(), isNull);
        await checkGuidelines(tester);

        for (final text in [
          'Así funciona',
          'Explora tu huella',
          'Dale contexto con GuardAI',
          'Decide cómo seguir',
          'Conoce a GuardAI',
        ]) {
          final section = find.text(text);
          await reveal(tester, section);
          expect(
            tester
                .getSemantics(section)
                .getSemanticsData()
                .flagsCollection
                .isHeader,
            isTrue,
          );
          await checkGuidelines(tester);
        }
        await reveal(tester, find.text('A tu ritmo. Desde un solo lugar.'));
        await checkGuidelines(tester);
      } finally {
        semantics.dispose();
      }
    });
  }

  testWidgets('a profile can receive keyboard focus and open with Enter', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      await start(tester);
      final first = controller.accounts.first;
      final button = find.byKey(Key('account-${first.id}'));
      var focused = false;
      for (var index = 0; index < 8 && !focused; index++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pumpAndSettle();
        focused =
            tester
                .getSemantics(button)
                .getSemanticsData()
                .flagsCollection
                .isFocused ==
            Tristate.isTrue;
      }
      expect(focused, isTrue);
      expect(controller.activeAccount, isNull);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(controller.activeAccount?.id, first.id);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('empty picker actions remain usable at 320 px and 2x text', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      await start(
        tester,
        repository: DemoAccountRepository(initialAccounts: []),
        size: const Size(320, 640),
        textScale: 2,
      );
      await reveal(tester, find.byKey(const Key('account-create')));
      await checkGuidelines(tester);
      await tester.tap(find.byKey(const Key('account-create')));
      await tester.pumpAndSettle();
      expect(controller.activeAccount, isNotNull);
      expect(controller.accounts, hasLength(1));
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets(
    'load failure is announced and retry restores available profiles',
    (tester) async {
      final semantics = tester.ensureSemantics();
      final repository = _UnavailableAccounts();
      try {
        await start(tester, repository: repository);
        final error = find.text(controller.loadError!);
        await reveal(tester, error);
        expect(
          tester
              .getSemantics(error)
              .getSemanticsData()
              .flagsCollection
              .isLiveRegion,
          isTrue,
        );
        expect(find.byKey(const Key('account-create')), findsNothing);
        expect(find.byKey(const Key('account-add-existing')), findsNothing);
        expect(find.textContaining('private-detail'), findsNothing);
        await checkGuidelines(tester);
        repository.unavailable = false;
        await reveal(tester, find.text('Reintentar'));
        await tester.tap(find.text('Reintentar'));
        await tester.pumpAndSettle();
        expect(controller.loadError, isNull);
        expect(controller.accounts, hasLength(2));
        expect(controller.activeAccount, isNull);
        expect(tester.takeException(), isNull);
        await reveal(
          tester,
          find.byKey(Key('account-${controller.accounts.first.id}')),
        );
        await checkGuidelines(tester);
      } finally {
        semantics.dispose();
      }
    },
  );
}

class _UnavailableAccounts implements AccountRepository {
  final _delegate = DemoAccountRepository();
  bool unavailable = true;

  @override
  Future<List<LocalAccount>> listAccounts() {
    if (unavailable) throw StateError('private-detail');
    return _delegate.listAccounts();
  }

  @override
  Future<LocalAccount> addAccount({
    required String name,
    required String email,
  }) => _delegate.addAccount(name: name, email: email);
}
