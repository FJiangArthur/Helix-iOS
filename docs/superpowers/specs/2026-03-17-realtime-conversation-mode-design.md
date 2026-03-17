# Realtime Conversation Mode

## Problem

The current pipeline uses two separate API calls: transcription (OpenAI Realtime WebSocket) then LLM analysis (REST `/chat/completions`). This adds latency and complexity. OpenAI's Realtime API can handle both in a single persistent WebSocket — listen to audio, transcribe, and generate text responses when appropriate.

## Solution

Add a new `openaiRealtime` transcription backend that uses the OpenAI Realtime API in full conversation mode (no `intent=transcription`). The model hears the audio, provides transcription, and autonomously decides when to respond with text — all over one WebSocket. This is toggleable alongside existing backends.

## Architecture

### Data Flow

```
Mic/Glasses Audio
    |
[OpenAIRealtimeTranscriber] (mode: .conversation)
    |  wss://api.openai.com/v1/realtime?model=gpt-4o-mini-realtime-preview
    |
    +-- input_audio_transcription.delta/completed --> transcript events
    +-- response.text.delta / response.text.done  --> AI response events
    |
[EventChannel: eventSpeechRecognize]
    |  {"script": "...", "isFinal": bool}       -- transcription (existing)
    |  {"aiResponse": "...", "isFinal": bool}   -- AI response (new, no "script" key)
    |
[ConversationListeningSession]
    |
    +-- transcript (has "script" key) --> ConversationEngine.onTranscriptionUpdate()
    |                                     (unchanged — updates home screen, history)
    |
    +-- aiResponse (has "aiResponse" key) --> ConversationEngine.onRealtimeResponse()
                                              (new — streams to glasses HUD, saves to history)
```

**Note:** AI response events carry only `aiResponse` (no `script` key). The existing transcript path ignores them because `script` resolves to empty string — this is by design.

### Key Difference from Current Pipeline

| Aspect | Current (transcription + LLM) | New (realtime conversation) |
|--------|-------------------------------|----------------------------|
| Connections | 2 (WebSocket + REST) | 1 (WebSocket) |
| Latency | Transcription → detect question → LLM call | Model decides when to respond in real-time |
| Trigger | Silence detection + question matching | Server-side VAD + model judgment |
| System prompt | Sent per LLM call | Set once in session config |

## Implementation

### 1. OpenAIRealtimeTranscriber.swift — Add conversation mode

**New enum and properties:**
```swift
enum RealtimeMode {
    case transcriptionOnly  // current behavior (intent=transcription)
    case conversation       // new: full realtime session
}

var onResponse: ((String, Bool) -> Void)?  // AI response callback
private var mode: RealtimeMode = .transcriptionOnly
private var systemInstructions: String = ""
```

**`start()` method:** Add `mode` and `systemPrompt` parameters.

**`connect()` changes by mode:**
- `.transcriptionOnly`: URL has `intent=transcription` (existing behavior)
- `.conversation`: URL has no intent param, just `model=gpt-4o-mini-realtime-preview`

**`sendEvent()` guard update:** The existing guard whitelists `"transcription_session.update"` to bypass the `isConnected` check. Add `"session.update"` to the whitelist for conversation mode:
```swift
guard let task = webSocketTask,
      isConnected
      || event["type"] as? String == "transcription_session.update"
      || event["type"] as? String == "session.update"
else { return }
```

**`sendSessionConfig()` changes by mode:**
- `.transcriptionOnly`: sends `transcription_session.update` (existing)
- `.conversation`: sends `session.update` with `modalities: ["text"]` (text-only responses, no audio output):
  ```json
  {
    "type": "session.update",
    "session": {
      "modalities": ["text"],
      "instructions": "<system prompt from assistant profile>",
      "input_audio_format": "pcm16",
      "input_audio_transcription": { "model": "gpt-4o-mini-transcribe" },
      "turn_detection": {
        "type": "server_vad",
        "threshold": 0.5,
        "prefix_padding_ms": 300,
        "silence_duration_ms": 800
      }
    }
  }
  ```

