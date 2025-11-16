// ABOUTME: API versioning configuration and version management system
// ABOUTME: Defines versioning strategy, compatibility rules, and version routing

/// API Version Configuration
///
/// This class manages API versioning across the entire Helix application,
/// including both native method channels and external HTTP APIs.
///
/// Versioning follows Semantic Versioning (SemVer) principles:
/// - MAJOR version for incompatible API changes
/// - MINOR version for backwards-compatible functionality additions
/// - PATCH version for backwards-compatible bug fixes
class APIVersionConfig {
  // Current API Versions
  static const String currentMethodChannelVersion = '1.0.0';
  static const String currentEventChannelVersion = '1.0.0';
  static const String currentOpenAIVersion = '1.0.0';
  static const String currentAnthropicVersion = '1.0.0';
  static const String currentWhisperVersion = '1.0.0';

  // API Version Headers
  static const String versionHeaderKey = 'X-API-Version';
  static const String deprecatedHeaderKey = 'X-API-Deprecated';
  static const String sunsetHeaderKey = 'X-API-Sunset';

  // Supported Version Ranges
  static const String minSupportedMethodChannelVersion = '1.0.0';
  static const String maxSupportedMethodChannelVersion = '2.0.0';

  // Deprecation Timeline (in days)
  static const int deprecationNoticePeriod = 90; // 3 months
  static const int sunsetPeriod = 180; // 6 months after deprecation

  // Feature Flags by Version
  static const Map<String, Map<String, bool>> versionFeatures = {
    '1.0.0': {
      'bluetooth_scan': true,
      'bluetooth_connect': true,
      'speech_recognition': true,
      'ai_analysis': true,
      'fact_checking': true,
      'conversation_summary': true,
    },
    '1.1.0': {
      'bluetooth_scan': true,
      'bluetooth_connect': true,
      'speech_recognition': true,
      'ai_analysis': true,
      'fact_checking': true,
      'conversation_summary': true,
      'sentiment_analysis': true, // New in 1.1.0
      'action_items': true, // New in 1.1.0
    },
  };
}

/// API Endpoint Versioning
///
/// Defines version paths and routing for all API endpoints
class APIEndpointVersions {
  // Method Channel Endpoints (Flutter ↔ Native iOS)
  static const Map<String, MethodChannelEndpoint> methodChannels = {
    'bluetooth': MethodChannelEndpoint(
      name: 'method.bluetooth',
      version: '1.0.0',
      methods: {
        'startScan': APIMethod(version: '1.0.0', deprecated: false),
        'stopScan': APIMethod(version: '1.0.0', deprecated: false),
        'connectToGlasses': APIMethod(version: '1.0.0', deprecated: false),
        'disconnectFromGlasses': APIMethod(version: '1.0.0', deprecated: false),
        'send': APIMethod(version: '1.0.0', deprecated: false),
        'startEvenAI': APIMethod(version: '1.0.0', deprecated: false),
        'stopEvenAI': APIMethod(version: '1.0.0', deprecated: false),
      },
    ),
  };

  // Event Channel Endpoints (Native iOS → Flutter)
  static const Map<String, EventChannelEndpoint> eventChannels = {
    'bleReceive': EventChannelEndpoint(
      name: 'eventBleReceive',
      version: '1.0.0',
      deprecated: false,
    ),
    'speechRecognize': EventChannelEndpoint(
      name: 'eventSpeechRecognize',
      version: '1.0.0',
      deprecated: false,
    ),
  };

  // External API Endpoints
  static const Map<String, ExternalAPIEndpoint> externalAPIs = {
    'openai_chat': ExternalAPIEndpoint(
      provider: 'OpenAI',
      endpoint: '/chat/completions',
      version: '1.0.0',
      externalVersion: 'v1',
      deprecated: false,
    ),
    'openai_whisper': ExternalAPIEndpoint(
      provider: 'OpenAI',
      endpoint: '/audio/transcriptions',
      version: '1.0.0',
      externalVersion: 'v1',
      deprecated: false,
    ),
    'anthropic_messages': ExternalAPIEndpoint(
      provider: 'Anthropic',
      endpoint: '/messages',
      version: '1.0.0',
      externalVersion: '2023-06-01',
      deprecated: false,
    ),
  };
}

