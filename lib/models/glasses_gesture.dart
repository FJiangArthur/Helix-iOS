enum GlassesGestureType {
  singlePress,
  doublePress,
  longPressStart,
  longPressEnd,
  fivePress,
}

class GlassesGesture {
  const GlassesGesture({
    required this.type,
    required this.timestamp,
  });

  final GlassesGestureType type;
  final DateTime timestamp;

  @override
  String toString() => 'GlassesGesture($type at $timestamp)';
}
