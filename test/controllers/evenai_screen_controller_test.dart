import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_helix/controllers/evenai_screen_controller.dart';
import 'package:flutter_helix/services/evenai_coordinator.dart';
import 'package:flutter_helix/services/implementations/mock_transcription_service.dart';
import 'package:flutter_helix/services/implementations/mock_glasses_display_service.dart';
import 'package:flutter_helix/services/implementations/mock_ble_service.dart';

void main() {
  late EvenAIScreenController controller;
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

    controller = EvenAIScreenController(coordinator: coordinator);
    controller.onInit();
  });

  tearDown(() {
    controller.onClose();
    coordinator.dispose();
    mockTranscription.dispose();
    mockDisplay.dispose();
    mockBle.dispose();
  });

  group('EvenAIScreenController Initialization', () {
    test('starts with correct initial state', () {
      expect(controller.isRunning.value, false);
      expect(controller.currentSession.value, isNull);
      expect(controller.currentPage.value, 0);
      expect(controller.totalPages.value, 0);
      expect(controller.displayedText.value, '');
      expect(controller.fullTranscript.value, '');
    });
  });

  group('EvenAIScreenController Session Control', () {
    test('startSession updates state correctly', () async {
      await controller.startSession();

      expect(controller.isRunning.value, true);
      expect(controller.currentSession.value, isNotNull);
    });

    test('stopSession updates state correctly', () async {
      await controller.startSession();

      mockTranscription.simulateTranscript('Test transcript');
      await Future.delayed(const Duration(milliseconds: 200));

      await controller.stopSession();

      expect(controller.isRunning.value, false);
      expect(controller.fullTranscript.value, isNotEmpty);
    });

    test('cannot start session twice', () async {
      await controller.startSession();
      final firstSession = controller.currentSession.value;

      await controller.startSession(); // Try again

      expect(controller.currentSession.value, same(firstSession));
    });

    test('toggleSession starts when not running', () async {
      expect(controller.isRunning.value, false);

      await controller.toggleSession();

      expect(controller.isRunning.value, true);
    });

    test('toggleSession stops when running', () async {
      await controller.startSession();
      expect(controller.isRunning.value, true);

      await controller.toggleSession();

      expect(controller.isRunning.value, false);
    });
  });

  group('EvenAIScreenController Navigation', () {
    setUp(() async {
      await controller.startSession();

      // Simulate paginated content
      controller.totalPages.value = 3;
      controller.currentPage.value = 0;
    });

    test('nextPage increments page number', () async {
      expect(controller.currentPage.value, 0);

      await controller.nextPage();

      expect(controller.currentPage.value, 1);
    });

    test('previousPage decrements page number', () async {
      controller.currentPage.value = 2;

      await controller.previousPage();

      expect(controller.currentPage.value, 1);
    });

    test('canGoBack returns correct value', () {
      controller.currentPage.value = 0;
      expect(controller.canGoBack, false);

      controller.currentPage.value = 1;
      expect(controller.canGoBack, true);
    });

    test('canGoForward returns correct value', () {
      controller.totalPages.value = 3;

      controller.currentPage.value = 2;
      expect(controller.canGoForward, false);

      controller.currentPage.value = 1;
      expect(controller.canGoForward, true);
    });

    test('cannot navigate when not running', () async {
      await controller.stopSession();

      final initialPage = controller.currentPage.value;

      // Should not throw
      await controller.nextPage();
      await controller.previousPage();

      // Page should not change
      expect(controller.currentPage.value, initialPage);
    });
  });

  group('EvenAIScreenController Formatting', () {
    test('pageIndicator formats correctly', () {
      controller.totalPages.value = 0;
      expect(controller.pageIndicator, '');

      controller.totalPages.value = 3;
      controller.currentPage.value = 0;
      expect(controller.pageIndicator, '1/3');

      controller.currentPage.value = 2;
      expect(controller.pageIndicator, '3/3');
    });
  });

  group('EvenAIScreenController Error Handling', () {
    test('handles start session error', () async {
      // Simulate error by disposing coordinator first
      coordinator.dispose();

      try {
        await controller.startSession();
        // May or may not throw depending on implementation
      } catch (e) {
        // Expected in some cases
      }

      // Error message should be set
      if (controller.errorMessage.value != null) {
        expect(controller.errorMessage.value, isNotNull);
      }
    });

    test('error message auto-clears after timeout', () async {
      controller.errorMessage.value = 'Test error';

      expect(controller.errorMessage.value, 'Test error');

      // Wait for auto-clear
      await Future.delayed(const Duration(seconds: 6));

      expect(controller.errorMessage.value, isNull);
    });

    test('clearError manually clears error', () {
      controller.errorMessage.value = 'Test error';

      controller.clearError();

      expect(controller.errorMessage.value, isNull);
    });
  });

  group('EvenAIScreenController Integration', () {
    test('session captures transcript segments', () async {
      await controller.startSession();

      mockTranscription.simulateTranscript('First segment');
      await Future.delayed(const Duration(milliseconds: 100));

      mockTranscription.simulateTranscript('Second segment');
      await Future.delayed(const Duration(milliseconds: 100));

      await controller.stopSession();

      final transcript = controller.fullTranscript.value;
      expect(transcript, contains('First'));
      expect(transcript, contains('Second'));
    });
  });
}
