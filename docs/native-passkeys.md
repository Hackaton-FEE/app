# Llaves de acceso nativas

El cliente utiliza `passkeys` 2.22.3 como puente con Credential Manager en
Android y AuthenticationServices en iOS. El backend FEE sigue siendo la parte
que genera los desafíos, verifica las firmas y entrega la sesión; no se usa
el servicio de autenticación de Corbado. El adaptador conserva `challenge`,
RP ID, algoritmos, credenciales permitidas/excluidas y verificación de usuario
solicitados por el servidor. Devuelve la atestación o firma producida por el
sistema, sin construir respuestas FIDO2 en Dart.

`NativePasskeyAuthenticator` reemplaza el autenticador de software anterior.
Su referencia local usa `fee.auth.v2.native_passkey_credential_id` y solo ayuda
a recordar el último ID nativo. No permite enumerar ni borrar las llaves del
gestor del sistema, ni determina si se puede iniciar sesión. El acceso usa
credenciales descubribles y permite seleccionar una llave sincronizada o de
otro dispositivo. Los IDs anteriores se conservan en almacenamiento pero no
se reutilizan para firmar ni se presentan como llaves válidas.

Cancelar, no tener un proveedor, fallar la asociación o no poder persistir la
referencia son errores recuperables. No hay una firma de reserva ni creación
automática de otra cuenta cuando falla el acceso. Un escaneo cuya sesión no
puede renovarse solicita iniciar sesión explícitamente.

## Android

Las APIs de passkeys requieren Android 9 / API 28 o posterior, un proveedor de
credenciales y bloqueo de pantalla configurados. Se mantiene el mínimo Android
actual de la app; un dispositivo sin soporte recibe un error de acceso.
El plugin incluye Credential Manager y su integración con Play Services.

El RP ID de producción es `backosisnt.ici-labs.com`; el paquete Android es
`org.hackatonfee.fee_app`. El servidor debe publicar sin redirección
`/.well-known/assetlinks.json` con `delegate_permission/common.get_login_creds`,
paquete y SHA-256 del certificado de **la app instalada**. También debe aceptar
el origen `android:apk-key-hash:<SHA256-base64url-sin-padding>` en
`FEE_WEBAUTHN_ORIGINS`. La huella hexadecimal de Asset Links y el hash base64url
del origen representan los mismos bytes.

El 10 de septiembre de 2026 se contrastó el APK debug local existente con el
archivo público: ambos contienen
`9F:67:EE:93:CD:48:3F:CA:3B:83:BC:F1:76:C4:2C:F2:97:B9:9D:4F:43:F2:26:8E:77:5D:25:3F:D6:07:47:90`.
Su origen correspondiente es
`android:apk-key-hash:n2fuk81IP8o7g7zxdsQs8pe5nU9D8iaOd10lP9YHR5A`.
También se comprobó que el servidor en ejecución acepta ese origen exacto.
Estas verificaciones no equivalen a una ceremonia biométrica real. Antes de distribuir una
versión firmada, agregar su certificado y origen reales; no reutilizar la
llave debug para publicación.

## iOS aplazado

Por indicación de la persona usuaria no se configura ni se valida Apple en
esta entrega. Se conserva la configuración iOS previa del proyecto, sin añadir
Associated Domains ni equipo de firma. El paquete es portable, pero la ruta
nativa comprobada aquí es Android. No se afirma funcionamiento iOS.

## Validación

`test/auth/native_passkey_authenticator_test.dart` comprueba traducción de
opciones y preservación de respuestas nativas con un doble del plugin,
cancelación sin registro implícito, error sin datos privados, ausencia de firma,
fallo de persistencia y separación del ID legado. Son pruebas del adaptador;
no producen ni validan firmas reales.

Para validar el sistema completo en un dispositivo asociado, iniciar sesión
con una llave ya existente o crearla por decisión explícita de la persona,
completar biometría/PIN, comprobar `/auth/me`, cerrar sesión y volver a entrar.
No usar el antiguo smoke test de credenciales sintéticas para acreditar FIDO2.
Las cuentas creadas con ese protocolo anterior no se convierten en passkeys
por actualizar el cliente: requieren una ruta de transición del servidor.

Referencias primarias: [paquete passkeys](https://pub.dev/packages/passkeys) e
[implementación Android](https://pub.dev/packages/passkeys_android).
