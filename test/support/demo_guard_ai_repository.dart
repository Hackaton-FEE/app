import 'package:fee_app/features/footprint/domain/footprint_item.dart';
import 'package:fee_app/features/footprint/domain/footprint_profile.dart';
import 'package:fee_app/features/guard_ai/domain/guard_ai_repository.dart';

/// A deterministic conversation held only in memory, without network or AI.
class DemoGuardAiRepository implements GuardAiRepository {
  FootprintProfile? _footprintContext;

  void setFootprintContext(FootprintProfile? profile) {
    _footprintContext = profile;
  }

  GuardAiConversation _conversation = GuardAiConversation(
    messages: const [
      GuardAiMessage(
        role: GuardAiRole.assistant,
        text:
            'Hola, soy GuardAI. Podemos organizar una revisión de tu privacidad '
            'paso a paso. ¿Qué te gustaría revisar? Puedes elegir una opción o '
            'describir el tema sin compartir datos sensibles.',
      ),
    ],
    suggestions: _startingSuggestions,
  );
  _Topic? _topic;
  int _step = 0;

  static const _startingSuggestions = [
    'Revisar mis datos',
    'Revisar un perfil',
    'Organizar próximos pasos',
    'Quiero preparar un reporte',
  ];

  @override
  Future<GuardAiConversation> loadConversation() async => _conversation;

  @override
  Future<GuardAiConversation> reply(GuardAiInput input) async {
    final text = input.text.toLowerCase();
    late final String response;
    late final List<String> suggestions;

    final wantsReport =
        !text.contains(RegExp(r'\b(no|sin|evitar)\b')) &&
        text.contains(RegExp(r'\b(quiero|necesito|deseo|ayúdame|ayudame)\b')) &&
        text.contains(RegExp(r'\b(reporte|reportar)\b'));
    if (wantsReport) {
      response =
          'Vamos a organizar lo que encontraste. Abre el formulario '
          'de abajo para añadir título, enlace, categoría y notas opcionales. '
          'Podrás revisarlo antes de guardarlo como caso local. '
          'Todavía no lo enviamos a ninguna plataforma ni autoridad.';
      suggestions = ['Empezar otro tema'];
    } else if (text == 'empezar otro tema') {
      _step = 0;
      _topic = null;
      response = 'Podemos empezar por otro tema. ¿Qué te gustaría revisar?';
      suggestions = _startingSuggestions;
    } else if (_step == 0) {
      _topic = _recognizeTopic(text);
      if (_topic == null) {
        if (_footprintContext != null &&
            (text.contains('huella') ||
                text.contains('escaneo') ||
                text.contains('encontraron') ||
                text.contains('encontraste') ||
                text.contains('diagnóstico') ||
                text.contains('diagnostico') ||
                text.contains('ubicaci') ||
                text.contains('donde') ||
                text.contains('dónde') ||
                text.contains('riesgo') ||
                text.contains('resumen'))) {
          final profile = _footprintContext!;
          if (text.contains('ubicaci') ||
              text.contains('donde') ||
              text.contains('dónde')) {
            final locs = profile.items
                .where(
                  (i) => i.exposedData.any((d) => d.startsWith('Ubicación:')),
                )
                .toList();
            if (locs.isNotEmpty) {
              final platforms = locs.map((e) => e.platform).join(', ');
              response =
                  'En tu auditoría para "${profile.targetIdentity}", se detectó ubicación geográfica pública en: $platforms. Te sugerimos revisar o restringir la información de ubicación en dichos perfiles.';
            } else {
              response =
                  'En tu auditoría para "${profile.targetIdentity}" no se detectó una ubicación física precisa expuesta en las cuentas analizadas.';
            }
          } else if (text.contains('riesgo')) {
            final high = profile.items
                .where((i) => i.riskLevel == FootprintRisk.high)
                .toList();
            if (high.isNotEmpty) {
              final names = high.map((e) => e.platform).join(', ');
              response =
                  'Tienes ${high.length} hallazgo(s) de riesgo alto en: $names. Te recomendamos priorizar la auditoría de esas cuentas.';
            } else {
              response =
                  'No se identificaron hallazgos de severidad crítica o alta para "${profile.targetIdentity}". El estado general es estable.';
            }
          } else {
            final riskLabel = profile.overallRisk == FootprintRisk.high
                ? 'Alto'
                : profile.overallRisk == FootprintRisk.medium
                ? 'Medio'
                : 'Bajo';
            final samplePlats = profile.items
                .take(3)
                .map((e) => e.platform)
                .join(', ');
            response =
                'Para "${profile.targetIdentity}", tu Nivel de Exposición es de ${profile.exposureScore}/100 (Riesgo $riskLabel). Detectamos ${profile.items.length} presencias públicas, incluyendo $samplePlats. ¿Deseas preparar un reporte para mitigar alguna?';
          }
          suggestions = [
            'Quiero preparar un reporte',
            'Revisar mis datos',
            'Empezar otro tema',
          ];
        } else {
          response =
              'Para orientarte mejor, por favor selecciona uno de los temas '
              'sugeridos o describe si buscas revisar datos expuestos, auditar un perfil o preparar un caso.';
          suggestions = _startingSuggestions;
        }
      } else {
        _step = 1;
        response = switch (_topic!) {
          _Topic.personalData =>
            'Empecemos por ubicar dónde aparecen los datos que quieres '
                'revisar. ¿En un buscador, en una red social o aún no lo sabes? '
                'No necesitas pegar el enlace ni los datos aquí.',
          _Topic.profile =>
            'Primero distingamos el origen del perfil. ¿Es una cuenta tuya '
                'o un perfil que no reconoces? No hace falta compartir '
                'contraseñas ni nombres.',
          _Topic.plan =>
            'Podemos preparar una lista breve para ti. ¿Quieres revisar '
                'la visibilidad de tus cuentas u organizar algo que ya encontraste?',
        };
        suggestions = switch (_topic!) {
          _Topic.personalData => [
            'En un buscador',
            'En una red social',
            'Aún no lo sé',
          ],
          _Topic.profile => ['Es mi cuenta', 'No reconozco el perfil'],
          _Topic.plan => ['Revisar visibilidad', 'Organizar un hallazgo'],
        };
      }
    } else if (_step == 1) {
      _step = 2;
      response = _nextStep(_topic!, text);
      suggestions = [
        'Preparar una lista',
        'Quiero preparar un reporte',
        'Empezar otro tema',
      ];
    } else {
      response = switch (_topic!) {
        _Topic.personalData =>
          'Tu lista de revisión:\n'
              '1. Identifica la página original y qué datos muestra.\n'
              '2. Si controlas la publicación, ajusta su visibilidad o elimínala. '
              'Si no, revisa las opciones de reporte o contacto de esa página.\n'
              '3. Anota qué cambió y qué sigue pendiente.\n\n'
              'Sigue estos pasos recomendados para proteger tu información en la plataforma afectada.',
        _Topic.profile =>
          'Tu lista de revisión:\n'
              '1. Comprueba la dirección del perfil dentro de la plataforma.\n'
              '2. Si es tu cuenta, revisa su visibilidad, sesiones abiertas y '
              'verificación en dos pasos. Si no la reconoces, usa las opciones '
              'de reporte de la plataforma para señalar una posible suplantación.\n'
              '3. Anota las acciones que decidas realizar.\n\n'
              'Verifica que las configuraciones de seguridad queden guardadas en la plataforma.',
        _Topic.plan =>
          'Tu lista de revisión:\n'
              '1. Elige una cuenta o un hallazgo para empezar.\n'
              '2. Define un cambio concreto que quieras revisar.\n'
              '3. Anota el resultado y el siguiente paso.\n\n'
              'Puedes registrar este seguimiento en tu panel de casos para monitorear el progreso.',
      };
      suggestions = ['Quiero preparar un reporte', 'Empezar otro tema'];
    }

    _conversation = GuardAiConversation(
      messages: [
        ..._conversation.messages,
        GuardAiMessage(role: GuardAiRole.person, text: input.text),
        GuardAiMessage(role: GuardAiRole.assistant, text: response),
      ],
      suggestions: suggestions,
      canPrepareReport: wantsReport,
    );
    return _conversation;
  }

