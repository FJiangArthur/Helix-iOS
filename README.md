# Helix iOS

Helix is a Flutter companion app for Even Realities G1 smart glasses. It combines live transcription, LLM-backed conversation assistance, HUD text delivery, BLE utilities, and local session history into a single operator workflow that can run on phone-only or phone-plus-glasses setups.

## What The App Does

Helix is built around one primary loop:

1. Capture speech from the phone microphone or the glasses pipeline.
2. Stream the transcript into the conversation engine.
3. Detect candidate questions and generate an answer with the active LLM provider.
4. Render the answer on the phone and, when connected, hand it off to the glasses HUD.

The app also includes direct text handoff, glasses utilities, a tilt-triggered dashboard, conversation history, and standalone recording tools.

## Core Functionalities

### Assistant

The Assistant tab is the main runtime surface for live AI assistance.

- Live listening can start from the phone microphone or the glasses path depending on settings and connection state.
- The transcript is streamed into `ConversationEngine`, which tracks partial text, finalized segments, question detection, follow-up chips, and response generation state.
- Users can switch between conversation modes such as general, interview, and passive.
- Typed quick-ask requests use the same LLM and HUD delivery pipeline as spoken questions.
- The assistant profile and quick-ask preset control response tone and format.

Primary files:

- `lib/main.dart`
- `lib/screens/home_screen.dart`
- `lib/services/conversation_engine.dart`
- `lib/services/conversation_listening_session.dart`

### Glasses Control And HUD Delivery

The Glasses tab is the operator console for Even Realities G1 connectivity and HUD workflows.

- BLE scan and pairing flows are managed through `BleManager`.
- The app can push text to the HUD, replay the latest handoff, and expose lower-level utility workflows.
- `DashboardService` listens for tilt-trigger signals and can overlay contextual HUD content when the device state allows it.
- HUD routing is coordinated through `HudController`, `TextService`, and glasses protocol helpers.

Primary files:

- `lib/screens/g1_test_screen.dart`
- `lib/ble_manager.dart`
- `lib/services/dashboard_service.dart`
- `lib/services/text_service.dart`

### History And Session Memory

Conversation history is persisted locally and surfaced as grouped sessions.

- Sessions are built from `ConversationTurn` records in the conversation engine.
- The history screen supports search, mode filters, favorites, action-item filtering, and fact-check flag filtering.
- Session metadata is derived from prior turns and assistant profiles so the user can quickly review important interactions.

Primary files:

- `lib/screens/conversation_history_screen.dart`
- `lib/models/assistant_session_meta.dart`

### Recording Tools

The Record tab is separate from live listening.

- It uses `AudioServiceImpl` for explicit recordings rather than the assistant’s speech-recognition path.
- Recordings expose duration and level feedback and are saved for later management.
- This flow intentionally avoids eager initialization to reduce conflicts with live transcription audio session ownership.

Primary files:

- `lib/screens/recording_screen.dart`
- `lib/services/audio_service.dart`

### Settings And Providers

Settings are the runtime control plane for the app.

- API keys are stored in secure storage.
- User defaults such as provider selection, active model, microphone source, language, conversation automation, and display preferences are persisted in `SettingsManager`.
- `LlmService` registers and switches between providers like OpenAI, Anthropic, DeepSeek, Qwen, and Zhipu.
- The settings screen can query available models and test provider configuration.

Primary files:

- `lib/screens/settings_screen.dart`
- `lib/services/settings_manager.dart`
- `lib/services/llm/llm_service.dart`

## Architecture Overview

At startup, the app initializes persisted settings, BLE listeners, provider configuration, and the glasses dashboard runtime before booting the Flutter UI.

```text
App startup
  -> SettingsManager.initialize()
  -> BleManager.startListening()
  -> LlmService.initializeDefaults()
  -> ConversationEngine wired to active LLM provider
  -> DashboardService.initialize()
  -> HelixApp / MainScreen
```

The most important runtime pipelines are:

### Live Conversation Pipeline

```text
Speech input
  -> ConversationListeningSession / EvenAI bridge
  -> ConversationEngine
  -> Question detection
  -> LlmService active provider
  -> phone UI stream + HUD delivery
```

### HUD Utility Pipeline

```text
User action or dashboard trigger
  -> TextService / DashboardService
  -> HudController
  -> glasses protocol serialization
  -> BLE transport
```

## Project Structure

```text
lib/
  app.dart                       App shell and tab navigation
  main.dart                      Startup wiring for settings, BLE, LLM, dashboard
  ble_manager.dart               BLE lifecycle and hardware connection state
  screens/                       User-facing screens
  services/                      Runtime orchestration, HUD, text, history, settings
  services/llm/                  Provider abstraction and model routing
  models/                        Conversation, BLE, dashboard, and assistant models
  theme/                         Shared visual system
  widgets/                       Reusable cards, buttons, and assistant UI

ios/Runner/
  AppDelegate.swift              Native iOS bridge registration
  SpeechStreamRecognizer.swift   Native speech bridge and streaming recognizer
  OpenAIRealtimeTranscriber.swift Native realtime OpenAI speech transport
  AudioResampler.swift           PCM resampling support for native speech flow
```

## Setup

### Prerequisites

- Flutter SDK compatible with this repository
- Xcode with iOS device support
- CocoaPods
- An Apple signing team for device deployment
- At least one LLM API key if you want live answers

### Install

```bash
flutter pub get
cd ios && pod install && cd ..
```

### Run

```bash
flutter devices
flutter run -d <device-id>
```

For physical iPhone deployment, keep the device unlocked during launch. The app can install successfully while launch still fails if SpringBoard denies opening a locked device.

## Recommended First Run

1. Open Settings and add an API key for the provider you plan to use.
2. Confirm the active provider and model.
3. Pair G1 glasses in the Glasses tab if hardware is available.
4. Return to Assistant and test typed quick ask first.
5. Then test live listening with the configured microphone source.

## Documentation

- `docs/ONBOARDING.md`
- `docs/ONBOARDING_DESIGN.md`
- `docs/Architecture.md`
- `docs/TechnicalSpecs.md`

## Current Notes

- The codebase still contains legacy paths from older experiments alongside the current assistant-plus-glasses flow. Before large refactors, trace the active codepaths from `main.dart`, `app.dart`, and the currently mounted screens.
- Native iOS deployment depends on the `Runner.xcodeproj` source list being in sync with files under `ios/Runner/`.
