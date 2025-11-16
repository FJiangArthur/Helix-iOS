// ABOUTME: API version routing and middleware for method channel calls
// ABOUTME: Handles version checking, deprecation warnings, and request routing

import 'package:flutter/services.dart';
import 'api_version_config.dart';
import '../utils/logging_service.dart';

/// API Version Router
///
/// Middleware layer for routing API calls to appropriate version handlers
/// and managing version compatibility
class APIVersionRouter {
  static const String _tag = 'APIVersionRouter';
  final LoggingService _logger;

  APIVersionRouter({required LoggingService logger}) : _logger = logger;

  /// Route a method channel call through version checking
  Future<dynamic> routeMethodCall({
    required String channelName,
    required String method,
    required String requestedVersion,
    required dynamic arguments,
    required Future<dynamic> Function(dynamic) handler,
  }) async {
    // Log the API call
    _logger.log(
      _tag,
      'API Call: $channelName.$method (v$requestedVersion)',
      LogLevel.debug,
    );

    // Check version compatibility
    final compatibility = checkVersionCompatibility(
      channelName: channelName,
      method: method,
      requestedVersion: requestedVersion,
    );

    if (!compatibility.isCompatible) {
      _logger.log(
        _tag,
        'Incompatible API version: $requestedVersion for $channelName.$method',
        LogLevel.error,
      );

      throw PlatformException(
        code: 'API_VERSION_INCOMPATIBLE',
        message: compatibility.errorMessage,
        details: {
          'requestedVersion': requestedVersion,
          'supportedVersions': compatibility.supportedVersions,
          'migrationGuide': compatibility.migrationGuide,
        },
      );
    }

    // Log deprecation warning if applicable
    if (compatibility.isDeprecated) {
      _logger.log(
        _tag,
        'DEPRECATION WARNING: $channelName.$method - ${compatibility.deprecationMessage}',
        LogLevel.warning,
      );
    }

    // Execute the handler
    try {
      final result = await handler(arguments);

      // Add version metadata to response
      if (result is Map<String, dynamic>) {
        result['_apiVersion'] = requestedVersion;
        result['_apiDeprecated'] = compatibility.isDeprecated;
        if (compatibility.isDeprecated) {
          result['_deprecationMessage'] = compatibility.deprecationMessage;
        }
      }

      return result;
    } catch (e) {
      _logger.log(
        _tag,
        'API call failed: $channelName.$method - $e',
        LogLevel.error,
      );
      rethrow;
    }
  }

  /// Check version compatibility for a method call
  VersionCompatibilityResult checkVersionCompatibility({
    required String channelName,
    required String method,
    required String requestedVersion,
  }) {
    // Find the method channel endpoint
    final endpoint = APIEndpointVersions.methodChannels.values.firstWhere(
      (e) => e.name == channelName,
      orElse: () => throw ArgumentError('Unknown channel: $channelName'),
    );

    // Find the specific method
    final apiMethod = endpoint.methods[method];
    if (apiMethod == null) {
      return VersionCompatibilityResult(
        isCompatible: false,
        errorMessage: 'Unknown method: $method',
      );
    }

    // Check if method is sunset
    if (!apiMethod.isSupported) {
      return VersionCompatibilityResult(
        isCompatible: false,
        errorMessage:
            'This API method has been sunset and is no longer available. '
            '${apiMethod.replacementMethod != null ? 'Use ${apiMethod.replacementMethod} instead.' : ''}',
        migrationGuide: apiMethod.migrationGuide,
      );
    }

    // Check version compatibility
    final isCompatible = VersionComparator.isCompatible(
      requestedVersion,
      apiMethod.version,
    );

    if (!isCompatible) {
      return VersionCompatibilityResult(
        isCompatible: false,
        errorMessage:
            'Requested version $requestedVersion is not compatible with method version ${apiMethod.version}',
        supportedVersions: [apiMethod.version],
      );
    }

    // Check for deprecation
    final isDeprecated = apiMethod.deprecated;
    final deprecationMessage = apiMethod.deprecationWarning;

    return VersionCompatibilityResult(
      isCompatible: true,
      isDeprecated: isDeprecated,
      deprecationMessage: deprecationMessage,
      currentVersion: apiMethod.version,
      replacementMethod: apiMethod.replacementMethod,
      migrationGuide: apiMethod.migrationGuide,
    );
  }

