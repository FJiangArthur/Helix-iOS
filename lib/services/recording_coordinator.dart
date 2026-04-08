// ABOUTME: Unified recording coordinator that manages both conversation
// ABOUTME: listening (transcription) and audio file recording in a single toggle.
// ABOUTME: Supports multiple recording modes: conversation, voiceNote, walkieTalkieChat.

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../ble_manager.dart';
import '../models/audio_configuration.dart';
import '../utils/app_logger.dart';
import 'audio_service.dart';
import 'conversation_engine.dart';
import 'conversation_listening_session.dart';
import 'evenai.dart';
import 'implementations/audio_service_impl.dart';
import 'passive_listening_service.dart';
import 'settings_manager.dart';
import 'voice_note_service.dart';

/// The type of recording session.
enum RecordingMode {
  /// Full ConversationEngine pipeline (transcription + AI processing).
  conversation,

  /// Short capture, transcribe only (voice memo).
  voiceNote,

  /// Push-to-talk AI chat.
  walkieTalkieChat,
}

/// The capture path currently available for an active recording.
enum RecordingCaptureState { idle, transcribing, audioOnly }

typedef RecordingAudioServiceFactory = AudioService Function();
typedef RecordingStartTranscription =
    Future<void> Function({
      required TranscriptSource source,
      required RecordingMode mode,
      required bool useGlasses,
    });
typedef RecordingStopTranscription =
    Future<void> Function({required bool startedViaEvenAI});

/// Singleton that coordinates recording across both the conversation
/// listening session (transcription) and the audio file recorder.
///
/// Consumers subscribe to [recordingStateStream], [captureStateStream],
/// and [durationStream] instead of managing their own recording state.
class RecordingCoordinator {
  RecordingCoordinator._({
    RecordingAudioServiceFactory? audioServiceFactory,
    RecordingStartTranscription? startTranscription,
    RecordingStopTranscription? stopTranscription,
    Stream<String?>? listeningErrors,
  }) : _audioServiceFactory = audioServiceFactory ?? AudioServiceImpl.new,
       _startTranscription = startTranscription ?? _defaultStartTranscription,
       _stopTranscription = stopTranscription ?? _defaultStopTranscription {
    _listeningErrorSubscription =
        (listeningErrors ?? ConversationListeningSession.instance.errorStream)
            .listen(_handleListeningError);
  }

  static RecordingCoordinator? _instance;
  static RecordingCoordinator get instance =>
      _instance ??= RecordingCoordinator._();

  @visibleForTesting
  factory RecordingCoordinator.test({
    required RecordingAudioServiceFactory audioServiceFactory,
    required RecordingStartTranscription startTranscription,
    required RecordingStopTranscription stopTranscription,
    required Stream<String?> listeningErrors,
  }) {
    return RecordingCoordinator._(
      audioServiceFactory: audioServiceFactory,
      startTranscription: startTranscription,
      stopTranscription: stopTranscription,
      listeningErrors: listeningErrors,
    );
  }

  // ── State ──────────────────────────────────────────────────────────

  final ValueNotifier<bool> isRecording = ValueNotifier<bool>(false);
  final ValueNotifier<RecordingCaptureState> captureState =
      ValueNotifier<RecordingCaptureState>(RecordingCaptureState.idle);

  /// The active recording mode, or null when not recording.
  RecordingMode? _currentMode;

  final StreamController<bool> _recordingStateController =
      StreamController<bool>.broadcast();
  final StreamController<RecordingCaptureState> _captureStateController =
      StreamController<RecordingCaptureState>.broadcast();
  final StreamController<Duration> _durationController =
      StreamController<Duration>.broadcast();

  Stream<bool> get recordingStateStream => _recordingStateController.stream;
  Stream<RecordingCaptureState> get captureStateStream =>
      _captureStateController.stream;
  Stream<Duration> get durationStream => _durationController.stream;

  String? _lastAudioFilePath;
  String? get lastAudioFilePath => _lastAudioFilePath;
  RecordingCaptureState get currentCaptureState => captureState.value;

