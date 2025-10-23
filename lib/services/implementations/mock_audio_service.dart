import 'dart:async';
import '../audio_service.dart';
import '../../models/audio_configuration.dart';

/// Mock audio service for testing
class MockAudioService implements AudioService {
  bool _isRecording = false;
  bool _isPaused = false;
  String? _currentRecordingPath;
  Timer? _durationTimer;
  Timer? _levelTimer;
  Duration _currentDuration = Duration.zero;

  final _levelController = StreamController<double>.broadcast();
  final _durationController = StreamController<Duration>.broadcast();

  // Test configuration
  Duration recordingDelay = const Duration(milliseconds: 100);
  bool shouldFailStart = false;
  double simulatedAudioLevel = 0.5;

  @override
  Stream<double> get audioLevelStream => _levelController.stream;

  @override
  Stream<Duration> get durationStream => _durationController.stream;

  @override
  bool get isRecording => _isRecording;

  @override
  bool get isPaused => _isPaused;

  @override
  Future<void> initialize(AudioConfiguration config) async {
    await Future.delayed(const Duration(milliseconds: 50));
  }

  @override
  Future<String?> startRecording() async {
    await Future.delayed(recordingDelay);

    if (shouldFailStart) {
      return null;
    }

    _isRecording = true;
    _isPaused = false;
    _currentDuration = Duration.zero;
    _currentRecordingPath = '/mock/path/recording_${DateTime.now().millisecondsSinceEpoch}.aac';

    // Start duration timer
    _durationTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      _currentDuration += const Duration(milliseconds: 100);
      _durationController.add(_currentDuration);
    });

    // Start audio level simulation
    _levelTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      // Simulate varying audio levels
      final level = simulatedAudioLevel +
          (DateTime.now().millisecond % 100) / 200.0;
      _levelController.add(level.clamp(0.0, 1.0));
    });

    return _currentRecordingPath;
  }

  @override
  Future<String?> stopRecording() async {
    await Future.delayed(recordingDelay);

    _isRecording = false;
    _isPaused = false;

    _durationTimer?.cancel();
    _durationTimer = null;

    _levelTimer?.cancel();
    _levelTimer = null;

    return _currentRecordingPath;
  }

  @override
  Future<void> pauseRecording() async {
    await Future.delayed(const Duration(milliseconds: 50));

    _isPaused = true;
    _durationTimer?.cancel();
    _levelTimer?.cancel();
  }

  @override
  Future<void> resumeRecording() async {
    await Future.delayed(const Duration(milliseconds: 50));

    _isPaused = false;

    // Resume timers
    _durationTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      _currentDuration += const Duration(milliseconds: 100);
      _durationController.add(_currentDuration);
    });

    _levelTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      final level = simulatedAudioLevel +
          (DateTime.now().millisecond % 100) / 200.0;
      _levelController.add(level.clamp(0.0, 1.0));
    });
  }

  @override
  Future<Duration?> getRecordingDuration() async {
    return _currentDuration;
  }

  @override
  void dispose() {
    _durationTimer?.cancel();
    _levelTimer?.cancel();
    _levelController.close();
    _durationController.close();
  }

  // Test helper methods

  /// Simulate audio level change
  void setAudioLevel(double level) {
    simulatedAudioLevel = level.clamp(0.0, 1.0);
  }

  /// Get current recording duration
  Duration get currentDuration => _currentDuration;

  /// Simulate recording failure
  void failNextStart() {
    shouldFailStart = true;
  }
}
