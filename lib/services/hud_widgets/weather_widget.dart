import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'hud_widget.dart';

/// Displays current weather and daily high/low on the HUD.
class WeatherWidget extends HudWidget {
  // Default to San Francisco; replace with dynamic location later.
  double latitude = 37.7749;
  double longitude = -122.4194;

  double? _tempF;
  String? _description;
  double? _hiF;
  double? _loF;

  @override
  String get id => 'weather';
  @override
  String get displayName => 'Weather';
  @override
  IconData get icon => Icons.wb_sunny;
  @override
  Duration get refreshInterval => const Duration(minutes: 30);
  @override
  int get maxLines => 2;

  @override
  Future<void> refresh() async {
    try {
      final uri = Uri.parse(
        'https://api.open-meteo.com/v1/forecast'
        '?latitude=$latitude&longitude=$longitude'
        '&current=temperature_2m,weather_code'
        '&daily=temperature_2m_max,temperature_2m_min'
        '&timezone=auto&forecast_days=1'
        '&temperature_unit=fahrenheit',
      );
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 10)
        ..idleTimeout = const Duration(seconds: 10);
      try {
        final request = await client.getUrl(uri);
        final response = await request.close();
        final body = await response.transform(utf8.decoder).join();
        final json = jsonDecode(body) as Map<String, dynamic>;

        final current = json['current'] as Map<String, dynamic>?;
        if (current != null) {
          _tempF = (current['temperature_2m'] as num?)?.toDouble();
          final code = (current['weather_code'] as num?)?.toInt() ?? -1;
          _description = _weatherDescription(code);
        }

        final daily = json['daily'] as Map<String, dynamic>?;
        if (daily != null) {
          final maxList = daily['temperature_2m_max'] as List?;
          final minList = daily['temperature_2m_min'] as List?;
          if (maxList != null && maxList.isNotEmpty) {
            _hiF = (maxList[0] as num?)?.toDouble();
          }
          if (minList != null && minList.isNotEmpty) {
            _loF = (minList[0] as num?)?.toDouble();
          }
        }
      } finally {
        client.close();
      }
    } catch (_) {
      // Keep cached data on failure.
    }
    lastRefreshed = DateTime.now();
  }

  @override
  List<String> renderLines() {
    try {
      if (_tempF == null) {
        return [HudWidget.truncate('Weather unavailable')];
      }
      final temp = _tempF!.round();
      final desc = _description ?? '';
      final line1 = HudWidget.truncate('$temp°F $desc');

      final hi = _hiF?.round();
      final lo = _loF?.round();
      final line2 = HudWidget.truncate('Hi ${hi ?? "--"}  Lo ${lo ?? "--"}');
      return [line1, line2];
    } catch (_) {
      return [HudWidget.truncate('Weather unavailable')];
    }
  }

  static String _weatherDescription(int code) {
    if (code == 0) return 'Clear';
    if (code >= 1 && code <= 3) return 'Cloudy';
    if (code >= 45 && code <= 48) return 'Foggy';
    if (code >= 51 && code <= 55) return 'Drizzle';
    if (code >= 56 && code <= 57) return 'Frz Drizzle';
    if (code >= 61 && code <= 65) return 'Rainy';
    if (code >= 66 && code <= 67) return 'Frz Rain';
    if (code >= 71 && code <= 75) return 'Snowy';
    if (code == 77) return 'Snow Grains';
    if (code >= 80 && code <= 82) return 'Showers';
    if (code >= 85 && code <= 86) return 'Snow Showers';
    if (code >= 95 && code <= 99) return 'Thunderstorm';
    return 'Weather';
  }
}
