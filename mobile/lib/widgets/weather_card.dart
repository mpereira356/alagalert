import 'package:flutter/material.dart';
import '../models/weather.dart';

class WeatherCard extends StatelessWidget {
  final List<WeatherPoint> points;
  const WeatherCard({super.key, required this.points});

  Widget _tile(BuildContext ctx, WeatherPoint p) {
    final t = TimeOfDay.fromDateTime(p.timestamp);
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud, size: 28),
          const SizedBox(height: 6),
          Text("${t.format(ctx)}", style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text("${(p.precipitation ?? 0).toStringAsFixed(1)} mm"),
          Text("${(p.windSpeed ?? 0).toStringAsFixed(0)} km/h"),
          Text("${(p.temperature ?? 0).toStringAsFixed(0)}°")
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final slice = points.take(3).toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text("Próximas horas", style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          Row(children: slice.map((e) => _tile(context, e)).toList()),
        ]),
      ),
    );
  }
}
