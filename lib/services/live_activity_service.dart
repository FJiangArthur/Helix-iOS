import 'dart:async';

import 'package:flutter/foundation.dart';

import '../ble_manager.dart';
import 'conversation_engine.dart';
import 'recording_coordinator.dart';

typedef LiveActivityInvokeMethod =
    Future<void> Function(String method, [dynamic arguments]);

class LiveActivityService {
  static LiveActivityService? _sharedInstance;

  LiveActivityService._({
    required Stream<bool> recordingStateStream,
    required Stream<Duration> durationStream,
    required Stream<EngineStatus> statusStream,
    required Stream<ConversationMode> modeStream,
    required Stream<QuestionDetectionResult> questionDetectionStream,
    required Stream<String> aiResponseStream,
    required LiveActivityInvokeMethod invokeMethod,
    ConversationMode? initialMode,
  }) : _recordingStateStream = recordingStateStream,
       _durationStream = durationStream,
       _statusStream = statusStream,
       _modeStream = modeStream,
       _questionDetectionStream = questionDetectionStream,
       _aiResponseStream = aiResponseStream,
       _invokeMethod = invokeMethod,
       _currentMode = initialMode ?? ConversationMode.general;

  factory LiveActivityService.instance() {
    return _sharedInstance ??= () {
      final engine = ConversationEngine.instance;
      final coordinator = RecordingCoordinator.instance;
      return LiveActivityService._(
        recordingStateStream: coordinator.recordingStateStream,
        durationStream: coordinator.durationStream,
        statusStream: engine.statusStream,
        modeStream: engine.modeStream,
        questionDetectionStream: engine.questionDetectionStream,
        aiResponseStream: engine.aiResponseStream,
        invokeMethod: BleManager.invokeMethod<void>,
        initialMode: engine.mode,
      );
    }();
  }

  @visibleForTesting
  factory LiveActivityService.test({
    required Stream<bool> recordingStateStream,
    required Stream<Duration> durationStream,
    required Stream<EngineStatus> statusStream,
    required Stream<ConversationMode> modeStream,
    required Stream<QuestionDetectionResult> questionDetectionStream,
    required Stream<String> aiResponseStream,
    required LiveActivityInvokeMethod invokeMethod,
    ConversationMode? initialMode,
  }) {
    return LiveActivityService._(
      recordingStateStream: recordingStateStream,
      durationStream: durationStream,
      statusStream: statusStream,
      modeStream: modeStream,
      questionDetectionStream: questionDetectionStream,
      aiResponseStream: aiResponseStream,
      invokeMethod: invokeMethod,
      initialMode: initialMode,
    );
  }

  final Stream<bool> _recordingStateStream;
  final Stream<Duration> _durationStream;
  final Stream<EngineStatus> _statusStream;
  final Stream<ConversationMode> _modeStream;
  final Stream<QuestionDetectionResult> _questionDetectionStream;
  final Stream<String> _aiResponseStream;
  final LiveActivityInvokeMethod _invokeMethod;

  final List<StreamSubscription<dynamic>> _subscriptions = [];

  bool _initialized = false;
  bool _isRecording = false;
  bool _isActivityStarted = false;
  ConversationMode _currentMode = ConversationMode.general;
  EngineStatus _currentStatus = EngineStatus.idle;
  Duration _currentDuration = Duration.zero;
  String _currentQuestion = '';
  String _currentAnswer = '';

  void initialize() {
    if (_initialized) return;
    _initialized = true;

    _subscriptions.addAll([
      _modeStream.listen(_handleModeChanged),
      _recordingStateStream.listen(_handleRecordingStateChanged),
      _durationStream.listen(_handleDurationChanged),
      _statusStream.listen(_handleStatusChanged),
      _questionDetectionStream.listen(_handleQuestionDetected),
      _aiResponseStream.listen(_handleAnswerUpdated),
    ]);
  }

  Future<void> debugDispose() async {
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();
    _initialized = false;
    _isRecording = false;
    _isActivityStarted = false;
    _currentQuestion = '';
    _currentAnswer = '';
    _currentDuration = Duration.zero;
    _currentStatus = EngineStatus.idle;
  }

  void _handleModeChanged(ConversationMode mode) {
    _currentMode = mode;
    if (_isActivityStarted) {
      unawaited(_updateActivity());
    }
  }

  void _handleRecordingStateChanged(bool recording) {
    final wasRecording = _isRecording;
    _isRecording = recording;

    if (recording && !wasRecording) {
      _startActivity();
      return;
    }

    if (!recording && wasRecording) {
      _stopActivity();
    }
  }

  void _handleDurationChanged(Duration duration) {
    _currentDuration = duration;
    if (_isActivityStarted) {
      unawaited(_updateActivity());
    }
  }

  void _handleStatusChanged(EngineStatus status) {
    _currentStatus = status;
    if (_isActivityStarted) {
      unawaited(_updateActivity());
    }
  }

  void _handleQuestionDetected(QuestionDetectionResult detection) {
    _currentQuestion = detection.question.trim();
    _currentAnswer = '';
    if (_isActivityStarted) {
      unawaited(_updateActivity());
    }
  }

  void _handleAnswerUpdated(String answer) {
    final trimmed = answer.trim();
    if (trimmed.isEmpty) return;
    _currentAnswer = trimmed;
    if (_isActivityStarted) {
      unawaited(_updateActivity());
    }
  }

  Future<void> _startActivity() async {
    if (_isActivityStarted) return;
    _isActivityStarted = true;
    _currentQuestion = '';
    _currentAnswer = '';
    await _invokeMethod('startLiveActivity', <String, dynamic>{
      'mode': _currentMode.name,
      'question': _currentQuestion,
      'answer': _currentAnswer,
      'status': _currentStatus.name,
      'duration': _currentDuration.inSeconds,
    });
    await _updateActivity();
  }

  Future<void> _updateActivity() async {
    if (!_isActivityStarted) return;
    await _invokeMethod('updateLiveActivity', <String, dynamic>{
      'mode': _currentMode.name,
      'question': _currentQuestion,
      'answer': _currentAnswer,
      'status': _currentStatus.name,
      'duration': _currentDuration.inSeconds,
    });
  }

  Future<void> _stopActivity() async {
    if (!_isActivityStarted) return;
    _isActivityStarted = false;
    await _invokeMethod('stopLiveActivity');
  }
}
