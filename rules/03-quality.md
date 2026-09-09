# Calidad del cliente

- Conserva Flutter 3.47.2 / Dart 3.13.2 y dependencias resueltas en `pubspec.lock`. Añade paquetes cuando el comportamiento pedido los justifique.
- Mantén responsabilidades: modelos inmutables y validación en dominio; repositorio asíncrono como fuente de verdad; plugin detrás del adaptador; estado de pantalla con `ChangeNotifier`. Inyecta dependencias por constructor y comparte una sola instancia de repositorio.
- Prueba comportamiento observable: edición válida/inválida, persistencia al recrear el repositorio, errores de escritura sin falso éxito y lectura corrupta sin pérdida automática. No escribas pruebas que solo reproduzcan el código o texto modificado.
- Usa dobles para pruebas unitarias y de widgets; verifica el adaptador con el plugin real en integración. Sigue [la guía de pruebas](../docs/testing.md) para distinguir esa comprobación de un cierre y reapertura del proceso.
- Ejecuta formato, análisis, pruebas y build Android según [CONTRIBUTING.md](../CONTRIBUTING.md). Los cambios nativos iOS requieren macOS/Xcode o una limitación explícita en el PR. Reporta únicamente validaciones realizadas.
