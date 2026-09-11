import '../domain/guard_ai_repository.dart';

/// Explicit, local demonstration. Never reads a real profile or calls a service.
class SampleGuardAiRepository implements GuardAiRepository {
  static const review = 'Revisar mi perfil';
  static const help = 'Ayúdame con una recomendación';
  static const plan = 'Preparar un plan de privacidad';
  static const action = 'Revisar la visibilidad del perfil de muestra';

  GuardAiConversation _conversation = GuardAiConversation(
    isSimulation: true,
    messages: const [
      GuardAiMessage(
        role: GuardAiRole.person,
        text: 'Hola, quiero entender qué muestra mi perfil de prueba.',
      ),
      GuardAiMessage(
        role: GuardAiRole.assistant,
        text:
            'Hola. Soy GuardAI en modo de muestra. Usaremos el perfil ficticio '
            '@cliente.demo. Toca «Revisar mi perfil» en acciones rápidas para '
            'ver el análisis y después pide ayuda para probar una recomendación.',
      ),
    ],
  );

  @override
  Future<GuardAiConversation> loadConversation() async => _conversation;

  @override
  Future<GuardAiConversation> reply(GuardAiInput input) async {
    final text = input.text.toLowerCase();
    final asksHelp = text.contains('ayúdame') || text.contains('ayudame');
    final asksProfile = text.contains('perfil') || text.contains('analiza');
    final response = asksHelp
        ? 'Podemos practicar la revisión de visibilidad de @cliente.demo. '
              'Acepta para ver los pasos, pospón para guardar tu preferencia '
              'durante esta sesión o rechaza para seguir conversando. '
              'La simulación no cambia ninguna cuenta.'
        : asksProfile
        ? 'Análisis de muestra · @cliente.demo\n\n'
              'En este escenario ficticio hay una biografía pública con ciudad, '
              'un enlace de contacto y un alias reutilizado. No son hallazgos '
              'de tu cuenta ni resultados de un escaneo.\n\n'
              'Asesoría del ejemplo:\n'
              '1. Comprueba qué información quieres mantener pública.\n'
              '2. Revisa quién puede ver las publicaciones y el contacto.\n'
              '3. Anota los cambios pendientes y verifica cada ajuste.\n\n'
              'Pide «Ayúdame con una recomendación» para practicar el siguiente paso.'
        : text.contains('plan')
        ? 'Plan de muestra\n\n'
              '1. Revisa un hallazgo en Lista o Mapa.\n'
              '2. Comprueba las relaciones en el mapa de nexos; una coincidencia '
              'no confirma titularidad.\n'
              '3. Consulta el historial y decide qué quieres revisar primero.\n\n'
              'Podemos practicar la revisión de privacidad desde «Ayúdame con una recomendación».'
        : 'Esta conversación usa respuestas de muestra. Puedes revisar el '
              'perfil ficticio, preparar un plan o pedir ayuda con una recomendación '
              'desde el botón de acciones rápidas.';
    _conversation = GuardAiConversation(
      isSimulation: true,
      messages: [
        ..._conversation.messages,
        GuardAiMessage(role: GuardAiRole.person, text: input.text),
        GuardAiMessage(
          role: GuardAiRole.assistant,
          text: response,
          recommendedAction: asksHelp ? action : null,
        ),
      ],
    );
    return _conversation;
  }
}
