import 'dart:async';
import 'dart:collection';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_helix/services/conversation_engine.dart';
import 'package:flutter_helix/services/hud_controller.dart';
import 'package:flutter_helix/services/llm/llm_provider.dart';
import 'package:flutter_helix/services/llm/llm_service.dart';
import 'package:flutter_helix/services/settings_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------------------
// FakeJsonProvider — queue-based mock LLM
// ---------------------------------------------------------------------------

class FakeStreamResponse {
  const FakeStreamResponse(
    this.chunks, {
    this.delayBetweenChunks = Duration.zero,
  });

  final List<String> chunks;
  final Duration delayBetweenChunks;
}

class FakeJsonProvider implements LlmProvider {
  FakeJsonProvider({
    List<String> responses = const [],
    List<FakeStreamResponse> streamResponses = const [],
  })  : _responses = Queue<String>.from(responses),
        _streamResponses = Queue<FakeStreamResponse>.from(streamResponses);

  final Queue<String> _responses;
  final Queue<FakeStreamResponse> _streamResponses;
  int streamCallCount = 0;
  int getResponseCallCount = 0;
  final List<String> capturedSystemPrompts = [];
  final List<List<ChatMessage>> capturedMessages = [];

  /// Dynamically enqueue a getResponse result.
  void enqueueResponse(String json) => _responses.addLast(json);

  /// Dynamically enqueue a streaming response.
  void enqueueStreamResponse(FakeStreamResponse r) =>
      _streamResponses.addLast(r);

  @override
  List<String> get availableModels => const ['fake-model'];

  @override
  String get defaultModel => 'fake-model';

  @override
  String get id => 'fake';

  @override
  String get name => 'Fake';

  @override
  Future<String> getResponse({
    required String systemPrompt,
    required List<ChatMessage> messages,
    String? model,
    double temperature = 0.7,
  }) async {
    getResponseCallCount++;
    capturedSystemPrompts.add(systemPrompt);
    capturedMessages.add(messages);
    if (_responses.isEmpty) {
      return '{"shouldRespond": false, "question": "", "questionExcerpt": ""}';
    }
    return _responses.removeFirst();
  }

  @override
  Stream<String> streamResponse({
    required String systemPrompt,
    required List<ChatMessage> messages,
    String? model,
    double temperature = 0.7,
  }) async* {
    streamCallCount++;
    capturedSystemPrompts.add(systemPrompt);
    capturedMessages.add(messages);
    final script = _streamResponses.isEmpty
        ? const FakeStreamResponse(['stubbed stream response'])
        : _streamResponses.removeFirst();
    for (var index = 0; index < script.chunks.length; index++) {
      if (index > 0 && script.delayBetweenChunks > Duration.zero) {
        await Future<void>.delayed(script.delayBetweenChunks);
      }
      yield script.chunks[index];
    }
  }

  @override
  Future<List<String>> queryAvailableModels({bool refresh = false}) async {
    return availableModels;
  }

  @override
  bool supportsRealtimeModel(String model) => false;

  @override
  Future<bool> testConnection(String apiKey) async => true;

  @override
  void updateApiKey(String apiKey) {}

  @override
  Stream<LlmResponseEvent> streamWithTools({
    required String systemPrompt,
    required List<ChatMessage> messages,
    List<ToolDefinition>? tools,
    String? model,
    double temperature = 0.7,
  }) async* {
    await for (final chunk in streamResponse(
      systemPrompt: systemPrompt,
      messages: messages,
      model: model,
      temperature: temperature,
    )) {
      yield TextDelta(chunk);
    }
  }
}

// ---------------------------------------------------------------------------
// Secure storage mock
// ---------------------------------------------------------------------------

const secureStorageChannel = MethodChannel(
  'plugins.it_nomads.com/flutter_secure_storage',
);
final secureStorageValues = <String, String>{};

Future<Object?> secureStorageHandler(MethodCall call) async {
  final arguments =
      (call.arguments as Map?)?.cast<Object?, Object?>() ?? {};
  final key = arguments['key'] as String?;

  switch (call.method) {
    case 'read':
      return key == null ? null : secureStorageValues[key];
    case 'write':
      final value = arguments['value'] as String?;
      if (key != null && value != null) {
        secureStorageValues[key] = value;
      }
      return null;
    case 'delete':
      if (key != null) secureStorageValues.remove(key);
      return null;
    case 'deleteAll':
      secureStorageValues.clear();
      return null;
    case 'containsKey':
      return key != null && secureStorageValues.containsKey(key);
    case 'readAll':
      return Map<String, String>.from(secureStorageValues);
    default:
      return null;
  }
}

