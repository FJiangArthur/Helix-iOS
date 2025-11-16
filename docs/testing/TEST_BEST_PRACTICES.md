# Testing Best Practices

Comprehensive best practices for testing in the Helix iOS application.

## General Principles

### 1. Write Tests First (TDD)

Consider writing tests before implementation:

```dart
// 1. Write the test
test('calculates duration correctly', () {
  final chunk = AudioChunk.fromBytes([...]);
  expect(chunk.durationMs, equals(1000));
});

// 2. Implement to make it pass
class AudioChunk {
  int get durationMs => calculateDuration();
}

// 3. Refactor if needed
```

### 2. Keep Tests Simple

Tests should be simpler than the code they test:

**Good**:
```dart
test('adds two numbers', () {
  expect(add(2, 3), equals(5));
});
```

**Bad**:
```dart
test('complex calculation', () {
  final input = generateComplexInput();
  final expected = calculateExpectedResult(input);
  final actual = performCalculation(input);
  expect(transformResult(actual), equals(transformExpected(expected)));
});
```

### 3. Test Behavior, Not Implementation

Focus on what the code does, not how it does it:

**Good**: Tests behavior
```dart
test('sorts numbers in ascending order', () {
  final result = sort([3, 1, 2]);
  expect(result, equals([1, 2, 3]));
});
```

**Bad**: Tests implementation
```dart
test('uses quicksort algorithm', () {
  expect(sorter.algorithm, equals('quicksort'));
  expect(sorter.pivotStrategy, equals('median-of-three'));
});
```

## Test Organization

### 1. Group Related Tests

```dart
void main() {
  group('AudioChunk', () {
    group('constructor', () {
      test('creates from bytes', () { ... });
      test('creates empty chunk', () { ... });
    });

    group('durationMs', () {
      test('calculates correctly for standard audio', () { ... });
      test('returns 0 for empty chunk', () { ... });
      test('handles stereo audio', () { ... });
    });
  });
}
```

### 2. Use Descriptive Test Names

Follow the pattern: "should [expected behavior] when [condition]"

```dart
test('should return empty list when no data is available', () { ... });
test('should throw exception when input is null', () { ... });
test('should cache result when called multiple times', () { ... });
```

### 3. One Assertion Per Test

Each test should verify one thing:

**Good**:
```dart
test('isEmpty returns true for empty data', () {
  final chunk = AudioChunk.empty();
  expect(chunk.isEmpty, isTrue);
});

test('isEmpty returns false for non-empty data', () {
  final chunk = AudioChunk.fromBytes([1, 2, 3]);
  expect(chunk.isEmpty, isFalse);
});
```

**Bad**:
```dart
test('isEmpty works correctly', () {
  expect(AudioChunk.empty().isEmpty, isTrue);
  expect(AudioChunk.fromBytes([1]).isEmpty, isFalse);
  expect(AudioChunk.fromBytes([]).isEmpty, isTrue);
});
```

## Test Data Management

### 1. Use Factories for Test Data

```dart
// Create factory
class AudioChunkFactory {
  static AudioChunk standard() => AudioChunk.fromBytes([1, 2, 3, 4]);
  static AudioChunk empty() => AudioChunk.empty();
  static AudioChunk large() => AudioChunk.fromBytes(List.filled(10000, 0));
}

// Use in tests
test('processes standard chunk', () {
  final chunk = AudioChunkFactory.standard();
  expect(processor.process(chunk), isNotNull);
});
```

### 2. Avoid Magic Numbers

**Good**:
```dart
const int expectedSegmentCount = 5;
const double highConfidenceThreshold = 0.95;

test('returns expected segments', () {
  expect(result.length, equals(expectedSegmentCount));
  expect(result.first.confidence, greaterThan(highConfidenceThreshold));
});
```

**Bad**:
```dart
test('returns expected segments', () {
  expect(result.length, equals(5));
  expect(result.first.confidence, greaterThan(0.95));
});
```

### 3. Use Test Data Files

```dart
final testData = await TestDataManager()
  .loadJsonFixture('sample_transcription.json');

expect(testData['segments'], hasLength(3));
```

## Mocking and Stubbing

