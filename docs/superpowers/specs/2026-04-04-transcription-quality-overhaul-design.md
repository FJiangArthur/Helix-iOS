# Transcription Quality Overhaul

**Date**: 2026-04-04
**Status**: Approved
**Problem**: Transcription quality is very low when using OpenAI gpt-4o-transcribe and gpt-4o-mini-transcribe — wrong words, garbled words, missing words, long delays, and sentence fragments.

## Root Cause Analysis

A three-role agentic review (SDE, PM, QA) identified 13 issues across the transcription pipeline. The primary audio source is phone microphone, which follows the worst-case path: 48kHz hardware → 16kHz (AVAudioConverter) → 24kHz (linear interpolation resampler). This double conversion truncates speech content at 8kHz then adds aliasing artifacts.

### Symptom-to-Cause Mapping

| Symptom | Root Causes |
|---------|-------------|
| Wrong/garbled words | Linear interpolation resampler adds artifacts; double conversion loses 8-12kHz frequency content (fricatives, sibilants) |
| Missing words | Audio dropped during reconnect; prefix_padding_ms too short clips utterance starts |
| Long delays | Session config race — audio flushes before server configures; main thread timer jitter |
| Sentence fragments | VAD silence_duration_ms=500 cuts speakers mid-thought |

## Design

### Section 1: Audio Resampling Overhaul

**1.1 Replace AudioResampler with AVAudioConverter**

Rewrite `AudioResampler.swift` to use `AVAudioConverter` with sinc interpolation. Same static API:

```swift
static func resample(pcm16Data: Data, fromRate: Int, toRate: Int) -> Data
```

Internally creates `AVAudioConverter(from: inputFormat, to: outputFormat)` and uses `convert(to:error:withInputFrom:)`.

**1.2 Direct 48kHz → 24kHz path for phone mic + OpenAI Realtime**

In `SpeechStreamRecognizer`, add `openAIMicrophoneOutputFormat24kHz` at 24kHz. When the backend is `.openai` (Realtime WebSocket), the mic tap converts directly to 24kHz, bypassing `AudioResampler` entirely. `OpenAIRealtimeTranscriber` gains an `inputAlready24kHz` flag to skip its internal resampling.

**1.3 Batch API path for gpt-4o-transcribe at native sample rate**

Route `gpt-4o-transcribe` and `gpt-4o-mini-transcribe` through the existing `WhisperBatchTranscriber` as an alternative to the Realtime WebSocket. These models are supported by the batch `/v1/audio/transcriptions` REST endpoint, which accepts WAV at any sample rate — the server handles optimal downsampling.

For the batch path with phone mic:
- Mic tap captures at hardware rate (typically 48kHz) and converts to 48kHz PCM16 (or keeps native format)
- `WhisperBatchTranscriber` encodes as WAV and POSTs to the API — no client-side resampling needed
- Server receives full-bandwidth audio and does its own high-quality conversion

Add a new setting `transcriptionTransport` with values:
- `"realtime"` — Realtime WebSocket (streaming partials, lower latency)
- `"batch"` — Batch REST API (best audio quality, slightly higher latency)

Default: `"realtime"`. Exposed in Settings so the user can A/B test.

When `transcriptionTransport == "batch"` and model is `gpt-4o-transcribe` or `gpt-4o-mini-transcribe`, `ConversationListeningSession` sets backend to `"whisper"` (reusing the existing batch path) with the selected model name.

**1.4 BLE glasses path**

Unchanged: 16kHz → `AudioResampler` (now high-quality via AVAudioConverter) → 24kHz for Realtime, or 16kHz WAV for batch.

**Files**: `AudioResampler.swift`, `SpeechStreamRecognizer.swift`, `OpenAIRealtimeTranscriber.swift`, `WhisperBatchTranscriber.swift`, `settings_manager.dart`, `conversation_listening_session.dart`

### Section 2: VAD Configuration Fix

**2.1 Update default VAD parameters**

In `OpenAIRealtimeTranscriber.sessionConfigEvent()`:

| Parameter | Old | New (transcription) | New (conversation) |
|-----------|-----|---------------------|-------------------|
| threshold | 0.5 | 0.35 | 0.35 |
| silence_duration_ms | 500 / 800 | 1000 | 1200 |
| prefix_padding_ms | 300 | 500 | 500 |

**2.2 Wire vadSensitivity setting end-to-end**

- `ConversationListeningSession` reads `settings.vadSensitivity` and passes in `startEvenAI` platform channel call
- `AppDelegate` extracts it and passes to `SpeechStreamRecognizer.startRecognition()`
- `SpeechStreamRecognizer` forwards to `OpenAIRealtimeTranscriber`
- `OpenAIRealtimeTranscriber` uses it in `sessionConfigEvent()`

