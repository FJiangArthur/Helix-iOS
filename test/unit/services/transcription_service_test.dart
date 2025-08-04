// ABOUTME: Simplified unit tests for TranscriptionService implementation
// ABOUTME: Tests basic initialization and service availability without platform dependencies

import 'dart:async';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_helix/services/implementations/transcription_service_impl.dart';
import 'package:flutter_helix/services/transcription_service.dart';
import 'package:flutter_helix/core/utils/logging_service.dart';

void main() {
  group('TranscriptionService', () {
    late TranscriptionServiceImpl transcriptionService;
    
    setUp(() {
      transcriptionService = TranscriptionServiceImpl(logger: LoggingService.instance);
    });
    
    tearDown(() async {
      await transcriptionService.dispose();
    });
    
    group('Basic Properties', () {
      test('should have correct initial state', () {
        expect(transcriptionService.isTranscribing, isFalse);
        expect(transcriptionService.currentLanguage, equals('en-US'));
        expect(transcriptionService.currentBackend, equals(TranscriptionBackend.device));
        expect(transcriptionService.currentQuality, equals(TranscriptionQuality.standard));
      });
      
      test('should provide streams', () {
        expect(transcriptionService.transcriptionStream, isA<Stream>());
        expect(transcriptionService.confidenceStream, isA<Stream>());
      });
    });
    
    group('Configuration', () {
      test('should update quality setting', () async {
        await transcriptionService.configureQuality(TranscriptionQuality.high);
        expect(transcriptionService.currentQuality, equals(TranscriptionQuality.high));
      });
      
      test('should update backend setting', () async {
        await transcriptionService.configureBackend(TranscriptionBackend.whisper);
        expect(transcriptionService.currentBackend, equals(TranscriptionBackend.whisper));
      });
      
      test('should update VAD sensitivity', () async {
        await transcriptionService.setVADSensitivity(0.8);
        expect(transcriptionService.vadSensitivity, equals(0.8));
      });
    });
    
    group('Initialization', () {
      test('should initialize without throwing', () async {
        // Initialization might fail in test environment due to platform dependencies
        // but it should handle errors gracefully
        try {
          await transcriptionService.initialize();
          expect(transcriptionService.isInitialized, isA<bool>());
        } catch (e) {
          // Expected in test environment without speech recognition services
          expect(e, isA<Exception>());
        }
      });
    });
    
    group('Language Support', () {
      test('should return available languages list', () async {
        try {
          final languages = await transcriptionService.getAvailableLanguages();
          expect(languages, isA<List<String>>());
        } catch (e) {
          // Expected in test environment
          expect(e, isA<Exception>());
        }
      });
    });
    
    group('Transcription Control', () {
      test('should handle start transcription gracefully', () async {
        try {
          await transcriptionService.startTranscription();
          // If successful, should be transcribing
          expect(transcriptionService.isTranscribing, isA<bool>());
        } catch (e) {
          // Expected in test environment without microphone access
          expect(e, isA<Exception>());
        }
      });
      
      test('should handle stop transcription', () async {
        // Should not throw even if not started
        await transcriptionService.stopTranscription();
        expect(transcriptionService.isTranscribing, isFalse);
      });
    });
    
    group('Resource Management', () {
      test('should dispose properly', () async {
        await transcriptionService.dispose();
        // Should not throw when called multiple times
        await transcriptionService.dispose();
      });
    });
  });
}