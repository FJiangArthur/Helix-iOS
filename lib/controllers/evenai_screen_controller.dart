import 'dart:async';
import 'package:get/get.dart';
import '../models/conversation_session.dart';
import '../models/transcript_segment.dart';
import '../services/evenai_coordinator.dart';

/// Controller for EvenAI screen state management
class EvenAIScreenController extends GetxController {
  final EvenAICoordinator _coordinator;

  // Observable state
  final isRunning = false.obs;
  final currentSession = Rx<ConversationSession?>(null);
  final currentPage = 0.obs;
  final totalPages = 0.obs;
  final displayedText = ''.obs;
  final fullTranscript = ''.obs;
  final errorMessage = Rx<String?>(null);

  StreamSubscription<TranscriptSegment>? _transcriptSubscription;

  EvenAIScreenController({
    required EvenAICoordinator coordinator,
  }) : _coordinator = coordinator;

  @override
  void onInit() {
    super.onInit();
    _setupTranscriptListener();
  }

  @override
  void onClose() {
    _transcriptSubscription?.cancel();
    super.onClose();
  }

  /// Setup transcript stream listener
  void _setupTranscriptListener() {
    // Note: In real implementation, this would listen to
    // _coordinator's transcript stream or EvenAI.textStream
    // For now, we'll update state manually through coordinator
  }

  /// Start EvenAI session
  Future<void> startSession() async {
    if (isRunning.value) return;

    try {
      errorMessage.value = null;

      await _coordinator.startSession();

      isRunning.value = true;
      currentSession.value = _coordinator.currentSession;
      fullTranscript.value = '';
    } catch (e) {
      _handleError('Failed to start EvenAI: $e');
      rethrow;
    }
  }

  /// Stop EvenAI session
  Future<void> stopSession() async {
    if (!isRunning.value) return;

    try {
      await _coordinator.stopSession();

      isRunning.value = false;
      currentSession.value = _coordinator.currentSession;

      // Save full transcript
      if (currentSession.value != null) {
        fullTranscript.value = currentSession.value!.fullTranscript;
      }
    } catch (e) {
      _handleError('Failed to stop EvenAI: $e');
      rethrow;
    }
  }

  /// Navigate to next page
  Future<void> nextPage() async {
    if (!isRunning.value) return;

    try {
      await _coordinator.nextPage();
      // Update page state
      // In real implementation, would get from display service
      if (currentPage.value < totalPages.value - 1) {
        currentPage.value++;
      }
    } catch (e) {
      _handleError('Failed to navigate: $e');
    }
  }

  /// Navigate to previous page
  Future<void> previousPage() async {
    if (!isRunning.value) return;

    try {
      await _coordinator.previousPage();
      // Update page state
      if (currentPage.value > 0) {
        currentPage.value--;
      }
    } catch (e) {
      _handleError('Failed to navigate: $e');
    }
  }

  /// Toggle session (start/stop)
  Future<void> toggleSession() async {
    if (isRunning.value) {
      await stopSession();
    } else {
      await startSession();
    }
  }

  /// Get page indicator text (e.g., "1/3")
  String get pageIndicator {
    if (totalPages.value == 0) return '';
    return '${currentPage.value + 1}/${totalPages.value}';
  }

  /// Check if can navigate to previous page
  bool get canGoBack => currentPage.value > 0;

  /// Check if can navigate to next page
  bool get canGoForward => currentPage.value < totalPages.value - 1;

  /// Handle errors
  void _handleError(String message) {
    errorMessage.value = message;
    print('EvenAIScreenController error: $message');

    // Auto-clear error after 5 seconds
    Future.delayed(const Duration(seconds: 5), () {
      if (errorMessage.value == message) {
        errorMessage.value = null;
      }
    });
  }

  /// Clear error message
  void clearError() {
    errorMessage.value = null;
  }
}