  final RecordingAudioServiceFactory _audioServiceFactory;
  final RecordingStartTranscription _startTranscription;
  final RecordingStopTranscription _stopTranscription;
  late final StreamSubscription<String?> _listeningErrorSubscription;

  AudioService? _audioService;
  bool _audioInitialized = false;
  StreamSubscription<Duration>? _durationSubscription;
  Timer? _fallbackDurationTimer;
  DateTime? _recordingStartTime;
  bool _startedViaEvenAI = false;

  // ── Public API ─────────────────────────────────────────────────────

  /// The active recording mode, or null when not recording.
  RecordingMode? get currentMode => _currentMode;

  /// Toggle recording on/off using [RecordingMode.conversation] (default).
  ///
  /// When starting, audio file capture is treated as the durable path.
  /// Live transcription is best-effort and may downgrade to audio-only.
  /// When stopping, both paths are stopped and the audio file path is returned.
  Future<String?> toggleRecording({
    required TranscriptSource source,
    RecordingMode mode = RecordingMode.conversation,
  }) async {
    if (isRecording.value) {
      return _stopAll();
    }

    await _startAll(source: source, mode: mode);
    return null;
  }

  /// Pause the active transcription stream without tearing down the
  /// recording session. Used by the Live Activity Pause button.
  void pauseTranscription() {
    ConversationListeningSession.instance.pauseTranscription();
  }

  /// Resume the transcription stream after [pauseTranscription].
  void resumeTranscription() {
    ConversationListeningSession.instance.resumeTranscription();
  }

  /// Start a voice note recording session.
  ///
  /// Uses [RecordingMode.voiceNote] — transcription only, no full pipeline.
  Future<void> startVoiceNote({
    TranscriptSource source = TranscriptSource.glasses,
  }) async {
    if (isRecording.value) return;
    await VoiceNoteService.instance.startRecording();
    await _startAll(source: source, mode: RecordingMode.voiceNote);
  }

  /// Stop the current voice note recording session.
  Future<String?> stopVoiceNote() async {
    if (!isRecording.value || _currentMode != RecordingMode.voiceNote) {
      return null;
    }
    await VoiceNoteService.instance.stopRecording();
    return _stopAll();
  }

  // ── Internals ──────────────────────────────────────────────────────

  Future<void> _ensureAudioInitialized() async {
    if (_audioInitialized) return;

    try {
      final service = _audioServiceFactory();
      _audioService = service;

      final config = AudioConfiguration.speechRecognition();
      await service.initialize(config);

      final hasPermission = await service.requestPermission();
      if (!hasPermission) {
        _audioService = null;
        appLogger.w(
          '[RecordingCoordinator] Microphone permission denied for audio recording — skipping file recorder',
        );
        return;
      }

      _audioInitialized = true;
    } catch (e) {
      appLogger.e('[RecordingCoordinator] Failed to init audio service: $e');
    }
  }

