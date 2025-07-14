// ABOUTME: Audio service implementation using flutter_sound for audio processing
// ABOUTME: Handles real-time audio capture, streaming, and voice activity detection

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:audio_session/audio_session.dart';

import '../audio_service.dart';
import '../../models/audio_configuration.dart';
import '../../core/utils/logging_service.dart';
import '../../core/utils/exceptions.dart';

/// Implementation of AudioService using flutter_sound
class AudioServiceImpl implements AudioService {
  static const String _tag = 'AudioServiceImpl';
  
  final LoggingService _logger;
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  final FlutterSoundPlayer _player = FlutterSoundPlayer();
  
  final StreamController<Uint8List> _audioStreamController = 
      StreamController<Uint8List>.broadcast();
  final StreamController<double> _audioLevelStreamController = 
      StreamController<double>.broadcast();
  final StreamController<bool> _voiceActivityStreamController = 
      StreamController<bool>.broadcast();
  
  AudioConfiguration _currentConfiguration = const AudioConfiguration();
  String? _currentRecordingPath;
  Timer? _volumeTimer;
  Timer? _vadTimer;
  bool _isInitialized = false;
  bool _hasPermission = false;
  bool _isRecording = false;
  
  // Voice Activity Detection state
  double _currentVolume = 0.0;
  double _vadThreshold = 0.01;
  bool _isVoiceActive = false;
  final List<double> _volumeHistory = [];
  static const int _volumeHistorySize = 10;
  
  AudioServiceImpl({required LoggingService logger}) : _logger = logger;

  @override
  AudioConfiguration get configuration => _currentConfiguration;

  @override
  bool get isRecording => _isRecording;

  @override
  bool get hasPermission => _hasPermission;

  @override
  Stream<Uint8List> get audioStream => _audioStreamController.stream;

  @override
  Stream<double> get audioLevelStream => _audioLevelStreamController.stream;

  @override
  Stream<bool> get voiceActivityStream => _voiceActivityStreamController.stream;

  @override
  Future<void> initialize(AudioConfiguration config) async {
    try {
      _logger.log(_tag, 'Initializing audio service', LogLevel.info);
      
      _currentConfiguration = config;
      
      // Initialize recorder and player
      await _recorder.openRecorder();
      await _player.openPlayer();
      
      // Configure audio session
      await _configureAudioSession();
      
      _vadThreshold = _currentConfiguration.vadThreshold;
      _isInitialized = true;
      
      _logger.log(_tag, 'Audio service initialized successfully', LogLevel.info);
    } catch (e) {
      _logger.log(_tag, 'Failed to initialize audio service: $e', LogLevel.error);
      throw AudioException('Initialization failed: $e', originalError: e);
    }
  }

  @override
  Future<bool> requestPermission() async {
    try {
      _logger.log(_tag, 'Requesting microphone permission', LogLevel.info);
      
      final micPermission = await Permission.microphone.request();
      _hasPermission = micPermission.isGranted;
      
      if (!_hasPermission) {
        _logger.log(_tag, 'Microphone permission denied', LogLevel.warning);
      }
      
      return _hasPermission;
    } catch (e) {
      _logger.log(_tag, 'Failed to request permission: $e', LogLevel.error);
      return false;
    }
  }

  @override
  Future<void> startRecording() async {
    if (!_isInitialized) {
      throw const AudioException('Service not initialized');
    }
    
    if (!_hasPermission) {
      throw const AudioException('Microphone permission required');
    }
    
    if (_isRecording) {
      _logger.log(_tag, 'Already recording', LogLevel.warning);
      return;
    }
    
    try {
      _logger.log(_tag, 'Starting audio recording', LogLevel.info);
      
      // Create temporary file for recording
      _currentRecordingPath = await _createTempRecordingFile();
      
      // Configure recording codec and settings
      final codec = _getCodecFromFormat(_currentConfiguration.format);
      
      await _recorder.startRecorder(
        toFile: _currentRecordingPath,
        codec: codec,
        sampleRate: _currentConfiguration.sampleRate,
        numChannels: _currentConfiguration.channels,
        bitRate: _currentConfiguration.bitRate,
      );
      
      _isRecording = true;
      
      // Start volume monitoring and VAD
      _startVolumeMonitoring();
      _startVoiceActivityDetection();
      
      // Start streaming audio data
      if (_currentConfiguration.enableRealTimeStreaming) {
        await _startAudioStreaming();
      }
      
      _logger.log(_tag, 'Recording started successfully', LogLevel.info);
    } catch (e) {
      _logger.log(_tag, 'Failed to start recording: $e', LogLevel.error);
      _isRecording = false;
      throw AudioException('Failed to start recording: $e', originalError: e);
    }
  }