// ---------------------------------------------------------------------------
// Setup helpers
// ---------------------------------------------------------------------------

/// Install secure-storage and BLE mocks needed by most tests.
void installPlatformMocks() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(secureStorageChannel, secureStorageHandler);

  // BLE method channel stub
  const bleChannel = MethodChannel('method.bluetooth');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(bleChannel, (call) async => null);
}

/// Remove platform mocks and clear accumulated state.
void removePlatformMocks() {
  secureStorageValues.clear();
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(secureStorageChannel, null);
  const bleChannel = MethodChannel('method.bluetooth');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(bleChannel, null);
}

/// Initialize SettingsManager with sensible defaults for tests.
Future<void> initTestSettings({
  Map<String, Object> overrides = const {},
}) async {
  SharedPreferences.setMockInitialValues({
    'transcriptionBackend': 'appleCloud',
    ...overrides,
  });
  await SettingsManager.instance.initialize();
}

/// Register a [FakeJsonProvider] with [LlmService] and wire it to the engine.
Future<FakeJsonProvider> configureFakeLlm({
  List<String> responses = const [],
  List<FakeStreamResponse> streamResponses = const [],
}) async {
  final llm = LlmService.instance;
  final provider = FakeJsonProvider(
    responses: responses,
    streamResponses: streamResponses,
  );
  llm.registerProvider(provider);
  llm.setActiveProvider('fake');
  ConversationEngine.setLlmServiceGetter(() => llm);
  return provider;
}

/// Full engine setup: platform mocks, settings, LLM, cleared history.
Future<({ConversationEngine engine, FakeJsonProvider provider})> setupTestEngine({
  List<String> responses = const [],
  List<FakeStreamResponse> streamResponses = const [],
  Map<String, Object> settingsOverrides = const {},
}) async {
  installPlatformMocks();
  await initTestSettings(overrides: settingsOverrides);
  ConversationEngine.resetTestHooks();
  SettingsManager.instance.assistantProfileId = 'professional';
  final provider = await configureFakeLlm(
    responses: responses,
    streamResponses: streamResponses,
  );
  final engine = ConversationEngine.instance;
  engine.clearHistory();
  engine.stop();
  await HudController.instance.resetToIdle(source: 'test.setup');
  return (engine: engine, provider: provider);
}

/// Standard teardown: stop engine, restore auto-detect.
void teardownTestEngine(ConversationEngine engine) {
  engine.autoDetectQuestions = true;
  engine.stop();
}

// ---------------------------------------------------------------------------
// Assertion helpers
// ---------------------------------------------------------------------------

/// Drain a broadcast stream until [predicate] returns true or [timeout] expires.
Future<T> waitForStream<T>(
  Stream<T> stream, {
  bool Function(T)? predicate,
  Duration timeout = const Duration(seconds: 5),
}) {
  final completer = Completer<T>();
  late StreamSubscription<T> sub;
  sub = stream.listen((event) {
    if (predicate == null || predicate(event)) {
      if (!completer.isCompleted) {
        completer.complete(event);
        sub.cancel();
      }
    }
  });
  return completer.future.timeout(timeout, onTimeout: () {
    sub.cancel();
    throw TimeoutException(
      'Stream did not emit matching event within $timeout',
    );
  });
}

/// Collect N events from a broadcast stream.
Future<List<T>> collectStreamEvents<T>(
  Stream<T> stream,
  int count, {
  Duration timeout = const Duration(seconds: 5),
}) async {
  final events = <T>[];
  final completer = Completer<List<T>>();
  late StreamSubscription<T> sub;
  sub = stream.listen((event) {
    events.add(event);
    if (events.length >= count && !completer.isCompleted) {
      completer.complete(events);
      sub.cancel();
    }
  });
  return completer.future.timeout(timeout, onTimeout: () {
    sub.cancel();
    throw TimeoutException(
      'collectStreamEvents: only collected ${events.length}/$count events within $timeout',
    );
  });
}
