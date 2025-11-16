# Privacy and Data Retention Implementation Guide

## Overview

This guide provides developers with practical instructions for implementing and maintaining data retention and privacy features in the Helix-iOS application.

**Last Updated**: 2025-11-16
**Target Audience**: Developers, QA Engineers, Product Managers

---

## Quick Start

### 1. Initialize Privacy Services

Add to your app initialization (e.g., `main.dart`):

```dart
import 'package:helix/core/config/privacy_config.dart';
import 'package:helix/core/utils/data_cleanup_service.dart';
import 'package:helix/services/analytics_service.dart';

Future<void> initializePrivacyServices() async {
  // Load or create privacy configuration
  final privacyConfig = PrivacyConfig(
    analyticsEnabled: true,
    aiAnalysisEnabled: true,
    autoDeleteEnabled: true,
    anonymizeExports: true,
    requireSecureDeletion: true,
  );

  // Initialize data cleanup service
  DataCleanupService.instance.initialize(privacyConfig);

  // Schedule periodic cleanup (every 6 hours)
  DataCleanupService.instance.schedulePeriodicCleanup(
    interval: const Duration(hours: 6),
  );

  // Initialize analytics with consent
  if (privacyConfig.analyticsEnabled && privacyConfig.hasAnalyticsConsent) {
    AnalyticsService.instance.initialize();
  }
}
```

### 2. Respect Privacy Configuration

Before collecting any data, check privacy settings:

```dart
import 'package:helix/core/config/privacy_config.dart';

// Check before analytics tracking
if (privacyConfig.analyticsEnabled) {
  AnalyticsService.instance.track(AnalyticsEvent.recordingStarted);
}

// Check before AI processing
if (privacyConfig.aiAnalysisEnabled && privacyConfig.hasAIProcessingConsent) {
  final result = await aiService.analyzeConversation(transcript);
}
```

### 3. Implement Data Export

Add a data export button to your settings screen:

```dart
import 'package:helix/core/utils/data_export_service.dart';

Future<void> exportUserData() async {
  final result = await DataExportService.instance.exportCompleteDataPackage(
    config: privacyConfig,
    anonymize: true,
  );

  if (result.success) {
    // Save to file or share
    final filePath = '/path/to/exports/${result.fileName}';
    await DataExportService.instance.saveExportToFile(result, filePath);

    // Show success message
    print('Data exported: ${result.sizeFormatted}');
  } else {
    // Handle error
    print('Export failed: ${result.error}');
  }
}
```

### 4. Implement Data Deletion

Add deletion options to your settings screen:

```dart
import 'package:helix/core/utils/data_cleanup_service.dart';
import 'package:helix/services/analytics_service.dart';

// Delete all audio files
Future<void> deleteAllAudio() async {
  final count = await DataCleanupService.instance.deleteAllAudioFiles();
  print('Deleted $count audio files');
}

// Delete all analytics
void clearAnalytics() {
  AnalyticsService.instance.clearEvents();
}

// Delete a specific file
Future<void> deleteFile(String filePath) async {
  final success = await DataCleanupService.instance.deleteFile(
    filePath,
    secure: true,
  );
}

// Run full cleanup
Future<void> runCleanup() async {
  final result = await DataCleanupService.instance.runCleanup();
  print(result);
}
```

---

## File Structure

### New Files Created

```
lib/core/
├── config/
│   └── privacy_config.dart          # Privacy configuration and retention periods
└── utils/
    ├── data_cleanup_service.dart     # Automated data cleanup and deletion
    ├── data_anonymization_service.dart # Data anonymization utilities
    └── data_export_service.dart      # GDPR data portability exports

docs/
├── DATA_RETENTION_POLICY.md          # Complete retention policy document
├── GDPR_COMPLIANCE_GUIDE.md          # GDPR compliance implementation guide
└── PRIVACY_IMPLEMENTATION_README.md  # This file - developer guide
```

### Existing Files Referenced

