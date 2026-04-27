import 'dart:async';

import 'package:flutter/services.dart';

import 'package:flutter/foundation.dart';

import '../ble_manager.dart';
import 'llm/llm_provider.dart';
import '../utils/app_logger.dart';
import 'conversation_engine.dart';
import 'settings_manager.dart';
import 'voice_assistant_service.dart';

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
  int? _latestTimestampMs;
  // ignore: unused_field
  int? _latestSegmentId;
  String _lastFinalizedTranscript = '';
  String _lastEmittedPartial = '';
  String? _latestSpeaker;
  bool _isRunning = false;
  bool _starting = false;
  bool _voiceWasEnabled = false;
  String? _currentError;
  int _speechEventCount = 0;

  bool get isRunning => _isRunning;
  TranscriptSource get source => _source;
  Stream<String?> get errorStream => _errorController.stream;
  String? get currentError => _currentError;

  Future<void> startSession({required TranscriptSource source}) async {
    if (_starting) return;
    _starting = true;
    try {
      if (_isRunning) {
        // Stop native side without tearing down the EventChannel subscription.
        // Full stopSession() cancels the subscription which triggers a
        // detach/attach cycle that races with the new startEvenAI call.
        // Pass emitFinal=false to suppress the empty transcript that would
        // otherwise be emitted before the new session has any audio.
        await _invokeMethod('stopEvenAI', {'emitFinal': false});
        _isRunning = false;
      }

      _source = source;
      _latestTranscript = '';
      _lastFinalizedTranscript = '';
      _lastEmittedPartial = '';
      _speechFinalizationCompleter = null;
      _publishError(null);
      _engine.start(source: source);

      // Reuse the existing EventChannel subscription if it's still alive.
      if (_speechSubscription != null) {
        appLogger.d(
          '[ListeningSession] Reusing existing eventSpeechRecognize subscription',
        );
      } else {
        appLogger.d(
          '[ListeningSession] Subscribing to eventSpeechRecognize stream',
        );
      }
      _speechSubscription ??= _speechEvents.listen(
        (event) {
          final payload = Map<String, dynamic>.from(event as Map);
          final text = (payload['script'] as String? ?? '').trim();
          final isFinal = payload['isFinal'] == true;
          final error = (payload['error'] as String?)?.trim();
          final timestampMs = payload['timestampMs'] as int?;
          final segmentId = payload['segmentId'] as int?;
          final speaker = payload['speaker'] as String?;
          final usagePayload = payload['usage'];

          if (kDebugMode && _speechEventCount++ % 10 == 0) {
            appLogger.d(
              '[ListeningSession] Speech event #$_speechEventCount — '
              'isFinal=$isFinal, text="${text.length > 140 ? text.substring(0, 140) : text}"'
              '${segmentId != null ? ", segmentId=$segmentId" : ""}'
              '${error != null ? ", error=$error" : ""}',
            );
          }

          if (text.isNotEmpty) {
            _ensureSpeechFinalizationCompleter();
            _latestTranscript = text;
            _latestTimestampMs = timestampMs;
            _latestSegmentId = segmentId;
            _latestSpeaker = speaker;
            _publishError(null);
            // Dedup identical partials to avoid redundant UI updates and LLM scheduling
            if (!isFinal && text == _lastEmittedPartial) return;
            _lastEmittedPartial = isFinal ? '' : text;
            _engine.onTranscriptionUpdate(text);
          }

          if (error != null && error.isNotEmpty) {
            appLogger.e('Speech recognition error: $error');
            _publishError(error);
          }

          if (usagePayload is Map) {
            final usageMap = usagePayload.cast<String, dynamic>();
            final operationType =
                (payload['usageOperationType'] as String?)?.trim() ?? '';
            final modelId =
                (payload['usageModel'] as String?)?.trim().isNotEmpty == true
                ? (payload['usageModel'] as String).trim()
                : SettingsManager.instance.transcriptionModel;
            final providerId =
                (payload['usageProvider'] as String?)?.trim().isNotEmpty == true
                ? (payload['usageProvider'] as String).trim()
                : 'openai';
            if (operationType == 'transcription') {
              _engine.onTranscriptionUsage(
                providerId: providerId,
                modelId: modelId,
                usage: LlmUsage.fromJson(usageMap),
              );
            }
          }

          if (isFinal) {
            finalizePendingTranscript(
              overrideText: text.isNotEmpty ? text : _latestTranscript,
            );
          }

          final aiResponse = payload['aiResponse'] as String?;
          if (aiResponse != null) {
            _engine.onRealtimeResponse(
              aiResponse,
              isFinal: payload['isFinal'] == true,
            );
          }
        },
        onError: (error) {
          appLogger.e('Speech recognition stream error', error: error);
          _publishError('Speech recognition stream error.');
          finalizePendingTranscript();
        },
      );

      // Allow the EventChannel subscription to complete its onListen callback
      // in the native layer. Without this, the speech event sink may not be
      // attached when recognition starts, causing early events to be dropped.
      await Future<void>.delayed(const Duration(milliseconds: 100));

      final langCode = _getLanguageCode();
      final sourceStr = source == TranscriptSource.glasses
          ? 'glasses'
          : 'microphone';
      final settings = SettingsManager.instance;

      // Models that use the batch REST API (whisper path) regardless of
      // the selected backend setting.
      final isBatchApiModel =
          settings.transcriptionModel.contains('diarize') ||
          settings.transcriptionModel == 'whisper-1';
      // Route to batch when transport is "48kHz Batch Proc" and model supports it.
      final isBatchTransport =
          settings.transcriptionTransport == '48kHz Batch Proc' &&
          (settings.transcriptionModel == 'gpt-4o-transcribe' ||
              settings.transcriptionModel == 'gpt-4o-mini-transcribe');
      final effectiveBackend = (isBatchApiModel || isBatchTransport)
          ? 'whisper'
          : settings.transcriptionBackend;

      String? apiKey;
      String? systemPrompt;
      if (effectiveBackend == 'openai' || effectiveBackend == 'whisper') {
        try {
          apiKey = await settings.getApiKey('openai');
        } catch (e) {
          appLogger.w('[ListeningSession] Failed to load OpenAI key: $e');
        }
      }
      if (settings.usesOpenAIRealtimeSession) {
        final basePrompt =
            settings.openAIRealtimePrompt?.trim().isNotEmpty == true
            ? settings.openAIRealtimePrompt!.trim()
            : _engine.systemPrompt;
        systemPrompt = _buildRealtimeConversationPrompt(basePrompt);
      }

      final voiceEnabled = settings.voiceResponseEnabled;
      final voiceName = settings.voiceAssistantVoice;

      appLogger.d(
        '[ListeningSession] Calling startEvenAI — '
        'lang=$langCode, source=$sourceStr, '
        'backend=$effectiveBackend, '
        'sessionMode=${settings.openAISessionMode}, '
        'model=${settings.transcriptionModel}'
        '${voiceEnabled ? ", voice=$voiceName" : ""}',
      );
      try {
        await _invokeMethod('startEvenAI', {
          'language': langCode,
          'source': sourceStr,
          'backend': effectiveBackend,
          'sessionMode': settings.openAISessionMode,
          'conversationModel': settings.realtimeConversationModel,
          'apiKey': apiKey,
          'model': settings.transcriptionModel,
          'systemPrompt': systemPrompt,
          'transcriptionPrompt': settings.transcriptionPrompt,
          'noiseReduction': settings.noiseReduction,
          'voiceActivityDetection': settings.voiceActivityDetection,
          'vadSensitivity': settings.vadSensitivity,
          if (voiceEnabled) 'voice': voiceName,
          if (effectiveBackend == 'whisper') ...{
            'enableDiarization': settings.enableDiarization,
            'chunkDurationSec': settings.whisperChunkDurationSec.toDouble(),
          },
        });
        _isRunning = true;

        // Start receiving voice audio output when voice responses are enabled
        _voiceWasEnabled = voiceEnabled;
        if (voiceEnabled) {
          await VoiceAssistantService.instance.startListening();
          appLogger.d('[ListeningSession] Voice assistant listening started');
        }

        appLogger.d(
          '[ListeningSession] startEvenAI succeeded — session is running',
        );
      } on PlatformException catch (error) {
        appLogger.e(
          '[ListeningSession] startEvenAI PlatformException: ${error.message}',
        );
        await _speechSubscription?.cancel();
        _speechSubscription = null;
        _isRunning = false;
        _engine.stop();
        _publishError(error.message ?? 'Failed to start speech recognition.');
        rethrow;
      } catch (error) {
        appLogger.e('[ListeningSession] startEvenAI error: $error');
        await _speechSubscription?.cancel();
        _speechSubscription = null;
        _isRunning = false;
        _engine.stop();
        _publishError('Failed to start speech recognition.');
        rethrow;
      }
    } finally {
      _starting = false;
    }
  }

  Future<void> stopSession() async {
    if (!_isRunning) {
      _engine.stop();
      _publishError(null);
      return;
    }

    await _invokeMethod('stopEvenAI');
    if (_voiceWasEnabled) {
      await VoiceAssistantService.instance.stopListening();
      _voiceWasEnabled = false;
    }
    await _waitForSpeechFinalization();
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
    final segmentTimestamp = _latestTimestampMs != null
        ? DateTime.fromMillisecondsSinceEpoch(_latestTimestampMs!)
        : null;
    _engine.onTranscriptionFinalized(
      candidate,
      segmentTimestamp: segmentTimestamp,
      speakerLabel: _latestSpeaker,
    );
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

  /// Pause transcription - stop forwarding audio but keep session alive
  void pauseTranscription() {
    _invokeMethod('pauseEvenAI', {});
    appLogger.d('[ListeningSession] Transcription paused');
  }

  /// Resume transcription
  void resumeTranscription() {
    _invokeMethod('resumeEvenAI', {});
    appLogger.d('[ListeningSession] Transcription resumed');
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

  String _buildRealtimeConversationPrompt(String basePrompt) {
    final trimmed = basePrompt.trim();
    if (_containsDelimitedContract(trimmed)) {
      return trimmed;
    }

    final contract = _realtimeDelimitedContract();
    if (trimmed.isEmpty) {
      return contract;
    }

    final isChinese = SettingsManager.instance.language == 'zh';
    final heading = isChinese
        ? '输出格式要求（必须严格遵守）：'
        : 'Output format requirements (must follow exactly):';
    return '$trimmed\n\n$heading\n\n$contract';
  }

  bool _containsDelimitedContract(String prompt) {
    return prompt.contains('§Q§') &&
        prompt.contains('§A§') &&
        prompt.contains('§END§');
  }

  String _realtimeDelimitedContract() {
    final isChinese = SettingsManager.instance.language == 'zh';
    if (isChinese) {
      return '''每一次回复都必须严格按照以下三段式格式输出，不允许任何额外内容：

§Q§
<对方刚刚问佩戴者的一句话问题。如果没有明确的问题，写 NONE。>
§A§
<如果 §Q§ 是 NONE，这里也写 NONE。否则给出直接的口语化答案，不要写"你可以说"之类的开场白，只用自然句子。>
§END§

规则：
- 永远不要在 §Q§ / §A§ / §END§ 结构之外写任何字。
- 不要使用 markdown、列表或项目符号。
- 如果对方只是在聊天或陈述，两个部分都写 NONE。
- 如果是佩戴者自己在说话，两个部分也都写 NONE。''';
    }

    return '''EVERY response MUST follow this EXACT format — three labeled sections, in this order, with no extra text:

§Q§
<one short sentence: the question the other person asked the wearer. If no clear question was asked, write NONE.>
§A§
<if §Q§ is NONE, write NONE here too. Otherwise: a direct spoken answer with no preamble, no "you could say", and plain sentences only.>
§END§

RULES:
- NEVER write anything outside the §Q§ / §A§ / §END§ structure.
- NEVER use markdown, bullets, or lists.
- If the other person is just chatting or making a statement, BOTH sections are NONE.
- If the wearer is the one speaking, BOTH sections are NONE.''';
  }
}
