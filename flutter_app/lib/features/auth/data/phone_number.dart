/// Normalizes user input to E.164 `+213XXXXXXXXX`, or null when it is not an
/// Algerian mobile number (first digit 5, 6 or 7 followed by 8 digits).
String? normalizeAlgerianMobile(String input) {
  final buffer = StringBuffer();
  for (final unit in input.runes) {
    if (unit >= 0x0660 && unit <= 0x0669) {
      buffer.writeCharCode(0x30 + unit - 0x0660);
    } else if (unit >= 0x06F0 && unit <= 0x06F9) {
      buffer.writeCharCode(0x30 + unit - 0x06F0);
    } else {
      buffer.writeCharCode(unit);
    }
  }
  var s = buffer.toString().replaceAll(RegExp(r'[\s.\-()]'), '');
  if (s.startsWith('+213')) {
    s = s.substring(4);
    if (s.startsWith('0')) s = s.substring(1);
  } else if (s.startsWith('00213')) {
    s = s.substring(5);
    if (s.startsWith('0')) s = s.substring(1);
  } else if (s.startsWith('213') && s.length == 12) {
    s = s.substring(3);
  } else if (s.startsWith('0')) {
    s = s.substring(1);
  }
  if (!RegExp(r'^[567][0-9]{8}$').hasMatch(s)) return null;
  return '+213$s';
}
