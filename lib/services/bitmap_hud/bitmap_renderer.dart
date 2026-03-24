import 'dart:ui' as ui;
import 'dart:typed_data';

import '../../utils/app_logger.dart';
import 'bmp_encoder.dart';
import 'bmp_widget.dart';
import 'display_constants.dart';
import 'draw_helpers.dart';

/// Renders a complete bitmap HUD frame from a layout and widget assignments.
///
/// Pipeline: PictureRecorder → Canvas → Image → RGBA → 1-bit BMP bytes.
class BitmapRenderer {
  BitmapRenderer._();

  /// Render the given [layout] with [zoneWidgets] to a 1-bit BMP [Uint8List].
  ///
  /// [zoneWidgets] maps zone IDs to BmpWidget instances. Zones without an
  /// assigned widget are left black.
  static Future<Uint8List> render(
    HudLayout layout,
    Map<String, BmpWidget> zoneWidgets,
  ) async {
    final recorder = ui.PictureRecorder();
    final displayRect = ui.Rect.fromLTWH(
      0,
      0,
      G1Display.width.toDouble(),
      G1Display.height.toDouble(),
    );
    final canvas = ui.Canvas(recorder, displayRect);

    // Fill background black
    canvas.drawRect(
      displayRect,
      ui.Paint()..color = const ui.Color(0xFF000000),
    );

    // Render each zone's widget
    for (final zone in layout.zones) {
      final widget = zoneWidgets[zone.id];
      if (widget == null) continue;

      canvas.save();
      canvas.clipRect(zone.toRect());
      canvas.translate(zone.x.toDouble(), zone.y.toDouble());

      try {
        widget.renderToCanvas(canvas, zone);
      } catch (e) {
        appLogger.w('BitmapRenderer: widget "${zone.id}" render failed: $e');
      }

      canvas.restore();
    }

    // Draw dividers
    for (final divider in layout.dividers) {
      if (divider.isVertical) {
        HudDraw.vLine(
          canvas,
          divider.x1,
          divider.y1,
          divider.y2 - divider.y1,
          thickness: divider.thickness,
        );
      } else if (divider.isHorizontal) {
        HudDraw.hLine(
          canvas,
          divider.x1,
          divider.y1,
          divider.x2 - divider.x1,
          thickness: divider.thickness,
        );
      } else {
        // Diagonal divider (rare)
        canvas.drawLine(
          ui.Offset(divider.x1, divider.y1),
          ui.Offset(divider.x2, divider.y2),
          ui.Paint()
            ..color = const ui.Color(0xFFFFFFFF)
            ..strokeWidth = divider.thickness
            ..isAntiAlias = false,
        );
      }
    }

    // Convert to image
    final picture = recorder.endRecording();
    final image = await picture.toImage(G1Display.width, G1Display.height);
    final byteData =
        await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    picture.dispose();
    image.dispose();

    if (byteData == null) {
      throw StateError('Failed to get RGBA data from rendered HUD image');
    }

    // Encode to 1-bit BMP
    return BmpEncoder.fromRgba(byteData, G1Display.width, G1Display.height);
  }
}
