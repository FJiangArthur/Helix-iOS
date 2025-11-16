# Testing Documentation

Welcome to the Helix iOS testing documentation.

## Quick Links

- **[Testing Guide](./TESTING_GUIDE.md)** - Comprehensive testing guide
- **[Unit Testing](./UNIT_TESTING.md)** - Unit testing guidelines
- **[Integration Testing](./INTEGRATION_TESTING.md)** - Integration testing guide
- **[Best Practices](./TEST_BEST_PRACTICES.md)** - Testing best practices
- **[E2E Testing](../../integration_test/e2e/README.md)** - End-to-end testing guide

## Getting Started

### Run All Tests

```bash
flutter test
```

### Run with Coverage

```bash
./scripts/run_tests_with_coverage.sh
```

### Run Integration Tests

```bash
flutter test integration_test
```

## Test Coverage Status

Current coverage targets:
- Overall: 80%+
- Critical business logic: 95%+
- Services: 90%+
- Models: 85%+

Check coverage:
```bash
./scripts/check_coverage.sh
```

## Test Structure

```
Helix-iOS/
├── test/                          # Unit tests
│   ├── helpers/                   # Test utilities
│   ├── fixtures/                  # Test data factories
│   ├── mocks/                     # Mock builders
│   ├── models/                    # Model tests
│   ├── services/                  # Service tests
│   └── test_data/                 # Test data files
├── integration_test/              # Integration tests
│   ├── e2e/                       # E2E tests
│   └── *_integration_test.dart    # Integration tests
└── test_driver/                   # Test drivers
    ├── integration_test.dart      # Integration driver
    └── e2e_test.dart             # E2E driver
```

## Available Test Utilities

### Test Helpers

```dart
import 'test/helpers/test_helpers.dart';

// Custom matchers
expect(dateTime, TestMatchers.isDateTimeCloseTo(expected));
expect(value, TestMatchers.isCloseToDouble(expected));

// Wait utilities
await waitForCondition(() => isReady);
await withTimeout(() => operation());
```

### Widget Test Helpers

```dart
import 'test/helpers/widget_test_helpers.dart';

// Widget testing utilities
await pumpWidgetWithProviders(tester, widget);
await tapAndSettle(tester, finder);
await waitForWidget(tester, finder);
```

### Test Fixtures

```dart
import 'test/fixtures/audio_fixtures.dart';
import 'test/fixtures/transcription_fixtures.dart';
import 'test/fixtures/ai_fixtures.dart';

// Create test data
final chunk = AudioChunkFactory.withDuration(durationMs: 1000);
final segment = TranscriptionSegmentFactory.createHighConfidence();
final analysis = AIAnalysisFactory.createSentimentResponse();
```

### Mock Builders

```dart
import 'test/mocks/mock_builders.dart';

// Build mocks with fluent API
final mockService = MockTranscriptionServiceBuilder()
  .withAvailability(true)
  .withMode(TranscriptionMode.native)
  .build();
```

## Testing Scripts

### Run Tests with Coverage

```bash
./scripts/run_tests_with_coverage.sh
```

Runs all tests and generates coverage reports.

### Check Coverage Threshold

```bash
./scripts/check_coverage.sh
```

Verifies coverage meets minimum threshold (80%).

### Generate Coverage Reports

```bash
./scripts/generate_coverage_report.sh
```

Generates detailed coverage reports in multiple formats.

## CI/CD Integration

Tests run automatically on:
- Every pull request
- Merges to main branch
- Before deployments
- Scheduled nightly runs

See `.github/workflows/` for CI configuration.

## Writing Your First Test

### 1. Create Test File

Create a file matching your source file:
```
lib/services/my_service.dart
test/services/my_service_test.dart
```

### 2. Write Test

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_helix/services/my_service.dart';

void main() {
  group('MyService', () {
    late MyService service;

    setUp(() {
      service = MyService();
    });

    tearDown(() {
      service.dispose();
    });

    test('does something correctly', () {
      // Arrange
      final input = 'test';

      // Act
      final result = service.doSomething(input);

      // Assert
      expect(result, equals('expected'));
    });
  });
}
```

### 3. Run Test

```bash
flutter test test/services/my_service_test.dart
```

## Best Practices Summary

1. **Write tests first** (TDD when possible)
2. **Keep tests simple** and focused
3. **Test behavior**, not implementation
4. **Use descriptive names** for tests
5. **One assertion per test** when possible
6. **Clean up resources** in tearDown()
7. **Mock external dependencies**
8. **Aim for high coverage** on critical code
9. **Run tests frequently** during development
10. **Fix failing tests immediately**

## Common Commands

```bash
# Run all tests
flutter test

# Run specific test file
flutter test test/services/my_service_test.dart

# Run with coverage
flutter test --coverage

# Run in watch mode
flutter test --watch

# Run integration tests
flutter test integration_test

# Run E2E tests
flutter drive --driver=test_driver/e2e_test.dart \
  --target=integration_test/e2e/user_flow_test.dart

# Check coverage
./scripts/check_coverage.sh

# Generate coverage report
./scripts/generate_coverage_report.sh
```

## Getting Help

- Review the testing guides in this directory
- Check existing tests for examples
- Ask in team chat for testing questions
- Create issues for testing infrastructure improvements

## Contributing

When adding new features:
1. Write tests for new code
2. Ensure tests pass locally
3. Verify coverage meets threshold
4. Update test documentation if needed
5. Add test utilities for common patterns

## Resources

### Internal Documentation
- [Testing Guide](./TESTING_GUIDE.md)
- [Unit Testing Guide](./UNIT_TESTING.md)
- [Integration Testing Guide](./INTEGRATION_TESTING.md)
- [Best Practices](./TEST_BEST_PRACTICES.md)

### External Resources
- [Flutter Testing Documentation](https://docs.flutter.dev/testing)
- [Effective Dart: Testing](https://dart.dev/guides/language/effective-dart/testing)
- [Mockito Package](https://pub.dev/packages/mockito)
- [Integration Testing](https://docs.flutter.dev/testing/integration-tests)

---

**Last Updated**: 2024-01-15
**Maintained By**: Engineering Team
