// ABOUTME: Performance budget definitions and enforcement
// ABOUTME: Defines acceptable performance thresholds and monitors violations

import 'package:flutter/foundation.dart';
import '../utils/logging_service.dart';
import 'alert_manager.dart';
import 'observability_config.dart';

/// Budget category
enum BudgetCategory {
  latency,
  memory,
  cpu,
  network,
  storage,
  battery,
  frameRate,
}

/// Budget violation severity
enum ViolationSeverity {
  none,
  warning,
  critical,
  emergency,
}

/// Performance budget definition
class PerformanceBudget {
  final String id;
  final String name;
  final String description;
  final BudgetCategory category;
  final double warningThreshold;
  final double criticalThreshold;
  final String unit;
  final bool enabled;

  const PerformanceBudget({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.warningThreshold,
    required this.criticalThreshold,
    required this.unit,
    this.enabled = true,
  });

  /// Check if value violates budget
  ViolationSeverity checkViolation(double value) {
    if (!enabled) return ViolationSeverity.none;

    if (value >= criticalThreshold) {
      return ViolationSeverity.critical;
    } else if (value >= warningThreshold) {
      return ViolationSeverity.warning;
    }
    return ViolationSeverity.none;
  }

  /// Get percentage of budget used
  double getUsagePercentage(double value) {
    return (value / criticalThreshold) * 100;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'category': category.name,
    'warningThreshold': warningThreshold,
    'criticalThreshold': criticalThreshold,
    'unit': unit,
    'enabled': enabled,
  };
}

/// Budget violation record
class BudgetViolation {
  final String budgetId;
  final String budgetName;
  final BudgetCategory category;
  final double value;
  final double threshold;
  final ViolationSeverity severity;
  final DateTime timestamp;
  final String? context;

  BudgetViolation({
    required this.budgetId,
    required this.budgetName,
    required this.category,
    required this.value,
    required this.threshold,
    required this.severity,
    required this.timestamp,
    this.context,
  });

  Map<String, dynamic> toJson() => {
    'budgetId': budgetId,
    'budgetName': budgetName,
    'category': category.name,
    'value': value,
    'threshold': threshold,
    'severity': severity.name,
    'timestamp': timestamp.toIso8601String(),
    if (context != null) 'context': context,
  };
}

/// Performance budgets manager
class PerformanceBudgets {
  static final PerformanceBudgets _instance = PerformanceBudgets._();
  static PerformanceBudgets get instance => _instance;

  PerformanceBudgets._() {
    _initializeBudgets();
  }

  final Map<String, PerformanceBudget> _budgets = {};
  final List<BudgetViolation> _violations = [];
  bool _isEnabled = true;

  /// Initialize default performance budgets
  void _initializeBudgets() {
    // Latency budgets
    addBudget(const PerformanceBudget(
      id: 'api_response_time',
      name: 'API Response Time',
      description: 'Maximum acceptable API response time',
      category: BudgetCategory.latency,
      warningThreshold: 1000,
      criticalThreshold: 2000,
      unit: 'ms',
    ));

    addBudget(const PerformanceBudget(
      id: 'audio_latency',
      name: 'Audio Processing Latency',
      description: 'Maximum acceptable audio processing latency',
      category: BudgetCategory.latency,
      warningThreshold: 100,
      criticalThreshold: 200,
      unit: 'ms',
    ));

    addBudget(const PerformanceBudget(
      id: 'transcription_latency',
      name: 'Transcription Latency',
      description: 'Maximum acceptable transcription latency',
      category: BudgetCategory.latency,
      warningThreshold: 500,
      criticalThreshold: 1000,
      unit: 'ms',
    ));

    addBudget(const PerformanceBudget(
      id: 'ai_analysis_latency',
      name: 'AI Analysis Latency',
      description: 'Maximum acceptable AI analysis latency',
      category: BudgetCategory.latency,
      warningThreshold: 3000,
      criticalThreshold: 5000,
      unit: 'ms',
    ));

    addBudget(const PerformanceBudget(
      id: 'db_query_time',
      name: 'Database Query Time',
      description: 'Maximum acceptable database query time',
      category: BudgetCategory.latency,
      warningThreshold: 50,
      criticalThreshold: 100,
      unit: 'ms',
    ));

    // Memory budgets
    addBudget(const PerformanceBudget(
      id: 'app_memory_usage',
      name: 'App Memory Usage',
      description: 'Maximum acceptable app memory usage',
      category: BudgetCategory.memory,
      warningThreshold: 200,
      criticalThreshold: 400,
      unit: 'MB',
    ));

    addBudget(const PerformanceBudget(
      id: 'cache_memory_usage',
      name: 'Cache Memory Usage',
      description: 'Maximum acceptable cache memory usage',
      category: BudgetCategory.memory,
      warningThreshold: 50,
      criticalThreshold: 100,
      unit: 'MB',
    ));

    // CPU budgets
    addBudget(const PerformanceBudget(
      id: 'cpu_usage',
      name: 'CPU Usage',
      description: 'Maximum acceptable CPU usage',
      category: BudgetCategory.cpu,
      warningThreshold: 70,
      criticalThreshold: 90,
      unit: '%',
    ));

    addBudget(const PerformanceBudget(
      id: 'background_cpu_usage',
      name: 'Background CPU Usage',
      description: 'Maximum acceptable background CPU usage',
      category: BudgetCategory.cpu,
      warningThreshold: 30,
      criticalThreshold: 50,
      unit: '%',
    ));

    // Network budgets
    addBudget(const PerformanceBudget(
      id: 'request_payload_size',
      name: 'Request Payload Size',
      description: 'Maximum acceptable request payload size',
      category: BudgetCategory.network,
      warningThreshold: 1024,
      criticalThreshold: 5120,
      unit: 'KB',
    ));

    addBudget(const PerformanceBudget(
      id: 'response_payload_size',
      name: 'Response Payload Size',
      description: 'Maximum acceptable response payload size',
      category: BudgetCategory.network,
      warningThreshold: 2048,
      criticalThreshold: 10240,
      unit: 'KB',
    ));

    // Storage budgets
    addBudget(const PerformanceBudget(
      id: 'local_storage_size',
      name: 'Local Storage Size',
      description: 'Maximum acceptable local storage usage',
      category: BudgetCategory.storage,
      warningThreshold: 100,
      criticalThreshold: 200,
      unit: 'MB',
    ));

    // Frame rate budgets
    addBudget(const PerformanceBudget(
      id: 'ui_frame_rate',
      name: 'UI Frame Rate',
      description: 'Minimum acceptable UI frame rate (inverted - lower is worse)',
      category: BudgetCategory.frameRate,
      warningThreshold: 30,
      criticalThreshold: 20,
      unit: 'fps',
    ));

    LoggingService.instance.info(
      'PerformanceBudgets',
      'Initialized ${_budgets.length} performance budgets',
    );
  }

