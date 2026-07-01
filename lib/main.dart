import 'package:flutter/material.dart';

import 'library_screen.dart';

void main() {
  runApp(const ShelfmarkApp());
}

class ShelfmarkApp extends StatelessWidget {
  const ShelfmarkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Shelfmark',
      theme: ThemeData(
        colorSchemeSeed: Colors.blueGrey,
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      home: const LibraryScreen(),
    );
  }
}
