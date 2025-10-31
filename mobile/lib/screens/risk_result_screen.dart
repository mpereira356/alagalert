import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../services/geocode_service.dart';

class RiskResultScreen extends StatefulWidget {
  const RiskResultScreen({super.key, required this.uf, required this.city});
  final String uf;
  final String city;

  @override
  State<RiskResultScreen> createState() => _RiskResultScreenState();
}

class _RiskResultScreenState extends State<RiskResultScreen> {
  bool _loading = true;
  String? _error;
  late _RiskData _risk;

  @override
  void initState() {
    super.initState();
    _fetchRisk();
  }

  String _cleanUf(dynamic v) {
    final s = (v ?? '').toString();
    final m = RegExp(r'([A-Za-z]{2})$').firstMatch(s);
    return (m?.group(1) ?? s).toUpperCase();
  }

  // ================= FETCH & COMPUTE =================

  Future<void> _fetchRisk() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final cleanUf = _cleanUf(widget.uf).trim();
      final cleanCity = widget.city.trim();

      final uri = Uri.parse('${GeocodeService.baseUrl}/risk/by-city')
          .replace(queryParameters: {'uf': cleanUf, 'city': cleanCity});

      final res = await http.get(uri);
      if (res.statusCode != 200) {
        throw Exception('HTTP ${res.statusCode}: ${res.body}');
      }

      final raw = utf8.decode(res.bodyBytes);
      final parsed = jsonDecode(raw);
      if (parsed is! Map<String, dynamic>) {
        throw Exception('Formato inesperado de JSON.');
      }
      final out = Map<String, dynamic>.from(parsed);

      final loc = (out['location'] is Map)
          ? (out['location'] as Map).cast<String, dynamic>()
          : <String, dynamic>{};
      final lat = (loc['lat'] is num)
          ? (loc['lat'] as num).toDouble()
          : double.tryParse('${loc['lat'] ?? ''}');
      final lon = (loc['lon'] is num)
          ? (loc['lon'] as num).toDouble()
          : double.tryParse('${loc['lon'] ?? ''}');

      final details = (out['details'] is Map)
          ? (out['details'] as Map).cast<String, dynamic>()
          : <String, dynamic>{};

      final fw = (out['forecast_window'] is List)
          ? out['forecast_window'] as List
          : const [];

      _RiskData computed;
      if (_hasAggregates(details)) {
        computed = _fromAggregates(
          city: loc['city']?.toString() ?? widget.city,
          uf: _cleanUf(loc['uf'] ?? widget.uf),
          lat: lat,
          lon: lon,
          details: details,
          fallbackForecast: fw,
        );
      } else if (fw.isNotEmpty) {
        computed = _fromForecastWindow(
          city: loc['city']?.toString() ?? widget.city,
          uf: _cleanUf(loc['uf'] ?? widget.uf),
          lat: lat,
          lon: lon,
          fw: fw,
        );
      } else if (lat != null && lon != null) {
        computed = await _fromOpenMeteo(
          city: loc['city']?.toString() ?? widget.city,
          uf: _cleanUf(loc['uf'] ?? widget.uf),
          lat: lat,
          lon: lon,
        );
      } else {
        computed = _RiskData.empty(
          city: loc['city']?.toString() ?? widget.city,
          uf: _cleanUf(loc['uf'] ?? widget.uf),
          lat: lat,
          lon: lon,
        );
      }

      final backendLevel = (out['risk_level'] ?? '').toString().trim();
      if (backendLevel.isNotEmpty) {
        computed = computed.copyWith(level: backendLevel);
      }

