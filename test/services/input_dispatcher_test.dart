// input_dispatcher_test.dart
//
// WS-F: Unit tests for the ring-remote InputDispatcher pipeline.
//
// Covers:
//   - Signature canonicalisation for all 4 channels
//   - Primary debounce (Rule 1)
//   - Phase filter (Rule 2)
//   - Volume coalescing (Rule 3)
//   - Hold suppression (Rule 4)
//   - Session guard / unbound behaviour

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_helix/services/input_dispatcher.dart';
import 'package:flutter_helix/services/settings_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('canonicalSignatureFromEvent', () {
    test('keyCommand with modifier', () {
      expect(
        canonicalSignatureFromEvent({
          'channel': 'keyCommand',
          'input': 'a',
          'modifierFlags': 0,
        }),
        'keyCommand:a:0',
      );
      expect(
        canonicalSignatureFromEvent({
          'channel': 'keyCommand',
          'input': 'b',
          'modifierFlags': 131072,
        }),
        'keyCommand:b:131072',
      );
    });

    test('pressEvent began phase only', () {
      expect(
        canonicalSignatureFromEvent({
          'channel': 'pressEvent',
          'phase': 'began',
          'keyCode': 42,
        }),
        'pressEvent:42',
      );
      expect(
        canonicalSignatureFromEvent({
          'channel': 'pressEvent',
          'phase': 'ended',
          'keyCode': 42,
        }),
        isNull,
      );
    });

    test('mediaCommand', () {
      expect(
        canonicalSignatureFromEvent({
          'channel': 'mediaCommand',
          'command': 'togglePlayPause',
        }),
        'mediaCommand:togglePlayPause',
      );
    });

    test('volumeChange direction', () {
      expect(
        canonicalSignatureFromEvent({
          'channel': 'volumeChange',
          'direction': 'up',
        }),
        'volumeChange:up',
      );
      expect(
        canonicalSignatureFromEvent({
          'channel': 'volumeChange',
          'direction': 'same',
        }),
        isNull,
      );
    });

    test('unknown channel returns null', () {
      expect(
        canonicalSignatureFromEvent({'channel': 'random'}),
        isNull,
      );
    });
  });

  group('InputDispatcher pipeline', () {
    late InputDispatcher dispatcher;
    late int dispatchCount;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await SettingsManager.instance.initialize();
      await SettingsManager.instance.setRingBindingSignature('keyCommand:a:0');

      dispatchCount = 0;
      dispatcher = InputDispatcher.forTesting(
        methodChannel: const MethodChannel('test.method.input_inspector'),
        eventChannel: const EventChannel('test.event.input_inspector'),
        onDispatch: () async {
          dispatchCount++;
        },
      );
      dispatcher.debugSetBinding('keyCommand:a:0');
    });

    test('matching signature triggers dispatch', () async {
      await dispatcher.debugInject({
        'channel': 'keyCommand',
        'input': 'a',
        'modifierFlags': 0,
      });
      expect(dispatchCount, 1);
    });

    test('non-matching signature does not dispatch', () async {
      await dispatcher.debugInject({
        'channel': 'keyCommand',
        'input': 'b',
        'modifierFlags': 0,
      });
      expect(dispatchCount, 0);
    });

    test('unbound dispatcher is inert', () async {
      dispatcher.debugSetBinding(null);
      await dispatcher.debugInject({
        'channel': 'keyCommand',
        'input': 'a',
        'modifierFlags': 0,
      });
      expect(dispatchCount, 0);
    });

    test('primary debounce drops rapid second edge', () async {
      await dispatcher.debugInject({
        'channel': 'keyCommand',
        'input': 'a',
        'modifierFlags': 0,
      });
      await dispatcher.debugInject({
        'channel': 'keyCommand',
        'input': 'a',
        'modifierFlags': 0,
      });
      expect(dispatchCount, 1);
      expect(dispatcher.debouncedCount, greaterThanOrEqualTo(1));
    });

    test('debounce lifts after window', () async {
      await dispatcher.debugInject({
        'channel': 'keyCommand',
        'input': 'a',
        'modifierFlags': 0,
      });
      await Future<void>.delayed(
          InputDispatcher.kPrimaryDebounce + const Duration(milliseconds: 50));
      await dispatcher.debugInject({
        'channel': 'keyCommand',
        'input': 'a',
        'modifierFlags': 0,
      });
      expect(dispatchCount, 2);
    });

    test('phase filter drops non-began pressEvent', () async {
      dispatcher.debugSetBinding('pressEvent:42');
      await dispatcher.debugInject({
        'channel': 'pressEvent',
        'phase': 'ended',
        'keyCode': 42,
      });
      expect(dispatchCount, 0);
    });

    test('volume coalesces with recent non-volume', () async {
      dispatcher.debugSetBinding('volumeChange:up');
      await dispatcher.debugInject({
        'channel': 'keyCommand',
        'input': 'z',
        'modifierFlags': 0,
      });
      await dispatcher.debugInject({
        'channel': 'volumeChange',
        'direction': 'up',
      });
      expect(dispatchCount, 0);
      expect(dispatcher.coalescedVolumeCount, 1);
    });

    test('hold suppression kicks in after threshold', () async {
      // Loosen debounce by directly invoking with no interval — rule 4
      // should suppress repeats before rule 1 even applies because they
      // share a signature within the hold window. We just assert only one
      // dispatch occurs.
      for (var i = 0; i < 6; i++) {
        await dispatcher.debugInject({
          'channel': 'keyCommand',
          'input': 'a',
          'modifierFlags': 0,
        });
      }
      expect(dispatchCount, 1);
    });
  });
}
