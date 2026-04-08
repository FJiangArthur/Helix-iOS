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
    Future<void> Function()? onAskQuestion,
    Future<void> Function()? onPause,
    Future<void> Function()? onResume,
  }) : _recordingStateStream = recordingStateStream,
       _durationStream = durationStream,
       _statusStream = statusStream,
       _modeStream = modeStream,
       _questionDetectionStream = questionDetectionStream,
       _aiResponseStream = aiResponseStream,
       _invokeMethod = invokeMethod,
       _onAskQuestion = onAskQuestion,
       _onPause = onPause,
       _onResume = onResume,
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
        onAskQuestion: () => engine.handleQAButtonPressed(),
        onPause: () async => coordinator.pauseTranscription(),
        onResume: () async => coordinator.resumeTranscription(),
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
    Future<void> Function()? onAskQuestion,
    Future<void> Function()? onPause,
    Future<void> Function()? onResume,
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
      onAskQuestion: onAskQuestion,
      onPause: onPause,
      onResume: onResume,
    );
  }

  final Stream<bool> _recordingStateStream;
  final Stream<Duration> _durationStream;
  final Stream<EngineStatus> _statusStream;
  final Stream<ConversationMode> _modeStream;
  final Stream<QuestionDetectionResult> _questionDetectionStream;
  final Stream<String> _aiResponseStream;
  final LiveActivityInvokeMethod _invokeMethod;
  final Future<void> Function()? _onAskQuestion;
  final Future<void> Function()? _onPause;
  final Future<void> Function()? _onResume;

  final List<StreamSubscription<dynamic>> _subscriptions = [];

  bool _initialized = false;
  bool _isRecording = false;
  bool _isActivityStarted = false;
  bool _isPaused = false;
  ConversationMode _currentMode = ConversationMode.general;
  EngineStatus _currentStatus = EngineStatus.idle;
  String _currentQuestion = '';
  String _currentAnswer = '';
  // TODO(plan-A): remove shim once feat/2026-04-06-priority-rework Phase 1a
  // lands and merges. Tracks the priority of the most recent question event
  // so that auto-detected answers stay off the Live Activity surface.
  QuestionPriority? _lastQuestionPriority;

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

    BleManager.setLiveActivityCallHandler(_handleNativeButton);
  }

  void _handleNativeButton(String buttonId) {
    switch (buttonId) {
      case 'askQuestion':
        unawaited(_onAskQuestion?.call() ?? Future<void>.value());
        break;
      case 'pauseTranscription':
        _isPaused = true;
        unawaited(_onPause?.call() ?? Future<void>.value());
        if (_isActivityStarted) {
          unawaited(_updateActivity());
        }
        break;
      case 'resumeTranscription':
        _isPaused = false;
        unawaited(_onResume?.call() ?? Future<void>.value());
        if (_isActivityStarted) {
          unawaited(_updateActivity());
        }
        break;
    }
  }

  @visibleForTesting
  void debugDispatchNativeButton(String buttonId) =>
      _handleNativeButton(buttonId);

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
    _currentStatus = EngineStatus.idle;
    _isPaused = false;
    _lastQuestionPriority = null;
  }

  void _handleModeChanged(ConversationMode mode) async {
    final previous = _currentMode;
    _currentMode = mode;
    // ActivityAttributes.mode is immutable after activity start; restart so
    // the new mode banner / icon takes effect.
    if (_isActivityStarted && previous != mode) {
      await _stopActivity();
      await _startActivity();
      return;
    }
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
    // No-op. The Live Activity widget renders elapsed time locally via
    // `Text(timerInterval:)` off the immutable `startedAt` attribute, so
    // duration ticks do NOT need to be forwarded to ActivityKit at all.
    // Previously we whole-second-gated this path (Tier-1 thermal fix), but
    // on-device profiling showed the residual 1 Hz updateActivity storm
    // still drove chronod + runningboardd + widget-extension wakeups every
    // second during recording. Dropping the forward entirely kills the
    // storm — the timer updates with zero app-side wakeups. The duration
    // stream subscription is kept so tests that pump events through it
    // (and any future consumer) continue to work.
  }

  void _handleStatusChanged(EngineStatus status) {
    _currentStatus = status;
    if (_isActivityStarted) {
      unawaited(_updateActivity());
    }
  }

  void _handleQuestionDetected(QuestionDetectionResult detection) {
    // TODO(plan-A): remove shim once feat/2026-04-06-priority-rework Phase 1a
    // lands and merges. Auto-detected questions never reach the Live Activity.
    _lastQuestionPriority = detection.priority;
    if (detection.priority == QuestionPriority.autoDetected) {
      return;
    }
    _currentQuestion = detection.question.trim();
    _currentAnswer = '';
    if (_isActivityStarted) {
      unawaited(_updateActivity());
    }
  }

  void _handleAnswerUpdated(String answer) {
    // Gate answers on the priority of the most recent question. If we never
    // saw a non-auto question, suppress.
    if (_lastQuestionPriority == null ||
        _lastQuestionPriority == QuestionPriority.autoDetected) {
      return;
    }
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
    });
    await _updateActivity();
  }

  Future<void> _updateActivity() async {
    if (!_isActivityStarted) return;
    final statusPayload = _isPaused ? 'paused' : _currentStatus.name;
    await _invokeMethod('updateLiveActivity', <String, dynamic>{
      'mode': _currentMode.name,
      'question': _currentQuestion,
      'answer': _currentAnswer,
      'status': statusPayload,
    });
  }

  Future<void> _stopActivity() async {
    if (!_isActivityStarted) return;
    _isActivityStarted = false;
    await _invokeMethod('stopLiveActivity');
  }
}
