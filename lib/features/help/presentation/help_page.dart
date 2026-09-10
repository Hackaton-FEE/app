import 'package:flutter/material.dart';

class HelpPage extends StatelessWidget {
  const HelpPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ayuda de uso')),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: const SingleChildScrollView(
              padding: EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _HelpSection(
                    title: 'Elige una cuenta y conoce la app',
                    body: 'Al abrir la app, elige la cuenta disponible para entrar. No se verifica un inicio de sesión. Si no se puede cargar, pulsa Reintentar.\n\nDesde el dashboard puedes abrir el recorrido visual. Cerrar sesión vuelve al inicio; el chat dura esta sesión.',
                  ),
                  _HelpSection(
                    title: 'Conversa con GuardAI',
                    body:
                        'El botón GuardAI abre una conversación de demostración. Escribe una pregunta o elige una sugerencia y continúa con las respuestas. Cada cuenta de ejemplo tiene su propio chat durante esta sesión.\n\n'
                        'Las respuestas siguen un recorrido local de ejemplo: no hay un modelo de IA conectado, búsquedas externas ni envío de solicitudes. El chat conserva lo que escribes al abrir ayuda o volver al dashboard.',
                  ),
                  _HelpSection(
                    title: 'Explora tu huella digital',
                    body:
                        'El dashboard muestra hallazgos simulados para que pruebes el recorrido. Escanear cambia la identidad del ejemplo; no busca cuentas ni confirma filtraciones reales. El índice es orientativo, no una probabilidad de sufrir un incidente.\n\n'
                        'En Lista o Mapa puedes explorar categorías y abrir cada hallazgo. GuardAI te permite conversar sobre tus siguientes pasos. Abre el menú de perfil para consultar los casos del dispositivo o el historial de escaneos. Escanear cambia la identidad del ejemplo. Los escaneos del historial con más de 72 horas se eliminan al cargar o guardar el historial; no hay borrado en segundo plano. La identidad del ejemplo se conserva solo durante esta sesión.',
                  ),
                  _HelpSection(
                    title: 'Organiza un caso a tu ritmo',
                    body:
                        'En Nuevo caso, escribe un título, pega el enlace del contenido y elige un tipo de situación. Las notas son opcionales: escribe solo lo que quieras conservar.\n\n'
                        'Pulsa Guardar caso y espera la confirmación. Podrás consultarlo y editarlo desde Mis casos. Abrir esta ayuda conserva el formulario mientras sigues en la app.',
                  ),
                  _HelpSection(
                    title: 'Archivar, restaurar o eliminar',
                    body:
                        'Archivar mueve el caso a Archivo. Puedes restaurarlo para volver a verlo en Activos.\n\n'
                        'Eliminar borra el enlace y las notas de la app después de tu confirmación. No se puede deshacer. Ninguna de estas acciones retira contenido de otros sitios.',
                  ),
                  _HelpSection(
                    title: 'Dónde se guarda tu información',
                    body:
                        'Los casos guardados permanecen en este dispositivo y no se envían a terceros. Son compartidos por las cuentas de ejemplo; cambiar de cuenta no los mueve ni los separa. La app usa almacenamiento cifrado, pero no tiene un bloqueo propio: quien pueda abrir la app podrá ver tus casos.\n\n'
                        'No hay sincronización ni recuperación garantizada si borras los datos de la app o cambias de dispositivo. Los cambios del formulario solo se conservan entre sesiones cuando pulsas Guardar caso.',
                  ),
                  _HelpSection(
                    title: 'Si no puedes guardar o cargar',
                    body:
                        'Si aparece un error en un campo, sigue la indicación junto a él y vuelve a guardar. Si falla el guardado, el formulario conserva lo que escribiste mientras permanece abierto.\n\n'
                        'Si el almacenamiento no está disponible, comprueba que el dispositivo esté desbloqueado y vuelve a intentar la acción. Evita borrar la app o sus datos para resolver un error: podrías perder los casos guardados.',
                  ),
                  _HelpSection(
                    title: 'Qué ayuda está disponible',
                    body: 'Esta guía explica cómo usar la app. Esta versión todavía no tiene un canal de atención humana ni envío de solicitudes de retiro. Guardar un caso no inicia una gestión con una plataforma.',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HelpSection extends StatelessWidget {
  const _HelpSection({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(title, style: Theme.of(context).textTheme.titleLarge),
          ),
          const SizedBox(height: 12),
          Text(body),
        ],
      ),
    );
  }
}
