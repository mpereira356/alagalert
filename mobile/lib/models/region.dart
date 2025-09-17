import 'package:latlong2/latlong.dart';

class RegionFeature {
  final Map<String, dynamic> properties;
  final List<List<LatLng>> polygons; // suporte a MultiPolygon simplificado

  RegionFeature(this.properties, this.polygons);

  static List<LatLng> _coordsToLatLng(List coords) =>
      coords.map<LatLng>((p) => LatLng((p[1] as num).toDouble(), (p[0] as num).toDouble())).toList();

  factory RegionFeature.fromGeoJson(Map<String, dynamic> f) {
    final type = f['geometry']['type'];
    final props = Map<String, dynamic>.from(f['properties'] ?? {});
    final polygons = <List<LatLng>>[];

    if (type == 'Polygon') {
      polygons.add(_coordsToLatLng(List.from(f['geometry']['coordinates'][0])));
    } else if (type == 'MultiPolygon') {
      for (final poly in f['geometry']['coordinates']) {
        polygons.add(_coordsToLatLng(List.from(poly[0])));
      }
    }
    return RegionFeature(props, polygons);
  }
}
