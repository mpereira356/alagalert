import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/risk.dart';
import '../models/location.dart';

/// Centralize o endpoint da API:
/// - Em produção, use --dart-define=API_URL=https://seu-dominio.com
/// - Se nada for passado, usa o IP público e porta como default
class ApiService {
  // Um único ponto de origem para Web e Mobile
  static final String baseUrl = const String.fromEnvironment(
    'API_URL',
    // ALTERE aqui se quiser outro default
    defaultValue: 'http://191.252.193.10:8000',
  );

  static Uri _u(String path, [Map<String, String>? query]) {
    final uri = Uri.parse(baseUrl);
    // Garante que não vai duplicar barras
    final cleanBase = uri.origin + (uri.path.endsWith('/') ? uri.path.substring(0, uri.path.length - 1) : uri.path);
    final cleanPath = path.startsWith('/') ? path : '/$path';
    return Uri.parse(cleanBase + cleanPath).replace(queryParameters: query);
  }

  static Future<RiskResult> getRiskByCity(String uf, String city) async {
    final url = _u('/risk/by-city', {
      'uf': uf,
      'city': Uri.encodeQueryComponent(city),
    });
    debugPrint('GET $url');

    final r = await http.get(url).timeout(const Duration(seconds: 20));
    if (r.statusCode != 200) {
      debugPrint('ERRO ${r.statusCode}: ${r.body}');
      throw Exception('Erro ${r.statusCode} ao obter risco');
    }
    return RiskResult.fromJson(jsonDecode(r.body));
  }

  static Future<List<GeoCodeResult>> geocode(String q) async {
    final url = _u('/geocode', {
      'q': Uri.encodeQueryComponent(q),
    });
    debugPrint('GET $url');

    final r = await http.get(url).timeout(const Duration(seconds: 15));
    if (r.statusCode != 200) return [];
    final data = jsonDecode(r.body) as List;
    return data.map((e) => GeoCodeResult.fromJson(e)).toList();
  }

  static Future<Map<String, dynamic>> getRegions(String level, {String? uf}) async {
    final query = {'level': level, if (uf != null) 'uf': uf};
    final url = _u('/regions', query);
    debugPrint('GET $url');

    final r = await http.get(url).timeout(const Duration(seconds: 25));
    if (r.statusCode != 200) {
      debugPrint('ERRO ${r.statusCode}: ${r.body}');
      throw Exception('Erro ao obter regiões');
    }
    return jsonDecode(r.body) as Map<String, dynamic>;
  }
}
