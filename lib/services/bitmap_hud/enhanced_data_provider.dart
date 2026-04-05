import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

import '../../utils/app_logger.dart';

/// Shared data cache for enhanced HUD widgets.
///
/// Prevents duplicate API calls when multiple widgets need the same data
/// (e.g., header and footer both need weather and battery info).
class EnhancedDataProvider {
  EnhancedDataProvider._();

  static EnhancedDataProvider? _instance;
  static EnhancedDataProvider get instance =>
      _instance ??= EnhancedDataProvider._();

  // Weather data
  double? weatherTemp;
  double? weatherHigh;
  double? weatherLow;
  int? weatherCode;
  DateTime? _weatherRefreshedAt;

  // Battery data
  double phoneBattery = 1.0;
  double glassesBattery = 1.0;
  bool bleConnected = false;

  // Notification data
  int notificationCount = 0;

  // Calendar events
  List<CalendarEvent> calendarEvents = [];
  DateTime? _calendarRefreshedAt;

  // Activity data (HealthKit)
  int steps = 0;
  double activeCalories = 0;
  int exerciseMinutes = 0;
  int standHours = 0;
  int stepGoal = 10000;

  /// Whether real activity data is available (false = HealthKit denied/unavailable).
  bool activityAvailable = false;
  DateTime? _activityRefreshedAt;

  // Stock data
  String? stockTicker;
  double? stockPrice;
  double? stockChange;
  double? stockChangePercent;
  List<double> stockIntradayPrices = [];

  // News headlines
  List<String> newsHeadlines = [];
  DateTime? _newsRefreshedAt;

  static const _eventKitChannel = MethodChannel('method.eventkit');
  static const _healthKitChannel = MethodChannel('method.healthkit');

  // Concurrency guards to prevent duplicate API calls
  bool _weatherRefreshing = false;
  bool _activityRefreshing = false;

  /// Refresh weather data if stale (>15 min).
  Future<void> refreshWeather({
    double latitude = 37.7749,
    double longitude = -122.4194,
  }) async {
    if (_weatherRefreshing) return;
    if (_weatherRefreshedAt != null &&
        DateTime.now().difference(_weatherRefreshedAt!) <
            const Duration(minutes: 15)) {
      return;
    }
    _weatherRefreshing = true;

    final client = HttpClient();
    try {
      final uri = Uri.parse(
        'https://api.open-meteo.com/v1/forecast'
        '?latitude=$latitude'
        '&longitude=$longitude'
        '&current_weather=true'
        '&daily=temperature_2m_max,temperature_2m_min'
        '&temperature_unit=fahrenheit'
        '&timezone=auto'
        '&forecast_days=1',
      );
      final request = await client.getUrl(uri);
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      final json = jsonDecode(body) as Map<String, dynamic>;

      final current = json['current_weather'] as Map<String, dynamic>?;
      if (current != null) {
        weatherTemp = (current['temperature'] as num?)?.toDouble();
        weatherCode = (current['weathercode'] as num?)?.toInt();
      }

      final daily = json['daily'] as Map<String, dynamic>?;
      if (daily != null) {
        final highs = daily['temperature_2m_max'] as List?;
        final lows = daily['temperature_2m_min'] as List?;
        if (highs != null && highs.isNotEmpty) {
          weatherHigh = (highs[0] as num?)?.toDouble();
        }
        if (lows != null && lows.isNotEmpty) {
          weatherLow = (lows[0] as num?)?.toDouble();
        }
      }
      _weatherRefreshedAt = DateTime.now();
    } catch (e) {
      appLogger.w('EnhancedDataProvider: weather refresh failed: $e');
      _weatherRefreshedAt = DateTime.now(); // Prevent retry storm
    } finally {
      client.close(force: false);
      _weatherRefreshing = false;
    }
  }

  /// Refresh calendar events if stale (>5 min).
  Future<void> refreshCalendar() async {
    if (_calendarRefreshedAt != null &&
        DateTime.now().difference(_calendarRefreshedAt!) <
            const Duration(minutes: 5)) {
      return;
    }

    try {
      final result = await _eventKitChannel.invokeMethod<List>(
        'getUpcomingCalendarEvents',
      );
      if (result != null) {
        calendarEvents = result.map((e) {
          final m = Map<String, dynamic>.from(e as Map);
          return CalendarEvent(
            title: m['title'] as String? ?? '',
            startDate: DateTime.tryParse(m['startDate'] as String? ?? ''),
            location: m['location'] as String?,
            isAllDay: m['isAllDay'] as bool? ?? false,
          );
        }).toList();
      }
    } on MissingPluginException {
      // Platform channel not available (simulator)
      calendarEvents = [];
    } catch (e) {
      appLogger.w('EnhancedDataProvider: calendar refresh failed: $e');
    }

    // Fall back to single-event API if multi-event not available
    if (calendarEvents.isEmpty) {
      try {
        final result = await _eventKitChannel.invokeMethod<Map>(
          'getNextCalendarEvent',
        );
        if (result != null) {
          calendarEvents = [
            CalendarEvent(
              title: result['title'] as String? ?? '',
              startDate: DateTime.tryParse(
                result['startDate'] as String? ?? '',
              ),
              location: result['location'] as String?,
              isAllDay: result['isAllDay'] as bool? ?? false,
            ),
          ];
        }
      } on MissingPluginException {
        // Platform channel not available
      } catch (_) {}
    }

    _calendarRefreshedAt = DateTime.now();
  }