```
lib/
├── models/
│   ├── conversation_model.dart       # Conversation data models
│   ├── transcription_segment.dart    # Transcription data models
│   ├── analysis_result.dart          # AI analysis result models
│   ├── audio_chunk.dart              # Audio data models
│   └── ble_health_metrics.dart       # BLE metrics models
├── services/
│   ├── analytics_service.dart        # Analytics tracking
│   └── audio_service.dart            # Audio recording
└── core/
    └── utils/
        └── logging_service.dart      # Application logging
```

---

## Usage Examples

### Example 1: Configure Retention Periods

```dart
import 'package:helix/core/config/privacy_config.dart';

// Use default retention periods
final config1 = const PrivacyConfig();

// Customize retention periods
final config2 = PrivacyConfig(
  customRetentionPeriods: {
    'audioRecordings': const Duration(hours: 12),  // Shorter retention
    'transcriptionResults': const Duration(days: 3),
    'analyticsEvents': const Duration(hours: 6),
  },
);

// Get retention period for a data type
final audioRetention = config2.getRetentionPeriod('audioRecordings');
print('Audio retention: ${audioRetention.inHours} hours');
```

### Example 2: Anonymize Data for Export

```dart
import 'package:helix/core/utils/data_anonymization_service.dart';
import 'package:helix/core/config/privacy_config.dart';

final anonymizer = DataAnonymizationService.instance;
final config = PrivacyConfig(removeSpeakerIds: true);

// Anonymize a conversation
final conversation = /* ... get conversation ... */;
final anonConversation = anonymizer.anonymizeConversation(
  conversation,
  config,
);

// Anonymize analytics before export
final analytics = AnalyticsService.instance;
final events = analytics.getEvents();
final exportData = anonymizer.exportAnonymizedAnalytics(events, config);

print('Exported ${exportData['totalEvents']} anonymized events');
```

### Example 3: Check Storage Usage

```dart
import 'package:helix/core/utils/data_cleanup_service.dart';

Future<void> showStorageInfo() async {
  final stats = await DataCleanupService.instance.getStorageStats();

  print('Audio Files: ${stats.audioFileCount} (${stats.formatSize(stats.audioFileSize)})');
  print('Temp Files: ${stats.tempFileCount} (${stats.formatSize(stats.tempFileSize)})');
  print('Total: ${stats.totalFiles} (${stats.formatSize(stats.totalSize)})');

  // Or get JSON representation
  final json = stats.toJson();
  print(json);
}
```

### Example 4: Run Scheduled Cleanup

```dart
import 'package:helix/core/utils/data_cleanup_service.dart';
import 'package:helix/core/config/privacy_config.dart';

Future<void> setupAutomaticCleanup() async {
  final config = PrivacyConfig(autoDeleteEnabled: true);

  DataCleanupService.instance.initialize(config);

  // Run cleanup every 6 hours
  DataCleanupService.instance.schedulePeriodicCleanup(
    interval: const Duration(hours: 6),
  );

  // Or run cleanup manually
  final result = await DataCleanupService.instance.runCleanup();
  print('Cleanup result: $result');
}
```

### Example 5: Implement Consent Management

