import 'package:flutter/material.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../widgets/risk_indicator.dart';
import '../widgets/metric_chip.dart';
import '../widgets/weather_card.dart';
import '../models/weather.dart';
import '../services/geocode_service.dart';
// import 'risk_result_screen.dart'; // Não é mais necessário

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Dados do resultado
  bool _loading = false;
  String? _error;
  Map<String, dynamic>? _data;
  // Guarda referência aos controllers gerados pelo TypeAhead (para alterar texto no onSelected)
  TextEditingController? _ufFieldCtrl;
  TextEditingController? _cityFieldCtrl;

  // Normaliza UF (ex.: "BR:SP" -> "SP")
  String _cleanUf(dynamic v) {
    final s = (v ?? '').toString();
    final m = RegExp(r'([A-Za-z]{2})$').firstMatch(s);
    return (m?.group(1) ?? s).toUpperCase();
  }

  // Seleções
  String? _selectedUf;        // ex.: "SP"
  String? _selectedStateName; // ex.: "São Paulo"
  String? _selectedCity;      // ex.: "Santos"

  // bool _loadingRisk = false; // Variável renomeada para _loading

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
    if (_loading) return;

    setState(() {
      _loading = true;
      _error = null;
      _data = null;
    });

    try {
      final uri = Uri.parse('${GeocodeService.baseUrl}/risk/by-city').replace(
        queryParameters: {
          'uf': uf,
          'city': city,
        },
      );

      final res = await http.get(uri);
      if (res.statusCode != 200) {
        throw Exception('HTTP ${res.statusCode}: ${res.body}');
      }

      final Map<String, dynamic> body =
          jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;

      if (!mounted) return;
      setState(() {
        _data = body;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Falha ao obter risco: $e';
        _loading = false;
      });
    }
  }

  // Lógica de _cleanUf, _showSnack, _buildUfTypeAhead, _buildCityTypeAhead...
  // ... (o restante do código da classe será mantido)

  // Removendo a navegação para RiskResultScreen
  // Future<void> _verRisco() async {
  //   final uf = _cleanUf(_selectedUf);
  //   final city = _selectedCity?.trim();
  //
  //   if (uf.isEmpty) {
  //     _showSnack('Escolha um estado primeiro.');
  //     return;
  //   }
  //   if (city == null || city.isEmpty) {
  //     _showSnack('Digite e selecione uma cidade.');
  //     return;
  //   }
  //   if (_loadingRisk) return;
  //
  //   if (!mounted) return;
  //   Navigator.of(context).push(
  //     MaterialPageRoute(builder: (_) => RiskResultScreen(uf: uf, city: city)),
  //   );
  // }
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

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ------- Busca de ESTADOS (via /geocode-states) -------
  Widget _buildUfTypeAhead() {
    return TypeAheadField<Map<String, dynamic>>(
      hideOnEmpty: true,
      hideOnLoading: false,
      suggestionsCallback: (pattern) async {
        return await GeocodeService.searchStates(pattern);
      },
      builder: (context, controller, focusNode) {
        // Guarda a referência para poder atualizar o texto no onSelected
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
        final uf = _cleanUf(suggestion['uf']);
        final stateName = suggestion['state']?.toString() ?? '';
        setState(() {
          _selectedUf = uf;
          _selectedStateName = stateName;
          _selectedCity = null;            // limpamos a cidade ao trocar de UF
          _cityFieldCtrl?.clear();
        });
        // Atualiza o texto visível do campo de estado
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

  // ------- Busca de CIDADES (via /geocode) -------
  Widget _buildCityTypeAhead() {
    return TypeAheadField<Map<String, dynamic>>(
      hideOnEmpty: true,
      hideOnLoading: false,
      suggestionsCallback: (pattern) async {
        if ((_selectedUf ?? '').isEmpty) return [];
        return await GeocodeService.searchCities(
          cityQuery: pattern,
          uf: _cleanUf(_selectedUf), // limpa aqui também
        );
      },
      builder: (context, controller, focusNode) {
        _cityFieldCtrl = controller; // guarda a referência
        return TextField(
          controller: controller,
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
        });
        // Atualiza o texto visível do campo de cidade
        _cityFieldCtrl?.text = city;
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
  Widget _buildRiskResult() {
    final level = (_data!['risk_level'] ?? 'Desconhecido').toString();
    final score = ((_data!['score'] as num?) ?? 0).toDouble() / 100.0; // Assume score is 0-100
    final details = (_data!['details'] ?? {}) as Map<String, dynamic>;
    final hourly = (_data!['hourly_forecast'] ?? []) as List;

    // Dados para os chips
    final rain = details['current_rain_mm'] ?? details['rain_1h_mm'] ?? 0.0;
    final wind = details['current_wind_speed_kmh'] ?? details['wind_speed_10m'] ?? 0.0;
    final temp = details['current_temperature_c'] ?? details['temperature_2m'] ?? 0.0;
    
    // Lista de WeatherPoint para o WeatherCard
    final hourlyPoints = hourly
        .map((e) => WeatherPoint.fromJson(e as Map<String, dynamic>))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Título e indicador de risco
        Text('Risco de Alagamento', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        RiskIndicator(score: score, level: level),
        const SizedBox(height: 24),

        // Chips de clima atual
        Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            MetricChip(
              label: 'Chuva ${rain.toStringAsFixed(1)} mm',
              icon: Icons.water_drop,
            ),
            const SizedBox(width: 8),
            MetricChip(
              label: 'Vento ${wind.toStringAsFixed(0)} km/h',
              icon: Icons.air,
            ),
            const SizedBox(width: 8),
            MetricChip(
              label: 'Temp ${temp.toStringAsFixed(0)}°C',
              icon: Icons.thermostat,
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Previsão horária
        WeatherCard(points: hourlyPoints),
        
        // Botão "Abrir Mapa por UF" (opcional, mas presente na imagem)
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton(
            onPressed: () {
              // TODO: Implementar navegação para o mapa
              _showSnack('Navegação para o mapa ainda não implementada.');
            },
            child: const Text('Abrir Mapa por UF'),
          ),
        ),
      ],
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
              onPressed: _loading ? null : _verRisco,
              child: _loading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Ver risco'),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 24),
            Text(_error!, style: const TextStyle(color: Colors.red)),
          ],
          if (_data != null) ...[
            const SizedBox(height: 24),
            _buildRiskResult(),
          ],
        ],
      ),
    );
  }
}
