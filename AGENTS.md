# Instrucciones para agentes

Este repositorio privado, `Hackaton-FEE/app`, contiene el cliente Flutter. Lee [la arquitectura](docs/architecture.md) antes de cambiar comportamiento y aplica estas reglas según la tarea:

- [Colaboración](rules/01-collaboration.md): ramas, alcance autorizado y revisión.
- [Producto y datos](rules/02-product-and-data.md): límites de la demo y tratamiento de información.
- [Calidad](rules/03-quality.md): validaciones y evidencia para el PR.

Las skills canónicas están en `skills/`. Abre explícitamente el archivo que corresponda cuando trabajes con IA:

- [flutter-feature](skills/flutter-feature/SKILL.md): pantallas, interacción, estado y comportamiento Flutter.
- [api-contract](skills/api-contract/SKILL.md): propuesta o integración del contrato con `Hackaton-FEE/server`.

El contexto inicial es Flutter 3.47.2 y Dart 3.13.2, con destino Android e iOS. La demo actual mantiene borradores en memoria: no conecta al backend, no persiste datos ni envía solicitudes reales. No conviertas funciones futuras en requisitos del scaffold.

El bootstrap inicial en `main` está autorizado; el trabajo posterior sigue [el flujo de PR](docs/workflow.md). Continúa las acciones cubiertas por la tarea y su autorización existente. Estas instrucciones no añaden una confirmación para cada edición, prueba o acción ya autorizada.
