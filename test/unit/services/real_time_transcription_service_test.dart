// ABOUTME: Unit tests for real-time transcription pipeline service
// ABOUTME: Tests audio-to-speech integration, streaming, buffering and performance metrics

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';

import '../../../lib/core/utils/logging_service.dart';
import '../../../lib/services/audio_service.dart';
import '../../../lib/services/transcription_service.dart';
import '../../../lib/services/real_time_transcription_service.dart';
import '../../../lib/models/transcription_segment.dart';

// Generate mocks
@GenerateMocks([AudioService, TranscriptionService, LoggingService])
import 'real_time_transcription_service_test.mocks.dart';

void main() {
  group('RealTimeTranscriptionService', () {
    late MockAudioService mockAudioService;
    late MockTranscriptionService mockTranscriptionService;
    late MockLoggingService mockLoggingService;
    late RealTimeTranscriptionService transcriptionService;
    
    late StreamController<Uint8List> audioStreamController;
    late StreamController<TranscriptionSegment> transcriptionStreamController;
    late StreamController<bool> voiceActivityController;

    setUp(() {
      mockAudioService = MockAudioService();
      mockTranscriptionService = MockTranscriptionService();
      mockLoggingService = MockLoggingService();
      
      // Set up stream controllers
      audioStreamController = StreamController<Uint8List>.broadcast();
      transcriptionStreamController = StreamController<TranscriptionSegment>.broadcast();
      voiceActivityController = StreamController<bool>.broadcast();
      
      // Configure mock streams
      when(mockAudioService.audioStream).thenAnswer((_) => audioStreamController.stream);
      when(mockAudioService.voiceActivityStream).thenAnswer((_) => voiceActivityController.stream);
      when(mockTranscriptionService.transcriptionStream).thenAnswer((_) => transcriptionStreamController.stream);
      
      // Configure mock properties
      when(mockTranscriptionService.isInitialized).thenReturn(true);
      when(mockTranscriptionService.hasPermissions).thenReturn(true);
      when(mockAudioService.hasPermission).thenReturn(true);
      
      transcriptionService = RealTimeTranscriptionServiceImpl(
        logger: mockLoggingService,
        audioService: mockAudioService,
        transcriptionService: mockTranscriptionService,
      );
    });

    tearDown(() {
      audioStreamController.close();
      transcriptionStreamController.close();
      voiceActivityController.close();
    });

    group('Initialization', () {
      test('should initialize successfully with default config', () async {
        const config = TranscriptionPipelineConfig();
        
        await transcriptionService.initialize(config);
        
        expect(transcriptionService.state, TranscriptionPipelineState.idle);
        expect(transcriptionService.config, config);
        verify(mockTranscriptionService.initialize()).called(1);
      });

      test('should handle initialization failure', () async {
        when(mockTranscriptionService.initialize()).thenThrow(Exception('Init failed'));
        
        const config = TranscriptionPipelineConfig();
        
        expect(
          () => transcriptionService.initialize(config),
          throwsException,
        );
        expect(transcriptionService.state, TranscriptionPipelineState.error);
      });
    });

    group('Real-time Transcription', () {
      setUp(() async {
        const config = TranscriptionPipelineConfig(
          targetLatencyMs: 500,
          enablePartialResults: true,
        );
        await transcriptionService.initialize(config);
      });

      test('should start transcription pipeline successfully', () async {
        await transcriptionService.startTranscription();
        
        expect(transcriptionService.state, TranscriptionPipelineState.active);
        expect(transcriptionService.isActive, true);
        
        verify(mockTranscriptionService.startTranscription(
          language: null,
          preferredBackend: null,
          enableCapitalization: true,
          enablePunctuation: true,
        )).called(1);
        verify(mockAudioService.startRecording()).called(1);
      });

      test('should handle audio chunks and track performance', () async {
        await transcriptionService.startTranscription();
        
        // Simulate audio chunks
        final audioData = Uint8List.fromList([1, 2, 3, 4, 5]);
        audioStreamController.add(audioData);
        
        await Future.delayed(const Duration(milliseconds: 10));
        
        final metrics = transcriptionService.getPerformanceMetrics();
        expect(metrics['processedChunks'], greaterThan(0));
      });

      test('should process partial transcription results', () async {
        await transcriptionService.startTranscription();
        
        final partialSegment = TranscriptionSegment(
          text: 'hello world',
          startTime: DateTime.now().subtract(const Duration(milliseconds: 500)),
          endTime: DateTime.now(),
          confidence: 0.8,
          isFinal: false,
        );
        
        final resultCompleter = Completer<TranscriptionSegment>();
        transcriptionService.partialTranscriptionStream.listen((segment) {
          if (!resultCompleter.isCompleted) {
            resultCompleter.complete(segment);
          }
        });
        
        transcriptionStreamController.add(partialSegment);
        
        final result = await resultCompleter.future.timeout(const Duration(seconds: 1));
        expect(result.text, contains('Hello world')); // Should be capitalized
        expect(result.text, endsWith('...')); // Should have ellipsis for partial
        expect(result.isFinal, false);
      });

      test('should process final transcription results with sentence completion', () async {
        await transcriptionService.startTranscription();
        
        final finalSegment = TranscriptionSegment(
          text: 'this is a complete sentence',
          startTime: DateTime.now().subtract(const Duration(milliseconds: 800)),
          endTime: DateTime.now(),
          confidence: 0.9,
          isFinal: true,
        );
        
        final resultCompleter = Completer<TranscriptionSegment>();
        transcriptionService.transcriptionStream.listen((segment) {
          if (!resultCompleter.isCompleted) {
            resultCompleter.complete(segment);
          }
        });
        
        transcriptionStreamController.add(finalSegment);
        
        final result = await resultCompleter.future.timeout(const Duration(seconds: 1));
        expect(result.text, 'This is a complete sentence.'); // Capitalized with period
        expect(result.isFinal, true);
        expect(result.metadata['processedForCompletion'], true);
      });
    });

    group('Performance Optimization', () {
      setUp(() async {
        const config = TranscriptionPipelineConfig(
          targetLatencyMs: 500,
          enablePartialResults: true,
        );
        await transcriptionService.initialize(config);
        await transcriptionService.startTranscription();
      });

      test('should track latency measurements', () async {
        // Simulate audio chunk followed by transcription result
        audioStreamController.add(Uint8List.fromList([1, 2, 3]));
        
        await Future.delayed(const Duration(milliseconds: 100));
        
        final segment = TranscriptionSegment(
          text: 'test',
          startTime: DateTime.now().subtract(const Duration(milliseconds: 200)),
          endTime: DateTime.now(),
          confidence: 0.8,
          isFinal: true,
        );
        
        final latencyCompleter = Completer<int>();
        transcriptionService.latencyStream.listen((latency) {
          if (!latencyCompleter.isCompleted) {
            latencyCompleter.complete(latency);
          }
        });
        
        transcriptionStreamController.add(segment);
        
        final latency = await latencyCompleter.future.timeout(const Duration(seconds: 1));
        expect(latency, lessThan(1000)); // Should be reasonable
      });

      test('should maintain performance metrics', () async {
        // Process several chunks
        for (int i = 0; i < 5; i++) {
          audioStreamController.add(Uint8List.fromList([i, i + 1, i + 2]));
          await Future.delayed(const Duration(milliseconds: 20));
        }
        
        final metrics = transcriptionService.getPerformanceMetrics();
        expect(metrics['processedChunks'], 5);
        expect(metrics['droppedChunks'], 0);
        expect(metrics['targetLatencyMs'], 500);
        expect(metrics, containsPair('sessionDurationMs', greaterThan(0)));
      });

      test('should manage memory efficiently', () async {
        const config = TranscriptionPipelineConfig(
          maxBufferedSegments: 3, // Small buffer for testing
        );
        await transcriptionService.initialize(config);
        await transcriptionService.startTranscription();
        
        // Add more segments than buffer size
        for (int i = 0; i < 5; i++) {
          final segment = TranscriptionSegment(
            text: 'segment $i',
            startTime: DateTime.now().subtract(Duration(milliseconds: 100 * (5 - i))),
            endTime: DateTime.now().subtract(Duration(milliseconds: 50 * (5 - i))),
            confidence: 0.8,
            isFinal: true,
          );
          transcriptionStreamController.add(segment);
          await Future.delayed(const Duration(milliseconds: 10));
        }
        
        final segments = transcriptionService.getCurrentSegments();
        expect(segments.length, lessThanOrEqualTo(3)); // Should not exceed buffer size
      });
    });

    group('Error Handling', () {
      setUp(() async {
        const config = TranscriptionPipelineConfig();
        await transcriptionService.initialize(config);
      });

      test('should handle transcription errors gracefully', () async {
        await transcriptionService.startTranscription();
        
        // Simulate transcription error
        transcriptionStreamController.addError(Exception('Transcription failed'));
        
        await Future.delayed(const Duration(milliseconds: 100));
        
        expect(transcriptionService.state, TranscriptionPipelineState.error);
      });

      test('should handle audio stream errors gracefully', () async {
        await transcriptionService.startTranscription();
        
        // Simulate audio error
        audioStreamController.addError(Exception('Audio failed'));
        
        await Future.delayed(const Duration(milliseconds: 100));
        
        expect(transcriptionService.state, TranscriptionPipelineState.error);
      });
    });

    group('Session Management', () {
      test('should clear session data correctly', () async {
        const config = TranscriptionPipelineConfig();
        await transcriptionService.initialize(config);
        await transcriptionService.startTranscription();
        
        // Add some data
        audioStreamController.add(Uint8List.fromList([1, 2, 3]));
        await Future.delayed(const Duration(milliseconds: 10));
        
        await transcriptionService.clearSession();
        
        final segments = transcriptionService.getCurrentSegments();
        expect(segments, isEmpty);
        
        final metrics = transcriptionService.getPerformanceMetrics();
        expect(metrics['processedChunks'], 0);
        expect(metrics['droppedChunks'], 0);
      });

      test('should stop transcription cleanly', () async {
        const config = TranscriptionPipelineConfig();
        await transcriptionService.initialize(config);
        await transcriptionService.startTranscription();
        
        expect(transcriptionService.isActive, true);
        
        await transcriptionService.stopTranscription();
        
        expect(transcriptionService.state, TranscriptionPipelineState.idle);
        expect(transcriptionService.isActive, false);
        
        verify(mockAudioService.stopRecording()).called(1);
        verify(mockTranscriptionService.stopTranscription()).called(1);
      });
    });
  });
}