  _Topic? _recognizeTopic(String text) {
    if (text.contains('perfil') || text.contains('cuenta')) {
      return _Topic.profile;
    }
    if (text.contains('dato') || text.contains('buscador')) {
      return _Topic.personalData;
    }
    if (text.contains('paso') ||
        text.contains('organiz') ||
        text.contains('plan')) {
      return _Topic.plan;
    }
    return null;
  }

  String _nextStep(_Topic topic, String text) {
    return switch (topic) {
      _Topic.personalData when text.contains('buscador') =>
        'Un resultado de búsqueda y la página que lo publica son lugares '
            'distintos. El siguiente paso de esta guía es identificar la página '
            'original y revisar sus opciones de contacto o privacidad. '
            '¿Preparamos una lista para seguirlo?',
      _Topic.personalData when text.contains('social') =>
        'En una red social, puedes empezar por revisar quién puede ver '
            'la publicación y qué controles ofrece la plataforma. '
            '¿Preparamos una lista para organizar esa revisión?',
      _Topic.personalData =>
        'Puedes empezar por identificar dónde viste la información, sin '
            'copiarla aquí. Con ese punto de partida, revisa la página original '
            'y sus opciones de privacidad. ¿Preparamos una lista?',
      _Topic.profile when text.contains('no reconozco') =>
        'Un perfil desconocido requiere revisión; este chat no puede '
            'confirmar quién lo controla. Puedes consultar dentro de la '
            'plataforma su ayuda para perfiles que no reconoces. '
            '¿Preparamos una lista con los siguientes pasos?',
      _Topic.profile when text.contains('mi cuenta') =>
        'Para una cuenta tuya, empieza por revisar qué datos son públicos '
            'y las opciones de visibilidad desde la propia plataforma. '
            '¿Preparamos una lista de revisión?',
      _Topic.profile =>
        'Sin confirmar si el perfil es tuyo, la guía puede empezar por '
            'comprobar su dirección en la plataforma y consultar sus opciones '
            'de ayuda. ¿Preparamos una lista de revisión?',
      _Topic.plan when text.contains('visibilidad') =>
        'Empieza por una sola cuenta: revisa qué información es pública y '
            'elige un ajuste de visibilidad que quieras comprobar. '
            '¿Lo organizamos en una lista breve?',
      _Topic.plan =>
        'Elige un hallazgo y anota para ti dónde aparece, qué quieres revisar '
            'y qué acción sigue pendiente. No necesitas contarlo con detalle '
            'aquí. ¿Lo organizamos en una lista breve?',
    };
  }
}

enum _Topic { personalData, profile, plan }
