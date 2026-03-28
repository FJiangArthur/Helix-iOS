# Agent Context

## Repo Identity

- **Project**: Helix-iOS
- **Type**: Flutter app with iOS-native integrations
- **Purpose**: Companion app for Even Realities G1 smart glasses — real-time conversation intelligence, all-day passive listening, embedded knowledge base, multi-tier LLM support, and BLE HUD output

## Operating Rules

- Read and follow `CLAUDE.md` before making changes.
- Run `bash scripts/run_gate.sh` before completing any code task.
- Minimum validation: `flutter analyze`, `flutter test test/`, `flutter build ios --simulator --no-codesign`
- Always boot a **dedicated simulator instance** for testing — never reuse shared ones.

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                  RecordingCoordinator                    │
│                                                         │
│  ┌─────────────────────┐  ┌──────────────────────────┐  │
│  │  ALL-DAY PASSIVE    │  │  ACTIVE SESSION          │  │
│  │  Phone mic (VAD)    │  │  Glasses/phone mic       │  │
│  │  On-device STT      │  │  Cloud streaming STT     │  │
│  │  NLTagger NER       │  │  Full AI pipeline        │  │
│  │  → Knowledge Base   │  │  Multi-tier models       │  │
│  │  Background-safe    │  │  28s glasses auto-restart │  │
│  └─────────────────────┘  └──────────────────────────┘  │
│                                                         │
│  Active pauses passive; passive resumes when active ends│
└─────────────────────────────────────────────────────────┘
```

- **Entry**: `lib/main.dart` → `lib/app.dart` (5-tab IndexedStack: Home, Memories, Facts, Buzz, Settings)
- **Native bridge**: `method.bluetooth`, `method.passiveAudio`, `method.naturalLanguage`, `eventSpeechRecognize`, `eventPassiveTranscription`, `eventRealtimeAudio`, `eventGlassesMicHealth`
- **State**: GetX + plain Streams
- **Database**: Drift (SQLite) with DAOs under `lib/services/database/`
- **Settings**: SharedPreferences + FlutterSecureStorage via `SettingsManager`

## Multi-Tier Model System

LLM calls are routed to two tiers via `SettingsManager.lightModel` / `smartModel`:

| Tier | Tasks | Typical Model |
|------|-------|---------------|
| Light | Question detection, sentiment, entity extraction, fact extraction, pipeline | `gpt-4o-mini` |
| Smart | Response generation, proactive analysis, Buzz answers | `gpt-4.1` |

Pass `model:` parameter to `LlmService.getResponse()` / `streamWithTools()` to override.

## Key Services

| File | Purpose |
|------|---------|
| `lib/services/conversation_engine.dart` | Core pipeline: transcription → detection → AI response → HUD |
| `lib/services/conversation_listening_session.dart` | Platform channel bridge for speech events |
| `lib/services/llm/llm_service.dart` | Multi-provider LLM registry with per-call model override |
| `lib/services/recording_coordinator.dart` | Unified recording toggle, passive mode pause/resume |
| `lib/services/knowledge_base.dart` | Entity/relationship/profile store, system prompt context |
| `lib/services/analysis_backend.dart` | AnalysisProvider interface (Cloud, llama.cpp, Foundation Models) |
| `lib/services/analysis_orchestrator.dart` | Merges analysis results into knowledge base |
| `lib/services/local_analysis_service.dart` | NLTagger NER (EN+ZH) via platform channel |
| `lib/services/passive_listening_service.dart` | All-day VAD-gated passive listening coordinator |
| `lib/services/evenai.dart` | Glasses session coordination, continuous mode |
| `lib/services/button_gesture_detector.dart` | BLE button gesture state machine |
| `lib/services/settings_manager.dart` | All settings persistence (model tiers, all-day mode, VAD) |
| `lib/services/bitmap_hud/bitmap_hud_service.dart` | HUD widget registration and 640x400 bitmap rendering |

## Native iOS

| File | Purpose |
|------|---------|
| `ios/Runner/AppDelegate.swift` | Platform channel handlers (BLE, speech, NLTagger, passive audio) |
| `ios/Runner/BluetoothManager.swift` | BLE connection, LC3 decode, mic data routing |
| `ios/Runner/SpeechStreamRecognizer.swift` | 4-backend speech recognition (Apple Cloud/On-Device, OpenAI Realtime, Whisper) |
| `ios/Runner/PassiveAudioMonitor.swift` | VAD + on-device SFSpeechRecognizer for all-day mode |
| `ios/Runner/GlassesMicSessionManager.swift` | 28s auto-restart for continuous glasses mic sessions |
| `ios/Runner/PcmConverter.m` | LC3 → PCM16 decoder (Google lc3 codec) |

## Database Schema

| Table | Purpose |
|-------|---------|
| `conversations` | Conversation records with mode, summary, sentiment |
| `conversation_segments` | Individual transcript segments with speaker labels |
| `facts` | Extracted personal facts (pending/confirmed/rejected) |
| `knowledge_entities` | People, companies, projects, places, topics |
| `knowledge_relationships` | Entity-to-entity relationships (works_at, reports_to, etc.) |
| `user_profiles` | Evolving user profile JSON (identity, style, interests) |
| `daily_memories` | Daily narrative summaries |
| `todos` | Action items extracted from conversations |
| `voice_notes` | Voice recordings with transcripts |

## Known Bugs

See `docs/TEST_BUG_REPORT.md` for full list (BUG-001 through BUG-006).

Key issues:
- **BUG-002**: Analytics counter skipped during rapid finalization — tests need 500ms delays between segments
- **BUG-003**: Long-press unreachable with production timer defaults (multiTap=300ms < longPress=600ms)

## Testing

- **145+ tests** under `test/services/`, `test/screens/`, `test/models/`
- Shared helpers in `test/helpers/test_helpers.dart` (FakeJsonProvider, SpeechEventEmitter, StreamRecorder)
- See `VALIDATION.md` for gate details and how to write new tests
- Gate script: `bash scripts/run_gate.sh` (6 gates: analyze, test, coverage, build, TODOs, warnings)

## Design Docs

- `docs/superpowers/specs/2026-03-26-allday-passive-streaming-design.md`
- `docs/superpowers/plans/2026-03-26-allday-streaming-plan-a-knowledge-base.md`
- `docs/superpowers/plans/2026-03-27-plan-b-passive-listening.md`
- `docs/superpowers/plans/2026-03-27-plan-c-continuous-active.md`
