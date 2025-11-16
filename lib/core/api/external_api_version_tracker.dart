// ABOUTME: Version tracking and management for external API providers (OpenAI, Anthropic)
// ABOUTME: Monitors API version changes, compatibility, and provides migration assistance

import 'dart:async';
import 'package:dio/dio.dart';
import 'api_version_config.dart';
import 'api_version_router.dart';
import '../utils/logging_service.dart';

/// External API Version Tracker
///
/// Tracks version compatibility and changes for external API providers
class ExternalAPIVersionTracker {
  static const String _tag = 'ExternalAPIVersionTracker';
  final LoggingService _logger;
  final APIVersionMiddleware _middleware;

  // Version tracking state
  final Map<String, APIVersionState> _versionStates = {};
  final Map<String, List<APIVersionEvent>> _versionHistory = {};

  ExternalAPIVersionTracker({
    required LoggingService logger,
  })  : _logger = logger,
        _middleware = APIVersionMiddleware(logger: logger);

  /// Track an API request
  Future<void> trackRequest({
    required String provider,
    required String endpoint,
    required Map<String, String> requestHeaders,
    Map<String, dynamic>? responseHeaders,
    int? statusCode,
    String? errorMessage,
  }) async {
    final key = '$provider:$endpoint';

    // Parse version information
    final requestVersion =
        requestHeaders[APIVersionConfig.versionHeaderKey] ?? 'unknown';
    final responseVersion = responseHeaders != null
        ? _middleware.parseVersionFromHeaders(responseHeaders)
        : null;
    final isDeprecated = responseHeaders != null
        ? _middleware.isDeprecatedFromHeaders(responseHeaders)
        : false;
    final sunsetDate = responseHeaders != null
        ? _middleware.getSunsetDateFromHeaders(responseHeaders)
        : null;

    // Update version state
    final state = _versionStates[key] ?? APIVersionState(
      provider: provider,
      endpoint: endpoint,
      currentVersion: requestVersion,
    );

    final updatedState = state.copyWith(
      lastRequestVersion: requestVersion,
      lastResponseVersion: responseVersion,
      isDeprecated: isDeprecated,
      sunsetDate: sunsetDate,
      lastRequestTime: DateTime.now(),
      totalRequests: state.totalRequests + 1,
      failedRequests: statusCode != null && statusCode >= 400
          ? state.failedRequests + 1
          : state.failedRequests,
      lastError: errorMessage,
    );

    _versionStates[key] = updatedState;

    // Log version change events
    if (responseVersion != null && responseVersion != state.lastResponseVersion) {
      _logVersionEvent(
        key: key,
        event: APIVersionEvent(
          timestamp: DateTime.now(),
          eventType: APIVersionEventType.versionChange,
          oldVersion: state.lastResponseVersion,
          newVersion: responseVersion,
          message: 'API version changed from ${state.lastResponseVersion} to $responseVersion',
        ),
      );
    }

    // Log deprecation events
    if (isDeprecated && !state.isDeprecated) {
      _logVersionEvent(
        key: key,
        event: APIVersionEvent(
          timestamp: DateTime.now(),
          eventType: APIVersionEventType.deprecationNotice,
          oldVersion: requestVersion,
          newVersion: responseVersion,
          message: 'API endpoint marked as deprecated',
          sunsetDate: sunsetDate,
        ),
      );

      _logger.log(
        _tag,
        'DEPRECATION NOTICE: $provider$endpoint is deprecated. Sunset date: $sunsetDate',
        LogLevel.warning,
      );
    }

    // Log errors
    if (errorMessage != null) {
      _logVersionEvent(
        key: key,
        event: APIVersionEvent(
          timestamp: DateTime.now(),
          eventType: APIVersionEventType.error,
          oldVersion: requestVersion,
          newVersion: responseVersion,
          message: 'API request failed: $errorMessage',
        ),
      );
    }
  }

  /// Get version state for a provider/endpoint
  APIVersionState? getVersionState(String provider, String endpoint) {
    return _versionStates['$provider:$endpoint'];
  }

  /// Get version history for a provider/endpoint
  List<APIVersionEvent> getVersionHistory(String provider, String endpoint) {
    return _versionHistory['$provider:$endpoint'] ?? [];
  }

