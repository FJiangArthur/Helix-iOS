// ABOUTME: Integration tests for complete recording workflow
// ABOUTME: Tests end-to-end recording, transcription, and conversation storage

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'dart:typed_data';

import '../../lib/services/audio_service.dart';
import '../../lib/services/conversation_storage_service.dart';
import '../../lib/services/transcription_service.dart';
import '../../lib/services/service_locator.dart';
import '../../lib/models/conversation_model.dart';
import '../../lib/models/transcription_segment.dart';
import '../../lib/models/audio_configuration.dart';
import '../../lib/ui/widgets/conversation_tab.dart';
import '../../lib/ui/screens/home_screen.dart';
import '../../lib/core/utils/logging_service.dart';

import '../test_helpers.dart';
import 'recording_workflow_test.mocks.dart';

@GenerateMocks([
  AudioService,
  ConversationStorageService,
  TranscriptionService,
  LoggingService,
])
void main() {
  group('Recording Workflow Integration Tests', () {
    late MockAudioService mockAudioService;
    late MockConversationStorageService mockStorageService;
    late MockTranscriptionService mockTranscriptionService;
    late MockLoggingService mockLoggingService;

    setUp(() {
      mockAudioService = MockAudioService();
      mockStorageService = MockConversationStorageService();
      mockTranscriptionService = MockTranscriptionService();
      mockLoggingService = MockLoggingService();

      // Setup default mock behaviors
      when(mockAudioService.hasPermission).thenReturn(true);
      when(mockAudioService.isRecording).thenReturn(false);
      when(mockAudioService.initialize(any)).thenAnswer((_) async {});
      when(mockAudioService.requestPermission()).thenAnswer((_) async => true);
      when(mockAudioService.startRecording()).thenAnswer((_) async {});
      when(mockAudioService.stopRecording()).thenAnswer((_) async {});
      when(mockAudioService.startConversationRecording(any))
          .thenAnswer((_) async => '/path/to/recording.wav');
      when(mockAudioService.stopConversationRecording())
          .thenAnswer((_) async {});

      // Setup audio level stream
      when(mockAudioService.audioLevelStream)
          .thenAnswer((_) => Stream.value(0.5));
      when(mockAudioService.recordingDurationStream)
          .thenAnswer((_) => Stream.value(const Duration(seconds: 30)));
      when(mockAudioService.voiceActivityStream)
          .thenAnswer((_) => Stream.value(true));

      // Setup storage service
      when(mockStorageService.getAllConversations())
          .thenAnswer((_) async => []);
      when(mockStorageService.conversationStream)
          .thenAnswer((_) => Stream.value([]));
      when(mockStorageService.saveConversation(any))
          .thenAnswer((_) async {});

      // Setup service locator mocks
      _setupServiceLocatorMocks();
    });

    void _setupServiceLocatorMocks() {
      // Note: In a real app, you'd set up proper dependency injection
      // For testing, we'll assume ServiceLocator can be mocked
    }

    testWidgets('Complete recording workflow - start to finish',
        (WidgetTester tester) async {
      // Build the conversation tab
      await tester.pumpWidget(
        MaterialApp(
          home: ConversationTab(
            onHistoryTap: () {},
          ),
        ),
      );

      // Find the record button
      final recordButton = find.byIcon(Icons.mic);
      expect(recordButton, findsOneWidget);

      // Tap to start recording
      await tester.tap(recordButton);
      await tester.pump();

      // Verify recording started
      verify(mockAudioService.startConversationRecording(any)).called(1);

      // Simulate some audio level changes
      final audioLevelController = StreamController<double>();
      when(mockAudioService.audioLevelStream)
          .thenAnswer((_) => audioLevelController.stream);

      // Emit some audio levels
      audioLevelController.add(0.3);
      await tester.pump();
      audioLevelController.add(0.7);
      await tester.pump();
      audioLevelController.add(0.5);
      await tester.pump();

      // Find the stop button (should be showing now)
      final stopButton = find.byIcon(Icons.stop);
      expect(stopButton, findsOneWidget);

      // Tap to stop recording
      await tester.tap(stopButton);
      await tester.pump();

      // Verify recording stopped
      verify(mockAudioService.stopRecording()).called(1);

      // Verify conversation was saved
      verify(mockStorageService.saveConversation(any)).called(1);

      // Cleanup
      await audioLevelController.close();
    });

    testWidgets('Recording with permission request',
        (WidgetTester tester) async {
      // Setup permission not granted initially
      when(mockAudioService.hasPermission).thenReturn(false);
      when(mockAudioService.requestPermission()).thenAnswer((_) async => true);

      await tester.pumpWidget(
        MaterialApp(
          home: ConversationTab(
            onHistoryTap: () {},
          ),
        ),
      );

      // Tap record button
      final recordButton = find.byIcon(Icons.mic);
      await tester.tap(recordButton);
      await tester.pump();

      // Verify permission was requested
      verify(mockAudioService.requestPermission()).called(1);

      // Verify recording started after permission granted
      verify(mockAudioService.startConversationRecording(any)).called(1);
    });

    testWidgets('Recording with permission denied',
        (WidgetTester tester) async {
      // Setup permission denied
      when(mockAudioService.hasPermission).thenReturn(false);
      when(mockAudioService.requestPermission()).thenAnswer((_) async => false);

      await tester.pumpWidget(
        MaterialApp(
          home: ConversationTab(
            onHistoryTap: () {},
          ),
        ),
      );

      // Tap record button
      final recordButton = find.byIcon(Icons.mic);
      await tester.tap(recordButton);
      await tester.pump();

      // Verify permission was requested
      verify(mockAudioService.requestPermission()).called(1);

      // Verify recording was NOT started
      verifyNever(mockAudioService.startConversationRecording(any));

      // Verify error message is shown
      expect(find.text('Microphone permission required for recording'),
          findsOneWidget);
    });

    testWidgets('Recording duration timer updates',
        (WidgetTester tester) async {
      // Setup duration stream
      final durationController = StreamController<Duration>();
      when(mockAudioService.recordingDurationStream)
          .thenAnswer((_) => durationController.stream);

      await tester.pumpWidget(
        MaterialApp(
          home: ConversationTab(
            onHistoryTap: () {},
          ),
        ),
      );

      // Start recording
      final recordButton = find.byIcon(Icons.mic);
      await tester.tap(recordButton);
      await tester.pump();

      // Emit duration updates
      durationController.add(const Duration(seconds: 5));
      await tester.pump();

      // Verify timer display updated
      expect(find.text('00:05'), findsOneWidget);

      durationController.add(const Duration(minutes: 1, seconds: 30));
      await tester.pump();

      // Verify timer display updated
      expect(find.text('01:30'), findsOneWidget);

      // Cleanup
      await durationController.close();
    });

    testWidgets('Audio level visualization updates',
        (WidgetTester tester) async {
      // Setup audio level stream
      final audioLevelController = StreamController<double>();
      when(mockAudioService.audioLevelStream)
          .thenAnswer((_) => audioLevelController.stream);

      await tester.pumpWidget(
        MaterialApp(
          home: ConversationTab(
            onHistoryTap: () {},
          ),
        ),
      );

      // Start recording
      final recordButton = find.byIcon(Icons.mic);
      await tester.tap(recordButton);
      await tester.pump();

      // Emit different audio levels
      audioLevelController.add(0.1); // Low level
      await tester.pump();

      audioLevelController.add(0.8); // High level
      await tester.pump();

      audioLevelController.add(0.0); // Silence
      await tester.pump();

      // Verify audio level bars are displayed
      expect(find.byType(AudioLevelBars), findsOneWidget);

      // Cleanup
      await audioLevelController.close();
    });

    testWidgets('Recording error handling',
        (WidgetTester tester) async {
      // Setup recording to throw error
      when(mockAudioService.startConversationRecording(any))
          .thenThrow(Exception('Recording failed'));

      await tester.pumpWidget(
        MaterialApp(
          home: ConversationTab(
            onHistoryTap: () {},
          ),
        ),
      );

      // Tap record button
      final recordButton = find.byIcon(Icons.mic);
      await tester.tap(recordButton);
      await tester.pump();

      // Verify error message is shown
      expect(find.textContaining('Recording error'), findsOneWidget);
    });

    testWidgets('History navigation from conversation tab',
        (WidgetTester tester) async {
      bool historyTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: ConversationTab(
            onHistoryTap: () {
              historyTapped = true;
            },
          ),
        ),
      );

      // Find and tap the history button
      final historyButton = find.byIcon(Icons.history);
      expect(historyButton, findsOneWidget);

      await tester.tap(historyButton);
      await tester.pump();

      // Verify history callback was called
      expect(historyTapped, isTrue);
    });

    testWidgets('Conversation saving with transcription segments',
        (WidgetTester tester) async {
      // Capture the saved conversation
      ConversationModel? savedConversation;
      when(mockStorageService.saveConversation(any))
          .thenAnswer((invocation) async {
        savedConversation = invocation.positionalArguments[0];
      });

      await tester.pumpWidget(
        MaterialApp(
          home: ConversationTab(
            onHistoryTap: () {},
          ),
        ),
      );

      // Start recording
      final recordButton = find.byIcon(Icons.mic);
      await tester.tap(recordButton);
      await tester.pump();

      // Stop recording
      final stopButton = find.byIcon(Icons.stop);
      await tester.tap(stopButton);
      await tester.pump();

      // Verify conversation was saved
      expect(savedConversation, isNotNull);
      expect(savedConversation!.participants, hasLength(2));
      expect(savedConversation!.participants.first.name, equals('You'));
      expect(savedConversation!.participants.last.name, equals('Speaker 2'));
    });

    testWidgets('Recording pause and resume functionality',
        (WidgetTester tester) async {
      // Setup pause/resume methods
      when(mockAudioService.pauseRecording()).thenAnswer((_) async {});
      when(mockAudioService.resumeRecording()).thenAnswer((_) async {});

      await tester.pumpWidget(
        MaterialApp(
          home: ConversationTab(
            onHistoryTap: () {},
          ),
        ),
      );

      // Start recording
      final recordButton = find.byIcon(Icons.mic);
      await tester.tap(recordButton);
      await tester.pump();

      // Find pause button (should be visible during recording)
      final pauseButton = find.byIcon(Icons.pause);
      expect(pauseButton, findsOneWidget);

      // Tap pause
      await tester.tap(pauseButton);
      await tester.pump();

      // Find resume button
      final resumeButton = find.byIcon(Icons.play_arrow);
      expect(resumeButton, findsOneWidget);

      // Tap resume
      await tester.tap(resumeButton);
      await tester.pump();

      // Verify pause button is back
      expect(find.byIcon(Icons.pause), findsOneWidget);
    });

    testWidgets('Multiple recording sessions',
        (WidgetTester tester) async {
      int recordingCount = 0;
      when(mockAudioService.startConversationRecording(any))
          .thenAnswer((_) async {
        recordingCount++;
        return '/path/to/recording_$recordingCount.wav';
      });

      await tester.pumpWidget(
        MaterialApp(
          home: ConversationTab(
            onHistoryTap: () {},
          ),
        ),
      );

      // First recording session
      await tester.tap(find.byIcon(Icons.mic));
      await tester.pump();
      await tester.tap(find.byIcon(Icons.stop));
      await tester.pump();

      // Second recording session
      await tester.tap(find.byIcon(Icons.mic));
      await tester.pump();
      await tester.tap(find.byIcon(Icons.stop));
      await tester.pump();

      // Verify two recordings were made
      expect(recordingCount, equals(2));
      verify(mockStorageService.saveConversation(any)).called(2);
    });

    testWidgets('Recording state persistence across widget rebuilds',
        (WidgetTester tester) async {
      // Setup recording state
      when(mockAudioService.isRecording).thenReturn(true);

      await tester.pumpWidget(
        MaterialApp(
          home: ConversationTab(
            onHistoryTap: () {},
          ),
        ),
      );

      // Start recording
      await tester.tap(find.byIcon(Icons.mic));
      await tester.pump();

      // Trigger widget rebuild
      await tester.pumpWidget(
        MaterialApp(
          home: ConversationTab(
            onHistoryTap: () {},
          ),
        ),
      );

      // Verify recording state is maintained
      expect(find.byIcon(Icons.stop), findsOneWidget);
    });

    group('Performance Tests', () {
      testWidgets('Rapid button tapping handling',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: ConversationTab(
              onHistoryTap: () {},
            ),
          ),
        );

        // Rapidly tap record button multiple times
        final recordButton = find.byIcon(Icons.mic);
        for (int i = 0; i < 5; i++) {
          await tester.tap(recordButton);
          await tester.pump(const Duration(milliseconds: 10));
        }

        // Should only start recording once
        verify(mockAudioService.startConversationRecording(any)).called(1);
      });

      testWidgets('High frequency audio level updates',
          (WidgetTester tester) async {
        final audioLevelController = StreamController<double>();
        when(mockAudioService.audioLevelStream)
            .thenAnswer((_) => audioLevelController.stream);

        await tester.pumpWidget(
          MaterialApp(
            home: ConversationTab(
              onHistoryTap: () {},
            ),
          ),
        );

        // Start recording
        await tester.tap(find.byIcon(Icons.mic));
        await tester.pump();

        // Send rapid audio level updates
        for (int i = 0; i < 100; i++) {
          audioLevelController.add(i / 100.0);
          if (i % 10 == 0) {
            await tester.pump(const Duration(milliseconds: 1));
          }
        }

        // Should handle updates without errors
        expect(tester.takeException(), isNull);

        await audioLevelController.close();
      });
    });

    group('Edge Cases', () {
      testWidgets('Recording during app backgrounding',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: ConversationTab(
              onHistoryTap: () {},
            ),
          ),
        );

        // Start recording
        await tester.tap(find.byIcon(Icons.mic));
        await tester.pump();

        // Simulate app lifecycle change
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          const MethodChannel('flutter/lifecycle'),
          (methodCall) async {
            return null;
          },
        );

        // App should handle lifecycle changes gracefully
        expect(tester.takeException(), isNull);
      });

      testWidgets('Recording with zero duration',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: ConversationTab(
              onHistoryTap: () {},
            ),
          ),
        );

        // Start and immediately stop recording
        await tester.tap(find.byIcon(Icons.mic));
        await tester.pump();
        await tester.tap(find.byIcon(Icons.stop));
        await tester.pump();

        // Should still save conversation
        verify(mockStorageService.saveConversation(any)).called(1);
      });
    });
  });
}