  /// Add a new performance budget
  void addBudget(PerformanceBudget budget) {
    _budgets[budget.id] = budget;
    LoggingService.instance.debug(
      'PerformanceBudgets',
      'Added budget: ${budget.name}',
      budget.toJson(),
    );
  }

  /// Remove a performance budget
  void removeBudget(String budgetId) {
    _budgets.remove(budgetId);
    LoggingService.instance.debug(
      'PerformanceBudgets',
      'Removed budget: $budgetId',
    );
  }

  /// Get a specific budget
  PerformanceBudget? getBudget(String budgetId) {
    return _budgets[budgetId];
  }

  /// Get all budgets
  List<PerformanceBudget> getAllBudgets() {
    return List.from(_budgets.values);
  }

  /// Get budgets by category
  List<PerformanceBudget> getBudgetsByCategory(BudgetCategory category) {
    return _budgets.values
        .where((b) => b.category == category)
        .toList();
  }

  /// Check value against budget
  ViolationSeverity checkBudget({
    required String budgetId,
    required double value,
    String? context,
  }) {
    if (!_isEnabled) return ViolationSeverity.none;

    final budget = _budgets[budgetId];
    if (budget == null) {
      LoggingService.instance.warning(
        'PerformanceBudgets',
        'Budget not found: $budgetId',
      );
      return ViolationSeverity.none;
    }

    final severity = budget.checkViolation(value);

    if (severity != ViolationSeverity.none) {
      _recordViolation(
        budget: budget,
        value: value,
        severity: severity,
        context: context,
      );
    }

    return severity;
  }

  /// Record a budget violation
  void _recordViolation({
    required PerformanceBudget budget,
    required double value,
    required ViolationSeverity severity,
    String? context,
  }) {
    final violation = BudgetViolation(
      budgetId: budget.id,
      budgetName: budget.name,
      category: budget.category,
      value: value,
      threshold: severity == ViolationSeverity.critical
          ? budget.criticalThreshold
          : budget.warningThreshold,
      severity: severity,
      timestamp: DateTime.now(),
      context: context,
    );

    _violations.add(violation);

    // Maintain violation history (keep last 200 violations)
    if (_violations.length > 200) {
      _violations.removeAt(0);
    }

    // Log violation
    final logLevel = severity == ViolationSeverity.critical ? 'error' : 'warning';
    LoggingService.instance.warning(
      'PerformanceBudgets',
      'Budget violation: ${budget.name} - $value${budget.unit} exceeds ${violation.threshold}${budget.unit}',
      violation.toJson(),
    );

    // Create alert
    if (severity == ViolationSeverity.critical) {
      AlertManager.instance.createAlert(
        type: _mapCategoryToAlertType(budget.category),
        severity: AlertSeverity.critical,
        message: 'Critical performance budget violation: ${budget.name}',
        details: {
          'budget': budget.name,
          'value': value,
          'threshold': violation.threshold,
          'unit': budget.unit,
          if (context != null) 'context': context,
        },
      );
    }
  }

