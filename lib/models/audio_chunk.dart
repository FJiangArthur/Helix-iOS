import 'dart:typed_data';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'audio_chunk.freezed.dart';

/// Represents a chunk of audio data
/// NOTE: No JSON serialization - audio data is binary, not meant for JSON
@freezed
class AudioChunk with _$AudioChunk {
  const factory AudioChunk({
    required Uint8List data,
    required DateTime timestamp,
    @Default(16000) int sampleRate,
    @Default(1) int channels,
    @Default(16) int bitsPerSample,
  }) = _AudioChunk;

  /// Create from raw bytes
  factory AudioChunk.fromBytes(List<int> bytes) => AudioChunk(
        data: Uint8List.fromList(bytes),
        timestamp: DateTime.now(),
      );

  /// Create empty chunk
  factory AudioChunk.empty() => AudioChunk(
        data: Uint8List(0),
        timestamp: DateTime.now(),
      );
}

/// Extension methods for AudioChunk
extension AudioChunkX on AudioChunk {
  /// Get duration in milliseconds
  int get durationMs {
    if (data.isEmpty) return 0;
    final bytesPerSample = bitsPerSample ~/ 8;
    final totalSamples = data.length ~/ (bytesPerSample * channels);
    return (totalSamples * 1000) ~/ sampleRate;
  }

  /// Check if chunk is empty
  bool get isEmpty => data.isEmpty;

  /// Get size in bytes
  int get sizeBytes => data.length;
}
