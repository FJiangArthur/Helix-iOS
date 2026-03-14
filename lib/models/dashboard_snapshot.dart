import '../services/ble.dart';
import '../services/conversation_engine.dart';

class DashboardSnapshot {
  const DashboardSnapshot({
    required this.timestamp,
    required this.connectionState,
    required this.mode,
    required this.engineStatus,
    required this.contextLine,
  });

  static const int lineWidth = 24;

  final DateTime timestamp;
  final BleConnectionState connectionState;
  final ConversationMode mode;
  final EngineStatus engineStatus;
  final String contextLine;

  List<String> get lines => [
    _truncate(_formatTime(timestamp)),
    _truncate(_formatDate(timestamp)),
    _truncate(_connectionLabel(connectionState)),
    _truncate('${_modeLabel(mode)} ${_statusLabel(engineStatus)}'),
    _truncate(contextLine),
  ];

  String get hudText => lines.join('\n');

  static String _formatTime(DateTime timestamp) {
    final hour = timestamp.hour.toString().padLeft(2, '0');
    final minute = timestamp.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  static String _formatDate(DateTime timestamp) {
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    final weekday = weekdays[timestamp.weekday - 1];
    final month = months[timestamp.month - 1];
    return '$weekday $month ${timestamp.day}';
  }

  static String _connectionLabel(BleConnectionState state) {
    return switch (state) {
      BleConnectionState.connected => 'GLASSES ONLINE',
      BleConnectionState.connecting => 'GLASSES CONNECTING',
      BleConnectionState.scanning => 'GLASSES SCANNING',
      BleConnectionState.reconnecting => 'GLASSES RECONNECTING',
      BleConnectionState.disconnected => 'GLASSES OFFLINE',
    };
  }

  static String _modeLabel(ConversationMode mode) {
    return switch (mode) {
      ConversationMode.general => 'GENERAL',
      ConversationMode.interview => 'INTERVIEW',
      ConversationMode.passive => 'PASSIVE',
    };
  }

  static String _statusLabel(EngineStatus status) {
    return switch (status) {
      EngineStatus.idle => 'READY',
      EngineStatus.listening => 'LISTENING',
      EngineStatus.thinking => 'THINKING',
      EngineStatus.responding => 'RESPONDING',
      EngineStatus.error => 'ERROR',
    };
  }

  static String _truncate(String value) {
    final normalized = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.length <= lineWidth) {
      return normalized;
    }
    return '${normalized.substring(0, lineWidth - 3)}...';
  }
}
