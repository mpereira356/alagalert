import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key, required this.uf});
  final String uf;

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _map = MapController();

  List<Polygon<Object>> _polygons = const [];
  LatLng _center = const LatLng(-14.235, -51.9253); // Brasil
  double _zoom = 5.0;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadGeojson(widget.uf);
  }

  Future<void> _loadGeojson(String uf) async {
    setState(() {
      _loading = true;
      _error = null;
      _polygons = const [];
    });

    try {
      // Ex.: assets/ibge/SP.geojson
      final path = 'assets/ibge/${uf.toUpperCase()}.geojson';
      final raw = await rootBundle.loadString(path);
      final data = jsonDecode(raw);

      final features = (data is Map && data['features'] is List)
          ? (data['features'] as List)
          : (data['type'] == 'Feature' ? [data] : <dynamic>[]);

      final polygons = <Polygon<Object>>[];
      final allPts = <LatLng>[];

      for (final f in features) {
        if (f is! Map) continue;
        final geom = f['geometry'];
        if (geom is! Map) continue;

        final type = (geom['type'] ?? '').toString();
        final coords = geom['coordinates'];

        if (type == 'Polygon' && coords is List) {
          final rings = _parsePolygon(coords);
          for (final ring in rings) {
            if (ring.isEmpty) continue;
            polygons.add(_mkPolygon(ring));
            allPts.addAll(ring);
          }
        } else if (type == 'MultiPolygon' && coords is List) {
          for (final poly in coords) {
            final rings = _parsePolygon(poly);
            for (final ring in rings) {
              if (ring.isEmpty) continue;
              polygons.add(_mkPolygon(ring));
              allPts.addAll(ring);
            }
          }
        }
      }

      // Centro/zoom manual pelos limites
      if (allPts.isNotEmpty) {
        double minLat = allPts.first.latitude,
            maxLat = allPts.first.latitude,
            minLon = allPts.first.longitude,
            maxLon = allPts.first.longitude;
        for (final p in allPts) {
          if (p.latitude < minLat) minLat = p.latitude;
          if (p.latitude > maxLat) maxLat = p.latitude;
          if (p.longitude < minLon) minLon = p.longitude;
          if (p.longitude > maxLon) maxLon = p.longitude;
        }
        _center = LatLng((minLat + maxLat) / 2, (minLon + maxLon) / 2);

        final latSpan = (maxLat - minLat).abs().clamp(0.1, 60.0);
        final lonSpan = (maxLon - minLon).abs().clamp(0.1, 60.0);
        final span = latSpan > lonSpan ? latSpan : lonSpan;

        double z;
        if (span > 25) z = 4.0;
        else if (span > 12) z = 5.0;
        else if (span > 6) z = 6.0;
        else if (span > 3) z = 7.0;
        else if (span > 1.5) z = 8.0;
        else z = 9.0;
        _zoom = z;
      } else {
        _center = const LatLng(-14.235, -51.9253);
        _zoom = 5.0;
      }

      setState(() {
        _polygons = polygons;
        _loading = false;
      });

      _map.move(_center, _zoom);
    } catch (e) {
      setState(() {
        _error = 'Falha ao carregar GeoJSON de ${widget.uf}: $e';
        _loading = false;
      });
    }
  }

  /// Converte rings GeoJSON -> lista de pontos (LatLng).
  /// Formato esperado: [ [ [lon,lat], [lon,lat], ... ] , ... ]
  List<List<LatLng>> _parsePolygon(dynamic coords) {
    final rings = <List<LatLng>>[];
    if (coords is! List) return rings;

    for (final ring in coords) {
      if (ring is! List) continue;
      final pts = <LatLng>[];
      for (final pair in ring) {
        if (pair is List && pair.length >= 2) {
          final lon = (pair[0] as num?)?.toDouble();
          final lat = (pair[1] as num?)?.toDouble();
          if (lat != null && lon != null) {
            pts.add(LatLng(lat, lon));
          }
        }
      }
      if (pts.isNotEmpty) rings.add(pts);
    }
    return rings;
  }

  Polygon<Object> _mkPolygon(List<LatLng> pts) {
    return Polygon<Object>(
      points: pts,
      color: Colors.deepPurple.withOpacity(0.15), // fill
      borderColor: Colors.deepPurple,             // stroke
      borderStrokeWidth: 1.0,
    );
    // ⚠️ Sem 'isFilled' ou 'isDotted' no flutter_map 8.x
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Mapa • ${widget.uf.toUpperCase()}'),
        actions: [
          IconButton(
            tooltip: 'Recarregar',
            onPressed: () => _loadGeojson(widget.uf),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(_error!, textAlign: TextAlign.center),
                  ),
                )
              : FlutterMap(
                  mapController: _map,
                  options: MapOptions(
                    initialCenter: _center,
                    initialZoom: _zoom,
                    interactionOptions:
                        const InteractionOptions(flags: InteractiveFlag.all),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                      subdomains: const ['a', 'b', 'c'],
                      userAgentPackageName: 'alagalert',
                    ),
                    if (_polygons.isNotEmpty) PolygonLayer(polygons: _polygons),
                    _Legend(uf: widget.uf, count: _polygons.length),
                  ],
                ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.uf, required this.count});
  final String uf;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomLeft,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(.9),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.black12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: Colors.deepPurple.withOpacity(0.25),
                  border: Border.all(color: Colors.deepPurple),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 8),
              Text('Polígonos $uf: $count'),
            ],
          ),
        ),
      ),
    );
  }
}
