import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Icono oficial de Osisnt, con relieve marfil sobre grafito.
///
/// Conserva las variantes vectoriales para los contextos que soliciten un
/// color, modo de contraste o los colores originales explícitamente.
class AppLogo extends StatelessWidget {
  /// Tamaño de referencia (ancho base) del isotipo cuando no se especifican [width] ni [height].
  final double size;

  /// Ancho explícito opcional. Si se define sin [height], calcula la altura automáticamente según el aspect ratio oficial.
  final double? width;

  /// Alto explícito opcional. Si se define sin [width], calcula el ancho automáticamente según el aspect ratio oficial.
  final double? height;

  /// Solicita el vector blanco o negro. Si es `null`, usa el icono de la app.
  final bool? isDarkMode;

  /// Tinte de color opcional para sobrescribir el color del vector.
  final Color? color;

  /// Etiqueta semántica para lectores de pantalla. Si es `null`, se excluye de la semántica.
  final String? semanticLabel;

  /// Si es true, usa los colores y gradientes originales del vector recortado en lugar de la variante monocromática.
  final bool useOriginalColors;

  /// Dimensiones canónicas del SVG recortado oficial.
  static const double originalWidth = 643.7101449275362;
  static const double originalHeight = 850.048;
  static const double vectorAspectRatio = originalWidth / originalHeight;
  static const double aspectRatio = 1;

  const AppLogo({
    super.key,
    this.size = 32.0,
    this.width,
    this.height,
    this.isDarkMode,
    this.color,
    this.semanticLabel = 'Logotipo de Osisnt',
    this.useOriginalColors = false,
  });

  @override
  Widget build(BuildContext context) {
    final useVector = isDarkMode != null || color != null || useOriginalColors;
    final ratio = useVector ? vectorAspectRatio : aspectRatio;
    final dark =
        isDarkMode ?? (Theme.of(context).brightness == Brightness.dark);
    final assetPath = useOriginalColors
        ? 'assets/logo/vector/logo_cropped.svg'
        : (dark
              ? 'assets/logo/vector/logo_dark_white.svg'
              : 'assets/logo/vector/logo_monochrome.svg');

    final ColorFilter? filter = color != null
        ? ColorFilter.mode(color!, BlendMode.srcIn)
        : null;

    final double effectiveWidth =
        width ?? (height != null ? height! * ratio : size);
    final double effectiveHeight =
        height ?? (width != null ? width! / ratio : size / ratio);

    final logoWidget = SizedBox(
      width: effectiveWidth,
      height: effectiveHeight,
      child: useVector
          ? SvgPicture.asset(
              assetPath,
              fit: BoxFit.contain,
              colorFilter: filter,
              excludeFromSemantics: true,
            )
          : Image.asset(
              'assets/logo/raster/osisnt_app_icon.png',
              fit: BoxFit.contain,
              excludeFromSemantics: true,
            ),
    );

    if (semanticLabel == null || semanticLabel!.isEmpty) {
      return ExcludeSemantics(child: logoWidget);
    }

    return Semantics(label: semanticLabel, image: true, child: logoWidget);
  }
}
