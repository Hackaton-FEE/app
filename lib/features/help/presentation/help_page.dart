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
                    title: 'Cuentas y acceso',
                    body: 'Al abrir la app, selecciona la cuenta disponible para entrar o inicia sesión. Si no se puede cargar, pulsa Reintentar.\n\nDesde el dashboard puedes abrir el recorrido guiado o explorar tu huella digital. Cerrar sesión te permite alternar de cuenta de forma segura.',
                  ),
                  _HelpSection(
                    title: 'Conversa con GuardAI',
                    body:
                        'El botón GuardAI abre el asistente de privacidad interactivo. Escribe una pregunta o elige una sugerencia para recibir una guía paso a paso adaptada a tu situación.\n\n'
                        'GuardAI te asiste en la mitigación de exposiciones y en la organización de tus casos. El chat conserva lo que escribes al abrir ayuda o volver al dashboard.',
                  ),
                  _HelpSection(
                    title: 'Explora tu huella digital',
                    body:
                        'El dashboard presenta el diagnóstico de exposición de tu identidad digital. Escanear te permite auditar un correo o alias para detectar datos públicos indexados o filtraciones.\n\n'
                        'En Lista o Mapa puedes explorar categorías y abrir cada hallazgo para conocer los datos expuestos y las acciones de mitigación recomendadas. Abre el menú lateral para consultar el historial de escaneos (los registros con más de 72 horas se depuran automáticamente al actualizar).',
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
                        'Los casos guardados permanecen en este dispositivo mediante almacenamiento cifrado local y no se comparten con terceros. La app resguarda tus casos localmente.\n\n'
                        'Los cambios del formulario se conservan entre sesiones cuando pulsas Guardar caso.',
                  ),
                  _HelpSection(
                    title: 'Si no puedes guardar o cargar',
                    body:
                        'Si aparece un error en un campo, sigue la indicación junto a él y vuelve a guardar. Si falla el guardado, el formulario conserva lo que escribiste mientras permanece abierto.\n\n'
                        'Si el almacenamiento no está disponible, comprueba que el dispositivo esté desbloqueado y vuelve a intentar la acción.',
                  ),
                  _HelpSection(
                    title: 'Qué ayuda está disponible',
                    body: 'Esta guía explica cómo usar la app. Puedes apoyarte en GuardAI para resolver dudas sobre privacidad o registrar casos para seguimiento.',
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
