# Health Check Architecture

## Overview

This document describes the comprehensive health check system implemented for the Helix application. The system provides monitoring, alerting, and observability for all services and components.

## Architecture

### Components

1. **Health Check Service** (`lib/core/health/health_check_service.dart`)
   - Central orchestrator for all health checks
   - Aggregates health status from all services
   - Provides health history and trends
   - Emits health status updates via streams

2. **Service Health Checkers** (`lib/core/health/service_health_checker.dart`)
   - Interface for service-specific health checks
   - Implements liveness, readiness, and dependency checks
   - Provides health check mixins for easy integration

3. **Health Check Models** (`lib/core/health/health_check_models.dart`)
   - Defines health status enumerations
   - Health check result structures
   - System health aggregation models

4. **Health Check Endpoint** (`lib/core/health/health_check_endpoint.dart`)
   - HTTP endpoint handler for health checks
   - RESTful API for health status queries
   - Supports various health check formats

5. **Service-Specific Implementations** (`lib/core/health/implementations/`)
   - Health checkers for each service
   - Custom health logic per service
   - Dependency tracking

### Health Check Types

#### 1. Liveness Checks
- **Purpose**: Determine if a service is running
- **Endpoint**: `/health/live`
- **Response**: `{"status": "alive", "timestamp": "..."}`
- **Use Case**: Container orchestration, basic monitoring

#### 2. Readiness Checks
- **Purpose**: Determine if a service can handle requests
- **Endpoint**: `/health/ready`
- **Response**: `{"status": "ready", "message": "...", "blockers": [...]}`
- **Use Case**: Load balancer configuration, traffic routing

#### 3. Dependency Checks
- **Purpose**: Verify health of service dependencies
- **Included In**: `/health` comprehensive check
- **Response**: Includes dependency health in details
- **Use Case**: Root cause analysis, dependency mapping

#### 4. Version Information
- **Purpose**: Report service version details
- **Endpoint**: `/health/version`
- **Response**: `{"version": "...", "buildNumber": "...", "gitCommit": "..."}`
- **Use Case**: Deployment verification, rollback decisions

## Service Inventory

### Flutter Application Services

#### Core Services
1. **AudioService**
   - Version: 1.0.0
   - Dependencies: None
   - Health Checks:
     - Liveness: Service existence
     - Readiness: Audio permission granted
     - Custom: Recording capability test

2. **LLMService**
   - Version: 2.0.0
   - Dependencies: None
   - Health Checks:
     - Liveness: Service existence
     - Readiness: Initialization status
     - Custom: API connectivity

3. **TranscriptionCoordinator**
   - Version: 1.0.0
   - Dependencies: AudioService
   - Health Checks:
     - Liveness: Service existence
     - Readiness: Transcription availability
     - Custom: Provider health

4. **AIInsightsService**
   - Version: 1.0.0
   - Dependencies: LLMService
   - Health Checks:
     - Liveness: Service statistics availability
     - Readiness: Service enabled status
     - Custom: Insight generation capability

### Infrastructure Services

#### Docker Services
1. **Redis**
   - Health Check: `redis-cli ping`
   - Interval: 30s
   - Timeout: 3s
   - Retries: 3

2. **PostgreSQL**
   - Health Check: `pg_isready -U helix -d helix_dev`
   - Interval: 30s
   - Timeout: 5s
   - Retries: 5

3. **Nginx**
   - Health Check: `wget --spider http://localhost/health`
   - Interval: 30s
   - Timeout: 5s
   - Retries: 3
   - Dependencies: mock-api

4. **Mock API**
   - Health Check: `curl -f http://localhost:1080/health`
   - Interval: 30s
   - Timeout: 10s
   - Retries: 3

5. **Documentation Server**
   - Health Check: `wget --spider http://localhost:8000`
   - Interval: 30s
   - Timeout: 5s
   - Retries: 3

## Health Status Definitions

### Status Levels

1. **Healthy** (Green)
   - Service is fully operational
   - All dependencies are healthy
   - Performance within normal thresholds
   - Health Score: 100

2. **Degraded** (Yellow)
   - Service is operational but with limitations
   - Some dependencies may be unhealthy
   - Performance degraded but acceptable
   - Health Score: 50

3. **Unhealthy** (Red)
   - Service is not operational
   - Critical dependencies failed
   - Cannot handle requests
   - Health Score: 0

4. **Unknown** (Blue)
   - Health status cannot be determined
   - Service not responding to checks
   - Monitoring error
   - Health Score: 25

### Health Scoring

Health scores range from 0-100:
- **90-100**: Excellent health
- **70-89**: Good health (minor issues)
- **50-69**: Degraded health (requires attention)
- **0-49**: Poor health (immediate action required)

System health score is the average of all service scores.

## API Endpoints

### Health Check Endpoints

#### GET /health
Comprehensive system health check

