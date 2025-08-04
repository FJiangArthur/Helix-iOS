// ABOUTME: Unit tests for TranscriptionService implementation
// ABOUTME: Tests speech-to-text conversion, confidence scoring, and real-time transcription

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
    
    group('Initialization', () {
      test('should initialize with correct default state', () {
        expect(transcriptionService.isTranscribing, isFalse);
        expect(transcriptionService.isInitialized, isFalse);
        expect(transcriptionService.currentLanguage, equals('en-US'));
        expect(transcriptionService.hasPermissions, isFalse);
        expect(transcriptionService.currentBackend, equals(TranscriptionBackend.device));
        expect(transcriptionService.currentQuality, equals(TranscriptionQuality.standard));
        expect(transcriptionService.vadSensitivity, equals(0.5));
      });
      
      test('should have transcription and confidence streams', () {
        expect(transcriptionService.transcriptionStream, isNotNull);
        expect(transcriptionService.confidenceStream, isNotNull);
      });
    });
    
    group('Configuration', () {
      test('should allow setting VAD sensitivity', () async {
        await transcriptionService.setVADSensitivity(0.8);
        expect(transcriptionService.vadSensitivity, equals(0.8));
      });
      
      test('should clamp VAD sensitivity to valid range', () async {
        await transcriptionService.setVADSensitivity(1.5);
        expect(transcriptionService.vadSensitivity, equals(1.0));
        
        await transcriptionService.setVADSensitivity(-0.5);
        expect(transcriptionService.vadSensitivity, equals(0.0));
      });
      
      test('should allow setting transcription quality', () async {
        await transcriptionService.configureQuality(TranscriptionQuality.high);
        expect(transcriptionService.currentQuality, equals(TranscriptionQuality.high));
      });
      
      test('should allow setting transcription backend', () async {
        await transcriptionService.configureBackend(TranscriptionBackend.whisper);
        expect(transcriptionService.currentBackend, equals(TranscriptionBackend.whisper));
      });
    });
    
    group('State Management', () {
      test('should track last confidence score', () {
        final initialConfidence = transcriptionService.getLastConfidence();
        expect(initialConfidence, equals(0.0));
      });
      
      test('should not allow transcription when not initialized', () async {
        expect(() async => await transcriptionService.startTranscription(), 
               throwsA(isA<Exception>()));
      });
    });
  });
}