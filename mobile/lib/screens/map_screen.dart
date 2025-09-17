import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../services/api_service.dart';
import '../models/region.dart';
import '../theme/app_theme.dart';
import '../widgets/region_legend.dart';
import 'package:alagalert/theme/levels.dart';

class MapScreen extends StatefulWidget {
  final String uf;
  const MapScreen({super.key, required this.uf});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final _mapController = MapController();
  List<RegionFeature> _features = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final gj = await ApiService.getRegions('city', uf: widget.uf);
      final feats = (gj['features'] as List)
          .map((f) => RegionFeature.fromGeoJson(Map<String, dynamic>.from(f)))
          .toList();
      setState(() => _features = feats);

      if (feats.isEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sem polígonos para UF ${widget.uf}.')),
        );
      } else {
        // Centraliza no primeiro polígono válido
        final pts = feats.first.polygons.expand((p) => p).toList();
        if (pts.isNotEmpty) {
          final avgLat = pts.map((e) => e.latitude).reduce((a, b) => a + b) / pts.length;
          final avgLng = pts.map((e) => e.longitude).reduce((a, b) => a + b) / pts.length;
          _mapController.move(LatLng(avgLat, avgLng), 7.5);
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao carregar regiões: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Color _colorFor(String level) => (levelColors[level] ?? levelColors["Moderado"]!).withOpacity(.35);

  @override
  Widget build(BuildContext context) {
    // por enquanto usa mesma cor para todas (poderia vir do backend)
    final fill = _colorFor("Moderado");
    final border = (levelColors["Moderado"] ?? Colors.blue);

    return Scaffold(
      appBar: AppBar(title: Text("Mapa – ${widget.uf}")),
      body: Stack(children: [
        FlutterMap(
          mapController: _mapController,
          options: const MapOptions(initialCenter: LatLng(-15.78, -47.93), initialZoom: 4.5),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'alagalert',
            ),
            PolygonLayer(
              polygons: _features.expand((f) => f.polygons.map((poly) => Polygon(
                points: poly,
                borderStrokeWidth: 1.0,
                borderColor: border,
                color: fill, // v7 usa `color` como fill
                isFilled: true,
              ))).toList(),
            ),
          ],
        ),
        if (_loading) const Center(child: CircularProgressIndicator()),
        Positioned(left: 12, bottom: 12, right: 12, child: const RegionLegend()),
      ]),
      floatingActionButton: FloatingActionButton(
        onPressed: _load,
        child: const Icon(Icons.refresh),
      ),
    );
  }
}
