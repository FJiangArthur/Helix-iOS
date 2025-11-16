# Health Check Implementation Guide

## Overview

This guide explains how to implement health checks for new services in the Helix application.

## Prerequisites

- Understanding of the service being monitored
- Knowledge of service dependencies
- Familiarity with health check concepts (liveness, readiness)

## Implementation Steps

### Step 1: Create Service Health Checker

Create a new file in `lib/core/health/implementations/`:

```dart
// lib/core/health/implementations/my_service_health.dart

import 'dart:async';
import '../health_check_models.dart';
import '../service_health_checker.dart';
import '../../../services/my_service.dart';
import '../../utils/logging_service.dart';

/// Health checker for My Service
class MyServiceHealth implements ServiceHealthChecker {
  static const String _tag = 'MyServiceHealth';

  final MyService _service;

  MyServiceHealth(this._service);

  @override
  String get serviceName => 'MyService';

  @override
  String get version => '1.0.0';

  @override
  List<String> get dependencies => ['DependencyService'];

  @override
  Map<String, dynamic> get metadata => {
    'status': _service.status,
    'isInitialized': _service.isInitialized,
  };

  @override
  Future<LivenessProbe> checkLiveness() async {
    try {
      // Check if service is alive
      // This should be a quick check - does the service exist and respond?

      final isAlive = _service.isRunning;

      return LivenessProbe(
        isAlive: isAlive,
        message: isAlive
            ? 'Service is alive'
            : 'Service is not running',
        timestamp: DateTime.now(),
      );
    } catch (e) {
      LoggingService.instance.log(
        _tag,
        'Liveness check failed: $e',
        LogLevel.error,
      );

      return LivenessProbe(
        isAlive: false,
        message: 'Liveness check failed: $e',
        timestamp: DateTime.now(),
      );
    }
  }

  @override
  Future<ReadinessProbe> checkReadiness() async {
    final blockers = <String>[];

    try {
      // Check if service is ready to handle requests
      // Add all conditions that must be met for readiness

      if (!_service.isInitialized) {
        blockers.add('Service not initialized');
      }

      if (!_service.hasRequiredResources()) {
        blockers.add('Required resources not available');
      }

      // Check dependencies
      for (final dep in dependencies) {
        if (!_service.isDependencyReady(dep)) {
          blockers.add('Dependency $dep not ready');
        }
      }

      final isReady = blockers.isEmpty;

      return ReadinessProbe(
        isReady: isReady,
        message: isReady
            ? 'Service is ready'
            : 'Service not ready: ${blockers.join(", ")}',
        blockers: blockers,
        timestamp: DateTime.now(),
      );
    } catch (e) {
      LoggingService.instance.log(
        _tag,
        'Readiness check failed: $e',
        LogLevel.error,
      );

      return ReadinessProbe(
        isReady: false,
        message: 'Readiness check failed: $e',
        blockers: ['Exception during readiness check: $e'],
        timestamp: DateTime.now(),
      );
    }
  }

  @override
  Future<HealthCheckResult> checkHealth() async {
    final startTime = DateTime.now();

    try {
      final liveness = await checkLiveness();
      final readiness = await checkReadiness();

      // Check dependencies
      final dependencies = <DependencyHealth>[];

      for (final depName in this.dependencies) {
        // You can check actual dependency health here
        dependencies.add(
          DependencyHealth(
            name: depName,
            type: 'service',
            status: HealthStatus.healthy, // Check actual status
            message: 'Dependency status',
          ),
        );
      }

      // Determine overall health status
      HealthStatus status;
      String message;

      if (!liveness.isAlive) {
        status = HealthStatus.unhealthy;
        message = 'Service is not alive';
      } else if (!readiness.isReady) {
        status = HealthStatus.degraded;
        message = 'Service is alive but not ready: ${readiness.blockers.join(", ")}';
      } else if (!dependencies.every((d) => d.isHealthy)) {
        status = HealthStatus.degraded;
        message = 'Service is ready but has unhealthy dependencies';
      } else {
        status = HealthStatus.healthy;
        message = 'Service is healthy and operational';
      }

      final responseTime = DateTime.now().difference(startTime);

      return HealthCheckResult(
        serviceName: serviceName,
        version: version,
        status: status,
        message: message,
        timestamp: DateTime.now(),
        isLive: liveness.isAlive,
        isReady: readiness.isReady,
        responseTime: responseTime,
        details: {
          'liveness': liveness.toJson(),
          'readiness': readiness.toJson(),
          ...metadata,
        },
        dependencies: dependencies,
      );
    } catch (e) {
      LoggingService.instance.log(
        _tag,
        'Health check failed: $e',
        LogLevel.error,
      );

      return HealthCheckResult(
        serviceName: serviceName,
        version: version,
        status: HealthStatus.unhealthy,
        message: 'Health check failed: $e',
        timestamp: DateTime.now(),
        isLive: false,
        isReady: false,
        responseTime: DateTime.now().difference(startTime),
        details: {'error': e.toString()},
        dependencies: [],
      );
    }
  }
}
```

