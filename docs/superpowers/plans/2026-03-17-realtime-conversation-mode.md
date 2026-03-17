# Realtime Conversation Mode Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an `openaiRealtime` backend that uses a single OpenAI Realtime API WebSocket for both transcription and AI text responses, displayed on smart glasses.

**Architecture:** The native `OpenAIRealtimeTranscriber` gains a `.conversation` mode that connects without `intent=transcription`, sends a system prompt, and handles both `input_audio_transcription` events (transcription) and `response.text.delta/done` events (AI responses). Events flow through the existing `eventSpeechRecognize` EventChannel to Dart, where `ConversationListeningSession` routes them to `ConversationEngine`.

**Tech Stack:** Swift (native iOS), Dart/Flutter, OpenAI Realtime API WebSocket, Flutter Platform Channels

**Spec:** `docs/superpowers/specs/2026-03-17-realtime-conversation-mode-design.md`

---

## File Map

| File | Action | Responsibility |
|------|--------|---------------|
| `ios/Runner/OpenAIRealtimeTranscriber.swift` | Modify | Add `RealtimeMode` enum, conversation session config, response event handling |
| `ios/Runner/SpeechStreamRecognizer.swift` | Modify | Wire `onResponse` callback, new `emitAIResponse()`, pass mode/systemPrompt |
| `ios/Runner/AppDelegate.swift` | Modify | Add `openaiRealtime` case, extract `systemPrompt` |
| `lib/services/conversation_listening_session.dart` | Modify | Parse `aiResponse` events, pass `systemPrompt` |
| `lib/services/conversation_engine.dart` | Modify | Add `systemPrompt` getter, `onRealtimeResponse()`, gate LLM calls |
| `lib/services/settings_manager.dart` | Modify | No code change needed (`transcriptionBackend` already accepts any string) |
| `lib/screens/settings_screen.dart` | Modify | Add dropdown option, conditional model selector |

---

### Task 1: Add RealtimeMode and conversation session config to OpenAIRealtimeTranscriber

**Files:**
- Modify: `ios/Runner/OpenAIRealtimeTranscriber.swift`

- [ ] **Step 1: Add RealtimeMode enum and new properties (after line 3)**

```swift
enum RealtimeMode {
    case transcriptionOnly
    case conversation
}
```

Add to class properties (after line 21):
```swift
var onResponse: ((String, Bool) -> Void)?
private var mode: RealtimeMode = .transcriptionOnly
private var systemInstructions: String = ""
```

- [ ] **Step 2: Update `start()` to accept mode and systemPrompt (line 42)**

Change signature to:
```swift
func start(
    apiKey: String,
    model: String,
    language: String,
    mode: RealtimeMode = .transcriptionOnly,
    systemPrompt: String = "",
    completion: @escaping (Result<Void, Error>) -> Void
)
```

Add inside body before `connect()`:
```swift
self.mode = mode
self.systemInstructions = systemPrompt
```

- [ ] **Step 3: Update `connect()` URL by mode (line ~143)**

Replace the URL construction:
```swift
let sessionModel = realtimeSessionModel(for: model)
let urlString: String
switch mode {
case .transcriptionOnly:
    urlString = "wss://api.openai.com/v1/realtime?intent=transcription&model=\(sessionModel)"
case .conversation:
    urlString = "wss://api.openai.com/v1/realtime?model=\(sessionModel)"
}
```

- [ ] **Step 4: Update `sendSessionConfig()` for conversation mode (line ~182)**

