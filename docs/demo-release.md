# Candidato Android para la demo · 11 de septiembre de 2026

Rama: `codex/demo-guardai-integration`.

## Procedencia y alcance

- Base: `origin/main` en `d0bedf8`, incluida recuperación de escaneos pendientes.
- GuardAI: componentes, contratos y pruebas de `front` en `cc10c47`.
- Icono Android: resultado de `codex/premium-app-icon` en `b888d33` (PR #7).
- Se integra la fábrica de repositorios para cada conversación nueva sobre la
  composición actual. Se mantienen autenticación nativa, identidad y datos OSINT
  reales de main; no se incorpora la composición antigua de front.
- No se reescriben ramas existentes ni se elimina el directorio local `output/`.

## Resultado observable

GuardAI abre desde el dashboard. El drawer permite regresar, crear, seleccionar
  y eliminar conversaciones con confirmación; cada una conserva su borrador en
  la sesión. La ayuda conserva el texto. Enviar sin servicio mantiene el borrador
  y explica que no se envió. Informes, recomendaciones, recordatorios y procesos
  tienen componentes e interfaces inyectables; los datos de ejemplo están
  exclusivamente en pruebas. No hay una galería de ejemplos en producción.

Se reutilizan los componentes Android de la rama de referencia. Las capturas
[de bienvenida](images/guardai-empty.png) y [de indisponibilidad](images/guardai-unavailable.png)
se generaron con widgets y fuentes del SDK. No son una comparación píxel a píxel
con otra instalación ni evidencia de TalkBack.

## Backend verificado por SSH

`oracle-fee`, imagen `fee-server:main-d92af3e`: API, PostgreSQL y túnel saludables.
El health público responde 200, versión 0.2.0. El código desplegado sí incluye
`POST /api/v1/assistant/chat`; el modo real está deshabilitado y no hay clave del
proveedor configurada. No se cambió el despliegue, configuración ni datos.
El contrato SSE y pendientes de integración se describen en [arquitectura](architecture.md).
No se ejecutó un nuevo escaneo real ni una llamada al proveedor de IA.

## Verificación realizada

Flutter 3.47.2 / Dart 3.13.2, Linux, Android debug:

- `flutter pub get --enforce-lockfile`: correcto.
- Formato de `lib test integration_test tool`: correcto.
- `dart run tool/check_source_size.dart`: 111 archivos; máximo 350 líneas.
- `flutter analyze`: sin incidencias.
- `flutter test`: 358 pasan, una prueba de red opt-in omitida.
- Capturas GuardAI: cinco pruebas pasan, incluidas anchura 320 y texto al 200 %.
- `flutter build apk --debug`: correcto.
- `adb install -r`: correcto en el Pixel conectado, sin borrar almacenamiento.

El APK previo se copió antes de instalar. Ambos artefactos están fuera del repo,
en `/home/peterpad/Hackaton-FEE/demo-artifacts/`:
`osisnt-demo-guardai.apk` y `osisnt-before-guardai.apk`. La copia anterior solo
respalda el ejecutable; no es una exportación de los datos del dispositivo.

El teléfono estaba bloqueado después de instalar: el recorrido físico, teclado
real y autenticación biométrica de esta compilación quedan pendientes.
No se ejecutó iOS, TalkBack ni una nueva prueba de reinicio de almacenamiento.
La compilación advierte que passkeys_android aún usa Kotlin Gradle Plugin;
no impidió compilar y no se actualizaron dependencias antes de la demo.

## Integración del equipo

Usar este PR como candidato consolidado. Incluye los cambios de icono del PR #7;
no requiere integrar front completa. Antes de fusionar, aplicar la revisión
cruzada y los checks del repositorio. Las ramas originales se conservan.