/// Method Channel Endpoint Definition
class MethodChannelEndpoint {
  final String name;
  final String version;
  final Map<String, APIMethod> methods;

  const MethodChannelEndpoint({
    required this.name,
    required this.version,
    required this.methods,
  });
}

/// Event Channel Endpoint Definition
class EventChannelEndpoint {
  final String name;
  final String version;
  final bool deprecated;
  final DateTime? deprecationDate;
  final DateTime? sunsetDate;

  const EventChannelEndpoint({
    required this.name,
    required this.version,
    required this.deprecated,
    this.deprecationDate,
    this.sunsetDate,
  });
}

/// External API Endpoint Definition
class ExternalAPIEndpoint {
  final String provider;
  final String endpoint;
  final String version; // Our internal version
  final String externalVersion; // Provider's API version
  final bool deprecated;
  final DateTime? deprecationDate;
  final DateTime? sunsetDate;

  const ExternalAPIEndpoint({
    required this.provider,
    required this.endpoint,
    required this.version,
    required this.externalVersion,
    required this.deprecated,
    this.deprecationDate,
    this.sunsetDate,
  });
}

/// API Method Definition
class APIMethod {
  final String version;
  final bool deprecated;
  final DateTime? deprecationDate;
  final DateTime? sunsetDate;
  final String? replacementMethod;
  final String? migrationGuide;

  const APIMethod({
    required this.version,
    required this.deprecated,
    this.deprecationDate,
    this.sunsetDate,
    this.replacementMethod,
    this.migrationGuide,
  });

  bool get isSupported {
    if (sunsetDate != null && DateTime.now().isAfter(sunsetDate!)) {
      return false;
    }
    return true;
  }

  String? get deprecationWarning {
    if (!deprecated) return null;

    final daysUntilSunset = sunsetDate?.difference(DateTime.now()).inDays;
    if (daysUntilSunset != null) {
      return 'This method is deprecated and will be removed in $daysUntilSunset days. '
          '${replacementMethod != null ? 'Use $replacementMethod instead.' : ''}';
    }
    return 'This method is deprecated. '
        '${replacementMethod != null ? 'Use $replacementMethod instead.' : ''}';
  }
}

/// Version Comparison Utilities
class VersionComparator {
  /// Parse a semantic version string into components
  static List<int> parse(String version) {
    final parts = version.split('.');
    return parts.map((p) => int.tryParse(p) ?? 0).toList();
  }

  /// Compare two version strings
  /// Returns: -1 if v1 < v2, 0 if v1 == v2, 1 if v1 > v2
  static int compare(String v1, String v2) {
    final parts1 = parse(v1);
    final parts2 = parse(v2);

    for (var i = 0; i < 3; i++) {
      final p1 = i < parts1.length ? parts1[i] : 0;
      final p2 = i < parts2.length ? parts2[i] : 0;

      if (p1 < p2) return -1;
      if (p1 > p2) return 1;
    }

    return 0;
  }

  /// Check if a version is compatible with a required version
  /// Compatible means: same major version, greater or equal minor/patch
  static bool isCompatible(String version, String requiredVersion) {
    final v = parse(version);
    final r = parse(requiredVersion);

    // Major version must match
    if (v[0] != r[0]) return false;

    // Minor version must be >= required
    if (v[1] < r[1]) return false;
    if (v[1] > r[1]) return true;

    // Patch version must be >= required
    return v[2] >= r[2];
  }

  /// Check if a version is within a supported range
  static bool isInRange(String version, String minVersion, String maxVersion) {
    return compare(version, minVersion) >= 0 &&
           compare(version, maxVersion) < 0;
  }

  /// Get the major version number
  static int getMajorVersion(String version) {
    return parse(version)[0];
  }

  /// Get the minor version number
  static int getMinorVersion(String version) {
    final parts = parse(version);
    return parts.length > 1 ? parts[1] : 0;
  }

  /// Get the patch version number
  static int getPatchVersion(String version) {
    final parts = parse(version);
    return parts.length > 2 ? parts[2] : 0;
  }

