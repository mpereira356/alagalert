import 'weather.dart';

class RiskFactors {
  final double precipitation6h;
  final double windAvg6h;
  final double tempAvg6h;

  RiskFactors(this.precipitation6h, this.windAvg6h, this.tempAvg6h);

  factory RiskFactors.fromJson(Map<String, dynamic> j) =>
      RiskFactors((j['precipitation_6h_mm'] as num).toDouble(),
          (j['wind_avg_6h_kmh'] as num).toDouble(),
          (j['temp_avg_6h_c'] as num).toDouble());
}

class RiskResult {
  final double riskScore;
  final String level;
  final String message;
  final RiskFactors factors;
  final List<WeatherPoint> window;
  final Map<String, dynamic>? location;

  RiskResult(this.riskScore, this.level, this.message, this.factors, this.window, this.location);

  factory RiskResult.fromJson(Map<String, dynamic> j) => RiskResult(
        (j['risk_score'] as num).toDouble(),
        j['level'],
        j['message'],
        RiskFactors.fromJson(j['factors']),
        (j['forecast_window'] as List).map((e) => WeatherPoint.fromJson(e)).toList(),
        j['location'] as Map<String, dynamic>?,
      );
}
