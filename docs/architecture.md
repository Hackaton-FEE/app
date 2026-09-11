# Arquitectura del cliente

El cliente Flutter 3.47.2 / Dart 3.13.2 presenta la huella digital consultada por
la API FEE. La entrega actual se valida en Android; Apple queda aplazado por
petición del usuario. No incluye cuentas ni hallazgos ficticios en producción.
GuardAI utiliza el informe visible en el dashboard como contexto de conversación.

## Composición y responsabilidades

| Área | Responsabilidad |
| --- | --- |
| `lib/app/` | Inyección por constructor, tema y composición de la sesión autenticada. |
| `features/auth/` | Cliente HTTP, tokens, passkeys nativas y estados de acceso. |
| `features/accounts/` | Presentación de la cuenta y perfil de identidad aportado por la persona. |
| `features/footprint/domain/` | Modelos inmutables de hallazgos, informe OSINT, correlación e historial. |
| `features/footprint/data/` | Cliente HTTP, mapeo del dashboard y persistencia local del historial. |
| `features/footprint/presentation/` | ChangeNotifier, dashboard, conexiones, cronología e historial. |
| `features/guard_ai/` | Interfaz de chat, conversaciones de sesión y adaptadores reemplazables; servicio no conectado. |
| `features/cases/` | Casos locales del dispositivo; sin sincronización ni envío externo. |

Se conserva ChangeNotifier, modelos inmutables y repositorios asíncronos como
fuente de verdad. Los widgets no serializan JSON ni llaman plugins directamente.
Una mutación solo se confirma después de persistir. Un error no se transforma
en lista vacía, diagnóstico de ejemplo o guardado exitoso.

## Autenticación y sesión

La distribución actual conserva la bienvenida y el botón Entrar. Al pulsarlo
prepara una sesión de pruebas, muestra progreso real y abre el formulario de
identidad sin registro ni interacción con Passkey. `main` activa
`FEE_TESTING_ACCESS=true`; se puede compilar con `false` para recuperar el flujo
nativo. El servidor debe habilitar `FEE_AUTH_MODE=testing` antes de distribuir
esta app. Véase [acceso temporal de pruebas](testing-access.md).

`BackendAuthRepository` consume `POST /auth/testing/session` (HTTP 201 con el
mismo contrato de tokens), renovación y `/auth/me`. La cuenta de pruebas tiene
un ID único y cero credenciales. El token JWT conserva la propiedad de los
análisis: OSINT y GuardAI reciben Bearer y comparten una renovación serializada.
El refresh de pruebas se guarda en una clave separada; las passkeys, sus
referencias nativas y el refresh anterior se conservan.

La sesión se establece antes de construir repositorios de perfil e historial,
cuyos prefijos usan el ID recibido del servidor. Una renovación rechazada
durante un análisis falla de forma recuperable y no crea otra cuenta. La
bienvenida se muestra al abrir la aplicación; solo Entrar puede solicitar
acceso. Cerrar sesión vuelve a la bienvenida, oculta el access token y conserva
el refresh de pruebas para recuperar la misma cuenta e historial al entrar.
Una renovación que estaba en curso no puede reintentar OSINT/LLM tras cerrar
sesión, ni sobrescribir la identidad elegida en una entrada posterior. Si el
refresh venció, una nueva entrada explícita puede crear otra cuenta; no se
atribuye el historial anterior a esa cuenta nueva. Un fallo de red o de lectura
conserva las credenciales y permite reintentar. La UI de pruebas conserva la
bienvenida y la salida, y omite el registro y el acceso nativo.

El backend identifica la cuenta con un ID y una etiqueta. No se deduce una
identidad OSINT de esa etiqueta. El perfil que la persona quiera auditar se
aporta en el formulario o en Escanear. Un perfil guardado permite volver al
dashboard sin ejecutar automáticamente otro análisis.

Fuera del modo de pruebas, `NativePasskeyAuthenticator` delega en `passkeys`
2.22.3; las respuestas provienen del gestor nativo, sin fabricar firmas ni
atestaciones. [Llaves nativas](native-passkeys.md) documenta la asociación
Android y sus errores recuperables. El autenticador se crea únicamente cuando
se solicita en ese modo; el acceso de pruebas no invoca el plugin.

## Contrato OSINT

La base configurada es `https://backosisnt.ici-labs.com/api/v1`.

| Operación | Contrato |
| --- | --- |
| Iniciar | `POST /osint/scans`, HTTP 202 con `scan_id`. |
| Progreso | `GET /osint/scans/{id}`, estados QUEUED, RUNNING, COMPLETED o FAILED. |
| Resultado | `GET /osint/scans/{id}/results`, HTTP 200 con dashboard. |
| Eliminar remoto | `DELETE /osint/scans/{id}`; independiente del historial local. |

