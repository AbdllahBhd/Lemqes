import 'package:flutter/widgets.dart';

/// Keeps phone numbers, codes, counts and ± controls left-to-right inside RTL.
class Ltr extends StatelessWidget {
  const Ltr({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) =>
      Directionality(textDirection: TextDirection.ltr, child: child);
}
