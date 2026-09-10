import 'package:flutter/material.dart';

import '../../../../app/palette.dart';
import '../../../cases/presentation/case_form_page.dart';
import '../../../cases/presentation/cases_controller.dart';

class ReportPrompt extends StatelessWidget {
  const ReportPrompt({
    required this.controller,
    this.enabled = true,
    super.key,
  });

  final CasesController controller;
  final bool enabled;

  Future<void> _open(BuildContext context) async {
    final caseId = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: AiReportFrame(
          child: SizedBox(
            width: 600,
            height: MediaQuery.sizeOf(context).height * .82,
            child: CaseFormPage(controller: controller),
          ),
        ),
      ),
    );
    if (caseId != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppPalette.success,
          content: Text(
            'Caso guardado en este dispositivo. No se ha enviado.',
            style: TextStyle(color: AppPalette.black),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: AiReportFrame(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(
                'Preparemos tu reporte',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Revisa los detalles en un formulario flotante. Se guarda como caso local; no se envía desde esta demostración.',
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: enabled ? () => _open(context) : null,
              icon: const Icon(Icons.open_in_new_rounded),
              label: const Text('Abrir formulario de reporte'),
            ),
          ],
        ),
      ),
    ),
  );
}

class AiReportFrame extends StatelessWidget {
  const AiReportFrame({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final highContrast = MediaQuery.highContrastOf(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 700),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: ColoredBox(color: colors.surface, child: child),
      ),
      builder: (context, progress, child) => Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(23),
          gradient: LinearGradient(
            begin: Alignment(-1, 1 - progress * 2),
            end: Alignment(1, progress * 2 - 1),
            colors: highContrast
                ? [colors.primary, colors.primary]
                : const [
                    AppPalette.deepOlive,
                    AppPalette.olive,
                    AppPalette.warmKhaki,
                    AppPalette.sandGold,
                    AppPalette.paleCream,
                  ],
          ),
          boxShadow: highContrast
              ? []
              : [
                  BoxShadow(
                    color: colors.primary.withValues(alpha: .18 * progress),
                    blurRadius: 24,
                    spreadRadius: 2,
                  ),
                ],
        ),
        child: child,
      ),
    );
  }
}
