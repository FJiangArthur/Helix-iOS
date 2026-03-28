# Helix-iOS

Flutter companion app for Even Realities G1 smart glasses. Real-time conversation intelligence with AI.

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
- Release builds: device only
- Always boot a **dedicated simulator instance** — the simulator is shared by multiple apps on this machine

## Architecture

- **Native (iOS)**: BluetoothManager.swift, SpeechStreamRecognizer.swift (4 backends), PcmConverter
- **Platform channels**: `method.bluetooth`, `eventSpeechRecognize`, `eventRealtimeAudio`
- **Dart services**: ConversationEngine (singleton, 4 modes), LlmService, EvenAI, HudController
- **State**: GetX + plain Streams
- **Database**: Drift (SQLite) with DAOs for conversations, facts, memories, todos

## Key Files

- `lib/services/conversation_engine.dart` — Core pipeline: transcription -> question detection -> AI response -> display
- `lib/services/conversation_listening_session.dart` — Platform channel bridge, `.test()` factory for testing
- `lib/services/llm/llm_service.dart` — Multi-provider LLM manager (OpenAI, Anthropic, DeepSeek, Qwen, Zhipu)
- `lib/services/button_gesture_detector.dart` — BLE button gesture state machine
- `lib/services/session_context_manager.dart` — Three-tier context window for proactive mode
- `ios/Runner/AppDelegate.swift` — BLE setup, platform channel handlers

## Known Issues

See `docs/TEST_BUG_REPORT.md` for documented bugs including:
- Segment compaction only fires from progressive splitting (BUG-001)
- Analytics counter skipped during rapid finalization (BUG-002)
- Long-press gesture unreachable with production timer defaults (BUG-003)
- RNNoiseProcessor is header-only / not implemented (BUG-006)
