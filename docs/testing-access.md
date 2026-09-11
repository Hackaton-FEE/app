# Acceso temporal para distribución de pruebas

La app compilada desde `main` tiene `FEE_TESTING_ACCESS=true` por defecto. Al
abrirla prepara el acceso automáticamente y presenta el formulario de datos
propios para la auditoría. No exige registro, etiqueta de cuenta, firma,
certificado de Passkey ni asociación de dominio nativa. Si el perfil ya está
guardado para esa cuenta, abre el dashboard y permite iniciar otra búsqueda.

El backend debe desplegar primero `POST /api/v1/auth/testing/session` y usar
`FEE_AUTH_MODE=testing`. La petición lleva `{}` y responde HTTP 201 con
`SessionResponse`: `access_token`, `refresh_token`, `token_type` y metadatos de
sesión existentes. `GET /auth/me` devuelve un ID de cuenta independiente para
cada sesión nueva, con `credentials_count=0`. No se comparte una cuenta global
entre instalaciones. Con acceso de pruebas deshabilitado responde HTTP 403 con
el tipo `testing-access-disabled`; la app muestra el error y permite reintentar.
No recurre a Passkey si falla el servicio.

OSINT y GuardAI mantienen las rutas, autorización Bearer, control de propiedad,
cuotas y validación actuales. Ambos consumen los mismos tokens, renuevan con
`POST /auth/token/refresh` y reintentan una sola vez ante HTTP 401. La renovación
concurrente se serializa para no reutilizar un refresh rotado. Los alias, correo
y teléfono de búsqueda se toman exclusivamente del formulario del cliente.

El refresh de pruebas se guarda en `fee.auth.v1.testing_refresh_token` dentro
de `fee_auth`; el access token vive en memoria. La clave anterior
`fee.auth.v1.refresh_token` y `fee.auth.v2.native_passkey_credential_id` se
conservan. Desactivar Passkey no elimina llaves del proveedor del dispositivo.
Los perfiles e historiales siguen separados por el ID remoto. Una credencial
inválida durante el análisis no provoca cambiar automáticamente de cuenta; se
muestra un error recuperable. Cerrar y volver a abrir permite preparar acceso
de nuevo. Si se requiere una cuenta nueva, su historial empieza independiente
del anterior, cuyos datos locales no se borran ni reasignan.

Para volver al acceso nativo, compilar con:

```sh
flutter build apk --debug --dart-define=FEE_TESTING_ACCESS=false
```

También debe deshabilitarse la creación de sesiones de pruebas en el servidor
al terminar la distribución temporal. `FeeApp` y `BackendAuthRepository`
aceptan `testingAccessEnabled` para pruebas e inyección; su valor por defecto
es `false`, mientras que el punto de entrada `main` activa la distribución de
pruebas de forma explícita.

`test/auth/testing_access_repository_test.dart` cubre creación concurrente,
restauración, rechazo del modo, recuperación de red, aislamiento del refresh,
preservación de Passkey y peticiones OSINT/LLM con Bearer y renovación
simultánea. `test/auth/testing_access_flow_test.dart` comprueba el formulario
automático, envío de datos del cliente, ausencia de login y recuperación
accesible a 320 px con texto al 200 %. Usan dobles HTTP y almacenamiento;
no consumen proxy residencial ni acreditan verificación nativa o TalkBack.
