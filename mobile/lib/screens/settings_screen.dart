import 'package:flutter/material.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  ThemeMode _mode = ThemeMode.system;
  bool _kmh = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Configurações")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<ThemeMode>(
            value: _mode,
            decoration: const InputDecoration(labelText: "Tema"),
            items: const [
              DropdownMenuItem(value: ThemeMode.system, child: Text("Sistema")),
              DropdownMenuItem(value: ThemeMode.light, child: Text("Claro")),
              DropdownMenuItem(value: ThemeMode.dark, child: Text("Escuro")),
            ],
            onChanged: (v){ setState(() => _mode = v!); },
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            value: _kmh,
            onChanged: (v) => setState(() => _kmh = v),
            title: const Text("Vento em km/h"),
            subtitle: const Text("Desligado = m/s"),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Cache limpo!"))),
            icon: const Icon(Icons.cleaning_services),
            label: const Text("Limpar cache local"),
          )
        ],
      ),
    );
  }
}