Add conversation mode branch:
```swift
private func sendSessionConfig() {
    switch mode {
    case .transcriptionOnly:
        // existing transcription_session.update code unchanged
        let languageMap: [String: String] = [
            "en": "en", "zh": "zh", "ja": "ja", "ko": "ko",
            "es": "es", "ru": "ru", "fr": "fr", "de": "de",
        ]
        let resolvedLang = languageMap[language] ?? "en"
        sendEvent([
            "type": "transcription_session.update",
            "session": [
                "input_audio_format": "pcm16",
                "input_audio_transcription": [
                    "language": resolvedLang,
                ],
                "turn_detection": [
                    "type": "server_vad",
                    "threshold": 0.5,
                    "prefix_padding_ms": 300,
                    "silence_duration_ms": 500,
                ],
            ],
        ])
        print("[OpenAITranscriber] Transcription session config sent, language=\(resolvedLang)")

    case .conversation:
        let languageMap: [String: String] = [
            "en": "en", "zh": "zh", "ja": "ja", "ko": "ko",
            "es": "es", "ru": "ru", "fr": "fr", "de": "de",
        ]
        let resolvedLang = languageMap[language] ?? "en"
        sendEvent([
            "type": "session.update",
            "session": [
                "modalities": ["text"],
                "instructions": systemInstructions,
                "input_audio_format": "pcm16",
                "input_audio_transcription": [
                    "model": "gpt-4o-mini-transcribe",
                    "language": resolvedLang,
                ],
                "turn_detection": [
                    "type": "server_vad",
                    "threshold": 0.5,
                    "prefix_padding_ms": 300,
                    "silence_duration_ms": 800,
                ],
            ],
        ])
        print("[OpenAITranscriber] Conversation session config sent, language=\(resolvedLang)")
    }
}
```

- [ ] **Step 5: Update `sendEvent()` guard to whitelist `session.update` (line ~251)**

```swift
guard let task = webSocketTask,
      isConnected
      || event["type"] as? String == "transcription_session.update"
      || event["type"] as? String == "session.update"
else { return }
```

- [ ] **Step 6: Add response event handling to `handleMessage()` (line ~290)**

Add new cases in the switch:
```swift
case "response.text.delta":
    if let delta = json["delta"] as? String, !delta.isEmpty {
        DispatchQueue.main.async {
            self.onResponse?(delta, false)
        }
    }

case "response.text.done":
    DispatchQueue.main.async {
        self.onResponse?("", true)
    }

case "session.created", "session.updated":
    print("[OpenAITranscriber] Session event: \(type)")
```

- [ ] **Step 7: Add disconnect flush for conversation mode in `handleDisconnect()` (line ~336)**

At the top of `handleDisconnect`, before setting `isConnected = false`:
```swift
if mode == .conversation {
    DispatchQueue.main.async {
        self.onResponse?("", true)
    }
}
```

- [ ] **Step 8: Build to verify compilation**

Run: `flutter build ios --debug --no-codesign 2>&1 | tail -5`
Expected: `✓ Built build/ios/iphoneos/Runner.app`

- [ ] **Step 9: Commit**

```bash
git add ios/Runner/OpenAIRealtimeTranscriber.swift
git commit -m "feat: add conversation mode to OpenAIRealtimeTranscriber"
```

---

### Task 2: Wire response events through SpeechStreamRecognizer

**Files:**
- Modify: `ios/Runner/SpeechStreamRecognizer.swift`

- [ ] **Step 1: Update `startRecognition()` signature (line 97)**

Add new parameters:
```swift
func startRecognition(
    identifier: String,
    source: String = "glasses",
    backend: TranscriptionBackend = .appleCloud,
    apiKey: String? = nil,
    model: String? = nil,
    realtimeConversation: Bool = false,
    systemPrompt: String? = nil,
    completion: @escaping (Result<Void, Error>) -> Void
)
```

Update the `startOpenAIRecognition` call (line ~113) to pass new params:
```swift
startOpenAIRecognition(
    identifier: identifier,
    source: source,
    apiKey: apiKey ?? "",
    model: model ?? "gpt-4o-mini-transcribe",
    realtimeConversation: realtimeConversation,
    systemPrompt: systemPrompt,
    completion: completion
)
```

- [ ] **Step 2: Update `startOpenAIRecognition()` signature and add response callback (line 243)**

Add parameters:
```swift
private func startOpenAIRecognition(
    identifier: String,
    source: String,
    apiKey: String,
    model: String,
    realtimeConversation: Bool = false,
    systemPrompt: String? = nil,
    completion: @escaping (Result<Void, Error>) -> Void
)
```

Wire new callback after `openaiTranscriber.onError` (line ~264):
```swift
openaiTranscriber.onResponse = { [weak self] text, isFinal in
    self?.emitAIResponse(text, isFinal: isFinal)
}
```

