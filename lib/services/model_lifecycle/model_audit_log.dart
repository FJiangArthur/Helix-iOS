// ABOUTME: Audit logging system for model lifecycle events
// ABOUTME: Tracks all model operations, changes, and compliance events

import 'dart:async';
import 'dart:convert';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/utils/logging_service.dart';

part 'model_audit_log.freezed.dart';
part 'model_audit_log.g.dart';

/// Audit log for model lifecycle management
class ModelAuditLog {
  static const String _tag = 'ModelAuditLog';
  static const String _storageKey = 'model_audit_log_v1';
  static const int _maxLogEntries = 10000;

  final LoggingService _logger;
  final List<AuditLogEntry> _entries = [];

  /// Stream controller for audit events
  final _eventController = StreamController<AuditLogEntry>.broadcast();

  ModelAuditLog({required LoggingService logger}) : _logger = logger;

  /// Stream of audit events
  Stream<AuditLogEntry> get events => _eventController.stream;

  /// Initialize the audit log
  Future<void> initialize() async {
    try {
      _logger.log(_tag, 'Initializing audit log', LogLevel.info);
      await _loadFromStorage();
      _logger.log(_tag, 'Audit log initialized with ${_entries.length} entries',
          LogLevel.info);
    } catch (e) {
      _logger.log(_tag, 'Failed to initialize audit log: $e', LogLevel.error);
      rethrow;
    }
  }

  /// Log an audit event
  Future<void> logEvent({
    required AuditAction action,
    required String modelId,
    String? version,
    String? userId,
    Map<String, dynamic>? metadata,
    AuditSeverity severity = AuditSeverity.info,
  }) async {
    try {
      final entry = AuditLogEntry(
        id: _generateId(),
        timestamp: DateTime.now(),
        action: action,
        modelId: modelId,
        version: version,
        userId: userId ?? 'system',
        metadata: metadata ?? {},
        severity: severity,
      );

      _entries.add(entry);

      // Log to console
      _logger.log(
        _tag,
        'Audit: ${action.name} - $modelId${version != null ? ' v$version' : ''}',
        _mapSeverityToLogLevel(severity),
      );

      // Emit event
      _eventController.add(entry);

      // Persist
      await _saveToStorage();

      // Cleanup old entries if needed
      if (_entries.length > _maxLogEntries) {
        await _cleanupOldEntries();
      }
    } catch (e) {
      _logger.log(_tag, 'Failed to log audit event: $e', LogLevel.error);
    }
  }

  /// Get all audit entries
  List<AuditLogEntry> getAllEntries() {
    return List.unmodifiable(_entries);
  }

  /// Get entries for a specific model
  List<AuditLogEntry> getEntriesForModel(String modelId) {
    return _entries.where((e) => e.modelId == modelId).toList();
  }

  /// Get entries for a specific version
  List<AuditLogEntry> getEntriesForVersion(String modelId, String version) {
    return _entries
        .where((e) => e.modelId == modelId && e.version == version)
        .toList();
  }

  /// Get entries by action type
  List<AuditLogEntry> getEntriesByAction(AuditAction action) {
    return _entries.where((e) => e.action == action).toList();
  }

  /// Get entries by severity
  List<AuditLogEntry> getEntriesBySeverity(AuditSeverity severity) {
    return _entries.where((e) => e.severity == severity).toList();
  }

  /// Get entries in a time range
  List<AuditLogEntry> getEntriesInRange(DateTime start, DateTime end) {
    return _entries
        .where((e) => e.timestamp.isAfter(start) && e.timestamp.isBefore(end))
        .toList();
  }

  /// Get recent entries
  List<AuditLogEntry> getRecentEntries({int limit = 100}) {
    final sorted = List<AuditLogEntry>.from(_entries)
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return sorted.take(limit).toList();
  }

  /// Get critical/error entries
  List<AuditLogEntry> getCriticalEntries() {
    return _entries
        .where((e) =>
            e.severity == AuditSeverity.error ||
            e.severity == AuditSeverity.critical)
        .toList();
  }

