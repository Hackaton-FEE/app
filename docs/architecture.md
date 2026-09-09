# Arquitectura del cliente

`Hackaton-FEE/app` usa Flutter 3.47.2 / Dart 3.13.2 para Android e iOS. La aplicación ofrece un **Dashboard de Huella Digital y Privacidad Personal** que traduce hallazgos OSINT técnicos a un lenguaje visual y accesible, precedido por un selector de cuentas de ejemplo con información de producto al deslizar, y con una barra inferior superpuesta (Escanear y GuardAI), un panel lateral de perfil y un mapa opcional de categorías. GuardAI propone una conversación iterativa de demostración. Los casos locales existentes se conservan como herramienta secundaria del dispositivo; su rediseño queda pendiente.

## Responsabilidades

| Área | Responsabilidad |
| --- | --- |
| `lib/main.dart`, `lib/app/` | Arranque, composición por constructor, tema y selector inicial (`AccountPickerPage`) y composición de las sesiones de demostración por cuenta. |
| `lib/features/accounts/` | Cuentas inmutables, repositorio asíncrono de demostración en memoria, `AccountsController`, selector y presentación de producto desplazable. |
| `lib/features/guard_ai/` | Mensajes y conversación inmutables, repositorio asíncrono de respuestas locales y `GuardAiController` con historial, borrador, estados y reintentos. |
| `lib/features/footprint/domain/` | Modelos de huella digital (`FootprintItem`, `FootprintProfile`), cálculo de score de exposición y contrato `FootprintRepository`. |
| `lib/features/footprint/data/` | Repositorio mock de diagnóstico y escaneo reactivo de identidades (`MockFootprintRepository`). |
| `lib/features/footprint/presentation/` | `DashboardPage`, indicador de exposición (`ExposureGauge`), tarjetas de hallazgos, filtros, diálogo de análisis de ejemplo, mapa de categorías, panel de perfil y barra inferior translúcida. |
| `lib/features/cases/domain/` | Modelos inmutables, validación y contrato asíncrono `CaseRepository`. |
| `lib/features/cases/data/` | Lectura y escritura de registros, formato persistido y adaptación del plugin nativo. |
| `lib/features/cases/presentation/` | `CasesController` con `ChangeNotifier`, estado visible, búsqueda, formularios pre-llenables y navegación. |

El widget recibe acciones y representa el estado del controlador. El controlador llama al repositorio y expone carga, resultado o error; no serializa JSON ni usa canales nativos. El repositorio es la fuente de verdad de los casos y el adaptador `CaseStorage` aísla el almacenamiento. Las dependencias llegan por constructor, de modo que pruebas de reglas y presentación puedan reemplazar el acceso nativo.

La presentación conserva también el estado efímero de edición, foco y confirmaciones de salida; no persiste un borrador a escondidas. `features/help/presentation/` ofrece la guía de uso sin red ni captura de datos. `shared/presentation/status_notice.dart` presenta feedback persistente y semántico; el contenido del caso no se añade a anuncios automáticos de estado. La [revisión de literatura y comparación](research/accessibility-and-user-care.md) explica estas decisiones y sus límites.

Al reabrir los casos, el campo de búsqueda representa la consulta conservada por el controlador. El formulario mantiene sus campos durante una carga fallida y permite volver a cargar los casos antes de habilitar Guardar; el reintento no descarta el borrador ni evita la comprobación de corrupción.

