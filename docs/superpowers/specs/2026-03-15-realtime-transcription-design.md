# Realtime Transcription: OpenAI Realtime API + Multi-Backend + Mic Selection

## Problem

Live transcription does not work. The app uses Apple's `SFSpeechRecognizer` exclusively, which:
- Silently fails due to audio session conflicts with flutter_sound
- Has a ~1 minute session timeout with no restart logic
- Provides no diagnostic feedback when it fails
- Cannot be configured by the user

The user wants low-latency, reliable transcription with the option to fall back to on-device recognition and choose between microphone sources.

## Solution

Replace the single-backend `SFSpeechRecognizer` pipeline with a multi-backend transcription system:

1. **OpenAI Realtime API** (WebSocket) — primary, lowest latency
2. **Apple Cloud Speech** (existing) — fallback, no API key needed
3. **Apple On-Device Speech** — offline fallback, works without network

Add user-facing microphone selection (glasses mic vs phone mic) with smart defaults.

## Architecture

```
Audio Sources                    Transcription Backends
─────────────                    ──────────────────────
                                 ┌─────────────────────────┐
Glasses MIC_DATA ──→ PCM 16kHz ─→│                         │
                                 │  SpeechStreamRecognizer  │
Phone Mic ──→ AVAudioEngine ────→│  (routes by backend)     │
                                 │                         │
                                 │  ┌─ OpenAI Realtime ────│──→ WebSocket
                                 │  ├─ Apple Cloud Speech  │──→ SFSpeechRecognizer
                                 │  └─ Apple On-Device     │──→ SFSpeechRecognizer
                                 │                         │    (onDevice=true)
                                 └────────────┬────────────┘
                                              │
                                              ▼
                                    blueSpeechSink (EventChannel)
                                              │
                                              ▼
                              ConversationListeningSession (unchanged)
                                    → ConversationEngine (unchanged)
                                    → HomeScreen UI (unchanged)
```

## Transcription Backends

### OpenAI Realtime (primary)

- **Connection**: `wss://api.openai.com/v1/realtime?intent=transcription`
- **Auth**: Bearer token from user's OpenAI API key (already stored in SecureStorage)
- **Audio format**: PCM16 little-endian, 24kHz, mono (base64-encoded)
- **Events sent**:
  - `transcription_session.update` — configure model, language
  - `input_audio_buffer.append` — audio chunks (base64)
  - `input_audio_buffer.commit` — mark end of speech segment
- **Events received**:
  - `conversation.item.input_audio_transcription.delta` — partial text
  - `conversation.item.input_audio_transcription.completed` — final text
  - `error` — error details
- **Models**: `gpt-4o-transcribe`, `gpt-4o-mini-transcribe`
- **Resampling**: 16kHz input (glasses/mic) upsampled to 24kHz via linear interpolation
- **Reconnection**: Auto-reconnect once on unexpected disconnect (max 1 retry, 2 total attempts); on second failure, fall back to Apple Cloud Speech
- **Auth errors**: HTTP 401 on WebSocket handshake (expired/revoked key) treated as unrecoverable — fall back immediately to Apple backend, surface error to user via `errorStream`

### Apple Cloud Speech (fallback)

- Existing `SFSpeechRecognizer` with `requiresOnDeviceRecognition = false`
- No API key needed
- ~1 minute session timeout (existing limitation)
- Requires network connectivity

### Apple On-Device Speech (offline fallback)

- `SFSpeechRecognizer` with `requiresOnDeviceRecognition = true`
- Works completely offline
- Lower accuracy than cloud
- Requires language model download (iOS handles this automatically)
- No session timeout

## Microphone Selection

### Sources

| Source | Description | Available When |
|--------|------------|----------------|
| `glasses` | G1 glasses BLE microphone (LC3→PCM via PcmConverter) | Glasses connected |
| `phone` | Device built-in microphone via AVAudioEngine | Always |

### Smart Defaults

- If glasses are connected → use glasses mic
- If glasses not connected → use phone mic
- User can override in Settings (persisted)
- If user selected glasses but glasses disconnect → auto-fallback to phone mic

### Settings

- `transcriptionBackend`: `'openai'` | `'appleCloud'` | `'appleOnDevice'` (default: `'openai'`)
- `preferredMicSource`: `'auto'` | `'glasses'` | `'phone'` (default: `'auto'`)

## New Files

### `ios/Runner/OpenAIRealtimeTranscriber.swift`

Single-responsibility class handling the WebSocket transcription session.

```swift
class OpenAIRealtimeTranscriber {
    func start(apiKey: String, model: String, language: String,
               completion: @escaping (Result<Void, Error>) -> Void)
    func appendAudio(_ pcmData: Data)       // 16kHz PCM16 input
    func stop()

    var onTranscript: ((String, Bool) -> Void)?  // (text, isFinal)
    var onError: ((String) -> Void)?
}
```

**Internals:**
- `URLSessionWebSocketTask` for the WebSocket connection
- Audio buffer: accumulates PCM samples, sends every 100ms (2400 samples at 24kHz)
- Resample: simple linear interpolation 16kHz → 24kHz (1.5x)
- Base64 encoding of resampled PCM before sending
- Ping/keepalive every 20 seconds
- Auto-reconnect on unexpected disconnect (max 1 retry, 2 total attempts)

### `ios/Runner/AudioResampler.swift`

Stateless utility for PCM sample rate conversion.

