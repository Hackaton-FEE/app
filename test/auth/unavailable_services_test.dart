import 'package:fee_app/app/theme.dart';
import 'package:fee_app/features/auth/data/auth_api_client.dart';
import 'package:fee_app/features/auth/data/backend_auth_repository.dart';
import 'package:fee_app/features/auth/domain/session_info.dart';
import 'package:fee_app/features/auth/domain/scan_capability.dart';
import 'package:fee_app/features/auth/presentation/widgets/active_sessions_dialog.dart';
import 'package:fee_app/features/auth/presentation/widgets/scan_capabilities_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _UnavailableAuth implements AuthRepository {
  @override
  Future<List<SessionInfo>> getSessions() async =>
      throw const AuthApiException(message: 'Unavailable');
  @override
  Future<List<ScanCapabilityProvider>> getScanCapabilities() async =>
      throw const AuthApiException(message: 'Unavailable');
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('failed session list never invents a current hardware session', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          body: ActiveSessionsDialog(authRepository: _UnavailableAuth()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('La lista de sesiones no está disponible en el servidor.'),
      findsOneWidget,
    );
    expect(find.text('Esta sesión (actual)'), findsNothing);
    expect(find.textContaining('hardware'), findsNothing);
  });

  testWidgets('failed capabilities never list engines as available', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          body: ScanCapabilitiesDialog(authRepository: _UnavailableAuth()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('El catálogo de motores no está disponible en el servidor.'),
      findsOneWidget,
    );
    expect(find.text('Disponible'), findsNothing);
    expect(find.textContaining('Blackbird'), findsNothing);
  });
}
