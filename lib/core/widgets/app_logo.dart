import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Logotipo vectorial oficial de Osisn't (Isotipo recortado y optimizado).
///
/// Renderiza el isotipo de la corriente de viento que culmina en la huella dactilar,
/// con recorte ajustado al contorno biométrico sin márgenes vacíos.
/// Se adapta dinámicamente al modo claro u oscuro del tema o admite un color
/// explícito para personalización en contextos especiales.
class AppLogo extends StatelessWidget {
  /// Tamaño de referencia (ancho base) del isotipo cuando no se especifican [width] ni [height].
  final double size;

  /// Ancho explícito opcional. Si se define sin [height], calcula la altura automáticamente según el aspect ratio oficial.
  final double? width;

  /// Alto explícito opcional. Si se define sin [width], calcula el ancho automáticamente según el aspect ratio oficial.
  final double? height;

  /// Si se debe forzar el modo oscuro (blanco puro) o modo claro (negro institucional).
  /// Si es `null`, infiere el brillo a partir de `Theme.of(context).brightness`.
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
  static const double aspectRatio = originalWidth / originalHeight; // ~0.7573

  const AppLogo({
    super.key,
    this.size = 32.0,
    this.width,
    this.height,
    this.isDarkMode,
    this.color,
    this.semanticLabel = "Logotipo de Osisn't",
    this.useOriginalColors = false,
  });

  @override
  Widget build(BuildContext context) {
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
        width ?? (height != null ? height! * aspectRatio : size);
    final double effectiveHeight =
        height ?? (width != null ? width! / aspectRatio : size / aspectRatio);

    final logoWidget = SizedBox(
      width: effectiveWidth,
      height: effectiveHeight,
      child: SvgPicture.asset(
        assetPath,
        fit: BoxFit.contain,
        colorFilter: filter,
      ),
    );

    if (semanticLabel == null || semanticLabel!.isEmpty) {
      return ExcludeSemantics(child: logoWidget);
    }

    return Semantics(label: semanticLabel, image: true, child: logoWidget);
  }
}
