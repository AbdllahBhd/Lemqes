import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class LemqesApp extends ConsumerWidget {
  const LemqesApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const MaterialApp(
      title: 'LEMQES',
      home: Scaffold(body: Center(child: Text('LEMQES'))),
    );
  }
}
