import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import '../../core/theme/lemqes_theme.dart';
import 'ltr.dart';

/// A one-time code entry: [length] digit boxes over a single text field, so
/// paste and SMS autofill fill every box at once.
///
/// Always left-to-right. Eastern Arabic digits are read as Latin digits.
/// [onCompleted] fires each time the field reaches [length] digits.
class CodeField extends StatefulWidget {
  const CodeField({
    required this.onCompleted,
    this.length = 6,
    this.enabled = true,
    this.semanticsLabel,
    super.key,
  });

  final ValueChanged<String> onCompleted;
  final int length;
  final bool enabled;
  final String? semanticsLabel;

  @override
  State<CodeField> createState() => _CodeFieldState();
}

class _CodeFieldState extends State<CodeField> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  String _lastCompleted = '';

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChanged);
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onChanged() {
    final code = _controller.text;
    setState(() {});
    if (code.length < widget.length) {
      _lastCompleted = '';
      return;
    }
    if (code == _lastCompleted) return;
    _lastCompleted = code;
    widget.onCompleted(code);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final code = _controller.text;
    final active = _focus.hasFocus
        ? code.length.clamp(0, widget.length - 1)
        : -1;
    // Boxes grow with the user's text size; FittedBox keeps them on one line.
    final scale = MediaQuery.textScalerOf(context)
        .clamp(minScaleFactor: 1, maxScaleFactor: 2)
        .scale(1);
    final digitStyle = lemqesNumeric.copyWith(
      fontSize: 24 * scale,
      height: 1.2,
      color: scheme.onSurface,
      fontWeight: FontWeight.w600,
    );

    final boxes = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < widget.length; i++) ...[
          if (i > 0) SizedBox(width: i == widget.length ~/ 2 ? 16 : 8),
          _DigitBox(
            digit: i < code.length ? code[i] : null,
            active: i == active,
            style: digitStyle,
            scale: scale,
          ),
        ],
      ],
    );

    return Semantics(
      label: widget.semanticsLabel,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Digit order is left-to-right in every language.
          ExcludeSemantics(
            child: FittedBox(child: Ltr(child: boxes)),
          ),
          // The real input sits over the boxes, invisible, taking the taps;
          // still in the semantics tree, or screen readers could not type.
          Positioned.fill(
            child: Opacity(
              opacity: 0,
              alwaysIncludeSemantics: true,
              child: TextField(
                controller: _controller,
                focusNode: _focus,
                enabled: widget.enabled,
                autofocus: true,
                keyboardType: TextInputType.number,
                textDirection: TextDirection.ltr,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.oneTimeCode],
                showCursor: false,
                enableInteractiveSelection: false,
                inputFormatters: [
                  _LatinDigitsFormatter(),
                  LengthLimitingTextInputFormatter(widget.length),
                ],
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  counterText: '',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DigitBox extends StatelessWidget {
  const _DigitBox({
    required this.digit,
    required this.active,
    required this.style,
    required this.scale,
  });

  final String? digit;
  final bool active;
  final TextStyle style;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      width: 44 * scale,
      height: 56 * scale,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: active ? scheme.primary : scheme.outline,
          width: active ? 2 : 1,
        ),
      ),
      child: Text(digit ?? '', style: style, textScaler: TextScaler.noScaling),
    );
  }
}

/// Keeps digits only, reading Arabic-Indic and Persian digits as 0-9.
class _LatinDigitsFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final out = StringBuffer();
    for (final unit in newValue.text.runes) {
      if (unit >= 0x30 && unit <= 0x39) {
        out.writeCharCode(unit);
      } else if (unit >= 0x0660 && unit <= 0x0669) {
        out.writeCharCode(0x30 + unit - 0x0660);
      } else if (unit >= 0x06F0 && unit <= 0x06F9) {
        out.writeCharCode(0x30 + unit - 0x06F0);
      }
    }
    final text = out.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
