# Unit Testing Guidelines

Comprehensive guide to writing effective unit tests for the Helix iOS application.

## What is Unit Testing?

Unit testing focuses on testing individual components (classes, methods, functions) in isolation. Each test should verify a single behavior or aspect of the component.

## Test Structure

### The AAA Pattern

All unit tests should follow the Arrange-Act-Assert pattern:

```dart
test('description', () {
  // Arrange: Set up test data and dependencies
  final service = MyService();
  final input = 'test input';

  // Act: Execute the behavior being tested
  final result = service.process(input);

  // Assert: Verify the expected outcome
  expect(result, equals('expected output'));
});
```

### Test Organization

```dart
void main() {
  group('ClassName', () {
    // Shared test instance
    late ClassName instance;

    // Runs before each test
    setUp(() {
      instance = ClassName();
    });

    // Runs after each test
    tearDown(() {
      instance.dispose();
    });

    group('method1', () {
      test('returns expected value when given valid input', () {
        // Test implementation
      });

      test('throws exception when given invalid input', () {
        // Test implementation
      });
    });

    group('method2', () {
      test('updates state correctly', () {
        // Test implementation
      });
    });
  });
}
```

## Writing Effective Tests

### 1. Test One Thing

Each test should verify a single behavior:

**Good**:
```dart
test('returns uppercase string', () {
  expect(toUpperCase('hello'), equals('HELLO'));
});

test('handles null input', () {
  expect(() => toUpperCase(null), throwsArgumentError);
});
```

**Bad**:
```dart
test('string operations', () {
  expect(toUpperCase('hello'), equals('HELLO'));
  expect(() => toUpperCase(null), throwsArgumentError);
  expect(toLowerCase('WORLD'), equals('world'));
});
```

### 2. Use Descriptive Names

Test names should clearly describe what they test:

**Good**:
```dart
test('calculates audio duration correctly for 16kHz mono audio', () { ... });
test('throws exception when sample rate is zero', () { ... });
test('returns empty list when no segments are available', () { ... });
```

**Bad**:
```dart
test('test1', () { ... });
test('it works', () { ... });
test('audio test', () { ... });
```

### 3. Test Edge Cases

Cover boundary conditions and edge cases:

```dart
group('AudioChunk.durationMs', () {
  test('returns 0 for empty data', () {
    final chunk = AudioChunk.empty();
    expect(chunk.durationMs, equals(0));
  });

  test('calculates correctly for exactly 1 second', () {
    final chunk = AudioChunkFactory.withDuration(durationMs: 1000);
    expect(chunk.durationMs, equals(1000));
  });

  test('handles very large audio chunks', () {
    final chunk = AudioChunkFactory.withDuration(durationMs: 3600000); // 1 hour
    expect(chunk.durationMs, equals(3600000));
  });
});
```

### 4. Use Test Fixtures

Leverage test fixtures for consistent test data:

```dart
import '../fixtures/audio_fixtures.dart';

test('processes audio chunk correctly', () {
  // Use factory method
  final chunk = AudioChunkFactory.create(
    sampleRate: AudioTestConstants.standardSampleRate,
  );

  final result = processor.process(chunk);

  expect(result, isNotNull);
});
```

### 5. Test Async Code Properly

Handle asynchronous operations correctly:

```dart
test('async method completes successfully', () async {
  final service = AsyncService();

  final result = await service.fetchData();

  expect(result, isNotNull);
});

test('stream emits expected values', () async {
  final service = StreamService();

  await expectLater(
    service.dataStream,
    emitsInOrder([
      'value1',
      'value2',
      'value3',
    ]),
  );
});

test('future completes with error', () async {
  final service = FailingService();

  await expectLater(
    service.fetchData(),
    throwsA(isA<NetworkException>()),
  );
});
```

## Common Testing Patterns

### Testing Classes with Dependencies

Use dependency injection and mocking:

```dart
// Production code
class TranscriptionService {
  TranscriptionService(this.audioService);

  final AudioService audioService;

  Future<String> transcribe() async {
    final audio = await audioService.getAudio();
    return processAudio(audio);
  }
}

// Test code
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';

@GenerateMocks([AudioService])
void main() {
  test('transcription uses audio from service', () async {
    // Arrange
    final mockAudio = MockAudioService();
    when(mockAudio.getAudio())
        .thenAnswer((_) async => AudioData());

    final service = TranscriptionService(mockAudio);

    // Act
    await service.transcribe();

    // Assert
    verify(mockAudio.getAudio()).called(1);
  });
}
```

### Testing Singletons

Reset singleton state between tests:

```dart
group('SingletonService', () {
  setUp(() {
    SingletonService.instance.reset(); // Reset state
  });

  test('maintains state across calls', () {
    final service = SingletonService.instance;

    service.setValue(42);

    expect(service.getValue(), equals(42));
  });
});
```

