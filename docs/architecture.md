# Arquitectura del cliente

`Hackaton-FEE/app` usa Flutter 3.47.2 / Dart 3.13.2 para Android e iOS. Esta entrega gestiona casos locales: crear, consultar, editar, buscar, archivar, restaurar y eliminar. Cada caso contiene título, URL, categoría y notas; sus estados son `draft` y `archived`. No hay conexión al servidor, imágenes, captura de evidencia ni reportes externos.

## Responsabilidades

| Área | Responsabilidad |
| --- | --- |
| `lib/main.dart`, `lib/app/` | Arranque, composición por constructor y tema. |
| `lib/features/cases/domain/` | Modelos inmutables, validación y contrato asíncrono `CaseRepository`. |
| `lib/features/cases/data/` | Lectura y escritura de registros, formato persistido y adaptación del plugin nativo. |
| `lib/features/cases/presentation/` | `CasesController` con `ChangeNotifier`, estado visible, búsqueda, formularios y navegación. |

El widget recibe acciones y representa el estado del controlador. El controlador llama al repositorio y expone carga, resultado o error; no serializa JSON ni usa canales nativos. El repositorio es la fuente de verdad de los casos y el adaptador `CaseStorage` aísla el almacenamiento. Las dependencias llegan por constructor, de modo que pruebas de reglas y presentación puedan reemplazar el acceso nativo.

Conservamos `ChangeNotifier` porque cubre el tamaño y los flujos actuales. Los modelos no se modifican desde los widgets: una edición produce un nuevo valor validado. No añadimos un framework de estado, un localizador global de servicios ni clases de casos de uso sin una necesidad concreta. Estas decisiones adaptan las [recomendaciones de Flutter sobre separación, modelos inmutables e inyección](https://docs.flutter.dev/app-architecture/recommendations) al proyecto existente.

## Persistencia local

`CaseStorage` ofrece `readAll()`, `write(id, value)` y `delete(id)`. `LocalCaseRepository` vive en `data/local_case_repository.dart`; su implementación nativa `FlutterSecureCaseStorage`, en `data/flutter_secure_case_storage.dart`, usa `flutter_secure_storage` 10.3.2. El plugin proporciona Keychain en iOS y almacenamiento cifrado en Android; sus opciones y requisitos se describen en la [documentación del paquete](https://pub.dev/packages/flutter_secure_storage).

Cada caso se almacena de manera independiente con un UUID y prefijo `fee.case.v1.`. El JSON tiene `schemaVersion: 1` y los campos `id`, `title`, `sourceUrl`, `category`, `notes`, `status`, `createdAt` y `updatedAt`. Las fechas se serializan en UTC como ISO 8601. Las categorías persistidas son `personalData`, `impersonation`, `intimateContent` y `other`; son etiquetas organizativas, sin clasificación jurídica ni procesamiento de imágenes.

El título es obligatorio, se recorta y admite hasta 80 caracteres visibles; las notas se recortan y admiten hasta 2,000. Ambos límites cuentan grafemas, igual que los campos Flutter, para tratar correctamente emojis y caracteres combinados. La URL admite HTTP/HTTPS sin credenciales incrustadas y su representación normalizada se limita a 2,048 caracteres. Las reglas viven en el dominio para aplicarse tanto al formulario como a los datos leídos.

Existe además un límite de tamaño independiente del contador visible: el JSON de título, URL normalizada, categoría y notas no puede superar **24 KiB codificados en UTF-8**. El registro completo, con versión, ID, estado y fechas, se limita a **32 KiB** antes de escribir y al leer. Esto contiene grafemas excepcionalmente grandes y la expansión de escapes JSON. Si se excede el tamaño de entrada, se informa al usuario antes de guardar; no se trunca el texto ni se confirma una escritura inexistente.

El repositorio relee el almacenamiento y serializa las operaciones **dentro de una misma instancia**. La app compone una sola instancia compartida. Esto evita que los widgets mantengan copias mutables de los casos, pero no implementa coordinación entre procesos o aislados: una futura extensión de compartir necesita resolver ese límite antes de escribir por su cuenta.

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