  /// Get compliance report for a time period
  Future<ComplianceReport> generateComplianceReport({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final entries = getEntriesInRange(startDate, endDate);

    final actionCounts = <AuditAction, int>{};
    final severityCounts = <AuditSeverity, int>{};
    final modelActivity = <String, int>{};

    for (final entry in entries) {
      actionCounts[entry.action] = (actionCounts[entry.action] ?? 0) + 1;
      severityCounts[entry.severity] = (severityCounts[entry.severity] ?? 0) + 1;
      modelActivity[entry.modelId] = (modelActivity[entry.modelId] ?? 0) + 1;
    }

    return ComplianceReport(
      startDate: startDate,
      endDate: endDate,
      totalEvents: entries.length,
      actionCounts: actionCounts,
      severityCounts: severityCounts,
      modelActivity: modelActivity,
      criticalEvents: entries
          .where((e) => e.severity == AuditSeverity.critical)
          .length,
      errors: entries.where((e) => e.severity == AuditSeverity.error).length,
      generatedAt: DateTime.now(),
    );
  }

  /// Export audit log as JSON
  Future<String> exportAsJson({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    List<AuditLogEntry> entries;

    if (startDate != null && endDate != null) {
      entries = getEntriesInRange(startDate, endDate);
    } else {
      entries = _entries;
    }

    final data = {
      'exportedAt': DateTime.now().toIso8601String(),
      'totalEntries': entries.length,
      'startDate': startDate?.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
      'entries': entries.map((e) => e.toJson()).toList(),
    };

    return jsonEncode(data);
  }

  /// Clear all audit entries (use with caution)
  Future<void> clearAll() async {
    _logger.log(_tag, 'Clearing all audit entries', LogLevel.warning);

    await logEvent(
      action: AuditAction.auditLogCleared,
      modelId: 'system',
      severity: AuditSeverity.warning,
      metadata: {'clearedCount': _entries.length},
    );

    _entries.clear();
    await _saveToStorage();
  }

  // Private helper methods

  String _generateId() {
    return 'audit_${DateTime.now().millisecondsSinceEpoch}_${_entries.length}';
  }

  LogLevel _mapSeverityToLogLevel(AuditSeverity severity) {
    switch (severity) {
      case AuditSeverity.debug:
        return LogLevel.debug;
      case AuditSeverity.info:
        return LogLevel.info;
      case AuditSeverity.warning:
        return LogLevel.warning;
      case AuditSeverity.error:
        return LogLevel.error;
      case AuditSeverity.critical:
        return LogLevel.error;
    }
  }

  Future<void> _loadFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString(_storageKey);

      if (data != null) {
        final json = jsonDecode(data) as Map<String, dynamic>;
        final entriesData = json['entries'] as List?;

        if (entriesData != null) {
          _entries.clear();
          _entries.addAll(
            entriesData
                .map((e) => AuditLogEntry.fromJson(e as Map<String, dynamic>))
                .toList(),
          );
        }
      }
    } catch (e) {
      _logger.log(_tag, 'Failed to load from storage: $e', LogLevel.error);
    }
  }

  Future<void> _saveToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final data = {
        'entries': _entries.map((e) => e.toJson()).toList(),
        'updatedAt': DateTime.now().toIso8601String(),
      };

      await prefs.setString(_storageKey, jsonEncode(data));
    } catch (e) {
      _logger.log(_tag, 'Failed to save to storage: $e', LogLevel.error);
    }
  }

  Future<void> _cleanupOldEntries() async {
    _logger.log(_tag, 'Cleaning up old audit entries', LogLevel.info);

    // Keep only the most recent entries
    final sorted = List<AuditLogEntry>.from(_entries)
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    _entries.clear();
    _entries.addAll(sorted.take(_maxLogEntries));

    await _saveToStorage();
  }

  /// Dispose of resources
  Future<void> dispose() async {
    await _eventController.close();
  }
}

/// Audit log entry
@freezed
class AuditLogEntry with _$AuditLogEntry {
  const factory AuditLogEntry({
    required String id,
    required DateTime timestamp,
    required AuditAction action,
    required String modelId,
    String? version,
    required String userId,
    @Default({}) Map<String, dynamic> metadata,
    @Default(AuditSeverity.info) AuditSeverity severity,
  }) = _AuditLogEntry;

  factory AuditLogEntry.fromJson(Map<String, dynamic> json) =>
      _$AuditLogEntryFromJson(json);
}

/// Audit action types
enum AuditAction {
  // Version management
  versionRegistered,
  versionActivated,
  versionDeactivated,
  versionDeprecated,
  versionRetired,
  versionRolledBack,

  // Performance monitoring
  metricsUpdated,
  performanceThresholdViolation,
  qualityDegraded,

  // Configuration changes
  configurationUpdated,
  thresholdsChanged,

  // Lifecycle events
  modelDeployed,
  modelUndeployed,
  canaryDeployment,
  canaryPromotion,

  // Errors and incidents
  deploymentFailed,
  evaluationFailed,
  apiError,

  // System events
  auditLogCleared,
  registryInitialized,
  backupCreated,
}

/// Audit severity levels
enum AuditSeverity {
  debug,
  info,
  warning,
  error,
  critical,
}

/// Compliance report
class ComplianceReport {
  final DateTime startDate;
  final DateTime endDate;
  final int totalEvents;
  final Map<AuditAction, int> actionCounts;
  final Map<AuditSeverity, int> severityCounts;
  final Map<String, int> modelActivity;
  final int criticalEvents;
  final int errors;
  final DateTime generatedAt;

  ComplianceReport({
    required this.startDate,
    required this.endDate,
    required this.totalEvents,
    required this.actionCounts,
    required this.severityCounts,
    required this.modelActivity,
    required this.criticalEvents,
    required this.errors,
    required this.generatedAt,
  });

  Map<String, dynamic> toJson() => {
        'startDate': startDate.toIso8601String(),
        'endDate': endDate.toIso8601String(),
        'totalEvents': totalEvents,
        'actionCounts': actionCounts.map((k, v) => MapEntry(k.name, v)),
        'severityCounts': severityCounts.map((k, v) => MapEntry(k.name, v)),
        'modelActivity': modelActivity,
        'criticalEvents': criticalEvents,
        'errors': errors,
        'generatedAt': generatedAt.toIso8601String(),
      };
}
