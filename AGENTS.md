# Instrucciones para agentes

Este repositorio privado, `Hackaton-FEE/app`, contiene el cliente Flutter. Lee [la arquitectura](docs/architecture.md) antes de cambiar comportamiento y aplica estas reglas según la tarea:

- [Colaboración](rules/01-collaboration.md): ramas, alcance autorizado y revisión.
- [Producto y datos](rules/02-product-and-data.md): alcance local y tratamiento de información.
- [Calidad](rules/03-quality.md): validaciones y evidencia para el PR.
- [Accesibilidad y atención](rules/04-accessibility-and-user-care.md): semántica, orientación, recuperación de errores y pruebas con tecnologías de asistencia.

Las skills canónicas están en `skills/`. Abre explícitamente el archivo que corresponda cuando trabajes con IA:

- [flutter-feature](skills/flutter-feature/SKILL.md): pantallas, interacción, estado y comportamiento Flutter.
- [api-contract](skills/api-contract/SKILL.md): propuesta o integración del contrato con `Hackaton-FEE/server`.

El cliente usa Flutter 3.47.2 y Dart 3.13.2, con destino Android e iOS. Gestiona casos locales con título, URL, categoría y notas; permite editar, buscar, archivar, restaurar y eliminar. Conserva un registro JSON versión 1 por caso mediante `flutter_secure_storage` 10.3.2. No conecta al backend ni recibe imágenes o envía reportes.

Mantén el `ChangeNotifier` existente para presentación, modelos inmutables y un repositorio asíncrono como fuente de verdad, inyectado por constructor. El adaptador de almacenamiento aísla el plugin nativo. Una operación solo se confirma cuando termina la persistencia; un error o dato corrupto no debe convertirse en éxito ni provocar un reset automático. Consulta [cómo verificar estos comportamientos](docs/testing.md).

El bootstrap inicial en `main` está autorizado; el trabajo posterior sigue [el flujo de PR](docs/workflow.md). Continúa las acciones cubiertas por la tarea y su autorización existente. Estas instrucciones no añaden una confirmación para cada edición, prueba o acción ya autorizada.
