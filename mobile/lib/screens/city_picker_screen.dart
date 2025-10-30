// lib/screens/city_picker_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import '../services/geocode_service.dart';

class CityPickerScreen extends StatefulWidget {
  final String? initialUf;    // sigla (ex.: SP)
  final String? initialCity;  // nome (ex.: Campinas)

  const CityPickerScreen({super.key, this.initialUf, this.initialCity});

  @override
  State<CityPickerScreen> createState() => _CityPickerScreenState();
}

class _CityPickerScreenState extends State<CityPickerScreen> {
  final _ufCtl = TextEditingController();
  final _cityCtl = TextEditingController();

  String? _selectedUf;
  String? _selectedCity;

  @override
  void initState() {
    super.initState();
    if (widget.initialUf != null && widget.initialUf!.isNotEmpty) {
      _selectedUf = widget.initialUf!.toUpperCase();
      _ufCtl.text = _selectedUf!;
    }
    if (widget.initialCity != null && widget.initialCity!.isNotEmpty) {
      _selectedCity = widget.initialCity!;
      _cityCtl.text = _selectedCity!;
    }
  }

  void _confirm() {
    if (_selectedUf == null || _selectedUf!.isEmpty ||
        _selectedCity == null || _selectedCity!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione UF e cidade')),
      );
      return;
    }
    Navigator.pop(context, {
      'uf': _selectedUf,
      'city': _selectedCity,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Escolher cidade")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Estado (digite a sigla ou nome)'),
          const SizedBox(height: 8),
          TypeAheadField<Map<String, String>>(
            suggestionsCallback: (pattern) async {
              return GeocodeService.suggestStates(pattern);
            },
            builder: (context, controller, focusNode) {
              controller.text = _ufCtl.text;
              return TextField(
                controller: controller,
                focusNode: focusNode,
                decoration: const InputDecoration(
                  hintText: 'Ex.: SP, RJ, São Paulo…',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.search),
                ),
              );
            },
            itemBuilder: (context, item) {
              final uf = item['uf'] ?? '';
              final st = item['state'] ?? '';
              return ListTile(
                leading: const Icon(Icons.flag_outlined),
                title: Text('$uf — $st'),
                subtitle: Text(item['displayName'] ?? ''),
              );
            },
            onSelected: (item) {
              _selectedUf = (item['uf'] ?? '').toUpperCase();
              _ufCtl.text = _selectedUf!;
              // Limpa cidade ao trocar UF
              _selectedCity = null;
              _cityCtl.clear();
              setState(() {});
            },
            emptyBuilder: (context) =>
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text('Nenhum estado encontrado'),
                ),
          ),

          const SizedBox(height: 16),
          const Text('Cidade (digite para buscar)'),
          const SizedBox(height: 8),
          TypeAheadField<Map<String, String>>(
            suggestionsCallback: (pattern) async {
              if (_selectedUf == null || _selectedUf!.isEmpty) return [];
              if (pattern.trim().isEmpty) return [];
              return GeocodeService.suggestCities(
                query: pattern,
                uf: _selectedUf!,
              );
            },
            builder: (context, controller, focusNode) {
              controller.text = _cityCtl.text;
              return TextField(
                controller: controller,
                focusNode: focusNode,
                enabled: _selectedUf != null && _selectedUf!.isNotEmpty,
                decoration: InputDecoration(
                  hintText: _selectedUf == null
                      ? 'Escolha primeiro o Estado'
                      : 'Ex.: Campinas',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.location_city),
                ),
              );
            },
            itemBuilder: (context, item) {
              return ListTile(
                leading: const Icon(Icons.location_on_outlined),
                title: Text(item['city'] ?? ''),
                subtitle: Text(item['displayName'] ?? ''),
              );
            },
            onSelected: (item) {
              _selectedCity = item['city'];
              _cityCtl.text = _selectedCity ?? '';
              setState(() {});
            },
            emptyBuilder: (context) =>
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text('Nenhuma cidade encontrada'),
                ),
          ),

          const SizedBox(height: 24),
          FilledButton(
            onPressed: _confirm,
            child: const Text('Usar esta cidade'),
          ),
        ],
      ),
    );
  }
}
