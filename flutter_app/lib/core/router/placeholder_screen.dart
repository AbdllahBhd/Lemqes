import 'package:flutter/material.dart';

/// Stand-in for screens built in later tasks.
class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen(this.name, {super.key});

  final String name;

  @override
  Widget build(BuildContext context) =>
      Scaffold(body: Center(child: Text(name)));
}
