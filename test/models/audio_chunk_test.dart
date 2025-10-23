import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_helix/models/audio_chunk.dart';

void main() {
  group('AudioChunk', () {
    test('fromBytes factory creates chunk from raw bytes', () {
      final bytes = [1, 2, 3, 4, 5, 6, 7, 8];
      final chunk = AudioChunk.fromBytes(bytes);

      expect(chunk.data, Uint8List.fromList(bytes));
      expect(chunk.sampleRate, 16000);
      expect(chunk.channels, 1);
      expect(chunk.bitsPerSample, 16);
      expect(chunk.timestamp, isNotNull);
    });

    test('empty factory creates empty chunk', () {
      final chunk = AudioChunk.empty();

      expect(chunk.data.isEmpty, true);
      expect(chunk.isEmpty, true);
      expect(chunk.sizeBytes, 0);
    });

    test('durationMs calculates correct duration', () {
      // 16000 Hz, 16-bit (2 bytes), mono (1 channel)
      // 1 second = 16000 samples = 32000 bytes
      final oneSecondData = Uint8List(32000);
      final chunk = AudioChunk(
        data: oneSecondData,
        timestamp: DateTime.now(),
        sampleRate: 16000,
        channels: 1,
        bitsPerSample: 16,
      );

      expect(chunk.durationMs, 1000);
    });

    test('durationMs returns 0 for empty chunk', () {
      final chunk = AudioChunk.empty();
      expect(chunk.durationMs, 0);
    });

    test('sizeBytes returns correct byte count', () {
      final chunk = AudioChunk.fromBytes(List.filled(1024, 0));
      expect(chunk.sizeBytes, 1024);
    });

    test('isEmpty returns true for empty data', () {
      final empty = AudioChunk.empty();
      final notEmpty = AudioChunk.fromBytes([1, 2, 3]);

      expect(empty.isEmpty, true);
      expect(notEmpty.isEmpty, false);
    });

    test('serializes to JSON correctly', () {
      final chunk = AudioChunk.fromBytes([1, 2, 3, 4]);
      final json = chunk.toJson();

      expect(json['sampleRate'], 16000);
      expect(json['channels'], 1);
      expect(json['bitsPerSample'], 16);
      expect(json['data'], isNotNull);
    });

    test('handles stereo audio correctly', () {
      // Stereo (2 channels), 16-bit, 16000 Hz
      // 1 second = 16000 samples per channel = 64000 bytes total
      final stereoData = Uint8List(64000);
      final chunk = AudioChunk(
        data: stereoData,
        timestamp: DateTime.now(),
        sampleRate: 16000,
        channels: 2,
        bitsPerSample: 16,
      );

      expect(chunk.durationMs, 1000);
      expect(chunk.channels, 2);
    });
  });
}
