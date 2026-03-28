# Helix-iOS

Flutter companion app for Even Realities G1 smart glasses. Real-time conversation intelligence with AI.

**Version**: 1.1.0+2

## Validation (MANDATORY)

**Before completing any code change**, run the validation gate:

```bash
bash scripts/run_gate.sh
```

See `VALIDATION.md` for full details on each gate and how to run individual test suites.

### Minimum validation before any commit or PR:

1. **Run `flutter analyze`** — must have 0 errors
2. **Run `flutter test test/`** — all tests must pass
3. **Run `flutter build ios --simulator --no-codesign`** — must build successfully

### After modifying these files, run the FULL gate (`bash scripts/run_gate.sh`):

- `lib/services/conversation_engine.dart`
- `lib/services/conversation_listening_session.dart`
- `lib/services/recording_coordinator.dart`
- `lib/services/button_gesture_detector.dart`
- `lib/services/entity_memory.dart`
- `lib/services/session_context_manager.dart`
- `lib/services/silence_timeout_service.dart`
- Any file in `test/helpers/`

### When writing new tests:

- Use shared helpers from `test/helpers/test_helpers.dart`
- Follow patterns in `VALIDATION.md` > "Writing new tests"
- For analytics tests, add 500ms delays between segment finalizations (known BUG-002)

## Build

- Xcode 26.3, Flutter 3.35+, iOS 15+
- Debug builds: `flutter run -d <sim-id>` (simulator)
- Release builds: device only (`flutter run --release -d <device-id>`)
- Always boot a **dedicated simulator instance** — the simulator is shared by multiple apps on this machine
- Simulators in use: iPhone 17 Pro (`0D7C3AB2`) = Album Clean, iPhone 17 (`6D249AFF`) = Pet App. Boot a separate instance for Helix.

## Product Overview

Helix listens to conversations, detects questions, generates AI answers, and displays them on the glasses HUD — hands-free.

### User Flows

1. **Live Conversation**: Listen -> transcribe -> detect question -> AI answer -> stream to glasses HUD -> background fact-check
2. **Text Query**: Type question -> AI answer -> phone + optional glasses -> follow-up chips
3. **Interview Coach**: Directly speakable output, STAR framework, no "you could say" phrasing
4. **Passive Listener**: Silent monitor, only facts/corrections/context

### Configuration

| Setting | Default | Range |
|---------|---------|-------|
| Max Response Sentences | 3 | 1-10 |
| Transcription Backend | OpenAI | OpenAI / Apple Cloud / Apple On-Device |
| Transcription Models | gpt-4o-mini-transcribe | gpt-4o-mini-transcribe, gpt-4o-transcribe, whisper-1, gpt-4o-mini-realtime, gpt-4o-realtime |
| HUD Render Path | Bitmap | Bitmap / Text (fallback) |
| Auto-detect Questions | On | On / Off |
| Auto-answer | On | On / Off |

### AI Providers

| Provider | Models |
|----------|--------|
| OpenAI | gpt-4.1, gpt-4.1-mini, gpt-4.1-nano, gpt-realtime |
| Anthropic | claude-sonnet-4, claude-haiku-4 |
| DeepSeek | deepseek-chat, deepseek-reasoner |
| Qwen | qwen-turbo, qwen-plus, qwen-max |
| Zhipu | glm-4-flash, glm-4 |

## Architecture

- **Native (iOS)**: BluetoothManager.swift, SpeechStreamRecognizer.swift (4 backends), PcmConverter
- **Platform channels**: `method.bluetooth`, `eventSpeechRecognize`, `eventRealtimeAudio`
- **Dart services**: ConversationEngine (singleton, 3 modes), LlmService, EvenAI, HudController
- **State**: GetX + plain Streams
- **Database**: Drift (SQLite) with DAOs for conversations, facts, memories, todos
- **Settings**: SharedPreferences + FlutterSecureStorage via `SettingsManager`

### Key Files

