// ABOUTME: Unit tests for real-time transcription pipeline service  
// ABOUTME: Tests configuration, state management, and basic functionality

import 'package:flutter_test/flutter_test.dart';

import '../../../lib/services/real_time_transcription_service.dart';
import '../../../lib/models/transcription_segment.dart';

void main() {
  group('RealTimeTranscriptionService Configuration', () {
    test('should create default configuration with correct values', () {
      const config = TranscriptionPipelineConfig();
      
      expect(config.audioChunkDurationMs, 100);
      expect(config.targetLatencyMs, 500);
      expect(config.enablePartialResults, true);
      expect(config.maxSessionDurationMinutes, 60);
      expect(config.maxBufferedSegments, 1000);
    });

    test('should create custom configuration', () {
      const config = TranscriptionPipelineConfig(
        audioChunkDurationMs: 50,
        targetLatencyMs: 300,
        enablePartialResults: false,
        maxSessionDurationMinutes: 120,
        maxBufferedSegments: 500,
      );
      
      expect(config.audioChunkDurationMs, 50);
      expect(config.targetLatencyMs, 300);
      expect(config.enablePartialResults, false);
      expect(config.maxSessionDurationMinutes, 120);
      expect(config.maxBufferedSegments, 500);
    });
  });

  group('TranscriptionPipelineState', () {
    test('should have correct enum values', () {
      expect(TranscriptionPipelineState.values, hasLength(5));
      expect(TranscriptionPipelineState.values, contains(TranscriptionPipelineState.idle));
      expect(TranscriptionPipelineState.values, contains(TranscriptionPipelineState.initializing));
      expect(TranscriptionPipelineState.values, contains(TranscriptionPipelineState.active));
      expect(TranscriptionPipelineState.values, contains(TranscriptionPipelineState.paused));
      expect(TranscriptionPipelineState.values, contains(TranscriptionPipelineState.error));
    });
  });

  group('TranscriptionSegment Processing', () {
    test('should create transcription segment with all properties', () {
      final now = DateTime.now();
      final startTime = now.subtract(const Duration(milliseconds: 500));
      
      final segment = TranscriptionSegment(
        text: 'Hello world',
        startTime: startTime,
        endTime: now,
        confidence: 0.85,
        speakerId: 'speaker_1',
        language: 'en-US',
        isFinal: true,
        segmentId: 'seg_123',
        processingTimeMs: 200,
        metadata: {'test': true},
      );
      
      expect(segment.text, 'Hello world');
      expect(segment.confidence, 0.85);
      expect(segment.speakerId, 'speaker_1');
      expect(segment.language, 'en-US');
      expect(segment.isFinal, true);
      expect(segment.segmentId, 'seg_123');
      expect(segment.processingTimeMs, 200);
      expect(segment.metadata['test'], true);
      expect(segment.duration.inMilliseconds, 500);
      expect(segment.isHighConfidence, true);
      expect(segment.isLowConfidence, false);
    });

    test('should identify high and low confidence segments', () {
      final now = DateTime.now();
      
      final highConfidenceSegment = TranscriptionSegment(
        text: 'High confidence text',
        startTime: now.subtract(const Duration(milliseconds: 100)),
        endTime: now,
        confidence: 0.9,
      );
      
      final lowConfidenceSegment = TranscriptionSegment(
        text: 'Low confidence text',
        startTime: now.subtract(const Duration(milliseconds: 100)),
        endTime: now,
        confidence: 0.3,
      );
      
      expect(highConfidenceSegment.isHighConfidence, true);
      expect(highConfidenceSegment.isLowConfidence, false);
      
      expect(lowConfidenceSegment.isHighConfidence, false);
      expect(lowConfidenceSegment.isLowConfidence, true);
    });

    test('should format speaker display name correctly', () {
      final now = DateTime.now();
      
      // With speaker name
      final segmentWithName = TranscriptionSegment(
        text: 'Test',
        startTime: now,
        endTime: now,
        confidence: 0.8,
        speakerId: 'speaker_1',
        speakerName: 'John Doe',
      );
      expect(segmentWithName.speakerDisplayName, 'John Doe');
      
      // With speaker ID only
      final segmentWithId = TranscriptionSegment(
        text: 'Test',
        startTime: now,
        endTime: now,
        confidence: 0.8,
        speakerId: 'speaker_1',
      );
      expect(segmentWithId.speakerDisplayName, 'Speaker speaker_1');
      
      // Without speaker info
      final segmentWithoutSpeaker = TranscriptionSegment(
        text: 'Test',
        startTime: now,
        endTime: now,
        confidence: 0.8,
      );
      expect(segmentWithoutSpeaker.speakerDisplayName, 'Unknown Speaker');
    });
  });

  group('Performance Requirements', () {
    test('default config should meet latency requirements', () {
      const config = TranscriptionPipelineConfig();
      
      // Should target <500ms latency as per requirements
      expect(config.targetLatencyMs, lessThanOrEqualTo(500));
      
      // Should enable partial results for <200ms feedback
      expect(config.enablePartialResults, true);
      
      // Should use small chunk sizes for low latency
      expect(config.audioChunkDurationMs, lessThanOrEqualTo(100));
    });
  });
}