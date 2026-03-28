# Helix - AI Conversation Companion for Smart Glasses

Flutter companion app for [Even Realities G1](https://evenrealities.com) smart glasses. Real-time conversation intelligence with AI.

## Features

- **Real-time transcription** via Apple Speech or OpenAI
- **AI-powered answers** displayed on glasses HUD (OpenAI, Anthropic, DeepSeek, Qwen, Zhipu)
- **3 conversation modes**: General, Interview Coach, Passive Listener
- **Background fact-check** on every AI response
- **Touchpad page scrolling** for multi-page answers
- **Configurable response length** (1-10 sentences)
- **Bitmap HUD rendering** with customizable widget layouts

## Requirements

- Flutter 3.35+, Dart 3.9+
- Xcode 26.3+, iOS 15+
- CocoaPods

## Quick Start

```bash
git clone https://github.com/FJiangArthur/Helix-iOS.git
cd Helix-iOS
flutter pub get
cd ios && pod install && cd ..
flutter run -d <simulator-id>
```

Release builds (device only):
```bash
flutter build ios --release
```

## Project Structure

```
lib/
  main.dart                          App init
  app.dart                           Tab navigation (Home, Glasses, History, Settings)
  screens/                           UI screens
  services/
    conversation_engine.dart         Core pipeline: transcription -> AI -> HUD
    conversation_listening_session.dart  Platform channel bridge
    llm/                             LLM providers (OpenAI, Anthropic, DeepSeek, Qwen, Zhipu)
    settings_manager.dart            SharedPreferences + secure storage
    bitmap_hud/                      Bitmap HUD rendering
    database/                        Drift SQLite DAOs
  models/                            Data models (Freezed)

ios/Runner/
  AppDelegate.swift                  BLE setup, platform channels
  BluetoothManager.swift             BLE connection management
  SpeechStreamRecognizer.swift       4-backend speech recognition
```

## Validation

Before any commit:
```bash
bash scripts/run_gate.sh
```

See [VALIDATION.md](VALIDATION.md) for details.

## License

MIT
