# Helix Project - Quick Reference Guide

## Project at a Glance

**What**: Flutter cross-platform app for Even Realities smart glasses
**Status**: Production-ready (Audio + AI core complete, Glasses integration in progress)
**Team**: Single developer with comprehensive documentation

## Technology Stack Matrix

| Category | Technology | Version | Status |
|----------|-----------|---------|--------|
| **Language** | Dart | 3.5+ | ✅ |
| **Framework** | Flutter | 3.24+ | ✅ |
| **iOS** | Native/Xcode | 15.0+ | ✅ |
| **Android** | Native/Gradle | 34+ | ✅ |
| **Audio** | flutter_sound | 9.2.13 | ✅ |
| **AI/LLM** | OpenAI (GPT-4) | Latest | ✅ |
| **AI/LLM** | Anthropic (Claude) | Latest | ✅ Failover |
| **Transcription** | Whisper API | Latest | ✅ |
| **BLE** | Native + Custom | Custom | 🚀 In Progress |
| **State Management** | GetX | 4.6.6 | ✅ |
| **Data Models** | Freezed | 2.4.7 | ✅ |

## Core Services Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                   UI Layer (Screens)                         │
│  Recording | G1Test | AIAssistant | Features | Settings    │
└────────────────────────┬────────────────────────────────────┘
                         │ consumes streams
                         ▼
┌─────────────────────────────────────────────────────────────┐
│                   Business Logic (Services)                  │
├─────────────────────────────────────────────────────────────┤
│ Audio Service      │ Transcription Service  │ AI Coordinator │
│ ├─ Recording       │ ├─ Native (iOS/Android)│ ├─ OpenAI      │
│ ├─ Permissions     │ ├─ Whisper API        │ ├─ Anthropic   │
│ ├─ Audio Levels    │ └─ Coordinator        │ ├─ Fact Check  │
│ └─ File Mgmt      │                        │ └─ Insights    │
│                    │                        │                │
│ BLE Manager        │ HUD Controller         │ Conv. Insights │
│ ├─ Connection      │ ├─ Display Content     │ ├─ Extraction  │
│ ├─ Health Track    │ ├─ Battery Monitor     │ ├─ Sentiment   │
│ └─ Transactions    │ └─ Gesture Control     │ └─ Topics      │
└─────────────────────────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│              External Services & Platforms                   │
│  Audio APIs | Network | Bluetooth | Cloud APIs | Storage   │
└─────────────────────────────────────────────────────────────┘
```

## File Organization

### Service Files (lib/services/)
- **ai_coordinator.dart** - Multi-provider LLM orchestration (420 lines)
- **audio_service.dart** - Audio capture interface (87 lines)
- **ble_manager.dart** - Bluetooth LE communication (380 lines)
- **conversation_insights.dart** - Insight extraction logic
- **hud_controller.dart** - Glass display management
- **transcription_coordinator.dart** - Speech-to-text orchestration

### Screen Files (lib/screens/)
- **recording_screen.dart** - Main audio recording UI
- **ai_assistant_screen.dart** - Chat/analysis interface
- **g1_test_screen.dart** - Glass connection testing
- **settings_screen.dart** - Configuration UI
- **file_management_screen.dart** - Recording library

### Model Files (lib/models/)
- Freezed: AudioChunk, AudioConfiguration, BleHealthMetrics, BleTransaction
- EventAI-specific models for smart glasses

## Key Entry Points

### For Audio Recording
```dart
// File: lib/screens/recording_screen.dart
// Consumes: AudioService streams
// Provides: Real-time recording UI with waveform visualization
```

### For AI Analysis
```dart
// File: lib/screens/ai_assistant_screen.dart
// Consumes: AICoordinator results
// Provides: Fact-checking, sentiment analysis, insights
```

### For Glasses Connection
```dart
// File: lib/screens/g1_test_screen.dart
// Consumes: BleManager connection state
// Provides: Connection status and control
```

## Build Commands

```bash
# Setup
flutter pub get
flutter packages pub run build_runner build --delete-conflicting-outputs

# Development
flutter run -d ios                          # iOS
flutter run -d android                      # Android
flutter run -d macos                        # macOS
flutter run -d chrome                       # Web

# Testing
flutter test                                # All tests
flutter test test/services/                # Service tests only
flutter test --coverage                     # With coverage

# Analysis
flutter analyze                             # Lint
dart format .                              # Format