  /// Refresh activity data if stale (>5 min).
  Future<void> refreshActivity() async {
    if (_activityRefreshing) return;
    if (_activityRefreshedAt != null &&
        DateTime.now().difference(_activityRefreshedAt!) <
            const Duration(minutes: 5)) {
      return;
    }

    _activityRefreshing = true;
    try {
      final result = await _healthKitChannel.invokeMethod<Map>(
        'getActivityData',
      );
      if (result != null) {
        steps = (result['steps'] as num?)?.toInt() ?? 0;
        activeCalories = (result['activeCalories'] as num?)?.toDouble() ?? 0;
        exerciseMinutes = (result['exerciseMinutes'] as num?)?.toInt() ?? 0;
        standHours = (result['standHours'] as num?)?.toInt() ?? 0;
        stepGoal = (result['stepGoal'] as num?)?.toInt() ?? 10000;
        activityAvailable = true;
      }
    } on MissingPluginException {
      // HealthKit not available (simulator) — mark unavailable
      activityAvailable = false;
    } catch (e) {
      appLogger.w('EnhancedDataProvider: activity refresh failed: $e');
      activityAvailable = false;
    }

    _activityRefreshedAt = DateTime.now();
    _activityRefreshing = false;
  }

  /// Refresh news headlines if stale (>15 min).
  Future<void> refreshNews({
    String feedUrl = 'https://feeds.bbci.co.uk/news/world/rss.xml',
  }) async {
    if (_newsRefreshedAt != null &&
        DateTime.now().difference(_newsRefreshedAt!) <
            const Duration(minutes: 15)) {
      return;
    }

    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10)
      ..idleTimeout = const Duration(seconds: 10);
    try {
      final uri = Uri.parse(feedUrl);
      final request = await client.getUrl(uri);
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      newsHeadlines = _parseHeadlines(body, maxItems: 5);
      _newsRefreshedAt = DateTime.now();
    } catch (e) {
      appLogger.w('EnhancedDataProvider: news refresh failed: $e');
    } finally {
      client.close();
    }
  }

  /// Refresh all data sources.
  Future<void> refreshAll() async {
    await Future.wait([
      refreshWeather(),
      refreshCalendar(),
      refreshActivity(),
      refreshNews(),
    ]);
  }

  /// Update externally-pushed values.
  void setPhoneBattery(double level) => phoneBattery = level.clamp(0.0, 1.0);
  void setGlassesBattery(double level) =>
      glassesBattery = level.clamp(0.0, 1.0);
  void setBleConnected(bool connected) => bleConnected = connected;
  void setNotificationCount(int count) => notificationCount = count;

  // --- RSS parsing ---

  List<String> _parseHeadlines(String xml, {int maxItems = 5}) {
    final results = <String>[];
    final itemPattern = RegExp(
      r'<item[^>]*>([\s\S]*?)<\/item>',
      caseSensitive: false,
    );
    final titlePattern = RegExp(
      r'<title[^>]*>([\s\S]*?)<\/title>',
      caseSensitive: false,
    );

    for (final itemMatch in itemPattern.allMatches(xml)) {
      if (results.length >= maxItems) break;
      final itemContent = itemMatch.group(1) ?? '';
      final titleMatch = titlePattern.firstMatch(itemContent);
      if (titleMatch == null) continue;

      var title = titleMatch.group(1) ?? '';
      title = title
          .replaceAll(RegExp(r'<!\[CDATA\[|\]\]>'), '')
          .trim()
          .replaceAll('&amp;', '&')
          .replaceAll('&lt;', '<')
          .replaceAll('&gt;', '>')
          .replaceAll('&quot;', '"')
          .replaceAll('&#39;', "'")
          .replaceAll('&apos;', "'");
      title = title.replaceAllMapped(
        RegExp(r'&#(\d+);'),
        (m) => String.fromCharCode(int.parse(m.group(1)!)),
      );
      title = title.replaceAllMapped(
        RegExp(r'&#x([0-9a-fA-F]+);', caseSensitive: false),
        (m) => String.fromCharCode(int.parse(m.group(1)!, radix: 16)),
      );
      if (title.isNotEmpty) results.add(title);
    }
    return results;
  }
}

/// A calendar event for display.
class CalendarEvent {
  final String title;
  final DateTime? startDate;
  final String? location;
  final bool isAllDay;

  const CalendarEvent({
    required this.title,
    this.startDate,
    this.location,
    this.isAllDay = false,
  });

  String formatTime() {
    if (startDate == null) return '';
    if (isAllDay) return 'All day';
    final h = startDate!.hour;
    final m = startDate!.minute.toString().padLeft(2, '0');
    final period = h >= 12 ? 'PM' : 'AM';
    final h12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    return '$h12:$m $period';
  }

  /// Minutes until event starts (negative if already started).
  int? minutesUntil() {
    if (startDate == null) return null;
    return startDate!.difference(DateTime.now()).inMinutes;
  }
}
