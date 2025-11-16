# End-to-End (E2E) Tests

This directory contains end-to-end tests that verify complete user flows and system behavior.

## What are E2E Tests?

E2E tests simulate real user interactions with the application, testing the complete flow from UI to backend services. They verify that all components work together correctly in production-like scenarios.

## Running E2E Tests

### On iOS Simulator
```bash
flutter drive \
  --driver=test_driver/e2e_test.dart \
  --target=integration_test/e2e/user_flow_test.dart \
  -d iPhone
```

### On iOS Device
```bash
flutter drive \
  --driver=test_driver/e2e_test.dart \
  --target=integration_test/e2e/user_flow_test.dart \
  -d <device-id>
```

### With Performance Profiling
```bash
flutter drive \
  --driver=test_driver/e2e_test.dart \
  --target=integration_test/e2e/user_flow_test.dart \
  --profile
```

## Test Categories

### User Flow Tests
Complete user journeys through the application:
- Recording and transcription flow
- Settings configuration
- AI feature usage
- Error recovery

### Performance Tests
Tests that measure and verify performance:
- App launch time
- Recording performance
- Transcription speed
- Memory usage
- Battery consumption

### Accessibility Tests
Tests that verify accessibility compliance:
- Screen reader support
- Semantic labels
- Contrast ratios
- Large text support
- Keyboard navigation

### Offline Scenarios
Tests that verify offline functionality:
- Native transcription without network
- Data queuing for sync
- Error messaging
- Feature degradation

## Writing E2E Tests

E2E tests should:
1. Test complete, realistic user flows
2. Use real services (not mocks) when possible
3. Include performance measurements
4. Test error scenarios
5. Verify accessibility
6. Test on multiple device sizes
7. Handle platform-specific behavior

### Example E2E Test Structure
```dart
testWidgets('User completes recording flow', (tester) async {
  // 1. Setup
  await setupPermissions();
  app.main();
  await tester.pumpAndSettle();

  // 2. Navigate to feature
  await navigateToRecording(tester);

  // 3. Perform actions
  await startRecording(tester);
  await Future.delayed(Duration(seconds: 5));
  await stopRecording(tester);

  // 4. Verify results
  await verifyTranscriptionShown(tester);
  await verifyAIInsights(tester);

  // 5. Cleanup
  await cleanupRecording();
});
```

## Best Practices

### Test Data
- Use realistic test data
- Include edge cases
- Test with various audio qualities
- Test different languages

### Performance
- Set performance budgets
- Monitor memory usage
- Track frame rates
- Measure network usage

### Reliability
- Handle flaky tests with retries
- Add explicit waits for async operations
- Verify preconditions
- Clean up after tests

### Documentation
- Document test scenarios
- Explain expected behavior
- Note platform differences
- Document known issues

## Platform-Specific Considerations

### iOS
- Handle permissions prompts
- Test with different iOS versions
- Verify background audio
- Test with various device models

### Device Capabilities
- Test on low-end devices
- Verify battery impact
- Test with limited storage
- Test with poor network

## Performance Budgets

Set and enforce performance budgets:

```dart
// Example performance assertions
expect(launchTime, lessThan(Duration(seconds: 3)));
expect(memoryUsage, lessThan(100 * 1024 * 1024)); // 100 MB
expect(frameBuildTime, lessThan(Duration(milliseconds: 16))); // 60 FPS
```

## Debugging E2E Tests

### Enable Verbose Logging
```bash
flutter drive --verbose ...
```

### Capture Screenshots
```dart
await binding.takeScreenshot('screenshot-name');
```

### Record Video
Use iOS Simulator's screen recording feature or device recording tools.

### View Timeline
```dart
await binding.traceAction(
  () async { /* test actions */ },
  reportKey: 'timeline',
);
```

## CI/CD Integration

E2E tests run in CI/CD pipeline:
- On PR merges
- Before releases
- On nightly builds
- Performance regression detection

## Troubleshooting

### Tests Timeout
- Increase timeout values
- Add more pumpAndSettle calls
- Check for infinite animations
- Verify network responses

### Flaky Tests
- Add explicit waits
- Use finders with timeouts
- Handle async operations properly
- Verify test isolation

### Permission Issues
- Grant permissions in setup
- Use permission_handler
- Test permission denial scenarios
- Verify permission persistence

### Device-Specific Issues
- Test on multiple devices
- Check iOS version compatibility
- Verify device capabilities
- Handle device-specific quirks
