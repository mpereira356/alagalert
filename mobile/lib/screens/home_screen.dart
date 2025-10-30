import 'package:flutter/material.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import '../services/geocode_service.dart';
import 'package:http/http.dart' as http;


class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Estado selecionado (sigla e nome)
  String? _selectedUf;        // ex.: "SP"
  String? _selectedStateName; // ex.: "São Paulo"

  // Cidade selecionada
  String? _selectedCity;

  // Controllers pros inputs
  final _ufController = TextEditingController();
  final _cityController = TextEditingController();

  // Para evitar spams de request
  bool _loadingRisk = false;

  @override
  void dispose() {
    _ufController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  Future<void> _verRisco() async {
    final uf = _selectedUf?.trim();
    final city = _selectedCity?.trim();
    if (uf == null || uf.isEmpty) {
      _showSnack('Escolha um estado primeiro.');
      return;
    }
    if (city == null || city.isEmpty) {
      _showSnack('Digite e selecione uma cidade.');
      return;
    }
    if (_loadingRisk) return;

    setState(() => _loadingRisk = true);
    try {
      final uri = Uri.parse('${GeocodeService.baseUrl}/risk/by-city')
          .replace(queryParameters: {'uf': uf, 'city': city});
      final res = await http.get(uri);
      if (res.statusCode == 200) {
        _showSnack('Risco obtido com sucesso!');
        // -> Aqui você pode navegar pra uma tela de resultado
        // ou exibir o JSON/resumo
      } else {
        _showSnack('Erro ${res.statusCode}: ${res.body}');
      }
    } catch (e) {
      _showSnack('Falha ao obter risco: $e');
    } finally {
      if (mounted) setState(() => _loadingRisk = false);
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Widget _buildUfTypeAhead() {
    return TypeAheadField<Map<String, dynamic>>(
      hideOnEmpty: true,
      hideOnLoading: false,
      suggestionsCallback: (pattern) async {
        // Busca ESTADOS como no site do Nominatim
        return await GeocodeService.searchStates(pattern);
      },
      builder: (context, controller, focusNode) {
        // Vincula controller para mostrar texto selecionado
        _ufController.value = controller.value;
        return TextField(
          controller: _ufController,
          focusNode: focusNode,
          decoration: const InputDecoration(
            labelText: 'Estado (digite para buscar)',
            hintText: 'Ex.: sp, rio, par...',
            border: OutlineInputBorder(),
          ),
        );
      },
      itemBuilder: (context, suggestion) {
        final state = suggestion['state'] ?? '';
        final uf = (suggestion['uf'] ?? '').toString().toUpperCase();
        final display = suggestion['display_name'] ?? state;
        return ListTile(
          title: Text('$state${uf.isNotEmpty ? ' ($uf)' : ''}'),
          subtitle: Text(display, maxLines: 1, overflow: TextOverflow.ellipsis),
        );
      },
      onSelected: (suggestion) {
        final uf = (suggestion['uf'] ?? '').toString().toUpperCase();
        final stateName = suggestion['state']?.toString() ?? '';
        setState(() {
          _selectedUf = uf;                // salva a sigla
          _selectedStateName = stateName;  // salva o nome
          _ufController.text = uf.isNotEmpty ? '$stateName ($uf)' : stateName;
          // limpa a cidade quando trocar de estado
          _selectedCity = null;
          _cityController.clear();
        });
      },
      errorBuilder: (context, error) => Padding(
        padding: const EdgeInsets.all(12.0),
        child: Text('Erro ao buscar estados: $error'),
      ),
      emptyBuilder: (context) => const Padding(
        padding: EdgeInsets.all(12.0),
        child: Text('Nenhum estado encontrado.'),
      ),
    );
  }

  Widget _buildCityTypeAhead() {
    return TypeAheadField<Map<String, dynamic>>(
      hideOnEmpty: true,
      hideOnLoading: false,
      suggestionsCallback: (pattern) async {
        if ((_selectedUf ?? '').isEmpty) return [];
        return await GeocodeService.searchCities(
          cityQuery: pattern,
          uf: _selectedUf!,
        );
      },
      builder: (context, controller, focusNode) {
        _cityController.value = controller.value;
        return TextField(
          controller: _cityController,
          focusNode: focusNode,
          decoration: InputDecoration(
            labelText: 'Cidade (digite para buscar)',
            hintText: _selectedUf == null
                ? 'Escolha o estado primeiro'
                : 'Ex.: campinas, santos...',
            border: const OutlineInputBorder(),
          ),
          enabled: _selectedUf != null && _selectedUf!.isNotEmpty,
        );
      },
      itemBuilder: (context, suggestion) {
        final city = suggestion['city'] ?? '';
        final uf = (suggestion['uf'] ?? '').toString().toUpperCase();
        final display = suggestion['display_name'] ?? '';
        return ListTile(
          title: Text('$city${uf.isNotEmpty ? ' - $uf' : ''}'),
          subtitle: Text(display, maxLines: 1, overflow: TextOverflow.ellipsis),
        );
      },
      onSelected: (suggestion) {
        final city = suggestion['city']?.toString() ?? '';
        setState(() {
          _selectedCity = city;
          _cityController.text = city;
        });
      },
      errorBuilder: (context, error) => Padding(
        padding: const EdgeInsets.all(12.0),
        child: Text('Erro ao buscar cidades: $error'),
      ),
      emptyBuilder: (context) => const Padding(
        padding: EdgeInsets.all(12.0),
        child: Text('Nenhuma cidade encontrada.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('AlagAlert')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Estado — TypeAhead como Nominatim
          _buildUfTypeAhead(),
          const SizedBox(height: 16),
          // Cidade — TypeAhead filtrando pelo UF escolhido
          _buildCityTypeAhead(),
          const SizedBox(height: 24),
          // Botão "Ver risco"
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
        ],
      ),
    );
  }
}
