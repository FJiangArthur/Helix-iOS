import 'dart:async';
import '../models/conversation_session.dart';
import '../models/audio_chunk.dart';
import 'audio_service.dart';
import 'interfaces/i_transcription_service.dart';

/// Service that connects audio recording to transcription pipeline
/// Bridges AudioService and TranscriptionService
class AudioRecordingService {
  final AudioService _audioService;
  final ITranscriptionService _transcription;

  ConversationSession? _currentSession;
  StreamSubscription<List<int>>? _audioSubscription;
  String? _currentRecordingPath;

  bool _isRecording = false;

  AudioRecordingService({
    required AudioService audioService,
    required ITranscriptionService transcription,
  })  : _audioService = audioService,
        _transcription = transcription;

  /// Whether currently recording
  bool get isRecording => _isRecording;

  /// Current session
  ConversationSession? get currentSession => _currentSession;

  /// Current recording file path
  String? get currentRecordingPath => _currentRecordingPath;

  /// Audio level stream
  Stream<double> get audioLevelStream => _audioService.audioLevelStream;

  /// Recording duration stream
  Stream<Duration> get durationStream => _audioService.durationStream;

  /// Start recording with transcription
  Future<ConversationSession> startRecording() async {
    if (_isRecording) {
      throw StateError('Already recording');
    }

    // Create new session
    _currentSession = ConversationSession.create().copyWith(
      status: SessionStatus.recording,
    );

    // Start audio recording
    _currentRecordingPath = await _audioService.startRecording();

    if (_currentRecordingPath == null) {
      throw Exception('Failed to start audio recording');
    }

    _isRecording = true;

    // Start transcription
    await _transcription.startTranscription();

    // Connect audio stream to transcription
    // Note: flutter_sound doesn't provide raw audio stream directly
    // This is a simplified model - real implementation would need
    // platform-specific audio streaming or use the recorded file
    _audioSubscription = _audioService.audioLevelStream.map((level) {
      // Simulate audio chunks based on level
      // In real implementation, this would be actual PCM data
      return List<int>.filled(1024, (level * 255).toInt());
    }).listen((audioData) {
      final chunk = AudioChunk.fromBytes(audioData);
      _transcription.processAudio(chunk);
    });

    return _currentSession!;
  }

  /// Stop recording and finalize session
  Future<ConversationSession> stopRecording() async {
    if (!_isRecording) {
      throw StateError('Not recording');
    }

    _isRecording = false;

    // Stop audio recording
    final path = await _audioService.stopRecording();

    // Stop transcription
    await _transcription.stopTranscription();

    // Cancel audio stream subscription
    await _audioSubscription?.cancel();
    _audioSubscription = null;

    // Update session
    if (_currentSession != null) {
      final duration = await _audioService.getRecordingDuration();

      _currentSession = _currentSession!.copyWith(
        endTime: DateTime.now(),
        status: SessionStatus.completed,
        audioFilePath: path,
        durationSeconds: duration?.inSeconds ?? 0,
      );
    }

    return _currentSession!;
  }

  /// Pause recording
  Future<void> pauseRecording() async {
    if (!_isRecording) return;

    await _audioService.pauseRecording();
    await _transcription.stopTranscription();
  }

  /// Resume recording
  Future<void> resumeRecording() async {
    if (!_isRecording) return;

    await _audioService.resumeRecording();
    await _transcription.startTranscription();
  }

  /// Cancel current recording without saving
  Future<void> cancelRecording() async {
    if (!_isRecording) return;

    _isRecording = false;

    await _audioService.stopRecording();
    await _transcription.stopTranscription();
    await _audioSubscription?.cancel();
    _audioSubscription = null;

    if (_currentSession != null) {
      _currentSession = _currentSession!.copyWith(
        status: SessionStatus.failed,
        errorMessage: 'Recording cancelled by user',
      );
    }

    _currentRecordingPath = null;
  }

  /// Get recording duration
  Future<Duration?> getRecordingDuration() async {
    return _audioService.getRecordingDuration();
  }

  /// Dispose resources
  void dispose() {
    _audioSubscription?.cancel();
  }
}
