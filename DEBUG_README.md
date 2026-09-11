# Registro de Depuración y Errores Solucionados (Hackaton-FEE)

Este documento recopila los errores diagnosticados, sus causas raíz, las soluciones implementadas y los puntos de verificación clave tanto en la **App Flutter** (`Hackaton-FEE/app`) como en el **Servidor FastAPI** (`Hackaton-FEE/server` / despliegue Oracle Cloud `oracle-fee`). Sirve como guía de referencia para continuar las sesiones de depuración.

---

## 1. Error de Registro y Autenticación con Passkeys Nativas (FIDO2/WebAuthn)

### Síntoma
En el teléfono Android físico (Pixel 10 Pro XL), al intentar registrar la passkey con Google Password Manager o iniciar sesión, el sistema operativo mostraba el error:
> *"Esta versión de la aplicación no está asociada al servicio"* / *"The app is not associated with this service"*.

### Causa Raíz
1. **Asociación de Dominio (Digital Asset Links)**: Android Credential Manager y Google Play Services exigen una verificación estricta (`autoVerify`) entre el paquete de la aplicación (`org.hackatonfee.fee_app`), la huella SHA-256 del certificado y el dominio HTTPS del backend (`backosisnt.ici-labs.com`).
2. **Relación Faltante en Servidor**: El endpoint `/.well-known/assetlinks.json` en el servidor solo declaraba la relación:
   ```json
   "relation": ["delegate_permission/common.get_login_creds"]
   ```
   Google Play Services para Credential Manager requiere adicionalmente la relación:
   ```json
   "delegate_permission/common.handle_all_urls"
   ```
3. **Configuración Faltante en Cliente Android**: En `AndroidManifest.xml`, el `intent-filter` no tenía habilitado `android:autoVerify="true"` con `backosisnt.ici-labs.com`, ni la metadata de statements apuntando a `@string/asset_statements`.

### Solución Implementada
* **Servidor (`src/fee_server/api/well_known.py`)**:
  Se incluyeron ambas relaciones en la respuesta:
  ```python
  body = [
      {
          "relation": [
              "delegate_permission/common.handle_all_urls",
              "delegate_permission/common.get_login_creds",
          ],
          "target": {
              "namespace": "android_app",
              "package_name": settings.android_package_name,
              "sha256_cert_fingerprints": [settings.android_cert_fingerprint],
          },
      }
  ]
  ```
* **App Móvil (`android/app/src/main/AndroidManifest.xml` y `res/values/strings.xml`)**:
  * Se configuró el `intent-filter` con `android:autoVerify="true"` para el host `backosisnt.ici-labs.com`.
  * Se vinculó el recurso `@string/asset_statements` que declara la relación bidireccional con el backend.
* **Verificación**:
  Se validó en el dispositivo físico mediante:
  ```bash
  adb shell pm get-app-links org.hackatonfee.fee_app
  ```
  Confirmando el estado:
  `backosisnt.ici-labs.com: verified (ID: 50018803-cab3-4ab9-af7e-a53470167edb)`.
  El registro y login nativo con biometría/Passkey quedó 100% funcional.

---

## 2. Error al Iniciar Escaneo OSINT ("Revisa el identificador y el consentimiento")

### Síntoma
En la pantalla principal (`DashboardPage`), tras iniciar sesión con un usuario nuevo (por ejemplo: "Pedro Ibarra"), aparecía un banner rojo persistente indicando:
> *"Revisa el identificador y el consentimiento del escaneo. Reintentar"*

### Causa Raíz
1. **Tipificación Errónea en Cliente (`ScanTarget.parse`)**:
   El método `ScanTarget.parse` en `lib/features/footprint/domain/scan_target.dart` únicamente detectaba:
   * Teléfono (si iniciaba con `+`).
   * Correo (si contenía `@`).
   * **Todo lo demás se asignaba ciegamente a `TargetType.username`**.
2. **Validación Estricta en Backend**:
   El servidor en `/api/v1/osint/scans` valida estrictamente los alias mediante el regex:
   ```python
   _USERNAME_RE = re.compile(r"^[A-Za-z0-9._-]{2,64}$")
   ```
   Al recibir "Pedro Ibarra" (con espacios), el backend devolvía HTTP 400 `InvalidIdentifierError`:
   `"Invalid identifier Pedro Ibarra for target type username"`.
   El backend soporta `target_type: "name"` para nombres de personas con espacios o acentos, pero la app nunca clasificaba este tipo.
3. **Ocultamiento de Errores RFC 7807**:
   En `lib/features/footprint/data/osint_client.dart`, `_handleError` ignoraba el campo `detail` del JSON de error devuelto por FastAPI y emitía un mensaje genérico, dificultando conocer la causa del fallo.