```swift
struct AudioResampler {
    static func resample(pcm16Data: Data, fromRate: Int, toRate: Int) -> Data
}
```

## Modified Files

### `ios/Runner/SpeechStreamRecognizer.swift`

Add backend routing:

```swift
enum TranscriptionBackend: String {
    case openai
    case appleCloud
    case appleOnDevice
}

func startRecognition(
    identifier: String,
    source: String,
    backend: TranscriptionBackend,
    apiKey: String?,
    model: String?,
    completion: @escaping (Result<Void, Error>) -> Void
)
```

- `.openai` → delegate to `OpenAIRealtimeTranscriber`
- `.appleCloud` → existing path with `requiresOnDeviceRecognition = false`
- `.appleOnDevice` → existing path with `requiresOnDeviceRecognition = true`
- All backends emit through the same `emitTranscript` → `blueSpeechSink` path

**Breaking change**: The `startRecognition` signature adds 3 new parameters. `AppDelegate.swift` must be updated simultaneously.

**`appendPCMData` delegation**: The existing `appendPCMData(_ pcmData: Data)` method (called by `BluetoothManager.getCommandValue()` for glasses audio) will check the active backend internally:
- If `.openai` → forward to `openaiTranscriber.appendAudio(pcmData)`
- If `.appleCloud` / `.appleOnDevice` → existing `recognitionRequest.append(audioBuffer)` path

This keeps `BluetoothManager` unchanged — it still calls `SpeechStreamRecognizer.shared.appendPCMData()`.

### `ios/Runner/AppDelegate.swift`

Extended `startEvenAI` method handler to accept:
```json
{
  "language": "EN",
  "source": "microphone",
  "backend": "openai",
  "apiKey": "sk-...",
  "model": "gpt-4o-mini-transcribe"
}
```

### `lib/services/evenai.dart`

The glasses recording entry point. `toStartEvenAIByOS()` calls `ConversationListeningSession.instance.startSession()`. No new parameters needed here — `startSession` reads backend/apiKey/model from `SettingsManager` internally, so `EvenAI` remains a thin coordinator.

### `lib/services/conversation_listening_session.dart`

**Signature change**: `startSession` keeps `{required TranscriptSource source}` but internally reads transcription settings from `SettingsManager` to pass to the native side:

```dart
Future<void> startSession({required TranscriptSource source}) async {
  // ... existing setup ...
  final settings = SettingsManager.instance;
  final sourceStr = source == TranscriptSource.glasses ? 'glasses' : 'microphone';
  final apiKey = settings.transcriptionBackend == 'openai'
      ? await settings.getApiKey('openai')
      : null;

  await _invokeMethod('startEvenAI', {
    'language': langCode,
    'source': sourceStr,
    'backend': settings.transcriptionBackend,
    'apiKey': apiKey,
    'model': settings.transcriptionModel,
  });
}
```

This keeps the `startSession` method signature unchanged so `EvenAI` and `HomeScreen` callers need no changes.

### `lib/services/settings_manager.dart`

Add settings fields:
```dart
String transcriptionBackend = 'openai';      // 'openai', 'appleCloud', 'appleOnDevice'
String transcriptionModel = 'gpt-4o-mini-transcribe';
String preferredMicSource = 'auto';           // 'auto', 'glasses', 'phone'
```

### `lib/screens/settings_screen.dart`

Add Transcription section with:
- Backend picker (OpenAI Realtime / Apple Cloud / Apple On-Device)
- Model picker (when OpenAI selected): gpt-4o-transcribe, gpt-4o-mini-transcribe
- Microphone source picker (Auto / Glasses / Phone)

### `lib/screens/home_screen.dart`

Apply `preferredMicSource` override in `_startRecording()`:
```dart
final useGlasses = switch (settings.preferredMicSource) {
  'glasses' => BleManager.isBothConnected(),
  'phone' => false,
  _ => BleManager.isBothConnected(),  // 'auto'
};
```

## Unchanged Files

- `lib/services/conversation_engine.dart` — receives transcription text the same way
- `lib/services/hud_controller.dart` — no changes
- `lib/services/glasses_answer_presenter.dart` — no changes
- `lib/services/llm/` — LLM layer is separate from transcription

## Error Handling

| Scenario | Behavior |
|----------|----------|
| OpenAI API key missing | Detected before connecting — fall back to Apple Cloud Speech, show info in UI |
| OpenAI API key expired/revoked (HTTP 401) | Detected on WebSocket handshake — fall back immediately, show error in UI |
| WebSocket connection fails (network) | Retry once, then fall back to Apple Cloud Speech |
| WebSocket disconnects mid-session | Auto-reconnect, resume sending audio |
| Apple Speech not authorized | Show permission error via `errorStream` |
| Network unavailable + OpenAI selected | Fall back to Apple On-Device |
| Glasses disconnect during recording | Switch to phone mic, continue session |

## Testing

- Unit tests for `AudioResampler` (16kHz → 24kHz conversion accuracy)
- Existing `ConversationListeningSession` tests continue to pass (Dart side unchanged)
- Manual testing: record on phone mic with each backend, verify transcripts appear
- Manual testing: record via glasses mic with OpenAI backend

## Cost Estimate

- `gpt-4o-mini-transcribe`: ~$0.01/min (cheapest real-time option)
- `gpt-4o-transcribe`: ~$0.06/min (highest accuracy)
- Apple backends: free
