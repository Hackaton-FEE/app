import 'package:fee_app/features/footprint/domain/footprint_item.dart';
import 'package:fee_app/features/footprint/domain/footprint_profile.dart';
import 'package:fee_app/features/guard_ai/domain/guard_ai_profile_report.dart';

class DemoGuardAiProfileReport extends GuardAiProfileReport {
  DemoGuardAiProfileReport._({
    required super.identity,
    required super.high,
    required super.medium,
    required super.low,
    required super.summary,
    required super.recommendation,
    required super.action,
    required super.sections,
    bool isDemo = false,
  }) : super(
         sourceNote: isDemo ? 'Datos ficticios de prueba.' : 'Datos de prueba.',
       );
  String get nextSteps => action == null
      ? 'No hay una acción prioritaria en los datos disponibles. Mantén tus ajustes de privacidad y revisa tu perfil cuando cambie tu información.'
      : 'Para empezar con el perfil $identity:\n\n'
            '1. $recommendation\n'
            '2. Si necesitas ayuda para retirar tus datos, solicítala en el chat.\n'
            '3. Si quieres llevar un registro, pide preparar un reporte.\n\n'
            'En esta demostración el proceso es simulado y no modifica cuentas externas.';

  String get explanation =>
      'Estas prioridades ayudan a organizar la revisión:\n\n'
      'Alta ($high): empieza por estos hallazgos.\n'
      'Media ($medium): conviene revisar la información visible y sus permisos.\n'
      'Baja ($low): son ajustes de mantenimiento.\n\n'
      'Un hallazgo es información que aparece en el perfil cargado, no un ataque confirmado. '
      '$sourceNote';

  factory DemoGuardAiProfileReport.demoUser(
    String username,
  ) => DemoGuardAiProfileReport._(
    identity: username,
    isDemo: true,
    high: 0,
    medium: 2,
    low: 1,
    summary:
        'En esta simulación, el perfil $username presenta 2 posibles problemas de privacidad y 1 ajuste de baja prioridad. Te explicamos qué revisar.',
    sections: const [
      GuardAiReportSection(
        'Publicaciones visibles · 1',
        'En el ejemplo, otras personas pueden ver tus publicaciones. Te recomendamos limitar su audiencia a personas que conoces.',
      ),
      GuardAiReportSection(
        'Datos de contacto · 1',
        'Simulamos que tu contacto aparece en la biografía. Revisa si necesitas mostrarlo y quién puede verlo.',
      ),
      GuardAiReportSection(
        'Información de la biografía · 1',
        'Como ajuste adicional, evita compartir rutinas o ubicaciones habituales en tu perfil.',
      ),
    ],
    recommendation: 'Empieza por revisar la audiencia de tus publicaciones y la visibilidad de tus datos de contacto.',
    action: 'Revisar la visibilidad de mi perfil',
  );

  factory DemoGuardAiProfileReport.fromProfile(FootprintProfile profile) {
    final items = [...profile.items]
      ..sort((a, b) {
        final risk = b.riskLevel.index.compareTo(a.riskLevel.index);
        return risk != 0 ? risk : b.category.index.compareTo(a.category.index);
      });
    final priority = profile.highRiskCount + profile.mediumRiskCount;
    final summary = items.isEmpty
        ? 'No hay hallazgos registrados para este perfil. Esto no garantiza que no existan riesgos; solo indica que no hay información disponible para esta revisión.'
        : priority == 0
        ? 'Hay ${items.length} hallazgos de baja prioridad. No hay problemas de prioridad alta o media en los datos disponibles; puedes enfocarte en mantener tus ajustes de privacidad.'
        : 'Se detectaron $priority posibles problemas de privacidad entre ${items.length} hallazgos de tu perfil. '
              '${profile.highRiskCount} tienen prioridad alta y ${profile.mediumRiskCount} prioridad media. Vamos a revisarlos paso a paso.';
    final sections = <GuardAiReportSection>[];
    for (final category in items.map((item) => item.category).toSet()) {
      final matches = items.where((item) => item.category == category).toList();
      final sites = matches.take(2).map((item) => item.platform).join(', ');
      final (title, meaning) = switch (category) {
        FootprintCategory.dataBreach => (
          'Posibles filtraciones',
          'Hay indicios de exposición de datos de acceso. Conviene revisar contraseñas reutilizadas y activar la verificación en dos pasos.',
        ),
        FootprintCategory.dataBroker => (
          'Datos en directorios',
          'Estos sitios pueden agrupar información personal. Revisa qué muestran y sus opciones para solicitar el retiro.',
        ),
        FootprintCategory.exposedContact => (
          'Datos de contacto visibles',
          'Tu correo o teléfono puede estar asociado a servicios públicos. Revisa quién puede encontrarte con esos datos.',
        ),
        FootprintCategory.socialProfile => (
          'Información pública',
          'Parte de tu perfil es visible para otras personas. Revisa la audiencia de tus publicaciones y tu biografía.',
        ),
      };
      sections.add(
        GuardAiReportSection('$title · ${matches.length}', '$sites. $meaning'),
      );
    }
    final action = priority == 0
        ? null
        : switch (items.first.category) {
            FootprintCategory.dataBreach =>
              'Revisar contraseñas y verificación en dos pasos',
            FootprintCategory.dataBroker =>
              'Revisar las opciones de retiro de mis datos',
            FootprintCategory.exposedContact =>
              'Revisar la visibilidad de mis datos de contacto',
            FootprintCategory.socialProfile =>
              'Revisar la visibilidad de mi perfil',
          };
    return DemoGuardAiProfileReport._(
      identity: profile.targetIdentity,
      high: profile.highRiskCount,
      medium: profile.mediumRiskCount,
      low: profile.lowRiskCount,
      summary: summary,
      sections: sections,
      action: action,
      recommendation: action == null
          ? 'Mantén contraseñas únicas y revisa periódicamente lo que compartes.'
          : 'Empieza por ${items.first.platform}: ${action.toLowerCase()}.',
    );
  }
}
