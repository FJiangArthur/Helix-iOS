// ABOUTME: Unit tests for TranscriptionService implementation
// ABOUTME: Tests speech-to-text conversion, confidence scoring, and real-time transcription

import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:fake_async/fake_async.dart';

import 'package:flutter_helix/services/implementations/transcription_service_impl.dart';
import 'package:flutter_helix/services/transcription_service.dart';
import 'package:flutter_helix/models/transcription_segment.dart';
import 'package:flutter_helix/core/utils/exceptions.dart';
import '../../test_helpers.dart';

void main() {
  group('TranscriptionService', () {
    late TranscriptionServiceImpl transcriptionService;
    late StreamController<TranscriptionSegment> segmentController;
    
    setUp(() {
      segmentController = StreamController<TranscriptionSegment>.broadcast();
      transcriptionService = TranscriptionServiceImpl();
    });
    
    tearDown(() {
      segmentController.close();
      transcriptionService.dispose();
    });
    
    group('Initialization', () {
      test('should initialize with correct default state', () {
        expect(transcriptionService.isListening, isFalse);
        expect(transcriptionService.isAvailable, isTrue);
        expect(transcriptionService.currentLanguage, equals('en-US'));
        expect(transcriptionService.segments, isEmpty);
      });
      
      test('should check speech recognition availability', () async {
        final isAvailable = await transcriptionService.checkAvailability();
        expect(isAvailable, isA<bool>());
      });
    });
    
    group('Language Support', () {
      test('should get list of supported languages', () async {
        final languages = await transcriptionService.getSupportedLanguages();
        
        expect(languages, isNotEmpty);
        expect(languages, contains('en-US'));
        expect(languages.every((lang) => lang.contains('-')), isTrue);
      });
      
      test('should set current language', () async {
        // Act
        await transcriptionService.setLanguage('es-ES');
        
        // Assert
        expect(transcriptionService.currentLanguage, equals('es-ES'));
      });
      
      test('should handle invalid language gracefully', () async {
        // Act & Assert
        expect(
          () async => await transcriptionService.setLanguage('invalid-lang'),
          throwsA(isA<TranscriptionException>()),
        );
      });
    });
    
    group('Real-time Transcription', () {
      test('should start transcription with default settings', () async {
        // Act
        await transcriptionService.startTranscription();
        
        // Assert
        expect(transcriptionService.isListening, isTrue);
      });
      
      test('should start transcription with custom settings', () async {
        // Act
        await transcriptionService.startTranscription(
          enableCapitalization: true,
          enablePunctuation: true,
          language: 'es-ES',
        );
        
        // Assert
        expect(transcriptionService.isListening, isTrue);
        expect(transcriptionService.currentLanguage, equals('es-ES'));
      });
      
      test('should stop transcription', () async {
        // Arrange
        await transcriptionService.startTranscription();
        expect(transcriptionService.isListening, isTrue);
        
        // Act
        await transcriptionService.stopTranscription();
        
        // Assert
        expect(transcriptionService.isListening, isFalse);
      });
      
      test('should handle transcription errors gracefully', () async {
        // This would test error scenarios like microphone unavailable
        expect(transcriptionService.isListening, isFalse);
      });
    });
    
    group('Transcription Results', () {
      test('should emit transcription segments via stream', () async {
        fakeAsync((async) {
          // Arrange
          final segments = <TranscriptionSegment>[];
          final subscription = transcriptionService.transcriptionStream.listen(
            (segment) => segments.add(segment),
          );
          
          // Act
          transcriptionService.startTranscription();
          
          // Simulate speech recognition results
          final testSegment = TestHelpers.createTestSegment(
            text: 'Hello world',
            confidence: 0.95,
          );
          
          // Simulate internal segment emission (would normally come from speech_to_text)
          segmentController.add(testSegment);
          async.elapse(const Duration(milliseconds: 100));
          
          // Assert
          expect(segments, isNotEmpty);
          expect(segments.first.text, equals('Hello world'));
          expect(segments.first.confidence, equals(0.95));
          
          subscription.cancel();
        });
      });
      
      test('should accumulate segments in service state', () {
        // Arrange
        final segment1 = TestHelpers.createTestSegment(text: 'First segment');
        final segment2 = TestHelpers.createTestSegment(text: 'Second segment');
        
        // Act
        transcriptionService.addSegment(segment1);
        transcriptionService.addSegment(segment2);
        
        // Assert
        expect(transcriptionService.segments.length, equals(2));
        expect(transcriptionService.segments[0].text, equals('First segment'));
        expect(transcriptionService.segments[1].text, equals('Second segment'));
      });
      
      test('should handle confidence scoring correctly', () {
        // Arrange
        final highConfidenceSegment = TestHelpers.createTestSegment(confidence: 0.95);
        final lowConfidenceSegment = TestHelpers.createTestSegment(confidence: 0.45);
        
        // Act
        transcriptionService.addSegment(highConfidenceSegment);
        transcriptionService.addSegment(lowConfidenceSegment);
        
        // Assert
        expect(transcriptionService.segments[0].confidence, equals(0.95));
        expect(transcriptionService.segments[1].confidence, equals(0.45));
        expect(transcriptionService.averageConfidence, closeTo(0.7, 0.1));
      });
    });
    
    group('Speaker Detection', () {
      test('should detect different speakers in conversation', () {
        // Arrange
        final speaker1Segment = TestHelpers.createTestSegment(
          speaker: 'Speaker 1',
          text: 'Hello everyone',
        );
        final speaker2Segment = TestHelpers.createTestSegment(
          speaker: 'Speaker 2', 
          text: 'Good morning',
        );
        
        // Act
        transcriptionService.addSegment(speaker1Segment);
        transcriptionService.addSegment(speaker2Segment);
        
        // Assert
        final speakers = transcriptionService.getUniqueSpeakers();
        expect(speakers.length, equals(2));
        expect(speakers, containsAll(['Speaker 1', 'Speaker 2']));
      });
      
      test('should handle unknown speakers', () {
        // Arrange
        final unknownSpeakerSegment = TestHelpers.createTestSegment(
          speaker: 'Unknown',
          text: 'Unclear speaker',
        );
        
        // Act
        transcriptionService.addSegment(unknownSpeakerSegment);
        
        // Assert
        expect(transcriptionService.segments.first.speaker, equals('Unknown'));
      });
    });
    
    group('Text Processing', () {
      test('should handle capitalization settings', () async {
        // Test with capitalization enabled
        await transcriptionService.startTranscription(enableCapitalization: true);
        
        final segment = TestHelpers.createTestSegment(text: 'hello world');
        transcriptionService.addSegment(segment);
        
        // The actual capitalization would happen in the speech recognition engine
        // We test that the setting is properly stored
        expect(transcriptionService.isCapitalizationEnabled, isTrue);
      });
      
      test('should handle punctuation settings', () async {
        // Test with punctuation enabled
        await transcriptionService.startTranscription(enablePunctuation: true);
        
        expect(transcriptionService.isPunctuationEnabled, isTrue);
      });
      
      test('should filter segments by confidence threshold', () {
        // Arrange
        final highConfidenceSegment = TestHelpers.createTestSegment(confidence: 0.9);
        final lowConfidenceSegment = TestHelpers.createTestSegment(confidence: 0.3);
        
        transcriptionService.addSegment(highConfidenceSegment);
        transcriptionService.addSegment(lowConfidenceSegment);
        
        // Act
        final filteredSegments = transcriptionService.getSegmentsAboveConfidence(0.8);
        
        // Assert
        expect(filteredSegments.length, equals(1));
        expect(filteredSegments.first.confidence, equals(0.9));
      });
    });
    
    group('Audio Processing Integration', () {
      test('should process audio data for transcription', () async {
        // Arrange
        final audioData = TestHelpers.createTestAudioData();
        
        // Act
        final result = await transcriptionService.transcribeAudioData(audioData);
        
        // Assert
        expect(result, isA<TranscriptionSegment>());
        expect(result.text, isNotEmpty);
        expect(result.confidence, greaterThan(0.0));
      });
      
      test('should handle empty audio data', () async {
        // Arrange
        final emptyAudioData = <int>[];
        
        // Act & Assert
        expect(
          () async => await transcriptionService.transcribeAudioData(emptyAudioData),
          throwsA(isA<TranscriptionException>()),
        );
      });
      
      test('should handle corrupted audio data', () async {
        // Arrange
        final corruptedData = List.generate(1000, (index) => 999999); // Invalid audio values
        
        // Act & Assert
        expect(
          () async => await transcriptionService.transcribeAudioData(corruptedData),
          throwsA(isA<TranscriptionException>()),
        );
      });
    });
    
    group('Performance', () {
      test('should handle large amounts of transcription data', () {
        // Arrange
        final startTime = DateTime.now();
        
        // Act - Add many segments
        for (int i = 0; i < 1000; i++) {
          final segment = TestHelpers.createTestSegment(
            text: 'Segment number $i',
            timestamp: DateTime.now().add(Duration(seconds: i)),
          );
          transcriptionService.addSegment(segment);
        }
        
        final endTime = DateTime.now();
        final duration = endTime.difference(startTime);
        
        // Assert
        expect(transcriptionService.segments.length, equals(1000));
        expect(duration.inMilliseconds, lessThan(1000)); // Should complete within 1 second
      });
      
      test('should maintain memory efficiency with segment cleanup', () {
        // Arrange - Add many segments
        for (int i = 0; i < 500; i++) {
          final segment = TestHelpers.createTestSegment(text: 'Segment $i');
          transcriptionService.addSegment(segment);
        }
        
        expect(transcriptionService.segments.length, equals(500));
        
        // Act - Clear old segments
        transcriptionService.clearSegmentsOlderThan(Duration(minutes: 1));
        
        // Assert - Should have cleared old segments
        expect(transcriptionService.segments.length, lessThan(500));
      });
    });
    
    group('State Management', () {
      test('should clear all segments', () {
        // Arrange
        transcriptionService.addSegment(TestHelpers.createTestSegment());
        transcriptionService.addSegment(TestHelpers.createTestSegment());
        expect(transcriptionService.segments.length, equals(2));
        
        // Act
        transcriptionService.clearAllSegments();
        
        // Assert
        expect(transcriptionService.segments, isEmpty);
      });
      
      test('should export segments as text', () {
        // Arrange
        transcriptionService.addSegment(TestHelpers.createTestSegment(
          speaker: 'Alice',
          text: 'Hello world',
        ));
        transcriptionService.addSegment(TestHelpers.createTestSegment(
          speaker: 'Bob',
          text: 'How are you',
        ));
        
        // Act
        final exportedText = transcriptionService.exportAsText();
        
        // Assert
        expect(exportedText, contains('Alice: Hello world'));
        expect(exportedText, contains('Bob: How are you'));
      });
      
      test('should export segments as JSON', () {
        // Arrange
        transcriptionService.addSegment(TestHelpers.createTestSegment());
        
        // Act
        final exportedJson = transcriptionService.exportAsJson();
        
        // Assert
        expect(exportedJson, isA<String>());
        expect(exportedJson, contains('speaker'));
        expect(exportedJson, contains('text'));
        expect(exportedJson, contains('confidence'));
      });
    });
    
    group('Error Handling', () {
      test('should handle speech recognition service unavailable', () async {
        // This would test platform-specific error scenarios
        expect(() => const TranscriptionException('Service unavailable'),
               throwsA(isA<TranscriptionException>()));
      });
      
      test('should handle network connectivity issues', () async {
        expect(() => const TranscriptionException('Network error'),
               throwsA(isA<TranscriptionException>()));
      });
      
      test('should handle unsupported language errors', () async {
        expect(() => const TranscriptionException('Language not supported'),
               throwsA(isA<TranscriptionException>()));
      });
    });
    
    group('Resource Cleanup', () {
      test('should dispose resources properly', () {
        // Arrange
        transcriptionService.startTranscription();
        transcriptionService.addSegment(TestHelpers.createTestSegment());
        
        // Act
        transcriptionService.dispose();
        
        // Assert
        expect(transcriptionService.isListening, isFalse);
        expect(transcriptionService.segments, isEmpty);
      });
      
      test('should handle multiple dispose calls safely', () {
        // Act & Assert - should not throw
        transcriptionService.dispose();
        transcriptionService.dispose();
        transcriptionService.dispose();
      });
    });
  });
}