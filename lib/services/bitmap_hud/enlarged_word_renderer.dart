import 'dart:typed_data';
import 'dart:ui' as ui;

import '../../utils/app_logger.dart';
import 'bmp_encoder.dart';
import 'display_constants.dart';

/// Renders a single word centered on the G1 display bitmap at 4× the base
/// text-HUD font size (base 21pt → 84pt). Used by the accessibility /
/// glanceable "enlarged words" render path.
///
/// Graceful fallback: if the word, rendered at the target size, would
/// exceed the usable display width (`G1Display.width` minus horizontal
/// padding), the font size is scaled down proportionally so the glyphs
/// always fit within the bitmap. A word that is empty or pure whitespace
/// renders as a blank frame rather than crashing.
class EnlargedWordRenderer {
  EnlargedWordRenderer._();

  /// Base font size of the standard text HUD (in logical pixels). The
  /// bitmap HUD shares the same coordinate space as the text HUD.
  static const double baseFontSize = 21.0;

  /// Scale factor applied on top of [baseFontSize] for the enlarged path.
  static const double zoomFactor = 4.0;

  /// Target font size when no fallback scaling is required.
  static const double targetFontSize = baseFontSize * zoomFactor; // 84

  /// Horizontal padding (each side) reserved inside the bitmap so glyphs
  /// never butt up against the display edge.
  static const double horizontalPadding = 8.0;

  /// Maximum pixel width available to the rendered word.
  static double get maxTextWidth =>
      G1Display.width.toDouble() - (horizontalPadding * 2);

  /// Measure the font size that makes [word] fit within [maxTextWidth].
  /// Returns [targetFontSize] when the word already fits.
  static Future<double> measureFittingFontSize(String word) async {
    if (word.isEmpty) return targetFontSize;

    final painter = _paintWord(word, targetFontSize);
    painter.layout(maxWidth: double.infinity);
    final naturalWidth = painter.width;
    painter.dispose();

    if (naturalWidth <= maxTextWidth) {
      return targetFontSize;
    }
    // Scale proportionally so the rendered width == maxTextWidth.
    final scaled = targetFontSize * (maxTextWidth / naturalWidth);
    // Never go below baseFontSize — the text HUD fallback handles
    // anything smaller than that.
    return scaled < baseFontSize ? baseFontSize : scaled;
  }

  /// Render [word] as a 1-bit BMP [Uint8List] ready for the BLE transport.
  static Future<Uint8List> render(String word) async {
    final image = await renderToImage(word);
    final byteData = await image.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    );
    image.dispose();
    if (byteData == null) {
      throw StateError('EnlargedWordRenderer: failed to read RGBA bytes');
    }
    return BmpEncoder.fromRgba(
      byteData,
      G1Display.bitmapWidth,
      G1Display.bitmapHeight,
    );
  }

  /// Render [word] to a [ui.Image] for phone-side preview / tests.
  static Future<ui.Image> renderToImage(String word) async {
    final recorder = ui.PictureRecorder();
    final rect = ui.Rect.fromLTWH(
      0,
      0,
      G1Display.width.toDouble(),
      G1Display.height.toDouble(),
    );
    final canvas = ui.Canvas(recorder, rect);
    canvas.drawRect(rect, ui.Paint()..color = const ui.Color(0xFF000000));

    final trimmed = word.trim();
    if (trimmed.isNotEmpty) {
      final fontSize = await measureFittingFontSize(trimmed);
      final painter = _paintWord(trimmed, fontSize);
      painter.layout(maxWidth: maxTextWidth);
      final dx = ((G1Display.width - painter.width) / 2).floorToDouble();
      final dy = ((G1Display.height - painter.height) / 2).floorToDouble();
      try {
        painter.paint(canvas, ui.Offset(dx, dy));
      } catch (e) {
        appLogger.w('EnlargedWordRenderer: paint failed: $e');
      }
      painter.dispose();
    }

    final picture = recorder.endRecording();
    final image = await picture.toImage(
      G1Display.bitmapWidth,
      G1Display.bitmapHeight,
    );
    picture.dispose();
    return image;
  }

  static ui.ParagraphBuilder _builder(double fontSize) {
    return ui.ParagraphBuilder(
      ui.ParagraphStyle(
        textAlign: ui.TextAlign.center,
        fontSize: fontSize,
        fontWeight: ui.FontWeight.w700,
        maxLines: 1,
        ellipsis: '',
      ),
    )..pushStyle(ui.TextStyle(color: const ui.Color(0xFFFFFFFF)));
  }

  /// Lightweight text "painter" built on raw [ui.Paragraph] so this
  /// module has no dependency on Flutter's widget layer. Mirrors the
  /// subset of TextPainter the renderer needs.
  static _ParagraphPainter _paintWord(String word, double fontSize) {
    final builder = _builder(fontSize)..addText(word);
    return _ParagraphPainter(builder.build());
  }
}

class _ParagraphPainter {
  _ParagraphPainter(this._paragraph);
  final ui.Paragraph _paragraph;
  bool _laidOut = false;

  double get width => _paragraph.longestLine;
  double get height => _paragraph.height;

  void layout({required double maxWidth}) {
    _paragraph.layout(ui.ParagraphConstraints(width: maxWidth));
    _laidOut = true;
  }

  void paint(ui.Canvas canvas, ui.Offset offset) {
    if (!_laidOut) {
      layout(maxWidth: double.infinity);
    }
    canvas.drawParagraph(_paragraph, offset);
  }

  void dispose() {
    // ui.Paragraph has no explicit dispose in current Flutter; kept for
    // API symmetry with TextPainter so callers can `.dispose()`.
  }
}
