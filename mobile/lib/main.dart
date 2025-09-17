import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'screens/home_screen.dart';
import 'screens/map_screen.dart';

void main() {
  runApp(const AlagAlertApp());
}

class AlagAlertApp extends StatefulWidget {
  const AlagAlertApp({super.key});
  @override
  State<AlagAlertApp> createState() => _AlagAlertAppState();
}

class _AlagAlertAppState extends State<AlagAlertApp> {
  ThemeMode _mode = ThemeMode.system;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AlagAlert',
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      themeMode: _mode,
      routes: {
        '/': (_) => const HomeScreen(),
        '/map': (ctx) {
          final uf = ModalRoute.of(ctx)!.settings.arguments as String? ?? "SP";
          return MapScreen(uf: uf);
        },
      },
      debugShowCheckedModeBanner: false,
    );
  }
}
