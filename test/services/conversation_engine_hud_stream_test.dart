import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_helix/services/conversation_engine.dart';
import 'package:flutter_helix/services/hud_stream_session.dart';
import 'package:flutter_helix/services/settings_manager.dart';
import 'package:flutter_helix/services/text_paginator.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _RecordingSink implements HudPacketSink {
  final List<
    ({int screenStatus, int pageIndex, int totalPages, String pageText})
  >
  calls = [];
  @override
  Future<void> send({
    required int screenStatus,
    required int pageIndex,
    required int totalPages,
    required String pageText,
  }) async {
    calls.add((
      screenStatus: screenStatus,
      pageIndex: pageIndex,
      totalPages: totalPages,
      pageText: pageText,
    ));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SettingsManager.instance.initialize();
    SettingsManager.instance.hudLineStreamingEnabled = true;
    ConversationEngine.instance.debugResetHudStreamSession();
  });

  tearDown(() {
    SettingsManager.instance.hudLineStreamingEnabled = false;
    ConversationEngine.setHudPacketSinkFactoryForTest(null);
    ConversationEngine.instance.debugResetHudStreamSession();
  });

  test(
    'flag-on streaming routes through HudStreamSession (line-gated, not token-gated)',
    () async {
      final sink = _RecordingSink();
      ConversationEngine.setHudPacketSinkFactoryForTest(() => sink);

      const text =
          'The quick brown fox jumps over the lazy dog. '
          'Pack my box with five dozen liquor jugs. '
          'How vexingly quick daft zebras jump today.';

      // Drive incrementally-growing snapshots, mimicking the LLM streaming
      // loop where each tick passes the full accumulated response so far.
      for (var n = 1; n <= text.length; n++) {
        await ConversationEngine.instance.debugStreamToGlasses(
          text.substring(0, n),
          isStreaming: true,
        );
      }
      await ConversationEngine.instance.debugStreamToGlasses(
        text,
        isStreaming: false,
      );

      final lines = TextPaginator.instance.splitIntoLines(text);
      expect(lines.length, greaterThanOrEqualTo(2));

      // One streaming emit per completed line + at most one tail flush in
      // finish(), plus one final 0x40. Crucially: not one per token.
      expect(
        sink.calls.length,
        lessThanOrEqualTo(lines.length + 2),
        reason: 'flush rate must be line-gated, not per token '
            '(${sink.calls.length} sink calls for ${text.length} tokens)',
      );
      expect(sink.calls.length, lessThan(text.length));
      expect(sink.calls.last.screenStatus, 0x40);
    },
  );
}
