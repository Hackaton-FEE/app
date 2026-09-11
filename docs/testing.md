# Verificar casos locales

Usa datos ficticios, por ejemplo título `Caso de prueba`, URL `https://example.com/publicacion`, categoría de organización y notas sin datos personales. Conserva los datos reales del dispositivo fuera de las pruebas automatizadas.

## Verificación rápida

Desde la raíz, con Flutter 3.47.2 / Dart 3.13.2:

```sh
flutter pub get --enforce-lockfile
dart format --output=none --set-exit-if-changed lib test integration_test tool
dart run tool/check_source_size.dart
flutter analyze
flutter test
flutter build apk --debug
```

Las pruebas unitarias verifican validación, lectura/escritura y fallos mediante dobles. Las pruebas de widgets verifican interacciones y estados visibles. No usan el backend ni servicios externos. Al cambiar comportamiento, comprueba el caso que el usuario observa y los errores relevantes; no hace falta volver a probar rutas ajenas a un cambio editorial.

## Accesibilidad y orientación de uso

Ejecuta las suites específicas desde la raíz:

```sh
flutter test test/accessibility
```

Las Guideline APIs de Flutter comprueban etiquetas, contraste y objetivos pulsables de los elementos construidos en cada escenario. `androidTapTargetGuideline` usa 48 × 48 unidades lógicas e `iOSTapTargetGuideline`, 44 × 44. Pasarlas no demuestra conformidad WCAG global ni reproduce la experiencia de un lector de pantalla. Incluye controles alcanzados mediante desplazamiento, además del primer viewport.

Comprueba los estados afectados en un viewport de **320 × 640 unidades lógicas y texto al 200 %**, con títulos, enlaces y notas largos dentro de sus límites. Revisa también orientación horizontal cuando cambie la distribución: texto, errores, diálogos y acciones deben seguir siendo legibles y alcanzables. Los valores de prueba no sustituyen todas las configuraciones de pantalla y texto del sistema.

Recorre crear → enviar inválido → corregir → guardar → editar → abrir ayuda y volver → cancelar salida o descartar → archivar/restaurar → cancelar o confirmar borrado. Verifica que el primer error reciba foco y quede visible; que una escritura fallida conserve el formulario; y que no haya confirmación de salida si está limpio o el guardado terminó. La ayuda debe conservar la edición y explicar guardado local, notas opcionales y ausencia de envío externo. Los avisos importantes deben permanecer visibles sin pedir foco; el borrado debe identificar el caso.

Para la comprobación manual nativa, usa datos ficticios y registra build, dispositivo, sistema, escala de texto y tecnología asistiva:

- En Android, activa TalkBack; en iOS, VoiceOver. Recorre la secuencia anterior comprobando nombre, rol, obligatoriedad, encabezados, orden y ausencia de focos duplicados.
- Escucha resultados de búsqueda, validación y acciones; comprueba que los anuncios aporten contexto sin repetir innecesariamente el contenido personal. Revisa el foco al cerrar ayuda y diálogos.
- Comprueba navegación con teclado y los servicios de entrada disponibles, además de los gestos del lector. Accessibility Scanner e Inspector pueden aportar comprobaciones adicionales.

Registra por separado pruebas automáticas, inspección nativa, recorrido con lectores y evaluación con personas usuarias. Los primeros no demuestran comprensión o utilidad para la población destinataria; una evaluación futura debe permitir pausas y omitir preguntas, sin solicitar historias reales. Consulta [la revisión de evidencia](research/accessibility-and-user-care.md) para sus límites y el registro de resultados de la entrega.

## Almacenamiento nativo

La prueba `integration_test/local_case_storage_test.dart` requiere un emulador o dispositivo Android; para iOS requiere macOS/Xcode y un destino iOS. Selecciona el identificador real mostrado por `flutter devices`:

```sh
flutter devices
flutter test integration_test/local_case_storage_test.dart -d <device-id>
```

Esta prueba usa el plugin nativo y vuelve a crear el almacenamiento/repositorio para comprobar persistencia, además de editar, archivar/restaurar y eliminar. Mantiene sus registros separados mediante un espacio de almacenamiento y prefijo de prueba. No detiene ni vuelve a iniciar el proceso de la aplicación; informa ese alcance cuando registres sus resultados.

