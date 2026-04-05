import 'dart:ui';

/// G1 micro-OLED display specifications for BMP mode.
class G1Display {
  G1Display._();

  /// Logical design space — matches physical BMP dimensions 1:1.
  static const int width = 576;
  static const int height = 136;

  /// Physical BMP dimensions accepted by the Even bitmap transport.
  static const int bitmapWidth = 576;
  static const int bitmapHeight = 136;
  static const int bitsPerPixel = 1;
  static const int bmpTrailerBytes = 2;

  /// BMP row bytes: rows must be a multiple of 4 bytes.
  static const int rowBytes = (bitmapWidth + 31) ~/ 32 * 4; // 72

  /// Total pixel data size in BMP (excluding headers).
  ///
  /// Even's sample BMPs include a 2-byte trailing pad after the packed rows.
  static const int pixelDataSize =
      rowBytes * bitmapHeight + bmpTrailerBytes; // 9794

  /// BMP header size: 14 (file) + 40 (info) + 8 (color table).
  static const int headerSize = 62;

  /// Total BMP file size.
  static const int totalBmpSize = headerSize + pixelDataSize; // 9856
}

/// A rectangular zone on the G1 display where a widget renders.
class HudZone {
  final String id;
  final int x;
  final int y;
  final int width;
  final int height;

  const HudZone({
    required this.id,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  }) : assert(width > 0),
       assert(height > 0),
       assert(x >= 0),
       assert(y >= 0);

  Rect toRect() => Rect.fromLTWH(
    x.toDouble(),
    y.toDouble(),
    width.toDouble(),
    height.toDouble(),
  );
}

/// A divider line drawn between zones.
class HudDivider {
  final double x1, y1, x2, y2;
  final double thickness;

  const HudDivider({
    required this.x1,
    required this.y1,
    required this.x2,
    required this.y2,
    this.thickness = 2,
  });

  bool get isVertical => x1 == x2;
  bool get isHorizontal => y1 == y2;
}

/// A complete layout definition: named set of zones + dividers.
class HudLayout {
  final String id;
  final String name;
  final List<HudZone> zones;
  final List<HudDivider> dividers;

  /// Maps zone IDs to default widget IDs for this layout.
  final Map<String, String> defaultWidgetAssignments;

  const HudLayout({
    required this.id,
    required this.name,
    required this.zones,
    this.dividers = const [],
    this.defaultWidgetAssignments = const {},
  });

  HudZone? zoneById(String id) {
    for (final z in zones) {
      if (z.id == id) return z;
    }
    return null;
  }
}
