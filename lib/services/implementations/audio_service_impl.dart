// ABOUTME: Simplified audio service implementation using flutter_sound
// ABOUTME: Clean, reliable audio recording without session conflicts

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';

import '../audio_service.dart';
import '../../models/audio_configuration.dart';
import '../../core/utils/exceptions.dart';

/// Simplified AudioService implementation
class AudioServiceImpl implements AudioService {
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  final FlutterSoundPlayer _player = FlutterSoundPlayer();

  // Stream controllers
  final StreamController<Uint8List> _audioStreamController =
      StreamController<Uint8List>.broadcast();
  final StreamController<double> _audioLevelStreamController =
      StreamController<double>.broadcast();
  final StreamController<bool> _voiceActivityStreamController =
      StreamController<bool>.broadcast();
  final StreamController<Duration> _recordingDurationStreamController =
      StreamController<Duration>.broadcast();

  // State
  AudioConfiguration _currentConfiguration = const AudioConfiguration();
  String? _currentRecordingPath;
  bool _isInitialized = false;
  bool _hasPermission = false;
  bool _isRecording = false;

  // Real-time monitoring via flutter_sound streams (no manual timers needed)

  // Voice activity detection
  double _currentAudioLevel = 0.0;
  bool _isVoiceActive = false;
  final List<double> _audioLevelHistory = [];
  static const int _maxHistory = 10;

  AudioServiceImpl();

  @override
  AudioConfiguration get configuration => _currentConfiguration;

  @override
  bool get isRecording => _isRecording;

  @override
  bool get hasPermission => _hasPermission;

  @override
  String? get currentRecordingPath => _currentRecordingPath;

  @override
  Stream<Uint8List> get audioStream => _audioStreamController.stream;

  @override
  Stream<double> get audioLevelStream => _audioLevelStreamController.stream;

  @override
  Stream<bool> get voiceActivityStream => _voiceActivityStreamController.stream;

  @override
  Stream<Duration> get recordingDurationStream =>
      _recordingDurationStreamController.stream;

  @override
  Future<void> initialize(AudioConfiguration config) async {
    try {
      _currentConfiguration = config;
      await _recorder.openRecorder();
      await _player.openPlayer();
      await _recorder.setSubscriptionDuration(const Duration(milliseconds: 100));
      _isInitialized = true;
    } catch (e) {
      throw AudioException('Initialization failed: $e');
    }
  }

  @override
  Future<bool> requestPermission() async {
    try {
      final status = await Permission.microphone.request();
      _hasPermission = status.isGranted || status.isLimited || status.isProvisional;
      return _hasPermission;
    } catch (e) {
      _hasPermission = false;
      return false;
    }
  }

  @override
  Future<void> startRecording() async {
    if (!_isInitialized) throw const AudioException('Service not initialized');
    if (!_hasPermission) throw const AudioException('Microphone permission required');
    if (_isRecording) return;

    try {
      _currentRecordingPath = await _createRecordingFile();
      
      await _recorder.startRecorder(
        toFile: _currentRecordingPath,
        codec: Codec.pcm16WAV,
        sampleRate: 16000,
        numChannels: 1,
      );

      _isRecording = true;
      _startSimpleMonitoring();
    } catch (e) {
      _isRecording = false;
      throw AudioException('Failed to start recording: $e');
    }
  }

  @override
  Future<void> stopRecording() async {
    if (!_isRecording) return;

    try {
      _stopMonitoring();
      await _recorder.stopRecorder();
      _isRecording = false;
      _currentAudioLevel = 0.0;
    } catch (e) {
      throw AudioException('Failed to stop recording: $e');
    }
  }

  @override
  Future<void> pauseRecording() async {
    if (_isRecording) await _recorder.pauseRecorder();
  }

  @override
  Future<void> resumeRecording() async {
    await _recorder.resumeRecorder();
  }

  @override
  Future<String> startConversationRecording(String conversationId) async {
    // Create conversation-specific file path
    final directory = Directory.systemTemp;
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    _currentRecordingPath = '${directory.path}/helix_conversation_${conversationId}_$timestamp.wav';
    
    await startRecording();
    return _currentRecordingPath!;
  }

  @override
  Future<void> stopConversationRecording() async {
    await stopRecording();
  }

  @override
  Future<List<AudioInputDevice>> getInputDevices() async {
    return [
      const AudioInputDevice(
        id: 'default',
        name: 'Default Microphone',
        type: 'built-in',
        isDefault: true,
      ),
    ];
  }

  @override
  Future<void> selectInputDevice(String deviceId) async {
    // Simple stub - not implemented
  }

  @override
  Future<void> configureAudioProcessing({
    bool enableNoiseReduction = true,
    bool enableEchoCancellation = true,
    double gainLevel = 1.0,
  }) async {
    // Simple stub - not implemented
  }

  @override
  Future<void> setVoiceActivityDetection(bool enabled) async {
    // Simple stub - not implemented  
  }

  @override
  Future<void> setAudioQuality(AudioQuality quality) async {
    // Simple stub - not implemented
  }

  @override
  Future<bool> testAudioRecording() async {
    return _hasPermission && _isInitialized;
  }

  @override
  Future<void> dispose() async {
    await stopRecording();
    await _recorder.closeRecorder();
    await _player.closePlayer();
    await _audioStreamController.close();
    await _audioLevelStreamController.close();
    await _voiceActivityStreamController.close();
    await _recordingDurationStreamController.close();
    _isInitialized = false;
  }

  // Additional methods used by other parts of the app

  Future<PermissionStatus> checkPermissionStatus() async {
    final status = await Permission.microphone.status;
    _hasPermission = status.isGranted || status.isLimited || status.isProvisional;
    return status;
  }

  Future<bool> openPermissionSettings() async {
    return await openAppSettings();
  }


  // Simple helper methods

  Future<String> _createRecordingFile() async {
    final directory = Directory.systemTemp;
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return '${directory.path}/helix_recording_$timestamp.wav';
  }

  void _startSimpleMonitoring() {
    _recorder.onProgress?.listen((progress) {
      if (!_isRecording) return;
      
      _recordingDurationStreamController.add(progress.duration);
      
      if (progress.decibels != null) {
        _currentAudioLevel = ((progress.decibels! + 60) / 60).clamp(0.0, 1.0);
        _audioLevelStreamController.add(_currentAudioLevel);
        
        _audioLevelHistory.add(_currentAudioLevel);
        if (_audioLevelHistory.length > _maxHistory) {
          _audioLevelHistory.removeAt(0);
        }
        _updateVoiceActivity();
      }
    });
  }

  void _updateVoiceActivity() {
    if (_audioLevelHistory.isEmpty) return;
    
    final avgLevel = _audioLevelHistory.reduce((a, b) => a + b) / _audioLevelHistory.length;
    final threshold = _currentConfiguration.vadThreshold;
    final wasActive = _isVoiceActive;
    
    _isVoiceActive = avgLevel > (_isVoiceActive ? threshold * 0.8 : threshold);
    
    if (wasActive != _isVoiceActive) {
      _voiceActivityStreamController.add(_isVoiceActive);
    }
  }

  void _stopMonitoring() {
    // Stream automatically stops when recording stops
  }
}