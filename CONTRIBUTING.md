# Contribuir a la app

Trabajamos dos personas con revisión cruzada. `main` conserva una versión comprobable; `work/engineer-1` y `work/engineer-2` identifican las ramas de cada ingeniero. Los cambios posteriores al bootstrap se integran por pull request y squash.

Para una tarea nueva se prefieren ramas breves creadas desde `main`, por ejemplo `feature/engineer-1-case-detail`. Consulta [el flujo completo](docs/workflow.md) para reutilizar o reemplazar una rama después de un squash sin perder trabajo.

Un PR describe el problema, el comportamiento final, su alcance y las verificaciones realizadas. Incluye captura si cambia una pantalla y enlaza el PR del servidor si modifica un contrato compartido. Antes de fusionar, la otra persona debe aprobar y los checks aplicables deben pasar. Es una **convención de equipo, sin enforcement**: el plan GitHub Free de esta organización no ofrece protección de ramas para estos repositorios privados.

Configura Flutter 3.47.2 / Dart 3.13.2 y ejecuta desde la raíz:

```sh
flutter pub get --enforce-lockfile
dart format --output=none --set-exit-if-changed lib test integration_test
flutter analyze
flutter test
flutter build apk --debug
```

`Flutter checks` y `Android build` son los checks automáticos esperados. iOS requiere macOS y Xcode; su compilación en CI se ejecuta manualmente. Un build Android no verifica iOS: deja esa diferencia explícita en el PR cuando afecte integración nativa.

Los cambios de persistencia o integración nativa también siguen [la guía de pruebas](docs/testing.md): una prueba con almacenamiento simulado no verifica el plugin y recrear el repositorio no prueba el reinicio del proceso.

Al trabajar con IA, sigue [AGENTS.md](AGENTS.md) y proporciona objetivo, criterios de aceptación y restricciones. La persona autora revisa el diff y responde por lo que se integra, incluyendo código generado.
