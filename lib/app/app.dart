import 'package:flutter/material.dart';

import '../features/cases/data/in_memory_case_repository.dart';
import '../features/cases/presentation/cases_controller.dart';
import '../features/cases/presentation/cases_page.dart';
import 'theme.dart';

class FeeApp extends StatefulWidget {
  const FeeApp({super.key});

  @override
  State<FeeApp> createState() => _FeeAppState();
}

class _FeeAppState extends State<FeeApp> {
  late final CasesController _cases = CasesController(InMemoryCaseRepository());

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
      home: CasesPage(controller: _cases),
    );
  }
}
