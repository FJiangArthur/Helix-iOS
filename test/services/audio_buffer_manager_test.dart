import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_helix/services/audio_buffer_manager.dart';

void main() {
  group('AudioBufferManager', () {
    late AudioBufferManager manager;

    setUp(() {
      manager = AudioBufferManager.instance;
      manager.clear();
    });

    test('starts in non-receiving state', () {
      expect(manager.isReceiving, false);
      expect(manager.isEmpty, true);
      expect(manager.bufferSize, 0);
    });

    test('startReceiving changes state', () {
      manager.startReceiving();

      expect(manager.isReceiving, true);
    });

    test('appendData adds to buffer when receiving', () {
      manager.startReceiving();
      manager.appendData([1, 2, 3, 4]);

      expect(manager.bufferSize, 4);
      expect(manager.isEmpty, false);
      expect(manager.audioBuffer, [1, 2, 3, 4]);
    });

    test('appendData does not add when not receiving', () {
      manager.appendData([1, 2, 3, 4]);

      expect(manager.bufferSize, 0);
      expect(manager.isEmpty, true);
    });

    test('stopReceiving changes state', () {
      manager.startReceiving();
      manager.stopReceiving();

      expect(manager.isReceiving, false);
    });

    test('finalizeAudioData returns Uint8List', () {
      manager.startReceiving();
      manager.appendData([1, 2, 3, 4]);

      final audioData = manager.finalizeAudioData();

      expect(audioData, isA<Uint8List>());
      expect(audioData.length, 4);
      expect(audioData[0], 1);
      expect(audioData[3], 4);
      expect(manager.audioData, isNotNull);
    });

    test('setDuration updates duration', () {
      manager.setDuration(10);

      expect(manager.durationSeconds, 10);
    });

    test('clear resets all state', () {
      manager.startReceiving();
      manager.appendData([1, 2, 3, 4]);
      manager.setDuration(5);

      manager.clear();

      expect(manager.isReceiving, false);
      expect(manager.isEmpty, true);
      expect(manager.bufferSize, 0);
      expect(manager.durationSeconds, 0);
      expect(manager.audioData, null);
    });

    test('audioBuffer returns immutable copy', () {
      manager.startReceiving();
      manager.appendData([1, 2, 3]);

      final buffer = manager.audioBuffer;

      expect(() => buffer.add(4), throwsUnsupportedError);
    });

    test('accumulates multiple appendData calls', () {
      manager.startReceiving();
      manager.appendData([1, 2]);
      manager.appendData([3, 4]);
      manager.appendData([5, 6]);

      expect(manager.bufferSize, 6);
      expect(manager.audioBuffer, [1, 2, 3, 4, 5, 6]);
    });

    test('dispose clears state', () {
      manager.startReceiving();
      manager.appendData([1, 2, 3, 4]);

      manager.dispose();

      expect(manager.isReceiving, false);
      expect(manager.isEmpty, true);
      expect(manager.bufferSize, 0);
    });
  });
}