**Response:**
```json
{
  "status": "healthy",
  "timestamp": "2024-01-01T12:00:00Z",
  "version": "1.0.0",
  "uptime": "3600s",
  "overallStatus": "healthy",
  "overallHealthScore": 95,
  "totalCheckDuration": 150,
  "systemInfo": {
    "platform": "ios",
    "environment": "production"
  },
  "services": [
    {
      "serviceName": "AudioService",
      "version": "1.0.0",
      "status": "healthy",
      "message": "Service is healthy and operational",
      "isLive": true,
      "isReady": true,
      "responseTime": 10,
      "healthScore": 100,
      "dependencies": []
    }
  ],
  "summary": {
    "total": 8,
    "healthy": 7,
    "degraded": 1,
    "unhealthy": 0,
    "unknown": 0
  }
}
```

#### GET /health/live
Liveness probe

**Response:**
```json
{
  "status": "alive",
  "timestamp": "2024-01-01T12:00:00Z",
  "message": "Application is running"
}
```

#### GET /health/ready
Readiness probe

**Response:**
```json
{
  "status": "ready",
  "timestamp": "2024-01-01T12:00:00Z",
  "message": "Application is ready to serve requests",
  "details": {
    "overallStatus": "healthy",
    "healthScore": 95,
    "unhealthyServices": []
  }
}
```

#### GET /health/services/{serviceName}
Individual service health

**Response:**
```json
{
  "service": "AudioService",
  "timestamp": "2024-01-01T12:00:00Z",
  "serviceName": "AudioService",
  "version": "1.0.0",
  "status": "healthy",
  "message": "Service is healthy and operational",
  "isLive": true,
  "isReady": true,
  "responseTime": 10,
  "healthScore": 100,
  "details": {
    "liveness": {
      "isAlive": true,
      "message": "Audio service is alive",
      "timestamp": "2024-01-01T12:00:00Z"
    },
    "readiness": {
      "isReady": true,
      "message": "Audio service is ready",
      "blockers": [],
      "timestamp": "2024-01-01T12:00:00Z"
    },
    "isRecording": false,
    "hasPermission": true
  },
  "dependencies": []
}
```

#### GET /health/metrics
Health metrics and trends

**Response:**
```json
{
  "timestamp": "2024-01-01T12:00:00Z",
  "trends": {
    "averageHealthScore": 92,
    "trend": "stable",
    "degradationRate": 0.0,
    "checkCount": 100
  },
  "current": {
    "overallStatus": "healthy",
    "overallHealthScore": 95
  },
  "dependencies": {
    "AIInsightsService": ["LLMService"],
    "TranscriptionCoordinator": ["AudioService"],
    "nginx": ["mock-api"]
  }
}
```

#### GET /health/dependencies
Dependency graph and validation

**Response:**
```json
{
  "timestamp": "2024-01-01T12:00:00Z",
  "dependencyGraph": {
    "AIInsightsService": ["LLMService"],
    "TranscriptionCoordinator": ["AudioService"]
  },
  "validationIssues": {},
  "hasIssues": false
}
```

#### GET /health/version
Version information

**Response:**
```json
{
  "timestamp": "2024-01-01T12:00:00Z",
  "application": {
    "name": "Helix",
    "version": "1.0.0",
    "buildNumber": "1",
    "environment": "production"
  },
  "services": [
    {
      "name": "AudioService",
      "version": "1.0.0"
    },
    {
      "name": "LLMService",
      "version": "2.0.0"
    }
  ]
}
```

## Configuration

### Dashboard Configuration
Location: `/home/user/Helix-iOS/config/health-dashboard.yaml`

Key settings:
- Refresh interval: 30s
- Alert threshold: 2 failed checks
- Service groups: Core, AI & Analytics, Infrastructure, Supporting
- Metrics tracking: response_time, health_score, availability
- Alert channels: console, analytics

### Monitoring Configuration
Location: `/home/user/Helix-iOS/config/health-monitoring.yaml`

Key settings:
- Collection interval: 30s
- Retention period: 7 days
- Alerting enabled with routing rules
- Circuit breaker patterns
- Auto-remediation (disabled by default)

## Monitoring Setup

### Running the Health Monitor

```bash
# Start the monitoring script
./scripts/health-check-monitor.sh
```

The monitor will:
1. Check all services every 30 seconds
2. Display real-time health status
3. Log to `logs/health-check.log`
4. Track alerts in `logs/health-alerts.log`
5. Export metrics to `logs/health-metrics.json`

### Docker Health Checks

Health checks are configured in `docker-compose.yml`:

```yaml
healthcheck:
  test: ["CMD", "redis-cli", "ping"]
  interval: 30s
  timeout: 3s
  retries: 3
  start_period: 5s
```

View container health:
```bash
docker ps --format "table {{.Names}}\t{{.Status}}"
```

## Integration

### Registering a Service

```dart
import 'package:flutter_helix/core/health/health_check_service.dart';
import 'package:flutter_helix/core/health/implementations/audio_service_health.dart';

// Register service for health checking
final healthCheckService = HealthCheckService.instance;
final audioServiceHealth = AudioServiceHealth(audioService);

healthCheckService.registerService(audioServiceHealth);
```