**2.3 Sensitivity-to-threshold mapping**

`vadSensitivity` is 0.0-1.0 (higher = more sensitive). Maps inversely: `threshold = 0.6 - (sensitivity * 0.4)`, giving range 0.2-0.6.

**Files**: `OpenAIRealtimeTranscriber.swift`, `SpeechStreamRecognizer.swift`, `AppDelegate.swift`, `conversation_listening_session.dart`

### Section 3: Reconnect & Session Reliability

**3.1 Buffer audio during reconnect**

Remove `guard isConnected` from `appendAudio()`. Audio always appends to `audioBuffer`. `flushAudioBuffer()` already checks `isConnected` before sending. Add a 5-second cap (240KB at 24kHz) to prevent unbounded growth.

**3.2 Gate audio flush on session confirmation**

Add `sessionConfigured` flag. Set to `false` on connect, set to `true` on `transcription_session.updated` / `session.updated`. `flushAudioBuffer()` checks this flag plus `isConnected`.

**3.3 Fix rapid start/stop race**

Replace 0.5s `DispatchQueue.main.asyncAfter` in `stop()` with a cancellable `DispatchWorkItem`. On `start()`, cancel any pending delayed disconnect. Add a `sessionId` counter so old delayed operations are no-ops.

**3.4 Reset retry count on successful reconnect**

In `urlSession(_:webSocketTask:didOpenWithProtocol:)`, set `retryCount = 0`.

**3.5 Recovery from transcription.failed**

On `transcription.failed`, send `input_audio_buffer.clear`. If 3+ failures within 30 seconds, trigger full reconnect.

**Files**: `OpenAIRealtimeTranscriber.swift`

### Section 4: Product-Level Improvements

**4.1 Default model change**

`SettingsManager.transcriptionModel` default: `gpt-4o-mini-transcribe` → `gpt-4o-transcribe`. Existing saved preferences unaffected.

**4.2 Transcription prompt support**

Add `transcriptionPrompt` to `SettingsManager` (SharedPreferences, default empty string). Pass through platform channel to native. Wire into:
- `OpenAIRealtimeTranscriber.sessionConfigEvent()` → `"prompt"` field in `"input_audio_transcription"`
- `WhisperBatchTranscriber.postToWhisper()` → multipart form field `"prompt"`

User sets in Settings, e.g.: "Names: Art, Helix. Topics: AI, smart glasses."

**4.3 Move send timer off main thread**

Replace `Timer.scheduledTimer` with `DispatchSourceTimer` on `DispatchQueue(label: "com.helix.openai.audio")`. Protect `audioBuffer` with this queue. WebSocket sends fire from any queue.

**4.4 BLE VAD gating for OpenAI path**

In `SpeechStreamRecognizer.appendPCMData()`, compute RMS via `computeBufferRMS()` before forwarding to `openaiTranscriber.appendAudio()`. Skip if below threshold. Use same `vadTrailingBufferSec` pattern as Whisper mic path.

**Files**: `settings_manager.dart`, `conversation_listening_session.dart`, `AppDelegate.swift`, `OpenAIRealtimeTranscriber.swift`, `WhisperBatchTranscriber.swift`, `SpeechStreamRecognizer.swift`

## Files Changed Summary

| File | Sections |
|------|----------|
| `ios/Runner/AudioResampler.swift` | 1 |
| `ios/Runner/OpenAIRealtimeTranscriber.swift` | 1, 2, 3, 4 |
| `ios/Runner/SpeechStreamRecognizer.swift` | 1, 2, 4 |
| `ios/Runner/WhisperBatchTranscriber.swift` | 1, 4 |
| `ios/Runner/AppDelegate.swift` | 2 |
| `lib/services/settings_manager.dart` | 1, 4 |
| `lib/services/conversation_listening_session.dart` | 1, 2, 4 |
| `lib/screens/settings_screen.dart` | 1 (transport toggle) |

## Testing Strategy

1. **Audio quality**: Record known speech at 48kHz, run through old vs new resampler, compare FFT spectra
2. **VAD behavior**: Test with natural conversation pauses (1-2s), verify sentences stay intact
3. **Reconnect reliability**: Simulate stale partials, verify no audio gaps in transcript
4. **Session config**: Log ordering of config-confirmed vs first-audio-sent
5. **Rapid toggle**: Toggle recording 5x in 2 seconds, verify final session works
6. **Transcription prompt**: Set domain vocabulary, verify improved accuracy for those terms
7. **Realtime vs Batch A/B test**: Manual comparison on phone mic with same speech sample:
   - Realtime (48→24kHz, streaming partials)
   - Batch (48kHz native WAV, server-side conversion)
   - Compare: word accuracy, latency, sentence completeness
8. **End-to-end**: Side-by-side comparison of transcript quality before/after all changes