| File | Purpose |
|------|---------|
| `lib/main.dart` | App init: SettingsManager -> BleManager -> LlmService -> ConversationEngine |
| `lib/app.dart` | 4-tab IndexedStack: Home, Glasses, History, Settings |
| `lib/services/conversation_engine.dart` | Core pipeline: transcription -> question detection -> AI -> HUD |
| `lib/services/conversation_listening_session.dart` | Platform channel bridge, `.test()` factory |
| `lib/services/llm/llm_service.dart` | Multi-provider LLM manager |
| `lib/services/llm/openai_provider.dart` | OpenAI provider (gpt-4.1 family + realtime) |
| `lib/services/settings_manager.dart` | All app settings persistence |
| `lib/services/evenai.dart` | Glasses touchpad routing, session coordination |
| `lib/services/bitmap_hud/bitmap_hud_service.dart` | HUD widget registration and bitmap rendering |
| `lib/services/button_gesture_detector.dart` | BLE button gesture state machine |
| `lib/services/session_context_manager.dart` | Three-tier context window for proactive mode |
| `lib/services/recording_coordinator.dart` | Unified recording toggle |
| `ios/Runner/AppDelegate.swift` | BLE setup, platform channel handlers |
| `ios/Runner/BluetoothManager.swift` | BLE dual connection (L/R glasses) |
| `ios/Runner/SpeechStreamRecognizer.swift` | 4-backend speech recognition |
| `ios/Runner/OpenAIRealtimeTranscriber.swift` | OpenAI WebSocket transcription |

### BLE & HUD Protocol

- G1 uses dual BLE connections (L/R glasses) via `MethodChannel('method.bluetooth')`
- Touchpad events: `notifyIndex` 0=exit, 1=pageBack/Forward (L/R), 2=headUp, 3=headDown, 23=evenaiStart, 24=evenaiRecordOver
- EvenAI protocol: multi-packet chunking (191 bytes/packet) with sequence numbers
- Packet header: `[cmd, syncSeq, maxSeq, seq, newScreen, pos(2B), currentPage, maxPage, ...data]`
- Screen codes: `0x01` new content, `0x30` AI streaming, `0x40` AI complete, `0x70` text page
- Text HUD: 488px max width, 21pt font, 5 lines per page
- Bitmap HUD: Full widget-based rendering via `BitmapHudService`

### Touchpad Behavior (liveListening mode)

| State | Left Touchpad | Right Touchpad |
|-------|--------------|----------------|
| No active answer | Pause/resume transcription | Trigger manual question detection |
| Active answer displayed | Previous page | Next page |

Answer flag (`EvenAI.hasActiveAnswer`) set when response completes, cleared when new transcription arrives.

## Technical Findings

### Transcription
- Apple Cloud is the most reliable backend for continuous conversation transcription
- OpenAI `didEmitFinalResult` guard was blocking all finals after first segment — fixed by resetting on new partials
- `AVAudioInputNode.installTap` crashes with hardcoded 16kHz — must use hardware input format and convert
- Stale partial detection: reconnect after 25 identical partials (~2.5s)
- Shutdown `buffer too small` error is benign — suppressed from user display

### LLM Providers
- OpenAI-compatible providers (DeepSeek/Qwen/Zhipu) share `OpenAiCompatibleProvider` base class
- Anthropic uses custom SSE parsing (`content_block_delta` events)
- Model filter: `filterQueriedModels()` only keeps gpt-4.1 family + realtime models

### Prompts
- All mode prompts use `maxResponseSentences` from settings (configurable 1-10)
- All prompts enforce direct output — never "you could say" or "here's a suggestion"
- Profile directive is a single line: `Profile: {name} — {answerStyle}`
- Background fact-check runs after every AI response (non-blocking)

### Audio
- Microphone permission deferred to first recording (was triggering at launch)
- RNNoise processor is header-only — noise reduction toggle has no effect (BUG-006)

## Known Bugs

See `docs/TEST_BUG_REPORT.md` for full details:

| Bug | Severity | Summary |
|-----|----------|---------|
| BUG-001 | Medium | Segment compaction only fires from progressive splitting path |
| BUG-002 | Medium | Analytics counter skipped during rapid finalization |
| BUG-003 | Low | Long-press gesture unreachable with production timer defaults |
| BUG-005 | Medium | _compactAndCapSegments silently loses data on failure |
| BUG-006 | Info | RNNoiseProcessor is header-only / not implemented |

## Documentation

| File | Purpose |
|------|---------|
| `CLAUDE.md` | This file — build, architecture, product, findings |
| `AGENTS.md` | Quick-reference agent context |
| `VALIDATION.md` | Test gate details, test suites, writing new tests |
| `docs/product-overview.md` | User flows, configuration, supported hardware |
| `docs/PROGRESS.md` | Feature checklist, version history |
| `docs/learning.md` | Technical findings: BLE protocol, transcription, LLM providers |
| `docs/TEST_BUG_REPORT.md` | Documented bugs with file/line references |
| `docs/appstore-metadata.md` | App Store submission copy |