### Implementing Health Checks

```dart
import 'package:flutter_helix/core/health/service_health_checker.dart';
import 'package:flutter_helix/core/health/health_check_models.dart';

class MyServiceHealth implements ServiceHealthChecker {
  @override
  String get serviceName => 'MyService';

  @override
  String get version => '1.0.0';

  @override
  List<String> get dependencies => ['DependencyService'];

  @override
  Future<LivenessProbe> checkLiveness() async {
    // Implement liveness check
    return LivenessProbe(
      isAlive: true,
      message: 'Service is alive',
      timestamp: DateTime.now(),
    );
  }

  @override
  Future<ReadinessProbe> checkReadiness() async {
    // Implement readiness check
    final blockers = <String>[];

    // Add readiness checks
    if (!isInitialized) {
      blockers.add('Service not initialized');
    }

    return ReadinessProbe(
      isReady: blockers.isEmpty,
      message: blockers.isEmpty ? 'Ready' : 'Not ready',
      blockers: blockers,
      timestamp: DateTime.now(),
    );
  }

  @override
  Future<HealthCheckResult> checkHealth() async {
    // Comprehensive health check
    final liveness = await checkLiveness();
    final readiness = await checkReadiness();

    // Determine status
    HealthStatus status;
    if (!liveness.isAlive) {
      status = HealthStatus.unhealthy;
    } else if (!readiness.isReady) {
      status = HealthStatus.degraded;
    } else {
      status = HealthStatus.healthy;
    }

    return HealthCheckResult(
      serviceName: serviceName,
      version: version,
      status: status,
      message: 'Health check result',
      timestamp: DateTime.now(),
      isLive: liveness.isAlive,
      isReady: readiness.isReady,
      dependencies: [],
    );
  }
}
```

### Starting Periodic Checks

```dart
// Start periodic health checks (every 5 minutes)
healthCheckService.startPeriodicHealthChecks(
  interval: Duration(minutes: 5),
);

// Listen to health status updates
healthCheckService.healthStatusStream.listen((result) {
  print('System health: ${result.overallStatus}');
  print('Health score: ${result.overallHealthScore}');

  if (result.unhealthyServices.isNotEmpty) {
    print('Unhealthy services: ${result.unhealthyServices.map((s) => s.serviceName).join(", ")}');
  }
});
```

## Alerting

### Alert Severities

1. **Info**: Informational, no action required
2. **Warning**: Investigate soon
3. **Critical**: Immediate action required
4. **Emergency**: System failure

### Alert Rules

Configured in `config/health-monitoring.yaml`:

- **Service Down**: Triggered when service is unhealthy for 2+ minutes
- **Service Degraded**: Triggered when service is degraded for 5+ minutes
- **High Response Time**: Triggered when response time > 5000ms for 3+ minutes
- **Multiple Services Down**: Triggered when 2+ services are down
- **Dependency Failure**: Triggered when dependencies are unhealthy

### Alert Channels

1. **Console**: Logs to application console
2. **Analytics**: Sends to analytics service
3. **Custom**: Integrate with external systems (Slack, PagerDuty, etc.)

## Best Practices

1. **Implement all health check types**: Liveness, readiness, and dependency checks
2. **Keep checks lightweight**: Health checks should complete quickly (< 1s)
3. **Include meaningful messages**: Provide actionable information in health check responses
4. **Track dependencies**: Declare all service dependencies for proper monitoring
5. **Set appropriate thresholds**: Configure thresholds based on service SLOs
6. **Monitor trends**: Use health history to identify patterns and predict issues
7. **Test health checks**: Ensure health checks work correctly in all states
8. **Document custom checks**: Clearly document any custom health check logic

## Troubleshooting

### Service Shows as Unhealthy

1. Check service logs for errors
2. Verify dependencies are healthy
3. Check resource availability (memory, CPU, network)
4. Review recent changes or deployments
5. Examine health check details for specific blockers

### Health Checks Timing Out

1. Reduce health check timeout
2. Optimize health check logic
3. Check for blocking operations
4. Increase resources if needed

### False Positive Alerts

1. Adjust alert thresholds
2. Increase alert delay/window
3. Review health check logic
4. Enable alert throttling

## Future Enhancements

1. **Metrics Export**: Prometheus/OpenTelemetry integration
2. **Dashboard UI**: Web-based health dashboard
3. **Advanced Analytics**: ML-based anomaly detection
4. **Auto-Remediation**: Automated recovery actions
5. **Distributed Tracing**: End-to-end request tracing
6. **SLO Tracking**: Service Level Objective monitoring
7. **Chaos Engineering**: Automated resilience testing

## References

- Health Check Models: `lib/core/health/health_check_models.dart`
- Health Check Service: `lib/core/health/health_check_service.dart`
- Service Health Checker: `lib/core/health/service_health_checker.dart`
- Dashboard Config: `config/health-dashboard.yaml`
- Monitoring Config: `config/health-monitoring.yaml`
- Monitor Script: `scripts/health-check-monitor.sh`
