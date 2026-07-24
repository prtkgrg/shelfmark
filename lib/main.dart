import 'package:flutter/material.dart';

import 'library_screen.dart';
import 'notifications.dart';
import 'theme_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ThemeController.load();
  await Notifications.init();
  runApp(const ShelfmarkApp());
}

class ShelfmarkApp extends StatelessWidget {
  const ShelfmarkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController.mode,
      builder: (context, mode, _) {
        return MaterialApp(
          title: 'Shelfmark',
          themeMode: mode,
          theme: ThemeData(
            colorSchemeSeed: Colors.blueGrey,
            brightness: Brightness.light,
            useMaterial3: true,
          ),
          darkTheme: ThemeData(
            colorSchemeSeed: Colors.blueGrey,
            brightness: Brightness.dark,
            useMaterial3: true,
          ),
          home: const LibraryScreen(),
        );
      },
    );
  }
}
