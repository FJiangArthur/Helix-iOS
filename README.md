# Helix - Native AI Companion for Smart Glasses

Native Swift companion app for [Even Realities G1](https://evenrealities.com) smart glasses. Real-time conversation intelligence with AI.

## Features

- **Real-time transcription** via Apple Speech or OpenAI
- **AI-powered answers** displayed on glasses HUD (OpenAI, Anthropic, DeepSeek, Qwen, Zhipu)
- **3 conversation modes**: General, Interview Coach, Passive Listener
- **Background fact-check** on every AI response
- **Touchpad page scrolling** for multi-page answers
- **Configurable response length** (1-10 sentences)
- **Bitmap HUD rendering** with customizable widget layouts

## Requirements

- Xcode 27.0+, iOS 17+
- Swift Package Manager
- iOS 27 simulator runtime for current validation

## Quick Start

```bash
git clone https://github.com/FJiangArthur/Helix-iOS.git
cd Helix-iOS
bash scripts/run_gate.sh
xcodebuild -workspace "ios/Even Companion.xcworkspace" -scheme Runner \
  -configuration Debug -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO build
```

Release archive:
```bash
cd ios
bundle exec fastlane ios ship
```

## Project Structure

```
NativeHelix/
  Package.swift                      Headless native package graph
  Sources/HelixRuntime               Dependency container and runtime state
  Sources/HelixConversation          Conversation pipeline and eval runner
  Sources/HelixAI                    Provider protocols and OpenAI adapters
  Sources/HelixSpeech                Transcription and question detection
  Sources/HelixG1                    BLE protocol, HUD pagination, touchpad routing
  Sources/HelixPersistence           Native stores and SwiftData schema

ios/Runner/
  AppDelegate.swift                  Native app bootstrap
  NativeHelixAppView.swift           SwiftUI app shell
  NativeHelixAssistantView.swift     Assistant workspace
  NativeHelixSecondaryViews.swift    Device, sessions, knowledge, settings
  BluetoothManager.swift             BLE connection management
  SpeechStreamRecognizer.swift       Speech recognition and realtime routing
```

## Validation

Before any commit:
```bash
bash scripts/run_gate.sh
```

See [VALIDATION.md](VALIDATION.md) for details.

## License

MIT
