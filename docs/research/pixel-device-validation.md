# Validación en Pixel físico

Comprobación realizada el **9 de septiembre de 2026** sobre el APK normal de la app. Complementa [la revisión de accesibilidad y atención al usuario](accessibility-and-user-care.md); no sustituye un recorrido completo con lector de pantalla ni una evaluación con personas usuarias.

## Entorno y aplicación

| Dato | Valor |
| --- | --- |
| Dispositivo | Pixel 10 Pro XL físico |
| Sistema | Android 17 / API 37 |
| Pantalla | 1080 × 2404 píxeles; densidad 390 |
| Escala de fuente | Original: `1.0`; comprobación ampliada: `2.0` |
| TalkBack | Activado temporalmente, versión `17.0.1.926549743`; desactivado al finalizar |
| APK | `app-debug.apk` |
| Commit | `00d6155c628df4b82b080972f0398694c3c3b01c` |
| SHA-256 del APK | `68d7f2a241f4dba6bf787959a2427371cf0c40f2256abc8d20fdc97c8125f933` |

La instalación inicial se realizó mediante `adb install -r`; no había una instalación anterior de la app. Se mantuvo la misma instalación entre las detenciones forzadas y reaperturas. Antes de detener el proceso se esperó la confirmación visible de cada operación; para el borrado, la lista sin el caso de demostración. No se ejecutó `flutter test` de integración en este Pixel: las comprobaciones utilizaron el APK normal y un caso de demostración.

## Resultados observados

| Escenario | Resultado |
| --- | --- |
| Enviar formulario vacío | El título recibe foco y su error queda visible. |
| Abrir ayuda y regresar | Se conservan los tres valores introducidos en el formulario. |
| Intentar salir con cambios | Elegir seguir editando cancela el descarte y conserva la edición. |
| Guardar y editar | El caso de demostración se guarda y permite modificarlo. |
| Buscar | La etiqueta de búsqueda permanece visible después de introducir texto. |
| Archivar y reabrir | Tras forzar la detención y abrir de nuevo, se conservan el archivado, la edición y las notas. |
| Restaurar y reabrir | La restauración se conserva después de otra detención forzada y reapertura. |
| Texto ampliado | Con `font_scale=2.0`, la categoría larga seleccionada se ve completa; el menú expone las cuatro opciones en el árbol nativo y permite seleccionar. |
| Salir de edición limpia | Se vuelve sin diálogo de descarte cuando no hay cambios. |
| Cancelar y confirmar borrado | Cancelar conserva el caso de demostración; confirmar lo elimina. Tras forzar cierre y reabrir, no reaparece. |

Estas comprobaciones muestran comportamiento funcional y presentación en esta configuración. Una detención forzada y reapertura comprueba continuidad entre procesos; no demuestra recuperación después de desinstalar, borrar datos o cambiar de dispositivo. La escala del sistema no equivale automáticamente a `TextScaler.linear(2)` de las pruebas de widgets.

## Alcance de TalkBack y estado final

TalkBack estaba activo y se observó su indicador verde de foco. Esto **no acredita la voz, los gestos ni el orden completo de navegación**: `adb input tap` activa controles directamente y `uiautomator dump` puede interferir mediante supresión de servicios de accesibilidad. La [documentación de UiAutomation](https://developer.android.com/reference/android/app/UiAutomation#FLAG_DONT_SUPPRESS_ACCESSIBILITY_SERVICES) explica la supresión de servicios; el [código de AOSP](https://android.googlesource.com/platform/frameworks/base/+/refs/heads/main/core/java/android/app/UiAutomation.java#998) distingue la inyección de eventos del filtro de accesibilidad. El recorrido directo de gestos y voz se aplazó para priorizar las funciones de la app. No se registra como aprobado ni fallido.

| Comprobación de cierre | Estado |
| --- | --- |
| Eliminar únicamente el caso de demostración y comprobar su ausencia tras reabrir | Completado. La app quedó abierta, sin casos de prueba. |
| Restablecer los ajustes de accesibilidad y fuente | Completado: fuente `1.0`, TalkBack desactivado y lista de servicios habilitados vacía, como al inicio. |
| Recorrido directo de foco, gestos y voz de TalkBack | Aplazado. |

La app normal queda instalada para uso y revisión. No se modificó código de la app en esta comprobación. No extrapolar este resultado a VoiceOver, otras configuraciones ni conformidad global de accesibilidad.
