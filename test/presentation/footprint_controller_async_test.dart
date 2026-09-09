import 'dart:async';

import 'package:fee_app/features/footprint/domain/footprint_item.dart';
import 'package:fee_app/features/footprint/domain/footprint_profile.dart';
import 'package:fee_app/features/footprint/domain/footprint_repository.dart';
import 'package:fee_app/features/footprint/presentation/footprint_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'a pending load blocks another load and a scan until completion',
    () async {
      final repository = _ControlledRepository();
      final controller = FootprintController(repository);
      addTearDown(controller.dispose);

      await controller.retry();
      expect(repository.loadCalls, 0);

      final loading = controller.loadProfile();
      await controller.loadProfile();
      expect(await controller.scanIdentity('alias_ficticio'), isFalse);
      expect(repository.loadCalls, 1);
      expect(repository.scanCalls, 0);
      expect(controller.isLoading, isTrue);
      expect(controller.profile, isNull);

      final first = _profile('primero');
      repository.loadGate.complete(first);
      await loading;
      expect(controller.isLoading, isFalse);
      expect(controller.profile, same(first));

      repository.loadGate = Completer<FootprintProfile>();
      final reloading = controller.loadProfile();
      final latest = _profile('actualizado');
      repository.loadGate.complete(latest);
      await reloading;
      expect(repository.loadCalls, 2);
      expect(controller.profile, same(latest));
    },
  );

  test(
    'a scan blocks loads and duplicate scans throughout preparation and reply',
    () async {
      final repository = _ControlledRepository();
      final controller = FootprintController(repository);
      addTearDown(controller.dispose);

      final scanning = controller.scanIdentity('alias_ficticio');
      await controller.loadProfile();
      expect(await controller.scanIdentity('otro_alias'), isFalse);
      expect(repository.loadCalls, 0);
      expect(repository.scanCalls, 0);
      expect(controller.isLoading, isTrue);

      await repository.scanStarted.future;
      await controller.loadProfile();
      expect(await controller.scanIdentity('otro_alias'), isFalse);
      expect(repository.loadCalls, 0);
      expect(repository.scanCalls, 1);
      expect(controller.profile, isNull);
      expect(controller.isLoading, isTrue);

      final scanned = _profile('alias_ficticio');
      repository.scanGate.complete(scanned);
      expect(await scanning, isTrue);
      expect(controller.profile, same(scanned));
      expect(controller.isLoading, isFalse);
      expect(controller.scanningStage, isNull);
    },
  );

  test(
    'retry repeats a failed load while preserving the last profile',
    () async {
      final repository = _ControlledRepository();
      final controller = FootprintController(repository);
      addTearDown(controller.dispose);
      final initial = _profile('inicial');
      repository.loadGate.complete(initial);
      await controller.loadProfile();

      repository.loadGate = Completer<FootprintProfile>();
      final failed = controller.loadProfile();
      repository.loadGate.completeError(StateError('dato_privado'));
      await failed;
      expect(controller.profile, same(initial));
      expect(controller.isLoading, isFalse);
      expect(controller.error, isNotNull);
      expect(controller.error, isNot(contains('dato_privado')));

      repository.loadGate = Completer<FootprintProfile>();
      final retry = controller.retry();
      expect(controller.profile, same(initial));
      expect(repository.loadCalls, 3);
      expect(repository.scanCalls, 0);
      final refreshed = _profile('actualizado');
      repository.loadGate.complete(refreshed);
      await retry;
      expect(controller.profile, same(refreshed));
      expect(controller.error, isNull);
    },
  );

  test(
    'retry repeats the failed scan identity and preserves the last profile',
    () async {
      final repository = _ControlledRepository();
      final controller = FootprintController(repository);
      addTearDown(controller.dispose);
      final initial = _profile('inicial');
      repository.loadGate.complete(initial);
      await controller.loadProfile();

      final failed = controller.scanIdentity('alias_ficticio');
      await repository.scanStarted.future;
      repository.scanGate.completeError(StateError('dato_privado'));
      expect(await failed, isFalse);
      expect(controller.profile, same(initial));
      expect(controller.isLoading, isFalse);
      expect(controller.scanningStage, isNull);
      expect(controller.error, isNotNull);
      expect(controller.error, isNot(contains('dato_privado')));

      repository.scanGate = Completer<FootprintProfile>();
      repository.scanStarted = Completer<void>();
      final retry = controller.retry();
      expect(controller.profile, same(initial));
      await controller.retry();
      await controller.loadProfile();
      expect(await controller.scanIdentity('otro_alias'), isFalse);
      await repository.scanStarted.future;
      expect(repository.scanIdentities, ['alias_ficticio', 'alias_ficticio']);
      expect(repository.loadCalls, 1);
      expect(controller.profile, same(initial));
      final scanned = _profile('alias_ficticio');
      repository.scanGate.complete(scanned);
      await retry;
      expect(controller.profile, same(scanned));
      expect(controller.error, isNull);
      await controller.retry();
      expect(repository.scanCalls, 2);
      expect(repository.loadCalls, 1);
    },
  );

  test('retry follows a load failure that replaced a failed scan', () async {
    final repository = _ControlledRepository();
    final controller = FootprintController(repository);
    addTearDown(controller.dispose);
    final scanning = controller.scanIdentity('alias_ficticio');
    await repository.scanStarted.future;
    repository.scanGate.completeError(StateError('fallo de ejemplo'));
    expect(await scanning, isFalse);

    final loading = controller.loadProfile();
    repository.loadGate.completeError(StateError('fallo de ejemplo'));
    await loading;
    repository.loadGate = Completer<FootprintProfile>();
    final retry = controller.retry();
    final loaded = _profile('perfil_cargado');
    repository.loadGate.complete(loaded);
    await retry;

    expect(repository.scanIdentities, ['alias_ficticio']);
    expect(repository.loadCalls, 2);
    expect(controller.profile, same(loaded));
    expect(controller.error, isNull);
  });

  for (final fails in [false, true]) {
    test(
      'disposed controller ignores a pending load ${fails ? 'failure' : 'result'}',
      () async {
        final repository = _ControlledRepository();
        final controller = FootprintController(repository);
        var notifications = 0;
        controller.addListener(() => notifications++);
        final loading = controller.loadProfile();
        controller.dispose();
        final beforeCompletion = notifications;

        if (fails) {
          repository.loadGate.completeError(StateError('dato_privado'));
        } else {
          repository.loadGate.complete(_profile('resultado_tardío'));
        }
        await loading;

        expect(notifications, beforeCompletion);
        expect(controller.profile, isNull);
        expect(controller.error, isNull);
      },
    );

    test(
      'disposed controller ignores a pending scan ${fails ? 'failure' : 'result'}',
      () async {
        final repository = _ControlledRepository();
        final controller = FootprintController(repository);
        var notifications = 0;
        controller.addListener(() => notifications++);
        final scanning = controller.scanIdentity('alias_ficticio');
        await repository.scanStarted.future;
        controller.dispose();
        final beforeCompletion = notifications;

        if (fails) {
          repository.scanGate.completeError(StateError('dato_privado'));
        } else {
          repository.scanGate.complete(_profile('resultado_tardío'));
        }
        expect(await scanning, isFalse);
        expect(notifications, beforeCompletion);
        expect(controller.profile, isNull);
        expect(controller.error, isNull);
      },
    );
  }

  test(
    'disposing during preparation stops the scan before calling the repository',
    () async {
      final repository = _ControlledRepository();
      final controller = FootprintController(repository);
      var notifications = 0;
      controller.addListener(() => notifications++);
      final scanning = controller.scanIdentity('alias_ficticio');
      controller.dispose();
      final beforeCompletion = notifications;

      expect(await scanning, isFalse);
      expect(repository.scanCalls, 0);
      expect(notifications, beforeCompletion);
    },
  );

  test(
    'actions after disposal neither call the repository nor change filters',
    () async {
      final repository = _ControlledRepository();
      final controller = FootprintController(repository)..dispose();

      await controller.loadProfile();
      await controller.retry();
      expect(await controller.scanIdentity('alias_ficticio'), isFalse);
      controller.setCategoryFilter(FootprintCategory.dataBroker);

      expect(repository.loadCalls, 0);
      expect(repository.scanCalls, 0);
      expect(controller.selectedCategory, isNull);
    },
  );
}

FootprintProfile _profile(String identity) => FootprintProfile(
  targetIdentity: identity,
  items: [],
  lastScannedAt: DateTime(2026),
);

class _ControlledRepository implements FootprintRepository {
  var loadGate = Completer<FootprintProfile>();
  var scanGate = Completer<FootprintProfile>();
  var scanStarted = Completer<void>();
  int loadCalls = 0;
  int scanCalls = 0;
  final scanIdentities = <String>[];

  @override
  Future<FootprintProfile> getProfile() {
    loadCalls++;
    return loadGate.future;
  }

  @override
  Future<FootprintProfile> scanIdentity(String identity) {
    scanCalls++;
    scanIdentities.add(identity);
    scanStarted.complete();
    return scanGate.future;
  }
}
