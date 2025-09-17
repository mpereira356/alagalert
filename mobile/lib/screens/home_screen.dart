// mobile/lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../widgets/risk_indicator.dart';
import '../widgets/metric_chip.dart';
import '../widgets/weather_card.dart';
import '../screens/city_picker_screen.dart';
import '../services/api_service.dart';
import '../models/risk.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _uf = "SP";
  String _city = "Campinas";
  RiskResult? _risk;
  bool _loading = false;

  Future<void> _pickCity() async {
    final res = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CityPickerScreen()),
    );
    if (res != null && mounted) {
      // res é CityPickerResult(uf, city)
      setState(() {
        _uf = res.uf;
        _city = res.city;
        _risk = null; // limpa para novo cálculo
      });
    }
  }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    try {
      final r = await ApiService.getRiskByCity(_uf, _city);
      if (mounted) setState(() => _risk = r);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erro: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _fetch(); // calcula risco inicial
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text("AlagAlert"),
        actions: [
          IconButton(onPressed: _pickCity, icon: const Icon(Icons.location_on_outlined)),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _fetch,
        child: const Icon(Icons.refresh),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // CARD: Seleção de UF e Cidade (ambos via CityPicker)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Escolha o Estado", style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: _pickCity,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(_uf, style: const TextStyle(fontWeight: FontWeight.w600)),
                            const Icon(Icons.expand_more),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text("Cidade", style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: _pickCity,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(_city, style: const TextStyle(fontWeight: FontWeight.w600)),
                            const Icon(Icons.search),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _loading ? null : _fetch,
                        child: const Text("Ver risco"),
                      ),
                    ),
                  ]),
            ),
          ).animate().moveY(begin: 20, duration: 300.ms).fadeIn(duration: 300.ms),

          const SizedBox(height: 16),

          if (_risk == null && _loading) const LinearProgressIndicator(),

          if (_risk != null) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text("Risco de Alagamento", style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  RiskIndicator(score: _risk!.riskScore, level: _risk!.level),
                  const SizedBox(height: 12),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    MetricChip(
                        label: "Chuva ${_risk!.factors.precipitation6h.toStringAsFixed(1)} mm",
                        icon: Icons.water_drop),
                    MetricChip(
                        label: "Vento ${_risk!.factors.windAvg6h.toStringAsFixed(0)} km/h",
                        icon: Icons.air),
                    MetricChip(
                        label: "Temp ${_risk!.factors.tempAvg6h.toStringAsFixed(0)}°C",
                        icon: Icons.thermostat),
                  ])
                ]),
              ),
            ).animate().moveY(begin: 20, duration: 300.ms).fadeIn(duration: 300.ms),

            const SizedBox(height: 16),
            WeatherCard(points: _risk!.window),
          ],

          const SizedBox(height: 16),
          FilledButton.tonal(
            onPressed: () => Navigator.pushNamed(context, '/map', arguments: _uf),
            child: const Text("Abrir Mapa por UF"),
          ),
        ],
      ),
    );
  }
}
