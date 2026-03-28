# Helix-iOS

Flutter companion app for Even Realities G1 smart glasses. Real-time conversation intelligence with AI-powered transcription, knowledge base, and all-day passive listening.

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
- `lib/services/knowledge_base.dart`
- `lib/services/passive_listening_service.dart`
- `lib/services/analysis_backend.dart`
- Any file in `test/helpers/`

### When writing new tests:

- Use shared helpers from `test/helpers/test_helpers.dart`
- Follow patterns in `VALIDATION.md` > "Writing new tests"
- For analytics tests, add 500ms delays between segment finalizations (known BUG-002)

## Build

- Xcode 26.3, Flutter 3.35+, iOS 15+
- Debug builds: `flutter run -d <sim-id>` (simulator)
- Release builds: device only
- Always boot a **dedicated simulator instance** — the simulator is shared by multiple apps on this machine

## Architecture

### Two-Mode System

```
RecordingCoordinator
├── ALL-DAY PASSIVE MODE
│   Phone mic (VAD-gated) → on-device STT → NLTagger NER
│   → Knowledge Base → optional cloud batch analysis
│   Background-safe (audio background mode)
│
└── ACTIVE SESSION MODE
    Glasses mic OR phone mic → cloud streaming STT
    Full ConversationEngine AI pipeline
    Auto-restart glasses mic at 28s intervals (GlassesMicSessionManager)
    Real-time response to glasses HUD (640x400 monochrome)
```

### Multi-Tier Model Support

LLM calls use two model tiers (configurable in Settings):

| Tier | Used For | Default |
|------|----------|---------|
| **Light Model** | Question detection, sentiment, entity extraction, fact extraction, pipeline analysis | Provider default (e.g. `gpt-4o-mini`) |
| **Smart Model** | User-facing responses, proactive suggestions, Buzz RAG answers | Provider default (e.g. `gpt-4.1`) |

Set via `SettingsManager.lightModel` / `SettingsManager.smartModel`. Null = use active provider default.

### Layers

- **Native (iOS)**: BluetoothManager.swift, SpeechStreamRecognizer.swift (4 backends), PassiveAudioMonitor.swift, GlassesMicSessionManager.swift, PcmConverter
- **Platform channels**: `method.bluetooth`, `method.passiveAudio`, `method.naturalLanguage`, `eventSpeechRecognize`, `eventPassiveTranscription`, `eventRealtimeAudio`, `eventGlassesMicHealth`
- **Dart services**: ConversationEngine (4 modes), LlmService (multi-tier), PassiveListeningService, EvenAI, HudController, UserKnowledgeBase
- **State**: GetX + plain Streams
- **Database**: Drift (SQLite) — conversations, facts, knowledge_entities, knowledge_relationships, user_profiles, memories, todos

## Key Files

### Core Pipeline
- `lib/services/conversation_engine.dart` — Transcription → question detection → AI response → HUD display
- `lib/services/conversation_listening_session.dart` — Platform channel bridge, `.test()` factory
- `lib/services/llm/llm_service.dart` — Multi-provider LLM with per-call model override
- `lib/services/recording_coordinator.dart` — Unified recording toggle, passive mode pause/resume

### Knowledge Base
- `lib/services/knowledge_base.dart` — Entity/relationship/profile store, context summary for prompts
- `lib/services/database/knowledge_dao.dart` — Drift DAO for KB tables
- `lib/services/analysis_backend.dart` — AnalysisProvider interface + CloudAnalysisProvider
- `lib/services/analysis_orchestrator.dart` — Merges analysis results into KB
- `lib/services/local_analysis_service.dart` — NLTagger NER (EN+ZH) via platform channel

### Passive Listening
- `lib/services/passive_listening_service.dart` — Dart coordinator for all-day mode
- `ios/Runner/PassiveAudioMonitor.swift` — VAD + on-device SFSpeechRecognizer

### Glasses Integration
- `lib/services/evenai.dart` — Glasses session coordination, continuous mode
- `lib/services/button_gesture_detector.dart` — BLE button gesture state machine
- `ios/Runner/GlassesMicSessionManager.swift` — 28s auto-restart for hours-long sessions
- `ios/Runner/BluetoothManager.swift` — BLE connection, LC3 decode, mic data routing
- `ios/Runner/SpeechStreamRecognizer.swift` — 4-backend speech recognition (Apple Cloud, On-Device, OpenAI Realtime, Whisper)

### Settings & Display
- `lib/services/settings_manager.dart` — All settings (allDayMode, model tiers, VAD, analysis backend)
- `lib/services/hud_controller.dart` — HUD state machine for glasses display
- `lib/services/bitmap_hud/bitmap_hud_service.dart` — Dashboard widget rendering (640x400)
- `ios/Runner/AppDelegate.swift` — Platform channel handlers (BLE, speech, NLTagger, passive audio)

## Known Issues

See `docs/TEST_BUG_REPORT.md` for documented bugs including:
- Segment compaction only fires from progressive splitting (BUG-001)
- Analytics counter skipped during rapid finalization (BUG-002)
- Long-press gesture unreachable with production timer defaults (BUG-003)
- _compactAndCapSegments silently loses data on failure (BUG-005)
- RNNoiseProcessor is header-only / not implemented (BUG-006)

## Design Docs

- `docs/superpowers/specs/2026-03-26-allday-passive-streaming-design.md` — All-day mode + KB spec
- `docs/superpowers/plans/2026-03-26-allday-streaming-plan-a-knowledge-base.md` — KB implementation plan
- `docs/superpowers/plans/2026-03-27-plan-b-passive-listening.md` — Passive listening plan
- `docs/superpowers/plans/2026-03-27-plan-c-continuous-active.md` — Continuous active sessions plan