Una prueba Android no valida Keychain de iOS. Un build iOS verifica compilación, no lectura/escritura en un dispositivo: registra por separado esas comprobaciones.

El workflow manual `iOS simulator build` selecciona un iPhone disponible, ejecuta esta misma prueba de integración contra Keychain y después compila la app normal. Puede lanzarse sobre una rama de PR desde Actions; no necesita credenciales de distribución.

## Cierre y reapertura en Android

Esta comprobación manual completa la prueba de integración. Instala una vez el APK o usa `flutter run` en el destino y después abre la misma instalación desde su icono.

1. Crea un caso ficticio y espera la confirmación de guardado. Abre su detalle y comprueba título, enlace, categoría y notas.
2. Edita el título y las notas; guarda y comprueba el resultado. Busca el título nuevo.
3. Archiva el caso y verifica que aparece en la vista correspondiente. No lo elimines todavía.
4. Desde Ajustes de Android → Aplicaciones → la app, usa **Forzar detención**. Abre de nuevo desde su icono: el caso debe conservar la edición y el estado archivado.
5. Restaura el caso a borrador, fuerza otra detención y vuelve a abrir. Comprueba el estado restaurado.
6. Elimina ese caso de prueba, confirma la acción y repite cierre/reapertura: no debe volver a aparecer.

No desinstales, reinstales ni uses **Borrar almacenamiento/datos** entre los pasos: esas acciones no simulan reinicio y pueden eliminar los registros. Hot reload tampoco sustituye esta comprobación. Opcionalmente reinicia el dispositivo manteniendo la instalación para verificar ese escenario por separado.

## Rendimiento del dashboard

La prueba de widgets `test/footprint/footprint_action_bar_test.dart` verifica que desplazar la lista no reconstruya ni mueva sus botones y que el estado de escaneo siga actualizándose. No mide FPS ni tiempo de GPU.

Para medir en un dispositivo físico, usa `profile`, no el APK `debug`. El benchmark inicia cuentas y casos ficticios en memoria, hace una pasada de calentamiento y cuatro recorridos de ida y vuelta con el mismo desplazamiento programado. No lee ni modifica los casos persistidos. La instalación de prueba reemplaza temporalmente el ejecutable de la app, no su almacenamiento.

```sh
flutter drive --profile --no-dds -d <device-id> \
  --driver=test_driver/dashboard_performance.dart \
  --target=integration_test/dashboard_scroll_performance_test.dart
```

El resultado queda en `build/performance/dashboard_scroll.json`. Conserva copias separadas antes/después con el mismo dispositivo y ajustes. `frame_build_times` y `frame_rasterizer_times` están en microsegundos: contrasta cada etapa con aproximadamente **8,333 µs para 120 Hz**, no solo con los contadores de presupuesto predeterminados del resumen. La frecuencia indicada por `display_refresh_rate_hz` no demuestra por sí sola 120 FPS sostenidos. Estos tiempos tampoco certifican la latencia táctil ni el comportamiento de todos los dispositivos. Registra modo, frecuencia, cantidad de frames y percentiles; no fuerces ajustes globales del teléfono.

Después de medir, vuelve a instalar/ejecutar la app normal con `flutter run --profile -d <device-id>` para no dejar el benchmark como pantalla de inicio. No desinstales ni borres datos. iOS requiere su propia medición en macOS con un iPhone compatible.

Medición del 10 de septiembre de 2026 en Pixel 10 Pro XL, Android 17, `profile`, pantalla reportada a 120 Hz: 1,669 frames, media de construcción 0.624 ms y de rasterizado 2.980 ms; percentil 99 de 1.441 ms y 7.750 ms respectivamente. Ninguna construcción y 10 rasterizados excedieron 8.333 ms (máximo de rasterizado 19.255 ms). Es una ejecución sintética posterior al cambio, no una comparación A/B ni una garantía de 120 FPS sostenidos. La medición previa no concluyó y no se utiliza como evidencia. No se midió iOS.