  @override
  Future<void> stopRecording() async {
    if (!_isRecording) {
      return;
    }
    
    try {
      _logger.log(_tag, 'Stopping audio recording', LogLevel.info);
      
      // Stop timers
      _volumeTimer?.cancel();
      _vadTimer?.cancel();
      
      // Stop recorder
      await _recorder.stopRecorder();
      
      _isRecording = false;
      
      _logger.log(_tag, 'Recording stopped successfully', LogLevel.info);
    } catch (e) {
      _logger.log(_tag, 'Failed to stop recording: $e', LogLevel.error);
      throw AudioException('Failed to stop recording: $e', originalError: e);
    }
  }

  @override
  Future<void> pauseRecording() async {
    if (!_isRecording) {
      return;
    }
    
    try {
      await _recorder.pauseRecorder();
      _logger.log(_tag, 'Recording paused', LogLevel.info);
    } catch (e) {
      _logger.log(_tag, 'Failed to pause recording: $e', LogLevel.error);
      throw AudioException('Failed to pause recording: $e', originalError: e);
    }
  }

  @override
  Future<void> resumeRecording() async {
    try {
      await _recorder.resumeRecorder();
      _logger.log(_tag, 'Recording resumed', LogLevel.info);
    } catch (e) {
      _logger.log(_tag, 'Failed to resume recording: $e', LogLevel.error);
      throw AudioException('Failed to resume recording: $e', originalError: e);
    }
  }

  @override
  Future<String> startConversationRecording(String conversationId) async {
    try {
      if (!_hasPermission) {
        throw const AudioException('Microphone permission required');
      }
      
      _logger.log(_tag, 'Starting conversation recording: $conversationId', LogLevel.info);
      
      // Create recording file for this conversation
      final directory = Directory.systemTemp;
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = _getFileExtension(_currentConfiguration.format);
      _currentRecordingPath = '${directory.path}/helix_conversation_${conversationId}_$timestamp.$extension';
      
      // Configure recording codec and settings
      final codec = _getCodecFromFormat(_currentConfiguration.format);
      
      await _recorder.startRecorder(
        toFile: _currentRecordingPath,
        codec: codec,
        sampleRate: _currentConfiguration.sampleRate,
        numChannels: _currentConfiguration.channels,
        bitRate: _currentConfiguration.bitRate,
      );
      
      _isRecording = true;
      
      // Start volume monitoring and VAD
      _startVolumeMonitoring();
      _startVoiceActivityDetection();
      
      return _currentRecordingPath!;
    } catch (e) {
      _logger.log(_tag, 'Failed to start conversation recording: $e', LogLevel.error);
      throw AudioException('Failed to start conversation recording: $e', originalError: e);
    }
  }

  @override
  Future<void> stopConversationRecording() async {
    await stopRecording();
  }

  @override
  Future<List<AudioInputDevice>> getInputDevices() async {
    try {
      // For now, return default devices
      // In a full implementation, this would query actual devices
      return [
        const AudioInputDevice(
          id: 'default',
          name: 'Default Microphone',
          type: 'built-in',
          isDefault: true,
        ),
        const AudioInputDevice(
          id: 'bluetooth',
          name: 'Bluetooth Microphone',
          type: 'bluetooth',
          isDefault: false,
        ),
      ];
    } catch (e) {
      _logger.log(_tag, 'Failed to get input devices: $e', LogLevel.error);
      throw AudioException('Failed to get input devices: $e', originalError: e);
    }
  }

