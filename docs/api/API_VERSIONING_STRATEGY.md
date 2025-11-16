# Helix API Versioning Strategy

## Table of Contents

1. [Overview](#overview)
2. [Versioning Principles](#versioning-principles)
3. [Version Numbering Scheme](#version-numbering-scheme)
4. [API Types and Versioning](#api-types-and-versioning)
5. [Backward Compatibility Rules](#backward-compatibility-rules)
6. [Deprecation Policy](#deprecation-policy)
7. [Version Routing](#version-routing)
8. [Implementation Details](#implementation-details)
9. [Best Practices](#best-practices)
10. [FAQ](#faq)

---

## Overview

The Helix API Versioning Strategy provides a comprehensive framework for managing API changes while maintaining stability and reliability for developers. This strategy applies to:

- **Method Channel APIs**: Flutter-to-Native iOS communication
- **Event Channel APIs**: Native iOS-to-Flutter communication
- **External HTTP APIs**: OpenAI and Anthropic integrations

### Goals

1. **Stability**: Ensure existing integrations continue to work
2. **Flexibility**: Allow evolution and improvement of APIs
3. **Clarity**: Make version changes transparent and predictable
4. **Migration Support**: Provide clear paths for upgrading

---

## Versioning Principles

### 1. Semantic Versioning

We follow [Semantic Versioning 2.0.0](https://semver.org/) with the format `MAJOR.MINOR.PATCH`:

```
MAJOR.MINOR.PATCH
  │     │     │
  │     │     └─── Bug fixes (backward compatible)
  │     └───────── New features (backward compatible)
  └─────────────── Breaking changes (not backward compatible)
```

### 2. Explicit Versioning

All API calls must include version information:

- **Method Channels**: Version passed in arguments or maintained by wrapper
- **Event Channels**: Version included in event metadata
- **HTTP APIs**: Version sent via `X-API-Version` header

### 3. Version Negotiation

The system automatically:
- Validates requested versions
- Warns about deprecated versions
- Rejects unsupported versions
- Provides upgrade guidance

### 4. Graceful Degradation

When possible:
- Support multiple versions simultaneously
- Provide clear error messages for incompatible versions
- Offer automatic migration assistance

---

## Version Numbering Scheme

### Major Version (x.0.0)

**When to increment:**
- Breaking API changes
- Removal of deprecated features
- Fundamental architecture changes
- Incompatible data structure changes

**Requirements:**
- 90-day deprecation notice
- 180-day sunset period
- Comprehensive migration guide
- Side-by-side version support during transition

**Examples:**
```dart
// v1.0.0 → v2.0.0: Method signature changed
// Old
await channel.invokeMethod('connectToGlasses', deviceName);

// New
await channel.invokeMethod('connectToGlasses', {
  'deviceName': deviceName,
  'timeout': 10000,
  'autoReconnect': true,
});
```

### Minor Version (x.y.0)

**When to increment:**
- New backward-compatible features
- New optional parameters
- New API endpoints/methods
- Extended functionality

**Requirements:**
- Must be 100% backward compatible
- Existing code continues to work unchanged
- New features are opt-in

**Examples:**
```dart
// v1.0.0 → v1.1.0: Added optional parameter
await channel.invokeMethod('startScan', {
  'timeout': 30000, // NEW: Optional timeout
});

// v1.0.0 → v1.1.0: Added new method
await channel.invokeMethod('getDeviceBatteryLevel'); // NEW
```

### Patch Version (x.y.z)

**When to increment:**
- Bug fixes
- Performance improvements
- Documentation updates
- Internal refactoring

**Requirements:**
- No API changes
- No new features
- Identical behavior for all valid inputs

**Examples:**
```dart
// v1.0.0 → v1.0.1: Fixed connection timeout bug
// API unchanged, behavior improved
await channel.invokeMethod('connectToGlasses', deviceName);
```

---

## API Types and Versioning

### Method Channel APIs

Method channels enable Flutter-to-Native iOS communication.

#### Version Specification

```dart
// Using VersionedMethodChannel wrapper
final bluetoothChannel = VersionedMethodChannel(
  name: 'method.bluetooth',
  version: '1.0.0',
  router: apiRouter,
  logger: logger,
);

// Invoke method with automatic version checking
final result = await bluetoothChannel.invokeMethod('startScan');
```

#### Version Headers

```dart
// Manual version specification
await channel.invokeMethod('startScan', {
  '_apiVersion': '1.0.0',
  // ... other parameters
});
```

### Event Channel APIs

Event channels enable Native iOS-to-Flutter communication.

#### Version Metadata

```dart
// Using VersionedEventChannel wrapper
final bleReceive = VersionedEventChannel(
  name: 'eventBleReceive',
  version: '1.0.0',
  logger: logger,
);

// Events automatically include version metadata
bleReceive.receiveBroadcastStream().listen((event) {
  print('Event version: ${event['_eventVersion']}');
  print('Timestamp: ${event['_timestamp']}');
  // ... handle event data
});
```

### External HTTP APIs

External APIs (OpenAI, Anthropic) use HTTP headers for versioning.

#### Version Headers

```dart
// Automatic version headers via middleware
final headers = middleware.addVersionHeaders(
  provider: 'OpenAI',
  endpoint: '/chat/completions',
);

// Result:
// {
//   'X-API-Version': '1.0.0',
//   'Content-Type': 'application/json',
//   'Authorization': 'Bearer ...'
// }
```

#### Version Tracking

```dart
// Automatic tracking via Dio interceptor
final dio = Dio();
dio.interceptors.add(APIVersionInterceptor(
  tracker: versionTracker,
  logger: logger,
));

// All requests are automatically tracked
final response = await dio.post('/chat/completions', data: {...});
```

---

## Backward Compatibility Rules

### Rule 1: Major Version Breaking Changes

Breaking changes are **ONLY** allowed in major version updates.

#### Allowed in Major Updates:
✅ Removing deprecated methods
✅ Changing required parameters
✅ Modifying response structures
✅ Renaming methods or endpoints
✅ Changing default behavior

#### Never Allowed:
❌ Breaking changes in minor/patch versions
❌ Removing features without deprecation
❌ Silent behavior changes

### Rule 2: Minor Version Additions

Minor versions must be **100% backward compatible**.

#### Allowed in Minor Updates:
✅ Adding new methods/endpoints
✅ Adding optional parameters
✅ Extending response data (new fields)
✅ Adding new event types
✅ Improving performance

#### Not Allowed:
❌ Changing existing method signatures
❌ Removing any functionality
❌ Making optional parameters required
❌ Changing error codes

### Rule 3: Patch Version Fixes

Patch versions are for **bug fixes only**.

#### Allowed in Patch Updates:
✅ Fixing crashes or errors
✅ Correcting incorrect behavior
✅ Performance improvements
✅ Documentation fixes
✅ Internal refactoring

#### Not Allowed:
❌ Any API changes
❌ New features
❌ Behavior changes (even improvements)

### Rule 4: Deprecation Process

All breaking changes must follow the deprecation process.

#### Timeline:
1. **Day 0**: Announce deprecation
   - Mark API as deprecated
   - Add warning logs
   - Publish migration guide

2. **Days 1-90**: Deprecation period
   - API fully functional
   - Warnings on each use
   - New version available

3. **Days 91-180**: Sunset warning
   - Escalated warnings
   - Countdown to sunset
   - Migration assistance

4. **Day 180**: Sunset
   - Remove deprecated API
   - Return error for old version
   - Only new version supported

---

## Deprecation Policy

### Marking APIs as Deprecated

```dart
// In api_version_config.dart
const APIMethod(
  version: '1.0.0',
  deprecated: true,
  deprecationDate: DateTime(2025, 11, 16),
  sunsetDate: DateTime(2026, 5, 15), // 180 days later
  replacementMethod: 'connectToDevice',
  migrationGuide: '/docs/api/migrations/v1-to-v2.md',
);
```

### Deprecation Warnings

Automatic warnings are logged when deprecated APIs are used:

```
[WARNING] API Deprecation: method.bluetooth.connectToGlasses
This method is deprecated and will be removed in 134 days.
Use connectToDevice instead.
Migration guide: /docs/api/migrations/v1-to-v2.md
```

### Monitoring Deprecated APIs

```dart
// Get list of deprecated APIs in use
final tracker = ExternalAPIVersionTracker(logger: logger);
final deprecatedAPIs = tracker.getDeprecatedAPIs();

// Get APIs nearing sunset (within 30 days)
final nearingSunset = tracker.getAPIsNearingSunset(daysThreshold: 30);

// Get API health summary
final health = tracker.getHealthSummary();
print('Deprecated endpoints: ${health['deprecatedEndpoints']}');
print('Health score: ${health['healthScore']}%');
```

---

## Version Routing

### Method Channel Version Routing

The `APIVersionRouter` handles all version checking and routing:

```dart
// Initialize router
final router = APIVersionRouter(logger: logger);

// Route method call through version checking
final result = await router.routeMethodCall(
  channelName: 'method.bluetooth',
  method: 'startScan',
  requestedVersion: '1.0.0',
  arguments: arguments,
  handler: (args) => actualImplementation(args),
);
```

### Version Compatibility Checking

```dart
// Check if version is compatible
final compatibility = router.checkVersionCompatibility(
  channelName: 'method.bluetooth',
  method: 'startScan',
  requestedVersion: '1.0.0',
);

if (compatibility.isCompatible) {
  // Proceed with API call
  if (compatibility.isDeprecated) {
    print('Warning: ${compatibility.deprecationMessage}');
  }
} else {
  // Handle incompatible version
  print('Error: ${compatibility.errorMessage}');
  print('Migration: ${compatibility.migrationGuide}');
}
```

### Version Comparison

```dart
// Compare versions
final result = VersionComparator.compare('1.2.3', '1.1.0');
// Returns: 1 (v1.2.3 is newer)

// Check compatibility
final compatible = VersionComparator.isCompatible('1.2.3', '1.0.0');
// Returns: true (same major version, newer minor)

// Check if in range
final inRange = VersionComparator.isInRange('1.5.0', '1.0.0', '2.0.0');
// Returns: true
```

---

## Implementation Details

### File Structure

```
lib/core/api/
├── api_version_config.dart          # Version configuration
├── api_version_router.dart          # Version routing middleware
└── external_api_version_tracker.dart # External API tracking

docs/api/
├── API_VERSIONING_STRATEGY.md       # This document
├── API_CHANGELOG.md                 # Version changelog
├── MIGRATION_GUIDES.md              # Migration guides
└── API_REFERENCE.md                 # API reference
```

### Key Components

#### 1. APIVersionConfig
Defines all version numbers, supported ranges, and feature flags.

```dart
class APIVersionConfig {
  static const String currentMethodChannelVersion = '1.0.0';
  static const String minSupportedMethodChannelVersion = '1.0.0';
  static const String maxSupportedMethodChannelVersion = '2.0.0';
  // ...
}
```

#### 2. APIVersionRouter
Routes API calls through version checking and validation.

```dart
class APIVersionRouter {
  Future<dynamic> routeMethodCall({...});
  VersionCompatibilityResult checkVersionCompatibility({...});
  Map<String, dynamic> getVersionInfo();
  Map<String, dynamic> listEndpoints();
}
```

#### 3. VersionedMethodChannel
Wrapper around Flutter MethodChannel with automatic versioning.

```dart
class VersionedMethodChannel {
  Future<T?> invokeMethod<T>(String method, [dynamic arguments]);
  void setMethodCallHandler(Future<dynamic> Function(MethodCall) handler);
}
```

#### 4. ExternalAPIVersionTracker
Tracks version changes and compatibility for external APIs.

```dart
class ExternalAPIVersionTracker {
  Future<void> trackRequest({...});
  APIVersionState? getVersionState(String provider, String endpoint);
  List<APIVersionState> getDeprecatedAPIs();
  Map<String, dynamic> getHealthSummary();
}
```

### Integration Examples

#### Using VersionedMethodChannel

```dart
// Initialize versioned channel
final bluetoothChannel = VersionedMethodChannel(
  name: 'method.bluetooth',
  version: APIVersionConfig.currentMethodChannelVersion,
  router: serviceLocator<APIVersionRouter>(),
  logger: serviceLocator<LoggingService>(),
);

// Use like regular method channel
try {
  final result = await bluetoothChannel.invokeMethod('startScan');
  print('Scan started: $result');
} on PlatformException catch (e) {
  if (e.code == 'API_VERSION_INCOMPATIBLE') {
    print('Version error: ${e.message}');
    print('Migration guide: ${e.details['migrationGuide']}');
  }
}
```

#### Using APIVersionInterceptor

```dart
// Add interceptor to Dio
final dio = Dio();
final tracker = ExternalAPIVersionTracker(logger: logger);

dio.interceptors.add(APIVersionInterceptor(
  tracker: tracker,
  logger: logger,
));

// Make requests - versioning is automatic
final response = await dio.post(
  '/chat/completions',
  data: {...},
);

// Check for deprecation warnings
final state = tracker.getVersionState('OpenAI', '/chat/completions');
if (state?.isDeprecated ?? false) {
  print('Warning: This API is deprecated');
  print('Days until sunset: ${state?.daysUntilSunset}');
}
```

---

## Best Practices

### For API Developers

#### 1. Plan for Change
```dart
// ✅ Good: Extensible design
class ConnectionParams {
  final String deviceName;
  final int? timeout;
  final bool? autoReconnect;

  ConnectionParams({
    required this.deviceName,
    this.timeout,
    this.autoReconnect,
  });
}

// ❌ Bad: Rigid design
void connect(String deviceName) { }
```

#### 2. Use Optional Parameters
```dart
// ✅ Good: New features are optional
Future<void> startScan({
  int? timeout,
  List<String>? deviceTypes, // New in v1.1
}) async { }

// ❌ Bad: Required parameters break compatibility
Future<void> startScan({
  required int timeout, // Breaking change!
}) async { }
```

#### 3. Extend, Don't Replace
```dart
// ✅ Good: Add new fields to responses
{
  'status': 'connected',
  'deviceName': 'G1_L_123',
  'batteryLevel': 85, // New in v1.1
  'firmwareVersion': '2.0', // New in v1.1
}

// ❌ Bad: Remove or rename fields
{
  'connectionStatus': 'connected', // Renamed!
  'name': 'G1_L_123', // Renamed!
}
```

#### 4. Provide Clear Error Messages
```dart
// ✅ Good: Helpful error message
throw PlatformException(
  code: 'API_VERSION_INCOMPATIBLE',
  message: 'API version 0.9.0 is not supported. '
          'Minimum version: 1.0.0. '
          'Please upgrade to the latest SDK.',
  details: {
    'currentVersion': '0.9.0',
    'minimumVersion': '1.0.0',
    'migrationGuide': 'https://docs.helix/migration',
  },
);

// ❌ Bad: Vague error
throw Exception('Version error');
```

### For API Consumers

#### 1. Always Specify Version
```dart
// ✅ Good: Explicit version
final channel = VersionedMethodChannel(
  name: 'method.bluetooth',
  version: '1.0.0',
  router: router,
  logger: logger,
);

// ❌ Bad: Implicit/default version
final channel = MethodChannel('method.bluetooth');
```

#### 2. Handle Deprecation Warnings
```dart
// ✅ Good: Monitor and respond to deprecation
final result = await channel.invokeMethod('startScan');
if (result['_apiDeprecated'] == true) {
  logger.warning('API deprecated: ${result['_deprecationMessage']}');
  // Plan migration
}

// ❌ Bad: Ignore warnings
final result = await channel.invokeMethod('startScan');
// Continue using deprecated API without planning
```

#### 3. Monitor API Health
```dart
// ✅ Good: Regular health checks
void checkAPIHealth() {
  final health = tracker.getHealthSummary();
  final deprecatedAPIs = tracker.getDeprecatedAPIs();
  final nearingSunset = tracker.getAPIsNearingSunset(daysThreshold: 30);

  if (nearingSunset.isNotEmpty) {
    // Alert: APIs will be sunset soon!
    for (final api in nearingSunset) {
      print('Warning: ${api.provider}${api.endpoint} '
            'sunsets in ${api.daysUntilSunset} days');
    }
  }
}

// ❌ Bad: No monitoring
// Just hope everything keeps working
```

#### 4. Test Version Upgrades
```dart
// ✅ Good: Test with new version before deploying
void testNewVersion() async {
  final testChannel = VersionedMethodChannel(
    name: 'method.bluetooth',
    version: '2.0.0', // Test new version
    router: router,
    logger: logger,
  );

  // Run integration tests
  await testBluetoothScanning();
  await testDeviceConnection();
  // ...
}

// ❌ Bad: Upgrade production without testing
// Hope for the best
```

---

## FAQ

### Q: How do I know which version to use?

**A:** Always use the latest stable version specified in `APIVersionConfig.currentMethodChannelVersion` or the specific API version constant. Check the [API Changelog](/docs/api/API_CHANGELOG.md) for the latest version.

### Q: What happens if I use a deprecated API?

**A:** The API will continue to work, but you'll receive deprecation warnings in logs. You should plan to migrate before the sunset date.

### Q: Can I use multiple API versions simultaneously?

**A:** Yes, during transition periods you can use different versions for different parts of your app. However, we recommend migrating all code to the same version for consistency.

### Q: How do I migrate from v1 to v2?

**A:** Follow the detailed migration guide at [/docs/api/MIGRATION_GUIDES.md](/docs/api/MIGRATION_GUIDES.md). It includes step-by-step instructions, code examples, and common pitfalls.

### Q: What if my requested version is not supported?

**A:** You'll receive a `PlatformException` with code `API_VERSION_INCOMPATIBLE`. The error details include the supported version range and migration guide.

### Q: How often are new API versions released?

**A:**
- **Patch versions**: As needed for bug fixes
- **Minor versions**: Quarterly or as features are ready
- **Major versions**: Annually or for significant breaking changes

### Q: What's the support timeline for each version?

**A:** Each major version is supported for at least 6 months after the next major version is released. See the [API Changelog](/docs/api/API_CHANGELOG.md) for specific dates.

### Q: How do I report API version issues?

**A:** Create a GitHub issue with:
- Current API version
- Expected behavior
- Actual behavior
- Steps to reproduce

### Q: Can I request a new API feature?

**A:** Yes! Submit a feature request on GitHub or contribute a pull request following our contribution guidelines.

### Q: How are external API versions managed?

**A:** External APIs (OpenAI, Anthropic) have their own versioning. We track their versions separately and provide a compatibility layer. Check `ExternalAPIVersionTracker` for current status.

---

## Related Documentation

- [API Changelog](/docs/api/API_CHANGELOG.md) - Detailed version history
- [Migration Guides](/docs/api/MIGRATION_GUIDES.md) - Step-by-step migration instructions
- [API Reference](/docs/api/API_REFERENCE.md) - Complete API documentation
- [Contributing Guide](/CONTRIBUTING.md) - How to contribute to the API

---

## Feedback and Improvements

This versioning strategy is continuously evolving. We welcome feedback and suggestions:

- **GitHub Issues**: For bugs or specific problems
- **Pull Requests**: For improvements to this document
- **Discussions**: For general feedback and ideas

---

*Last Updated: 2025-11-16*
*Version: 1.0.0*
