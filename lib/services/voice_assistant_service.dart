// ABOUTME: Service that receives PCM audio from OpenAI Realtime API via platform channel
// ABOUTME: and plays it through the phone speaker using flutter_sound streaming playback.

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_sound/flutter_sound.dart';

import '../utils/app_logger.dart';

/// Streams PCM16 audio from the native OpenAI Realtime transcriber to the
/// phone speaker. Audio arrives as raw PCM chunks at 24 kHz mono via the
/// `eventRealtimeAudio` EventChannel.
class VoiceAssistantService {
  static VoiceAssistantService? _instance;
  static VoiceAssistantService get instance =>
      _instance ??= VoiceAssistantService._();

  VoiceAssistantService._();

  static const _audioChannel = EventChannel('eventRealtimeAudio');

  final FlutterSoundPlayer _player = FlutterSoundPlayer();
  StreamSubscription? _audioSub;
  bool _isListening = false;
  bool _isPlayerOpen = false;
  bool _isStreaming = false;

  bool get isListening => _isListening;

  /// Open the player session. Call once at app startup or before first use.
  Future<void> initialize() async {
    if (_isPlayerOpen) return;
    try {
      await _player.openPlayer();
      _isPlayerOpen = true;
      appLogger.d('[VoiceAssistant] Player initialized');
    } catch (e) {
      appLogger.e('[VoiceAssistant] Failed to initialize player', error: e);
    }
  }

  /// Begin listening for audio chunks from the native side and play them.
  Future<void> startListening() async {
    if (_isListening) return;
    if (!_isPlayerOpen) await initialize();

    _isListening = true;
    _audioSub = _audioChannel
        .receiveBroadcastStream('eventRealtimeAudio')
        .listen(
      (event) async {
        if (event is Uint8List) {
          await _feedAudio(event);
        } else if (event is Map && event['event'] == 'done') {
          await _finishStreaming();
        }
      },
      onError: (error) {
        appLogger.e('[VoiceAssistant] Audio stream error', error: error);
      },
    );

    appLogger.d('[VoiceAssistant] Listening for audio output');
  }

  /// Stop listening and stop any in-progress playback.
  Future<void> stopListening() async {
    _isListening = false;
    await _audioSub?.cancel();
    _audioSub = null;
    await _stopStreaming();
    appLogger.d('[VoiceAssistant] Stopped listening');
  }

  /// Release all resources.
  Future<void> dispose() async {
    await stopListening();
    if (_isPlayerOpen) {
      await _player.closePlayer();
      _isPlayerOpen = false;
    }
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  Future<void> _feedAudio(Uint8List chunk) async {
    if (!_isPlayerOpen) return;

    // Start streaming playback on the first chunk of a new response.
    if (!_isStreaming) {
      try {
        await _player.startPlayerFromStream(
          codec: Codec.pcm16,
          sampleRate: 24000,
          numChannels: 1,
          interleaved: true,
          bufferSize: 8192,
        );
        _isStreaming = true;
        appLogger.d('[VoiceAssistant] Started streaming playback (24kHz PCM16)');
      } catch (e) {
        appLogger.e('[VoiceAssistant] Failed to start stream player', error: e);
        return;
      }
    }

    try {
      _player.uint8ListSink?.add(chunk);
    } catch (e) {
      appLogger.e('[VoiceAssistant] Failed to feed audio chunk', error: e);
    }
  }

  Future<void> _finishStreaming() async {
    if (!_isStreaming) return;
    appLogger.d('[VoiceAssistant] Audio response complete');
    // Send an empty event to signal end-of-stream, then let the player
    // finish draining its buffer before stopping.
    // Let the player finish draining its buffer, then stop.
    // Small delay to allow remaining audio to play out.
    await Future.delayed(const Duration(milliseconds: 500));
    await _stopStreaming();
  }

  Future<void> _stopStreaming() async {
    if (!_isStreaming) return;
    _isStreaming = false;
    try {
      await _player.stopPlayer();
    } catch (_) {
      // Player may already be stopped.
    }
  }
}
