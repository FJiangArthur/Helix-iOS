# Helix Engineering Onboarding

This document is for engineers joining the Helix codebase. It explains how to get productive quickly, which codepaths are active, and which subsystems matter first.

## 1. Product Mental Model

Helix is an AI assistant for Even Realities G1 smart glasses with a usable phone-only fallback.

The product has three primary user jobs:

1. Listen to a live conversation.
2. Turn that conversation into useful AI output.
3. Deliver the output discreetly to the phone UI and, when available, the glasses HUD.

Everything else in the app supports that loop:

- provider configuration
- BLE pairing and text delivery
- dashboard overlays
- local history
- manual recording and debugging tools

## 2. First Files To Read

Read these in order:

1. `lib/main.dart`
2. `lib/app.dart`
3. `lib/screens/home_screen.dart`
4. `lib/services/conversation_engine.dart`
5. `lib/services/conversation_listening_session.dart`
6. `lib/ble_manager.dart`
7. `lib/services/dashboard_service.dart`
8. `lib/services/settings_manager.dart`

If you only understand those files, you can already reason about most regressions in the app.

## 3. Environment Setup

### Required Tools

- Flutter SDK
- Dart SDK bundled with Flutter
- Xcode
- CocoaPods
- A paired iPhone if you need real device speech/BLE validation

### Bootstrap

```bash
flutter pub get
cd ios && pod install && cd ..
```

### Device Deployment

```bash
flutter devices
flutter run -d <device-id>
```

Important detail:

- The device must be unlocked when the install transitions into launch.
- A successful build does not guarantee successful launch if SpringBoard denies it.

## 4. Runtime Architecture

### Startup

Startup is intentionally thin and imperative.

`main()` currently does four things before `runApp()`:

1. loads persisted settings
2. starts BLE listeners
3. initializes LLM provider state
4. initializes dashboard listeners

That means a large amount of app state is singleton-driven. When changing startup behavior, check for hidden assumptions in singleton constructors and side effects.

### App Shell

`AppEntry` decides whether onboarding is shown.

`MainScreen` hosts the five primary tabs:

- Assistant
- Glasses
- History
- Record
- Settings

### Conversation Path

The active assistant pipeline is:

```text
speech events
  -> ConversationListeningSession
  -> ConversationEngine.start / update / finalize
  -> question detection
  -> LlmService
  -> ai response stream
  -> HUD / text delivery
```

Two things matter operationally:

- `ConversationListeningSession` owns the bridge between Flutter and native speech events.
- `ConversationEngine` owns almost all conversational state and output policy.

### Glasses Path

The glasses path is split across BLE transport and HUD orchestration:

- `BleManager` manages connection and native bridge calls.
- `TextService` and HUD services serialize payloads for device rendering.
- `DashboardService` listens for trigger events and temporarily takes over the display.

## 5. User-Facing Surfaces

### Assistant Tab

This is the primary product surface.

What users do here:

- start or stop live listening
- type quick-ask prompts
- review the active transcript
- inspect generated answers
- switch interaction mode

What developers should watch here:

- speech start/stop behavior
- provider/model selection propagation
- stale stream cancellation
- HUD duplication or route contention

### Glasses Tab

This is the hardware operations console.

What users do here:

- scan for glasses
- connect or disconnect
- inspect connection status
- replay last handoff
- access utility workflows

### History Tab

This is local assistant memory, not a server-backed conversation archive.

It groups `ConversationTurn` entries into user-facing sessions with filters for:

- mode
- favorites
- action items
- fact-check flags

### Record Tab

This is a distinct recording flow, not the same thing as live assistant listening.

That distinction is important because audio session conflicts often come from assuming these surfaces are interchangeable.

### Settings Tab

This is where providers, models, API keys, language, automation toggles, and display preferences are configured.

When debugging unexpected assistant behavior, inspect settings before changing business logic.

## 6. Native iOS Boundary

These files are the key native boundary:

- `ios/Runner/AppDelegate.swift`
- `ios/Runner/SpeechStreamRecognizer.swift`
- `ios/Runner/OpenAIRealtimeTranscriber.swift`
- `ios/Runner/AudioResampler.swift`

Common failure modes:

- source file exists on disk but is missing from `Runner.xcodeproj`
- microphone permission works but launch fails because the phone is locked
- speech event channels attach after native events begin
- audio session conflicts between recording and live transcription

## 7. Settings And Persistence

`SettingsManager` is the operational source of truth for:

- active provider and model
- stored API keys
- conversation automation toggles
- preferred mic source
- display settings
- onboarding completion

It uses a mix of `SharedPreferences` and `FlutterSecureStorage`.

Rule of thumb:

- product preferences go in shared preferences
- secrets go in secure storage

## 8. How To Add Features Safely

When adding a new feature, decide which layer owns it before writing code.

Use this split:

- UI composition or user controls: screen or widget
- persisted preference or user default: `SettingsManager`
- live assistant behavior: `ConversationEngine`
- speech transport/session lifecycle: `ConversationListeningSession`
- device rendering or hardware routing: BLE/HUD services
- provider-specific model calls: `services/llm/*`

Avoid pushing new product logic directly into a screen if it affects more than presentation state.

## 9. Common Debugging Entry Points

### “Listening starts but nothing transcribes”

Inspect:

- native speech bridge startup
- event channel attachment
- microphone permissions
- selected mic source
- whether the recording screen currently owns the audio session

### “Answer text appears too slowly”

Inspect:

- `ConversationEngine` response batching
- provider streaming granularity
- HUD streaming path

### “Build works but app will not open on device”

Inspect:

- device unlocked state
- signing identity
- whether native source files are present in `Runner.xcodeproj`

### “Glasses connected but HUD content is wrong”

Inspect:

- `HudController` current intent
- `DashboardService` activity
- `TextService` sending state
- latest handoff memory

## 10. Suggested First Tasks For New Engineers

If you are new to the codebase, do these first:

1. Build and launch on simulator.
2. Build and install on a physical phone.
3. Add an API key and verify provider switching.
4. Run a typed quick ask from the Assistant tab.
5. Trace a spoken question from speech input to `ConversationEngine`.
6. Pair glasses and send a manual text handoff.

Those steps expose almost every important system boundary.
