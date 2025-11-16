# Helix-iOS Build Instructions

Complete setup guide for building and running the Helix-iOS application.

## Table of Contents
1. [Prerequisites](#prerequisites)
2. [Initial Setup](#initial-setup)
3. [Configuration](#configuration)
4. [Building the App](#building-the-app)
5. [Running Tests](#running-tests)
6. [Troubleshooting](#troubleshooting)

---

## Prerequisites

### Required Software
- **Flutter SDK**: >= 3.35.0
- **Dart SDK**: >= 3.9.0 < 4.0.0
- **Xcode**: 14.0+ (for iOS development)
- **CocoaPods**: 1.16.2+
- **Git**: For version control

### Installation

#### 1. Install Flutter
```bash
# Download and install Flutter from https://flutter.dev/docs/get-started/install
# Or use homebrew on macOS:
brew install flutter

# Verify installation
flutter doctor
```

#### 2. Install CocoaPods
```bash
# macOS
sudo gem install cocoapods

# Verify installation
pod --version
```

---

## Initial Setup

### Step 1: Clone the Repository
```bash
git clone <repository-url>
cd Helix-iOS
```

### Step 2: Install Flutter Dependencies
```bash
flutter pub get
```

**Expected Result**: All Dart packages will be downloaded and the `Flutter/Generated.xcconfig` file will be created.

### Step 3: Install iOS Dependencies
```bash
cd ios
pod install
cd ..
```

**Expected Result**: All iOS CocoaPods will be installed, including:
- flutter_sound (9.28.0)
- permission_handler_apple (9.1.4)
- connectivity_plus
- fluttertoast
- path_provider_foundation

### Step 4: Install macOS Dependencies (Optional)
```bash
cd macos
pod install
cd ..
```

---

## Configuration

### Step 1: Create API Configuration File

Copy the template configuration file:
```bash
cp llm_config.local.json.template llm_config.local.json
```

### Step 2: Add Your API Keys

Edit `llm_config.local.json` and add your API keys:

```json
{
  "llmEndpoint": "https://llm.art-ai.me/v1/chat/completions",
  "llmApiKey": "YOUR-LLM-ART-AI-ME-API-KEY-HERE",
  "openAIApiKey": "sk-YOUR-OPENAI-API-KEY-HERE",
  "llmModel": "gpt-4.1-mini",
  "llmModels": {
    "fast": "gpt-4.1-mini",
    "balanced": "gpt-4.1",
    "advanced": "gpt-5",
    "reasoning": "o3"
  }
}
```

**Important Notes**:
- `llmApiKey`: Your API key for llm.art-ai.me backend (required for main LLM features)
- `openAIApiKey`: Direct OpenAI API key for Whisper transcription (optional, only for SimpleAITestScreen)
- This file is gitignored for security - never commit it!

### Step 3: Configure Code Signing (iOS Devices Only)

If deploying to a physical device:

1. Open `ios/Runner.xcworkspace` in Xcode
2. Select the "Runner" project
3. Go to "Signing & Capabilities"
4. Select your team
5. Configure bundle identifier if needed

**Note**: Simulator builds don't require code signing.

---

## Building the App

### Build for iOS Simulator
```bash
flutter build ios --simulator
```

### Build for iOS Device
```bash
flutter build ios --release
```

### Build for macOS
```bash
flutter build macos
```

### Run on Connected Device/Simulator
```bash
# List available devices
flutter devices

# Run on specific device
flutter run -d <device-id>

# Run in release mode
flutter run --release
```

---

## Running Tests

### Unit Tests
```bash
flutter test
```

### Integration Tests
```bash
flutter test integration_test/
```

### With Coverage Report
```bash
flutter test --coverage
```

---

## Troubleshooting

### Issue: "flutter: command not found"
**Solution**: Add Flutter to your PATH:
```bash
export PATH="$PATH:`pwd`/flutter/bin"
# Add to ~/.zshrc or ~/.bashrc for persistence
```

### Issue: "Pod install failed"
**Solution**: Update CocoaPods and repository:
```bash
pod repo update
cd ios && pod install
```

### Issue: "Generated.xcconfig not found"
**Solution**: Run Flutter pub get:
```bash
flutter pub get
```

### Issue: "API key not configured"
**Solution**:
1. Copy `llm_config.local.json.template` to `llm_config.local.json`
2. Add your API keys
3. Restart the app

### Issue: "Build fails with missing dependencies"
**Solution**: Clean and rebuild:
```bash
flutter clean
flutter pub get
cd ios && pod install && cd ..
flutter build ios --simulator
```

### Issue: "Microphone permission denied"
**Solution**:
1. Check Info.plist includes `NSMicrophoneUsageDescription`
2. Reset app permissions: Settings > Privacy > Microphone
3. Reinstall the app

---

## Project Structure Overview

```
Helix-iOS/
├── lib/
│   ├── core/              # Core configuration and utilities
│   │   ├── config/        # App configuration (AppConfig)
│   │   ├── errors/        # Error handling
│   │   └── observability/ # Monitoring and logging
│   ├── models/            # Data models
│   ├── screens/           # UI screens
│   ├── services/          # Business logic services
│   │   ├── ai_providers/  # OpenAI, Anthropic providers
│   │   ├── implementations/ # Service implementations
│   │   └── transcription/ # Speech-to-text services
│   └── utils/             # Utilities
├── ios/                   # iOS-specific code
├── macos/                 # macOS-specific code
├── test/                  # Unit tests
└── integration_test/      # Integration tests
```

---

## Key Services Overview

### 1. **LLM Service** (`llm_service_impl_v2.dart`)
- Multi-provider AI service (OpenAI, Anthropic, llm.art-ai.me)
- Automatic failover between providers
- Response caching
- Usage tracking

### 2. **Audio Service** (`audio_service_impl.dart`)
- Records audio at 16kHz, mono, 16-bit
- Real-time audio level monitoring
- Voice activity detection
- Configurable audio quality

### 3. **Transcription Service** (`transcription_coordinator.dart`)
- Dual-mode: Native iOS Speech + Cloud Whisper
- Automatic mode switching based on connectivity
- Real-time transcription streaming

### 4. **BLE Manager** (`ble_manager.dart`)
- Bluetooth LE communication with Even Realities G1 glasses
- Send text and images to HUD
- Health monitoring and reconnection

---

## Available Models (llm.art-ai.me)

| Model | Speed | Use Case | Rate Limit |
|-------|-------|----------|------------|
| gpt-4.1-mini | Fast | Quick responses | 150 req/min |
| gpt-4.1 | Balanced | General purpose | 150 req/min |
| gpt-5 | Advanced | Complex analysis | 2,500 req/min |
| o1 | Reasoning | Logical problems | 1,500 req/min |
| o3 | Complex | Advanced reasoning | 120 req/min |

---

## Next Steps

1. ✅ Complete initial setup
2. ✅ Configure API keys
3. ✅ Build for simulator
4. Test core features:
   - [ ] Audio recording (RecordingScreen)
   - [ ] AI integration (SimpleAITestScreen)
   - [ ] BLE connection (G1TestScreen)
   - [ ] Feature verification (FeatureVerificationScreen)
5. Deploy to device and test with Even Realities G1 glasses

---

## Support & Documentation

- **Main Documentation**: `/docs/`
- **API Integration**: See `lib/core/config/app_config.dart`
- **Security**: See `SECURITY.md`
- **Contributing**: See `CONTRIBUTING.md`

For issues or questions, consult the project documentation or contact the development team.