Update the `openaiTranscriber.start()` call (line ~270):
```swift
let mode: RealtimeMode = realtimeConversation ? .conversation : .transcriptionOnly
openaiTranscriber.start(
    apiKey: apiKey,
    model: model,
    language: lang,
    mode: mode,
    systemPrompt: systemPrompt ?? ""
) { [weak self] result in
```

- [ ] **Step 3: Add `emitAIResponse()` method (after `emitError` at line ~437)**

```swift
private func emitAIResponse(_ text: String, isFinal: Bool) {
    let event: [String: Any] = [
        "aiResponse": text,
        "isFinal": isFinal,
    ]
    emitSpeechEvent(event)
}
```

- [ ] **Step 4: Build to verify**

Run: `flutter build ios --debug --no-codesign 2>&1 | tail -5`
Expected: `✓ Built`

- [ ] **Step 5: Commit**

```bash
git add ios/Runner/SpeechStreamRecognizer.swift
git commit -m "feat: wire AI response events through SpeechStreamRecognizer"
```

---

### Task 3: Add openaiRealtime case in AppDelegate

**Files:**
- Modify: `ios/Runner/AppDelegate.swift`

- [ ] **Step 1: Extract new params and add switch case (lines 46-83)**

After `let model = args["model"] as? String` (line 52), add:
```swift
let systemPrompt = args["systemPrompt"] as? String
let realtimeConversation = backendStr == "openaiRealtime"
```

Add case in the backend switch (before `default:`):
```swift
case "openaiRealtime":
    backend = .openai
```

Update `startRecognition` call (line 64) to pass new params:
```swift
SpeechStreamRecognizer.shared.startRecognition(
    identifier: lang,
    source: source,
    backend: backend,
    apiKey: apiKey,
    model: model,
    realtimeConversation: realtimeConversation,
    systemPrompt: systemPrompt
) { startResult in
```

- [ ] **Step 2: Build to verify**

Run: `flutter build ios --debug --no-codesign 2>&1 | tail -5`
Expected: `✓ Built`

- [ ] **Step 3: Commit**

```bash
git add ios/Runner/AppDelegate.swift
git commit -m "feat: add openaiRealtime backend case in AppDelegate"
```

---

### Task 4: Add systemPrompt getter and onRealtimeResponse to ConversationEngine

**Files:**
- Modify: `lib/services/conversation_engine.dart`

- [ ] **Step 1: Add public systemPrompt getter**

Add near other public getters (around line 60-70):
```dart
/// System prompt for the current mode and language, used by realtime sessions.
String get systemPrompt => _getSystemPrompt();
```

- [ ] **Step 2: Add `_realtimeResponseBuffer` field**

Add with other private fields (around line 30-40):
```dart
String _realtimeResponseBuffer = '';
```

- [ ] **Step 3: Add `onRealtimeResponse()` method**

Add after `onTranscriptionFinalized` method:
```dart
/// Handle AI response text from the OpenAI Realtime API conversation mode.
void onRealtimeResponse(String text, {required bool isFinal}) {
    if (text.isNotEmpty) {
        _realtimeResponseBuffer += text;
        _streamToGlasses(text, isStreaming: true);
        _statusController.add(EngineStatus.responding);
    }

    if (isFinal) {
        final fullResponse = _realtimeResponseBuffer.trim();
        if (fullResponse.isNotEmpty) {
            _streamToGlasses('', isStreaming: false);
            _history.add(
                ConversationTurn(
                    role: 'assistant',
                    content: fullResponse,
                    timestamp: DateTime.now(),
                    mode: _mode.name,
                    assistantProfileId: _activeAssistantProfile().id,
                ),
            );
            _persistHistory();
            _aiResponseController.add(fullResponse);
        }
        _realtimeResponseBuffer = '';
        _statusController.add(
            _isActive ? EngineStatus.listening : EngineStatus.idle,
        );
    }
}
```

- [ ] **Step 4: Gate `_generateResponse()` for realtime mode (line 811)**

Add at the top of `_generateResponse`, after `Timer? flushTimer;` (line 815):
```dart
if (SettingsManager.instance.transcriptionBackend == 'openaiRealtime') {
    return;
}
```

