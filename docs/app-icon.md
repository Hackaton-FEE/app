# Icono de Osisnt

El arte aprobado se conserva en
`assets/logo/raster/osisnt_app_icon.png`. Es la misma pieza con fondo grafito y
símbolo en relieve utilizada en el pitch. Los SVG originales se mantienen para
usos donde se necesita un símbolo plano, incluida la versión temática de Android.

El cambio se limita al icono externo del lanzador Android. La interfaz conserva
su logotipo SVG original y el indicador animado de carga. El PNG fuente no se
incluye en los assets de Flutter; solo se utiliza para generar recursos nativos.

## Android

El manifiesto sigue apuntando a `@mipmap/ic_launcher`. Los recursos incluyen:

- PNG tradicionales de 48, 72, 96, 144 y 192 píxeles.
- Un icono adaptativo desde Android 8 (API 26), con fondo grafito independiente.
- Una capa monocromática desde Android 13 (API 33), para lanzadores que permiten
  iconos con los colores elegidos por la persona.

Las capas adaptativas miden 108 dp. El arte se sitúa de modo que el símbolo queda
dentro de la zona central de 66 dp; el lanzador recorta el marco exterior según
su máscara. La apariencia del contorno depende del dispositivo. La versión
temática utiliza el símbolo SVG original, sin convertir el fondo en una mancha.
Se sigue la [guía de iconos adaptativos de Android](https://developer.android.com/develop/ui/compose/system/icon_design_adaptive).

## Regenerar

`tool/generate_app_icons.cjs` necesita Node.js y `sharp` disponible en su ruta de
módulos. No añade una dependencia al cliente Flutter. Si se usa un entorno que
ya incluye `sharp`, basta con configurar `NODE_PATH` hacia ese `node_modules`:

```sh
NODE_PATH=/ruta/a/node_modules node tool/generate_app_icons.cjs
```

El argumento opcional permite preparar recursos a partir de otro PNG cuadrado:

```sh
NODE_PATH=/ruta/a/node_modules node tool/generate_app_icons.cjs ruta/al/icono.png
```

Después de regenerar, revisa el icono a tamaño pequeño y con máscaras circular y
redondeada; compila Android para validar las referencias de los recursos. Los
recursos están versionados, por lo que una compilación normal no necesita Node
ni `sharp`. iOS permanece aplazado conforme a la arquitectura del proyecto.

## Verificación

Se verificaron formato, límite de tamaño de código, análisis estático y las
335 pruebas de Flutter (una prueba de red opt-in omitida). El APK debug compiló.
Se inspeccionaron máscaras circular y redondeada del lanzador. El componente
`AppLogo`, sus pruebas y la declaración de assets de Flutter se conservan
exactamente como estaban antes de este cambio.

La actualización por `adb install -r` al Pixel 10 Pro XL fue rechazada con
`INSTALL_FAILED_UPDATE_INCOMPATIBLE`: la instalación previa tiene otra firma.
No se desinstaló la app ni se borraron datos. La inspección en ese dispositivo
queda pendiente de compilar con la firma original. No se verificaron iOS ni
lectores de pantalla en dispositivo.
