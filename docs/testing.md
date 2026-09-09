# Verificar casos locales

Usa datos ficticios, por ejemplo título `Caso de prueba`, URL `https://example.com/publicacion`, categoría de organización y notas sin datos personales. Conserva los datos reales del dispositivo fuera de las pruebas automatizadas.

## Verificación rápida

Desde la raíz, con Flutter 3.47.2 / Dart 3.13.2:

```sh
flutter pub get --enforce-lockfile
dart format --output=none --set-exit-if-changed lib test integration_test
flutter analyze
flutter test
flutter build apk --debug
```

Las pruebas unitarias verifican validación, lectura/escritura y fallos mediante dobles. Las pruebas de widgets verifican interacciones y estados visibles. No usan el backend ni servicios externos. Al cambiar comportamiento, comprueba el caso que el usuario observa y los errores relevantes; no hace falta volver a probar rutas ajenas a un cambio editorial.

## Almacenamiento nativo

La prueba `integration_test/local_case_storage_test.dart` requiere un emulador o dispositivo Android; para iOS requiere macOS/Xcode y un destino iOS. Selecciona el identificador real mostrado por `flutter devices`:

```sh
flutter devices
flutter test integration_test/local_case_storage_test.dart -d <device-id>
```

Esta prueba usa el plugin nativo y vuelve a crear el almacenamiento/repositorio para comprobar persistencia, además de editar, archivar/restaurar y eliminar. Mantiene sus registros separados mediante un espacio de almacenamiento y prefijo de prueba. No detiene ni vuelve a iniciar el proceso de la aplicación; informa ese alcance cuando registres sus resultados.

Una prueba Android no valida Keychain de iOS. Un build iOS verifica compilación, no lectura/escritura en un dispositivo: registra por separado esas comprobaciones.

El workflow manual `iOS simulator build` selecciona un iPhone disponible, ejecuta esta misma prueba de integración contra Keychain y después compila la app normal. Puede lanzarse sobre una rama de PR desde Actions; no necesita credenciales de distribución.

## Cierre y reapertura en Android

Esta comprobación manual completa la prueba de integración. Instala una vez el APK o usa `flutter run` en el destino y después abre la misma instalación desde su icono.

1. Crea un caso ficticio y espera la confirmación de guardado. Abre su detalle y comprueba título, enlace, categoría y notas.
2. Edita el título y las notas; guarda y comprueba el resultado. Busca el título nuevo.
3. Archiva el caso y verifica que aparece en la vista correspondiente. No lo elimines todavía.
4. Desde Ajustes de Android → Aplicaciones → la app, usa **Forzar detención**. Abre de nuevo desde su icono: el caso debe conservar la edición y el estado archivado.
5. Restaura el caso a borrador, fuerza otra detención y vuelve a abrir. Comprueba el estado restaurado.
6. Elimina ese caso de prueba, confirma la acción y repite cierre/reapertura: no debe volver a aparecer.

No desinstales, reinstales ni uses **Borrar almacenamiento/datos** entre los pasos: esas acciones no simulan reinicio y pueden eliminar los registros. Hot reload tampoco sustituye esta comprobación. Opcionalmente reinicia el dispositivo manteniendo la instalación para verificar ese escenario por separado.

## Fallos y evidencia del PR

Los dobles de prueba permiten simular almacenamiento inaccesible, escritura fallida y JSON inválido o de versión desconocida sin dañar datos del teléfono. Verifica que no se anuncie éxito ni se sustituya el contenido por una colección vacía. Para cambios de validación de texto, incluye emojis y caracteres combinados dentro de los límites visibles, y una entrada que exceda la cota independiente de 24 KiB de metadatos UTF-8. No introduzcas corrupción en un dispositivo con datos de trabajo.

En el PR indica comandos ejecutados, plataforma/destino, resultado del plugin real y si se completó cierre/reapertura. Adjunta capturas con datos ficticios si cambió la UI. No sumes tests de mocks, integración y reinicio manual como si demostraran lo mismo.