  Future<void> _startAll({
    required TranscriptSource source,
    RecordingMode mode = RecordingMode.conversation,
  }) async {
    PassiveListeningService.instance.pause();

    _currentMode = mode;
    _lastAudioFilePath = null;

    var audioRecordingStarted = false;
    try {
      await _ensureAudioInitialized();
      if (_audioInitialized && _audioService != null) {
        await _audioService!.startRecording();
        audioRecordingStarted = _audioService!.isRecording;
        if (audioRecordingStarted) {
          _durationSubscription = _audioService!.durationStream.listen((d) {
            _durationController.add(d);
          });
        }
      }
    } catch (e) {
      appLogger.e(
        '[RecordingCoordinator] Audio file recording failed to start: $e',
      );
    }

    if (!audioRecordingStarted) {
      _recordingStartTime = DateTime.now();
      _fallbackDurationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (_recordingStartTime != null) {
          _durationController.add(
            DateTime.now().difference(_recordingStartTime!),
          );
        }
      });
    }

    final settings = SettingsManager.instance;
    final useGlasses = switch (settings.preferredMicSource) {
      'phone' => false,
      _ => BleManager.isBothConnected(),
    };

    appLogger.d(
      '[RecordingCoordinator] micPref=${settings.preferredMicSource} '
      'bleConnected=${BleManager.isBothConnected()} '
      'useGlasses=$useGlasses source=$source mode=$mode',
    );

    var transcriptionStarted = false;
    try {
      await _startTranscription(
        source: source,
        mode: mode,
        useGlasses: useGlasses,
      );
      _startedViaEvenAI = useGlasses;
      transcriptionStarted = true;
    } catch (e) {
      _startedViaEvenAI = false;
      if (!audioRecordingStarted) {
        _cleanupFailedStartAttempt();
        rethrow;
      }
      appLogger.w(
        '[RecordingCoordinator] Transcription failed to start; continuing in audio-only mode: $e',
      );
    }

    isRecording.value = true;
    _recordingStateController.add(true);
    _setCaptureState(
      transcriptionStarted
          ? RecordingCaptureState.transcribing
          : RecordingCaptureState.audioOnly,
    );
    appLogger.i(
      '[RecordingCoordinator] Recording started captureState=${captureState.value.name}',
    );
  }

  Future<String?> _stopAll() async {
    await _stopTranscription(startedViaEvenAI: _startedViaEvenAI);
    _startedViaEvenAI = false;

    String? filePath;
    try {
      if (_audioInitialized && _audioService != null) {
        await _audioService!.stopRecording();
        filePath = _audioService!.currentRecordingPath;
        _lastAudioFilePath = filePath;
        await ConversationEngine.instance.attachLatestAudioFilePath(filePath);
      }
    } catch (e) {
      appLogger.e('[RecordingCoordinator] Audio stop failed: $e');
    }

    _durationSubscription?.cancel();
    _durationSubscription = null;
    _fallbackDurationTimer?.cancel();
    _fallbackDurationTimer = null;
    _recordingStartTime = null;

    _currentMode = null;
    isRecording.value = false;
    _recordingStateController.add(false);
    _setCaptureState(RecordingCaptureState.idle);
    appLogger.i('[RecordingCoordinator] Recording stopped — file: $filePath');

    if (SettingsManager.instance.allDayModeEnabled) {
      PassiveListeningService.instance.resume();
    }

    return filePath;
  }

  void _cleanupFailedStartAttempt() {
    _durationSubscription?.cancel();
    _durationSubscription = null;
    _fallbackDurationTimer?.cancel();
    _fallbackDurationTimer = null;
    _recordingStartTime = null;
    _currentMode = null;
    _setCaptureState(RecordingCaptureState.idle);

    if (SettingsManager.instance.allDayModeEnabled) {
      PassiveListeningService.instance.resume();
    }
  }

  void _handleListeningError(String? error) {
    if (!isRecording.value) return;
    if (error == null || error.trim().isEmpty) return;
    _setCaptureState(RecordingCaptureState.audioOnly);
  }

  void _setCaptureState(RecordingCaptureState nextState) {
    if (captureState.value == nextState) return;
    captureState.value = nextState;
    _captureStateController.add(nextState);
  }

  static Future<void> _defaultStartTranscription({
    required TranscriptSource source,
    required RecordingMode mode,
    required bool useGlasses,
  }) async {
    if (useGlasses) {
      if (mode == RecordingMode.conversation) {
        await EvenAI.get.startContinuousSession();
      } else {
        await EvenAI.get.toStartEvenAIByOS();
      }
      return;
    }

    await ConversationListeningSession.instance.startSession(
      source: TranscriptSource.phone,
    );
  }

  static Future<void> _defaultStopTranscription({
    required bool startedViaEvenAI,
  }) async {
    if (startedViaEvenAI) {
      if (EvenAI.get.continuousMode) {
        await EvenAI.get.stopContinuousSession();
      } else {
        await EvenAI.get.stopEvenAIByOS();
      }
      return;
    }

    await ConversationListeningSession.instance.stopSession();
  }

  @visibleForTesting
  Future<void> debugDispose() async {
    await _listeningErrorSubscription.cancel();
    await _durationSubscription?.cancel();
    _fallbackDurationTimer?.cancel();
    _fallbackDurationTimer = null;
  }
}
