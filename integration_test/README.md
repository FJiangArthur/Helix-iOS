# Integration Tests

This directory contains integration tests for the Helix iOS application. Integration tests verify that multiple components work together correctly.

## Running Integration Tests

### Prerequisites
- Flutter SDK installed
- iOS Simulator or physical device
- All dependencies installed (`flutter pub get`)

### Run All Integration Tests
```bash
flutter test integration_test
```

### Run Specific Integration Test
```bash
flutter test integration_test/app_integration_test.dart
```

### Run on iOS Device
```bash
flutter drive \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/app_integration_test.dart
```

## Test Organization

### app_integration_test.dart
Main application integration tests covering:
- App launch and initialization
- Navigation flows
- Core feature integration

### audio_transcription_integration_test.dart
Tests for audio recording and transcription:
- Audio service initialization
- Transcription service integration
- Mode switching
- Error handling

### ai_services_integration_test.dart
Tests for AI analysis features:
- Sentiment analysis
- Fact-checking
- Claim detection
- Multi-service integration

## Writing Integration Tests

Integration tests should:
1. Test realistic user flows
2. Verify multiple components working together
3. Use real services when possible (with test data)
4. Handle async operations properly
5. Clean up resources in tearDown()

Example:
```dart
testWidgets('User can record and transcribe audio', (tester) async {
  // 1. Navigate to recording screen
  await tester.tap(find.byIcon(Icons.mic));
  await tester.pumpAndSettle();

  // 2. Start recording
  await tester.tap(find.text('Start Recording'));
  await tester.pump(Duration(seconds: 2));

  // 3. Stop recording
  await tester.tap(find.text('Stop Recording'));
  await tester.pumpAndSettle();

  // 4. Verify transcription appears
  expect(find.byType(TranscriptionWidget), findsOneWidget);
});
```

## Best Practices

1. **Isolation**: Each test should be independent
2. **Cleanup**: Always dispose resources in tearDown()
3. **Timeouts**: Set appropriate timeouts for async operations
4. **Mocking**: Use mocks for external dependencies (APIs, etc.)
5. **Permissions**: Handle platform permissions in tests
6. **Data**: Use test fixtures for consistent test data

## Troubleshooting

### Tests Timeout
- Increase timeout in test configuration
- Check for hanging async operations
- Verify services are properly initialized

### Permission Errors
- Grant necessary permissions before running tests
- Use permission_handler for test setup

### State Issues
- Ensure proper cleanup in tearDown()
- Reset singletons between tests
- Clear caches and storage

## CI/CD Integration

Integration tests are run as part of the CI/CD pipeline:
- On pull requests
- Before deployment
- On scheduled runs

See `.github/workflows/` for CI configuration.
