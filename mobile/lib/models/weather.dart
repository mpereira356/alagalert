class WeatherPoint {
  final DateTime timestamp;
  final double? temperature;
  final double? precipitation;
  final double? windSpeed;

  WeatherPoint({
    required this.timestamp,
    this.temperature,
    this.precipitation,
    this.windSpeed,
  });

  factory WeatherPoint.fromJson(Map<String, dynamic> j) => WeatherPoint(
        timestamp: DateTime.parse(j['timestamp']),
        temperature: (j['temperature'] as num?)?.toDouble(),
        precipitation: (j['precipitation'] as num?)?.toDouble(),
        windSpeed: (j['wind_speed'] as num?)?.toDouble(),
      );
}
