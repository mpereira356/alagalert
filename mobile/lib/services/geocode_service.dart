import 'dart:convert';
import 'package:http/http.dart' as http;

/// Ajuste o baseUrl pro seu backend:
/// Pode sobrescrever em build com:
/// flutter build web --release --dart-define=ALAGALERT_API=http://SEU_IP:8000
const String baseUrl = String.fromEnvironment(
  'ALAGALERT_API',
  defaultValue: 'http://191.252.193.10:8000',
);

class GeocodeService {
  /// Opcional: expõe também dentro da classe, para poder usar GeocodeService.baseUrl
  static const String baseUrl = String.fromEnvironment(
    'ALAGALERT_API',
    defaultValue: 'http://191.252.193.10:8000',
  );

  static const _defaultHeaders = {
    'Content-Type': 'application/json',
  };

  /// Busca ESTADOS no Nominatim via seu endpoint /geocode-states?q=
  /// Retorna: [{state, uf, lat, lon, display_name}, ...]
  static Future<List<Map<String, dynamic>>> searchStates(String query) async {
    if (query.trim().isEmpty) return [];
    final uri = Uri.parse('$baseUrl/geocode-states')
        .replace(queryParameters: {'q': query, 'country': 'br', 'limit': '27'});
    final res = await http.get(uri, headers: _defaultHeaders);
    if (res.statusCode != 200) return [];
    final List data = jsonDecode(utf8.decode(res.bodyBytes));
    return data.cast<Map<String, dynamic>>();
  }

  /// Busca CIDADES consultando /geocode com "cidade UF, Brasil"
  /// Retorna: [{city, uf, lat, lon, display_name}, ...]
  static Future<List<Map<String, dynamic>>> searchCities({
    required String cityQuery,
    required String uf,
  }) async {
    final q = cityQuery.trim();
    if (q.isEmpty || uf.trim().isEmpty) return [];
    final composed = '$q $uf, Brasil';
    final uri = Uri.parse('$baseUrl/geocode').replace(queryParameters: {
      'q': composed,
      'country': 'br',
      'limit': '8',
      'cities_only': 'true',
    });
    final res = await http.get(uri, headers: _defaultHeaders);
    if (res.statusCode != 200) return [];
    final List data = jsonDecode(utf8.decode(res.bodyBytes));
    return data.cast<Map<String, dynamic>>();
  }

  /// (Opcional) Utilitário para chamar /risk/by-city
  static Future<Map<String, dynamic>> riskByCity({
    required String uf,
    required String city,
  }) async {
    final uri = Uri.parse('$baseUrl/risk/by-city')
        .replace(queryParameters: {'uf': uf, 'city': city});
    final res = await http.get(uri, headers: _defaultHeaders);
    if (res.statusCode != 200) {
      throw Exception('Erro ${res.statusCode}: ${utf8.decode(res.bodyBytes)}');
    }
    return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
  }
}
