import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Indicador de carga oficial con la animación de viento formando una huella digital.
///
/// La animación muestra una ráfaga de viento que ingresa desde la derecha y, a
/// medida que avanza hacia la izquierda, la cola trasera se elimina para formar
/// una huella digital limpia, centrada y sin apéndices.
///
/// Disponible en Blanco y Negro:
/// - [isDarkMode] = `false`: Renderiza en Negro (`#000000`).
/// - [isDarkMode] = `true`: Renderiza en Blanco (`#FFFFFF`).
class LogoLoadingIndicator extends StatefulWidget {
  /// Tamaño del indicador de carga (ancho de referencia).
  final double size;

  /// Duración de un ciclo completo de 120 frames (por defecto 2000ms a 60 FPS).
  final Duration duration;

  /// Si debe reproducir la secuencia de 120 fotogramas SVG o el SVG autónomo.
  final bool useFrames;

  /// Mensaje descriptivo opcional debajo del logo de carga.
  final String? message;

  /// Si está en modo oscuro (usa la secuencia en blanco puro). Si es null, lo deduce de Theme.of(context).
  final bool? isDarkMode;

  /// Tinte opcional para forzar un color específico.
  final Color? colorOverride;

  const LogoLoadingIndicator({
    super.key,
    this.size = 96.0,
    this.duration = const Duration(milliseconds: 2000),
    this.useFrames = true,
    this.message,
    this.isDarkMode,
    this.colorOverride,
  });

  @override
  State<LogoLoadingIndicator> createState() => _LogoLoadingIndicatorState();
}

class _LogoLoadingIndicatorState extends State<LogoLoadingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  int _currentFrame = 1;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    )..addListener(_onAnimationTick);

    if (widget.useFrames) {
      _controller.repeat();
    }
  }

  void _onAnimationTick() {
    final frame = (1 + (_controller.value * 119)).round().clamp(1, 120);
    if (frame != _currentFrame) {
      setState(() {
        _currentFrame = frame;
      });
    }
  }

  @override
  void didUpdateWidget(covariant LogoLoadingIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.duration != widget.duration) {
      _controller.duration = widget.duration;
    }
    if (oldWidget.useFrames != widget.useFrames) {
      if (widget.useFrames) {
        _controller.repeat();
      } else {
        _controller.stop();
      }
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onAnimationTick);
    _controller.dispose();
    super.dispose();
  }

  String _formatFrame(int n) => n.toString().padLeft(3, '0');

  @override
  Widget build(BuildContext context) {
    final dark = widget.isDarkMode ?? (Theme.of(context).brightness == Brightness.dark);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    final ColorFilter? filter = widget.colorOverride != null
        ? ColorFilter.mode(widget.colorOverride!, BlendMode.srcIn)
        : null;

    Widget loaderWidget;

    if (widget.useFrames && !reduceMotion) {
      final folder = dark ? 'frames_120_white' : 'frames_120';
      final framePath = 'assets/logo/$folder/frame_${_formatFrame(_currentFrame)}.svg';

      loaderWidget = SizedBox(
        width: widget.size,
        height: widget.size * (928.0 / 1152.0),
        child: SvgPicture.asset(
          framePath,
          fit: BoxFit.contain,
          colorFilter: filter,
          placeholderBuilder: (_) => const SizedBox.shrink(),
        ),
      );
    } else {
      final standalonePath = dark
          ? 'assets/logo/standalone/logo_loading_white.svg'
          : 'assets/logo/standalone/logo_loading_black.svg';

      loaderWidget = SizedBox(
        width: widget.size,
        height: widget.size * (928.0 / 1152.0),
        child: SvgPicture.asset(
          standalonePath,
          fit: BoxFit.contain,
          colorFilter: filter,
        ),
      );
    }

    if (widget.message == null) {
      return Semantics(
        label: 'Cargando contenido...',
        child: loaderWidget,
      );
    }

    final textColor = dark ? Colors.white : const Color(0xFF0F172A);

    return Semantics(
      label: widget.message,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          loaderWidget,
          const SizedBox(height: 16),
          Text(
            widget.message!,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: textColor,
              letterSpacing: 0.2,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
