import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_helix/services/hud_stream_session.dart';
import 'package:flutter_helix/services/text_paginator.dart';

class RecordingHudPacketSink implements HudPacketSink {
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

class ManualHudPacketSink implements HudPacketSink {
  final List<Completer<void>> pending = [];
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
  }) {
    calls.add((
      screenStatus: screenStatus,
      pageIndex: pageIndex,
      totalPages: totalPages,
      pageText: pageText,
    ));
    final c = Completer<void>();
    pending.add(c);
    return c.future;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('empty stream finish sends one 0x40 with empty body', () async {
    final sink = RecordingHudPacketSink();
    final session = HudStreamSession(sink: sink);
    await session.finish();
    expect(sink.calls, hasLength(1));
    expect(sink.calls.single.screenStatus, 0x40);
    expect(sink.calls.single.pageText, '');
  });

  test(
    'multi-line streaming produces line-gated emits + final 0x40, monotonic growth',
    () async {
      final sink = RecordingHudPacketSink();
      final session = HudStreamSession(sink: sink);
      const input =
          'The quick brown fox jumps over the lazy dog. '
          'Pack my box with five dozen liquor jugs. '
          'How vexingly quick daft zebras jump today.';
      for (final ch in input.split('')) {
        await session.appendDelta(ch);
      }
      await session.finish();

      // Determine expected line count from the paginator (single source of truth).
      final lines = TextPaginator.instance.splitIntoLines(input);
      expect(
        lines.length,
        greaterThanOrEqualTo(2),
        reason: 'test input should wrap at 488px / 21pt',
      );

      // Streaming emits = lines.length (one per line completion + final-tail flush in finish()).
      // Plus one final 0x40 emit. Token-by-token feeding must NOT produce token-rate emits.
      final streamingCalls = sink.calls
          .where((c) => c.screenStatus != 0x40)
          .toList();
      final finalCalls = sink.calls
          .where((c) => c.screenStatus == 0x40)
          .toList();

      expect(finalCalls, hasLength(1));
      expect(
        streamingCalls.length,
        lessThanOrEqualTo(lines.length + 1),
        reason: 'flushes are line-gated, not token-gated '
            '(one per line + at most one tail flush in finish())',
      );
      expect(
        streamingCalls.length,
        lessThan(input.length),
        reason: 'must be far fewer than per-token rate',
      );

      // First streaming frame on each page must assert NEW_CONTENT;
      // subsequent same-page frames omit it.
      final seenPages = <int>{};
      for (final call in streamingCalls) {
        final isFirstOnPage = seenPages.add(call.pageIndex);
        expect(
          call.screenStatus,
          isFirstOnPage ? 0x01 | 0x30 : 0x30,
        );
      }
      // Monotonic prefix growth within a page (resets at page boundary).
      for (var i = 1; i < streamingCalls.length; i++) {
        if (streamingCalls[i].pageIndex != streamingCalls[i - 1].pageIndex) {
          continue;
        }
        expect(
          streamingCalls[i].pageText.startsWith(streamingCalls[i - 1].pageText),
          isTrue,
          reason: 'page text must grow as prefix-extension within a page',
        );
      }
    },
  );

  test('final 0x40 frame pageText equals TextPaginator last page (tail-included)',
      () async {
    final sink = RecordingHudPacketSink();
    final session = HudStreamSession(sink: sink);
    const input =
        'Some multi-line answer text that wraps across several visual rows '
        'at 488 pixels by 21 point and finishes on a partial line.';
    for (final ch in input.split('')) {
      await session.appendDelta(ch);
    }
    await session.finish();
    TextPaginator.instance.paginateText(input);
    final pages = <String>[];
    for (var i = 0; i < TextPaginator.instance.pageCount; i++) {
      TextPaginator.instance.goToPage(i);
      pages.add(TextPaginator.instance.currentPageText);
    }
    // The trailing partial line lives ONLY on the final 0x40 frame — streaming
    // frames are committed-line-only (Tier-0 contract).
    final finalCall = sink.calls.lastWhere((c) => c.screenStatus == 0x40);
    expect(finalCall.pageText, pages.last);
  });

  test('streaming frames never include the in-flight (partial) tail line',
      () async {
    final sink = RecordingHudPacketSink();
    final session = HudStreamSession(sink: sink);
    const input =
        'The quick brown fox jumps over the lazy dog. '
        'Pack my box with five dozen liquor jugs. '
        'How vexingly quick daft zebras jump today and tomorrow.';
    for (final ch in input.split('')) {
      await session.appendDelta(ch);
    }
    await session.finish();

    // Every streaming frame's pageText must be a sequence of fully-completed
    // visual lines per the paginator. Re-wrap the streaming pageText and
    // verify nothing is "in progress".
    final streamingCalls =
        sink.calls.where((c) => c.screenStatus != 0x40).toList();
    for (final call in streamingCalls) {
      // pageText is a join of committed lines with '\n'. Each segment must
      // be a complete wrapped line on its own (i.e. re-wrapping it returns
      // a single entry).
      for (final segment in call.pageText.split('\n')) {
        if (segment.isEmpty) continue;
        final rewrapped = TextPaginator.instance.splitIntoLines(segment);
        expect(rewrapped.length, 1,
            reason: 'streaming pageText must contain only completed visual '
                'lines; "$segment" wrapped to ${rewrapped.length} lines');
      }
    }
  });

  test('page boundary: 7 wrapped lines yields page 0 then page 1', () async {
    // Build an input that wraps to exactly 7 lines.
    final unit =
        'aaaa bbbb cccc dddd eeee ffff gggg hhhh iiii jjjj kkkk llll mmmm nnnn oooo';
    var input = unit;
    while (TextPaginator.instance.splitIntoLines(input).length < 7) {
      input = '$input $unit';
    }
    // Trim back to exactly 7 if we overshot — keep adding/removing words.
    while (TextPaginator.instance.splitIntoLines(input).length > 7) {
      final words = input.split(' ');
      words.removeLast();
      input = words.join(' ');
    }
    expect(TextPaginator.instance.splitIntoLines(input).length, 7);

    final sink = RecordingHudPacketSink();
    final session = HudStreamSession(sink: sink);
    for (final ch in input.split('')) {
      await session.appendDelta(ch);
    }
    await session.finish();

    final page0 = sink.calls.where((c) => c.pageIndex == 0).toList();
    final page1 = sink.calls.where((c) => c.pageIndex == 1).toList();
    expect(page0, isNotEmpty);
    expect(page1, isNotEmpty);

    expect(page0.first.screenStatus, 0x01 | 0x30);
    expect(page1.first.screenStatus, 0x01 | 0x30);

    // Final 0x40 lands on page 1 with totalPages 2.
    final finalCall = sink.calls.lastWhere((c) => c.screenStatus == 0x40);
    expect(finalCall.pageIndex, 1);
    expect(finalCall.totalPages, 2);
  });

  test('cancel mid-stream emits no 0x40 and ignores subsequent appends',
      () async {
    final sink = RecordingHudPacketSink();
    final session = HudStreamSession(sink: sink);
    const seed = 'Some text that wraps across at least two visual lines '
        'at 488 pixels by 21 point font size for sure.';
    for (final ch in seed.split('')) {
      await session.appendDelta(ch);
    }
    final beforeCancel = sink.calls.length;
    await session.cancel();
    await session.appendDelta(' more text after cancel');
    await session.finish();
    expect(sink.calls.length, beforeCancel);
    expect(sink.calls.where((c) => c.screenStatus == 0x40), isEmpty);
  });

  test('long unbroken token holds in pending tail until finish', () async {
    final sink = RecordingHudPacketSink();
    final session = HudStreamSession(sink: sink);
    final longRun = 'a' * 100;
    await session.appendDelta(longRun);
    // No streaming emit yet — single oversized "word" is one wrapped line.
    expect(sink.calls.where((c) => c.screenStatus != 0x40), isEmpty);
    await session.finish();
    // Finish flushes the tail then emits 0x40.
    expect(sink.calls.last.screenStatus, 0x40);
    expect(sink.calls.last.pageText.contains(longRun), isTrue);
  });

  test('backpressure: serialized emits, no concurrent in-flight sends',
      () async {
    final sink = ManualHudPacketSink();
    final session = HudStreamSession(sink: sink);
    // Feed 30 single-char tokens fast without awaiting; each appendDelta
    // returns a Future that suspends inside _emitStreaming once the sink call
    // is in flight.
    final futures = <Future<void>>[];
    for (var i = 0; i < 30; i++) {
      futures.add(session.appendDelta('a '));
    }
    // Allow microtasks to drain so the first sink.send is registered.
    for (var step = 0; step < 200; step++) {
      await Future<void>.delayed(Duration.zero);
      if (sink.pending.isEmpty) break;
      // Single-slot queue: never more than one in-flight at a time.
      expect(sink.pending.length, lessThanOrEqualTo(1));
      sink.pending.removeAt(0).complete();
    }
    await Future.wait(futures);
    final finishFuture = session.finish();
    for (var step = 0; step < 50; step++) {
      await Future<void>.delayed(Duration.zero);
      if (sink.pending.isEmpty) break;
      expect(sink.pending.length, lessThanOrEqualTo(1));
      sink.pending.removeAt(0).complete();
    }
    await finishFuture;
    expect(sink.calls.last.screenStatus, 0x40);
  });

  test('ProtoHudPacketSink implements HudPacketSink', () {
    expect(const ProtoHudPacketSink(), isA<HudPacketSink>());
  });
}
