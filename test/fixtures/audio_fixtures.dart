/// Audio Test Fixtures
///
/// Provides factory methods and fixtures for creating test audio data

import 'dart:typed_data';
import 'package:flutter_helix/models/audio_chunk.dart';

/// Factory for creating test audio chunks
class AudioChunkFactory {
  /// Create an audio chunk with default test values
  static AudioChunk create({
    Uint8List? data,
    DateTime? timestamp,
    int sampleRate = 16000,
    int channels = 1,
    int bitsPerSample = 16,
  }) {
    return AudioChunk(
      data: data ?? Uint8List.fromList(List<int>.filled(1024, 0)),
      timestamp: timestamp ?? DateTime.now(),
      sampleRate: sampleRate,
      channels: channels,
      bitsPerSample: bitsPerSample,
    );
  }

  /// Create an audio chunk with specific duration in milliseconds
  static AudioChunk withDuration({
    required int durationMs,
    int sampleRate = 16000,
    int channels = 1,
    int bitsPerSample = 16,
  }) {
    // Calculate required bytes: (sampleRate * durationMs / 1000) * (bitsPerSample / 8) * channels
    final int samplesNeeded = (sampleRate * durationMs / 1000).round();
    final int bytesPerSample = bitsPerSample ~/ 8;
    final int totalBytes = samplesNeeded * bytesPerSample * channels;

    return AudioChunk(
      data: Uint8List(totalBytes),
      timestamp: DateTime.now(),
      sampleRate: sampleRate,
      channels: channels,
      bitsPerSample: bitsPerSample,
    );
  }

  /// Create a list of audio chunks
  static List<AudioChunk> createList({
    required int count,
    int bytesPerChunk = 1024,
    int sampleRate = 16000,
    Duration? spacing,
  }) {
    final List<AudioChunk> chunks = <AudioChunk>[];
    DateTime baseTime = DateTime.now();

    for (int i = 0; i < count; i++) {
      if (spacing != null) {
        baseTime = baseTime.add(spacing);
      }

      chunks.add(
        AudioChunk(
          data: Uint8List(bytesPerChunk),
          timestamp: baseTime,
          sampleRate: sampleRate,
          channels: 1,
          bitsPerSample: 16,
        ),
      );
    }

    return chunks;
  }

  /// Create audio data with specific pattern (useful for debugging)
  static Uint8List createPatternedData({
    required int bytes,
    int pattern = 0xAA,
  }) {
    return Uint8List.fromList(List<int>.filled(bytes, pattern));
  }

  /// Create audio data simulating silence
  static Uint8List createSilence({required int bytes}) {
    return Uint8List(bytes);
  }

  /// Create audio data simulating noise
  static Uint8List createNoise({required int bytes, int seed = 42}) {
    final List<int> noise = <int>[];
    int random = seed;

    for (int i = 0; i < bytes; i++) {
      // Simple pseudo-random number generator
      random = (random * 1103515245 + 12345) & 0x7fffffff;
      noise.add(random % 256);
    }

    return Uint8List.fromList(noise);
  }
}

/// Common audio test constants
class AudioTestConstants {
  static const int standardSampleRate = 16000;
  static const int highQualitySampleRate = 44100;
  static const int standardBitsPerSample = 16;
  static const int monoChannels = 1;
  static const int stereoChannels = 2;

  // Buffer sizes
  static const int smallBuffer = 1024;
  static const int mediumBuffer = 4096;
  static const int largeBuffer = 16384;

  // Durations
  static const int shortDurationMs = 100;
  static const int mediumDurationMs = 1000;
  static const int longDurationMs = 5000;
}