      setState(() {
        _risk = computed;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Falha ao obter risco: $e';
        _loading = false;
      });
    }
  }

  bool _hasAggregates(Map<String, dynamic> d) =>
      d.containsKey('rain_24h_mm') ||
      d.containsKey('rain_48h_mm') ||
      d.containsKey('max_intensity_mm_h') ||
      d.containsKey('hours_rain_gt_2mm');

  _RiskData _fromAggregates({
    required String city,
    required String uf,
    required double? lat,
    required double? lon,
    required Map<String, dynamic> details,
    required List<dynamic> fallbackForecast,
  }) {
    final r24 = _toDouble(details['rain_24h_mm'] ?? details['rain_24h']);
    final r48 = _toDouble(details['rain_48h_mm'] ?? details['rain_48h']);
    final maxInt = _toDouble(details['max_intensity_mm_h'] ?? details['max_intensity']);
    final hours2 = _toInt(details['hours_rain_gt_2mm'] ?? details['hours_2mm']);
    final temp = _toDouble(details['temp_avg_6h_c'] ?? details['temp'] ?? 0);
    final wind = _toDouble(details['wind_avg_6h_kmh'] ?? details['wind'] ?? 0);

    final level = _computeRiskLevel(
      rain24: r24,
      rain48: r48,
      maxIntensity: maxInt,
      hoursAbove2: hours2,
    );
    final score = _riskScore(level, r48, maxInt);

    final hours = _toHourly(fallbackForecast);

    return _RiskData(
      city: city,
      uf: uf,
      lat: lat,
      lon: lon,
      level: level,
      scorePct: score,
      rain24: r24,
      rain48: r48,
      windKmh: wind,
      tempC: temp,
      maxIntensity: maxInt,
      hoursAbove2mm: hours2,
      hourly: hours,
    );
  }

  _RiskData _fromForecastWindow({
    required String city,
    required String uf,
    required double? lat,
    required double? lon,
    required List<dynamic> fw,
  }) {
    final precip = fw
        .map((e) => (e is Map && e['precipitation'] != null)
            ? ((e['precipitation'] as num?)?.toDouble() ?? 0.0)
            : 0.0)
        .toList();

    final wind = fw
        .map((e) => (e is Map && e['wind_speed'] != null)
            ? ((e['wind_speed'] as num?)?.toDouble() ?? 0.0)
            : 0.0)
        .toList();

    final temp = fw
        .map((e) => (e is Map && e['temperature'] != null)
            ? ((e['temperature'] as num?)?.toDouble() ?? 0.0)
            : 0.0)
        .toList();

    List<double> take(int n, List<double> xs) => xs.length >= n ? xs.sublist(0, n) : xs;
    double sum(List<double> xs) => xs.fold<double>(0, (a, b) => a + b);
    double maxOf(List<double> xs) => xs.isEmpty ? 0 : xs.reduce((a, b) => a > b ? a : b);

    final r24 = sum(take(24, precip));
    final r48 = sum(take(48, precip));
    final maxInt = maxOf(take(48, precip));
    final hours2 = take(48, precip).where((v) => v > 2.0).length;
    final windAvg = (take(6, wind).isEmpty ? 0 : (sum(take(6, wind)) / take(6, wind).length)).toDouble();
    final tempAvg = (take(6, temp).isEmpty ? 0 : (sum(take(6, temp)) / take(6, temp).length)).toDouble();

    final level = _computeRiskLevel(
      rain24: r24,
      rain48: r48,
      maxIntensity: maxInt,
      hoursAbove2: hours2,
    );
    final score = _riskScore(level, r48, maxInt);

    final hours = _toHourly(fw);

    return _RiskData(
      city: city,
      uf: uf,
      lat: lat,
      lon: lon,
      level: level,
      scorePct: score,
      rain24: r24,
      rain48: r48,
      windKmh: windAvg,
      tempC: tempAvg,
      maxIntensity: maxInt,
      hoursAbove2mm: hours2,
      hourly: hours,
    );
  }

  Future<_RiskData> _fromOpenMeteo({
    required String city,
    required String uf,
    required double lat,
    required double lon,
  }) async {
    final uri = Uri.parse(
      'https://api.open-meteo.com/v1/forecast'
      '?latitude=$lat&longitude=$lon'
      '&hourly=precipitation,temperature_2m,wind_speed_10m'
      '&timezone=auto'
      '&forecast_days=2',
    );

    final res = await http.get(uri);
    if (res.statusCode != 200) {
      return _RiskData.empty(city: city, uf: uf, lat: lat, lon: lon);
    }
    final body = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    final hourly = (body['hourly'] ?? {}) as Map<String, dynamic>;
    final List<dynamic> p = (hourly['precipitation'] ?? []) as List<dynamic>;
    final List<dynamic> t = (hourly['temperature_2m'] ?? []) as List<dynamic>;
    final List<dynamic> w = (hourly['wind_speed_10m'] ?? []) as List<dynamic>;
    final List<dynamic> ts = (hourly['time'] ?? []) as List<dynamic>;

    final precip = p.map((e) => (e as num?)?.toDouble() ?? 0.0).toList();
    final temp = t.map((e) => (e as num?)?.toDouble() ?? 0.0).toList();
    final wind = w.map((e) => (e as num?)?.toDouble() ?? 0.0).toList();

    List<double> take(int n, List<double> xs) => xs.length >= n ? xs.sublist(0, n) : xs;
    double sum(List<double> xs) => xs.fold<double>(0, (a, b) => a + b);
    double maxOf(List<double> xs) => xs.isEmpty ? 0 : xs.reduce((a, b) => a > b ? a : b);

    final r24 = sum(take(24, precip));
    final r48 = sum(take(48, precip));
    final maxInt = maxOf(take(48, precip));
    final hours2 = take(48, precip).where((v) => v > 2.0).length;
    final windAvg = (take(6, wind).isEmpty ? 0 : (sum(take(6, wind)) / take(6, wind).length)).toDouble();
    final tempAvg = (take(6, temp).isEmpty ? 0 : (sum(take(6, temp)) / take(6, temp).length)).toDouble();

    final hourlyRows = <_HourRow>[];
    for (var i = 0; i < ts.length && i < 6; i++) {
      final dt = DateTime.tryParse(ts[i].toString());
      hourlyRows.add(_HourRow(
        time: dt,
        precipMm: precip.length > i ? precip[i] : 0,
        windKmh: wind.length > i ? wind[i] : 0,
        tempC: temp.length > i ? temp[i] : 0,
      ));
    }

    final level = _computeRiskLevel(
      rain24: r24,
      rain48: r48,
      maxIntensity: maxInt,
      hoursAbove2: hours2,
    );
    final score = _riskScore(level, r48, maxInt);

    return _RiskData(
      city: city,
      uf: uf,
      lat: lat,
      lon: lon,
      level: level,
      scorePct: score,
      rain24: r24,
      rain48: r48,
      windKmh: windAvg,
      tempC: tempAvg,
      maxIntensity: maxInt,
      hoursAbove2mm: hours2,
      hourly: hourlyRows,
    );
  }

  // ================ RULES =================

  /// Regra simples para classificar risco. Ajuste como quiser.
  String _computeRiskLevel({
    required double rain24,
    required double rain48,
    required double maxIntensity,
    required int hoursAbove2,
  }) {
    // Alto se chover muito ou intensidade forte por muitas horas.
    if (rain48 >= 40 || maxIntensity >= 10 || hoursAbove2 >= 8) {
      return 'Alto';
    }
    // Moderado se houver chuva relevante ou intensidade moderada.
    if (rain48 >= 15 || maxIntensity >= 5 || hoursAbove2 >= 3) {
      return 'Moderado';
    }
    return 'Baixo';
  }

  double _riskScore(String level, double rain48, double maxInt) {
    switch (level.toLowerCase()) {
      case 'alto':
      case 'high':
        return 85;
      case 'moderado':
      case 'medium':
        return 45;
      default:
        return (rain48 + maxInt).clamp(0, 25) * 2;
    }
  }

  double _toDouble(dynamic v) => (v is num) ? v.toDouble() : double.tryParse('$v') ?? 0;
  int _toInt(dynamic v) => (v is num) ? v.toInt() : int.tryParse('$v') ?? 0;

  List<_HourRow> _toHourly(List<dynamic> fw) {
    final rows = <_HourRow>[];
    for (var i = 0; i < fw.length && i < 6; i++) {
      final m = (fw[i] is Map) ? (fw[i] as Map).cast<String, dynamic>() : {};
      rows.add(_HourRow(
        time: DateTime.tryParse('${m['timestamp'] ?? ''}'),
        precipMm: _toDouble(m['precipitation']),
        windKmh: _toDouble(m['wind_speed']),
        tempC: _toDouble(m['temperature']),
      ));
    }
    return rows;
    }

  // ================= UI =================

  @override
  Widget build(BuildContext context) {
    final title = 'Risco • ${widget.city} - ${_cleanUf(widget.uf)}';
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchRisk)],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _fetchRisk,
        child: const Icon(Icons.refresh),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Padding(padding: const EdgeInsets.all(16), child: Text(_error!)))
                : _dashboard(),
      ),
    );
  }

  Widget _dashboard() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _RiskCard(data: _risk),
        const SizedBox(height: 16),
        _HoursCard(rows: _risk.hourly),
        const SizedBox(height: 16),
        SizedBox(
          height: 48,
          child: FilledButton.tonal(
            onPressed: () {
              // TODO: navegar para o mapa (ajuste conforme sua MapScreen)
              Navigator.of(context).pop();
            },
            child: const Text('Abrir Mapa por UF'),
          ),
        ),
      ],
    );
  }
}