```dart
import 'package:helix/core/config/privacy_config.dart';

class ConsentManager {
  PrivacyConfig _config = const PrivacyConfig();

  // Request analytics consent
  Future<void> requestAnalyticsConsent() async {
    // Show consent dialog
    final granted = await showConsentDialog('Analytics');

    if (granted) {
      _config = _config.copyWith(
        hasAnalyticsConsent: true,
        analyticsEnabled: true,
        consentTimestamp: DateTime.now(),
      );
      await saveConfig(_config);
    }
  }

  // Request AI processing consent
  Future<void> requestAIConsent() async {
    final granted = await showConsentDialog('AI Processing');

    if (granted) {
      _config = _config.copyWith(
        hasAIProcessingConsent: true,
        aiAnalysisEnabled: true,
        consentTimestamp: DateTime.now(),
      );
      await saveConfig(_config);
    }
  }

  // Withdraw all consents
  Future<void> withdrawAllConsents() async {
    _config = _config.copyWith(
      hasAnalyticsConsent: false,
      hasAIProcessingConsent: false,
      hasDataExportConsent: false,
      analyticsEnabled: false,
      aiAnalysisEnabled: false,
    );
    await saveConfig(_config);

    // Delete associated data
    await DataCleanupService.instance.deleteAllAudioFiles();
    AnalyticsService.instance.clearEvents();
  }

  Future<void> saveConfig(PrivacyConfig config) async {
    // Save to SharedPreferences or local storage
    final json = config.toJson();
    // await storage.save('privacy_config', json);
  }
}
```

---

## Privacy Checklist for Developers

### Before Collecting Any Data

- [ ] Check if privacy config allows collection
- [ ] Verify user consent if required
- [ ] Document what data is being collected
- [ ] Specify retention period
- [ ] Implement deletion mechanism

### When Adding New Features

- [ ] Update `DataTypeRegistry` if new data types
- [ ] Add retention period to `DataRetentionPeriods`
- [ ] Implement cleanup in `DataCleanupService`
- [ ] Add anonymization support if needed
- [ ] Update privacy policy documentation
- [ ] Add to data export if user-generated
- [ ] Implement user deletion option

### Before Release

- [ ] Review all data collection points
- [ ] Test data export functionality
- [ ] Test data deletion functionality
- [ ] Verify retention periods are enforced
- [ ] Check anonymization works correctly
- [ ] Review third-party data sharing
- [ ] Update privacy documentation
- [ ] Test consent management flows

---

## Common Scenarios

### Scenario 1: Adding a New Data Type

1. **Add to DataTypeRegistry:**
```dart
// In lib/core/config/privacy_config.dart
static const Map<String, DataTypeMetadata> dataTypes = {
  // ... existing types ...
  'newDataType': DataTypeMetadata(
    name: 'New Data Type',
    sensitivity: DataSensitivity.confidential,
    defaultRetention: Duration(days: 7),
    requiresConsent: true,
    canBeAnonymized: true,
    requiresEncryption: false,
  ),
};
```

2. **Add retention period:**
```dart
// In lib/core/config/privacy_config.dart
class DataRetentionPeriods {
  // ... existing periods ...
  static const Duration newDataType = Duration(days: 7);
}
```

3. **Implement cleanup:**
```dart
// In lib/core/utils/data_cleanup_service.dart
Future<CleanupItemResult> _cleanupNewDataType() async {
  // Implement cleanup logic
}
```

4. **Add to export:**
```dart
// In lib/core/utils/data_export_service.dart
Future<ExportResult> exportNewDataType() async {
  // Implement export logic
}
```

### Scenario 2: Handling User Deletion Request

```dart
Future<void> handleUserDeletionRequest(String dataType) async {
  switch (dataType) {
    case 'all':
      // Delete everything
      await DataCleanupService.instance.deleteAllAudioFiles();
      AnalyticsService.instance.clearEvents();
      // Clear other data stores
      break;

    case 'audio':
      await DataCleanupService.instance.deleteAllAudioFiles();
      break;

    case 'analytics':
      AnalyticsService.instance.clearEvents();
      break;

    case 'specific_file':
      await DataCleanupService.instance.deleteFile(filePath, secure: true);
      break;
  }

  // Log deletion for compliance
  print('User deletion request processed: $dataType');
}
```

### Scenario 3: Responding to Data Access Request