## Fallos y evidencia del PR

Los dobles de prueba permiten simular almacenamiento inaccesible, escritura fallida y JSON inválido o de versión desconocida sin dañar datos del teléfono. Verifica que no se anuncie éxito ni se sustituya el contenido por una colección vacía. Para cambios de validación de texto, incluye emojis y caracteres combinados dentro de los límites visibles, y una entrada que exceda la cota independiente de 24 KiB de metadatos UTF-8. No introduzcas corrupción en un dispositivo con datos de trabajo.

En el PR indica comandos ejecutados, plataforma/destino, resultado del plugin real y si se completó cierre/reapertura. Adjunta capturas con datos ficticios si cambió la UI. No sumes tests de mocks, integración y reinicio manual como si demostraran lo mismo.

## Historial de escaneos

`flutter test test/footprint test/presentation/scan_history_page_test.dart` cubre persistencia recreando el repositorio, conservación ante corrupción, fallos de purga y borrado, reintento de guardado sin duplicados y operaciones en cola. La navegación conserva los accesos independientes a historial y casos; las pruebas de widgets incluyen ancho de 320 px y texto al 200 %.

`flutter test integration_test/scan_history_storage_test.dart -d <device-id>` comprueba el plugin nativo con un espacio de almacenamiento de prueba: persistencia al recrear el repositorio, separación por cuenta, corrupción conservada y purga de registros vencidos. Se ejecutó en Pixel 10 Pro XL con Android 17; no prueba reinicio del proceso, iOS, TalkBack ni VoiceOver.

Referencias inspeccionadas de widgets a 390 × 844: [perfil con historial y casos](images/integrated-profile-history-cases.png) e [historial](images/integrated-scan-history.png).

## Integración OSINT y retirada de datos de demostración

Los datos de ejemplo y repositorios simulados viven en `test/support` y nunca
se componen en la app de producción. El smoke test de red es opt-in mediante
`FEE_LIVE_BACKEND_TEST`; las pruebas ordinarias no registran cuentas ni
consumen tráfico de Decodo.

Las pruebas de `test/footprint/` cubren el contrato de correlación, compatibilidad
sin `correlation`, round-trip de historial, corrupción sin pérdida, teléfono
internacional y errores sin falso éxito. El panel se verifica a 390 px y a
320 px con texto al 200 %, incluyendo apertura, desplazamiento y cierre.

Para regenerar la captura de widgets con fuentes legibles del SDK:

```sh
flutter test --dart-define=FEE_CAPTURE_CORRELATION=true \
  --dart-define=FEE_FLUTTER_FONTS=/ruta/flutter/bin/cache/artifacts/material_fonts \
  test/footprint/osint_report_card_test.dart
```

La imagen usa exclusivamente el fixture `correlated_dashboard.json`. No
representa un dispositivo, una ceremonia biométrica ni un recorrido TalkBack.
Las pruebas de adaptador passkeys están en `test/auth/`; véase
[native-passkeys.md](native-passkeys.md). Apple queda aplazado por petición del
usuario. El build Android no acredita que un proveedor externo acepte cada consulta.

## Recuperación de análisis al volver a la app

`test/footprint/pending_scan_recovery_test.dart` cubre pérdida de conexión,
recreación del repositorio, consulta del mismo ID sin otro POST, respuesta vieja
tras suspensión, corrupción conservada y fallo de guardado sin confirmación.
`test/footprint/scan_lifecycle_test.dart` verifica que el dashboard observe la
pausa y solicite recuperación al volver a primer plano. Son pruebas con dobles;
no prueban ejecución Flutter en segundo plano.

La integración `scan_history_storage_test.dart` también verifica que el ID
pendiente sobreviva a recrear el adaptador nativo y se separe por cuenta. El
marcador solo se elimina tras guardar el resultado, o ante FAILED/EXPIRED/404.
Para el recorrido real: iniciar una autoauditoría, esperar su aceptación,
bloquear o cambiar de app, volver y comprobar que continúa el mismo ID. Forzar
la detención y reabrir permite comprobar recuperación tras terminar el proceso,
sin borrar almacenamiento ni crear otra búsqueda.