- [ ] **Step 5: Gate `_generateProactiveSuggestion()` for realtime mode (line 245)**

Add at the top of `_generateProactiveSuggestion`:
```dart
if (SettingsManager.instance.transcriptionBackend == 'openaiRealtime') {
    return;
}
```

- [ ] **Step 6: Build to verify**

Run: `flutter build ios --debug --no-codesign 2>&1 | tail -5`
Expected: `✓ Built`

- [ ] **Step 7: Commit**

```bash
git add lib/services/conversation_engine.dart
git commit -m "feat: add onRealtimeResponse and gate LLM calls for realtime mode"
```

---

### Task 5: Parse AI response events in ConversationListeningSession

**Files:**
- Modify: `lib/services/conversation_listening_session.dart`

- [ ] **Step 1: Add AI response parsing to the speech event listener (inside the `.listen()` block, around line 90)**

After the existing `if (isFinal)` block (line 102-106), add:
```dart
final aiResponse = payload['aiResponse'] as String?;
if (aiResponse != null) {
    _engine.onRealtimeResponse(
        aiResponse,
        isFinal: payload['isFinal'] == true,
    );
}
```

- [ ] **Step 2: Pass systemPrompt in startEvenAI call (around line 129)**

Update the settings block (after `apiKey` retrieval, line 118-122):
```dart
final settings = SettingsManager.instance;
String? apiKey;
String? systemPrompt;
if (settings.transcriptionBackend == 'openai' ||
    settings.transcriptionBackend == 'openaiRealtime') {
    apiKey = await settings.getApiKey('openai');
}
if (settings.transcriptionBackend == 'openaiRealtime') {
    systemPrompt = _engine.systemPrompt;
}
```

Add `systemPrompt` to the `startEvenAI` args map (line 129-135):
```dart
await _invokeMethod('startEvenAI', {
    'language': langCode,
    'source': sourceStr,
    'backend': settings.transcriptionBackend,
    'apiKey': apiKey,
    'model': settings.transcriptionModel,
    'systemPrompt': systemPrompt,
});
```

- [ ] **Step 3: Build to verify**

Run: `flutter build ios --debug --no-codesign 2>&1 | tail -5`
Expected: `✓ Built`

- [ ] **Step 4: Commit**

```bash
git add lib/services/conversation_listening_session.dart
git commit -m "feat: parse AI response events and pass systemPrompt for realtime mode"
```

---

### Task 6: Add dropdown option in Settings UI

**Files:**
- Modify: `lib/screens/settings_screen.dart`

- [ ] **Step 1: Add new dropdown item (around line 336)**

Add after the existing `'openai'` dropdown item:
```dart
DropdownMenuItem(value: 'openaiRealtime', child: Text('OpenAI Live AI')),
```

- [ ] **Step 2: Update model selector visibility (around line 348)**

Change the condition from:
```dart
if (_settings.transcriptionBackend == 'openai')
```
to:
```dart
if (_settings.transcriptionBackend == 'openai')
```
(Keep as-is — model selector should only show for transcription-only mode, not for `openaiRealtime`)

- [ ] **Step 3: Build to verify**

Run: `flutter build ios --debug --no-codesign 2>&1 | tail -5`
Expected: `✓ Built`

- [ ] **Step 4: Commit**

```bash
git add lib/screens/settings_screen.dart
git commit -m "feat: add OpenAI Live AI option to transcription backend dropdown"
```

---

### Task 7: End-to-end verification

- [ ] **Step 1: Full build**

Run: `flutter build ios --debug --no-codesign`
Expected: Clean build with no errors.

- [ ] **Step 2: Run on device/simulator**

1. Launch app, go to Settings
2. Under Transcription, select "OpenAI Live AI" backend
3. Return to home screen, tap microphone
4. Check Xcode console for: `[OpenAITranscriber] WebSocket opened` → `Conversation session config sent` → `Session event: session.created`
5. Speak a question — verify transcription events appear AND AI response text streams to glasses
6. Switch to "OpenAI Realtime" (transcription-only) — verify old behavior works
7. Switch to "Apple Cloud" — verify no regression

- [ ] **Step 3: Final commit if any fixups needed**