Conservamos `ChangeNotifier` porque cubre el tamaño y los flujos actuales. Los modelos no se modifican desde los widgets: una edición produce un nuevo valor validado. No añadimos un framework de estado, un localizador global de servicios ni clases de casos de uso sin una necesidad concreta. Estas decisiones adaptan las [recomendaciones de Flutter sobre separación, modelos inmutables e inyección](https://docs.flutter.dev/app-architecture/recommendations) al proyecto existente.

## Presentación Osisn't

El dashboard sigue las ideas de `../documentation/osisnt-interfaz-huella-digital.md`: exposición comprensible, categorías explorables y un siguiente paso sencillo. `FootprintActionBar` vive en `Scaffold.bottomNavigationBar` con `extendBody: true`. Su gradiente integra la barra con el contenido; el desenfoque se recorta a la acción translúcida para limitar el área filtrada. El desplazamiento modifica sutilmente la opacidad y posición sin ocultar acciones. La preferencia de reducir movimiento desactiva ese desplazamiento y las transiciones de las hojas; alto contraste usa superficie opaca. La lista reserva altura suficiente para alcanzar el último hallazgo sobre la barra.

`ProfileDrawer` usa `NavigationDrawer`, muestra la cuenta de ejemplo y permite volver al selector, cambiar la identidad del análisis, abrir los casos del dispositivo o ayuda. No representa autenticación. `FootprintMap` deriva sus cuatro categorías del mismo perfil de la lista; seleccionar un nodo abre la lista filtrada. En anchos reducidos y texto grande utiliza controles apilados. Se conservan las acciones táctiles mínimas de 48 unidades y las etiquetas visibles.

`FootprintExplorer` agrupa mapa, filtros y hallazgos en el mismo viewport del dashboard. Los hallazgos se construyen bajo demanda; cada actualización obtiene una sola lista filtrada y calcula los contadores de categorías en una pasada. Los modelos copian y protegen sus colecciones. `FootprintController` coordina carga y escaneo, ignora resultados tras destruirse y conserva la operación fallida para que Reintentar repita ese escaneo o esa carga.

El análisis de huella continúa usando `MockFootprintRepository`: **no consulta servicios externos**. El inicio y las hojas lo identifican como una demostración. El índice es orientativo y no es una probabilidad de daño. Crear o preparar un caso solo lo guarda localmente; no confirma envío ni eliminación externa. La identidad de ejemplo permanece en memoria durante la sesión.

## Entrada por cuentas y GuardAI

La app siempre abre `AccountPickerPage`. `DemoAccountRepository` entrega dos cuentas ficticias; elegir una entra directamente al dashboard, sin contraseñas ni verificación. «Usar otra cuenta» agrega un perfil de ejemplo y entra con él; un repositorio vacío muestra «Crear una cuenta». Las altas y la cuenta activa son efímeras: al recrear la app aparece de nuevo el selector y, al recrear el repositorio, solo los ejemplos iniciales. No existe persistencia de cuentas ni integración con Google o un proveedor de autenticación.

La misma pantalla permite deslizar hacia contenido de presentación: propuesta de valor, tres pasos de uso y una introducción a GuardAI. La acción «Descubre Osisn't» desplaza a esa sección y respeta la preferencia de reducir movimiento. Los botones, textos y tarjetas admiten ancho reducido y escala de texto grande.

Cada ID de cuenta tiene su propia instancia de `FootprintController` y `GuardAiController`. El chat y su borrador se conservan al volver al dashboard, abrir ayuda o cambiar entre cuentas durante la ejecución. `DemoGuardAiRepository` mantiene la conversación en memoria y produce preguntas y siguientes pasos predefinidos según las respuestas. **No hay un modelo de IA conectado**, consultas externas ni creación o envío automático de casos. La UI confirma un mensaje cuando termina la operación asíncrona; un error conserva el borrador y permite reintentar. Salir y abrir ayuda se bloquean mientras se procesa un envío.

La presentación comercial del selector vive en `AccountProductOverview`, sin depender de las actualizaciones de selección. `GuardAiHistory` conserva una instancia de widget mientras no cambie la conversación inmutable, de modo que escribir el borrador no reconstruye sus mensajes. El historial anterior se construye bajo demanda y la última respuesta permanece montada como destino de desplazamiento al enviar.

Los casos existentes siguen bajo una única instancia de `CaseRepository` y se identifican como **casos del dispositivo**, visibles desde todas las cuentas de ejemplo. No se atribuyen a una persona ni se migran por inferencia. El aislamiento y propiedad de casos deberán definirse al conectar autenticación real. El cambio del botón principal no modifica su formato persistido, lectura, edición o recuperación de errores.

## Persistencia local

`CaseStorage` ofrece `readAll()`, `write(id, value)` y `delete(id)`. `LocalCaseRepository` vive en `data/local_case_repository.dart`; su implementación nativa `FlutterSecureCaseStorage`, en `data/flutter_secure_case_storage.dart`, usa `flutter_secure_storage` 10.3.2. El plugin proporciona Keychain en iOS y almacenamiento cifrado en Android; sus opciones y requisitos se describen en la [documentación del paquete](https://pub.dev/packages/flutter_secure_storage).

Cada caso se almacena de manera independiente con un UUID y prefijo `fee.case.v1.`. El JSON tiene `schemaVersion: 1` y los campos `id`, `title`, `sourceUrl`, `category`, `notes`, `status`, `createdAt` y `updatedAt`. Las fechas se serializan en UTC como ISO 8601. Las categorías persistidas son `personalData`, `impersonation`, `intimateContent` y `other`; son etiquetas organizativas, sin clasificación jurídica ni procesamiento de imágenes.

El título es obligatorio, se recorta y admite hasta 80 caracteres visibles; las notas se recortan y admiten hasta 2,000. Ambos límites cuentan grafemas, igual que los campos Flutter, para tratar correctamente emojis y caracteres combinados. La URL admite HTTP/HTTPS sin credenciales incrustadas y su representación normalizada se limita a 2,048 caracteres. Las reglas viven en el dominio para aplicarse tanto al formulario como a los datos leídos.

Existe además un límite de tamaño independiente del contador visible: el JSON de título, URL normalizada, categoría y notas no puede superar **24 KiB codificados en UTF-8**. El registro completo, con versión, ID, estado y fechas, se limita a **32 KiB** antes de escribir y al leer. Esto contiene grafemas excepcionalmente grandes y la expansión de escapes JSON. Si se excede el tamaño de entrada, se informa al usuario antes de guardar; no se trunca el texto ni se confirma una escritura inexistente.

El repositorio relee el almacenamiento y serializa las operaciones **dentro de una misma instancia**. La app compone una sola instancia compartida. Esto evita que los widgets mantengan copias mutables de los casos, pero no implementa coordinación entre procesos o aislados: una futura extensión de compartir necesita resolver ese límite antes de escribir por su cuenta.

Solo las lecturas públicas de la colección y las actualizaciones de presentación ordenan los casos; comparten el criterio de fecha de modificación descendente e ID ascendente para empates. Las mutaciones siguen validando todos los registros, pero no ordenan la colección que usan internamente para buscar el caso.

`createCase`, `updateCase`, `setArchived` y `deleteCase` solo terminan con éxito cuando concluye la escritura o eliminación correspondiente. La UI espera ese resultado antes de confirmar. Las lecturas o mutaciones fallidas generan errores sin URL ni datos personales: almacenamiento no disponible, contenido persistido inválido o caso inexistente.

Un registro corrupto o de esquema desconocido impide cargar o modificar el conjunto. Se conserva el original y se muestra un error: no se sustituye por una lista vacía, no se descarta en silencio ni se resetea el almacenamiento. No hay reparación automática ni migraciones a versiones futuras implementadas. La entrega previa solo guardaba en memoria y no dejó registros persistentes que importar.

La dependencia se fija exactamente en 10.3.2 y Android usa `compileSdk` 36. Se conserva una combinación estable compatible con el SDK del proyecto; una actualización del plugin debe verificar también sus requisitos nativos.

## Alcance de la protección local

El adaptador fija `resetOnError: false` y `storageNamespace: 'fee_cases'` en Android. En iOS usa `unlocked_this_device`, `synchronizable: false` y una cuenta propia de Keychain. Android configura `allowBackup: false` y excluye las preferencias del almacenamiento de sus reglas de copia en nube y transferencia entre dispositivos. Estas opciones no constituyen una función de respaldo, exportación o recuperación para el usuario.

La app no incluye inicio de sesión, bloqueo propio o desafío biométrico. El almacenamiento cifrado no equivale a conocimiento cero ni garantiza recuperación tras desinstalación, borrado de datos o cambio de dispositivo. No se promete borrado completo al desinstalar: el ciclo de vida del almacenamiento nativo depende de la plataforma. Tampoco admite adjuntos: el formato por registro se limita a metadatos pequeños. Al crecer el volumen o incorporar sincronización deberá revisarse la estrategia, por ejemplo una base de datos cifrada y migraciones explícitas.

## Próximos límites a resolver

1. **Compartir:** entrada desde Android/iOS, validación reutilizada, origen de la acción y coordinación de escritores.
2. **Autenticación:** identidad, acceso al dispositivo y propiedad de los casos existentes al cambiar de cuenta.
3. **Backend:** contratos de casos, sincronización, conflictos y reintentos. El servidor separado solo expone inicialmente `GET /api/v1/health`, con HTTP 200 `{"status":"ok","service":"fee-server","version":"0.1.0"}`; esta app no lo consume.
4. **Solicitudes externas:** separar preparado, enviado, recibido, retiro en origen y desindexación con evidencia de cada resultado. `draft` y `archived` nunca representan esos resultados.

La [guía de pruebas](testing.md) distingue pruebas locales, el plugin real y reinicio de proceso. iOS requiere macOS/Xcode; una ejecución Android no valida Keychain ni el proyecto iOS.
