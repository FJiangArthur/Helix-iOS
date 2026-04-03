import 'dart:typed_data';
import 'dart:ui' as ui;

import 'display_constants.dart';

/// Encodes a Flutter [ui.Image] or raw RGBA pixels into a 1-bit monochrome BMP
/// suitable for the Even G1 bitmap transport.
class BmpEncoder {
  BmpEncoder._();

  /// Convert a rendered [ui.Image] to 1-bit BMP bytes.
  static Future<Uint8List> fromImage(
    ui.Image image, {
    int threshold = 128,
  }) async {
    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (byteData == null) {
      throw StateError('Failed to get RGBA data from image');
    }
    return fromRgba(byteData, image.width, image.height, threshold: threshold);
  }

  /// Convert raw RGBA byte data to 1-bit BMP.
  ///
  /// Each pixel's luminance (R+G+B)/3 is compared against [threshold].
  /// Pixels above threshold become palette index 0 (white), while darker pixels
  /// remain palette index 1 (black). This matches Even's sample BMP assets.
  static Uint8List fromRgba(
    ByteData rgba,
    int width,
    int height, {
    int threshold = 128,
  }) {
    final rowBytes = (width + 31) ~/ 32 * 4;
    final pixelDataSize = rowBytes * height + G1Display.bmpTrailerBytes;
    final fileSize = G1Display.headerSize + pixelDataSize;
    final bmp = Uint8List(fileSize);
    final data = ByteData.view(bmp.buffer);

    // --- File Header (14 bytes) ---
    bmp[0] = 0x42; // 'B'
    bmp[1] = 0x4D; // 'M'
    data.setUint32(2, fileSize, Endian.little);
    // Reserved (4 bytes at offset 6): already 0
    data.setUint32(
      10,
      G1Display.headerSize,
      Endian.little,
    ); // pixel data offset

    // --- BITMAPINFOHEADER (40 bytes) ---
    data.setUint32(14, 40, Endian.little); // header size
    data.setInt32(18, width, Endian.little);
    data.setInt32(22, height, Endian.little); // positive = bottom-up
    data.setUint16(26, 1, Endian.little); // planes
    data.setUint16(28, 1, Endian.little); // bits per pixel
    // Compression (4 bytes at 30): 0 = BI_RGB (already 0)
    data.setUint32(34, pixelDataSize, Endian.little); // image size
    data.setUint32(38, 0x0b12, Endian.little); // x pixels per meter
    data.setUint32(42, 0x0b12, Endian.little); // y pixels per meter
    // Remaining BITMAPINFOHEADER fields: 0 (ppm, colors, important)

    // --- Color Table (8 bytes: 2 entries x 4 bytes BGRA) ---
    // Index 0: White
    bmp[54] = 0xFF;
    bmp[55] = 0xFF;
    bmp[56] = 0xFF;
    bmp[57] = 0x00;
    // Index 1: Black
    bmp[58] = 0x00;
    bmp[59] = 0x00;
    bmp[60] = 0x00;
    bmp[61] = 0x00;

    // --- Pixel Data ---
    // BMP stores rows bottom-to-top. Each row is `rowBytes` bytes.
    // 8 pixels per byte, MSB first. Start with palette index 1 everywhere
    // so empty areas remain black, then clear bits for white content.
    bmp.fillRange(
      G1Display.headerSize,
      G1Display.headerSize + rowBytes * height,
      0xFF,
    );
    final rgbaBytes = rgba.buffer.asUint8List(
      rgba.offsetInBytes,
      rgba.lengthInBytes,
    );
    for (int y = 0; y < height; y++) {
      // BMP row index: bottom-up
      final bmpRow = height - 1 - y;
      final bmpRowOffset = G1Display.headerSize + bmpRow * rowBytes;
      for (int x = 0; x < width; x++) {
        final rgbaIdx = (y * width + x) * 4;
        final r = rgbaBytes[rgbaIdx];
        final g = rgbaBytes[rgbaIdx + 1];
        final b = rgbaBytes[rgbaIdx + 2];
        final luminance = (r + g + b) ~/ 3;

        if (luminance >= threshold) {
          // Clear bit to select palette index 0 (white).
          final byteIdx = bmpRowOffset + (x >> 3);
          final bitIdx = 7 - (x & 7);
          bmp[byteIdx] &= ~(1 << bitIdx);
        }
      }
    }

    return bmp;
  }
}
