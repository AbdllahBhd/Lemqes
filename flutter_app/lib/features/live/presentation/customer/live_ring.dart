import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/theme/lemqes_gradients.dart';
import '../../../../core/theme/status_colors.dart';
import '../../data/live_derive.dart';
import '../../data/live_models.dart';
import '../../data/live_providers.dart';

enum LiveRingKind { open, onBreak, none }

/// The ring a status earns: the Lagoon ring when open, a dashed grey one on
/// break, none when closed, uncertain or while the connection is down (a
/// ring claims "live").
LiveRingKind liveRingOf(LiveView? v, {required bool connected}) {
  if (v == null || !connected || v.stale) return LiveRingKind.none;
  return switch (v.status) {
    LiveStatus.open => LiveRingKind.open,
    LiveStatus.onBreak => LiveRingKind.onBreak,
    LiveStatus.closed => LiveRingKind.none,
  };
}

/// The ring stroke and the gap between it and the photo.
const _stroke = 2.5;
const _gap = 2.0;

/// A pro's photo with its live ring. Takes the same room with or without a
/// ring, so cards stay aligned whatever their status. Decorative: the status
/// line says the same in words.
class LiveRing extends ConsumerWidget {
  const LiveRing({required this.view, required this.child, super.key});

  final LiveView? view;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kind = liveRingOf(view, connected: ref.watch(liveConnectedProvider));
    final theme = Theme.of(context);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return ExcludeSemantics(
      child: Stack(
        alignment: Alignment.center,
        children: [
          Padding(padding: const EdgeInsets.all(_stroke + _gap), child: child),
          Positioned.fill(
            child: AnimatedSwitcher(
              duration: reduceMotion
                  ? Duration.zero
                  : const Duration(milliseconds: 200),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              child: SizedBox.expand(
                key: Key('liveRing_${kind.name}'),
                child: CustomPaint(
                  painter: switch (kind) {
                    LiveRingKind.open => _GradientRing(
                      theme.extension<LemqesGradients>()!.button,
                    ),
                    LiveRingKind.onBreak => _DashedRing(
                      context.statusColors.closed,
                    ),
                    LiveRingKind.none => null,
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GradientRing extends CustomPainter {
  const _GradientRing(this.gradient);

  final Gradient gradient;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(_stroke / 2);
    canvas.drawOval(
      rect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _stroke
        ..shader = gradient.createShader(Offset.zero & size),
    );
  }

  @override
  bool shouldRepaint(_GradientRing old) => old.gradient != gradient;
}

class _DashedRing extends CustomPainter {
  const _DashedRing(this.color);

  final Color color;

  static const _dashes = 18;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(_stroke / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..color = color;
    const step = 2 * math.pi / _dashes;
    for (var i = 0; i < _dashes; i++) {
      canvas.drawArc(rect, i * step, step * 0.55, false, paint);
    }
  }

  @override
  bool shouldRepaint(_DashedRing old) => old.color != color;
}
