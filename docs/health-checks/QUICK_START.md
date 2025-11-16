# Health Checks Quick Start Guide

## Overview

This guide provides quick instructions for setting up and using the health check system in the Helix application.

## Quick Setup

### 1. Enable Health Checks in Flutter App

Add to your service locator setup:

```dart
import 'package:flutter_helix/core/health/health_check_service.dart';
import 'package:flutter_helix/core/health/implementations/audio_service_health.dart';
import 'package:flutter_helix/core/health/implementations/llm_service_health.dart';

// In your service setup function
Future<void> setupHealthChecks() async {
  final healthService = HealthCheckService.instance;

  // Register service health checkers
  healthService.registerService(
    AudioServiceHealth(getIt<AudioService>()),
  );

  healthService.registerService(
    LLMServiceHealth(getIt<LLMServiceImplV2>()),
  );

  // Start periodic health checks (every 5 minutes)
  healthService.startPeriodicHealthChecks(
    interval: Duration(minutes: 5),
  );

  // Listen to health updates
  healthService.healthStatusStream.listen((result) {
    print('System Health: ${result.overallStatus} (${result.overallHealthScore}/100)');
  });
}
```

### 2. Start Docker Services with Health Checks

```bash
# Start all services with health checks
docker-compose up -d

# Check service health
docker ps --format "table {{.Names}}\t{{.Status}}"

# View specific service health
docker inspect helix-redis --format '{{.State.Health.Status}}'
```

### 3. Run Health Monitoring Script

```bash
# Make script executable (first time only)
chmod +x scripts/health-check-monitor.sh

# Start monitoring
./scripts/health-check-monitor.sh
```

## Quick Health Checks

### Check System Health

```bash
# Via curl (if HTTP endpoint is exposed)
curl http://localhost:9100/health | jq

# Via Docker
docker exec helix-redis redis-cli ping
docker exec helix-postgres pg_isready -U helix -d helix_dev
```

### Check Individual Services

```bash
# Nginx
curl http://localhost:8080/health

# Mock API
curl http://localhost:1080/health

# Redis
docker exec helix-redis redis-cli ping

# PostgreSQL
docker exec helix-postgres pg_isready -U helix
```

## Common Operations

### View Health Status

```dart
// Get latest system health
final health = HealthCheckService.instance.latestHealth;
print('Overall Status: ${health?.overallStatus}');
print('Health Score: ${health?.overallHealthScore}');

// Get specific service health
final audioHealth = await HealthCheckService.instance
    .checkServiceHealth('AudioService');
print('Audio Service: ${audioHealth.status}');
```

### Check Service Dependencies

```dart
// Get dependency graph
final dependencies = HealthCheckService.instance.getDependencyGraph();
print('Dependencies: $dependencies');

// Validate dependencies
final issues = await HealthCheckService.instance.validateDependencies();
if (issues.isNotEmpty) {
  print('Dependency Issues: $issues');
}
```

### View Health Trends

```dart
// Get health trends
final trends = HealthCheckService.instance.getHealthTrends();
print('Average Score: ${trends["averageHealthScore"]}');
print('Trend: ${trends["trend"]}'); // improving, stable, degrading
```

## Monitoring Dashboard

### View Real-Time Health

The monitoring script provides a real-time dashboard:

```
=== Health Check Results ===
Time: 2024-01-01 12:00:00

✓ Nginx: HEALTHY
✓ Mock API: HEALTHY
✓ Redis: HEALTHY
✓ PostgreSQL: HEALTHY

=== Container Health ===
✓ helix-redis: healthy
✓ helix-postgres: healthy
✓ helix-nginx: healthy
✓ helix-mock-api: healthy

=== Summary ===
Total services: 4
Unhealthy: 0
✓ All services are healthy
```

### Check Logs

```bash
# Health check logs
tail -f logs/health-check.log

# Alert logs
tail -f logs/health-alerts.log

# Metrics (JSON)
cat logs/health-metrics.json | jq
```

## Troubleshooting

### Service Shows Unhealthy

```dart
// Check detailed health status
final health = await HealthCheckService.instance
    .checkServiceHealth('ServiceName');

print('Status: ${health.status}');
print('Message: ${health.message}');
print('Details: ${health.details}');
print('Is Live: ${health.isLive}');
print('Is Ready: ${health.isReady}');

// Check readiness blockers
if (!health.isReady) {
  print('Blockers: ${health.details['readiness']['blockers']}');
}
```

### Container Health Check Failing

```bash
# View container health logs
docker inspect helix-redis --format '{{json .State.Health}}' | jq

# Manual health check
docker exec helix-redis redis-cli ping

# Check container logs
docker logs helix-redis --tail 50
```

### Reset Health History

```dart
// Clear health history
HealthCheckService.instance.clearHistory();
```

## Configuration

### Adjust Check Intervals

```dart
// Change periodic check interval
HealthCheckService.instance.stopPeriodicHealthChecks();
HealthCheckService.instance.startPeriodicHealthChecks(
  interval: Duration(minutes: 1), // More frequent checks
);
```

### Modify Docker Health Checks

Edit `docker-compose.yml`:

```yaml
healthcheck:
  test: ["CMD", "redis-cli", "ping"]
  interval: 10s      # Change from 30s
  timeout: 5s        # Change from 3s
  retries: 5         # Change from 3
  start_period: 10s  # Change from 5s
```

Then restart:
```bash
docker-compose up -d --force-recreate
```

## API Endpoints

### Basic Health Check

```bash
# Overall health
curl http://localhost:9100/health

# Liveness
curl http://localhost:9100/health/live

# Readiness
curl http://localhost:9100/health/ready

# Specific service
curl http://localhost:9100/health/services/AudioService

# Metrics
curl http://localhost:9100/health/metrics

# Dependencies
curl http://localhost:9100/health/dependencies

# Version
curl http://localhost:9100/health/version
```

## Best Practices

1. **Start health checks early**: Initialize health monitoring during app startup
2. **Monitor critical services**: Focus on services critical to core functionality
3. **Set realistic thresholds**: Configure based on actual service performance
4. **Review health trends**: Regularly check trends to identify degradation
5. **Act on alerts**: Investigate and resolve unhealthy states promptly
6. **Keep checks fast**: Health checks should complete in < 1 second
7. **Test failure scenarios**: Ensure health checks correctly detect failures

## Next Steps

- Review [Health Check Architecture](HEALTH_CHECK_ARCHITECTURE.md) for detailed information
- Check [Implementation Guide](IMPLEMENTATION_GUIDE.md) for adding health checks to new services
- Explore [Monitoring Configuration](../../config/health-monitoring.yaml) for advanced settings

## Support

For issues or questions:
1. Check the troubleshooting section above
2. Review service logs
3. Inspect health check details
4. Check the architecture documentation
