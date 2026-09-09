import 'package:flutter/material.dart';

import '../domain/source_link.dart';

class NewCasePage extends StatefulWidget {
  const NewCasePage({super.key});

  @override
  State<NewCasePage> createState() => _NewCasePageState();
}

class _NewCasePageState extends State<NewCasePage> {
  final _formKey = GlobalKey<FormState>();
  final _urlController = TextEditingController();

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  void _save() {
    if (_formKey.currentState!.validate()) {
      Navigator.of(context).pop(parseSourceLink(_urlController.text));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nuevo borrador')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  Text(
                    'Empieza por el enlace',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Usa un enlace de ejemplo para probar el flujo. '
                    'Este prototipo no abre el contenido ni envía reportes.',
                  ),
                  const SizedBox(height: 28),
                  TextFormField(
                    controller: _urlController,
                    keyboardType: TextInputType.url,
                    textInputAction: TextInputAction.done,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: const InputDecoration(
                      labelText: 'Enlace del contenido',
                      hintText: 'https://example.com/publicacion',
                      prefixIcon: Icon(Icons.link),
                      errorMaxLines: 3,
                    ),
                    validator: (value) {
                      try {
                        parseSourceLink(value ?? '');
                        return null;
                      } on FormatException catch (error) {
                        return error.message;
                      }
                    },
                    onFieldSubmitted: (_) => _save(),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _save,
                    icon: const Icon(Icons.add_task),
                    label: const Text('Crear borrador'),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'El borrador se perderá al cerrar la app. '
                    'No adjuntes imágenes ni datos sensibles.',
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
