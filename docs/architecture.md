# Arquitectura del cliente

`Hackaton-FEE/app` es una aplicación Flutter 3.47.2 / Dart 3.13.2 para Android e iOS. El scaffold demuestra creación, validación y listado de borradores de casos mediante una URL introducida por el usuario. Los datos viven en memoria y se pierden al reiniciar. No hay llamadas al servidor, almacenamiento persistente ni envío de solicitudes a terceros.

## Organización

| Área | Responsabilidad |
| --- | --- |
| `lib/main.dart` | Entrada de la aplicación. |
| `lib/app/` | Composición de la app y tema visual. |
| `lib/features/cases/domain/` | Borrador, validación del enlace y contrato del repositorio. |
| `lib/features/cases/data/` | Implementación del repositorio en memoria. |
| `lib/features/cases/presentation/` | Controlador, listado y formulario de nuevo caso. |

La presentación usa el dominio y el contrato del repositorio; la implementación de datos conserva los borradores durante la sesión. Esta separación permite probar reglas y widgets sin red. Mantén las decisiones de dominio fuera de los widgets cuando tengan lógica propia.

## Límite con el servidor

El repositorio separado `Hackaton-FEE/server` proporciona inicialmente `GET /api/v1/health`, con respuesta HTTP 200 `{"status":"ok","service":"fee-server","version":"0.1.0"}`. La app aún no consume ese endpoint. No existe contrato de creación, envío o resolución de casos en este scaffold.

Una integración futura debe distinguir estado local, solicitud enviada, respuesta de una plataforma, retiro en origen y desindexación. Cada afirmación de la UI debe corresponder a evidencia del estado que muestra. Un hash no convierte una arquitectura en conocimiento cero.

## Roadmap, fuera de la entrega inicial

1. Conectar una comprobación de salud de solo lectura y acordar contratos con el servidor.
2. Definir persistencia, ciclo de vida del borrador y un primer tipo de solicitud con revisión del usuario.
3. Evaluar extensiones de compartir, identidad/KYC, manejo de imágenes íntimas y adaptadores externos como trabajos separados, con requisitos propios.

No hay reportes ni escalamiento automáticos implementados. La documentación conceptual describe una visión más amplia, no funciones disponibles.

Android puede compilarse en el entorno de desarrollo actual. Compilar y firmar iOS requiere macOS/Xcode; el workflow iOS es manual para controlar consumo de runners.
