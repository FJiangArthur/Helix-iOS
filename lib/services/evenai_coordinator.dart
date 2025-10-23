import 'dart:async';
import '../models/conversation_session.dart';
import '../models/transcript_segment.dart';
import 'interfaces/i_transcription_service.dart';
import 'interfaces/i_glasses_display_service.dart';
import 'interfaces/i_ble_service.dart';
import 'ble.dart';

/// Coordinates EvenAI conversation flow between transcription and glasses display
/// This replaces the monolithic EvenAI service with clear separation of concerns
class EvenAICoordinator {
  final ITranscriptionService _transcription;
  final IGlassesDisplayService _display;
  final IBleService _ble;

  ConversationSession? _currentSession;
  StreamSubscription<TranscriptSegment>? _transcriptSubscription;
  StreamSubscription<BleEvent>? _bleEventSubscription;

  bool _isRunning = false;
  String _accumulatedText = '';

  // Configuration
  static const int maxCharsPerPage = 40;
  static const int maxRecordingDuration = 30; // seconds

  Timer? _recordingTimer;

  EvenAICoordinator({
    required ITranscriptionService transcription,
    required IGlassesDisplayService display,
    required IBleService ble,
  })  : _transcription = transcription,
        _display = display,
        _ble = ble {
    _setupBleEventListener();
  }

  /// Whether EvenAI is currently running
  bool get isRunning => _isRunning;

  /// Current conversation session
  ConversationSession? get currentSession => _currentSession;

  /// Start EvenAI session (triggered by glasses button or manual)
  Future<void> startSession() async {
    if (_isRunning) return;

    _isRunning = true;
    _accumulatedText = '';

    // Create new conversation session
    _currentSession = ConversationSession.create().copyWith(
      status: SessionStatus.recording,
    );

    // Start transcription
    await _transcription.startTranscription();

    // Listen to transcription results
    _transcriptSubscription = _transcription.transcriptStream.listen(
      _handleTranscriptSegment,
      onError: (error) {
        print('Transcription error: $error');
      },
    );

    // Push screen to glasses (0x01 = EvenAI screen)
    // This would call Proto.pushScreen(0x01) in real implementation

    // Start recording timeout
    _startRecordingTimer();
  }

  /// Stop EvenAI session
  Future<void> stopSession() async {
    if (!_isRunning) return;

    _isRunning = false;

    // Stop transcription
    await _transcription.stopTranscription();
    await _transcriptSubscription?.cancel();
    _transcriptSubscription = null;

    // Stop recording timer
    _stopRecordingTimer();

    // Update session
    if (_currentSession != null) {
      _currentSession = _currentSession!.copyWith(
        endTime: DateTime.now(),
        status: SessionStatus.completed,
      );
    }

    // Clear glasses display
    await _display.clear();
  }

  /// Handle incoming transcript segment
  void _handleTranscriptSegment(TranscriptSegment segment) {
    if (!_isRunning) return;

    // Update accumulated text
    if (segment.isFinal) {
      _accumulatedText += ' ${segment.text}';
    } else {
      // For partial transcripts, show immediately but don't accumulate
      _updateGlassesDisplay(segment.text);
      return;
    }

    // Add to session
    if (_currentSession != null) {
      final updatedSegments = [
        ..._currentSession!.segments,
        segment,
      ];
      _currentSession = _currentSession!.copyWith(
        segments: updatedSegments,
      );
    }

    // Update glasses display
    _updateGlassesDisplay(_accumulatedText.trim());
  }

  /// Update glasses display with paginated text
  Future<void> _updateGlassesDisplay(String text) async {
    if (text.isEmpty) {
      await _display.showText('');
      return;
    }

    // Split text into pages
    final pages = _paginateText(text);

    // Show paginated content
    await _display.showPaginatedText(pages);
  }

  /// Navigate to next page (triggered by touchpad)
  Future<void> nextPage() async {
    if (!_isRunning) return;
    await _display.nextPage();
  }

  /// Navigate to previous page (triggered by touchpad)
  Future<void> previousPage() async {
    if (!_isRunning) return;
    await _display.previousPage();
  }

  /// Paginate text for glasses display
  List<String> _paginateText(String text) {
    if (text.isEmpty) return [];

    final words = text.split(' ');
    final pages = <String>[];
    var currentLine = '';

    for (final word in words) {
      if (currentLine.isEmpty) {
        currentLine = word;
      } else if ((currentLine + ' ' + word).length <= maxCharsPerPage) {
        currentLine += ' $word';
      } else {
        pages.add(currentLine);
        currentLine = word;
      }
    }

    if (currentLine.isNotEmpty) {
      pages.add(currentLine);
    }

    return pages;
  }

  /// Setup BLE event listener for glasses commands
  void _setupBleEventListener() {
    _bleEventSubscription = _ble.eventStream.listen((event) {
      switch (event) {
        case BleEvent.evenaiStart:
          startSession();
          break;
        case BleEvent.evenaiRecordOver:
          stopSession();
          break;
        case BleEvent.nextPageForEvenAI:
          nextPage();
          break;
        case BleEvent.upHeader:
          previousPage();
          break;
        case BleEvent.downHeader:
          nextPage();
          break;
        default:
          break;
      }
    });
  }

  /// Start recording timeout timer
  void _startRecordingTimer() {
    _recordingTimer?.cancel();
    _recordingTimer = Timer(
      Duration(seconds: maxRecordingDuration),
      () {
        if (_isRunning) {
          stopSession();
        }
      },
    );
  }

  /// Stop recording timer
  void _stopRecordingTimer() {
    _recordingTimer?.cancel();
    _recordingTimer = null;
  }

  /// Dispose resources
  void dispose() {
    stopSession();
    _bleEventSubscription?.cancel();
    _transcriptSubscription?.cancel();
    _recordingTimer?.cancel();
  }
}
