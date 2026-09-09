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

Las tres fases están implementadas. Se añadieron cinco archivos de producción
para secciones completas o presentación compartida: el total pasó de 46 a 51.

| Pantalla | Antes | Después |
| --- | ---: | ---: |
| Dashboard | 498 | 345 |
| Selector inicial | 411 | 250 |
| Formulario de casos | 360 | 299 |
| GuardAI | 311 | 295 |

Fase 1: formato y análisis sin incidencias; 157 pruebas unitarias/de widgets
aprobadas, incluidas las regresiones de recuperación y ciclo de vida. El formulario
con recuperación se comprobó a 320 × 640 y texto al 200 % mediante pruebas de
widgets y guidelines. La [captura del formulario](images/quality-case-recovery.png)
es un render de widget Flutter a 390 × 844 con fuentes Roboto y datos ficticios;
no es una captura de un dispositivo Android.

Validación final local con Flutter 3.47.2 / Dart 3.13.2 en Linux:

- `flutter pub get --enforce-lockfile`: correcto, sin cambios de dependencias.
- Formato, `flutter analyze --no-pub` y `git diff --check`: sin incidencias.
- `dart run tool/check_source_size.dart`: 51 archivos; máximo de 345 líneas.
- `flutter test --no-pub`: 166 pruebas aprobadas. Además se volvió a ejecutar la
  regresión de reemplazo/desmontaje de controladores tras reforzar sus asserts.
- `flutter build apk --debug --no-pub`: APK Android compilado correctamente.
- Lista de 120 hallazgos: acceso al último elemento con menos de 20 tarjetas
  montadas en el escenario de prueba. El builder evita crear de entrada todos
  los widgets de tarjetas; el ListView anterior ya difería su montaje.
- Chat de 161 mensajes de alturas variables: historial bajo demanda; cero
  reconstrucciones de historial/burbujas durante tres cambios de borrador;
  respuesta final visible tras enviar o reintentar con teclado abierto y texto
  al 100 % y 200 %. Un fallo asíncrono devuelve foco después de habilitar el campo.

No se ejecutó integración con el plugin real, reinicio de proceso ni recorridos
TalkBack/VoiceOver: no había destino Android/iOS conectado. iOS no se compiló en
este entorno Linux. Las comprobaciones de semántica y tamaños de pantalla no
sustituyen esas validaciones ni pruebas con personas usuarias. Consulta también
[la guía de pruebas](testing.md).
