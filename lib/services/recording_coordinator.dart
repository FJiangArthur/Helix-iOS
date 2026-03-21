// ABOUTME: Unified recording coordinator that manages both conversation
// ABOUTME: listening (transcription) and audio file recording in a single toggle.

import 'dart:async';

import 'package:flutter/foundation.dart';

import 'conversation_engine.dart';
import 'conversation_listening_session.dart';
import 'implementations/audio_service_impl.dart';
import '../models/audio_configuration.dart';
import '../services/evenai.dart';
import '../services/settings_manager.dart';
import '../ble_manager.dart';
import '../utils/app_logger.dart';

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

  /// Toggle recording on/off.
  ///
  /// When starting, both the conversation listening session AND the audio
  /// file recorder are started. When stopping, both are stopped and the
  /// audio file path is returned.
  Future<String?> toggleRecording({
    required TranscriptSource source,
  }) async {
    if (isRecording.value) {
      return _stopAll();
    } else {
      await _startAll(source: source);
      return null;
    }
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

  Future<void> _startAll({required TranscriptSource source}) async {
    // 1. Start conversation listening session (transcription).
    final settings = SettingsManager.instance;
    final useGlasses = switch (settings.preferredMicSource) {
      'glasses' => BleManager.isBothConnected(),
      'phone' => false,
      _ => BleManager.isBothConnected(), // 'auto'
    };

    _startedViaEvenAI = useGlasses;
    if (useGlasses) {
      await EvenAI.get.toStartEvenAIByOS();
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
      await EvenAI.get.stopEvenAIByOS();
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
    isRecording.value = false;
    _recordingStateController.add(false);
    appLogger.i('[RecordingCoordinator] Recording stopped — file: $filePath');

    return filePath;
  }
}
