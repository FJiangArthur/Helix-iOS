# Helix-iOS Validation Gate

This document defines the mandatory validation steps that must pass before any code is considered complete. The gating script at `scripts/run_gate.sh` automates all checks.

## Quick Start

```bash
bash scripts/run_gate.sh
```

Exit code 0 = all gates pass. Exit code 1 = at least one failure. Do not merge or ship if any gate fails.

## Gates

### Gate 1: Static Analysis

```bash
flutter analyze --no-fatal-infos
```

- **Pass criteria**: 0 errors. Warnings and infos are acceptable.
- **What it catches**: Type errors, unused imports, dead code, API misuse.

### Gate 2: Unit Tests

```bash
flutter test test/ --reporter expanded
```

- **Pass criteria**: 100% of tests pass.
- **Test categories**:
  - **Transcription pipeline** (9 tests): Progressive splitting, diarization, partial dedup, error handling
  - **Conversation engine** (45 tests): Modes, analytics, proactive, features, errors, long session
  - **Gesture detector** (8 tests): Single/double/long/five press, cooldown, disconnect
  - **Supporting services** (37 tests): Entity memory, session context, gesture router, silence timeout
  - **E2E flows** (3 tests): Full conversation, multi-turn, mode switching
  - **Pre-existing tests** (25 tests): Models, screens, widgets

### Gate 3: Test Coverage

```bash
flutter test --coverage test/
lcov --summary coverage/lcov.info
```

- **Pass criteria**: Line coverage >= 60% (target: raise to 80% over time).
- **Requires**: `lcov` installed (`brew install lcov`). Skipped if not available.

### Gate 4: iOS Simulator Build

```bash
flutter build ios --simulator --no-codesign
```

- **Pass criteria**: Build succeeds without errors.
- **What it catches**: Compilation errors, missing dependencies, native integration issues.

### Gate 5: Critical TODOs

- **Pass criteria**: <= 5 TODOs in critical files:
  - `lib/services/conversation_engine.dart`
  - `lib/services/conversation_listening_session.dart`
  - `lib/services/recording_coordinator.dart`

### Gate 6: Analyzer Warnings

- **Pass criteria**: <= 10 warnings from `flutter analyze` (reuses Gate 1 output). Infos are always acceptable.

## Running Individual Test Suites

### New tests only (fast validation during development)

```bash
flutter test \
  test/services/button_gesture_detector_test.dart \
  test/services/transcription_pipeline_test.dart \
  test/services/e2e_conversation_flow_test.dart \
  test/services/conversation_engine_error_test.dart \
  test/services/conversation_engine_modes_test.dart \
  test/services/silence_timeout_service_test.dart \
  test/services/conversation_engine_analytics_test.dart \
  test/services/conversation_engine_proactive_test.dart \
  test/services/conversation_engine_features_test.dart \
  test/services/entity_memory_test.dart \
  test/services/session_context_manager_test.dart \
  test/services/gesture_action_router_test.dart \
  test/services/conversation_engine_long_session_test.dart
```

### By category

```bash
# Transcription pipeline
flutter test test/services/transcription_pipeline_test.dart

# Conversation engine (all modes, features, analytics, errors)
flutter test test/services/conversation_engine_modes_test.dart \
  test/services/conversation_engine_analytics_test.dart \
  test/services/conversation_engine_proactive_test.dart \
  test/services/conversation_engine_features_test.dart \
  test/services/conversation_engine_error_test.dart \
  test/services/conversation_engine_long_session_test.dart

# Gesture and interaction
flutter test test/services/button_gesture_detector_test.dart \
  test/services/gesture_action_router_test.dart \
  test/services/silence_timeout_service_test.dart

# Supporting services
flutter test test/services/entity_memory_test.dart \
  test/services/session_context_manager_test.dart

# End-to-end
flutter test test/services/e2e_conversation_flow_test.dart
```

## Test Infrastructure

### Shared helpers (`test/helpers/`)

| File | Purpose |
|------|---------|
| `test_helpers.dart` | `FakeJsonProvider`, platform mocks, `setupTestEngine()`, `configureFakeLlm()` |
| `speech_event_emitter.dart` | Simulates transcription events for `ConversationListeningSession.test()` |
| `stream_recorder.dart` | Subscribes to all 16 ConversationEngine streams, records events with timestamps |

### Writing new tests

1. Import `../helpers/test_helpers.dart`
2. Call `installPlatformMocks()` in `setUpAll`, `removePlatformMocks()` in `tearDownAll`
3. Use `setupTestEngine()` in `setUp` to get a fresh `(engine, provider)` tuple
4. Call `teardownTestEngine(engine)` in `tearDown`
5. Use `provider.enqueueResponse()` / `provider.enqueueStreamResponse()` to control LLM behavior
6. Set `engine.autoDetectQuestions = false` unless testing question detection
7. For analytics tests, add 500ms delays between `onTranscriptionFinalized` calls (see BUG-002)

## Known Bugs

See `docs/TEST_BUG_REPORT.md` for the full list. Key issues that affect testing:

- **BUG-002**: Analytics counter skipped during rapid finalization — tests need delays between segments
- **BUG-003**: Long-press unreachable with production timers — tests use custom short timers
- **Pre-existing screen test failures**: Several screen/widget tests fail due to UI changes not reflected in tests. These are NOT caused by the new test infrastructure.

## When to Run

| Scenario | Command |
|----------|---------|
| During development (quick check) | `flutter test test/services/<file>_test.dart` |
| Before committing | `flutter test test/` |
| Before creating PR | `bash scripts/run_gate.sh` |
| Before release | `bash scripts/run_gate.sh` (all gates must pass) |