  /// Increment version for a breaking change
  static String incrementMajor(String version) {
    final parts = parse(version);
    return '${parts[0] + 1}.0.0';
  }

  /// Increment version for a new feature
  static String incrementMinor(String version) {
    final parts = parse(version);
    return '${parts[0]}.${parts[1] + 1}.0';
  }

  /// Increment version for a bug fix
  static String incrementPatch(String version) {
    final parts = parse(version);
    return '${parts[0]}.${parts[1]}.${parts[2] + 1}';
  }
}

/// Backward Compatibility Rules
///
/// Defines the rules for maintaining backward compatibility across versions
class BackwardCompatibilityRules {
  /// Rule 1: Major version changes break compatibility
  /// - Must provide migration guide
  /// - Require 6 months deprecation notice
  /// - Old version must be supported during transition period
  static const String majorVersionRule = '''
MAJOR VERSION CHANGES (x.0.0):
- Breaking changes are allowed
- Must increment major version number
- Requires 90-day deprecation notice
- Requires 180-day sunset period
- Must provide detailed migration guide
- Previous major version must remain supported during sunset period
  ''';

  /// Rule 2: Minor version changes must be backward compatible
  /// - Add new features without breaking existing ones
  /// - Extend APIs with optional parameters
  /// - New endpoints can be added
  static const String minorVersionRule = '''
MINOR VERSION CHANGES (x.y.0):
- Must be 100% backward compatible
- Can add new methods/endpoints
- Can add optional parameters to existing methods
- Cannot remove or rename existing methods
- Cannot change required parameters
- Cannot change response structure for existing calls
  ''';

  /// Rule 3: Patch version changes for bug fixes only
  /// - Fix bugs without changing behavior
  /// - No new features
  /// - No API changes
  static const String patchVersionRule = '''
PATCH VERSION CHANGES (x.y.z):
- Bug fixes only
- No new features
- No API changes
- Must maintain identical behavior for all valid inputs
- Can fix incorrect behavior or crashes
- Can improve performance without changing behavior
  ''';

  /// Rule 4: Deprecation Process
  /// - Announce deprecation 90 days before sunset
  /// - Provide clear migration path
  /// - Log warnings when deprecated APIs are used
  /// - Sunset after 180 days from deprecation announcement
  static const String deprecationProcess = '''
DEPRECATION PROCESS:
1. Announcement Phase (Day 0):
   - Announce deprecation publicly
   - Mark API as deprecated in code
   - Add deprecation warnings to logs
   - Provide migration guide

2. Deprecation Period (Days 1-90):
   - API remains fully functional
   - Warnings logged on each use
   - Migration guide available
   - New version available for testing

3. Sunset Warning Period (Days 91-180):
   - Escalated warnings
   - Reminder notifications
   - Final migration deadline approaching

4. Sunset (Day 180):
   - Deprecated API removed
   - Only new version supported
   - Automatic upgrade or failure for old clients
  ''';
}

/// API Deprecation Policy
class APIDeprecationPolicy {
  /// Check if a method is deprecated
  static bool isDeprecated(APIMethod method) {
    return method.deprecated;
  }

  /// Check if a method is sunset (no longer supported)
  static bool isSunset(APIMethod method) {
    return !method.isSupported;
  }

  /// Get deprecation warning message
  static String? getDeprecationWarning(APIMethod method) {
    return method.deprecationWarning;
  }

  /// Calculate days until sunset
  static int? daysUntilSunset(APIMethod method) {
    if (method.sunsetDate == null) return null;
    return method.sunsetDate!.difference(DateTime.now()).inDays;
  }

  /// Mark a method as deprecated
  static APIMethod markAsDeprecated(
    APIMethod method,
    String replacementMethod,
    String migrationGuide,
  ) {
    final now = DateTime.now();
    return APIMethod(
      version: method.version,
      deprecated: true,
      deprecationDate: now,
      sunsetDate: now.add(const Duration(
        days: APIVersionConfig.deprecationNoticePeriod +
              APIVersionConfig.sunsetPeriod,
      )),
      replacementMethod: replacementMethod,
      migrationGuide: migrationGuide,
    );
  }
}