# Release
flutter build ios --release                 # iOS
flutter build apk --release                 # Android APK
flutter build appbundle --release          # Android App Bundle
```

## Configuration Files

| File | Purpose | Example |
|------|---------|---------|
| `pubspec.yaml` | Dependencies | Versions, assets, fonts |
| `analysis_options.yaml` | Linting rules | Flutter best practices |
| `settings.local.json` | API Keys | `{openai_api_key: "..."}` |
| `ios/Podfile` | iOS dependencies | CocoaPods, minimum iOS |
| `android/app/build.gradle.kts` | Android config | SDK levels, namespace |
| `.github/workflows/*.yml` | CI/CD | Build triggers, steps |

## Platform-Specific Setup

### iOS
```bash
cd ios
pod install
cd ..
open -a Simulator
flutter run -d ios
```

### Android
```bash
flutter emulators --launch Pixel_5
flutter run -d android
```

### macOS
```bash
flutter config --enable-macos-desktop
flutter run -d macos
```

## Key Features Status

| Feature | Status | Lines | Epic |
|---------|--------|-------|------|
| Audio Recording | ✅ Complete | 1,200+ | 1.1 |
| Audio Visualization | ✅ Complete | 400+ | 1.2 |
| Transcription (Native) | ✅ Complete | 800+ | 2.1 |
| Transcription (Whisper) | ✅ Complete | 500+ | 2.1 |
| AI Analysis (OpenAI) | ✅ Complete | 600+ | 2.2 |
| AI Analysis (Anthropic) | ✅ Complete | 200+ | 2.2 |
| Fact Checking | ✅ Complete | 400+ | 2.2 |
| Glasses Connection (BLE) | 🚀 In Progress | 800+ | 2.3 |
| HUD Display | 🚀 In Progress | 300+ | 2.3 |
| Gesture Recognition | 📋 Planned | - | 2.3 |

## Testing Coverage

```
test/
├── models/
│   ├── audio_chunk_test.dart
│   └── ble_transaction_test.dart
├── services/
│   ├── ai_coordinator_test.dart
│   ├── audio_buffer_manager_test.dart
│   ├── conversation_insights_test.dart
│   ├── text_paginator_test.dart
│   └── transcription/
│       ├── native_transcription_service_test.dart
│       └── transcription_models_test.dart
└── [Integration tests - to be added]
```

## Performance Baselines

### Audio
- **Capture**: 16kHz, mono, 16-bit PCM
- **Buffer**: Managed by flutter_sound
- **Latency**: <50ms

### AI/LLM
- **Rate Limit**: 20 req/min (configurable)
- **Cache**: 100 items max
- **Provider Failover**: Automatic if primary fails

### Transcription
- **Native**: Real-time (iOS 14.5+, Android 5.0+)
- **Whisper API**: 2-5 seconds latency
- **Auto-switch**: Based on network connectivity

## Debugging Tools

```bash
# Enable logging
flutter run -v                              # Verbose logging

# DevTools
flutter pub global activate devtools
devtools

# Static analysis
flutter analyze --fatal-infos

# Code generation watch mode
flutter packages pub run build_runner watch
```

## Common Issues & Solutions

| Issue | Cause | Solution |
|-------|-------|----------|
| "No API key" | Missing settings.local.json | Create file with API keys |
| Build fails | Missing code generation | Run build_runner |
| iOS build fails | Pod issues | `cd ios && pod deintegrate && pod install` |
| Permission denied | Missing Info.plist | Check iOS platform configuration |
| Audio not recording | Permission not granted | Request microphone permission |

## Important Constants

```dart
// AI Coordinator defaults
_maxRequestsPerMinute = 20
_maxCacheSize = 100
_claimConfidenceThreshold = 0.6  // 60%

// Audio Configuration defaults
sampleRate = 16000  // Hz
bitDepth = 16       // bits
channels = 1        // mono

// Transcription timeouts
nativeTranscriptionTimeout = 10s
whisperAPITimeout = 30s
```

## Dependencies by Category

```
# Audio & Media (1)
- flutter_sound: ^9.2.13

# AI/LLM (1 - custom implementations)
- http: ^1.2.0

# State Management (1)
- get: ^4.6.6

# Data Models (2)
- freezed_annotation: ^2.4.1
- json_annotation: ^4.8.1

# Permissions (1)
- permission_handler: ^10.2.0

# Connectivity (1)
- connectivity_plus: ^6.0.1

# UI (1)
- cupertino_icons: ^1.0.8

# Utilities (2)
- fluttertoast: ^8.2.8
- crclib: ^3.0.0

# Code Generation (Dev only)
- build_runner: ^2.4.7
- freezed: ^2.4.7
- json_serializable: ^6.7.1

# Testing (Dev only)
- mockito: ^5.4.4
- build_test: ^2.2.2

# Linting (Dev only)
- flutter_lints: ^5.0.0
```

## Project Statistics

- **Total Dart Files**: 48+ (excluding generated)
- **Total Lines of Code**: 10,000+ (core logic)
- **Test Files**: 8 (models + services)
- **Documentation Files**: 8 (comprehensive)
- **Platform Targets**: 6 (iOS, Android, macOS, Windows, Linux, Web)
- **Supported Platforms**: 4 (iOS 15.0+, Android 5.0+, macOS, Windows, Linux)

## Next Steps for Development

### Immediate (Epic 2.3)
1. Complete smart glasses HUD integration
2. Test BLE communication thoroughly
3. Add gesture recognition support
4. Comprehensive integration tests

### Short-term (Post Epic 2.3)
1. Cross-platform testing
2. Performance optimization
3. Security audit
4. Release build configuration

### Medium-term (Epic 3.0)
1. Production deployment
2. User documentation
3. Community support setup
4. Version 1.0 release

## Key Team Skills Needed

- **Flutter/Dart**: Core framework expertise
- **iOS/Native**: CoreBluetooth, Audio frameworks
- **Android/Native**: BluetoothAdapter, MediaRecorder
- **AI/LLM**: API integration, prompt engineering
- **Audio**: DSP, waveform processing
- **BLE**: Protocol design, hardware communication

## Resources

- **Source Code**: `/home/user/Helix-iOS/`
- **Git Remote**: http://local_proxy@127.0.0.1:64289/git/FJiangArthur/Helix-iOS
- **Current Branch**: claude/cross-platform-app-setup-011CUukDq7wg5tVcQ34nGdiZ
- **Documentation**: `/home/user/Helix-iOS/docs/`
- **Test Suite**: `/home/user/Helix-iOS/test/`

