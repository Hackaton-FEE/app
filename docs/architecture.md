# Arquitectura del cliente

El cliente Flutter 3.47.2 / Dart 3.13.2 presenta la huella digital consultada por
la API FEE. La entrega actual se valida en Android; Apple queda aplazado por
petición del usuario. No incluye cuentas ni hallazgos de demostración en los escaneos. GuardAI
ofrece una conversación de muestra explícita y separada, con datos ficticios
y sin comunicación externa; el chat normal conserva su adaptador configurado.

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

La app utiliza `BackendAuthRepository` y los endpoints de passkeys, renovación,
`/auth/me` y logout. `NativePasskeyAuthenticator` delega en `passkeys` 2.22.3:
las respuestas provienen del gestor nativo, sin fabricar firmas ni atestaciones.
La documentación de [llaves nativas](native-passkeys.md) recoge la asociación
Android, los errores recuperables y la transición desde credenciales antiguas.

El backend identifica la cuenta con un ID y una etiqueta. No se deduce una
identidad OSINT de esa etiqueta. El perfil que la persona quiera auditar se
aporta en onboarding o en Escanear. La sesión se restaura con los tokens
persistidos; si la renovación falla se solicita acceso explícito. Nunca se
registra otra cuenta como recuperación automática.

No hay endpoints de contraseña, catálogo de proveedores ni administración de
sesiones en el contrato desplegado. La UI de acceso ofrece passkeys; el menú lateral no incluye catálogo ni
administración de sesiones.

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
acciones. `FeeApp.guardAiRepositoryFactory` crea un repositorio independiente
por cuenta y por conversación. El adaptador de producción sigue siendo
`UnavailableGuardAiRepository`: conserva el borrador y avisa que el mensaje no
se ha enviado. Desde «Acciones rápidas» se puede abrir una conversación de
muestra separada con `SampleGuardAiRepository`, identificada en el título.
Usa siempre el perfil ficticio @cliente.demo; nunca interpreta un escaneo real.
Los atajos permiten revisar el perfil de muestra, preparar un plan y pedir
ayuda para abrir la confirmación. Conservan el borrador. Aceptar inicia el
ejecutor local de muestra y su progreso; completar la simulación no modifica
cuentas ni envía solicitudes. Posponer conserva una preferencia de sesión.
El menú se cierra con `closeDrawer` antes de salir una sola vez de GuardAI,
sin apilar un dashboard nuevo. El resto de dobles vive en `test/support`.
`GuardAiActionExecutor` permite integrar ejecución y progreso; su implementación
por defecto falla sin confirmar éxito. Posponer no programa notificaciones.

La inspección del backend desplegado `d92af3e` en `oracle-fee` el 11 de septiembre
de 2026 confirmó `POST /api/v1/assistant/chat`, autenticado y limitado a 15/minuto.
Recibe `messages` con `role` (`user` o `assistant`) y `content`; responde SSE con
`token` (`content`), `error` (`detail`) y `done`. El servidor antepone su prompt
fijo y no persiste conversaciones. En producción está `assistant_mode=disabled`
y no hay clave del proveedor configurada. Este cliente todavía no consume ese
endpoint. Habilitarlo requiere configurar el proveedor y verificar el adaptador,
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
