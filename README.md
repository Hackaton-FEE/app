# App móvil · Hackaton-FEE

Base Flutter para iOS y Android de la aplicación de gestión de privacidad. El concepto está en [documentation/concepto-central-plataforma.md](https://github.com/Hackaton-FEE/documentation/blob/main/concepto-central-plataforma.md); este repositorio distingue la visión del producto de las capacidades implementadas.

## Qué funciona

- Pantalla de inicio y flujo para crear, listar y eliminar borradores a partir de un enlace HTTP/HTTPS.
- Borradores exclusivamente en memoria: una nueva sesión empieza vacía. No hay llamadas a red ni reportes a terceros.
- Proyectos nativos Android (Kotlin) e iOS (Swift) generados por Flutter.
- Separación de dominio, repositorio y presentación con inyección de dependencias sencilla.
- Pruebas de validación de enlaces, ciclo de vida del repositorio y flujo de usuario.

Es un prototipo para datos de ejemplo. No contiene almacenamiento persistente, autenticación, recepción desde el menú Compartir, captura de evidencia, hashing NCII, notificaciones push ni solicitudes de retiro. Estas capacidades se desarrollarán mediante PRs independientes.

## Inicio rápido

Requisitos: Flutter **3.47.2** (Dart **3.13.2** incluido), Git y herramientas de la plataforma. `.fvmrc` fija la versión si el equipo usa FVM; FVM es opcional. Las dependencias resueltas están en `pubspec.lock`.

```bash
git clone https://github.com/Hackaton-FEE/app.git
cd app
flutter doctor
flutter pub get --enforce-lockfile
flutter devices
flutter run -d <device-id>
```

Para Android, instala Android Studio/SDK y Java 17 o una versión compatible con el Gradle del proyecto. En Linux se puede compilar Android, pero no iOS. Para iOS utiliza un Mac con Xcode, sus herramientas de línea de comandos y un simulador instalado.

```bash
# Android, compilación de desarrollo
flutter build apk --debug

# Solo macOS con Xcode: simulador iOS, sin firma de distribución
flutter build ios --simulator --debug
```

El APK queda en `build/app/outputs/flutter-apk/app-debug.apk`. Para un iPhone físico hay que configurar el equipo de Apple y la firma en Xcode. Los identificadores generados con el prefijo `org.hackatonfee` son de desarrollo: confirmarlos antes de publicar. Android release no reutiliza la clave debug; las credenciales de distribución se configurarán fuera del repositorio.

## Estructura

```text
lib/
  main.dart
  app/                      # Composición de dependencias y tema
  features/cases/
    domain/                 # Borrador, contrato del repositorio y enlace
    data/                   # Repositorio local en memoria
    presentation/           # Controlador y pantallas
test/                       # Pruebas de dominio y widgets
android/                    # Proyecto nativo Android
ios/                        # Proyecto nativo iOS
rules/                      # Reglas mantenidas por el equipo
skills/                     # Guías por tarea para asistentes de IA
docs/                       # Arquitectura y forma de trabajo
.github/workflows/          # Validación Flutter, Android e iOS manual
```

## Validación

```bash
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
flutter build apk --debug
```

GitHub Actions ejecuta `Flutter checks` y `Android build` en pushes y pull requests. El APK debug se conserva siete días como artifact. `iOS simulator build` se ejecuta manualmente desde Actions en un runner macOS; no publica nada en App Store y no se considera verificado hasta que su ejecución pase. Usar ese runner consume la cuota correspondiente de GitHub Actions.

## Dos ingenieros y desarrollo con IA

Leer [CONTRIBUTING.md](CONTRIBUTING.md), [AGENTS.md](AGENTS.md) y [flujo del equipo](docs/workflow.md). `main` es la base estable; `work/engineer-1` y `work/engineer-2` son las ramas iniciales de trabajo. Cada PR debe tener validación y revisión del otro ingeniero. GitHub Free no aplica protección de ramas en repositorios privados: estas reglas son una convención del equipo hasta habilitar un plan compatible.

El [servidor](https://github.com/Hackaton-FEE/server) es independiente. Su contrato inicial es `GET /api/v1/health`; esta app todavía no lo consume. No incluir claves privadas en Dart, `--dart-define`, assets ni código nativo: cualquier valor distribuido en una app puede extraerse.

## Siguiente entrega sugerida

1. Acordar contrato de casos y autenticación con el servidor.
2. Implementar recepción de enlaces en Android y una Share Extension de iOS con pruebas en dispositivos reales.
3. Añadir persistencia, acceso por usuario y seguimiento con estados verificables.
4. Preparar solicitudes revisables para una plataforma y una jurisdicción concretas.

Referencias: [crear una app Flutter](https://docs.flutter.dev/reference/create-new-app) y [protección de ramas en GitHub](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches/about-protected-branches).
