# Helix - AI-Powered Conversation Intelligence for Smart Glasses

[![Flutter](https://img.shields.io/badge/Flutter-3.24+-blue?logo=flutter)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.5+-blue?logo=dart)](https://dart.dev)
[![AI](https://img.shields.io/badge/AI-OpenAI%20%7C%20Anthropic-green)](https://platform.openai.com)
[![License](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

Helix is a Flutter-based companion app for Even Realities smart glasses that provides **real-time conversation analysis** and **AI-powered insights** displayed directly on the glasses HUD. The app processes live audio, performs speech-to-text conversion, and leverages advanced LLM APIs for fact-checking, summarization, and contextual assistance.

## ✨ Key Features

### 🎤 **Real-Time Audio Processing**
- High-quality audio capture (16kHz, mono)
- Voice activity detection and noise reduction
- Real-time waveform visualization
- Cross-platform audio support

### 🧠 **AI-Powered Analysis Engine** ✅ **COMPLETE (Epic 2.2)**
- **Multi-Provider LLM Support**: OpenAI GPT-4 + Anthropic integration
- **Real-Time Fact Checking**: AI-powered claim detection and verification
- **Conversation Intelligence**: Action items, sentiment analysis, topic extraction
- **Smart Insights**: Contextual suggestions and recommendations
- **Automatic Failover**: Health monitoring with intelligent provider switching

### 📱 **Smart Glasses Integration**
- Bluetooth connectivity to Even Realities glasses
- Real-time HUD content rendering
- Battery monitoring and display control
- Gesture-based interaction support

### 🔒 **Privacy & Security**
- Local-first processing when possible
- Encrypted API communications
- Configurable data retention policies
- No persistent storage without explicit consent

## 🚀 Quick Start

### **Prerequisites**
- **Flutter SDK**: 3.24+ (with Dart 3.5+)
- **Development IDE**: VS Code with Flutter extension OR Android Studio
- **Platform Tools**: 
  - **iOS**: Xcode 15+ (for iOS development)
  - **Android**: Android SDK 34+ (for Android development)
  - **macOS**: macOS 12+ (for macOS development)
- **API Keys**: OpenAI and/or Anthropic (optional but recommended)

### **Setup Instructions**

#### 1. **Install Flutter SDK**
```bash
# macOS (using Homebrew)
brew install flutter

# Or download from https://docs.flutter.dev/get-started/install
```

#### 2. **Verify Flutter Installation**
```bash
flutter doctor
# Ensure all checkmarks are green, especially for your target platform
```

#### 3. **Clone and Setup Project**
```bash
# Clone the repository
git clone https://github.com/FJiangArthur/Helix-iOS.git
cd Helix-iOS

# Install dependencies
flutter pub get

# Generate code (Freezed models, JSON serialization)
flutter packages pub run build_runner build --delete-conflicting-outputs
```

#### 4. **Configure API Keys** (Optional)
Create `settings.local.json` in the project root:
```json
{
  "openai_api_key": "sk-your-openai-key-here",
  "anthropic_api_key": "sk-ant-your-anthropic-key-here"
}
```

#### 5. **Platform-Specific Setup**

##### **iOS Development**
```bash
# Install CocoaPods
sudo gem install cocoapods

# Install iOS dependencies
cd ios && pod install && cd ..

# Open iOS simulator or connect device
open -a Simulator

# Run on iOS
flutter run -d ios
```

##### **Android Development**
```bash
# Start Android emulator or connect device
flutter emulators --launch <emulator_id>

# Run on Android
flutter run -d android
```

##### **macOS Development**
```bash
# Enable macOS support
flutter config --enable-macos-desktop

# Run on macOS
flutter run -d macos
```

### **Building the App**

#### **Development Build**
```bash
# Run with hot reload
flutter run

# Run on specific device
flutter devices                    # List available devices
flutter run -d <device-id>         # Run on specific device
```

#### **Release Builds**

##### **iOS Release (requires Xcode)**
```bash
# Build iOS release
flutter build ios --release

# Build and archive for App Store (in Xcode)
# 1. Open ios/Runner.xcworkspace in Xcode
# 2. Select "Any iOS Device" as target
# 3. Product → Archive
# 4. Upload to App Store Connect
```

##### **Android Release**
```bash
# Build Android APK
flutter build apk --release

# Build Android App Bundle (for Play Store)
flutter build appbundle --release
```

##### **macOS Release**
```bash
# Build macOS app
flutter build macos --release
```

## 🧪 Testing

### **Run Tests**
```bash
# Run all tests
flutter test

# Run tests with coverage
flutter test --coverage

# Run specific test file
flutter test test/unit/services/llm_service_test.dart

# Run integration tests
flutter test integration_test/
```

### **Code Quality**
```bash
# Static analysis
flutter analyze

# Format code
dart format .

# Generate code (after model changes)
flutter packages pub run build_runner build --delete-conflicting-outputs
```

## 📁 Project Structure

```
lib/
├── core/utils/                 # Constants, logging, exceptions
├── models/                     # Freezed data models
├── services/                   # Business logic services
│   ├── ai_providers/          # OpenAI, Anthropic integrations
│   ├── implementations/       # Service implementations
│   ├── fact_checking_service.dart  # Real-time fact verification
│   ├── ai_insights_service.dart    # Conversation intelligence
│   └── llm_service.dart       # Multi-provider LLM interface
├── ui/                        # Flutter UI components
└── main.dart                  # App entry point

test/
├── unit/                      # Unit tests
├── integration/               # Integration tests  
└── widget_test.dart          # Widget tests
```

## 📚 Documentation

| Document | Description |
|----------|-------------|
| **[📖 Architecture](docs/Architecture.md)** | Complete system architecture and design patterns |
| **[🚀 Quick Start](docs/QUICK_START.md)** | Get up and running in 10 minutes |
| **[👩‍💻 Developer Guide](docs/DEVELOPER_GUIDE.md)** | Comprehensive development workflows and patterns |
| **[🔌 AI Services API](docs/AI_SERVICES_API.md)** | Complete API reference for AI services |

## 🛠️ Development Workflow

### **IDE Setup**

#### **VS Code (Recommended)**
```bash
# Install Flutter extension
code --install-extension Dart-Code.flutter

# Recommended settings in .vscode/settings.json
{
  "dart.lineLength": 100,
  "editor.rulers": [80, 100],
  "dart.enableSdkFormatter": true
}
```

#### **Android Studio**
1. Install Flutter and Dart plugins
2. Configure Flutter SDK path
3. Enable hot reload on save

### **Common Commands**
```bash
# Development
flutter run --debug                    # Run in debug mode
flutter hot-reload                     # Hot reload changes
flutter hot-restart                    # Full restart

# Code Generation (after model changes)
flutter packages pub run build_runner watch --delete-conflicting-outputs

# Testing
flutter test                          # Run all tests
flutter test --coverage             # Generate coverage report
flutter test test/unit/              # Run unit tests only

# Analysis
flutter analyze                      # Static code analysis
dart format .                       # Format code
flutter doctor                      # Check Flutter setup
```

### **Troubleshooting**

#### **Common Issues**

**"No API key configured"**
```bash
# Create settings.local.json with your API keys
cp settings.local.json.example settings.local.json
```

**"Build runner fails"**
```bash
flutter clean
flutter pub get
flutter packages pub run build_runner build --delete-conflicting-outputs
```

**"iOS build fails"**
```bash
cd ios && pod deintegrate && pod install && cd ..
flutter clean && flutter run -d ios
```

**"Permission denied for microphone"**
- **iOS**: Check Info.plist includes NSMicrophoneUsageDescription
- **Android**: Check AndroidManifest.xml includes RECORD_AUDIO permission

## 🎯 Current Status

### **✅ Completed (Epic 2.2)**
- Multi-Provider LLM Service (OpenAI + Anthropic)
- Real-Time Fact Checking pipeline
- AI Insights generation
- Automatic provider failover
- Comprehensive documentation

### **🚀 Next Milestones**
- **Epic 2.3**: Smart Glasses UI Integration
- **Epic 2.4**: Real-Time Transcription Pipeline
- **Epic 3.0**: Production Polish & Optimization

## 🤝 Contributing

### **Development Standards**
- Follow [Effective Dart](https://dart.dev/guides/language/effective-dart) guidelines
- Use Riverpod for state management with Freezed data models
- Write comprehensive unit tests (>= 90% coverage)
- Add ABOUTME comments to new files
- Follow existing architecture patterns

### **Pull Request Requirements**
- [ ] Tests pass (`flutter test`)
- [ ] Code analysis clean (`flutter analyze`)
- [ ] Documentation updated
- [ ] Breaking changes documented

### **Development Workflow**
1. **Fork & Clone**: `git clone your-fork-url`
2. **Create Branch**: `git checkout -b feature/amazing-feature`
3. **Develop**: Follow patterns in [Developer Guide](docs/DEVELOPER_GUIDE.md)
4. **Test**: `flutter test` + `flutter analyze`
5. **Submit PR**: Include tests and documentation

## 🔗 Useful Links

- **[Linear Project](https://linear.app/art-jiang/project/helix-real-time-transcription-and-fact-checking-4ac9c858372e)** - Issue tracking and roadmap
- **[GitHub Repository](https://github.com/FJiangArthur/Helix-iOS)** - Source code and releases
- **[Flutter Documentation](https://docs.flutter.dev)** - Flutter framework docs
- **[Riverpod Guide](https://riverpod.dev)** - State management documentation

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

**Built with ❤️ by the Helix Team**

*For questions, issues, or contributions, please reach out through GitHub Issues or our Linear project board.*
