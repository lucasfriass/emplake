import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Estilo neumórfico (relevo suave) que segue o tema/cor semente do usuário.
class NeuStyle {
  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  /// Cor base: a mesma do fundo da tela, para o relevo "emergir" dela.
  static Color base(BuildContext context) =>
      Theme.of(context).colorScheme.surfaceContainer;

  static List<BoxShadow> raised(
    BuildContext context, {
    double distance = 6,
    double blur = 14,
  }) {
    final dark = isDark(context);
    return [
      BoxShadow(
        color: dark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.white.withValues(alpha: 0.9),
        offset: Offset(-distance, -distance),
        blurRadius: blur,
      ),
      BoxShadow(
        color: dark
            ? Colors.black.withValues(alpha: 0.55)
            : const Color(0xFF8A94A6).withValues(alpha: 0.45),
        offset: Offset(distance, distance),
        blurRadius: blur,
      ),
    ];
  }
}

/// Caixa com relevo (elevada) ou rebaixada (pressed = efeito "afundado").
class NeuBox extends StatelessWidget {
  const NeuBox({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 20,
    this.pressed = false,
    this.depth = 6,
    this.color,
    this.borderColor,
    this.extraShadows = const [],
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final bool pressed;
  final double depth;
  final Color? color;
  final Color? borderColor;
  final List<BoxShadow> extraShadows;

  @override
  Widget build(BuildContext context) {
    final base = color ?? NeuStyle.base(context);
    final dark = NeuStyle.isDark(context);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      padding: padding,
      decoration: BoxDecoration(
        color: pressed ? null : base,
        gradient: pressed
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color.lerp(base, Colors.black, dark ? 0.35 : 0.10)!,
                  Color.lerp(base, Colors.white, dark ? 0.06 : 0.55)!,
                ],
              )
            : null,
        borderRadius: BorderRadius.circular(radius),
        border: borderColor != null
            ? Border.all(color: borderColor!, width: 2)
            : null,
        boxShadow: [
          if (!pressed)
            ...NeuStyle.raised(
              context,
              distance: depth,
              blur: depth * 2.2,
            ),
          ...extraShadows,
        ],
      ),
      child: child,
    );
  }
}

/// Botão neumórfico: afunda ao ser pressionado ou quando `selected`.
class NeuButton extends StatefulWidget {
  const NeuButton({
    super.key,
    required this.child,
    required this.onPressed,
    this.selected = false,
    this.filled = false,
    this.radius = 16,
    this.minSize = const Size(52, 48),
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    this.tooltip,
  });

  final Widget child;
  final VoidCallback? onPressed;
  final bool selected;

  /// Botão de destaque, pintado com a cor primária do tema.
  final bool filled;
  final double radius;
  final Size minSize;
  final EdgeInsets padding;
  final String? tooltip;

  @override
  State<NeuButton> createState() => _NeuButtonState();
}

class _NeuButtonState extends State<NeuButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    Widget button = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      onTap: widget.onPressed,
      child: NeuBox(
        padding: widget.padding,
        radius: widget.radius,
        depth: _down ? 2 : 5,
        pressed: (_down || widget.selected) && !widget.filled,
        color: widget.filled ? scheme.primary : null,
        borderColor: widget.selected ? scheme.primary : null,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: math.max(0.0, widget.minSize.width - widget.padding.horizontal),
            minHeight: math.max(0.0, widget.minSize.height - widget.padding.vertical),
          ),
          child: Center(
            widthFactor: 1,
            heightFactor: 1,
            child: DefaultTextStyle.merge(
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: widget.filled
                    ? scheme.onPrimary
                    : (widget.selected ? scheme.primary : scheme.onSurface),
              ),
              child: IconTheme.merge(
                data: IconThemeData(
                  color: widget.filled
                      ? scheme.onPrimary
                      : (widget.selected ? scheme.primary : scheme.onSurface),
                ),
                child: widget.child,
              ),
            ),
          ),
        ),
      ),
    );

    button = MouseRegion(
      cursor: widget.onPressed == null
          ? SystemMouseCursors.basic
          : SystemMouseCursors.click,
      child: Semantics(button: true, child: button),
    );

    if (widget.tooltip != null) {
      button = Tooltip(message: widget.tooltip!, child: button);
    }
    return button;
  }
}