**`handleMessage()` — new event types for conversation mode:**
- `response.text.delta` → extract `delta` field → `onResponse?(delta, false)`
- `response.text.done` → `onResponse?("", true)` (use `response.text.done` not `response.done` — the latter fires for the entire turn and could include future audio modalities)
- `conversation.item.input_audio_transcription.delta` → `onTranscript?(delta, false)` (same as transcription-only)
- `conversation.item.input_audio_transcription.completed` → `onTranscript?(transcript, true)`

**Reconnect handling for conversation mode:** When `handleDisconnect` retries in conversation mode, it must re-send the `session.update` with `systemInstructions`. The `connect()` method already calls `sendSessionConfig()` after the WebSocket opens (via `didOpenWithProtocol` delegate), and `systemInstructions` is stored as an instance variable — so reconnects automatically re-send the config. No additional work needed, but verify this path in testing.

**Disconnect cleanup:** On unexpected disconnect, if `mode == .conversation`, call `onResponse?("", true)` to flush any partial response buffer on the Dart side. This prevents `_realtimeResponseBuffer` from growing stale and `EngineStatus` from getting stuck at `.responding`.

### 2. SpeechStreamRecognizer.swift — Route response events

**`startOpenAIRecognition()` signature:** Accept `mode: RealtimeMode` and `systemPrompt: String?`; pass to transcriber's `start()`.

**New response callback wiring:**
```swift
openaiTranscriber.onResponse = { [weak self] text, isFinal in
    self?.emitAIResponse(text, isFinal: isFinal)
}
```

**New `emitAIResponse()` method:** Sends events through the speech EventChannel:
```swift
private func emitAIResponse(_ text: String, isFinal: Bool) {
    let event: [String: Any] = [
        "aiResponse": text,
        "isFinal": isFinal,
    ]
    speechEventSink?(event)
}
```

### 3. AppDelegate.swift — New backend case + params

**`startEvenAI` handler changes:**
- Extract `systemPrompt` from args: `let systemPrompt = args["systemPrompt"] as? String`
- Add new case in backend switch:
  ```swift
  case "openaiRealtime":
      backend = .openai  // same underlying enum, mode differentiates
  ```
- Pass `systemPrompt` and a `realtimeConversation: Bool` flag (true when `backendStr == "openaiRealtime"`) to `SpeechStreamRecognizer.startRecognition()`.

**`startRecognition()` signature:** Add `systemPrompt: String? = nil` and `realtimeConversation: Bool = false`.

### 4. ConversationListeningSession.dart — Parse AI responses

**`startSession()` changes:**
- When `transcriptionBackend == 'openaiRealtime'`, get the system prompt and pass it to `startEvenAI`:
  ```dart
  String? systemPrompt;
  if (settings.transcriptionBackend == 'openaiRealtime') {
      apiKey = await settings.getApiKey('openai');  // same API key
      systemPrompt = _engine.systemPrompt;  // new public getter
  }
  await _invokeMethod('startEvenAI', {
      ...existing params,
      'systemPrompt': systemPrompt,
  });
  ```

- Parse speech events: if event contains `aiResponse` key, route to engine:
  ```dart
  final aiResponse = payload['aiResponse'] as String?;
  if (aiResponse != null) {
      _engine.onRealtimeResponse(
          aiResponse,
          isFinal: payload['isFinal'] == true,
      );
  }
  ```

### 5. ConversationEngine.dart — New response handler

**New public getter** to expose system prompt:
```dart
String get systemPrompt => _getSystemPrompt();
```

**New state:**
```dart
String _realtimeResponseBuffer = '';
```

**New public method:**
```dart
void onRealtimeResponse(String text, {required bool isFinal}) {
    // Stream delta text to glasses HUD
    _streamToGlasses(text, isStreaming: !isFinal);

    // Accumulate for history
    _realtimeResponseBuffer += text;

    if (isFinal) {
        // Save to conversation history (matching existing pattern)
        if (_realtimeResponseBuffer.trim().isNotEmpty) {
            _history.add(ConversationTurn(
                role: 'assistant',
                content: _realtimeResponseBuffer.trim(),
                timestamp: DateTime.now(),
                mode: _mode.name,
                assistantProfileId: _activeAssistantProfile().id,
            ));
            _persistHistory();
        }
        _realtimeResponseBuffer = '';
        _emitSnapshot(status: EngineStatus.listening);
    } else {
        _emitSnapshot(status: EngineStatus.responding);
    }
}
```

