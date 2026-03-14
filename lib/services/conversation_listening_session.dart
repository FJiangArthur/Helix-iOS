import 'dart:async';

import 'package:flutter/services.dart';

import '../ble_manager.dart';
import '../utils/app_logger.dart';
import 'conversation_engine.dart';
import 'settings_manager.dart';

class ConversationListeningSession {
  ConversationListeningSession._({
    Stream<dynamic>? speechEvents,
    Future<dynamic> Function(String method, [dynamic arguments])? invokeMethod,
    ConversationEngine? engine,
    Duration finalizationTimeout = const Duration(milliseconds: 1500),
  }) : _speechEvents =
           speechEvents ??
           const EventChannel(
             _eventSpeechRecognize,
           ).receiveBroadcastStream(_eventSpeechRecognize),
       _invokeMethod = invokeMethod ?? BleManager.invokeMethod,
       _engine = engine ?? ConversationEngine.instance,
       _finalizationTimeout = finalizationTimeout;

  static ConversationListeningSession? _instance;
  static ConversationListeningSession get instance =>
      _instance ??= ConversationListeningSession._();

  static const _eventSpeechRecognize = 'eventSpeechRecognize';
  factory ConversationListeningSession.test({
    required Stream<dynamic> speechEvents,
    Future<dynamic> Function(String method, [dynamic arguments])? invokeMethod,
    ConversationEngine? engine,
    Duration finalizationTimeout = const Duration(milliseconds: 50),
  }) {
    return ConversationListeningSession._(
      speechEvents: speechEvents,
      invokeMethod: invokeMethod,
      engine: engine,
      finalizationTimeout: finalizationTimeout,
    );
  }

  final Stream<dynamic> _speechEvents;
  final Future<dynamic> Function(String method, [dynamic arguments])
  _invokeMethod;
  final ConversationEngine _engine;
  final Duration _finalizationTimeout;
  final StreamController<String?> _errorController =
      StreamController<String?>.broadcast();

  StreamSubscription? _speechSubscription;
  Completer<void>? _speechFinalizationCompleter;
  TranscriptSource _source = TranscriptSource.phone;
  String _latestTranscript = '';
  String _lastFinalizedTranscript = '';
  bool _isRunning = false;
  String? _currentError;

  bool get isRunning => _isRunning;
  TranscriptSource get source => _source;
  Stream<String?> get errorStream => _errorController.stream;
  String? get currentError => _currentError;

  Future<void> startSession({required TranscriptSource source}) async {
    if (_isRunning) {
      await stopSession();
    }

    _source = source;
    _latestTranscript = '';
    _lastFinalizedTranscript = '';
    _speechFinalizationCompleter = null;
    _publishError(null);
    _engine.start(source: source);

    await _speechSubscription?.cancel();
    _speechSubscription = _speechEvents.listen(
      (event) {
        final payload = Map<String, dynamic>.from(event as Map);
        final text = (payload['script'] as String? ?? '').trim();
        final isFinal = payload['isFinal'] == true;
        final error = (payload['error'] as String?)?.trim();

        if (text.isNotEmpty) {
          _ensureSpeechFinalizationCompleter();
          _latestTranscript = text;
          _publishError(null);
          _engine.onTranscriptionUpdate(text);
        }

        if (error != null && error.isNotEmpty) {
          appLogger.e('Speech recognition error: $error');
          _publishError(error);
        }

        if (isFinal) {
          finalizePendingTranscript(
            overrideText: text.isNotEmpty ? text : _latestTranscript,
          );
        }
      },
      onError: (error) {
        appLogger.e('Speech recognition stream error', error: error);
        _publishError('Speech recognition stream error.');
        finalizePendingTranscript();
      },
    );

    final langCode = _getLanguageCode();
    try {
      await _invokeMethod('startEvenAI', {
        'language': langCode,
        'source': source == TranscriptSource.glasses ? 'glasses' : 'microphone',
      });
      _isRunning = true;
    } on PlatformException catch (error) {
      await _speechSubscription?.cancel();
      _speechSubscription = null;
      _isRunning = false;
      _engine.stop();
      _publishError(error.message ?? 'Failed to start speech recognition.');
      rethrow;
    } catch (error) {
      await _speechSubscription?.cancel();
      _speechSubscription = null;
      _isRunning = false;
      _engine.stop();
      _publishError('Failed to start speech recognition.');
      rethrow;
    }
  }

  Future<void> stopSession() async {
    if (!_isRunning) {
      _engine.stop();
      _publishError(null);
      return;
    }

    await _invokeMethod('stopEvenAI');
    await _waitForSpeechFinalization();
    await _speechSubscription?.cancel();
    _speechSubscription = null;
    _isRunning = false;
    _engine.stop();
    _publishError(null);
  }

  void finalizePendingTranscript({String? overrideText}) {
    final candidate = (overrideText ?? _latestTranscript).trim();
    if (candidate.isEmpty || candidate == _lastFinalizedTranscript) {
      _completeSpeechFinalization();
      return;
    }

    _lastFinalizedTranscript = candidate;
    _engine.onTranscriptionFinalized(candidate);
    _completeSpeechFinalization();
  }

  Future<void> _waitForSpeechFinalization() async {
    final waiter = _speechFinalizationCompleter;
    if (waiter == null || waiter.isCompleted) {
      return;
    }

    try {
      await waiter.future.timeout(_finalizationTimeout);
    } catch (_) {
      finalizePendingTranscript();
      await _speechSubscription?.cancel();
      _speechSubscription = null;
    }
  }

  void _completeSpeechFinalization() {
    final waiter = _speechFinalizationCompleter;
    if (waiter != null && !waiter.isCompleted) {
      waiter.complete();
    }
  }

  void _ensureSpeechFinalizationCompleter() {
    final waiter = _speechFinalizationCompleter;
    if (waiter == null || waiter.isCompleted) {
      _speechFinalizationCompleter = Completer<void>();
    }
  }

  void _publishError(String? message) {
    _currentError = message;
    _errorController.add(message);
  }

  String _getLanguageCode() {
    final lang = SettingsManager.instance.language;
    switch (lang) {
      case 'zh':
        return 'CN';
      case 'ja':
        return 'JP';
      case 'ko':
        return 'KR';
      case 'es':
        return 'ES';
      case 'ru':
        return 'RU';
      default:
        return 'EN';
    }
  }
}
