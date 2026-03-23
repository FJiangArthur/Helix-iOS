import 'package:flutter/material.dart';

/// Abstract base class for HUD widgets that provide content to the glasses dashboard.
///
/// Each widget fetches data from a source, caches it, and renders 1-5 lines of
/// text (max 24 chars each) for the glasses display.
abstract class HudWidget {
  static const int lineWidth = 24;

  /// Unique identifier matching [HudWidgetConfig.widgetId].
  String get id;

  /// Human-readable name for the Settings UI.
  String get displayName;

  /// Icon for the Settings UI.
  IconData get icon;

  /// How often [refresh] should be called.
  Duration get refreshInterval;

  /// Maximum number of display lines this widget can produce (1-5).
  int get maxLines;

  /// When data was last successfully refreshed.
  DateTime? lastRefreshed;

  /// Fetch fresh data from the source. Implementations must not throw.
  Future<void> refresh();

  /// Format cached data into display lines.
  /// Returns 0 to [maxLines] lines, each ≤ [lineWidth] chars.
  /// Must not throw — return fallback text on error.
  List<String> renderLines();

  /// Truncate a string to fit within the display line width.
  static String truncate(String value, [int width = lineWidth]) {
    final trimmed = value.trim();
    if (trimmed.length <= width) return trimmed;
    return '${trimmed.substring(0, width - 3)}...';
  }
}
