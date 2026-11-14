import 'package:material_ui/material_ui.dart';

import 'lemqes_tokens.dart';

/// Open / on-break / closed inks, picked per brightness so each stays AA on
/// its surface.
@immutable
class StatusColors extends ThemeExtension<StatusColors> {
  const StatusColors({
    required this.open,
    required this.onBreak,
    required this.closed,
  });

  static const light = StatusColors(
    open: LemqesColors.open,
    onBreak: LemqesColors.onBreak,
    closed: LemqesColors.closed,
  );

  static const dark = StatusColors(
    open: LemqesColors.openOnDark,
    onBreak: LemqesColors.onBreakOnDark,
    closed: LemqesColors.closedOnDark,
  );

  final Color open;
  final Color onBreak;
  final Color closed;

  @override
  StatusColors copyWith({Color? open, Color? onBreak, Color? closed}) =>
      StatusColors(
        open: open ?? this.open,
        onBreak: onBreak ?? this.onBreak,
        closed: closed ?? this.closed,
      );

  @override
  StatusColors lerp(StatusColors? other, double t) {
    if (other == null) return this;
    return StatusColors(
      open: Color.lerp(open, other.open, t)!,
      onBreak: Color.lerp(onBreak, other.onBreak, t)!,
      closed: Color.lerp(closed, other.closed, t)!,
    );
  }
}

extension StatusColorsX on BuildContext {
  StatusColors get statusColors => Theme.of(this).extension<StatusColors>()!;
}
