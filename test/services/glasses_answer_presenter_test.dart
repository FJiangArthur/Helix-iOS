import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_helix/ble_manager.dart';
import 'package:flutter_helix/services/glasses_answer_presenter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GlassesAnswerPresenter', () {
    setUp(() {
      BleManager.get().debugSetConnectionState(
        leftConnected: true,
        rightConnected: true,
      );
    });

    tearDown(() {
      BleManager.get().debugSetConnectionState(
        leftConnected: false,
        rightConnected: false,
      );
    });

    test('short answers send once', () async {
      final sent = <(String, int, int, bool)>[];
      final presenter = GlassesAnswerPresenter(
        sender: (text, currentWindow, totalWindows, {bool isFinal = false}) async {
          sent.add((text, currentWindow, totalWindows, isFinal));
          return true;
        },
        cadence: Duration.zero,
        initialHold: Duration.zero,
        prepareDelivery: () async {},
        beginTextTransfer: (_) async {},
        resetToIdle: (_) async {},
      );

      await presenter.present('A short answer for the HUD.');

      expect(sent.length, 1);
      expect(sent.single.$2, 1);
      expect(sent.single.$3, 1);
      // A single-window answer is itself the final frame — must latch.
      expect(sent.single.$4, true);
      expect(
        presenter.currentState.status,
        GlassesAnswerDeliveryStatus.delivered,
      );
    });

    test('long answers send overlapping windows in order', () async {
      final sent = <String>[];
      final finals = <bool>[];
      final presenter = GlassesAnswerPresenter(
        sender: (text, currentWindow, totalWindows, {bool isFinal = false}) async {
          sent.add(text);
          finals.add(isFinal);
          return true;
        },
        cadence: Duration.zero,
        initialHold: Duration.zero,
        prepareDelivery: () async {},
        beginTextTransfer: (_) async {},
        resetToIdle: (_) async {},
      );

      final longAnswer = List.generate(
        40,
        (index) => 'Window$index scrolling answer content',
      ).join(' ');
      final expectedWindows = presenter.buildWindows(longAnswer);

      await presenter.present(longAnswer);

      expect(expectedWindows.length, greaterThan(1));
      expect(sent, expectedWindows);
      // Only the last window should be marked final — everything before it
      // must be an intermediate scroll frame.
      expect(finals.last, true);
      expect(finals.sublist(0, finals.length - 1).every((v) => !v), true);
    });

    test('new answers preempt an in-flight delivery', () async {
      final sent = <String>[];
      final completers = <Completer<void>>[];
      Future<void> waitForCompleters(int count) async {
        final deadline = DateTime.now().add(const Duration(milliseconds: 100));
        while (completers.length < count && DateTime.now().isBefore(deadline)) {
          await Future<void>.delayed(Duration.zero);
        }
        expect(completers.length, greaterThanOrEqualTo(count));
      }

      final presenter = GlassesAnswerPresenter(
        sender: (text, currentWindow, totalWindows, {bool isFinal = false}) async {
          sent.add(text);
          final completer = Completer<void>();
          completers.add(completer);
          await completer.future;
          return true;
        },
        cadence: const Duration(milliseconds: 1),
        initialHold: const Duration(milliseconds: 1),
        prepareDelivery: () async {},
        beginTextTransfer: (_) async {},
        resetToIdle: (_) async {},
      );

      final first = presenter.present(
        List.generate(30, (index) => 'First$index scrolling answer').join(' '),
      );
      await waitForCompleters(1);
      final second = presenter.present('Replacement answer.');
      await waitForCompleters(2);

      for (final completer in completers) {
        if (!completer.isCompleted) {
          completer.complete();
        }
      }
      await second;
      await first;

      expect(sent, isNotEmpty);
      expect(
        presenter.currentState.status,
        GlassesAnswerDeliveryStatus.delivered,
      );
      expect(presenter.currentState.answerText, 'Replacement answer.');
    });
  });
}
