enum HudIntent {
  idle,
  quickAsk,
  liveListening,
  textTransfer,
  notification,
}

class HudRouteState {
  const HudRouteState({
    required this.intent,
    required this.source,
    required this.timestamp,
    required this.pushesScreen,
  });

  final HudIntent intent;
  final String source;
  final DateTime timestamp;
  final bool pushesScreen;
}