// ================ WIDGETS ================

class _RiskCard extends StatelessWidget {
  const _RiskCard({required this.data});
  final _RiskData data;

  Color get _levelColor {
    switch (data.level.toLowerCase()) {
      case 'alto':
      case 'high':
        return Colors.red;
      case 'moderado':
      case 'medium':
        return Colors.orange;
      default:
        return Colors.green;
    }
  }

  String get _levelLabel {
    switch (data.level.toLowerCase()) {
      case 'alto':
      case 'high':
        return 'Alto';
      case 'moderado':
      case 'medium':
        return 'Moderado';
      default:
        return 'Baixo';
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _levelColor;
    final pct = (data.scorePct.clamp(0, 100)) / 100.0;

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Risco de Alagamento', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            LayoutBuilder(builder: (context, c) {
              return Stack(
                children: [
                  Container(
                    height: 12,
                    width: c.maxWidth,
                    decoration: BoxDecoration(
                      color: Colors.black12, borderRadius: BorderRadius.circular(12)),
                  ),
                  Container(
                    height: 12,
                    width: c.maxWidth * pct,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: const LinearGradient(
                        colors: [Colors.blue, Colors.green, Colors.orange, Colors.red],
                      ),
                    ),
                  ),
                ],
              );
            }),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(_levelLabel,
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(color: color, fontWeight: FontWeight.w700)),
                const Spacer(),
                Text('${data.scorePct.toStringAsFixed(0)}%',
                    style: Theme.of(context).textTheme.titleLarge),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _MetricChip(
                    icon: Icons.water_drop,
                    label: 'Chuva ${data.rain24.toStringAsFixed(1)} mm'),
                _MetricChip(
                    icon: Icons.air,
                    label: 'Vento ${data.windKmh.toStringAsFixed(0)} km/h'),
                _MetricChip(
                    icon: Icons.thermostat,
                    label: 'Temp ${data.tempC.toStringAsFixed(0)}ºC'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withOpacity(.08),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 18),
        const SizedBox(width: 6),
        Text(label),
      ]),
    );
  }
}

