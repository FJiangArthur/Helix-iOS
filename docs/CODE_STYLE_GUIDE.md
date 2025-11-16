# Code Style Guide

This document outlines the coding standards and best practices for the Helix Flutter application.

## Table of Contents

1. [Overview](#overview)
2. [Dart & Flutter Standards](#dart--flutter-standards)
3. [Type Safety](#type-safety)
4. [Naming Conventions](#naming-conventions)
5. [Code Organization](#code-organization)
6. [Error Handling](#error-handling)
7. [Asynchronous Code](#asynchronous-code)
8. [Widget Development](#widget-development)
9. [State Management](#state-management)
10. [Testing](#testing)
11. [Documentation](#documentation)
12. [Tools & Scripts](#tools--scripts)

## Overview

This project enforces strict code quality standards to ensure maintainability, readability, and robustness. All code must pass automated linting, formatting, and testing before being merged.

### Key Principles

- **Type Safety First**: Always specify types explicitly
- **Immutability**: Prefer `final` and `const` wherever possible
- **Null Safety**: Leverage Dart's sound null safety
- **Readability**: Clear, self-documenting code over clever solutions
- **Testability**: Write code that's easy to test

## Dart & Flutter Standards

### Formatting

All Dart code must be formatted using `dart format` with a line length of 120 characters.

```bash
# Format all code
./scripts/format.sh

# Check formatting without modifying files
./scripts/format.sh --check
```

### Linting

The project uses comprehensive linting rules defined in `analysis_options.yaml`. Run the analyzer before committing:

```bash
# Run analyzer
./scripts/lint.sh

# Run in strict mode (CI)
./scripts/lint.sh --strict
```

### Auto-fixing

Many formatting and linting issues can be fixed automatically:

```bash
# Auto-fix formatting and apply automated fixes
./scripts/fix.sh
```

## Type Safety

### Always Declare Types

**Good:**
```dart
final String userName = 'John Doe';
final int age = 30;
final List<String> tags = ['flutter', 'dart'];

String getUserName() {
  return userName;
}
```

**Bad:**
```dart
final userName = 'John Doe';  // ✗ Type not specified
var age = 30;                  // ✗ Use final, not var
final tags = ['flutter'];      // ✗ Generic type not specified

getUserName() {                // ✗ Return type not specified
  return userName;
}
```

### Avoid Dynamic

Avoid using `dynamic` unless absolutely necessary. Use generics or specific types instead.

**Good:**
```dart
List<T> filterItems<T>(List<T> items, bool Function(T) predicate) {
  return items.where(predicate).toList();
}
```

**Bad:**
```dart
List<dynamic> filterItems(List<dynamic> items, Function predicate) {
  return items.where((dynamic item) => predicate(item)).toList();
}
```

## Naming Conventions

### Classes and Types

Use `UpperCamelCase` for class names, enum types, typedefs, and type parameters.

```dart
class AudioRecorder {}
class UserProfile {}
enum ConnectionStatus { connected, disconnected, reconnecting }
typedef AudioCallback = void Function(Uint8List data);
```

### Variables, Methods, and Parameters

Use `lowerCamelCase` for variable names, method names, and parameters.

```dart
final String userName = 'John';
int calculateTotalScore() { }
void processAudioData(Uint8List audioBuffer) { }
```

### Constants

Use `lowerCamelCase` for constant names (not SCREAMING_CAPS).

```dart
const int maxRetryAttempts = 3;
const String apiEndpoint = 'https://api.example.com';
```

### Private Members

Prefix private members with an underscore.

```dart
class AudioProcessor {
  final int _bufferSize;
  String _lastError = '';

  void _processInternal() { }
}
```

### Boolean Variables

Use positive, descriptive names for boolean variables.

**Good:**
```dart
bool isConnected = true;
bool hasPermission = false;
bool canRecord = true;
```

**Bad:**
```dart
bool notConnected = false;  // ✗ Negative naming
bool permission = false;     // ✗ Not descriptive
```

## Code Organization

### Import Ordering

Organize imports in the following order:

1. Dart SDK imports
2. Flutter imports
3. Package imports
4. Relative imports

```dart
// Dart SDK
import 'dart:async';
import 'dart:typed_data';

// Flutter
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Packages
import 'package:get_it/get_it.dart';
import 'package:riverpod/riverpod.dart';

// Relative
import '../models/audio_data.dart';
import '../services/audio_service.dart';
```

Use `package:` imports instead of relative imports for files in `lib/`.

### File Organization

- Keep files focused on a single responsibility
- Limit file length to ~500 lines (split into multiple files if longer)
- Use feature-based folder structure

```
lib/
├── core/              # Core utilities, constants, themes
├── models/            # Data models
├── services/          # Business logic services
├── providers/         # State management providers
├── screens/           # UI screens
├── widgets/           # Reusable widgets
└── utils/             # Utility functions
```

### Class Organization

Organize class members in this order:

1. Static constants
2. Static variables
3. Instance fields
4. Constructors
5. Named constructors
6. Static methods
7. Getters and setters
8. Instance methods
9. Private methods

```dart
class AudioRecorder {
  // 1. Static constants
  static const int defaultSampleRate = 16000;

  // 2. Instance fields
  final AudioService _audioService;
  final StreamController<Uint8List> _dataController;

  // 3. Constructor
  AudioRecorder(this._audioService)
      : _dataController = StreamController<Uint8List>.broadcast();

  // 4. Named constructors
  AudioRecorder.withConfig(AudioConfig config) : this(AudioService(config));

  // 5. Getters
  Stream<Uint8List> get dataStream => _dataController.stream;

  // 6. Public methods
  Future<void> startRecording() async {
    await _initializeRecorder();
    await _audioService.start();
  }

  // 7. Private methods
  Future<void> _initializeRecorder() async {
    // Implementation
  }
}
```

## Error Handling

### Use Specific Exception Types

**Good:**
```dart
try {
  await audioService.startRecording();
} on PermissionDeniedException catch (e) {
  logger.error('Microphone permission denied', error: e);
  showPermissionDialog();
} on AudioDeviceException catch (e) {
  logger.error('Audio device error', error: e);
  showErrorDialog(e.message);
} catch (e, stackTrace) {
  logger.error('Unexpected error', error: e, stackTrace: stackTrace);
  rethrow;
}
```

### Always Provide Context

Include meaningful error messages and context:

```dart
if (buffer.isEmpty) {
  throw ArgumentError.value(
    buffer,
    'buffer',
    'Audio buffer cannot be empty',
  );
}
```

### Clean Up Resources

Always clean up resources, especially in async code:

```dart
Future<void> processAudio(String filePath) async {
  final File file = File(filePath);
  final Stream<List<int>> stream = file.openRead();

  try {
    await for (final List<int> data in stream) {
      await processChunk(data);
    }
  } finally {
    await stream.drain();  // Always clean up
  }
}
```

## Asynchronous Code

### Use async/await

Prefer `async`/`await` over raw Futures for readability.

**Good:**
```dart
Future<String> fetchUserData() async {
  final String userId = await getCurrentUserId();
  final User user = await userRepository.getUser(userId);
  return user.name;
}
```

**Bad:**
```dart
Future<String> fetchUserData() {
  return getCurrentUserId().then((String userId) {
    return userRepository.getUser(userId).then((User user) {
      return user.name;
    });
  });
}
```

### Avoid Unawaited Futures

Always await async calls or explicitly mark them with `unawaited()`:

```dart
import 'package:flutter/foundation.dart';

Future<void> processData() async {
  // Good: awaited
  await saveToDatabase(data);

  // Good: explicitly unawaited with comment
  unawaited(
    analytics.logEvent('data_processed')  // Fire and forget
  );
}
```

### Handle Timeouts

Add timeouts to network calls and long-running operations:

```dart
Future<Response> fetchData() async {
  try {
    return await http.get(uri).timeout(
      const Duration(seconds: 30),
      onTimeout: () {
        throw TimeoutException('Request timed out after 30 seconds');
      },
    );
  } catch (e) {
    logger.error('Failed to fetch data', error: e);
    rethrow;
  }
}
```

## Widget Development

### Use const Constructors

Use `const` constructors wherever possible for better performance:

```dart
// Good
const SizedBox(height: 16)
const Padding(
  padding: EdgeInsets.all(8),
  child: Text('Hello'),
)

// Use const with widget fields
class MyWidget extends StatelessWidget {
  const MyWidget({super.key, required this.title});

  final String title;
}
```

### Keep build() Methods Pure

Widget `build()` methods should be pure functions without side effects:

**Good:**
```dart
@override
Widget build(BuildContext context) {
  return Text(title);
}
```

**Bad:**
```dart
@override
Widget build(BuildContext context) {
  analytics.logEvent('widget_built');  // ✗ Side effect in build
  return Text(title);
}
```

### Extract Complex Widgets

Break down complex widget trees into smaller, reusable widgets:

**Good:**
```dart
class UserProfile extends StatelessWidget {
  const UserProfile({super.key, required this.user});

  final User user;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        UserAvatar(user: user),
        UserInfo(user: user),
        UserActions(user: user),
      ],
    );
  }
}
```

### Use Keys Appropriately

Add keys to widgets that need to maintain state across rebuilds:

```dart
ListView.builder(
  itemCount: items.length,
  itemBuilder: (BuildContext context, int index) {
    return ListTile(
      key: ValueKey<String>(items[index].id),  // Use keys for list items
      title: Text(items[index].name),
    );
  },
)
```

## State Management

This project uses Riverpod for state management. Follow these patterns:

### Provider Definition

```dart
// Simple value provider
final audioServiceProvider = Provider<AudioService>((ProviderRef ref) {
  return AudioService();
});

// State notifier provider
final audioRecorderProvider = StateNotifierProvider<AudioRecorder, AudioState>(
  (StateNotifierProviderRef ref) {
    final AudioService service = ref.watch(audioServiceProvider);
    return AudioRecorder(service);
  },
);
```

### Widget Integration

```dart
class RecordingScreen extends ConsumerWidget {
  const RecordingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AudioState audioState = ref.watch(audioRecorderProvider);

    return Scaffold(
      body: audioState.when(
        idle: () => const IdleView(),
        recording: () => const RecordingView(),
        error: (String message) => ErrorView(message: message),
      ),
    );
  }
}
```

## Testing

### Test File Organization

Mirror the structure of your lib/ directory in test/:

```
lib/services/audio_service.dart
test/services/audio_service_test.dart
```

### Test Naming

Use descriptive test names that explain what is being tested:

```dart
void main() {
  group('AudioService', () {
    test('should start recording when microphone permission is granted', () {
      // Arrange
      final AudioService service = AudioService();

      // Act
      final Future<void> result = service.startRecording();

      // Assert
      expect(result, completes);
    });

    test('should throw PermissionDeniedException when permission is denied', () {
      // Test implementation
    });
  });
}
```

### Use Mocks Appropriately

```dart
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

@GenerateMocks([AudioService])
void main() {
  late MockAudioService mockService;

  setUp(() {
    mockService = MockAudioService();
  });

  test('should call service.start() when recording starts', () async {
    // Arrange
    when(mockService.start()).thenAnswer((_) async => true);

    // Act
    await mockService.start();

    // Assert
    verify(mockService.start()).called(1);
  });
}
```

## Documentation

### Public API Documentation

Document all public APIs with dartdoc comments:

```dart
/// Processes audio data and returns transcribed text.
///
/// The [audioData] parameter must not be null or empty.
/// The [language] parameter defaults to 'en-US' if not specified.
///
/// Returns the transcribed text or an empty string if transcription fails.
///
/// Throws [ArgumentError] if audioData is empty.
/// Throws [TranscriptionException] if the transcription service fails.
///
/// Example:
/// ```dart
/// final String text = await transcriber.transcribe(
///   audioData,
///   language: 'en-US',
/// );
/// ```
Future<String> transcribe(
  Uint8List audioData, {
  String language = 'en-US',
}) async {
  // Implementation
}
```

### Inline Comments

Use inline comments sparingly and only for complex logic:

```dart
// Calculate the optimal buffer size based on sample rate
// Formula: sampleRate * bytesPerSample * channelCount * durationInSeconds
final int bufferSize = sampleRate * 2 * 1 * 1;
```

## Tools & Scripts

### Available Scripts

```bash
# Format code
./scripts/format.sh              # Format all Dart files
./scripts/format.sh --check      # Check formatting without changes

# Lint code
./scripts/lint.sh                # Run analyzer
./scripts/lint.sh --strict       # Strict mode for CI

# Auto-fix issues
./scripts/fix.sh                 # Format, fix imports, and analyze

# Validation (CI)
./scripts/validate.sh            # Run all checks + tests
```

### Pre-commit Hooks

Pre-commit hooks are configured to run automatically. Install them with:

```bash
# Install pre-commit (if not already installed)
pip install pre-commit

# Install hooks
pre-commit install

# Run manually on all files
pre-commit run --all-files
```

### IDE Integration

#### VS Code

Add these settings to `.vscode/settings.json`:

```json
{
  "dart.lineLength": 120,
  "editor.formatOnSave": true,
  "editor.codeActionsOnSave": {
    "source.fixAll": true,
    "source.organizeImports": true
  },
  "dart.analysisExcludedFolders": [
    "build",
    ".dart_tool"
  ]
}
```

#### Android Studio / IntelliJ

1. Go to Settings → Editor → Code Style → Dart
2. Set "Right margin" to 120
3. Enable "Format code on save"
4. Enable "Organize imports on save"

## Enforcement

All code must pass the following checks before merging:

1. **Formatting**: `./scripts/format.sh --check` must pass
2. **Linting**: `./scripts/lint.sh --strict` must pass with no errors or warnings
3. **Tests**: `flutter test` must pass with all tests passing
4. **Pre-commit hooks**: All hooks must pass

These checks are enforced in CI/CD pipelines and will block merging if they fail.

## Questions?

If you have questions about these standards or need clarification, please:

1. Check the [Dart Style Guide](https://dart.dev/guides/language/effective-dart/style)
2. Check the [Flutter Style Guide](https://github.com/flutter/flutter/wiki/Style-guide-for-Flutter-repo)
3. Ask in the team's development channel

## Updates

This guide is a living document. Suggestions for improvements are welcome via pull requests.