### Testing Error Handling

Verify error cases are handled correctly:

```dart
test('throws exception for invalid input', () {
  expect(
    () => service.process(null),
    throwsA(isA<ArgumentError>()),
  );
});

test('returns error result for network failure', () async {
  final result = await service.fetchWithFallback();

  expect(result.isError, isTrue);
  expect(result.error, contains('Network'));
});
```

### Testing State Management

Verify state changes correctly:

```dart
test('state transitions correctly', () {
  final stateMachine = StateMachine();

  expect(stateMachine.state, equals(State.initial));

  stateMachine.start();
  expect(stateMachine.state, equals(State.running));

  stateMachine.stop();
  expect(stateMachine.state, equals(State.stopped));
});
```

## Custom Matchers

Use custom matchers for better test readability:

```dart
import '../helpers/test_helpers.dart';

test('timestamp is recent', () {
  final chunk = AudioChunk.fromBytes([1, 2, 3]);

  expect(
    chunk.timestamp,
    TestMatchers.isDateTimeCloseTo(
      DateTime.now(),
      tolerance: Duration(seconds: 1),
    ),
  );
});

test('confidence is within valid range', () {
  final segment = TranscriptionSegment(confidence: 0.85);

  expect(segment.confidence, greaterThanOrEqualTo(0.0));
  expect(segment.confidence, lessThanOrEqualTo(1.0));
});
```

## Test Coverage Goals

### What to Test

✅ **DO Test**:
- Public APIs
- Edge cases and boundaries
- Error conditions
- State transitions
- Business logic
- Data transformations

❌ **DON'T Test**:
- Private methods directly (test through public API)
- Third-party library code
- Generated code (.g.dart, .freezed.dart)
- Simple getters/setters
- UI layout (use widget tests)

### Coverage Targets

- **Critical business logic**: 95%+
- **Services and utilities**: 90%+
- **Models and data classes**: 85%+
- **Overall project**: 80%+

## Performance Considerations

### Keep Tests Fast

```dart
// Good: Fast, focused test
test('calculates sum quickly', () {
  expect(add(2, 2), equals(4));
});

// Bad: Slow test with unnecessary delays
test('calculates sum', () async {
  await Future.delayed(Duration(seconds: 1)); // Unnecessary
  expect(add(2, 2), equals(4));
});
```

### Avoid External Dependencies

```dart
// Good: Use mocks for external services
test('fetches data from API', () async {
  final mockApi = MockApiService();
  when(mockApi.getData()).thenAnswer((_) async => testData);

  final result = await service.fetch();
  expect(result, equals(testData));
});

// Bad: Actual network call
test('fetches data from API', () async {
  final result = await http.get('https://api.example.com/data');
  expect(result.statusCode, equals(200));
});
```

## Common Pitfalls

### 1. Testing Implementation Details

**Bad**: Tests internal implementation
```dart
test('uses specific algorithm', () {
  expect(service.sortAlgorithm, equals('quicksort'));
});
```

**Good**: Tests behavior
```dart
test('sorts list correctly', () {
  final result = service.sort([3, 1, 2]);
  expect(result, equals([1, 2, 3]));
});
```

### 2. Overly Complex Tests

**Bad**: Complex test setup
```dart
test('complex scenario', () {
  final a = createA();
  final b = createB(a);
  final c = createC(b);
  final d = createD(c, someValue);
  // ... many more steps
});
```

**Good**: Use helper methods
```dart
test('complex scenario', () {
  final system = createTestSystem();
  final result = system.execute();
  expect(result, isValid);
});
```

### 3. Shared Mutable State

**Bad**: Tests share state
```dart
final sharedList = []; // Shared across tests

test('adds item', () {
  sharedList.add('item');
  expect(sharedList.length, equals(1));
});

test('removes item', () {
  sharedList.remove('item'); // Depends on previous test!
});
```

**Good**: Independent tests
```dart
test('adds item', () {
  final list = [];
  list.add('item');
  expect(list.length, equals(1));
});

test('removes item', () {
  final list = ['item'];
  list.remove('item');
  expect(list.isEmpty, isTrue);
});
```

## Testing Checklist

Before committing tests, verify:

- [ ] Tests follow AAA pattern
- [ ] Test names are descriptive
- [ ] Tests are independent
- [ ] Edge cases are covered
- [ ] Async code is tested properly
- [ ] Mocks are used for dependencies
- [ ] Tests run quickly (< 100ms each)
- [ ] tearDown() cleans up resources
- [ ] No hardcoded test data
- [ ] Tests are readable and maintainable

## Resources

- [Flutter Testing Documentation](https://docs.flutter.dev/testing)
- [Effective Dart: Testing](https://dart.dev/guides/language/effective-dart/testing)
- [Mockito Package](https://pub.dev/packages/mockito)
- [Test Fixtures Guide](../../test/fixtures/README.md)
