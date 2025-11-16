# Test Data Directory

This directory contains test data files used in unit, integration, and E2E tests.

## Structure

```
test_data/
├── sample_transcription.json   # Sample transcription segments
├── sample_ai_response.json     # Sample AI analysis responses
├── audio/                      # Audio test files (if needed)
└── fixtures/                   # Additional test fixtures
```

## Usage

### In Unit Tests

```dart
import 'package:flutter_test/flutter_test.dart';
import '../fixtures/test_data_manager.dart';

void main() {
  test('Load test data', () async {
    final manager = TestDataManager();
    final data = await manager.loadJsonFixture('sample_transcription.json');

    expect(data['segments'], isNotNull);
  });
}
```

### In Integration Tests

```dart
final testData = await TestDataManager()
  .loadJsonFixture('sample_ai_response.json');

// Use test data in your integration test
expect(testData['sentiment']['score'], greaterThan(0.5));
```

## Adding New Test Data

1. Create your test data file in the appropriate format (JSON, text, binary)
2. Place it in this directory or a subdirectory
3. Document the file's purpose and structure in this README
4. Update test fixtures to reference the new data

## Test Data Guidelines

### DO:
- Use realistic data that represents actual use cases
- Include edge cases and boundary conditions
- Document the purpose of each test data file
- Keep test data files small and focused
- Use version control for test data

### DON'T:
- Include sensitive or personal information
- Use production data
- Create overly large test files
- Hardcode test data in test files
- Include binary files without documentation

## File Descriptions

### sample_transcription.json
Sample transcription data including:
- Multiple transcription segments
- Confidence scores
- Timestamps
- Language information
- Metadata

Use for testing transcription display, processing, and analysis.

### sample_ai_response.json
Sample AI analysis response including:
- Sentiment analysis results
- Fact-checking data
- Claim detection
- Keywords and summaries

Use for testing AI feature integration and display.

## Maintenance

- Review test data files quarterly
- Remove obsolete test data
- Update data to match current API responses
- Ensure data reflects latest features
- Keep documentation current