  /// Map budget category to alert type
  AlertType _mapCategoryToAlertType(BudgetCategory category) {
    switch (category) {
      case BudgetCategory.latency:
        return AlertType.performanceLatency;
      case BudgetCategory.memory:
        return AlertType.performanceMemory;
      case BudgetCategory.cpu:
        return AlertType.performanceCpu;
      case BudgetCategory.network:
      case BudgetCategory.storage:
      case BudgetCategory.battery:
      case BudgetCategory.frameRate:
        return AlertType.performanceLatency;
    }
  }

  /// Get violations within a time window
  List<BudgetViolation> getViolations({
    Duration? timeWindow,
    BudgetCategory? category,
    ViolationSeverity? severity,
  }) {
    var filtered = _violations.toList();

    if (timeWindow != null) {
      final cutoff = DateTime.now().subtract(timeWindow);
      filtered = filtered.where((v) => v.timestamp.isAfter(cutoff)).toList();
    }

    if (category != null) {
      filtered = filtered.where((v) => v.category == category).toList();
    }

    if (severity != null) {
      filtered = filtered.where((v) => v.severity == severity).toList();
    }

    return filtered;
  }

  /// Get violation summary
  Map<String, dynamic> getViolationSummary({Duration? timeWindow}) {
    final violations = getViolations(timeWindow: timeWindow);

    final byCategoryCount = <String, int>{};
    final bySeverityCount = <String, int>{};

    for (final violation in violations) {
      byCategoryCount[violation.category.name] =
          (byCategoryCount[violation.category.name] ?? 0) + 1;
      bySeverityCount[violation.severity.name] =
          (bySeverityCount[violation.severity.name] ?? 0) + 1;
    }

    return {
      'totalViolations': violations.length,
      'timeWindow': timeWindow?.inMinutes ?? 'all',
      'byCategory': byCategoryCount,
      'bySeverity': bySeverityCount,
      'recentViolations': violations
          .take(10)
          .map((v) => v.toJson())
          .toList(),
    };
  }

  /// Get budget compliance report
  Map<String, dynamic> getComplianceReport() {
    final violations = getViolations(timeWindow: const Duration(hours: 24));
    final budgetViolationCounts = <String, int>{};

    for (final violation in violations) {
      budgetViolationCounts[violation.budgetId] =
          (budgetViolationCounts[violation.budgetId] ?? 0) + 1;
    }

    final budgetCompliance = <String, Map<String, dynamic>>{};
    for (final budget in _budgets.values) {
      final violationCount = budgetViolationCounts[budget.id] ?? 0;
      budgetCompliance[budget.id] = {
        'name': budget.name,
        'category': budget.category.name,
        'enabled': budget.enabled,
        'violations24h': violationCount,
        'compliant': violationCount == 0,
        'warningThreshold': budget.warningThreshold,
        'criticalThreshold': budget.criticalThreshold,
        'unit': budget.unit,
      };
    }

    final totalBudgets = _budgets.length;
    final compliantBudgets = budgetCompliance.values
        .where((b) => b['compliant'] == true)
        .length;

    return {
      'generatedAt': DateTime.now().toIso8601String(),
      'totalBudgets': totalBudgets,
      'compliantBudgets': compliantBudgets,
      'complianceRate': totalBudgets > 0
          ? ((compliantBudgets / totalBudgets) * 100).toStringAsFixed(2)
          : '0',
      'budgets': budgetCompliance.values.toList(),
      'violationSummary': getViolationSummary(
        timeWindow: const Duration(hours: 24),
      ),
    };
  }

  /// Generate full performance budgets report
  Map<String, dynamic> generateReport() {
    return {
      'generatedAt': DateTime.now().toIso8601String(),
      'enabled': _isEnabled,
      'totalBudgets': _budgets.length,
      'budgets': _budgets.values.map((b) => b.toJson()).toList(),
      'compliance': getComplianceReport(),
      'recentViolations': getViolations(
        timeWindow: const Duration(hours: 1),
      ).map((v) => v.toJson()).toList(),
    };
  }

  /// Clear violation history
  void clearViolations() {
    _violations.clear();
    LoggingService.instance.info('PerformanceBudgets', 'Violation history cleared');
  }

  /// Enable/disable budgets
  void setEnabled(bool enabled) {
    _isEnabled = enabled;
    LoggingService.instance.info(
      'PerformanceBudgets',
      'Performance budgets ${enabled ? 'enabled' : 'disabled'}',
    );
  }

  /// Get enabled status
  bool get isEnabled => _isEnabled;
}
