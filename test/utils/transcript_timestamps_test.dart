import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_helix/utils/transcript_timestamps.dart';

void main() {
  test('formats elapsed transcript timestamps in minutes and seconds', () {
    final sessionStart = DateTime(2026, 1, 1, 9, 0, 0);

    expect(
      formatTranscriptElapsed(
        sessionStart.add(const Duration(seconds: 5)),
        sessionStart: sessionStart,
      ),
      '+00:05',
    );
  });

  test('clamps negative elapsed transcript timestamps to zero', () {
    final sessionStart = DateTime(2026, 1, 1, 9, 0, 10);

    expect(
      formatTranscriptElapsed(
        sessionStart.subtract(const Duration(seconds: 5)),
        sessionStart: sessionStart,
      ),
      '+00:00',
    );
  });
}
