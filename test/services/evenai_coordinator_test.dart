import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_helix/services/evenai_coordinator.dart';
import 'package:flutter_helix/services/implementations/mock_transcription_service.dart';
import 'package:flutter_helix/services/implementations/mock_glasses_display_service.dart';
import 'package:flutter_helix/services/implementations/mock_ble_service.dart';
import 'package:flutter_helix/models/conversation_session.dart';

void main() {
  late EvenAICoordinator coordinator;
  late MockTranscriptionService mockTranscription;
  late MockGlassesDisplayService mockDisplay;
  late MockBleService mockBle;

  setUp(() {
    mockTranscription = MockTranscriptionService();
    mockDisplay = MockGlassesDisplayService();
    mockBle = MockBleService();

    coordinator = EvenAICoordinator(
      transcription: mockTranscription,
      display: mockDisplay,
      ble: mockBle,
    );
  });

  tearDown(() {
    coordinator.dispose();
    mockTranscription.dispose();
    mockDisplay.dispose();
    mockBle.dispose();
  });

  group('EvenAICoordinator Session Management', () {
    test('starts in idle state', () {
      expect(coordinator.isRunning, false);
      expect(coordinator.currentSession, isNull);
    });

    test('startSession initializes conversation session', () async {
      await coordinator.startSession();

      expect(coordinator.isRunning, true);
      expect(coordinator.currentSession, isNotNull);
      expect(coordinator.currentSession!.status, SessionStatus.recording);
      expect(mockTranscription.isTranscribing, true);
    });

    test('stopSession ends conversation', () async {
      await coordinator.startSession();
      expect(coordinator.isRunning, true);

      await coordinator.stopSession();

      expect(coordinator.isRunning, false);
      expect(mockTranscription.isTranscribing, false);
      expect(coordinator.currentSession!.status, SessionStatus.completed);
      expect(coordinator.currentSession!.endTime, isNotNull);
    });

    test('cannot start session when already running', () async {
      await coordinator.startSession();
      final firstSession = coordinator.currentSession;

      await coordinator.startSession(); // Try to start again

      expect(coordinator.currentSession, same(firstSession));
    });
  });

  group('EvenAICoordinator Transcription Flow', () {
    setUp(() async {
      await coordinator.startSession();
    });

    test('displays transcribed text on glasses', () async {
      mockTranscription.simulateTranscript('Hello world');

      await Future.delayed(const Duration(milliseconds: 200));

      expect(mockDisplay.lastShownText, isNotEmpty);
      expect(mockDisplay.displayedPages, isNotEmpty);
    });

    test('accumulates final transcript segments', () async {
      mockTranscription.simulateTranscript('Hello', isFinal: true);
      await Future.delayed(const Duration(milliseconds: 100));

      mockTranscription.simulateTranscript('world', isFinal: true);
      await Future.delayed(const Duration(milliseconds: 100));

      final session = coordinator.currentSession!;
      expect(session.segments.length, 2);
      expect(session.fullTranscript, contains('Hello'));
      expect(session.fullTranscript, contains('world'));
    });

    test('shows partial transcripts without accumulating', () async {
      mockDisplay.clearHistory();

      mockTranscription.simulatePartialTranscript('Test...');
      await Future.delayed(const Duration(milliseconds: 100));

      // Should display but not add to session segments
      expect(mockDisplay.lastShownText, isNotNull);
      expect(coordinator.currentSession!.segments.length, 0);
    });

    test('paginates long text correctly', () async {
      // Generate text longer than maxCharsPerPage (40 chars)
      final longText =
          'This is a very long text that will definitely exceed forty characters and require pagination';

      mockTranscription.simulateTranscript(longText);
      await Future.delayed(const Duration(milliseconds: 200));

      expect(mockDisplay.totalPages, greaterThan(1));
      expect(mockDisplay.displayedPages[0].length, lessThanOrEqualTo(40));
    });
  });

  group('EvenAICoordinator Navigation', () {
    setUp(() async {
      await coordinator.startSession();

      // Add long text to create multiple pages
      final longText =
          'First page text here and more. Second page text continues beyond forty characters limit for testing pagination';
      mockTranscription.simulateTranscript(longText);
      await Future.delayed(const Duration(milliseconds: 200));
    });

    test('nextPage navigates to next page', () async {
      expect(mockDisplay.currentPage, 0);

      await coordinator.nextPage();

      expect(mockDisplay.currentPage, 1);
    });

    test('previousPage navigates to previous page', () async {
      await coordinator.nextPage();
      expect(mockDisplay.currentPage, 1);

      await coordinator.previousPage();

      expect(mockDisplay.currentPage, 0);
    });

    test('cannot navigate beyond page bounds', () async {
      // Try to go to previous from first page
      await coordinator.previousPage();
      expect(mockDisplay.currentPage, 0);

      // Navigate to last page
      while (mockDisplay.currentPage < mockDisplay.totalPages - 1) {
        await coordinator.nextPage();
      }

      final lastPage = mockDisplay.currentPage;

      // Try to go beyond last page
      await coordinator.nextPage();
      expect(mockDisplay.currentPage, lastPage);
    });
  });

  group('EvenAICoordinator BLE Event Integration', () {
    test('starts session on evenaiStart event', () async {
      expect(coordinator.isRunning, false);

      mockBle.simulateEvent(BleEvent.evenaiStart);
      await Future.delayed(const Duration(milliseconds: 200));

      expect(coordinator.isRunning, true);
    });

    test('stops session on evenaiRecordOver event', () async {
      await coordinator.startSession();
      expect(coordinator.isRunning, true);

      mockBle.simulateEvent(BleEvent.evenaiRecordOver);
      await Future.delayed(const Duration(milliseconds: 200));

      expect(coordinator.isRunning, false);
    });

    test('navigates pages on touchpad events', () async {
      await coordinator.startSession();

      // Add paginated content
      final longText =
          'Page one content here with enough text. Page two continues with more text beyond forty character limit';
      mockTranscription.simulateTranscript(longText);
      await Future.delayed(const Duration(milliseconds: 200));

      expect(mockDisplay.currentPage, 0);

      // Simulate touchpad down (next page)
      mockBle.simulateEvent(BleEvent.downHeader);
      await Future.delayed(const Duration(milliseconds: 100));

      expect(mockDisplay.currentPage, 1);

      // Simulate touchpad up (previous page)
      mockBle.simulateEvent(BleEvent.upHeader);
      await Future.delayed(const Duration(milliseconds: 100));

      expect(mockDisplay.currentPage, 0);
    });
  });

  group('EvenAICoordinator Edge Cases', () {
    test('handles empty transcript gracefully', () async {
      await coordinator.startSession();

      mockTranscription.simulateTranscript('');
      await Future.delayed(const Duration(milliseconds: 100));

      // Should not crash
      expect(coordinator.isRunning, true);
    });

    test('handles transcription errors gracefully', () async {
      await coordinator.startSession();

      mockTranscription.simulateError();
      await Future.delayed(const Duration(milliseconds: 100));

      // Should continue running despite error
      expect(coordinator.isRunning, true);
    });

    test('clears display when session stops', () async {
      await coordinator.startSession();
      mockTranscription.simulateTranscript('Some text');
      await Future.delayed(const Duration(milliseconds: 100));

      expect(mockDisplay.isDisplaying, true);

      await coordinator.stopSession();
      await Future.delayed(const Duration(milliseconds: 100));

      expect(mockDisplay.isDisplaying, false);
    });
  });
}
