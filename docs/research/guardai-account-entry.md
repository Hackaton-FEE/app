# Selector de cuentas y GuardAI

Entrega local del 9 de septiembre de 2026. La navegación se amplía sobre el dashboard que estaba en desarrollo, conservando los casos locales y su persistencia.

## Comportamiento

- Al abrir, el selector ofrece dos cuentas ficticias. Un toque entra al dashboard sin formulario, contraseñas ni autenticación. «Usar otra cuenta» agrega otro ejemplo y entra directamente. Una lista vacía ofrece «Crear una cuenta».
- Al deslizar hacia abajo, el mismo inicio presenta la propuesta de la app, tres pasos de uso y GuardAI. «Descubre Osisn't» lleva a esa sección; reducir movimiento elimina la transición.
- El menú de perfil permite cambiar de cuenta. Cada cuenta mantiene su propio análisis de ejemplo, conversación y borrador mientras la app sigue ejecutándose. Una fábrica inyectable crea un repositorio de huella por cuenta para evitar compartir su estado mutable.
- GuardAI sustituye la acción principal «Crear caso» y la recomendación del dashboard. Su conversación itera con respuestas y sugerencias predefinidas hasta proponer una lista de siguientes pasos. La página conserva el borrador al volver o abrir ayuda y permite reintentar fallos.
- Las cuentas agregadas y chats solo viven en memoria. No hay conexión de autenticación, IA, Google ni consultas externas. Los casos anteriores siguen disponibles como «Casos del dispositivo», compartidos entre las cuentas de demostración; no se reasignan ni migran.

## Evidencia visual

Capturas renderizadas en pruebas de widgets a **390 × 844 unidades lógicas, DPR 2**, con fuentes del SDK y datos ficticios. Son vistas de prueba, no capturas de un dispositivo ni evidencia de TalkBack/VoiceOver.

- [Selector de cuentas](../images/account-picker-preview.png).
- [Presentación al deslizar](../images/account-marketing-preview.png).
- [GuardAI después de una respuesta](../images/guardai-chat-preview.png).

## Validación

- Dependencias: `flutter pub get --enforce-lockfile`, sin nuevas dependencias.
- Formato: `dart format --output=none --set-exit-if-changed lib test integration_test`, sin cambios pendientes.
- Análisis: `flutter analyze`, sin incidencias.
- Suite completa: `flutter test --no-pub`, **141 pruebas aprobadas**.
- Android: `flutter build apk --debug`, compilación correcta.
- Pruebas de cuentas: entrada directa, agregar y elegir otra, estado inicial al recrear la app, aislamiento de identidad analizada, chat y borrador por cuenta, fallos y respuestas diferidas sin éxito anticipado.
- Pruebas de GuardAI: conversación iterativa, campos vacíos/límites, respuesta fallida conservando texto, carga fallida y recuperación, ayuda y vuelta al chat.
- Accesibilidad de widgets: controles etiquetados, contraste, objetivos Android/iOS, encabezados, navegación con Tab/Enter y recuperación de errores; selector y contenido desplazado a 320 × 640 con texto al 200 %, y chat con teclado visible.

No se ejecutó integración del plugin nativo, cierre/reapertura en un dispositivo, build iOS, TalkBack, VoiceOver ni evaluación con personas para esta entrega. El formato y el adaptador persistente de casos no cambian. Las pruebas automáticas no demuestran conformidad global de accesibilidad.
