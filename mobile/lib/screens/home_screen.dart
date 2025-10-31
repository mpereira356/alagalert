import 'package:flutter/material.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import '../services/geocode_service.dart';
import 'risk_result_screen.dart';
import 'map_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  TextEditingController? _ufFieldCtrl;
  TextEditingController? _cityFieldCtrl;

  // Normaliza: "BR:SP" -> "SP"
  String _cleanUf(dynamic v) {
    final s = (v ?? '').toString();
    final m = RegExp(r'([A-Za-z]{2})$').firstMatch(s);
    return (m?.group(1) ?? s).toUpperCase();
  }

  String? _selectedUf;        // ex.: "SP"
  String? _selectedStateName; // ex.: "São Paulo"
  String? _selectedCity;      // ex.: "Santos"

  bool _loadingRisk = false;

  Future<void> _verRisco() async {
    final uf = _cleanUf(_selectedUf);
    final city = _selectedCity?.trim();

    if (uf.isEmpty) {
      _showSnack('Escolha um estado primeiro.');
      return;
    }
    if (city == null || city.isEmpty) {
      _showSnack('Digite e selecione uma cidade.');
      return;
    }
    if (_loadingRisk) return;

    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => RiskResultScreen(uf: uf, city: city)),
    );
  }

  void _abrirMapa() {
    final uf = _cleanUf(_selectedUf);
    if (uf.isEmpty) {
      _showSnack('Escolha um estado para abrir o mapa.');
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => MapScreen(uf: uf)),
    );
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ---------- ESTADO ----------
  Widget _buildUfTypeAhead() {
    return TypeAheadField<Map<String, dynamic>>(
      hideOnEmpty: true,
      hideOnLoading: false,
      suggestionsCallback: (pattern) async {
        return GeocodeService.searchStates(pattern);
      },
      builder: (context, controller, focusNode) {
        _ufFieldCtrl = controller;
        return TextField(
          controller: controller,
          focusNode: focusNode,
          decoration: const InputDecoration(
            labelText: 'Estado (digite para buscar)',
            hintText: 'Ex.: sp, rio, par...',
            border: OutlineInputBorder(),
          ),
        );
      },
      itemBuilder: (context, s) {
        final state = s['state'] ?? '';
        final uf = (s['uf'] ?? '').toString().toUpperCase();
        final display = s['display_name'] ?? state;
        return ListTile(
          title: Text('$state${uf.isNotEmpty ? ' ($uf)' : ''}'),
          subtitle: Text(display, maxLines: 1, overflow: TextOverflow.ellipsis),
        );
      },
      onSelected: (s) {
        final uf = _cleanUf(s['uf']);
        final stateName = s['state']?.toString() ?? '';
        setState(() {
          _selectedUf = uf;
          _selectedStateName = stateName;
          _selectedCity = null;
        });
        _cityFieldCtrl?.clear();
        _ufFieldCtrl?.text = stateName.isNotEmpty ? '$stateName ($uf)' : uf;
      },
      errorBuilder: (context, error) => const Padding(
        padding: EdgeInsets.all(12.0),
        child: Text('Erro ao buscar estados.'),
      ),
      emptyBuilder: (context) => const Padding(
        padding: EdgeInsets.all(12.0),
        child: Text('Nenhum estado encontrado.'),
      ),
    );
  }

  // ---------- CIDADE (filtrada rigidamente pela UF) ----------
  Widget _buildCityTypeAhead() {
    return TypeAheadField<Map<String, dynamic>>(
      hideOnEmpty: true,
      hideOnLoading: false,
      suggestionsCallback: (pattern) async {
        final uf = _cleanUf(_selectedUf);
        if (uf.isEmpty) return [];
        // >>> correção aqui: cityQuery <<<
        return GeocodeService.searchCities(cityQuery: pattern, uf: uf);
      },
      builder: (context, controller, focusNode) {
        _cityFieldCtrl = controller;
        return TextField(
          controller: controller,
          focusNode: focusNode,
          decoration: InputDecoration(
            labelText: 'Cidade (digite para buscar)',
            hintText: (_selectedUf == null || _selectedUf!.isEmpty)
                ? 'Escolha o estado primeiro'
                : 'Ex.: santos, campinas...',
            border: const OutlineInputBorder(),
          ),
          enabled: _selectedUf != null && _selectedUf!.isNotEmpty,
        );
      },
      itemBuilder: (context, s) {
        final city = (s['city'] ?? s['name'] ?? '').toString();
        final uf = (s['uf'] ?? '').toString().toUpperCase();
        final display = s['display_name'] ?? '';
        return ListTile(
          title: Text('$city${uf.isNotEmpty ? ' - $uf' : ''}'),
          subtitle: Text(display, maxLines: 1, overflow: TextOverflow.ellipsis),
        );
      },
      onSelected: (s) {
        final city = (s['city'] ?? s['name'] ?? '').toString();
        setState(() => _selectedCity = city);
        _cityFieldCtrl?.text = city; // exibe a cidade no campo
      },
      errorBuilder: (context, error) => const Padding(
        padding: EdgeInsets.all(12.0),
        child: Text('Erro ao buscar cidades.'),
      ),
      emptyBuilder: (context) => const Padding(
        padding: EdgeInsets.all(12.0),
        child: Text('Nenhuma cidade encontrada.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AlagAlert')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildUfTypeAhead(),
          const SizedBox(height: 16),
          _buildCityTypeAhead(),
          const SizedBox(height: 24),
          SizedBox(
            height: 48,
            child: FilledButton(
              onPressed: _loadingRisk ? null : _verRisco,
              child: _loadingRisk
                  ? const SizedBox(
                      width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Ver risco'),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _abrirMapa,
            icon: const Icon(Icons.map_outlined),
            label: const Text('Abrir mapa por UF'),
          ),
        ],
      ),
    );
  }
}
