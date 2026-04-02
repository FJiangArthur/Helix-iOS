String formatTranscriptElapsed(
  DateTime timestamp, {
  required DateTime sessionStart,
  bool includePlus = true,
}) {
  var elapsed = timestamp.difference(sessionStart);
  if (elapsed.isNegative) {
    elapsed = Duration.zero;
  }

  final totalSeconds = elapsed.inSeconds;
  final hours = totalSeconds ~/ 3600;
  final minutes = (totalSeconds % 3600) ~/ 60;
  final seconds = totalSeconds % 60;
  final prefix = includePlus ? '+' : '';

  if (hours > 0) {
    return '$prefix${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  return '$prefix${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
}
