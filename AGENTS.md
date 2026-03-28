# Codex Context

This file captures the local working context I built while taking over the
repository on 2026-03-27. It is not a product spec; it is an operator note for
future coding sessions.

## Repo Identity

- Project: `Helix-iOS`
- Type: Flutter app with iOS-native integrations
- Purpose: companion app for Even Realities smart glasses with real-time
  conversation intelligence, HUD output, BLE integration, and AI-backed
  analysis

## Operating Rules

- Read and follow `CLAUDE.md` before making changes.
- Before closing any code task, run the required validation gate:
  `bash scripts/run_gate.sh`
- Minimum expected validation for normal code changes:
  - `flutter analyze --no-fatal-infos`
  - `flutter test test/ --reporter expanded`
  - `flutter build ios --simulator --no-codesign`
- Be careful with existing uncommitted work. The repo is already dirty and
  contains many user changes across Dart, iOS, docs, tests, and generated
  files.

## High-Level Architecture

- Flutter entry point: `lib/main.dart`
- App shell and tab navigation: `lib/app.dart`
- Native bridge channel: `method.bluetooth`
- Native event channels:
  - `eventSpeechRecognize`
  - `eventRealtimeAudio`
- Core runtime path:
  - `ConversationListeningSession`
  - `ConversationEngine`
  - `LlmService` and provider implementations
  - HUD / bitmap HUD services
  - BLE manager and gesture pipeline

## Important Services

- `lib/services/conversation_engine.dart`
  - Main orchestration pipeline for transcription, question detection, AI
    response generation, history, proactive suggestions, analytics, and HUD
    output.
- `lib/services/conversation_listening_session.dart`
  - Platform-channel bridge that starts/stops native speech capture, receives
    transcription events, finalizes transcripts, and forwards realtime AI
    responses.
- `lib/services/llm/llm_service.dart`
  - Multi-provider LLM registry and active-provider routing.
- `lib/services/session_context_manager.dart`
  - Proactive-mode context management and long-session memory shaping.
- `lib/services/button_gesture_detector.dart`
  - BLE button gesture state machine.
- `lib/services/entity_memory.dart`
  - Persisted people/company memory loaded on app startup.
- `lib/services/bitmap_hud/bitmap_hud_service.dart`
  - HUD widget registration and bitmap refresh flow.

## Native iOS Notes

- Native bootstrap: `ios/Runner/AppDelegate.swift`
- Native responsibilities include:
  - Bluetooth manager wiring
  - speech recognition / transcription backend startup
  - realtime audio output event forwarding
  - NaturalLanguage-based text analysis bridge
- Key native files seen during takeover:
  - `ios/Runner/BluetoothManager.swift`
  - `ios/Runner/SpeechStreamRecognizer.swift`
  - `ios/Runner/WhisperBatchTranscriber.swift`
  - `ios/Runner/SpeakerTurnDetector.swift`

## Data and Persistence

- Drift-backed SQLite database under `lib/services/database/`
- SharedPreferences for lightweight app flags such as onboarding completion
- secure storage for provider API keys through `SettingsManager`

## UI Shape

- Main tabs:
  - Home
  - Memories
  - Facts
  - Buzz
  - Settings
- Screens live mostly under `lib/screens/`
- Theme root: `lib/theme/helix_theme.dart`

## Testing Shape

- Tests are concentrated under `test/services/`, `test/screens/`, and
  `test/helpers/`
- Shared test infrastructure exists in `test/helpers/test_helpers.dart`
- Existing bug documentation and test constraints are in
  `docs/TEST_BUG_REPORT.md` and `VALIDATION.md`

## Known Risks / Bugs

Current documented issues from `docs/TEST_BUG_REPORT.md`:

- BUG-001: segment compaction only runs on progressive splitting path
- BUG-002: analytics counters can be skipped during rapid finalization
- BUG-003: long-press timing defaults are internally inconsistent
- BUG-004: test emitter `segmentId` type mismatch risk
- BUG-005: compaction can silently lose data on failure
- BUG-006: RNNoise processor is header-only / not implemented

## Current Worktree Reality

At takeover time, `git status --short` showed:

- many modified tracked files
- many untracked new feature/test/doc files
- generated plugin/lock/build artifacts mixed in with real source changes

Implication:

- do not assume clean baseline
- do not revert unrelated changes
- inspect surrounding diffs before editing shared files

## Recommended Takeover Flow For Future Sessions

1. Read `CLAUDE.md`
2. Check `git status --short`
3. Inspect the task-specific files
4. Run the narrowest useful tests first
5. Run `bash scripts/run_gate.sh` before declaring completion

## Source Files Used To Build This Context

- `CLAUDE.md`
- `README.md`
- `VALIDATION.md`
- `docs/TEST_BUG_REPORT.md`
- `scripts/run_gate.sh`
- `lib/main.dart`
- `lib/app.dart`
- `lib/services/conversation_engine.dart`
- `lib/services/conversation_listening_session.dart`
- `ios/Runner/AppDelegate.swift`