### Solución Implementada
* **`lib/features/footprint/domain/scan_target.dart`**:
  * Se definieron regex independientes para `_usernameRegex` y `_nameRegex`:
    ```dart
    static final RegExp _usernameRegex = RegExp(r'^[A-Za-z0-9._-]{2,64}$');
    static final RegExp _nameRegex = RegExp(r"^[A-Za-zÀ-ÿ\s'.-]{2,120}$");
    ```
  * `ScanTarget.parse` ahora clasifica:
    * Contiene `@` $\rightarrow$ `TargetType.email`.
    * Inicia con `+` y dígitos $\rightarrow$ `TargetType.phone`.
    * Coincide con `_usernameRegex` (sin espacios) $\rightarrow$ `TargetType.username`.
    * Contiene espacios o coincide con `_nameRegex` $\rightarrow$ `TargetType.name`.
* **`lib/features/footprint/data/osint_client.dart`**:
  * Se extrae el detalle RFC 7807 (`body['detail']` o `body['title']`) en `_handleError` para propagar el mensaje exacto del servidor.
* **`lib/features/accounts/presentation/profile_setup_page.dart`**:
  * Se añadió validación interactiva en el formulario de configuración de perfil para advertir al usuario antes de guardar si su identificador es un nombre, alias, correo o teléfono válido.
* **Pruebas**:
  * Cobertura completa en `test/footprint/scan_target_test.dart` con 322 pruebas pasando.
  * Se instaló la versión actualizada en el dispositivo físico, desapareciendo el banner de error y permitiendo la ejecución del escaneo.

---

## 3. Rate Limiting por IP Bloqueando Pruebas de Desarrollo

### Síntoma
Durante pruebas intensivas de depuración y flujo en vivo, el middleware SlowAPI aplicaba límites de tasa (`120/minute`) por IP pública, arriesgando bloqueos en peticiones del hackathon.

### Causa Raíz
En `src/fee_server/core/rate_limit.py`, el `Limiter` de SlowAPI estaba instanciado estáticamente sin posibilidad de desactivación dinámica.

### Solución Implementada
* Se agregó la lectura de la variable de entorno `FEE_RATE_LIMIT_ENABLED` (por defecto `0` / desactivado):
  ```python
  _enabled = os.getenv("FEE_RATE_LIMIT_ENABLED", "0").lower() in ("1", "true", "yes")
  limiter = Limiter(
      key_func=get_remote_address,
      default_limits=["120/minute"],
      enabled=_enabled,
  )
  ```
  Al pasar `enabled=False`, SlowAPI desactiva de forma nativa todos los decoradores `@limiter.limit` en todas las rutas sin requerir cambios archivo por archivo.
* Se sincronizó en el contenedor Docker en producción (`fee-prod-api-1`) en Oracle Cloud y se reinició el servicio.

---

## 4. Estado de los Repositorios y Despliegue

### Repositorio `Hackaton-FEE/app` (Cliente Flutter)
* **Rama `main`**: Al día con commit `933afb3`.
* **Ramas remotas**:
  * `origin/front`: Rama creada por FernandoN04 (`Redesign chat bot`) con modificaciones en `GuardAI` (`guard_ai_page.dart`, `guard_ai_controller.dart`). Actualmente no tiene PR y presenta conflictos con `main` si se intenta fusionar directamente.
* **APK Compilado**: `build/app/outputs/flutter-apk/app-debug.apk` instalado y verificado en Google Pixel 10 Pro XL.

### Repositorio `Hackaton-FEE/server` (Backend FastAPI)
* **Rama `main`**: Al día con commit `9b95371`.
* **Historial de Pull Requests**:
  * **PR #3** (`codex/strict-native-passkeys`): Combinado en `main` (`ae5b821`).
  * **PR #2** (`codex/decodo-residential-proxy`): Combinado en `main` (`805544f`).
  * **PR #1** (`feature/auth-scan-modules`): Cerrado sin combinar (código legacy de contraseñas reemplazado por Passkeys).
  * No hay PRs abiertos pendientes.
* **Despliegue en Oracle Cloud (`ssh oracle-fee`)**:
  * Contenedor API: `fee-prod-api-1` corriendo en `http://0.0.0.0:8000` (UID `10001`).
  * Base de datos: `fee-prod-db-1` (Postgres 17).
  * Túnel: `fee-prod-cloudflared-1` exponiendo `https://backosisnt.ici-labs.com`.
  * AssetLinks verificado públicamente en: `https://backosisnt.ici-labs.com/.well-known/assetlinks.json`.

---

## 5. Próximos Pasos para Seguir Depurando

1. **Motores OSINT Asíncronos**:
   * Probar respuestas completas de escaneo contra objetivos reales (Blackbird, Maigret, Holehe con proxy Decodo residencial).
   * Monitorear tiempos de ejecución y consumo en el contenedor de Oracle Cloud con `docker logs -f fee-prod-api-1`.
2. **Integración de GuardAI**:
   * Si se decide integrar el rediseño del chat bot (`origin/front`), resolver los conflictos de fusión en `guard_ai_page.dart` y sincronizarlo con el estado actual del repositorio y casos locales.
3. **Manejo de Expiración de Tokens JWT**:
   * Validar el refresco transparente de tokens (`/api/v1/auth/token/refresh`) desde `AuthApiClient` cuando el access token de 1 hora expire.
4. **Almacenamiento Local de Casos**:
   * Verificar la persistencia segura en `flutter_secure_storage` cuando se crean múltiples casos tras un escaneo con hallazgos reales.
