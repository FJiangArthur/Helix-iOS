# Helix Quick Start Guide

## 🚀 Get Up and Running in 10 Minutes

### Prerequisites Checklist
- [ ] **Flutter SDK 3.24+** installed
- [ ] **VS Code** or **Android Studio** with Flutter extensions
- [ ] **Git** configured with your credentials
- [ ] **OpenAI API Key** (optional but recommended for full features)
- [ ] **Anthropic API Key** (optional)

### 1. Clone and Setup (2 minutes)

```bash
# Clone the repository
git clone https://github.com/FJiangArthur/Helix-iOS.git
cd Helix-iOS

# Install dependencies
flutter pub get

# Generate code (Freezed models, JSON serialization)
flutter packages pub run build_runner build --delete-conflicting-outputs
```

### 2. Configure API Keys (1 minute)

Create `settings.local.json` in the project root:

```json
{
  "openai_api_key": "sk-your-openai-key-here",
  "anthropic_api_key": "sk-ant-your-anthropic-key-here"
}
```

> **Note**: This file is git-ignored for security. You can run without API keys, but AI features will be limited.

### 3. Run the App (1 minute)

```bash
# Run on your preferred platform
flutter run

# Or specify platform
flutter run -d chrome      # Web
flutter run -d macos       # macOS
flutter run -d ios         # iOS (requires Xcode)
flutter run -d android     # Android (requires Android SDK)
```

### 4. Verify Installation (2 minutes)

1. **App Launches**: Helix app opens with 5 tabs
2. **Audio Permission**: Grant microphone access when prompted
3. **Recording Test**: Tap the mic button in Conversation tab
4. **AI Features**: If API keys are configured, try asking a question

### 5. Explore Key Features (4 minutes)

#### **Conversation Tab**
- Tap 🎤 to start recording
- Watch real-time transcription (if speech service is configured)
- See AI insights appear automatically

#### **Analysis Tab**
- View conversation summaries
- Check fact-verification results
- Review action items and sentiment

#### **Settings Tab**
- Configure AI providers
- Adjust confidence thresholds
- Enable/disable insight types

## 🔧 Development Setup

### IDE Configuration

#### **VS Code Extensions**
```bash
# Install recommended extensions
code --install-extension Dart-Code.dart-code
code --install-extension Dart-Code.flutter
code --install-extension Nash.awesome-flutter-snippets
code --install-extension RichardCoutts.moor-snippets
```

#### **VS Code Settings**
Add to `.vscode/settings.json`:
```json
{
  "dart.lineLength": 100,
  "editor.rulers": [80, 100],
  "dart.enableSdkFormatter": true,
  "dart.runPubGetOnPubspecChanges": true
}
```

### Code Generation Setup

```bash
# Watch for changes and auto-generate
flutter packages pub run build_runner watch --delete-conflicting-outputs
```

### Testing Setup

```bash
# Run all tests
flutter test

# Run with coverage
flutter test --coverage

# Run specific test
flutter test test/unit/services/llm_service_test.dart
```

## 📱 Platform-Specific Setup

### iOS Setup
1. **Xcode**: Install from App Store
2. **iOS Simulator**: Included with Xcode
3. **Pods**: Already configured in `ios/Podfile`

```bash
cd ios && pod install && cd ..
flutter run -d ios
```

### Android Setup
1. **Android Studio**: Download from Google
2. **Android SDK**: Install via Android Studio
3. **Emulator**: Create via AVD Manager

```bash
flutter run -d android
```

### macOS Setup
```bash
# Enable macOS support (if not already enabled)
flutter config --enable-macos-desktop
flutter create --platforms=macos .
flutter run -d macos
```

## 🧪 Testing Your Setup

### 1. Basic Functionality Test

```dart
// In a test file, verify services are working
void main() {
  test('Service locator setup', () async {
    await setupServiceLocator();
    
    final logger = ServiceLocator.instance.get<LoggingService>();
    expect(logger, isNotNull);
    
    final audioService = ServiceLocator.instance.get<AudioService>();
    expect(audioService, isNotNull);
  });
}
```

### 2. AI Services Test (with API keys)

