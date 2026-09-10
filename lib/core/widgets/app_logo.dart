import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Logotipo vectorial oficial de Osisn't.
///
/// Renderiza el isotipo de la corriente de viento que culmina en la huella dactilar.
/// Se adapta dinámicamente al modo claro u oscuro del tema o admite un color
/// explícito para personalización en contextos especiales.
class AppLogo extends StatelessWidget {
  /// Tamaño de referencia (ancho) del isotipo.
  final double size;

  /// Si se debe forzar el modo oscuro (blanco puro) o modo claro (negro institucional).
  /// Si es `null`, infiere el brillo a partir de `Theme.of(context).brightness`.
  final bool? isDarkMode;

  /// Tinte de color opcional para sobrescribir el color del vector.
  final Color? color;

  /// Etiqueta semántica para lectores de pantalla. Si es `null`, se excluye de la semántica.
  final String? semanticLabel;

  const AppLogo({
    super.key,
    this.size = 32.0,
    this.isDarkMode,
    this.color,
    this.semanticLabel = "Logotipo de Osisn't",
  });

  @override
  Widget build(BuildContext context) {
    final dark =
        isDarkMode ?? (Theme.of(context).brightness == Brightness.dark);
    final assetPath = dark
        ? 'assets/logo/vector/logo_dark_white.svg'
        : 'assets/logo/vector/logo_monochrome.svg';

    final ColorFilter? filter = color != null
        ? ColorFilter.mode(color!, BlendMode.srcIn)
        : null;

    final logoWidget = SizedBox(
      width: size,
      height: size * (928.0 / 1152.0),
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
