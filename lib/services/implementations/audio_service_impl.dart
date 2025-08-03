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
  Timer? _durationTimer;
  Timer? _streamingTimer;
  bool _isInitialized = false;
  bool _hasPermission = false;
  bool _isRecording = false;
  
  // Voice Activity Detection state
  double _currentVolume = 0.0;
  double _vadThreshold = 0.01;
  bool _isVoiceActive = false;
  final List<double> _volumeHistory = [];
  int _volumeHistoryIndex = 0;
  double _rollingVolumeSum = 0.0; // For efficient average calculation
  static const int _volumeHistorySize = 5; // Reduced for better performance
  
  // Performance optimization constants
  static const Duration _volumeUpdateInterval = Duration(milliseconds: 150); // Reduced frequency
  static const Duration _vadUpdateInterval = Duration(milliseconds: 100); // Reduced frequency  
  static const Duration _durationUpdateInterval = Duration(milliseconds: 200); // Less frequent updates
  
  // Recording timing
  DateTime? _recordingStartTime;
  final StreamController<Duration> _recordingDurationStreamController = 
      StreamController<Duration>.broadcast();
  
  AudioServiceImpl({required LoggingService logger}) : _logger = logger;

  @override
  AudioConfiguration get configuration => _currentConfiguration;

  @override
  bool get isRecording => _isRecording;

  @override
  bool get hasPermission => _hasPermission;

  @override
  String? get currentRecordingPath => _currentRecordingPath;
  
  /// Check current microphone permission status without requesting
  Future<PermissionStatus> checkPermissionStatus() async {
    try {
      final status = await Permission.microphone.status;
      final previousPermission = _hasPermission;
      _hasPermission = status.isGranted || status.isLimited || status.isProvisional;
      
      _logger.log(_tag, 'Current microphone permission status: ${status.name} (hasPermission: $previousPermission -> $_hasPermission)', LogLevel.debug);
      return status;
    } catch (e) {
      _logger.log(_tag, 'Failed to check permission status: $e', LogLevel.error);
      _hasPermission = false;
      return PermissionStatus.denied;
    }
  }
  
  /// Open app settings for user to manually enable microphone permission
  Future<bool> openPermissionSettings() async {
    try {
      _logger.log(_tag, 'Opening app settings for permission management', LogLevel.info);
      return await openAppSettings();
    } catch (e) {
      _logger.log(_tag, 'Failed to open app settings: $e', LogLevel.error);
      return false;
    }
  }

  @override
  Stream<Uint8List> get audioStream => _audioStreamController.stream;

  @override
  Stream<double> get audioLevelStream => _audioLevelStreamController.stream;

  @override
  Stream<bool> get voiceActivityStream => _voiceActivityStreamController.stream;
  
  @override
  Stream<Duration> get recordingDurationStream => _recordingDurationStreamController.stream;

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
      
      // Check if we should show rationale (Android only)
      if (Platform.isAndroid) {
        final shouldShowRationale = await Permission.microphone.shouldShowRequestRationale;
        if (shouldShowRationale) {
          _logger.log(_tag, 'Should show permission rationale to user', LogLevel.debug);
        }
      }
      
      final status = await Permission.microphone.request();
      
      switch (status) {
        case PermissionStatus.granted:
          _hasPermission = true;
          _logger.log(_tag, 'Microphone permission granted', LogLevel.info);
          return true;
          
        case PermissionStatus.denied:
          _hasPermission = false;
          _logger.log(_tag, 'Microphone permission denied', LogLevel.warning);
          return false;
          
        case PermissionStatus.permanentlyDenied:
          _hasPermission = false;
          _logger.log(_tag, 'Microphone permission permanently denied - user must enable in settings', LogLevel.error);
          return false;
          
        case PermissionStatus.restricted:
          _hasPermission = false;
          _logger.log(_tag, 'Microphone permission restricted (parental controls)', LogLevel.warning);
          return false;
          
        case PermissionStatus.limited:
          _hasPermission = true; // Limited access is still usable
          _logger.log(_tag, 'Microphone permission granted with limitations', LogLevel.info);
          return true;
          
        case PermissionStatus.provisional:
          _hasPermission = true; // Provisional access is usable
          _logger.log(_tag, 'Microphone permission granted provisionally', LogLevel.info);
          return true;
      }
    } catch (e) {
      _logger.log(_tag, 'Failed to request microphone permission: $e', LogLevel.error);
      _hasPermission = false;
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
      _recordingStartTime = DateTime.now();
      
      // Start volume monitoring and VAD
      _startVolumeMonitoring();
      _startVoiceActivityDetection();
      _startDurationTracking();
      
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
      _durationTimer?.cancel();
      _streamingTimer?.cancel();
      
      // Stop recorder
      await _recorder.stopRecorder();
      
      _isRecording = false;
      _recordingStartTime = null;
      
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
      _recordingStartTime = DateTime.now();
      
      // Start volume monitoring and VAD
      _startVolumeMonitoring();
      _startVoiceActivityDetection();
      _startDurationTracking();
      
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
      _durationTimer?.cancel();
      _streamingTimer?.cancel();
      
      await _recorder.closeRecorder();
      await _player.closePlayer();
      
      await _audioStreamController.close();
      await _audioLevelStreamController.close();
      await _voiceActivityStreamController.close();
      await _recordingDurationStreamController.close();
      
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
    // Subscribe to FlutterSound onProgress stream for real-time audio levels
    _recorder.onProgress!.listen((RecordingDisposition disposition) {
      try {
        // Get real decibel level from FlutterSound
        final decibels = disposition.decibels;
        
        if (decibels != null && decibels.isFinite) {
          // Convert decibels to linear scale (0.0 to 1.0)
          final volume = _decibelToLinear(decibels);
          _currentVolume = volume;
          
          // Only emit audio level if there are listeners (performance optimization)
          if (_audioLevelStreamController.hasListener) {
            _audioLevelStreamController.add(volume);
          }
          
          // Update volume history for VAD
          _updateVolumeHistory(volume);
          
          _logger.log(_tag, 'Real audio level: ${decibels.toStringAsFixed(1)}dB -> ${volume.toStringAsFixed(3)}', LogLevel.debug);
        } else {
          // Handle null or invalid decibel values
          _updateVolumeHistory(_currentVolume);
        }
      } catch (e) {
        _logger.log(_tag, 'Error processing audio level from onProgress: $e', LogLevel.warning);
        _updateVolumeHistory(_currentVolume);
      }
    });
    
    // Backup timer-based monitoring for additional robustness
    _volumeTimer = Timer.periodic(_volumeUpdateInterval, (timer) async {
      try {
        if (!_isRecording || !_recorder.isRecording) {
          // Decay audio level when not recording
          final decayRate = 0.1;
          final volume = math.max(0.0, _currentVolume - decayRate);
          _currentVolume = volume;
          
          if (_audioLevelStreamController.hasListener) {
            _audioLevelStreamController.add(volume);
          }
          _updateVolumeHistory(volume);
        }
      } catch (e) {
        _logger.log(_tag, 'Error in backup volume monitoring: $e', LogLevel.debug);
      }
    });
  }

  void _startVoiceActivityDetection() {
    _vadTimer = Timer.periodic(_vadUpdateInterval, (timer) {
      _updateVoiceActivityDetection();
    });
  }
  
  void _startDurationTracking() {
    _durationTimer = Timer.periodic(_durationUpdateInterval, (timer) {
      if (!_isRecording || _recordingStartTime == null) {
        timer.cancel();
        _durationTimer = null;
        return;
      }
      
      final duration = DateTime.now().difference(_recordingStartTime!);
      _recordingDurationStreamController.add(duration);
    });
  }

  double _decibelToLinear(double decibels) {
    // Convert decibels to linear scale
    // Improved sensitivity for voice detection:
    // -60 dB = silence threshold, -20 dB = normal speech, 0 dB = max
    const minDb = -60.0;  // More sensitive silence threshold
    const maxDb = -10.0;  // Normal speech range ceiling
    
    // Clamp input to expected range
    final clampedDb = decibels.clamp(-80.0, 0.0);
    
    // Normalize to 0.0-1.0 range with better sensitivity
    final normalizedDb = (clampedDb - minDb) / (maxDb - minDb);
    final linearValue = normalizedDb.clamp(0.0, 1.0);
    
    // Apply slight curve to enhance low-level audio visibility
    final enhancedValue = math.pow(linearValue, 0.7).toDouble();
    
    return enhancedValue;
  }

  void _updateVolumeHistory(double volume) {
    // Efficient circular buffer approach to avoid frequent list operations
    if (_volumeHistory.length < _volumeHistorySize) {
      _volumeHistory.add(volume);
      _rollingVolumeSum += volume;
    } else {
      // Replace oldest entry using circular indexing and update rolling sum
      _rollingVolumeSum -= _volumeHistory[_volumeHistoryIndex];
      _volumeHistory[_volumeHistoryIndex] = volume;
      _rollingVolumeSum += volume;
      _volumeHistoryIndex = (_volumeHistoryIndex + 1) % _volumeHistorySize;
    }
  }

  void _updateVoiceActivityDetection() {
    if (_volumeHistory.isEmpty) return;
    
    // Use rolling average for O(1) performance instead of O(n) reduce operation
    final averageVolume = _rollingVolumeSum / _volumeHistory.length;
    final wasActive = _isVoiceActive;
    
    // Simple VAD based on volume threshold with hysteresis to prevent fluttering
    final threshold = _isVoiceActive ? _vadThreshold * 0.8 : _vadThreshold; // Lower threshold when already active
    _isVoiceActive = averageVolume > threshold;
    
    if (wasActive != _isVoiceActive) {
      // Only emit voice activity if there are listeners (performance optimization)
      if (_voiceActivityStreamController.hasListener) {
        _voiceActivityStreamController.add(_isVoiceActive);
      }
      _logger.log(_tag, 'Voice activity: $_isVoiceActive (avg: ${averageVolume.toStringAsFixed(3)})', LogLevel.debug);
    }
  }

  Future<void> _startAudioStreaming() async {
    try {
      // Set up real-time audio streaming with optimized chunk size
      _logger.log(_tag, 'Started real-time audio streaming', LogLevel.debug);
      
      // Use more efficient streaming interval based on configuration
      final streamingInterval = Duration(milliseconds: math.max(50, _currentConfiguration.chunkDurationMs));
      
      _streamingTimer = Timer.periodic(streamingInterval, (timer) {
        if (!_isRecording) {
          timer.cancel();
          _streamingTimer = null;
          return;
        }
        
        // Optimized: Only send empty chunks when needed to maintain stream flow
        // In a real implementation, this would process actual audio buffer chunks
        if (_audioStreamController.hasListener) {
          _audioStreamController.add(Uint8List.fromList([]));
        }
      });
    } catch (e) {
      _logger.log(_tag, 'Failed to start audio streaming: $e', LogLevel.error);
    }
  }
}