import 'package:flutter/material.dart';

import '../../core/theme/lemqes_gradients.dart';

/// The one primary action of a screen: a Lagoon gradient pill.
///
/// Disabled when [onPressed] is null. While [loading], a spinner takes the
/// icon's place, the label stays, and taps are ignored.
class LemqesPrimaryButton extends StatefulWidget {
  const LemqesPrimaryButton({
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.icon,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData? icon;

  @override
  State<LemqesPrimaryButton> createState() => _LemqesPrimaryButtonState();
}

class _LemqesPrimaryButtonState extends State<LemqesPrimaryButton> {
  static const double _iconSize = 18;
  static const double _ringGap = 3;
  static const double _ringWidth = 2;

  // A blue-tinted drop below the pill; on deep-sea ground a plain dark one,
  // since a coloured glow there reads as a halo.
  static const List<BoxShadow> _lightShadow = [
    BoxShadow(
      color: Color(0x991F6FD1),
      offset: Offset(0, 10),
      blurRadius: 20,
      spreadRadius: -8,
    ),
  ];
  static const List<BoxShadow> _darkShadow = [
    BoxShadow(
      color: Color(0x99000000),
      offset: Offset(0, 8),
      blurRadius: 16,
      spreadRadius: -6,
    ),
  ];

  bool _focused = false;

  @override
  void initState() {
    super.initState();
    FocusManager.instance.addHighlightModeListener(_onHighlightModeChanged);
  }

  @override
  void dispose() {
    FocusManager.instance.removeHighlightModeListener(_onHighlightModeChanged);
    super.dispose();
  }

  void _onHighlightModeChanged(FocusHighlightMode _) => setState(() {});

  // Keyboard users see a ring; touch focus is invisible, as in Material.
  bool get _showFocusRing =>
      _focused &&
      FocusManager.instance.highlightMode == FocusHighlightMode.traditional;

  static void _ignoreWhileLoading() {}

  Color? _stateLayer(Set<WidgetState> states) {
    if (widget.loading) return null;
    if (states.contains(WidgetState.pressed)) {
      return Colors.black.withValues(alpha: 0.16);
    }
    // Darkening, never lightening: white label on the blue end only clears
    // AA by a small margin (4.94:1).
    if (states.contains(WidgetState.focused)) {
      return Colors.black.withValues(alpha: 0.10);
    }
    if (states.contains(WidgetState.hovered)) {
      return Colors.black.withValues(alpha: 0.08);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final gradients = theme.extension<LemqesGradients>()!;
    final enabled = widget.onPressed != null;
    final foreground = enabled
        ? Colors.white
        : scheme.onSurface.withValues(alpha: 0.38);

    final leading = widget.loading
        ? SizedBox.square(
            dimension: _iconSize,
            child: CircularProgressIndicator(strokeWidth: 2, color: foreground),
          )
        : widget.icon == null
        ? null
        : Icon(widget.icon, size: _iconSize);

    final button = FilledButton(
      clipBehavior: Clip.antiAlias,
      onFocusChange: (focused) => setState(() => _focused = focused),
      onPressed: widget.loading && enabled
          ? _ignoreWhileLoading
          : widget.onPressed,
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(Size(64, 48)),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 24),
        ),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: const WidgetStatePropertyAll(StadiumBorder()),
        elevation: const WidgetStatePropertyAll(0),
        textStyle: WidgetStatePropertyAll(theme.textTheme.labelLarge),
        foregroundColor: WidgetStatePropertyAll(foreground),
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.disabled)
              ? scheme.onSurface.withValues(alpha: 0.12)
              : Colors.transparent,
        ),
        // State layers are painted over the gradient in backgroundBuilder.
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        splashFactory: NoSplash.splashFactory,
        backgroundBuilder: (context, states, child) {
          if (states.contains(WidgetState.disabled)) return child!;
          return DecoratedBox(
            decoration: BoxDecoration(gradient: gradients.button),
            child: CustomPaint(
              painter: _StateLayerPainter(_stateLayer(states)),
              foregroundPainter: const _TopHighlightPainter(),
              child: child,
            ),
          );
        },
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (leading != null) ...[leading, const SizedBox(width: 8)],
          Flexible(
            child: Text(
              widget.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );

    return Stack(
      clipBehavior: Clip.none,
      children: [
        DecoratedBox(
          decoration: ShapeDecoration(
            shape: const StadiumBorder(),
            shadows: !enabled
                ? null
                : theme.brightness == Brightness.dark
                ? _darkShadow
                : _lightShadow,
          ),
          child: button,
        ),
        if (_showFocusRing)
          const Positioned.fill(
            left: -(_ringGap + _ringWidth),
            top: -(_ringGap + _ringWidth),
            right: -(_ringGap + _ringWidth),
            bottom: -(_ringGap + _ringWidth),
            child: IgnorePointer(child: _FocusRing(width: _ringWidth)),
          ),
      ],
    );
  }
}

class _FocusRing extends StatelessWidget {
  const _FocusRing({required this.width});

  final double width;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: ShapeDecoration(
        shape: StadiumBorder(
          side: BorderSide(
            color: Theme.of(context).colorScheme.primary,
            width: width,
          ),
        ),
      ),
    );
  }
}

/// Material state layer (pressed / hovered / focused) over the gradient.
class _StateLayerPainter extends CustomPainter {
  const _StateLayerPainter(this.color);

  final Color? color;

  @override
  void paint(Canvas canvas, Size size) {
    final color = this.color;
    if (color == null) return;
    canvas.drawRect(Offset.zero & size, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_StateLayerPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// A 1 px light edge along the top of the pill (an inset highlight).
class _TopHighlightPainter extends CustomPainter {
  const _TopHighlightPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final radius = Radius.circular(size.height / 2);
    final outer = RRect.fromRectAndRadius(Offset.zero & size, radius);
    final inner = outer.shift(const Offset(0, 1));
    final path = Path.combine(
      PathOperation.difference,
      Path()..addRRect(outer),
      Path()..addRRect(inner),
    );
    canvas.drawPath(path, Paint()..color = const Color(0x40FFFFFF));
  }

  @override
  bool shouldRepaint(_TopHighlightPainter oldDelegate) => false;
}
