import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_helix/services/bitmap_hud/bitmap_renderer.dart';
import 'package:flutter_helix/services/bitmap_hud/display_constants.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'BitmapRenderer renders Even-compatible BMP dimensions and palette',
    () async {
      final bmp = await BitmapRenderer.render(
        const HudLayout(id: 'empty', name: 'Empty', zones: []),
        const {},
      );

      int u32le(int offset) =>
          ByteData.sublistView(bmp).getUint32(offset, Endian.little);
      int i32le(int offset) =>
          ByteData.sublistView(bmp).getInt32(offset, Endian.little);

      expect(bmp[0], 0x42);
      expect(bmp[1], 0x4d);
      expect(u32le(2), bmp.length);
      expect(u32le(10), 62);
      expect(i32le(18), G1Display.bitmapWidth);
      expect(i32le(22), G1Display.bitmapHeight);
      expect(u32le(34), G1Display.pixelDataSize);
      expect(
        bmp.sublist(54, 62),
        Uint8List.fromList([0xff, 0xff, 0xff, 0x00, 0x00, 0x00, 0x00, 0x00]),
      );
      expect(bmp.sublist(bmp.length - 2), Uint8List.fromList([0x00, 0x00]));
    },
  );
}
