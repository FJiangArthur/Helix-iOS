import '../services/ble.dart';
import '../services/conversation_engine.dart';
import '../utils/conversation_mode_labels.dart';

class DashboardSnapshot {
  const DashboardSnapshot({
    required this.timestamp,
    required this.connectionState,
    required this.mode,
    required this.engineStatus,
    required this.contextLine,
    this.recordingDuration,
    this.questionCount = 0,
    this.answerCount = 0,
    this.wordCount = 0,
    this.segmentCount = 0,
  });

  static const int lineWidth = 24;

  final DateTime timestamp;
  final BleConnectionState connectionState;
  final ConversationMode mode;
  final EngineStatus engineStatus;
  final String contextLine;
  final Duration? recordingDuration;
  final int questionCount;
  final int answerCount;
  final int wordCount;
  final int segmentCount;

  bool get isInConversation => recordingDuration != null;

  /// Formats conversation stats: `Q:3 A:3  ~450w s:5`
  /// Fits within 24 chars.
  String conversationStatsLine() {
    final qaPart = 'Q:$questionCount A:$answerCount';
    final wordPart = '~${wordCount}w';
    final segPart = segmentCount > 0 ? ' s:$segmentCount' : '';
    final combined = '$qaPart  $wordPart$segPart';
    return _truncate(combined);
  }

  /// Formats time with optional recording duration.
  /// When recording: `09:41  REC 05:23`
  /// When not recording: `09:41`
  String timeWithRecording() {
    final time = _formatTime(timestamp);
    if (recordingDuration == null) {
      return time;
    }
    final dur = recordingDuration!;
    final minutes = dur.inMinutes.toString().padLeft(2, '0');
    final seconds = (dur.inSeconds % 60).toString().padLeft(2, '0');
    return _truncate('$time  REC $minutes:$seconds');
  }

  List<String> get lines {
    if (isInConversation) {
      return [
        _truncate(timeWithRecording()),
        _truncate(_formatDate(timestamp)),
        _truncate(_connectionModeLabel(connectionState, mode)),
        _truncate(conversationStatsLine()),
        _truncate(contextLine),
      ];
    }
    return [
      _truncate(_formatTime(timestamp)),
      _truncate(_formatDate(timestamp)),
      _truncate(_connectionLabel(connectionState)),
      _truncate(
        engineStatus == EngineStatus.idle
            ? 'Tap mic to start'
            : '${_modeLabel(mode)} ${_statusLabel(engineStatus)}',
      ),
      _truncate(contextLine),
    ];
  }

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

  static String _connectionModeLabel(
    BleConnectionState state,
    ConversationMode mode,
  ) {
    final conn = switch (state) {
      BleConnectionState.connected => 'ONLINE',
      BleConnectionState.connecting => 'CONNECTING',
      BleConnectionState.scanning => 'SCANNING',
      BleConnectionState.reconnecting => 'RECONNECTING',
      BleConnectionState.disconnected => 'OFFLINE',
    };
    return '$conn | ${_modeLabel(mode)}';
  }

  static String _modeLabel(ConversationMode mode) {
    return conversationModeLabel(mode, uppercase: true);
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
    final trimmed = value.trim();
    if (trimmed.length <= lineWidth) {
      return trimmed;
    }
    return '${trimmed.substring(0, lineWidth - 3)}...';
  }
}