```dart
Future<void> handleDataAccessRequest() async {
  // Collect all user data
  final analyticsExport = await DataExportService.instance.exportAnalyticsData(
    config: privacyConfig,
    anonymize: false, // User's own data
  );

  final audioExport = await DataExportService.instance.exportAudioFileMetadata(
    config: privacyConfig,
  );

  final prefsExport = await DataExportService.instance.exportUserPreferences(
    config: privacyConfig,
  );

  // Combine and provide to user
  final completePackage = await DataExportService.instance.exportCompleteDataPackage(
    config: privacyConfig,
    anonymize: false,
  );

  // Save and share
  final filePath = '/path/to/user_data_export.json';
  await DataExportService.instance.saveExportToFile(completePackage, filePath);

  // Provide download link or email to user
}
```

---

## Testing

### Unit Tests

```dart
// test/privacy/data_cleanup_test.dart
void main() {
  group('DataCleanupService', () {
    test('deletes files older than retention period', () async {
      // Setup
      final service = DataCleanupService.instance;
      final config = PrivacyConfig(autoDeleteEnabled: true);
      service.initialize(config);

      // Create test files with different ages
      // ...

      // Execute cleanup
      final result = await service.runCleanup();

      // Verify
      expect(result.success, isTrue);
      expect(result.itemsDeleted, greaterThan(0));
    });
  });
}
```

### Integration Tests

```dart
// test/privacy/privacy_integration_test.dart
void main() {
  testWidgets('user can export all data', (tester) async {
    // Navigate to settings
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    // Navigate to privacy
    await tester.tap(find.text('Privacy'));
    await tester.pumpAndSettle();

    // Tap export
    await tester.tap(find.text('Export Data'));
    await tester.pumpAndSettle();

    // Verify export successful
    expect(find.text('Export Complete'), findsOneWidget);
  });
}
```

---

## Troubleshooting

### Issue: Data not being deleted automatically

**Solution:**
1. Check if `autoDeleteEnabled` is true in privacy config
2. Verify `schedulePeriodicCleanup()` is called
3. Check retention periods are configured correctly
4. Review logs for cleanup errors

### Issue: Export fails with large datasets

**Solution:**
1. Implement pagination for large exports
2. Export data in chunks
3. Compress export files
4. Consider streaming export for very large datasets

### Issue: Anonymization removes too much data

**Solution:**
1. Review anonymization rules in `DataAnonymizationService`
2. Adjust `_removePersonalInfo()` patterns
3. Make anonymization configurable per data type
4. Test with sample data before production

---

## Performance Considerations

### Cleanup Performance

- Run cleanup during off-peak hours
- Limit number of files processed per batch
- Use background tasks for cleanup
- Monitor cleanup duration

### Export Performance

- Implement pagination for large exports
- Stream data instead of loading all in memory
- Compress export files
- Show progress indicators

### Anonymization Performance

- Cache anonymized IDs to avoid regeneration
- Process data in batches
- Use efficient string replacement algorithms
- Profile anonymization on large datasets

---

## Security Best Practices

1. **Never log sensitive data**
   - No PII in debug logs
   - No API keys in logs
   - Sanitize error messages

2. **Secure file deletion**
   - Always use `secureDeleteFile()` for sensitive data
   - Overwrite files before deletion
   - Verify deletion completed

3. **API key protection**
   - Store in local config files only
   - Never commit to version control
   - Rotate keys periodically
   - Use environment variables

4. **Data transmission**
   - Always use HTTPS/TLS
   - Minimize data in API requests
   - Validate API responses
   - Handle network errors gracefully

---

## Support and Resources

### Documentation

- [Data Retention Policy](/docs/DATA_RETENTION_POLICY.md)
- [GDPR Compliance Guide](/docs/GDPR_COMPLIANCE_GUIDE.md)
- [Privacy Config API](/lib/core/config/privacy_config.dart)

### Contact

- Privacy questions: privacy@helix-app.example.com
- Technical support: dev-support@helix-app.example.com
- Security issues: security@helix-app.example.com

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | 2025-11-16 | Initial implementation guide |

---

**Next Steps:**
1. Review this guide with your team
2. Implement privacy features in your app
3. Test thoroughly
4. Update documentation as needed
5. Schedule regular privacy reviews