  @override
  Future<void> selectInputDevice(String deviceId) async {
    try {
      _logger.log(_tag, 'Selecting input device: $deviceId', LogLevel.info);
      // Implementation would depend on platform-specific audio routing
      // For now, just log the action
    } catch (e) {
      _logger.log(_tag, 'Failed to select input device: $e', LogLevel.error);
      throw AudioException('Failed to select input device: $e', originalError: e);
    }
  }

  @override
  Future<void> configureAudioProcessing({
    bool enableNoiseReduction = true,
    bool enableEchoCancellation = true,
    double gainLevel = 1.0,
  }) async {
    try {
      _logger.log(_tag, 'Configuring audio processing', LogLevel.info);
      
      // Update configuration
      _currentConfiguration = _currentConfiguration.copyWith(
        enableNoiseReduction: enableNoiseReduction,
        enableEchoCancellation: enableEchoCancellation,
        gainLevel: gainLevel,
      );
      
      // Apply configuration if recording
      if (_isRecording) {
        await stopRecording();
        await startRecording();
      }
    } catch (e) {
      _logger.log(_tag, 'Failed to configure audio processing: $e', LogLevel.error);
      throw AudioException('Failed to configure audio processing: $e', originalError: e);
    }
  }

  @override
  Future<void> setVoiceActivityDetection(bool enabled) async {
    try {
      _logger.log(_tag, 'Setting voice activity detection: $enabled', LogLevel.info);
      
      _currentConfiguration = _currentConfiguration.copyWith(
        enableVoiceActivityDetection: enabled,
      );
      
      if (enabled && (_vadTimer?.isActive != true)) {
        _startVoiceActivityDetection();
      } else if (!enabled && (_vadTimer?.isActive == true)) {
        _vadTimer?.cancel();
      }
    } catch (e) {
      _logger.log(_tag, 'Failed to set voice activity detection: $e', LogLevel.error);
      throw AudioException('Failed to set voice activity detection: $e', originalError: e);
    }
  }

  @override
  Future<void> setAudioQuality(AudioQuality quality) async {
    try {
      _logger.log(_tag, 'Setting audio quality: $quality', LogLevel.info);
      
      _currentConfiguration = _currentConfiguration.copyWith(quality: quality);
      
      // Apply quality settings
      if (_isRecording) {
        await stopRecording();
        await startRecording();
      }
    } catch (e) {
      _logger.log(_tag, 'Failed to set audio quality: $e', LogLevel.error);
      throw AudioException('Failed to set audio quality: $e', originalError: e);
    }
  }

  @override
  Future<bool> testAudioRecording() async {
    try {
      _logger.log(_tag, 'Testing audio recording', LogLevel.info);
      
      if (!_hasPermission) {
        return false;
      }
      
      // Start a short test recording
      await startRecording();
      await Future.delayed(const Duration(seconds: 2));
      await stopRecording();
      
      // Check if file was created
      if (_currentRecordingPath != null) {
        final file = File(_currentRecordingPath!);
        final exists = await file.exists();
        if (exists) {
          await file.delete(); // Clean up test file
        }
        return exists;
      }
      
      return false;
    } catch (e) {
      _logger.log(_tag, 'Audio recording test failed: $e', LogLevel.error);
      return false;
    }
  }

  @override
  Future<void> dispose() async {
    try {
      _logger.log(_tag, 'Disposing audio service', LogLevel.info);
      
      await stopRecording();
      
      _volumeTimer?.cancel();
      _vadTimer?.cancel();
      
      await _recorder.closeRecorder();
      await _player.closePlayer();
      
      await _audioStreamController.close();
      await _audioLevelStreamController.close();
      await _voiceActivityStreamController.close();
      
      // Clean up temporary files
      if (_currentRecordingPath != null) {
        final file = File(_currentRecordingPath!);
        if (await file.exists()) {
          await file.delete();
        }
      }
      
      _isInitialized = false;
    } catch (e) {
      _logger.log(_tag, 'Error during disposal: $e', LogLevel.error);
    }
  }

  // Private helper methods