  /// Get API version information
  Map<String, dynamic> getVersionInfo() {
    return {
      'methodChannelVersion': APIVersionConfig.currentMethodChannelVersion,
      'eventChannelVersion': APIVersionConfig.currentEventChannelVersion,
      'openAIVersion': APIVersionConfig.currentOpenAIVersion,
      'anthropicVersion': APIVersionConfig.currentAnthropicVersion,
      'whisperVersion': APIVersionConfig.currentWhisperVersion,
      'supportedVersionRange': {
        'min': APIVersionConfig.minSupportedMethodChannelVersion,
        'max': APIVersionConfig.maxSupportedMethodChannelVersion,
      },
    };
  }

  /// List all available API endpoints with their versions
  Map<String, dynamic> listEndpoints() {
    final endpoints = <String, dynamic>{};

    // Method channels
    endpoints['methodChannels'] = APIEndpointVersions.methodChannels.map(
      (key, endpoint) => MapEntry(key, {
        'name': endpoint.name,
        'version': endpoint.version,
        'methods': endpoint.methods.map(
          (methodName, method) => MapEntry(methodName, {
            'version': method.version,
            'deprecated': method.deprecated,
            'deprecationDate': method.deprecationDate?.toIso8601String(),
            'sunsetDate': method.sunsetDate?.toIso8601String(),
            'replacementMethod': method.replacementMethod,
          }),
        ),
      }),
    );

    // Event channels
    endpoints['eventChannels'] = APIEndpointVersions.eventChannels.map(
      (key, endpoint) => MapEntry(key, {
        'name': endpoint.name,
        'version': endpoint.version,
        'deprecated': endpoint.deprecated,
        'deprecationDate': endpoint.deprecationDate?.toIso8601String(),
        'sunsetDate': endpoint.sunsetDate?.toIso8601String(),
      }),
    );

    // External APIs
    endpoints['externalAPIs'] = APIEndpointVersions.externalAPIs.map(
      (key, endpoint) => MapEntry(key, {
        'provider': endpoint.provider,
        'endpoint': endpoint.endpoint,
        'version': endpoint.version,
        'externalVersion': endpoint.externalVersion,
        'deprecated': endpoint.deprecated,
        'deprecationDate': endpoint.deprecationDate?.toIso8601String(),
        'sunsetDate': endpoint.sunsetDate?.toIso8601String(),
      }),
    );

    return endpoints;
  }
}

/// Version Compatibility Result
class VersionCompatibilityResult {
  final bool isCompatible;
  final bool isDeprecated;
  final String? deprecationMessage;
  final String? errorMessage;
  final String? currentVersion;
  final List<String>? supportedVersions;
  final String? replacementMethod;
  final String? migrationGuide;

  VersionCompatibilityResult({
    required this.isCompatible,
    this.isDeprecated = false,
    this.deprecationMessage,
    this.errorMessage,
    this.currentVersion,
    this.supportedVersions,
    this.replacementMethod,
    this.migrationGuide,
  });
}

/// Versioned Method Channel Wrapper
///
/// Wrapper around FlutterMethodChannel that adds automatic version handling
class VersionedMethodChannel {
  final MethodChannel _channel;
  final String _version;
  final APIVersionRouter _router;
  final LoggingService _logger;

  VersionedMethodChannel({
    required String name,
    required String version,
    required APIVersionRouter router,
    required LoggingService logger,
  })  : _channel = MethodChannel(name),
        _version = version,
        _router = router,
        _logger = logger;

  /// Invoke a method with automatic version checking
  Future<T?> invokeMethod<T>(String method, [dynamic arguments]) async {
    return await _router.routeMethodCall<T>(
      channelName: _channel.name,
      method: method,
      requestedVersion: _version,
      arguments: arguments,
      handler: (args) => _channel.invokeMethod<T>(method, args),
    );
  }

