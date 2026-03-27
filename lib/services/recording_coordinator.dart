// ABOUTME: Unified recording coordinator that manages both conversation
// ABOUTME: listening (transcription) and audio file recording in a single toggle.
// ABOUTME: Supports multiple recording modes: conversation, voiceNote, walkieTalkieChat.

import 'dart:async';

import 'package:flutter/foundation.dart';

import 'conversation_engine.dart';
import 'conversation_listening_session.dart';
import 'implementations/audio_service_impl.dart';
import 'passive_listening_service.dart';
import 'voice_note_service.dart';
import '../models/audio_configuration.dart';
import '../services/evenai.dart';
import '../services/settings_manager.dart';
import '../ble_manager.dart';
import '../utils/app_logger.dart';

/// The type of recording session.
enum RecordingMode {
  /// Full ConversationEngine pipeline (transcription + AI processing).
  conversation,

  /// Short capture, transcribe only (voice memo).
  voiceNote,

  /// Push-to-talk AI chat.
  walkieTalkieChat,
}

/// Singleton that coordinates recording across both the conversation
/// listening session (transcription) and the audio file recorder.
///
/// Consumers subscribe to [recordingStateStream] and [durationStream]
/// instead of managing their own recording state.
class RecordingCoordinator {
  RecordingCoordinator._();

  static RecordingCoordinator? _instance;
  static RecordingCoordinator get instance =>
      _instance ??= RecordingCoordinator._();

  // ── State ──────────────────────────────────────────────────────────

  final ValueNotifier<bool> isRecording = ValueNotifier<bool>(false);

  /// The active recording mode, or null when not recording.
  RecordingMode? _currentMode;

  final StreamController<bool> _recordingStateController =
      StreamController<bool>.broadcast();
  final StreamController<Duration> _durationController =
      StreamController<Duration>.broadcast();

  Stream<bool> get recordingStateStream => _recordingStateController.stream;
  Stream<Duration> get durationStream => _durationController.stream;

  String? _lastAudioFilePath;
  String? get lastAudioFilePath => _lastAudioFilePath;

  AudioServiceImpl? _audioService;
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
  /// When starting, both the conversation listening session AND the audio
  /// file recorder are started. When stopping, both are stopped and the
  /// audio file path is returned.
  Future<String?> toggleRecording({
    required TranscriptSource source,
    RecordingMode mode = RecordingMode.conversation,
  }) async {
    if (isRecording.value) {
      return _stopAll();
    } else {
      await _startAll(source: source, mode: mode);
      return null;
    }
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
      final service = AudioServiceImpl();
      _audioService = service;

      final config = AudioConfiguration.speechRecognition();
      await service.initialize(config);

      final hasPermission = await service.requestPermission();
      if (!hasPermission) {
        _audioService = null;
        appLogger.w('[RecordingCoordinator] Microphone permission denied for audio recording — skipping file recorder');
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
    // Pause passive listening during active session
    PassiveListeningService.instance.pause();

    _currentMode = mode;

    // 1. Start conversation listening session (transcription).
    final settings = SettingsManager.instance;
    final useGlasses = switch (settings.preferredMicSource) {
      'glasses' => BleManager.isBothConnected(),
      'phone' => false,
      _ => BleManager.isBothConnected(), // 'auto'
    };

    _startedViaEvenAI = useGlasses;
    if (useGlasses) {
      if (mode == RecordingMode.conversation) {
        await EvenAI.get.startContinuousSession();
      } else {
        await EvenAI.get.toStartEvenAIByOS();
      }
    } else {
      await ConversationListeningSession.instance.startSession(
        source: source,
      );
    }

    // 2. Start audio file recording (best-effort; don't fail the whole flow).
    try {
      await _ensureAudioInitialized();
      if (_audioInitialized && _audioService != null) {
        await _audioService!.startRecording();
        _durationSubscription = _audioService!.durationStream.listen((d) {
          _durationController.add(d);
        });
      }
    } catch (e) {
      appLogger.e('[RecordingCoordinator] Audio file recording failed to start: $e');
    }

    // 3. Fallback duration timer when audio service is unavailable.
    if (!_audioInitialized || _audioService == null) {
      _recordingStartTime = DateTime.now();
      _fallbackDurationTimer = Timer.periodic(
        const Duration(seconds: 1),
        (_) {
          if (_recordingStartTime != null) {
            _durationController.add(
              DateTime.now().difference(_recordingStartTime!),
            );
          }
        },
      );
    }

    // 4. Publish state.
    isRecording.value = true;
    _recordingStateController.add(true);
    appLogger.i('[RecordingCoordinator] Recording started');
  }

  Future<String?> _stopAll() async {
    // 1. Stop conversation listening session.
    // Use the saved flag rather than EvenAI.isRunning, which may have been
    // reset by the 30-second timer (recordOverByOS) before we get here.
    if (_startedViaEvenAI) {
      if (EvenAI.get.continuousMode) {
        await EvenAI.get.stopContinuousSession();
      } else {
        await EvenAI.get.stopEvenAIByOS();
      }
    } else {
      await ConversationListeningSession.instance.stopSession();
    }
    _startedViaEvenAI = false;

    // 2. Stop audio file recording.
    String? filePath;
    try {
      if (_audioInitialized && _audioService != null) {
        await _audioService!.stopRecording();
        filePath = _audioService!.currentRecordingPath;
        _lastAudioFilePath = filePath;
      }
    } catch (e) {
      appLogger.e('[RecordingCoordinator] Audio stop failed: $e');
    }

    // 3. Cleanup.
    _durationSubscription?.cancel();
    _durationSubscription = null;
    _fallbackDurationTimer?.cancel();
    _fallbackDurationTimer = null;
    _recordingStartTime = null;

    // 4. Publish state.
    _currentMode = null;
    isRecording.value = false;
    _recordingStateController.add(false);
    appLogger.i('[RecordingCoordinator] Recording stopped — file: $filePath');

    // Resume passive listening after active session
    if (SettingsManager.instance.allDayModeEnabled) {
      PassiveListeningService.instance.resume();
    }

    return filePath;
  }
}