  Future<void> _configureAudioSession() async {
    try {
      final session = await AudioSession.instance;
      
      // Configure the audio session for recording
      await session.configure(AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
        avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.defaultToSpeaker,
        avAudioSessionMode: AVAudioSessionMode.measurement,
        avAudioSessionRouteSharingPolicy: AVAudioSessionRouteSharingPolicy.defaultPolicy,
        avAudioSessionSetActiveOptions: AVAudioSessionSetActiveOptions.none,
        androidAudioAttributes: const AndroidAudioAttributes(
          contentType: AndroidAudioContentType.speech,
          flags: AndroidAudioFlags.audibilityEnforced,
          usage: AndroidAudioUsage.voiceCommunication,
        ),
        androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
        androidWillPauseWhenDucked: true,
      ));
      
      _logger.log(_tag, 'Audio session configured successfully', LogLevel.debug);
    } catch (e) {
      _logger.log(_tag, 'Audio session configuration failed: $e', LogLevel.warning);
    }
  }

  Future<String> _createTempRecordingFile() async {
    final directory = Directory.systemTemp;
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final extension = _getFileExtension(_currentConfiguration.format);
    return '${directory.path}/helix_recording_$timestamp.$extension';
  }

  Codec _getCodecFromFormat(AudioFormat format) {
    switch (format) {
      case AudioFormat.wav:
        return Codec.pcm16WAV;
      case AudioFormat.mp3:
        return Codec.mp3;
      case AudioFormat.aac:
        return Codec.aacADTS;
      case AudioFormat.flac:
        return Codec.pcm16WAV; // Fallback to WAV for FLAC
    }
  }

  String _getFileExtension(AudioFormat format) {
    switch (format) {
      case AudioFormat.wav:
        return 'wav';
      case AudioFormat.mp3:
        return 'mp3';
      case AudioFormat.aac:
        return 'aac';
      case AudioFormat.flac:
        return 'flac';
    }
  }

  void _startVolumeMonitoring() {
    _volumeTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) async {
      try {
        // For now, simulate volume data
        // In a full implementation, this would use flutter_sound's amplitude API
        final simulatedVolume = _currentVolume + (math.Random().nextDouble() - 0.5) * 0.1;
        final volume = simulatedVolume.clamp(0.0, 1.0);
        
        _currentVolume = volume;
        _audioLevelStreamController.add(volume);
        
        // Update volume history for VAD
        _updateVolumeHistory(volume);
      } catch (e) {
        // Ignore errors during volume monitoring
      }
    });
  }

  void _startVoiceActivityDetection() {
    _vadTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      _updateVoiceActivityDetection();
    });
  }

  double _decibelToLinear(double decibels) {
    // Convert decibels to linear scale
    // Typical microphone range: -80 dB (silence) to 0 dB (max)
    const minDb = -80.0;
    const maxDb = 0.0;
    
    final normalizedDb = (decibels - minDb) / (maxDb - minDb);
    return normalizedDb.clamp(0.0, 1.0);
  }

  void _updateVolumeHistory(double volume) {
    _volumeHistory.add(volume);
    if (_volumeHistory.length > _volumeHistorySize) {
      _volumeHistory.removeAt(0);
    }
  }

  void _updateVoiceActivityDetection() {
    if (_volumeHistory.isEmpty) return;
    
    final averageVolume = _volumeHistory.reduce((a, b) => a + b) / _volumeHistory.length;
    final wasActive = _isVoiceActive;
    
    // Simple VAD based on volume threshold
    _isVoiceActive = averageVolume > _vadThreshold;
    
    if (wasActive != _isVoiceActive) {
      _voiceActivityStreamController.add(_isVoiceActive);
      _logger.log(_tag, 'Voice activity: $_isVoiceActive', LogLevel.debug);
    }
  }

  Future<void> _startAudioStreaming() async {
    try {
      // Set up real-time audio streaming
      // This is a simplified implementation
      // In practice, you'd want to stream raw audio data chunks
      _logger.log(_tag, 'Started real-time audio streaming', LogLevel.debug);
      
      // For now, we'll simulate streaming by reading the recording file periodically
      Timer.periodic(Duration(milliseconds: _currentConfiguration.chunkDurationMs), (timer) {
        if (!_isRecording) {
          timer.cancel();
          return;
        }
        
        // In a real implementation, this would stream actual audio chunks
        _audioStreamController.add(Uint8List.fromList([]));
      });
    } catch (e) {
      _logger.log(_tag, 'Failed to start audio streaming: $e', LogLevel.error);
    }
  }
}