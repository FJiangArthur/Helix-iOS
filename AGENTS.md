# Agent Context

## Repo Identity

- **Project**: Helix-iOS
- **Type**: Flutter app with iOS-native integrations
- **Purpose**: Companion app for Even Realities G1 smart glasses with real-time conversation intelligence, HUD output, BLE integration, and AI analysis

## Operating Rules

- Read and follow `CLAUDE.md` before making changes.
- Run `bash scripts/run_gate.sh` before completing any code task.
- Minimum validation: `flutter analyze`, `flutter test test/`, `flutter build ios --simulator --no-codesign`

## Architecture

- **Entry**: `lib/main.dart` -> `lib/app.dart` (4-tab IndexedStack: Home, Glasses, History, Settings)
- **Native bridge**: `method.bluetooth`, `eventSpeechRecognize`, `eventRealtimeAudio`
- **State**: GetX + plain Streams
- **Database**: Drift (SQLite) with DAOs under `lib/services/database/`
- **Settings**: SharedPreferences + FlutterSecureStorage via `SettingsManager`

## Key Services

| File | Purpose |
|------|---------|
| `lib/services/conversation_engine.dart` | Transcription -> question detection -> AI response -> HUD |
| `lib/services/conversation_listening_session.dart` | Platform channel bridge for speech capture |
| `lib/services/llm/llm_service.dart` | Multi-provider LLM registry and routing |
| `lib/services/settings_manager.dart` | All app settings persistence |
| `lib/services/bitmap_hud/bitmap_hud_service.dart` | HUD widget registration and bitmap rendering |
| `lib/services/evenai.dart` | Glasses touchpad routing, session coordination |
| `lib/services/button_gesture_detector.dart` | BLE button gesture state machine |

## Native iOS

| File | Purpose |
|------|---------|
| `ios/Runner/AppDelegate.swift` | BLE setup, platform channel handlers |
| `ios/Runner/BluetoothManager.swift` | BLE connection management |
| `ios/Runner/SpeechStreamRecognizer.swift` | 4-backend speech recognition |

## Known Bugs

See `docs/TEST_BUG_REPORT.md` for full list (BUG-001 through BUG-006).

## Testing

- Tests under `test/services/`, `test/screens/`, `test/helpers/`
- Shared helpers in `test/helpers/test_helpers.dart`
- See `VALIDATION.md` for gate details