### 1. Mock External Dependencies

```dart
@GenerateMocks([AudioService, TranscriptionService])
void main() {
  test('uses audio service', () {
    final mockAudio = MockAudioService();
    when(mockAudio.getChunk()).thenReturn(testChunk);

    final processor = AudioProcessor(mockAudio);
    processor.process();

    verify(mockAudio.getChunk()).called(1);
  });
}
```

### 2. Don't Over-Mock

Only mock what you need to:

**Good**:
```dart
test('processes valid input', () {
  final processor = AudioProcessor();
  final result = processor.process(testData);
  expect(result, isValid);
});
```

**Bad**:
```dart
test('processes valid input', () {
  final mockValidator = MockValidator();
  final mockTransformer = MockTransformer();
  final mockStorage = MockStorage();
  // ... mocking everything unnecessarily
});
```

### 3. Verify Important Interactions

```dart
test('saves processed data', () {
  final mockStorage = MockStorage();
  final service = DataService(mockStorage);

  service.processAndSave(data);

  verify(mockStorage.save(any)).called(1);
  verifyNoMoreInteractions(mockStorage);
});
```

## Async Testing

### 1. Always Await Async Operations

```dart
test('completes async operation', () async {
  final result = await service.fetchData();
  expect(result, isNotNull);
});
```

### 2. Test Streams Properly

```dart
test('stream emits expected values', () async {
  final stream = service.dataStream;

  await expectLater(
    stream,
    emitsInOrder([
      predicate((x) => x > 0),
      predicate((x) => x > 10),
      emitsDone,
    ]),
  );
});
```

### 3. Handle Timeouts

```dart
test('completes within timeout', () async {
  final result = await service.slowOperation().timeout(
    Duration(seconds: 5),
    onTimeout: () => throw TimeoutException('Too slow'),
  );

  expect(result, isNotNull);
});
```

## Error Testing

### 1. Test Error Conditions

```dart
test('throws exception for invalid input', () {
  expect(
    () => service.process(null),
    throwsA(isA<ArgumentError>()),
  );
});

test('returns error for network failure', () async {
  final mockHttp = MockHttpClient();
  when(mockHttp.get(any)).thenThrow(NetworkException());

  final result = await service.fetch();

  expect(result.isError, isTrue);
});
```

### 2. Test Error Messages

```dart
test('provides helpful error message', () {
  try {
    service.process(invalidData);
    fail('Should have thrown');
  } catch (e) {
    expect(e.toString(), contains('Invalid data format'));
  }
});
```

## Performance Testing

### 1. Set Performance Budgets

```dart
test('completes within performance budget', () {
  final stopwatch = Stopwatch()..start();

  service.performOperation();

  stopwatch.stop();
  expect(stopwatch.elapsedMilliseconds, lessThan(100));
});
```

### 2. Test Memory Usage

```dart
test('does not leak memory', () async {
  final initialMemory = await getMemoryUsage();

  for (int i = 0; i < 1000; i++) {
    service.operation();
  }

  await Future.delayed(Duration(seconds: 1)); // Allow GC
  final finalMemory = await getMemoryUsage();

  expect(
    finalMemory - initialMemory,
    lessThan(10 * 1024 * 1024), // Less than 10MB growth
  );
});
```

## Widget Testing

### 1. Use Helper Functions

```dart
import '../helpers/widget_test_helpers.dart';

testWidgets('button triggers action', (tester) async {
  await pumpWidgetWithProviders(tester, MyWidget());

  await tapAndSettle(tester, find.byType(ElevatedButton));

  expect(find.text('Success'), findsOneWidget);
});
```

### 2. Test Accessibility

```dart
testWidgets('has proper accessibility labels', (tester) async {
  await tester.pumpWidget(MyWidget());

  final SemanticsHandle handle = tester.ensureSemantics();

  expect(
    tester.getSemantics(find.byType(IconButton)),
    matchesSemantics(
      label: 'Start Recording',
      isButton: true,
    ),
  );

  handle.dispose();
});
```

### 3. Test Different Screen Sizes