### Step 2: Register Service Health Checker

Add to your service locator setup:

```dart
import 'package:flutter_helix/core/health/health_check_service.dart';
import 'package:flutter_helix/core/health/implementations/my_service_health.dart';

// In setupServiceLocator() or similar initialization function
Future<void> setupHealthChecks() async {
  final healthService = HealthCheckService.instance;
  final myService = getIt<MyService>();

  // Register health checker
  healthService.registerService(
    MyServiceHealth(myService),
  );
}
```

### Step 3: Test Health Checks

```dart
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MyServiceHealth', () {
    late MyService service;
    late MyServiceHealth healthChecker;

    setUp(() {
      service = MyService();
      healthChecker = MyServiceHealth(service);
    });

    test('liveness check returns alive when service is running', () async {
      // Arrange
      service.start();

      // Act
      final result = await healthChecker.checkLiveness();

      // Assert
      expect(result.isAlive, isTrue);
    });

    test('readiness check returns not ready when service not initialized', () async {
      // Act
      final result = await healthChecker.checkReadiness();

      // Assert
      expect(result.isReady, isFalse);
      expect(result.blockers, contains('Service not initialized'));
    });

    test('health check returns healthy when all checks pass', () async {
      // Arrange
      service.start();
      await service.initialize();

      // Act
      final result = await healthChecker.checkHealth();

      // Assert
      expect(result.status, HealthStatus.healthy);
      expect(result.isLive, isTrue);
      expect(result.isReady, isTrue);
    });
  });
}
```

## Using HealthCheckMixin

For simpler implementations, use the `HealthCheckMixin`:

```dart
class SimpleServiceHealth with HealthCheckMixin {
  final SimpleService _service;

  SimpleServiceHealth(this._service);

  @override
  String get serviceName => 'SimpleService';

  @override
  String get version => '1.0.0';

  // The mixin provides default implementations of:
  // - checkLiveness()
  // - checkReadiness()
  // - checkHealth()

  // You can override specific methods if needed
  @override
  Future<LivenessProbe> checkLiveness() async {
    return LivenessProbe(
      isAlive: _service.isRunning,
      message: 'Custom liveness check',
      timestamp: DateTime.now(),
    );
  }
}
```

## For Services with Async Initialization

Extend `AsyncHealthChecker` for services with initialization phases:

```dart
class AsyncServiceHealth extends AsyncHealthChecker {
  final AsyncService _service;

  AsyncServiceHealth(this._service) {
    // Mark as initializing when created
    if (_service.isInitializing) {
      markInitializing();
    } else if (_service.isInitialized) {
      markInitialized();
    }

    // Listen to service state changes
    _service.onInitialized(() {
      markInitialized();
    });
  }

  @override
  String get serviceName => 'AsyncService';

  @override
  String get version => '1.0.0';

  @override
  List<String> get dependencies => [];

  // AsyncHealthChecker provides liveness and readiness checks
  // that automatically handle initialization state

  @override
  Future<HealthCheckResult> checkHealth() async {
    // Add custom health check logic
    final liveness = await checkLiveness();
    final readiness = await checkReadiness();

    // ... rest of implementation
  }
}
```

## Adding Custom Health Checks

### Resource-Based Checks

```dart
@override
Future<ReadinessProbe> checkReadiness() async {
  final blockers = <String>[];

  // Check memory usage
  final memoryUsage = await _service.getMemoryUsage();
  if (memoryUsage > 500 * 1024 * 1024) { // 500 MB
    blockers.add('Memory usage too high: ${memoryUsage ~/ (1024 * 1024)} MB');
  }

  // Check disk space
  final diskSpace = await _service.getAvailableDiskSpace();
  if (diskSpace < 100 * 1024 * 1024) { // 100 MB
    blockers.add('Low disk space: ${diskSpace ~/ (1024 * 1024)} MB remaining');
  }

  return ReadinessProbe(
    isReady: blockers.isEmpty,
    message: blockers.isEmpty ? 'Ready' : 'Not ready',
    blockers: blockers,
    timestamp: DateTime.now(),
  );
}
```

### API Connectivity Checks

```dart
@override
Future<HealthCheckResult> checkHealth() async {
  // ... existing code ...

  // Check API connectivity
  final apiHealth = DependencyHealth(
    name: 'ExternalAPI',
    type: 'api',
    status: await _checkAPIHealth(),
    message: 'External API connectivity',
  );

  dependencies.add(apiHealth);

  // ... rest of implementation
}

Future<HealthStatus> _checkAPIHealth() async {
  try {
    final response = await http.get(
      Uri.parse('https://api.example.com/health'),
    ).timeout(Duration(seconds: 5));

    return response.statusCode == 200
        ? HealthStatus.healthy
        : HealthStatus.degraded;
  } catch (e) {
    return HealthStatus.unhealthy;
  }
}
```

### Performance-Based Checks