```dart
void main() {
  test('LLM service initialization', () async {
    final llmService = ServiceLocator.instance.get<LLMService>();
    
    await llmService.initialize(
      openAIKey: 'your-test-key',
      preferredProvider: LLMProvider.openai,
    );
    
    expect(llmService.isInitialized, isTrue);
  });
}
```

### 3. End-to-End Test

```dart
testWidgets('Recording workflow', (tester) async {
  await tester.pumpWidget(MyApp());
  
  // Navigate to conversation tab
  await tester.tap(find.text('Conversation'));
  await tester.pumpAndSettle();
  
  // Start recording
  await tester.tap(find.byIcon(Icons.mic));
  await tester.pump();
  
  // Verify recording state
  expect(find.text('Recording...'), findsOneWidget);
});
```

## 📊 Project Structure Overview

```
helix/
├── 📁 lib/
│   ├── 🏗️ core/utils/          # Logging, constants, exceptions
│   ├── 📋 models/              # Data models (Freezed)
│   ├── ⚙️  services/           # Business logic
│   │   ├── ai_providers/       # OpenAI, Anthropic integrations
│   │   └── implementations/    # Service implementations
│   ├── 🎨 ui/                  # User interface
│   └── 📱 main.dart           # App entry point
├── 📁 test/
│   ├── unit/                   # Unit tests
│   ├── integration/            # Integration tests
│   └── widget_test.dart       # Widget tests
├── 📁 docs/                   # Documentation
│   ├── Architecture.md        # System architecture
│   ├── DEVELOPER_GUIDE.md     # Development guide
│   └── AI_SERVICES_API.md     # AI services API docs
└── 📁 assets/                 # App assets
```

## 🤝 Contributing Workflow

### 1. Create Feature Branch
```bash
git checkout -b feature/my-awesome-feature
```

### 2. Follow Code Standards
- Use `flutter analyze` to check code quality
- Add tests for new functionality
- Follow existing naming conventions
- Add ABOUTME comments to new files

### 3. Test Your Changes
```bash
flutter test                    # Run tests
flutter analyze                 # Check code quality
flutter build apk --debug       # Test builds
```

### 4. Submit PR
```bash
git add .
git commit -m "feat: add awesome new feature"
git push origin feature/my-awesome-feature
```

## 🆘 Common Issues & Solutions

### Issue: "No API key configured"
**Solution**: Create `settings.local.json` with your API keys

### Issue: "Build runner fails"
**Solution**: 
```bash
flutter clean
flutter pub get
flutter packages pub run build_runner build --delete-conflicting-outputs
```

### Issue: "iOS build fails"
**Solution**:
```bash
cd ios
pod deintegrate
pod install
cd ..
flutter clean
flutter run -d ios
```

### Issue: "Permission denied for microphone"
**Solution**: Check platform-specific permission settings
- **iOS**: Info.plist includes NSMicrophoneUsageDescription
- **Android**: AndroidManifest.xml includes RECORD_AUDIO permission

### Issue: "Flutter version mismatch"
**Solution**:
```bash
flutter --version                    # Check current version
flutter upgrade                      # Upgrade to latest
flutter doctor                       # Check setup
```

## 📚 Next Steps

1. **Read the Architecture**: [Architecture.md](./Architecture.md)
2. **Explore the API**: [AI_SERVICES_API.md](./AI_SERVICES_API.md)
3. **Development Guide**: [DEVELOPER_GUIDE.md](./DEVELOPER_GUIDE.md)
4. **Join Linear**: Get access to project management
5. **Review PRs**: Understand codebase through existing pull requests

## 🎯 Key Concepts to Understand

### **Service-Based Architecture**
- Services are registered in `service_locator.dart`
- Interfaces define contracts, implementations provide functionality
- Dependency injection via `get_it` package

### **AI Analysis Pipeline**
- Audio → Transcription → AI Analysis → Insights
- Multi-provider support with automatic failover
- Real-time processing with queue management

### **State Management**
- Riverpod for reactive state management
- Freezed for immutable data models
- Stream-based real-time updates

### **Testing Strategy**
- Unit tests for business logic
- Widget tests for UI components
- Integration tests for workflows
- Mock services for isolated testing

---

**Welcome to the Helix team! 🎉** 

If you run into any issues, check the [DEVELOPER_GUIDE.md](./DEVELOPER_GUIDE.md) or reach out to the team. Happy coding! 🚀