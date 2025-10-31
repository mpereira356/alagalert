import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'screens/map_screen.dart';

void main() {
  runApp(const AlagAlertApp());
}

class AlagAlertApp extends StatelessWidget {
  const AlagAlertApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AlagAlert',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF6563A4),
        scaffoldBackgroundColor: const Color(0xFFF7F5FA),
      ),
      routes: {
        '/': (_) => const HomeScreen(),
        '/map': (ctx) {
          final args =
              ModalRoute.of(ctx)!.settings.arguments as Map<String, String>;
          return MapScreen(uf: args['uf']!);
        },
      },
    );
  }
}
