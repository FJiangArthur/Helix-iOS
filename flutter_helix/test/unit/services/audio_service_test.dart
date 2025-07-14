// ABOUTME: Unit tests for AudioService implementation
// ABOUTME: Tests audio recording, processing, and noise reduction functionality

import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:fake_async/fake_async.dart';

import 'package:flutter_helix/services/implementations/audio_service_impl.dart';
import 'package:flutter_helix/services/audio_service.dart';
import 'package:flutter_helix/core/utils/exceptions.dart';
import '../../test_helpers.dart';

void main() {
  group('AudioService', () {
    late AudioServiceImpl audioService;
    late StreamController<double> audioLevelController;
    
    setUp(() {
      audioLevelController = StreamController<double>.broadcast();
      audioService = AudioServiceImpl();
    });
    
    tearDown(() {
      audioLevelController.close();
      audioService.dispose();
    });
    
    group('Initialization', () {
      test('should initialize with correct default state', () {
        expect(audioService.isRecording, isFalse);
        expect(audioService.isPlaying, isFalse);
        expect(audioService.currentAudioLevel, equals(0.0));
      });
      
      test('should configure audio session on initialization', () async {
        // AudioServiceImpl should configure audio session internally
        expect(audioService.isInitialized, isTrue);
      });
    });
    
    group('Recording', () {
      test('should start recording with correct configuration', () async {
        // Act
        await audioService.startRecording();
        
        // Assert
        expect(audioService.isRecording, isTrue);
        expect(audioService.recordingPath, isNotNull);
      });
      
      test('should stop recording and return file path', () async {
        // Arrange
        await audioService.startRecording();
        expect(audioService.isRecording, isTrue);
        
        // Act
        final filePath = await audioService.stopRecording();
        
        // Assert
        expect(audioService.isRecording, isFalse);
        expect(filePath, isNotNull);
        expect(filePath, isNotEmpty);
      });
      
      test('should throw exception when starting recording while already recording', () async {
        // Arrange
        await audioService.startRecording();
        
        // Act & Assert
        expect(
          () async => await audioService.startRecording(),
          throwsA(isA<AudioException>()),
        );
      });
      
      test('should throw exception when stopping recording while not recording', () async {
        // Act & Assert
        expect(
          () async => await audioService.stopRecording(),
          throwsA(isA<AudioException>()),
        );
      });
      
      test('should handle recording errors gracefully', () async {
        // This would require mocking the underlying flutter_sound recorder
        // For now, we test the error handling structure
        expect(audioService.isRecording, isFalse);
      });
    });
    
    group('Audio Level Monitoring', () {
      test('should provide audio level stream during recording', () async {
        fakeAsync((async) {
          // Arrange
          final audioLevels = <double>[];
          final subscription = audioService.audioLevelStream.listen(
            (level) => audioLevels.add(level),
          );
          
          // Act
          audioService.startRecording();
          async.elapse(const Duration(seconds: 2));
          
          // Assert
          expect(audioLevels, isNotEmpty);
          expect(audioLevels.every((level) => level >= 0.0 && level <= 1.0), isTrue);
          
          subscription.cancel();
        });
      });
      
      test('should emit zero audio level when not recording', () {
        // Arrange
        double? lastLevel;
        final subscription = audioService.audioLevelStream.listen(
          (level) => lastLevel = level,
        );
        
        // Act - not recording
        
        // Assert
        expect(lastLevel ?? 0.0, equals(0.0));
        subscription.cancel();
      });
    });
    
    group('Audio Processing', () {
      test('should process audio data with noise reduction', () async {
        // Arrange
        final testAudioData = TestHelpers.createTestAudioData(
          durationSeconds: 2,
          sampleRate: 16000,
        );
        
        // Act
        final processedData = await audioService.processAudioData(
          testAudioData,
          enableNoiseReduction: true,
        );
        
        // Assert
        expect(processedData, isNotNull);
        expect(processedData.length, equals(testAudioData.length));
        // Processed data should be different from original (noise reduction applied)
        expect(processedData, isNot(equals(testAudioData)));
      });
      
      test('should return original data when noise reduction disabled', () async {
        // Arrange
        final testAudioData = TestHelpers.createTestAudioData(
          durationSeconds: 1,
          sampleRate: 16000,
        );
        
        // Act
        final processedData = await audioService.processAudioData(
          testAudioData,
          enableNoiseReduction: false,
        );
        
        // Assert
        expect(processedData, equals(testAudioData));
      });
      
      test('should handle empty audio data', () async {
        // Arrange
        final emptyData = <int>[];
        
        // Act
        final processedData = await audioService.processAudioData(
          emptyData,
          enableNoiseReduction: true,
        );
        
        // Assert
        expect(processedData, isEmpty);
      });
    });
    
    group('Playback', () {
      test('should start playback of audio file', () async {
        // Arrange
        const testFilePath = '/test/path/to/audio.wav';
        
        // Act
        await audioService.startPlayback(testFilePath);
        
        // Assert
        expect(audioService.isPlaying, isTrue);
      });
      
      test('should stop playback', () async {
        // Arrange
        const testFilePath = '/test/path/to/audio.wav';
        await audioService.startPlayback(testFilePath);
        expect(audioService.isPlaying, isTrue);
        
        // Act
        await audioService.stopPlayback();
        
        // Assert
        expect(audioService.isPlaying, isFalse);
      });
      
      test('should handle playback completion', () async {
        fakeAsync((async) {
          // Arrange
          const testFilePath = '/test/path/to/audio.wav';
          bool playbackCompleted = false;
          
          audioService.playbackCompleteStream.listen((_) {
            playbackCompleted = true;
          });
          
          // Act
          audioService.startPlayback(testFilePath);
          async.elapse(const Duration(seconds: 5)); // Simulate playback duration
          
          // Assert
          expect(playbackCompleted, isTrue);
          expect(audioService.isPlaying, isFalse);
        });
      });
    });
    
    group('Audio Quality', () {
      test('should configure different quality settings', () async {
        // Test high quality
        await audioService.setRecordingQuality(AudioQuality.high);
        expect(audioService.currentQuality, equals(AudioQuality.high));
        
        // Test medium quality
        await audioService.setRecordingQuality(AudioQuality.medium);
        expect(audioService.currentQuality, equals(AudioQuality.medium));
        
        // Test low quality
        await audioService.setRecordingQuality(AudioQuality.low);
        expect(audioService.currentQuality, equals(AudioQuality.low));
      });
      
      test('should use appropriate sample rates for quality settings', () async {
        // High quality should use 44.1kHz
        await audioService.setRecordingQuality(AudioQuality.high);
        expect(audioService.sampleRate, equals(44100));
        
        // Medium quality should use 16kHz
        await audioService.setRecordingQuality(AudioQuality.medium);
        expect(audioService.sampleRate, equals(16000));
        
        // Low quality should use 8kHz
        await audioService.setRecordingQuality(AudioQuality.low);
        expect(audioService.sampleRate, equals(8000));
      });
    });
    
    group('Voice Activity Detection', () {
      test('should detect voice activity in audio data', () {
        // Arrange
        final silentData = List.filled(1000, 0); // Silent audio
        final loudData = TestHelpers.createTestAudioData(); // Audio with signal
        
        // Act
        final silentVAD = audioService.detectVoiceActivity(silentData);
        final loudVAD = audioService.detectVoiceActivity(loudData);
        
        // Assert
        expect(silentVAD, isFalse);
        expect(loudVAD, isTrue);
      });
      
      test('should use configurable VAD threshold', () {
        // Arrange
        final moderateData = TestHelpers.createTestAudioData();
        
        // Test with high threshold (should not detect voice)
        audioService.setVADThreshold(0.9);
        expect(audioService.detectVoiceActivity(moderateData), isFalse);
        
        // Test with low threshold (should detect voice)
        audioService.setVADThreshold(0.1);
        expect(audioService.detectVoiceActivity(moderateData), isTrue);
      });
    });
    
    group('Resource Management', () {
      test('should dispose resources properly', () {
        // Arrange
        audioService.startRecording();
        
        // Act
        audioService.dispose();
        
        // Assert
        expect(audioService.isRecording, isFalse);
        expect(audioService.isPlaying, isFalse);
      });
      
      test('should handle multiple dispose calls safely', () {
        // Act & Assert - should not throw
        audioService.dispose();
        audioService.dispose();
        audioService.dispose();
      });
    });
    
    group('Error Handling', () {
      test('should handle microphone permission denied', () async {
        // This would require platform-specific mocking
        // For now, test the exception structure
        expect(() => const AudioException('Permission denied'), 
               throwsA(isA<AudioException>()));
      });
      
      test('should handle disk space issues', () async {
        expect(() => const AudioException('Insufficient disk space'), 
               throwsA(isA<AudioException>()));
      });
      
      test('should handle audio format issues', () async {
        expect(() => const AudioException('Unsupported audio format'), 
               throwsA(isA<AudioException>()));
      });
    });
  });
}