import 'dart:typed_data';

/// Computes which BMP chunks have changed between two frames, enabling
/// incremental BLE updates instead of full-frame sends.
class DeltaEncoder {
  DeltaEncoder._();

  static const int chunkSize = 194;

  /// Compare [oldBmp] and [newBmp] and return indices of chunks that differ.
  ///
  /// Both must be the same length (complete BMP files). Compares chunk-aligned
  /// segments of [chunkSize] bytes.
  static List<int> diff(Uint8List oldBmp, Uint8List newBmp) {
    if (oldBmp.length != newBmp.length) {
      throw ArgumentError(
          'BMP size mismatch: old=${oldBmp.length}, new=${newBmp.length}');
    }

    final totalChunks = (newBmp.length + chunkSize - 1) ~/ chunkSize;
    final changed = <int>[];

    for (int i = 0; i < totalChunks; i++) {
      final start = i * chunkSize;
      final end =
          (start + chunkSize > newBmp.length) ? newBmp.length : start + chunkSize;

      bool differs = false;
      for (int j = start; j < end; j++) {
        if (oldBmp[j] != newBmp[j]) {
          differs = true;
          break;
        }
      }

      if (differs) {
        changed.add(i);
      }
    }

    return changed;
  }

  /// Extract specific chunks from [bmpData] by their indices.
  ///
  /// Returns a list of (chunkIndex, chunkBytes) pairs ready for BLE transmission.
  static List<DeltaChunk> extractChunks(
      Uint8List bmpData, List<int> indices) {
    final chunks = <DeltaChunk>[];
    for (final i in indices) {
      final start = i * chunkSize;
      final end = (start + chunkSize > bmpData.length)
          ? bmpData.length
          : start + chunkSize;
      chunks.add(DeltaChunk(index: i, data: bmpData.sublist(start, end)));
    }
    return chunks;
  }

  /// Compute the percentage of chunks that changed (0.0 to 1.0).
  static double changeRatio(Uint8List oldBmp, Uint8List newBmp) {
    final totalChunks = (newBmp.length + chunkSize - 1) ~/ chunkSize;
    final changed = diff(oldBmp, newBmp);
    return totalChunks > 0 ? changed.length / totalChunks : 0.0;
  }
}

/// A single changed chunk with its index and data bytes.
class DeltaChunk {
  final int index;
  final Uint8List data;

  const DeltaChunk({required this.index, required this.data});
}
