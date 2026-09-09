---
name: flutter-feature
description: Implementar o revisar pantallas, interacción y lógica del cliente Flutter de Hackaton-FEE/app respetando el alcance de la demo y su arquitectura. Usar para cambios del cliente; usar api-contract cuando cambie su comunicación con el servidor.
---

# Cambios Flutter

Lee [arquitectura](../../docs/architecture.md) y [producto y datos](../../rules/02-product-and-data.md). Confirma qué comportamiento debe observar el usuario y conserva el resto del alcance actual.

Trabaja en la capa afectada: `lib/app/` para composición y tema; `lib/features/cases/domain/` para reglas y contratos; `data/` para el repositorio en memoria; `presentation/` para controladores y pantallas. Evita añadir paquetes de estado o red para resolver una tarea local.

Los borradores desaparecen al reiniciar: no presentes persistencia, conexión al servidor o envío real como funciones existentes. Maneja validación y errores sin registrar la URL ni otros datos personales.

Para cambios de comportamiento, verifica entrada válida e inválida y el resultado visible pertinente con pruebas unitarias o de widgets. Ejecuta las verificaciones aplicables de [calidad](../../rules/03-quality.md). Para cambios de diseño, inspecciona la pantalla y su legibilidad en tamaño móvil.

Entrega un diff acotado y explica comportamiento, pruebas y límites de plataforma. Aplica [el flujo de PR](../../docs/workflow.md) dentro de la autorización de la tarea; no agregues una aprobación extra para las ediciones ya autorizadas.