```dart
testWidgets('adapts to different screen sizes', (tester) async {
  // Test on small screen
  tester.binding.window.physicalSizeTestValue = Size(320, 568);
  await tester.pumpWidget(MyWidget());
  expect(find.byType(CompactLayout), findsOneWidget);

  // Test on large screen
  tester.binding.window.physicalSizeTestValue = Size(414, 896);
  await tester.pumpWidget(MyWidget());
  expect(find.byType(RegularLayout), findsOneWidget);
});
```

## Code Coverage

### 1. Aim for High Coverage

- Critical business logic: 95%+
- Services: 90%+
- Models: 85%+
- Overall: 80%+

### 2. Don't Chase 100%

Focus on meaningful tests, not coverage metrics:

**Good**: Test important behavior
```dart
test('validates user input correctly', () {
  expect(validator.validate('valid@email.com'), isTrue);
  expect(validator.validate('invalid'), isFalse);
});
```

**Bad**: Test trivial code for coverage
```dart
test('getter returns value', () {
  expect(user.name, equals(user.name));
});
```

### 3. Ignore Generated Code

Add to coverage exclusions:
```yaml
# .lcovrc
geninfo_no_recursion = 1
lcov_branch_coverage = 1

# Exclude patterns
exclude = **/*.g.dart,**/*.freezed.dart,**/*.mocks.dart
```

## Continuous Integration

### 1. Run Tests on Every Commit

```yaml
# .github/workflows/test.yml
on: [push, pull_request]

jobs:
  test:
    steps:
      - run: flutter test
      - run: flutter test integration_test
```

### 2. Enforce Coverage Thresholds

```bash
./scripts/check_coverage.sh
# Fails if coverage < 80%
```

### 3. Run Tests in Parallel

```bash
flutter test --concurrency=4
```

## Debugging Tests

### 1. Use Print Statements

```dart
test('debug failing test', () {
  print('Input: $input');
  final result = process(input);
  print('Result: $result');
  expect(result, expected);
});
```

### 2. Use Debugger

```dart
test('step through code', () {
  final input = createInput();
  debugger(); // Breakpoint
  final result = process(input);
  expect(result, isValid);
});
```

### 3. Isolate Failures

```dart
test('isolated test', () {
  // Comment out other tests
  // Run only this one
  final result = service.method();
  expect(result, expected);
}, skip: false); // or skip: 'debugging'
```

## Common Pitfalls to Avoid

### 1. Don't Test Framework Code

```dart
// Bad: Testing Flutter framework
test('ListView scrolls', () {
  // This tests Flutter, not your code
});

// Good: Test your business logic
test('list contains expected items', () {
  expect(viewModel.items, hasLength(5));
});
```

### 2. Don't Share State Between Tests

```dart
// Bad: Shared mutable state
final sharedList = [];

test('test 1', () {
  sharedList.add(1);
});

test('test 2', () {
  sharedList.add(2); // Depends on test 1!
});

// Good: Independent tests
test('test 1', () {
  final list = [];
  list.add(1);
  expect(list, hasLength(1));
});
```

### 3. Don't Make Tests Too Complex

```dart
// Bad: Complex test logic
test('complex test', () {
  final input = complexSetup();
  final transformer = createTransformer(input);
  final validator = createValidator(transformer);
  // ... many more steps
});

// Good: Simple and clear
test('simple test', () {
  final system = TestSystemBuilder.create();
  final result = system.execute(input);
  expect(result, isValid);
});
```

## Testing Checklist

Before committing, ensure:

- [ ] All tests pass locally
- [ ] New code has tests
- [ ] Tests are independent
- [ ] Tests are fast (< 100ms per unit test)
- [ ] Tests use descriptive names
- [ ] Edge cases are covered
- [ ] Mocks are properly used
- [ ] Async code is tested correctly
- [ ] Resources are cleaned up
- [ ] Coverage meets threshold

## Additional Resources

- [Testing Guide](./TESTING_GUIDE.md)
- [Unit Testing Guide](./UNIT_TESTING.md)
- [Integration Testing Guide](./INTEGRATION_TESTING.md)
- [Flutter Testing Best Practices](https://docs.flutter.dev/testing/best-practices)
- [Effective Dart: Testing](https://dart.dev/guides/language/effective-dart/testing)
