# Helix iOS Testing Guide

Comprehensive guide to testing in the Helix iOS application.

## Table of Contents

1. [Overview](#overview)
2. [Test Types](#test-types)
3. [Getting Started](#getting-started)
4. [Running Tests](#running-tests)
5. [Writing Tests](#writing-tests)
6. [Test Coverage](#test-coverage)
7. [Best Practices](#best-practices)
8. [CI/CD Integration](#cicd-integration)

## Overview

The Helix iOS app uses a comprehensive testing strategy that includes:
- **Unit Tests**: Test individual components in isolation
- **Integration Tests**: Test component interactions
- **E2E Tests**: Test complete user workflows
- **Widget Tests**: Test Flutter UI components

### Test Infrastructure

```
test/
├── helpers/              # Test utilities and helpers
├── fixtures/             # Test data factories
├── mocks/                # Mock builders
├── models/               # Model tests
├── services/             # Service tests
└── test_data/           # Test data files

integration_test/
├── e2e/                 # End-to-end tests
└── *.dart               # Integration tests

test_driver/
├── integration_test.dart # Integration test driver
└── e2e_test.dart        # E2E test driver
```

## Test Types

### Unit Tests

Test individual classes, methods, and functions in isolation.

**Location**: `test/`

**Example**:
```dart
test('AudioChunk calculates duration correctly', () {
  final chunk = AudioChunk.fromBytes([...]);
  expect(chunk.durationMs, equals(1000));
});
```

### Integration Tests

Test interactions between multiple components.

**Location**: `integration_test/`

**Example**:
```dart
test('Transcription service integrates with audio service', () async {
  // Test multiple services working together
});
```

### E2E Tests

Test complete user workflows from start to finish.

**Location**: `integration_test/e2e/`

**Example**:
```dart
testWidgets('User can record and view transcription', (tester) async {
  // Test complete user journey
});
```

### Widget Tests

Test Flutter UI components.

**Example**:
```dart
testWidgets('Recording button displays correctly', (tester) async {
  await tester.pumpWidget(RecordingButton());
  expect(find.byIcon(Icons.mic), findsOneWidget);
});
```

## Getting Started

### Prerequisites

1. Flutter SDK installed
2. All dependencies installed:
   ```bash
   flutter pub get
   ```

3. iOS Simulator or device (for integration/E2E tests)

### Test Dependencies

The following testing packages are configured:

- `flutter_test`: Core testing framework
- `integration_test`: Integration and E2E tests
- `mockito`: Mocking framework
- `build_test`: Test code generation

## Running Tests

### Run All Unit Tests

```bash
flutter test
```

### Run Specific Test File

```bash
flutter test test/models/audio_chunk_test.dart
```

### Run Tests with Coverage

```bash
./scripts/run_tests_with_coverage.sh
```

### Run Integration Tests

```bash
flutter test integration_test
```

### Run E2E Tests

```bash
flutter drive \
  --driver=test_driver/e2e_test.dart \
  --target=integration_test/e2e/user_flow_test.dart
```

### Run Tests in Watch Mode

```bash
flutter test --watch
```

### Run with Specific Tags

```bash
flutter test --tags=unit
flutter test --exclude-tags=slow
```

## Writing Tests

### Unit Test Template

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_helix/path/to/class.dart';

void main() {
  group('ClassName', () {
    late ClassName instance;

    setUp(() {
      instance = ClassName();
    });

    tearDown(() {
      instance.dispose();
    });

    test('description of what is being tested', () {
      // Arrange
      final input = 'test input';

      // Act
      final result = instance.method(input);

      // Assert
      expect(result, equals('expected output'));
    });
  });
}
```

### Integration Test Template

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Feature Integration', () {
    test('components work together', () async {
      // Setup
      final service1 = Service1();
      final service2 = Service2();

      // Test integration
      await service1.initialize();
      await service2.initialize();

      // Verify interaction
      expect(service1.isReady, isTrue);
      expect(service2.isReady, isTrue);

      // Cleanup
      service1.dispose();
      service2.dispose();
    });
  });
}
```

### Widget Test Template

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../helpers/widget_test_helpers.dart';

void main() {
  testWidgets('Widget displays correctly', (tester) async {
    // Build widget
    await pumpWidgetWithProviders(
      tester,
      MyWidget(),
    );

    // Verify UI
    expect(find.text('Expected Text'), findsOneWidget);

    // Interact
    await tapAndSettle(tester, find.byType(ElevatedButton));

    // Verify result
    expect(find.text('Result'), findsOneWidget);
  });
}
```

## Test Coverage

### Coverage Requirements

- **Minimum Overall Coverage**: 80%
- **Critical Paths**: 95%
- **New Code**: 90%

### Generate Coverage Report

```bash
./scripts/generate_coverage_report.sh
```

This will:
1. Run all tests with coverage
2. Generate HTML report
3. Create summary statistics
4. Generate badge data

### View Coverage Report

```bash
open coverage/html/index.html
```

### Check Coverage Against Threshold

```bash
./scripts/check_coverage.sh
```

## Best Practices

### General Testing

1. **Follow AAA Pattern**: Arrange, Act, Assert
2. **One Assertion Per Test**: Keep tests focused
3. **Independent Tests**: Tests should not depend on each other
4. **Descriptive Names**: Test names should describe what they test
5. **Clean Up Resources**: Always dispose in tearDown()

### Test Data

1. **Use Fixtures**: Leverage test fixtures for consistent data
2. **Avoid Hardcoding**: Use factory methods for test data
3. **Edge Cases**: Test boundary conditions
4. **Realistic Data**: Use data that represents real scenarios

### Mocking

1. **Mock External Dependencies**: Mock APIs, databases, etc.
2. **Don't Over-Mock**: Only mock what's necessary
3. **Use Test Doubles**: Prefer fakes for complex dependencies
4. **Verify Interactions**: Use mockito to verify calls

### Performance

1. **Fast Tests**: Unit tests should run in milliseconds
2. **Parallel Execution**: Tests should be parallelizable
3. **Avoid Sleeps**: Use proper waiting mechanisms
4. **Resource Management**: Clean up to prevent memory leaks

### Code Organization

1. **Mirror Source Structure**: Test files match source structure
2. **Group Related Tests**: Use `group()` to organize
3. **Shared Setup**: Use `setUp()` and `tearDown()`
4. **Helper Functions**: Extract common test code

## CI/CD Integration

### GitHub Actions

Tests run automatically on:
- Pull requests
- Merges to main
- Scheduled runs

### Pre-commit Hooks

Local tests run before commits:
```bash
git commit
# Tests run automatically
```

### Coverage Reports

Coverage reports are:
- Generated on every PR
- Published to coverage service
- Tracked over time
- Enforced with minimum thresholds

## Troubleshooting

### Tests Fail Locally But Pass in CI

- Check Flutter version
- Verify all dependencies are installed
- Clear build cache: `flutter clean`
- Check for environment-specific code

### Tests Are Flaky

- Add explicit waits
- Check for race conditions
- Ensure proper cleanup
- Use `pumpAndSettle()` for animations

### Coverage Not Generated

- Verify lcov is installed
- Check file permissions
- Ensure tests run successfully
- Review `.lcovrc` configuration

### Tests Timeout

- Increase timeout values
- Check for infinite loops
- Verify async operations complete
- Add debug logging

## Additional Resources

- [Flutter Testing Documentation](https://docs.flutter.dev/testing)
- [Mockito Documentation](https://pub.dev/packages/mockito)
- [Integration Testing Guide](./INTEGRATION_TESTING.md)
- [E2E Testing Guide](../integration_test/e2e/README.md)
- [Unit Testing Best Practices](./UNIT_TESTING.md)

## Support

For testing questions or issues:
1. Check existing tests for examples
2. Review this documentation
3. Ask in team chat
4. Create a GitHub issue
