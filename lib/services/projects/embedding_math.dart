// ABOUTME: Float32 vector encode/decode and cosine similarity for Project RAG.
// ABOUTME: Stored as little-endian byte blobs; decode returns Float32List view.

import 'dart:math' as math;
import 'dart:typed_data';

class EmbeddingMath {
  /// Encode a Float32List as a Uint8List blob for BLOB storage.
  /// Host-endian; we always encode and decode on-device so a single byte
  /// order is consistent across reads/writes.
  static Uint8List encodeVector(Float32List v) {
    return Uint8List.view(v.buffer, v.offsetInBytes, v.lengthInBytes);
  }

  /// Decode a BLOB back to Float32List. Always copies because the BLOB
  /// returned from Drift may not be aligned for Float32.
  static Float32List decodeVector(Uint8List blob) {
    if (blob.lengthInBytes % 4 != 0) {
      throw ArgumentError(
          'blob length ${blob.lengthInBytes} is not a multiple of 4');
    }
    final copy = Float32List(blob.lengthInBytes ~/ 4);
    final byteView = Uint8List.view(copy.buffer);
    byteView.setRange(0, blob.lengthInBytes, blob);
    return copy;
  }

  /// Cosine similarity: dot(a,b) / (|a| * |b|). Returns 0 for zero vectors.
  static double cosineSimilarity(Float32List a, Float32List b) {
    if (a.length != b.length) {
      throw ArgumentError('length mismatch: ${a.length} vs ${b.length}');
    }
    double dot = 0;
    double na = 0;
    double nb = 0;
    for (var i = 0; i < a.length; i++) {
      final ai = a[i];
      final bi = b[i];
      dot += ai * bi;
      na += ai * ai;
      nb += bi * bi;
    }
    if (na == 0 || nb == 0) return 0.0;
    return dot / (math.sqrt(na) * math.sqrt(nb));
  }
}
