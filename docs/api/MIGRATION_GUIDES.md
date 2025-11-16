# Helix API Migration Guides

This document provides step-by-step migration guides for upgrading between major API versions.

## Table of Contents

1. [Current Version](#current-version)
2. [Migration Overview](#migration-overview)
3. [General Migration Process](#general-migration-process)
4. [Future Migrations](#future-migrations)
5. [Migration Tools](#migration-tools)
6. [Getting Help](#getting-help)

---

## Current Version

**Current API Version: 1.0.0**

This is the initial release. No migrations are needed at this time.

---

## Migration Overview

### Version Support Timeline

| From Version | To Version | Migration Required | Difficulty | Timeline | Guide |
|-------------|------------|-------------------|------------|----------|-------|
| 1.0.0 | Current | ✅ No | N/A | N/A | N/A |

### Future Planned Migrations

When new major versions are released, migration guides will be added here.

---

## General Migration Process

### Step 1: Assess Impact

Before starting a migration:

1. **Check Current Version**
   ```dart
   final router = APIVersionRouter(logger: logger);
   final versionInfo = router.getVersionInfo();
   print('Current version: ${versionInfo['methodChannelVersion']}');
   ```

2. **Review Changelog**
   - Read the [API Changelog](/docs/api/API_CHANGELOG.md)
   - Identify breaking changes affecting your code
   - Note new features you might want to adopt

3. **Identify Affected Code**
   ```dart
   // Search your codebase for API calls
   grep -r "invokeMethod" lib/
   grep -r "MethodChannel" lib/
   grep -r "EventChannel" lib/
   ```

4. **Estimate Effort**
   - Count affected API calls
   - Identify complex integrations
   - Plan testing requirements

### Step 2: Prepare for Migration

1. **Create Feature Branch**
   ```bash
   git checkout -b migration/api-v1-to-v2
   ```

2. **Update Dependencies**
   ```yaml
   # pubspec.yaml
   dependencies:
     flutter:
       sdk: flutter
     # Update any Helix-related packages
   ```

3. **Run Tests (Baseline)**
   ```bash
   flutter test
   flutter test integration_test/
   ```

4. **Document Current State**
   - List all API endpoints in use
   - Document current behavior
   - Take screenshots if needed

### Step 3: Perform Migration

Follow the specific migration guide for your version upgrade.

### Step 4: Test Migration

1. **Unit Tests**
   ```bash
   flutter test
   ```

2. **Integration Tests**
   ```bash
   flutter test integration_test/
   ```

3. **Manual Testing**
   - Test all affected features
   - Verify edge cases
   - Check error handling

4. **Performance Testing**
   - Compare performance metrics
   - Monitor memory usage
   - Check API response times

### Step 5: Deploy Migration

1. **Staged Rollout**
   - Deploy to development
   - Deploy to staging
   - Deploy to production

2. **Monitor**
   - Watch error logs
   - Monitor API usage
   - Check deprecation warnings

3. **Rollback Plan**
   - Keep old version available
   - Document rollback procedure
   - Test rollback process

---

## Future Migrations

### Template for Future Major Version Migrations

When migrating from version X.0.0 to Y.0.0, follow this template:

#### Overview

- **From Version**: X.0.0
- **To Version**: Y.0.0
- **Difficulty**: Low/Medium/High
- **Estimated Time**: X hours
- **Breaking Changes**: List of breaking changes

#### Breaking Changes

1. **Change Name**: Description
   - **Impact**: High/Medium/Low
   - **Affected APIs**: List
   - **Migration**: Step-by-step instructions

#### New Features

1. **Feature Name**: Description
   - **Benefits**: Why adopt this feature
   - **Usage**: How to use it

#### Code Examples

##### Before (vX.0.0)
```dart
// Old code example
```

##### After (vY.0.0)
```dart
// New code example
```

#### Common Issues and Solutions

##### Issue 1: Description
**Symptom**: What you'll see
**Cause**: Why it happens
**Solution**: How to fix it

---

## Migration Tools

### Version Compatibility Checker

Use this tool to check if your code is compatible with a new version:

```dart
import 'package:helix/core/api/api_version_router.dart';

void checkCompatibility() {
  final router = APIVersionRouter(logger: logger);

  // Check if a specific version is compatible
  final compatibility = router.checkVersionCompatibility(
    channelName: 'method.bluetooth',
    method: 'startScan',
    requestedVersion: '2.0.0', // Version you want to migrate to
  );

  if (compatibility.isCompatible) {
    print('✅ Compatible with version 2.0.0');
    if (compatibility.isDeprecated) {
      print('⚠️  Warning: ${compatibility.deprecationMessage}');
    }
  } else {
    print('❌ Not compatible: ${compatibility.errorMessage}');
    print('Migration guide: ${compatibility.migrationGuide}');
  }
}
```

### API Usage Scanner

Scan your codebase for deprecated API usage:

```dart
import 'package:helix/core/api/external_api_version_tracker.dart';

void scanDeprecatedAPIs() {
  final tracker = ExternalAPIVersionTracker(logger: logger);

  // Get all deprecated APIs in use
  final deprecatedAPIs = tracker.getDeprecatedAPIs();

  if (deprecatedAPIs.isEmpty) {
    print('✅ No deprecated APIs in use');
  } else {
    print('⚠️  Deprecated APIs in use:');
    for (final api in deprecatedAPIs) {
      print('  - ${api.provider}${api.endpoint}');
      print('    Days until sunset: ${api.daysUntilSunset}');
      print('    Usage: ${api.totalRequests} requests');
    }
  }

  // Get APIs nearing sunset (within 30 days)
  final nearingSunset = tracker.getAPIsNearingSunset(daysThreshold: 30);

  if (nearingSunset.isNotEmpty) {
    print('\n⚠️  APIs nearing sunset (30 days):');
    for (final api in nearingSunset) {
      print('  - ${api.provider}${api.endpoint}');
      print('    Sunset in: ${api.daysUntilSunset} days');
    }
  }
}
```

### Automated Migration Script Template

Create a script to help automate parts of your migration:

```bash
#!/bin/bash
# migration_helper.sh

echo "🔄 Starting API Migration Helper"

# 1. Backup current code
echo "📦 Creating backup..."
git stash save "pre-migration-backup"

# 2. Create migration branch
echo "🌿 Creating migration branch..."
git checkout -b migration/api-v1-to-v2

# 3. Search for deprecated API usage
echo "🔍 Scanning for deprecated APIs..."
grep -r "deprecatedMethod" lib/ || echo "No deprecated methods found"

# 4. Run tests to establish baseline
echo "🧪 Running baseline tests..."
flutter test > migration_baseline_tests.log

# 5. Update version constants
echo "📝 Ready to update version constants"
echo "Update APIVersionConfig in lib/core/api/api_version_config.dart"

echo "✅ Migration helper complete"
echo "Next steps:"
echo "  1. Review MIGRATION_GUIDES.md for your version"
echo "  2. Make required code changes"
echo "  3. Run tests: flutter test"
echo "  4. Test manually"
echo "  5. Commit changes"
```

### Testing Checklist

Use this checklist when testing your migration:

- [ ] All unit tests pass
- [ ] All integration tests pass
- [ ] Bluetooth scanning works
- [ ] Device connection works
- [ ] Speech recognition works
- [ ] AI analysis works
- [ ] Error handling works correctly
- [ ] Performance is acceptable
- [ ] No deprecation warnings (unless expected)
- [ ] Documentation is updated
- [ ] Migration guide is followed
- [ ] Rollback procedure is tested

---

## Example Migration Scenarios

### Scenario 1: Simple Parameter Addition

**Situation**: A new optional parameter is added to an existing method.

**Before (v1.0.0)**
```dart
await channel.invokeMethod('startScan');
```

**After (v1.1.0)**
```dart
// Still works with default behavior
await channel.invokeMethod('startScan');

// Or use new optional parameter
await channel.invokeMethod('startScan', {
  'timeout': 60000, // New optional parameter
});
```

**Migration Required**: ❌ No (backward compatible)
**Action**: Optional - adopt new parameter if desired

---

### Scenario 2: Method Signature Change (Breaking)

**Situation**: A method's required parameters change (hypothetical v2.0.0).

**Before (v1.0.0)**
```dart
await channel.invokeMethod('connectToGlasses', {
  'deviceName': 'G1_L_123',
});
```

**After (v2.0.0 - hypothetical)**
```dart
await channel.invokeMethod('connectToGlasses', {
  'deviceId': 'abc-123-def', // Changed from deviceName
  'timeout': 10000, // Now required
  'autoReconnect': true, // New required parameter
});
```

**Migration Required**: ✅ Yes
**Steps**:
1. Update all `connectToGlasses` calls
2. Replace `deviceName` with `deviceId`
3. Add `timeout` parameter
4. Add `autoReconnect` parameter
5. Test connection flow
6. Update error handling

---

### Scenario 3: Deprecated Method Replacement

**Situation**: An old method is deprecated and replaced with a new one.

**Before (v1.0.0)**
```dart
await channel.invokeMethod('startEvenAI', {
  'identifier': 'EN',
});
```

**After (v2.0.0 - hypothetical)**
```dart
// Old method deprecated, use new method
await channel.invokeMethod('startSpeechRecognition', {
  'language': 'en-US', // Changed parameter name and format
  'continuous': true, // New parameter
  'interimResults': true, // New parameter
});
```

**Migration Required**: ✅ Yes (before sunset)
**Steps**:
1. Find all uses of `startEvenAI`
2. Replace with `startSpeechRecognition`
3. Convert language identifier format
4. Add new required parameters
5. Test speech recognition
6. Remove old method calls before sunset date

---

### Scenario 4: Response Structure Change

**Situation**: The response structure changes (hypothetical v2.0.0).

**Before (v1.0.0)**
```dart
final result = await channel.invokeMethod('getDeviceInfo');
// Returns: { 'name': 'G1', 'battery': 85 }

final deviceName = result['name'];
final battery = result['battery'];
```

**After (v2.0.0 - hypothetical)**
```dart
final result = await channel.invokeMethod('getDeviceInfo');
// Returns: {
//   'device': { 'name': 'G1', 'id': 'abc-123' },
//   'status': { 'battery': 85, 'connected': true }
// }

final deviceName = result['device']['name'];
final battery = result['status']['battery'];
```

**Migration Required**: ✅ Yes
**Steps**:
1. Find all code parsing `getDeviceInfo` response
2. Update to use nested structure
3. Add null checks
4. Test all device info displays
5. Update type definitions if using typed models

---

## Migration Best Practices

### 1. Migrate Incrementally

Don't try to migrate everything at once. Break it down:

1. **Phase 1**: Update version constants and dependencies
2. **Phase 2**: Fix critical breaking changes
3. **Phase 3**: Adopt new features
4. **Phase 4**: Clean up deprecated code

### 2. Use Feature Flags

Control migration rollout with feature flags:

```dart
class FeatureFlags {
  static const bool useV2API = false; // Toggle for gradual rollout

  static String get apiVersion => useV2API ? '2.0.0' : '1.0.0';
}

// In your code
final channel = VersionedMethodChannel(
  name: 'method.bluetooth',
  version: FeatureFlags.apiVersion,
  router: router,
  logger: logger,
);
```

### 3. Maintain Compatibility Layer

For complex migrations, create a compatibility layer:

```dart
class BluetoothAPICompat {
  final String apiVersion;

  BluetoothAPICompat(this.apiVersion);

  Future<void> connect(String deviceIdentifier) async {
    if (apiVersion.startsWith('1.')) {
      // Use v1 API
      await channel.invokeMethod('connectToGlasses', {
        'deviceName': deviceIdentifier,
      });
    } else {
      // Use v2 API
      await channel.invokeMethod('connectToGlasses', {
        'deviceId': deviceIdentifier,
        'timeout': 10000,
        'autoReconnect': true,
      });
    }
  }
}
```

### 4. Document Everything

Keep detailed migration notes:

```dart
// MIGRATION NOTE (v1 → v2):
// Changed from deviceName to deviceId
// Added timeout and autoReconnect parameters
// See: /docs/api/MIGRATION_GUIDES.md#v1-to-v2

await channel.invokeMethod('connectToGlasses', {
  'deviceId': deviceId, // Was: deviceName in v1
  'timeout': 10000, // New in v2
  'autoReconnect': true, // New in v2
});
```

### 5. Test Thoroughly

Migration testing checklist:

- [ ] Unit tests for each changed component
- [ ] Integration tests for end-to-end flows
- [ ] Manual testing of UI flows
- [ ] Performance regression testing
- [ ] Error handling and edge cases
- [ ] Backward compatibility (if supporting multiple versions)
- [ ] Load testing for API changes
- [ ] User acceptance testing

---

## Getting Help

### Migration Support Resources

1. **Documentation**
   - [API Versioning Strategy](/docs/api/API_VERSIONING_STRATEGY.md)
   - [API Changelog](/docs/api/API_CHANGELOG.md)
   - [API Reference](/docs/api/API_REFERENCE.md)

2. **Code Examples**
   - Check `/examples` directory for working code
   - Review test files for usage patterns

3. **Community Support**
   - GitHub Discussions for questions
   - GitHub Issues for bugs
   - Stack Overflow (tag: helix-api)

4. **Professional Support**
   - Contact the development team for complex migrations
   - Request custom migration assistance

### Reporting Migration Issues

If you encounter issues during migration:

1. **Check Existing Issues**
   - Search GitHub issues for similar problems
   - Check closed issues for solutions

2. **Create Detailed Issue**
   Include:
   - Source version
   - Target version
   - Steps to reproduce
   - Expected vs actual behavior
   - Code snippets
   - Error messages
   - Migration guide section followed

3. **Provide Context**
   - Your use case
   - Impact on your application
   - Timeline constraints

### Migration Assistance

Need help with migration? We offer:

- **Migration Reviews**: Have your migration plan reviewed
- **Code Reviews**: Get feedback on your migration implementation
- **Pair Programming**: Schedule sessions with our team
- **Custom Tooling**: Request tools for complex migrations

---

## Appendix: Version History

### v1.0.0 (2025-11-16)
- Initial release
- No migrations needed

### Future Versions
Migration guides will be added as new major versions are released.

---

*Last Updated: 2025-11-16*
*Version: 1.0.0*
