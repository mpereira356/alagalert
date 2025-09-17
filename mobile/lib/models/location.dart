class GeoCodeResult {
  final String name;
  final String uf;
  final String city;
  final double lat;
  final double lon;
  final String source;

  GeoCodeResult(
      {required this.name,
      required this.uf,
      required this.city,
      required this.lat,
      required this.lon,
      required this.source});

  factory GeoCodeResult.fromJson(Map<String, dynamic> j) => GeoCodeResult(
        name: j['name'],
        uf: j['uf'],
        city: j['city'],
        lat: (j['lat'] as num).toDouble(),
        lon: (j['lon'] as num).toDouble(),
        source: j['source'],
      );
}
