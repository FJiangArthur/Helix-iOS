import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_helix/services/projects/embedding_math.dart';

void main() {
  group('EmbeddingMath', () {
    test('encode/decode round-trips', () {
      final src = Float32List.fromList([1.0, -2.5, 3.25, 0.0]);
      final blob = EmbeddingMath.encodeVector(src);
      expect(blob.lengthInBytes, src.length * 4);
      final round = EmbeddingMath.decodeVector(blob);
      expect(round.length, src.length);
      for (var i = 0; i < src.length; i++) {
        expect(round[i], src[i]);
      }
    });

    test('cosine similarity identical vectors = 1.0', () {
      final a = Float32List.fromList([1, 0, 0]);
      final b = Float32List.fromList([1, 0, 0]);
      expect(EmbeddingMath.cosineSimilarity(a, b), closeTo(1.0, 1e-6));
    });

    test('cosine similarity orthogonal = 0', () {
      final a = Float32List.fromList([1, 0, 0]);
      final b = Float32List.fromList([0, 1, 0]);
      expect(EmbeddingMath.cosineSimilarity(a, b), closeTo(0.0, 1e-6));
    });

    test('cosine similarity opposite = -1', () {
      final a = Float32List.fromList([1, 0]);
      final b = Float32List.fromList([-1, 0]);
      expect(EmbeddingMath.cosineSimilarity(a, b), closeTo(-1.0, 1e-6));
    });

    test('cosine of zero vector is 0 (safe divide)', () {
      final a = Float32List.fromList([0, 0, 0]);
      final b = Float32List.fromList([1, 2, 3]);
      expect(EmbeddingMath.cosineSimilarity(a, b), 0.0);
    });

    test('throws when dimensions mismatch', () {
      final a = Float32List.fromList([1, 2]);
      final b = Float32List.fromList([1, 2, 3]);
      expect(() => EmbeddingMath.cosineSimilarity(a, b),
          throwsA(isA<ArgumentError>()));
    });
  });
}
