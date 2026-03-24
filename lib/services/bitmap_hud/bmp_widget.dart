import 'dart:ui' as ui;

import 'display_constants.dart';

/// Abstract base class for bitmap HUD widgets that render to a Canvas.
///
/// Each widget fetches data from a source, caches it, and renders pixels
/// within a [HudZone] on the G1 display. This replaces the text-based
/// [HudWidget] for the bitmap HUD render path.
abstract class BmpWidget {
  /// Unique identifier (e.g., 'bmp_clock', 'bmp_weather').
  String get id;

  /// Human-readable name for the Settings UI.
  String get displayName;

  /// How often [refresh] should be called.
  Duration get refreshInterval;

  /// When data was last successfully refreshed.
  DateTime? lastRefreshed;

  /// Fetch fresh data from the source. Implementations must not throw.
  Future<void> refresh();

  /// Render this widget's content onto [canvas] within the given [zone].
  ///
  /// The [BitmapRenderer] clips the canvas to the zone and translates the
  /// origin to (zone.x, zone.y) before calling this method. Implementations
  /// should draw starting from (0, 0) up to (zone.width, zone.height).
  void renderToCanvas(ui.Canvas canvas, HudZone zone);
}
