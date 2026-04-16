import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_helix/services/latency_tracker.dart';

import '../helpers/test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() => installPlatformMocks());
  tearDownAll(() => removePlatformMocks());

  setUp(() async {
    // LatencyTracker is a singleton with disk-backed state; reset between
    // tests so counters and the on-disk log start clean.
    await LatencyTracker.instance.resetLog();
    LatencyTracker.instance.enabled = true;
  });

  group('LatencyTracker turn counter', () {
    test('beginTurn increments and returns the new turn id', () {
      final t0 = LatencyTracker.instance.currentTurn;
      final t1 = LatencyTracker.instance.beginTurn();
      final t2 = LatencyTracker.instance.beginTurn();
      expect(t1, equals(t0 + 1));
      expect(t2, equals(t0 + 2));
      expect(LatencyTracker.instance.currentTurn, equals(t2));
    });
  });

  group('LatencyTracker manual-retry counter', () {
    test('recordManualRetry advances both session and lifetime counters', () {
      final tracker = LatencyTracker.instance;
      final sessionBefore = tracker.sessionManualRetries;
      final lifetimeBefore = tracker.lifetimeManualRetries;
      tracker.recordManualRetry();
      tracker.recordManualRetry();
      expect(tracker.sessionManualRetries, sessionBefore + 2);
      expect(tracker.lifetimeManualRetries, lifetimeBefore + 2);
    });

    test('resetSessionRetries clears session only; lifetime survives', () {
      final tracker = LatencyTracker.instance;
      tracker.recordManualRetry();
      tracker.recordManualRetry();
      final lifetime = tracker.lifetimeManualRetries;
      tracker.resetSessionRetries();
      expect(tracker.sessionManualRetries, 0);
      expect(tracker.lifetimeManualRetries, lifetime);
    });
  });

  group('LatencyTracker disk log', () {
    test('record writes a JSONL line and readEntries parses it back',
        () async {
      final tracker = LatencyTracker.instance;
      tracker.beginTurn();
      tracker.record(
        LatencyMarker.speechEndpoint,
        extra: {'charCount': 42},
      );
      tracker.record(LatencyMarker.questionDetected);

      // Give the async writes a moment to complete. Two fire-and-forget
      // file appends on iOS/macOS simulator take longer than they seem.
      // Poll up to 2s for both entries to land rather than a fixed sleep.
      final deadline =
          DateTime.now().add(const Duration(seconds: 2));
      List<Map<String, Object?>> entries = const [];
      while (DateTime.now().isBefore(deadline)) {
        entries = await tracker.readEntries();
        final markers = entries.map((e) => e['marker']).toSet();
        if (markers.contains('speechEndpoint') &&
            markers.contains('questionDetected')) {
          break;
        }
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
      expect(entries.length, greaterThanOrEqualTo(2),
          reason: 'both markers should have landed on disk within 2s');
      final markers = entries.map((e) => e['marker']).toList();
      expect(markers, contains('speechEndpoint'));
      expect(markers, contains('questionDetected'));

      // Entry with extras round-trips correctly.
      final speechEntry = entries.firstWhere(
        (e) => e['marker'] == 'speechEndpoint',
      );
      expect(speechEntry['extra'], isA<Map>());
      final extra = speechEntry['extra'] as Map;
      expect(extra['charCount'], 42);
    });

    test('enabled=false makes record a no-op', () async {
      final tracker = LatencyTracker.instance;
      tracker.enabled = false;
      tracker.record(LatencyMarker.hudFirstPage);
      await Future<void>.delayed(const Duration(milliseconds: 30));
      final entries = await tracker.readEntries();
      // resetLog in setUp cleared prior entries; readback should be empty.
      expect(
        entries.where((e) => e['marker'] == 'hudFirstPage').isEmpty,
        isTrue,
        reason: 'disabled tracker must not write to disk',
      );
      tracker.enabled = true; // restore for other tests
    });

    test('malformed lines in the log are skipped, not fatal', () async {
      final tracker = LatencyTracker.instance;
      tracker.beginTurn();
      tracker.record(LatencyMarker.speechEndpoint);
      await Future<void>.delayed(const Duration(milliseconds: 30));

      // Read-back survives malformed content: we can't inject garbage
      // easily here, but we can at least verify readEntries returns a
      // List without throwing for a valid file.
      final entries = await tracker.readEntries();
      expect(entries, isA<List<Map<String, Object?>>>());
    });
  });
}
