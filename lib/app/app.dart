import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../features/cases/data/flutter_secure_case_storage.dart';
import '../features/cases/data/local_case_repository.dart';
import '../features/cases/domain/case_repository.dart';
import '../features/cases/presentation/cases_controller.dart';
import '../features/cases/presentation/cases_page.dart';
import 'theme.dart';

class FeeApp extends StatefulWidget {
  const FeeApp({this.repository, super.key});

  final CaseRepository? repository;

  @override
  State<FeeApp> createState() => _FeeAppState();
}

class _FeeAppState extends State<FeeApp> {
  late final CasesController _cases;

  @override
  void initState() {
    super.initState();
    _cases = CasesController(
      widget.repository ??
          LocalCaseRepository(storage: FlutterSecureCaseStorage()),
    );
    unawaited(_cases.load());
  }

  @override
  void dispose() {
    _cases.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Privacidad FEE',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      locale: const Locale('es'),
      supportedLocales: const [Locale('es')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: CasesPage(controller: _cases),
    );
  }
}