```dart
@override
Future<HealthCheckResult> checkHealth() async {
  final startTime = DateTime.now();

  // ... perform health checks ...

  final responseTime = DateTime.now().difference(startTime);

  // Determine status based on response time
  HealthStatus status;
  if (!liveness.isAlive) {
    status = HealthStatus.unhealthy;
  } else if (!readiness.isReady) {
    status = HealthStatus.degraded;
  } else if (responseTime.inMilliseconds > 1000) {
    // Slow health check indicates degraded service
    status = HealthStatus.degraded;
  } else {
    status = HealthStatus.healthy;
  }

  return HealthCheckResult(
    // ... other fields ...
    status: status,
    responseTime: responseTime,
  );
}
```

## Best Practices

### 1. Keep Health Checks Fast

```dart
// BAD: Expensive operation in health check
Future<LivenessProbe> checkLiveness() async {
  await _service.performFullDiagnostic(); // Too slow!
  return LivenessProbe(...);
}

// GOOD: Quick status check
Future<LivenessProbe> checkLiveness() async {
  final isAlive = _service.isRunning; // Fast check
  return LivenessProbe(...);
}
```

### 2. Provide Meaningful Messages

```dart
// BAD: Generic message
message: 'Service not ready'

// GOOD: Specific, actionable message
message: 'Service not ready: Database connection not established, API key not configured'
```

### 3. Track All Dependencies

```dart
@override
List<String> get dependencies => [
  'DatabaseService',
  'CacheService',
  'ExternalAPI',
];

// Check each dependency in health check
for (final dep in dependencies) {
  dependencies.add(await _checkDependency(dep));
}
```

### 4. Include Relevant Metadata

```dart
@override
Map<String, dynamic> get metadata => {
  'version': version,
  'uptime': _service.uptime.inSeconds,
  'requestCount': _service.totalRequests,
  'errorCount': _service.totalErrors,
  'cacheHitRate': _service.cacheHitRate,
};
```

### 5. Handle Errors Gracefully

```dart
@override
Future<HealthCheckResult> checkHealth() async {
  try {
    // Health check logic
  } catch (e) {
    // Always return a result, even on error
    return HealthCheckResult(
      serviceName: serviceName,
      version: version,
      status: HealthStatus.unhealthy,
      message: 'Health check failed: $e',
      timestamp: DateTime.now(),
      isLive: false,
      isReady: false,
      details: {'error': e.toString()},
    );
  }
}
```

## Testing Health Checks

### Unit Tests

```dart
test('health check detects uninitialized service', () async {
  // Arrange
  final service = MyService(); // Not initialized

  // Act
  final health = await MyServiceHealth(service).checkHealth();

  // Assert
  expect(health.status, HealthStatus.degraded);
  expect(health.isLive, isTrue);
  expect(health.isReady, isFalse);
});
```

### Integration Tests

```dart
testWidgets('health check works end-to-end', (tester) async {
  // Setup
  await setupServices();
  final healthService = HealthCheckService.instance;

  // Act
  final result = await healthService.checkSystemHealth();

  // Assert
  expect(result.overallStatus, HealthStatus.healthy);
  expect(result.services, isNotEmpty);
});
```

## Monitoring Configuration

Add service to `config/health-monitoring.yaml`:

```yaml
services:
  MyService:
    enabled: true
    checkInterval: 30s
    criticalityLevel: high
    dependencies:
      - DependencyService
    customChecks:
      - name: "custom_check"
        description: "Custom health check"
        type: custom
```

## Common Patterns

### Database Service

```dart
@override
Future<ReadinessProbe> checkReadiness() async {
  final blockers = <String>[];

  if (!_service.isConnected) {
    blockers.add('Database not connected');
  }

  if (_service.connectionPoolExhausted) {
    blockers.add('Connection pool exhausted');
  }

  return ReadinessProbe(
    isReady: blockers.isEmpty,
    message: blockers.isEmpty ? 'Ready' : 'Not ready',
    blockers: blockers,
    timestamp: DateTime.now(),
  );
}
```

### Cache Service

```dart
@override
Map<String, dynamic> get metadata => {
  'cacheSize': _service.cacheSize,
  'hitRate': _service.hitRate,
  'evictionCount': _service.evictionCount,
  'memoryUsage': _service.memoryUsage,
};
```

### API Client Service

```dart
@override
Future<HealthCheckResult> checkHealth() async {
  // ... existing code ...

  // Check API connectivity
  try {
    await _service.ping().timeout(Duration(seconds: 3));
    status = HealthStatus.healthy;
  } catch (e) {
    status = HealthStatus.unhealthy;
    message = 'API unreachable: $e';
  }

  // ... rest of implementation
}
```

## Next Steps

1. Review existing health check implementations in `lib/core/health/implementations/`
2. Test your health checks thoroughly
3. Monitor health check performance
4. Update documentation with service-specific health check details
5. Configure alerting rules for critical services

## Support

For questions or issues:
- Check [Architecture Documentation](HEALTH_CHECK_ARCHITECTURE.md)
- Review [Quick Start Guide](QUICK_START.md)
- Examine existing implementations in `lib/core/health/implementations/`
