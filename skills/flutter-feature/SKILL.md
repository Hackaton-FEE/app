---
name: flutter-feature
description: Implementar o revisar pantallas, estado y casos locales persistentes de Hackaton-FEE/app respetando la separación entre dominio, repositorio y presentación Flutter. Usar api-contract cuando cambie su comunicación con el servidor.
---

# Cambios Flutter

Lee [arquitectura](../../docs/architecture.md) y [producto y datos](../../rules/02-product-and-data.md). Confirma qué comportamiento debe observar el usuario y conserva el resto del alcance actual.

Para interacción aplica [accesibilidad y atención](../../rules/04-accessibility-and-user-care.md): etiquetas persistentes, roles y encabezados, foco visible al corregir, ayuda consistente y salida sin pérdida inadvertida. Evita salir o abrir otra ruta mientras se confirma un guardado y habilita la navegación al terminar. Usa las pruebas de `test/accessibility/` como base; no presentes sus resultados como certificación ni como recorrido real de lector de pantalla.

Trabaja en la capa afectada: `lib/app/` para composición por constructor y tema; `lib/features/cases/domain/` para modelos inmutables, reglas y contratos; `data/` para el repositorio asíncrono y adaptador de almacenamiento; `presentation/` para `ChangeNotifier` y pantallas. Conserva esas responsabilidades sin agregar capas o paquetes de estado por rutina.

El repositorio es la fuente de verdad y se compone una sola instancia: serializa sus propias operaciones, pero no escritores en otros procesos. Las pantallas no manejan JSON, claves del plugin ni copias mutables de los casos. Distingue el estado de carga del estado local borrador/archivado.

Confirma una mutación solo después de persistir. Si falla, mantén el formulario o estado recuperable y muestra un mensaje sin URL ni notas. Un JSON corrupto o desconocido debe conservarse y producir un error; no soluciones la carga reseteando datos. La persistencia no implica conexión al servidor, bloqueo propio, conocimiento cero ni envío externo.

Prueba entradas válidas e inválidas, el efecto visible y fallos relevantes con dobles de almacenamiento. Si cambias persistencia, incluye recreación del repositorio; para el plugin o configuración nativa sigue [la guía de pruebas](../../docs/testing.md). No declares reinicio real basándote en recrear objetos. Ejecuta [calidad](../../rules/03-quality.md) e inspecciona las pantallas afectadas en tamaño móvil.

Entrega un diff acotado y explica comportamiento, pruebas y límites de plataforma. Aplica [el flujo de PR](../../docs/workflow.md) dentro de la autorización de la tarea; no agregues una aprobación extra para las ediciones ya autorizadas.
