import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import '../../../utils/app_logger.dart';
import '../bmp_widget.dart';
import '../display_constants.dart';
import '../draw_helpers.dart';

/// Displays current weather via Open-Meteo API.
/// Default location: San Francisco (37.7749, -122.4194).
class BmpWeatherWidget extends BmpWidget {
  BmpWeatherWidget({
    this.latitude = 37.7749,
    this.longitude = -122.4194,
  });

  final double latitude;
  final double longitude;

  // Cached data ---------------------------------------------------------------
  double? _tempCurrent;
  double? _tempHigh;
  double? _tempLow;
  int? _weatherCode; // WMO code

  // BmpWidget -----------------------------------------------------------------

  @override
  String get id => 'bmp_weather';

  @override
  String get displayName => 'Weather';

  @override
  Duration get refreshInterval => const Duration(minutes: 15);

  @override
  Future<void> refresh() async {
    final client = HttpClient();
    try {
      final uri = Uri.parse(
        'https://api.open-meteo.com/v1/forecast'
        '?latitude=$latitude'
        '&longitude=$longitude'
        '&current_weather=true'
        '&daily=temperature_2m_max,temperature_2m_min'
        '&timezone=auto'
        '&forecast_days=1',
      );
      final request = await client.getUrl(uri);
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      final json = jsonDecode(body) as Map<String, dynamic>;

      final current = json['current_weather'] as Map<String, dynamic>?;
      if (current != null) {
        _tempCurrent = (current['temperature'] as num?)?.toDouble();
        _weatherCode = (current['weathercode'] as num?)?.toInt();
      }

      final daily = json['daily'] as Map<String, dynamic>?;
      if (daily != null) {
        final highs = daily['temperature_2m_max'] as List<dynamic>?;
        final lows = daily['temperature_2m_min'] as List<dynamic>?;
        if (highs != null && highs.isNotEmpty) {
          _tempHigh = (highs[0] as num?)?.toDouble();
        }
        if (lows != null && lows.isNotEmpty) {
          _tempLow = (lows[0] as num?)?.toDouble();
        }
      }
      lastRefreshed = DateTime.now();
    } catch (e) {
      // Keep stale data; log for diagnostics.
      appLogger.w('BmpWeather: refresh failed: $e');
    } finally {
      client.close(force: false);
    }
  }

  // Rendering -----------------------------------------------------------------

  @override
  void renderToCanvas(ui.Canvas canvas, HudZone zone) {
    final icon = _iconForCode(_weatherCode);
    const iconSize = 18.0;
    final w = zone.width.toDouble();
    final h = zone.height.toDouble();

    final iconY = (h - iconSize) / 2;
    HudDraw.icon(canvas, Offset(0, iconY), icon, iconSize);

    final textX = iconSize + 4.0;
    final tempStr = _tempCurrent != null ? '${_tempCurrent!.round()}°' : '--°';
    HudDraw.text(canvas, tempStr, Offset(textX, 2),
        fontSize: 16, weight: FontWeight.bold, maxWidth: w - iconSize - 8);

    final hiLoStr = 'H:${_tempHigh?.round() ?? '--'}° L:${_tempLow?.round() ?? '--'}°';
    HudDraw.text(canvas, hiLoStr, Offset(textX, 20),
        fontSize: 10, maxWidth: w - iconSize - 8);
  }

  // Helpers -------------------------------------------------------------------

  HudIcon _iconForCode(int? code) {
    if (code == null) return HudIcon.sun;
    // WMO weather interpretation codes (simplified).
    if (code == 0 || code == 1) return HudIcon.sun;
    if (code >= 2 && code <= 3) return HudIcon.cloud;
    if (code >= 51 && code <= 67) return HudIcon.rain;
    if (code >= 71 && code <= 77) return HudIcon.snow;
    if (code >= 80 && code <= 82) return HudIcon.rain;
    if (code >= 85 && code <= 86) return HudIcon.snow;
    if (code >= 95) return HudIcon.rain; // thunderstorm
    return HudIcon.cloud;
  }
}