class _HoursCard extends StatelessWidget {
  const _HoursCard({required this.rows});
  final List<_HourRow> rows;

  String _fmtHour(DateTime? dt) {
    if (dt == null) return '—';
    final h = dt.hour;
    final mm = dt.minute.toString().padLeft(2, '0');
    final ampm = h >= 12 ? 'PM' : 'AM';
    final h12 = h % 12 == 0 ? 12 : h % 12;
    return '$h12:$mm $ampm';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Próximas horas', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            if (rows.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('Sem dados horários disponíveis.'),
              )
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: rows.map((r) {
                  return Expanded(
                    child: Column(
                      children: [
                        const Icon(Icons.cloud, size: 28),
                        const SizedBox(height: 8),
                        Text(_fmtHour(r.time)),
                        const SizedBox(height: 6),
                        Text('${r.precipMm.toStringAsFixed(1)} mm',
                            style: const TextStyle(fontSize: 12)),
                        Text('${r.windKmh.toStringAsFixed(0)} km/h',
                            style: const TextStyle(fontSize: 12)),
                        Text('${r.tempC.toStringAsFixed(0)}°',
                            style: const TextStyle(fontSize: 12)),
                      ],
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }
}

// ================ MODELS ================

class _RiskData {
  final String city;
  final String uf;
  final double? lat;
  final double? lon;

  final String level;
  final double scorePct;

  final double rain24;
  final double rain48;
  final double windKmh;
  final double tempC;
  final double maxIntensity;
  final int hoursAbove2mm;

  final List<_HourRow> hourly;

  const _RiskData({
    required this.city,
    required this.uf,
    required this.lat,
    required this.lon,
    required this.level,
    required this.scorePct,
    required this.rain24,
    required this.rain48,
    required this.windKmh,
    required this.tempC,
    required this.maxIntensity,
    required this.hoursAbove2mm,
    required this.hourly,
  });

  factory _RiskData.empty({
    required String city,
    required String uf,
    required double? lat,
    required double? lon,
  }) =>
      _RiskData(
        city: city,
        uf: uf,
        lat: lat,
        lon: lon,
        level: 'Baixo',
        scorePct: 3,
        rain24: 0,
        rain48: 0,
        windKmh: 5,
        tempC: 17,
        maxIntensity: 0,
        hoursAbove2mm: 0,
        hourly: const [],
      );

  _RiskData copyWith({String? level}) => _RiskData(
        city: city,
        uf: uf,
        lat: lat,
        lon: lon,
        level: level ?? this.level,
        scorePct: scorePct,
        rain24: rain24,
        rain48: rain48,
        windKmh: windKmh,
        tempC: tempC,
        maxIntensity: maxIntensity,
        hoursAbove2mm: hoursAbove2mm,
        hourly: hourly,
      );
}

class _HourRow {
  final DateTime? time;
  final double precipMm;
  final double windKmh;
  final double tempC;

  const _HourRow({
    required this.time,
    required this.precipMm,
    required this.windKmh,
    required this.tempC,
  });
}