  /// Get all version states
  Map<String, APIVersionState> getAllVersionStates() {
    return Map.unmodifiable(_versionStates);
  }

  /// Check for deprecated APIs in use
  List<APIVersionState> getDeprecatedAPIs() {
    return _versionStates.values.where((state) => state.isDeprecated).toList();
  }

  /// Check for APIs approaching sunset
  List<APIVersionState> getAPIsNearingSunset({int daysThreshold = 30}) {
    final threshold = DateTime.now().add(Duration(days: daysThreshold));
    return _versionStates.values
        .where((state) =>
            state.sunsetDate != null &&
            state.sunsetDate!.isBefore(threshold) &&
            state.sunsetDate!.isAfter(DateTime.now()))
        .toList();
  }

  /// Get API health summary
  Map<String, dynamic> getHealthSummary() {
    final total = _versionStates.length;
    final deprecated = getDeprecatedAPIs().length;
    final nearingSunset = getAPIsNearingSunset().length;
    final failing = _versionStates.values
        .where((state) => state.failureRate > 0.1) // >10% failure rate
        .length;

    return {
      'totalEndpoints': total,
      'deprecatedEndpoints': deprecated,
      'endpointsNearingSunset': nearingSunset,
      'failingEndpoints': failing,
      'healthScore': total > 0
          ? ((total - deprecated - failing) / total * 100).toStringAsFixed(2)
          : '100.00',
    };
  }

  /// Clear version history
  void clearHistory() {
    _versionHistory.clear();
    _logger.log(_tag, 'Version history cleared', LogLevel.info);
  }

  /// Log a version event
  void _logVersionEvent({
    required String key,
    required APIVersionEvent event,
  }) {
    if (!_versionHistory.containsKey(key)) {
      _versionHistory[key] = [];
    }
    _versionHistory[key]!.add(event);

    // Keep only last 100 events per endpoint
    if (_versionHistory[key]!.length > 100) {
      _versionHistory[key]!.removeAt(0);
    }

    // Log significant events
    if (event.eventType == APIVersionEventType.versionChange ||
        event.eventType == APIVersionEventType.deprecationNotice) {
      _logger.log(_tag, event.message, LogLevel.warning);
    }
  }
}

/// API Version State
class APIVersionState {
  final String provider;
  final String endpoint;
  final String currentVersion;
  final String? lastRequestVersion;
  final String? lastResponseVersion;
  final bool isDeprecated;
  final DateTime? sunsetDate;
  final DateTime? lastRequestTime;
  final int totalRequests;
  final int failedRequests;
  final String? lastError;

  APIVersionState({
    required this.provider,
    required this.endpoint,
    required this.currentVersion,
    this.lastRequestVersion,
    this.lastResponseVersion,
    this.isDeprecated = false,
    this.sunsetDate,
    this.lastRequestTime,
    this.totalRequests = 0,
    this.failedRequests = 0,
    this.lastError,
  });

  double get failureRate =>
      totalRequests > 0 ? failedRequests / totalRequests : 0.0;

  int? get daysUntilSunset => sunsetDate?.difference(DateTime.now()).inDays;

  bool get isSunset =>
      sunsetDate != null && DateTime.now().isAfter(sunsetDate!);

  APIVersionState copyWith({
    String? currentVersion,
    String? lastRequestVersion,
    String? lastResponseVersion,
    bool? isDeprecated,
    DateTime? sunsetDate,
    DateTime? lastRequestTime,
    int? totalRequests,
    int? failedRequests,
    String? lastError,
  }) {
    return APIVersionState(
      provider: provider,
      endpoint: endpoint,
      currentVersion: currentVersion ?? this.currentVersion,
      lastRequestVersion: lastRequestVersion ?? this.lastRequestVersion,
      lastResponseVersion: lastResponseVersion ?? this.lastResponseVersion,
      isDeprecated: isDeprecated ?? this.isDeprecated,
      sunsetDate: sunsetDate ?? this.sunsetDate,
      lastRequestTime: lastRequestTime ?? this.lastRequestTime,
      totalRequests: totalRequests ?? this.totalRequests,
      failedRequests: failedRequests ?? this.failedRequests,
      lastError: lastError ?? this.lastError,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'provider': provider,
      'endpoint': endpoint,
      'currentVersion': currentVersion,
      'lastRequestVersion': lastRequestVersion,
      'lastResponseVersion': lastResponseVersion,
      'isDeprecated': isDeprecated,
      'sunsetDate': sunsetDate?.toIso8601String(),
      'lastRequestTime': lastRequestTime?.toIso8601String(),
      'totalRequests': totalRequests,
      'failedRequests': failedRequests,
      'failureRate': failureRate,
      'daysUntilSunset': daysUntilSunset,
      'isSunset': isSunset,
      'lastError': lastError,
    };
  }
}