  /// Set method call handler with version checking
  void setMethodCallHandler(
    Future<dynamic> Function(MethodCall call) handler,
  ) {
    _channel.setMethodCallHandler((call) async {
      try {
        // Extract version from arguments if provided
        String version = _version;
        if (call.arguments is Map) {
          final args = call.arguments as Map;
          version = args['_apiVersion'] as String? ?? _version;
        }

        // Route through version checker
        return await _router.routeMethodCall(
          channelName: _channel.name,
          method: call.method,
          requestedVersion: version,
          arguments: call.arguments,
          handler: (_) => handler(call),
        );
      } catch (e) {
        _logger.log(
          'VersionedMethodChannel',
          'Method call handler error: $e',
          LogLevel.error,
        );
        rethrow;
      }
    });
  }

  /// Get the channel version
  String get version => _version;

  /// Get the channel name
  String get name => _channel.name;
}

/// Versioned Event Channel Wrapper
///
/// Wrapper around EventChannel that adds version metadata to events
class VersionedEventChannel {
  final EventChannel _channel;
  final String _version;
  final LoggingService _logger;

  VersionedEventChannel({
    required String name,
    required String version,
    required LoggingService logger,
  })  : _channel = EventChannel(name),
        _version = version,
        _logger = logger;

  /// Receive broadcast stream with version metadata
  Stream<dynamic> receiveBroadcastStream([dynamic arguments]) {
    return _channel.receiveBroadcastStream(arguments).map((event) {
      // Add version metadata to events
      if (event is Map<String, dynamic>) {
        event['_eventVersion'] = _version;
        event['_timestamp'] = DateTime.now().toIso8601String();
      }
      return event;
    });
  }

  /// Get the channel version
  String get version => _version;

  /// Get the channel name
  String get name => _channel.name;
}

/// API Version Middleware for HTTP Requests
///
/// Adds version headers and handles version negotiation for external APIs
class APIVersionMiddleware {
  static const String _tag = 'APIVersionMiddleware';
  final LoggingService _logger;

  APIVersionMiddleware({required LoggingService logger}) : _logger = logger;

  /// Add version headers to a request
  Map<String, String> addVersionHeaders({
    required String provider,
    required String endpoint,
    Map<String, String>? existingHeaders,
  }) {
    final headers = existingHeaders ?? {};

    // Find the external API endpoint
    final apiEndpoint = APIEndpointVersions.externalAPIs.values.firstWhere(
      (e) => e.provider == provider && e.endpoint == endpoint,
      orElse: () => throw ArgumentError(
        'Unknown external API: $provider$endpoint',
      ),
    );

    // Add version headers
    headers[APIVersionConfig.versionHeaderKey] = apiEndpoint.version;

    // Add deprecation headers if applicable
    if (apiEndpoint.deprecated) {
      headers[APIVersionConfig.deprecatedHeaderKey] = 'true';
      if (apiEndpoint.sunsetDate != null) {
        headers[APIVersionConfig.sunsetHeaderKey] =
            apiEndpoint.sunsetDate!.toIso8601String();
      }

      // Log deprecation warning
      _logger.log(
        _tag,
        'Using deprecated API: $provider$endpoint',
        LogLevel.warning,
      );
    }

    return headers;
  }

  /// Parse version from response headers
  String? parseVersionFromHeaders(Map<String, dynamic> headers) {
    return headers[APIVersionConfig.versionHeaderKey] as String?;
  }

  /// Check if API is deprecated from response headers
  bool isDeprecatedFromHeaders(Map<String, dynamic> headers) {
    final deprecated = headers[APIVersionConfig.deprecatedHeaderKey];
    return deprecated == 'true' || deprecated == true;
  }

  /// Get sunset date from response headers
  DateTime? getSunsetDateFromHeaders(Map<String, dynamic> headers) {
    final sunsetStr = headers[APIVersionConfig.sunsetHeaderKey] as String?;
    if (sunsetStr == null) return null;
    return DateTime.tryParse(sunsetStr);
  }
}