El formulario de perfil y «Escanear» exige correo propio, de uno a diez alias
y teléfono internacional. Usa el contrato existente: `target_type=phone`,
`identifier` con el teléfono, `associated_email`, `associated_usernames` y
`consent_self_audit=true`. Así el servidor recibe entradas para Blackbird y
Maigret (alias), Holehe (correo) e Ignorant (teléfono) en una sola auditoría.
No se infieren correos ni alias a partir del nombre. Los perfiles antiguos se
precargan sin reset; deben completarse antes de iniciar una auditoría nueva.

El correo asociado se propaga por el controlador y repositorio y se conserva
en reintentos, incluida la renovación de sesión. El teléfono se envía como
identificador primario porque el backend no admite `associated_phone`.
Los identificadores se guardan en el perfil local antes de iniciar desde el
formulario; si la persistencia falla, se conservan los campos y no se inicia.
Los pendientes aceptados siguen recuperándose por ID, sin duplicar solicitudes.

Disponer de las tres entradas habilita el intento de los cuatro motores; no
garantiza que todas sus fuentes respondan. No se cambian límites, proxies,
reintentos ni credenciales del servidor. El modo configurado sigue siendo real.
Los nombres completos anteriores se conservan localmente; el servidor actual
no los usa para alimentar un motor, por lo que ya no se solicitan en el formulario.

El cuerpo inicial declara `target_type`, `identifier`, identificadores
asociados y `consent_self_audit`. Los teléfonos requieren `+` y código
internacional; se normalizan espacios, paréntesis y guiones. Los alias numéricos
sin `+` siguen siendo alias. La UI explica que se auditan datos propios.

La identidad se envía a FEE y sus motores consultan fuentes externas mediante el
proxy configurado en el servidor. Flutter no contiene credenciales Decodo ni
configura un proxy global. Los casos del dispositivo no se adjuntan al escaneo.

El cliente conserva el score, nivel de riesgo, fecha, resumen, `partial`,
herramientas ejecutadas y `correlation` del backend. No recalcula un score
diferente para los informes reales ni inventa fecha o campos ante datos inválidos.
FAILED, tiempo agotado, 401, 429 y respuestas mal formadas son errores recuperables:
no confirman el escaneo ni sustituyen el perfil anterior por datos ficticios.

`correlation` es opcional/nullable para aceptar versiones anteriores. Cuando
existe, `OsintReportCodec` valida nodos, conexiones, referencias de grupos,
cronología y patrones de contacto. Las colecciones están protegidas contra
mutaciones. Un dato opcional corrupto produce error, no pérdida silenciosa.

## Presentación de nuevos datos

`ExposureGauge` integra el resultado parcial, consultas limitadas y acceso al
mapa de nexos dentro del índice de exposición, sin otro recuadro en los hallazgos.
`CorrelationGraph` permite seleccionar cualquier cuenta, incluidas las aisladas,
y recorrer sus vecinos en grupos de seis. Solo dibuja relaciones recibidas del
servidor; tocar un nodo lo selecciona y la lista explica los datos coincidentes.
La pestaña «Cronología y datos» conserva en `CorrelationDetails` los grupos,
campos coincidentes, grupos, fechas de registro y patrones de contacto.
La coincidencia no acredita titularidad. Una cuenta antigua no se presenta como
inactiva: el servidor no conoce su última actividad.

La ausencia de hallazgos no se describe como huella limpia. Los fallos de una
fuente siguen siendo visibles aunque otras terminen. Se mantienen semántica de
encabezados, controles de al menos 48 unidades, texto ampliado y movimiento
reducido. [Captura de widget Android](images/osint-correlation-android.png)
con datos exclusivamente de prueba; no es una sesión de una persona real.

El dashboard comparte viewport entre resumen, filtros y hallazgos construidos
bajo demanda. La navegación y recorridos mantienen foco y estado. La paleta
institucional se centraliza en `lib/app/palette.dart` y el tema Material.

## Historial e identidad local

Un JSON versión 1 por escaneo conserva los hallazgos y, para informes nuevos,
`osintReport` con metadatos y correlación. Cada ID de cuenta tiene su prefijo
`fee.scan.<accountId>.v1.` dentro del espacio nativo `fee_scans`. El máximo
por registro es 16 MiB. Los registros se validan antes de podar o mutar y las
operaciones se serializan dentro de una instancia.

La retención local sigue siendo de tres días y no borra escaneos remotos.
Recrear el repositorio mantiene los nuevos datos y los registros anteriores.
Un registro anterior sin referencia de informe no tiene origen verificable:
se conserva con el aviso «Origen no verificado», sin mostrar hallazgos,
puntuación ni riesgo, y no se puede cargar al panel. No se le atribuye
procedencia real o simulada ni se borra por inferencia.

El perfil de identidad se guarda en `fee_identity`, separado de la cuenta
remota. Los adaptadores de almacenamiento desactivan el reset automático.
Corrupción, errores de lectura o de escritura preservan los originales y
permiten reintentar, sin completar el onboarding por un guardado fallido.

## GuardAI y casos

