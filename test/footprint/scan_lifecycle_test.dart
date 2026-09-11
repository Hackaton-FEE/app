import 'package:fee_app/app/app.dart';
import 'package:fee_app/features/cases/data/local_case_repository.dart';
import 'package:fee_app/features/footprint/data/local_scan_history_repository.dart';
import 'package:fee_app/features/footprint/domain/footprint_profile.dart';
import 'package:fee_app/features/footprint/domain/resumable_footprint_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../data/fake_case_storage.dart';
import '../support/demo_account_repository.dart';
import '../support/demo_guard_ai_repository.dart';
import '../support/mock_footprint_repository.dart';
import '../support/ready_identity_repository.dart';
import 'fake_scan_history_storage.dart';

class RecoverableRepository extends MockFootprintRepository
    implements ResumableFootprintRepository {
  final foreground = <bool>[];
  int resumes = 0;
  @override
  void setForeground(bool value) => foreground.add(value);
  @override
  Future<FootprintProfile?> resumePendingScan() async {
    resumes++;
    return null;
  }

  @override
  Future<void> acknowledgeScan(String scanId) async {}
}

void main() {
  testWidgets('dashboard resumes pending scan after background lifecycle', (
    tester,
  ) async {
    final repo = RecoverableRepository();
    await tester.pumpWidget(
      FeeApp(
        guardAiRepositoryFactory: (_) => DemoGuardAiRepository(),
        identityProfileRepository: ReadyIdentityRepository(),
        accountRepository: DemoAccountRepository(),
        repository: LocalCaseRepository(storage: FakeCaseStorage()),
        footprintRepositoryFactory: (_) => repo,
        scanHistoryRepositoryFactory: (_) =>
            LocalScanHistoryRepository(storage: FakeScanHistoryStorage()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('account-demo-personal')));
    await tester.pumpAndSettle();
    final initialResumes = repo.resumes;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(repo.foreground.last, isFalse);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(repo.foreground.last, isTrue);
    expect(repo.resumes, initialResumes + 1);
    expect(tester.takeException(), isNull);
  });
}
