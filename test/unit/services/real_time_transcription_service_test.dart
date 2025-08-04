// ABOUTME: Unit tests for RealTimeTranscriptionService implementation
// ABOUTME: Tests real-time transcription pipeline, performance monitoring, and memory management

import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';

import 'package:flutter_helix/services/real_time_transcription_service.dart';
import 'package:flutter_helix/services/audio_service.dart';
import 'package:flutter_helix/services/transcription_service.dart';
import 'package:flutter_helix/models/transcription_segment.dart';
import 'package:flutter_helix/core/utils/logging_service.dart';

@GenerateMocks([AudioService, TranscriptionService, LoggingService])
import 'real_time_transcription_service_test.mocks.dart';

void main() {
  group('RealTimeTranscriptionService', () {
    late RealTimeTranscriptionServiceImpl service;
    late MockAudioService mockAudioService;
    late MockTranscriptionService mockTranscriptionService;
    late MockLoggingService mockLoggingService;
    
    late StreamController<Uint8List> audioStreamController;
    late StreamController<TranscriptionSegment> transcriptionStreamController;

    setUp(() {
      mockAudioService = MockAudioService();
      mockTranscriptionService = MockTranscriptionService();
      mockLoggingService = MockLoggingService();
      
      audioStreamController = StreamController<Uint8List>.broadcast();
      transcriptionStreamController = StreamController<TranscriptionSegment>.broadcast();
      
      // Setup mock streams
      when(mockAudioService.audioStream).thenAnswer((_) => audioStreamController.stream);
      when(mockTranscriptionService.transcriptionStream).thenAnswer((_) => transcriptionStreamController.stream);
      
      // Setup mock properties
      when(mockAudioService.hasPermission).thenReturn(true);
      when(mockTranscriptionService.isInitialized).thenReturn(true);
      
      service = RealTimeTranscriptionServiceImpl(
        logger: mockLoggingService,
        audioService: mockAudioService,
        transcriptionService: mockTranscriptionService,
      );
    });

    tearDown(() async {
      await audioStreamController.close();
      await transcriptionStreamController.close();
      await service.dispose();
    });

    group('Initialization', () {
      test('should initialize with correct default state', () {
        expect(service.state, equals(TranscriptionPipelineState.idle));
        expect(service.isActive, isFalse);
      });

      test('should initialize with custom configuration', () async {
        const config = TranscriptionPipelineConfig(
          audioChunkDurationMs: 50,
          targetLatencyMs: 300,
          enablePartialResults: true,
        );

        await service.initialize(config);

        expect(service.config.audioChunkDurationMs, equals(50));
        expect(service.config.targetLatencyMs, equals(300));
        expect(service.config.enablePartialResults, isTrue);
      });

      test('should fail initialization if audio permission denied', () async {
        when(mockAudioService.hasPermission).thenReturn(false);
        when(mockAudioService.requestPermission()).thenAnswer((_) async => false);

        const config = TranscriptionPipelineConfig();
        
        expect(
          () async => await service.initialize(config),
          throwsA(isA<Exception>()),
        );
      });

      test('should fail initialization if transcription service not available', () async {
        when(mockTranscriptionService.isInitialized).thenReturn(false);
        when(mockTranscriptionService.initialize()).thenThrow(Exception('Service not available'));

        const config = TranscriptionPipelineConfig();
        
        expect(
          () async => await service.initialize(config),
          throwsA(isA<Exception>()),
        );
      });
    });

    group('State Management', () {
      test('should transition states correctly during transcription lifecycle', () async {
        const config = TranscriptionPipelineConfig();
        await service.initialize(config);

        expect(service.state, equals(TranscriptionPipelineState.idle));

        // Mock successful transcription start
        when(mockTranscriptionService.startTranscription()).thenAnswer((_) => Future.value());
        when(mockAudioService.startRecording()).thenAnswer((_) => Future.value());

        await service.startTranscription();
        expect(service.state, equals(TranscriptionPipelineState.active));
        expect(service.isActive, isTrue);

        // Mock successful transcription stop
        when(mockTranscriptionService.stopTranscription()).thenAnswer((_) => Future.value());
        when(mockAudioService.stopRecording()).thenAnswer((_) => Future.value());

        await service.stopTranscription();
        expect(service.state, equals(TranscriptionPipelineState.idle));
        expect(service.isActive, isFalse);
      });

      test('should emit state changes via stream', () async {
        const config = TranscriptionPipelineConfig();
        await service.initialize(config);

        final stateChanges = <TranscriptionPipelineState>[];
        final subscription = service.stateStream.listen((state) {
          stateChanges.add(state);
        });

        when(mockTranscriptionService.startTranscription()).thenAnswer((_) => Future.value());
        when(mockAudioService.startRecording()).thenAnswer((_) => Future.value());

        await service.startTranscription();

        expect(stateChanges, contains(TranscriptionPipelineState.active));
        
        await subscription.cancel();
      });
    });

    group('Transcription Processing', () {
      test('should process final transcription segments', () async {
        const config = TranscriptionPipelineConfig();
        await service.initialize(config);

        when(mockTranscriptionService.startTranscription()).thenAnswer((_) => Future.value());
        when(mockAudioService.startRecording()).thenAnswer((_) => Future.value());

        await service.startTranscription();

        final receivedSegments = <TranscriptionSegment>[];
        final subscription = service.transcriptionStream.listen((segment) {
          receivedSegments.add(segment);
        });

        // Simulate transcription result
        final testSegment = TranscriptionSegment(
          text: 'hello world',
          startTime: DateTime.now(),
          endTime: DateTime.now().add(const Duration(seconds: 1)),
          confidence: 0.95,
          isFinal: true,
        );

        transcriptionStreamController.add(testSegment);
        await Future.delayed(const Duration(milliseconds: 50));

        expect(receivedSegments, hasLength(1));
        expect(receivedSegments.first.text, equals('Hello world.')); // Should be capitalized and punctuated
        expect(receivedSegments.first.confidence, equals(0.95));

        await subscription.cancel();
      });

      test('should process partial transcription segments', () async {
        const config = TranscriptionPipelineConfig(enablePartialResults: true);
        await service.initialize(config);

        when(mockTranscriptionService.startTranscription()).thenAnswer((_) => Future.value());
        when(mockAudioService.startRecording()).thenAnswer((_) => Future.value());

        await service.startTranscription();

        final receivedPartials = <TranscriptionSegment>[];
        final subscription = service.partialTranscriptionStream.listen((segment) {
          receivedPartials.add(segment);
        });

        // Simulate partial transcription result
        final partialSegment = TranscriptionSegment(
          text: 'hello wor',
          startTime: DateTime.now(),
          endTime: DateTime.now().add(const Duration(milliseconds: 500)),
          confidence: 0.7,
          isFinal: false,
        );

        transcriptionStreamController.add(partialSegment);
        await Future.delayed(const Duration(milliseconds: 50));

        expect(receivedPartials, hasLength(1));
        expect(receivedPartials.first.text, equals('Hello wor...')); // Should have ellipsis
        expect(receivedPartials.first.isFinal, isFalse);

        await subscription.cancel();
      });

      test('should enhance text with sentence completion and punctuation', () async {
        const config = TranscriptionPipelineConfig();
        await service.initialize(config);

        when(mockTranscriptionService.startTranscription()).thenAnswer((_) => Future.value());
        when(mockAudioService.startRecording()).thenAnswer((_) => Future.value());

        await service.startTranscription();

        final receivedSegments = <TranscriptionSegment>[];
        final subscription = service.transcriptionStream.listen((segment) {
          receivedSegments.add(segment);
        });

        // Test various text processing scenarios
        final testCases = [
          ('hello world', 'Hello world.'),
          ('how are you', 'How are you.'),
          ('good morning!', 'Good morning!'), // Already has punctuation
          ('yes', 'Yes'), // Too short for period
        ];

        for (final (input, expected) in testCases) {
          final segment = TranscriptionSegment(
            text: input,
            startTime: DateTime.now(),
            endTime: DateTime.now().add(const Duration(seconds: 1)),
            confidence: 0.9,
            isFinal: true,
          );

          transcriptionStreamController.add(segment);
          await Future.delayed(const Duration(milliseconds: 50));
        }

        expect(receivedSegments, hasLength(4));
        expect(receivedSegments[0].text, equals('Hello world.'));
        expect(receivedSegments[1].text, equals('How are you.'));
        expect(receivedSegments[2].text, equals('Good morning!'));
        expect(receivedSegments[3].text, equals('Yes'));

        await subscription.cancel();
      });
    });

    group('Performance Monitoring', () {
      test('should track latency measurements', () async {
        const config = TranscriptionPipelineConfig(targetLatencyMs: 500);
        await service.initialize(config);

        when(mockTranscriptionService.startTranscription()).thenAnswer((_) => Future.value());
        when(mockAudioService.startRecording()).thenAnswer((_) => Future.value());

        await service.startTranscription();

        final latencies = <int>[];
        final subscription = service.latencyStream.listen((latency) {
          latencies.add(latency);
        });

        // Simulate audio chunk processing
        audioStreamController.add(Uint8List.fromList([1, 2, 3, 4]));
        await Future.delayed(const Duration(milliseconds: 100));

        // Simulate transcription result
        final segment = TranscriptionSegment(
          text: 'test',
          startTime: DateTime.now(),
          endTime: DateTime.now(),
          confidence: 0.8,
          isFinal: true,
        );

        transcriptionStreamController.add(segment);
        await Future.delayed(const Duration(milliseconds: 50));

        expect(latencies, isNotEmpty);
        expect(latencies.first, greaterThan(0));

        await subscription.cancel();
      });

      test('should provide performance metrics', () async {
        const config = TranscriptionPipelineConfig();
        await service.initialize(config);

        final metrics = service.getPerformanceMetrics();

        expect(metrics, isA<Map<String, dynamic>>());
        expect(metrics.keys, containsAll([
          'sessionDurationMs',
          'processedChunks',
          'droppedChunks',
          'averageLatencyMs',
          'currentSegments',
          'processingRate',
          'totalWordsProcessed',
          'bufferedWords',
        ]));
      });
    });

    group('Memory Management', () {
      test('should manage segment buffer size', () async {
        const config = TranscriptionPipelineConfig(maxBufferedSegments: 5);
        await service.initialize(config);

        when(mockTranscriptionService.startTranscription()).thenAnswer((_) => Future.value());
        when(mockAudioService.startRecording()).thenAnswer((_) => Future.value());

        await service.startTranscription();

        // Add more segments than the buffer limit
        for (int i = 0; i < 10; i++) {
          final segment = TranscriptionSegment(
            text: 'segment $i',
            startTime: DateTime.now(),
            endTime: DateTime.now(),
            confidence: 0.8,
            isFinal: true,
          );
          transcriptionStreamController.add(segment);
          await Future.delayed(const Duration(milliseconds: 10));
        }

        await Future.delayed(const Duration(milliseconds: 100));

        final currentSegments = service.getCurrentSegments();
        expect(currentSegments.length, lessThanOrEqualTo(5));
      });

      test('should clear session data properly', () async {
        const config = TranscriptionPipelineConfig();
        await service.initialize(config);

        when(mockTranscriptionService.startTranscription()).thenAnswer((_) => Future.value());
        when(mockAudioService.startRecording()).thenAnswer((_) => Future.value());

        await service.startTranscription();

        // Add some segments
        final segment = TranscriptionSegment(
          text: 'test segment',
          startTime: DateTime.now(),
          endTime: DateTime.now(),
          confidence: 0.8,
          isFinal: true,
        );
        transcriptionStreamController.add(segment);
        await Future.delayed(const Duration(milliseconds: 50));

        expect(service.getCurrentSegments(), isNotEmpty);

        await service.clearSession();

        expect(service.getCurrentSegments(), isEmpty);
        final metrics = service.getPerformanceMetrics();
        expect(metrics['totalWordsProcessed'], equals(0));
      });
    });

    group('Audio Processing', () {
      test('should handle audio stream data', () async {
        const config = TranscriptionPipelineConfig();
        await service.initialize(config);

        when(mockTranscriptionService.startTranscription()).thenAnswer((_) => Future.value());
        when(mockAudioService.startRecording()).thenAnswer((_) => Future.value());

        await service.startTranscription();

        // Simulate audio data
        final audioData = Uint8List.fromList(List.generate(1024, (i) => i % 256));
        audioStreamController.add(audioData);

        await Future.delayed(const Duration(milliseconds: 50));

        final metrics = service.getPerformanceMetrics();
        expect(metrics['processedChunks'], greaterThan(0));
      });

      test('should handle audio stream errors gracefully', () async {
        const config = TranscriptionPipelineConfig();
        await service.initialize(config);

        when(mockTranscriptionService.startTranscription()).thenAnswer((_) => Future.value());
        when(mockAudioService.startRecording()).thenAnswer((_) => Future.value());

        await service.startTranscription();

        // Simulate audio stream error
        audioStreamController.addError(Exception('Audio stream error'));

        await Future.delayed(const Duration(milliseconds: 50));

        expect(service.state, equals(TranscriptionPipelineState.error));
      });
    });

    group('Language and Backend Configuration', () {
      test('should pass language configuration to transcription service', () async {
        const config = TranscriptionPipelineConfig();
        await service.initialize(config);

        when(mockTranscriptionService.startTranscription(
          language: anyNamed('language'),
          preferredBackend: anyNamed('preferredBackend'),
          enableCapitalization: anyNamed('enableCapitalization'),
          enablePunctuation: anyNamed('enablePunctuation'),
        )).thenAnswer((_) => Future.value());
        when(mockAudioService.startRecording()).thenAnswer((_) => Future.value());

        await service.startTranscription(
          language: 'es-ES',
          preferredBackend: TranscriptionBackend.whisper,
        );

        verify(mockTranscriptionService.startTranscription(
          language: 'es-ES',
          preferredBackend: TranscriptionBackend.whisper,
          enableCapitalization: true,
          enablePunctuation: true,
        )).called(1);
      });
    });

    group('Error Handling', () {
      test('should handle transcription service errors', () async {
        const config = TranscriptionPipelineConfig();
        await service.initialize(config);

        when(mockTranscriptionService.startTranscription()).thenAnswer((_) => Future.value());
        when(mockAudioService.startRecording()).thenAnswer((_) => Future.value());

        await service.startTranscription();

        // Simulate transcription error
        transcriptionStreamController.addError(Exception('Transcription error'));

        await Future.delayed(const Duration(milliseconds: 50));

        expect(service.state, equals(TranscriptionPipelineState.error));
      });

      test('should handle service initialization failures', () async {
        when(mockTranscriptionService.initialize()).thenThrow(Exception('Init failed'));

        const config = TranscriptionPipelineConfig();
        
        expect(
          () async => await service.initialize(config),
          throwsA(isA<Exception>()),
        );
      });
    });

    group('Resource Cleanup', () {
      test('should dispose resources properly', () async {
        const config = TranscriptionPipelineConfig();
        await service.initialize(config);

        when(mockTranscriptionService.startTranscription()).thenAnswer((_) => Future.value());
        when(mockAudioService.startRecording()).thenAnswer((_) => Future.value());

        await service.startTranscription();

        when(mockTranscriptionService.stopTranscription()).thenAnswer((_) => Future.value());
        when(mockAudioService.stopRecording()).thenAnswer((_) => Future.value());

        await service.dispose();

        expect(service.state, equals(TranscriptionPipelineState.idle));
      });

      test('should handle multiple dispose calls safely', () async {
        const config = TranscriptionPipelineConfig();
        await service.initialize(config);

        // Should not throw
        await service.dispose();
        await service.dispose();
        await service.dispose();
      });
    });

    group('Pause and Resume', () {
      test('should pause and resume transcription', () async {
        const config = TranscriptionPipelineConfig();
        await service.initialize(config);

        when(mockTranscriptionService.startTranscription()).thenAnswer((_) => Future.value());
        when(mockAudioService.startRecording()).thenAnswer((_) => Future.value());
        when(mockTranscriptionService.pauseTranscription()).thenAnswer((_) => Future.value());
        when(mockAudioService.pauseRecording()).thenAnswer((_) => Future.value());
        when(mockTranscriptionService.resumeTranscription()).thenAnswer((_) => Future.value());
        when(mockAudioService.resumeRecording()).thenAnswer((_) => Future.value());

        await service.startTranscription();
        expect(service.state, equals(TranscriptionPipelineState.active));

        await service.pauseTranscription();
        expect(service.state, equals(TranscriptionPipelineState.paused));

        await service.resumeTranscription();
        expect(service.state, equals(TranscriptionPipelineState.active));
      });
    });
  });
}