GuardAI incorpora los componentes de `front` (`cc10c47`): bienvenida, drawer,
conversaciones y borradores durante la sesión, ayuda, informes y diálogos de
acciones. `FeeApp.guardAiRepositoryFactory` permite inyectar repositorios
independientes por cuenta y conversación. El adaptador de producción es
`BackendGuardAiRepository`, que consume SSE de `/assistant/chat`. Cada turno
obtiene una instantánea actual del mismo FootprintController del dashboard;
incluye score, riesgo, fecha, parcialidad y hallazgos dentro de una cota.
Se indica cuántos hallazgos se omiten del contexto, sin inventar datos. El
contexto se renueva al cambiar el informe y no se almacena como mensaje visible.
Viaja al servidor y al proveedor del asistente junto con la conversación;
no incluye tokens, notas de casos ni consulta fuentes nuevas.

El botón de acciones rápidas conserva el borrador y ofrece revisión del perfil,
ayuda y plan de privacidad. Se ha retirado la conversación de muestra y su
ejecutor simulado del producto. Las pruebas siguen usando dobles. La respuesta
generada se confirma al recibir `done` en SSE, sin esperar a que
el servidor cierre la conexión. Si el proveedor no responde, devuelve contenido
vacío, agota el tiempo o falla la red, el repositorio presenta una respuesta
local identificada como «Orientación general:», elegida por palabras de la
consulta. También se aplica ante HTTP 429 y fallos 5xx. No interpreta el informe,
atribuye hallazgos ni incorpora acciones del perfil. El siguiente turno vuelve
a consultar al proveedor. La consulta y esta orientación se incorporan una
sola vez al chat; los errores de sesión o validación conservan el borrador.

El historial visible permanece completo. Para cada petición se conservan el
contexto actual del informe y la nueva consulta, y se añaden los pares recientes
que caben en 20 mensajes y 16,000 bytes UTF-8 de JSON. Los mensajes históricos
se limitan a 4,000 puntos de código solo en el envío. La consulta actual no se
recorta; si excede el contrato se rechaza para corregirla.
Los diálogos de acciones no confirman ejecución externa sin un ejecutor conectado.
Posponer no programa notificaciones. Regresar al inicio cierra el menú y sale
una sola vez de GuardAI, conservando conversación y borrador durante la sesión.

La inspección del backend desplegado `d92af3e` en `oracle-fee` el 11 de septiembre
de 2026 confirmó `POST /api/v1/assistant/chat`, autenticado y limitado a 15/minuto.
Recibe `messages` con `role` (`user` o `assistant`) y `content`; responde SSE con
`token` (`content`), `error` (`detail`) y `done`. El servidor antepone su prompt
fijo y no persiste conversaciones. En producción está `assistant_mode=disabled`
y no hay clave del proveedor configurada. El cliente ya consume ese
endpoint. Habilitar respuestas requiere configurar el proveedor y verificar el adaptador,
el streaming completo, renovación de sesión y errores sin falso envío exitoso.
El contrato inspeccionado no incluye ejecución de acciones ni informes
estructurados. No se inventan esas capacidades en el cliente.

Los casos conservan título, URL, categoría, notas, estado y fechas. Siguen
siendo casos del dispositivo compartidos entre sesiones, sin asignarles propiedad
por inferencia. No hay imágenes, reportes enviados, retiros ni desindexación
confirmados por la app.

`LocalCaseRepository` conserva JSON versión 1 con prefijo `fee.case.v1.`,
UUID, límite de 24 KiB para entrada serializada y 32 KiB por registro. El título
admite 80 grafemas y notas 2,000. La URL admite HTTP/HTTPS sin credenciales.
El adaptador usa `flutter_secure_storage` 10.3.2, namespace `fee_cases`,
`resetOnError: false`, Keychain no sincronizable y exclusiones Android de backup.
La app no promete recuperación después de desinstalación ni conocimiento cero.

Consulta [las pruebas](testing.md) para distinguir unidad/widgets, plugin nativo,
compilación y cierre/reapertura real del proceso.

## Escaneos pendientes y ciclo de vida

El ID aceptado y la identidad consultada se conservan en almacenamiento seguro
con prefijo `fee.pending.<accountId>.v1.`, separado del historial. Al volver al
dashboard o recrear la sesión, se consulta ese mismo ID. Las consultas GET se
pausan al salir de primer plano y se repiten al regresar; una respuesta anterior
a la suspensión se descarta. El análisis sigue ejecutándose en el servidor.

Reintentar un pendiente no envía otro POST. El resultado se guarda en historial
con su ID remoto como clave para evitar duplicados; después se elimina el
marcador pendiente. Fallos de red, escritura o datos inválidos conservan el
marcador. FAILED, EXPIRED y 404 liberan el pendiente y muestran un error.

La recuperación requiere haber recibido y persistido el ID del HTTP 202. Si el
proceso termina antes de ese punto, el contrato actual no permite descubrir el
ID perdido: no hay listado remoto ni clave de idempotencia para crear escaneos.
