import 'dart:convert';
import 'package:http/http.dart' as http;

class GeocodeService {
  static const String baseUrl = String.fromEnvironment(
    'ALAGALERT_API',
    defaultValue: 'http://localhost:8000',
  );

  // Estados (UFs)
  static Future<List<Map<String, dynamic>>> searchStates(String query) async {
    if (query.trim().isEmpty) return [];
    final uri = Uri.parse('$baseUrl/geocode-states').replace(queryParameters: {
      'q': query.trim(),
      'country': 'br',
      'limit': '27',
    });

    final res = await http.get(uri);
    if (res.statusCode != 200) return [];
    final List data = jsonDecode(utf8.decode(res.bodyBytes)) as List;
    return data.cast<Map<String, dynamic>>();
  }

  // Cidades (filtradas pela UF)
  static Future<List<Map<String, dynamic>>> searchCities({
    required String cityQuery,
    required String uf,
    int limit = 20,
  }) async {
    if (cityQuery.trim().isEmpty || uf.trim().isEmpty) return [];
    final uri = Uri.parse('$baseUrl/geocode').replace(queryParameters: {
      'q': cityQuery.trim(),
      'country': 'br',
      'limit': '$limit',        // mantenha <= ao le do backend
      'cities_only': 'true',
      'uf': uf.toUpperCase(),
    });

    final res = await http.get(uri);
    if (res.statusCode != 200) return [];
    final List data = jsonDecode(utf8.decode(res.bodyBytes)) as List;
    return data.cast<Map<String, dynamic>>();
  }
}
