# Mejora de calidad del prototipo

Esta entrega conserva Flutter/Dart, `ChangeNotifier`, la inyección por constructor
y el almacenamiento local de casos. El alcance es corregir los problemas de la
revisión de software y simplificar su mantenimiento. No incorpora autenticación,
backend ni servicios de IA.

## Fases y aceptación

1. **Estado y recuperación.** Sincronizar la búsqueda al reabrir casos; recuperar
   una carga fallida desde el formulario sin perder lo escrito; proteger las
   colecciones de huella; impedir operaciones solapadas y notificaciones después
   de destruir el controlador. Cada defecto se acompaña de una regresión que
   comprueba el comportamiento corregido.
2. **Organización de pantallas.** Mantener cada archivo Dart de producción bajo
   `lib/` en un máximo de 350 líneas. Extraer secciones con responsabilidad propia
   y conservar juntos los componentes privados pequeños. Mantener navegación,
   contenido, semántica y distribución adaptable.
3. **Trabajo por actualización y controles de calidad.** Construir historiales y
   hallazgos bajo demanda, aislar la escritura del borrador del historial del chat,
   compartir la representación de riesgos y el orden de casos, y evitar ordenar
   colecciones cuando la operación no lo necesita. Comprobar el límite de tamaño
   en CI y ejecutar las verificaciones del cliente.

Las fases se registran en commits separados. El criterio de extracción es la
responsabilidad del componente; no se introducen clases de casos de uso,
localizadores de servicios ni un archivo por control visual.

## Límites de escalabilidad

La lectura completa del almacenamiento antes de una mutación permite detectar un
registro corrupto en cualquier caso y bloquear la escritura sin modificar los
datos. Se conserva ese contrato. Quitar ordenamientos innecesarios reduce trabajo,
pero no convierte el adaptador en una base de datos con consultas o paginación.
Para aumentar sustancialmente el volumen se necesita medir con datos
representativos y diseñar una migración explícita.

El límite de 350 líneas se aplica al código de producción escrito a mano, incluidos
comentarios y líneas vacías. Las pruebas y archivos generados tienen otra función;
no se fragmentan solo para cumplir ese número.

## Evidencia de entrega

Fase 1: formato y análisis sin incidencias; 157 pruebas unitarias/de widgets
aprobadas, incluidas las regresiones de recuperación y ciclo de vida. El formulario
con recuperación se comprobó a 320 × 640 y texto al 200 % mediante pruebas de
widgets y guidelines. La [captura del formulario](images/quality-case-recovery.png)
es un render de widget Flutter a 390 × 844 con fuentes Roboto y datos ficticios;
no es una captura de un dispositivo Android.

El registro final distingue pruebas unitarias y de widgets, build Android e
integración nativa. Las comprobaciones de semántica y tamaños de pantalla no
sustituyen TalkBack/VoiceOver ni pruebas con personas usuarias. Consulta también
[la guía de pruebas](testing.md).