/// API Version Event
class APIVersionEvent {
  final DateTime timestamp;
  final APIVersionEventType eventType;
  final String? oldVersion;
  final String? newVersion;
  final String message;
  final DateTime? sunsetDate;

  APIVersionEvent({
    required this.timestamp,
    required this.eventType,
    this.oldVersion,
    this.newVersion,
    required this.message,
    this.sunsetDate,
  });

  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'eventType': eventType.toString(),
      'oldVersion': oldVersion,
      'newVersion': newVersion,
      'message': message,
      'sunsetDate': sunsetDate?.toIso8601String(),
    };
  }
}

/// API Version Event Types
enum APIVersionEventType {
  versionChange,
  deprecationNotice,
  sunsetNotice,
  error,
  compatibility,
  migration,
}

/// Dio Interceptor for Automatic Version Tracking
///
/// Automatically tracks version information for all Dio HTTP requests
class APIVersionInterceptor extends Interceptor {
  final ExternalAPIVersionTracker _tracker;
  final APIVersionMiddleware _middleware;
  final LoggingService _logger;

  APIVersionInterceptor({
    required ExternalAPIVersionTracker tracker,
    required LoggingService logger,
  })  : _tracker = tracker,
        _middleware = APIVersionMiddleware(logger: logger),
        _logger = logger;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    try {
      // Determine provider from base URL
      final provider = _getProviderFromUrl(options.baseUrl);
      final endpoint = options.path;

      if (provider != null) {
        // Add version headers
        final headers = _middleware.addVersionHeaders(
          provider: provider,
          endpoint: endpoint,
          existingHeaders: Map<String, String>.from(
            options.headers.map((k, v) => MapEntry(k.toString(), v.toString())),
          ),
        );

        options.headers.addAll(headers);
      }
    } catch (e) {
      _logger.log(
        'APIVersionInterceptor',
        'Failed to add version headers: $e',
        LogLevel.warning,
      );
    }

    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    try {
      final provider = _getProviderFromUrl(response.requestOptions.baseUrl);
      final endpoint = response.requestOptions.path;

      if (provider != null) {
        // Track the request
        _tracker.trackRequest(
          provider: provider,
          endpoint: endpoint,
          requestHeaders: Map<String, String>.from(
            response.requestOptions.headers
                .map((k, v) => MapEntry(k.toString(), v.toString())),
          ),
          responseHeaders: Map<String, dynamic>.from(response.headers.map),
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      _logger.log(
        'APIVersionInterceptor',
        'Failed to track API response: $e',
        LogLevel.warning,
      );
    }

    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    try {
      final provider = _getProviderFromUrl(err.requestOptions.baseUrl);
      final endpoint = err.requestOptions.path;

      if (provider != null) {
        // Track the failed request
        _tracker.trackRequest(
          provider: provider,
          endpoint: endpoint,
          requestHeaders: Map<String, String>.from(
            err.requestOptions.headers
                .map((k, v) => MapEntry(k.toString(), v.toString())),
          ),
          responseHeaders: err.response?.headers != null
              ? Map<String, dynamic>.from(err.response!.headers.map)
              : null,
          statusCode: err.response?.statusCode,
          errorMessage: err.message,
        );
      }
    } catch (e) {
      _logger.log(
        'APIVersionInterceptor',
        'Failed to track API error: $e',
        LogLevel.warning,
      );
    }

    handler.next(err);
  }

  String? _getProviderFromUrl(String baseUrl) {
    if (baseUrl.contains('openai.com')) return 'OpenAI';
    if (baseUrl.contains('anthropic.com')) return 'Anthropic';
    return null;
  }
}
