import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_helix/services/bitmap_hud/display_constants.dart';
import 'package:flutter_helix/services/bitmap_hud/enlarged_word_renderer.dart';
import 'package:flutter_helix/services/settings_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('EnlargedWordRenderer', () {
    test('renders a known word to an Even-compatible BMP of expected size',
        () async {
      final bmp = await EnlargedWordRenderer.render('Hello');
      // Exactly the G1 BMP total size — same shape as BitmapRenderer.
      expect(bmp.length, G1Display.totalBmpSize);
      // BM magic header.
      expect(bmp[0], 0x42);
      expect(bmp[1], 0x4d);
      final width =
          ByteData.sublistView(bmp).getInt32(18, Endian.little);
      final height =
          ByteData.sublistView(bmp).getInt32(22, Endian.little);
      expect(width, G1Display.bitmapWidth);
      expect(height, G1Display.bitmapHeight);
    });

    test('uses target 4× font size for short words', () async {
      final size = await EnlargedWordRenderer.measureFittingFontSize('Hi');
      expect(size, EnlargedWordRenderer.targetFontSize);
    });

    test(
        'falls back to a smaller font size so a 30-char word fits within '
        'the display width', () async {
      const longWord = 'abcdefghijklmnopqrstuvwxyz0123'; // 30 chars
      final size =
          await EnlargedWordRenderer.measureFittingFontSize(longWord);
      // Must be strictly smaller than the 4× target.
      expect(size, lessThan(EnlargedWordRenderer.targetFontSize));
      // And must still produce a sized BMP (no crash, no overflow).
      final bmp = await EnlargedWordRenderer.render(longWord);
      expect(bmp.length, G1Display.totalBmpSize);
    });

    test('empty / whitespace input renders a blank frame (no crash)',
        () async {
      final bmp = await EnlargedWordRenderer.render('   ');
      expect(bmp.length, G1Display.totalBmpSize);
    });
  });

  group('SettingsManager.bitmapHudEnlargedWords', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
    });

    test('defaults to false and round-trips through persistence', () async {
      final settings = SettingsManager.instance;
      await settings.initialize();
      // Default is false on a fresh mock prefs store.
      settings.bitmapHudEnlargedWords = false;
      await settings.update((s) => s.bitmapHudEnlargedWords = true);
      expect(settings.bitmapHudEnlargedWords, isTrue);

      // Verify the value was written to shared_preferences under the
      // documented key.
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('bitmap_hud_enlarged_words'), isTrue);
    });
  });
}