**Skip LLM calls when in realtime mode.** Gate both `_generateResponse()` AND `_generateProactiveSuggestion()`:
```dart
// At top of _generateResponse():
if (SettingsManager.instance.transcriptionBackend == 'openaiRealtime') return;

// At top of _generateProactiveSuggestion():
if (SettingsManager.instance.transcriptionBackend == 'openaiRealtime') return;
```

This prevents the silence timer from triggering separate LLM calls that would race with realtime API responses on the glasses HUD.

### 6. SettingsManager.dart — New backend value

Add `'openaiRealtime'` as valid `transcriptionBackend` value. No new fields needed — the model is derived automatically (`gpt-4o-mini-realtime-preview`). The existing `getApiKey('openai')` is reused for authentication.

### 7. settings_screen.dart — New dropdown option

Add to the backend dropdown:
```dart
DropdownMenuItem(value: 'openaiRealtime', child: Text('OpenAI Live AI')),
```

Hide model selector when `openaiRealtime` is selected (model is fixed).

## System Prompt Integration

The realtime session's `instructions` field receives the same system prompt as the existing LLM pipeline. A new public getter `ConversationEngine.systemPrompt` exposes `_getSystemPrompt()` so `ConversationListeningSession` can include it in `startEvenAI` args.

This means: general mode gets the general system prompt, interview mode gets the STAR framework prompt, passive mode gets the "jump in when valuable" prompt — all with the active assistant profile's `answerStyle` directive appended.

## Error Handling

**Connection drop mid-response:** The native `handleDisconnect` calls `onResponse?("", true)` to signal completion. The Dart side flushes `_realtimeResponseBuffer` to history (if non-empty) and returns status to `listening`.

**Reconnect:** Retries use existing exponential backoff (up to 3 attempts). `systemInstructions` is preserved as an instance var, so `sendSessionConfig()` re-sends the full session config after reconnect.

**Rate limits:** If the API returns a rate limit error, it flows through `onError` → `emitError` → Dart `_publishError()`, which displays the error in the UI. The session is not automatically retried for rate limit errors (only for connection drops).

## Files to Modify

| File | Changes |
|------|---------|
| `ios/Runner/OpenAIRealtimeTranscriber.swift` | Add `RealtimeMode`, conversation session config, `response.text.delta`/`response.text.done` handling, `onResponse` callback, `sendEvent` guard update, disconnect flush |
| `ios/Runner/SpeechStreamRecognizer.swift` | Wire `onResponse`, new `emitAIResponse()`, pass mode/systemPrompt |
| `ios/Runner/AppDelegate.swift` | Add `"openaiRealtime"` case, extract `systemPrompt` from args |
| `lib/services/conversation_listening_session.dart` | Parse `aiResponse` events, pass system prompt for realtime backend |
| `lib/services/conversation_engine.dart` | New `systemPrompt` getter, `onRealtimeResponse()`, `_realtimeResponseBuffer` field, gate `_generateResponse` and `_generateProactiveSuggestion` for realtime |
| `lib/services/settings_manager.dart` | Accept `'openaiRealtime'` as backend value |
| `lib/screens/settings_screen.dart` | Add dropdown option, hide model selector for realtime |

## Verification

1. `flutter build ios --debug --no-codesign` compiles
2. Select "OpenAI Live AI" backend in settings
3. Tap microphone; verify logs: `WebSocket opened` → `session.updated` → transcription events flowing
4. Speak a question; verify AI response streams to glasses HUD and appears in conversation history
5. Stop and restart recording — verify no double-start or stale buffer
6. Kill network mid-response — verify status returns to `listening` and partial response is saved
7. Switch to "OpenAI Realtime" (transcription-only) — verify old behavior still works
8. Switch to "Apple Cloud" — verify no regression
9. Test interview mode — verify STAR framework prompt is used
10. Switch backend mid-session — verify clean transition
