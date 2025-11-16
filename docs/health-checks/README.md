# Health Check System Documentation

## Overview

The Helix Health Check System provides comprehensive monitoring, alerting, and observability for all application and infrastructure services.

## Quick Links

- **[Quick Start Guide](QUICK_START.md)** - Get started in 5 minutes
- **[Architecture Documentation](HEALTH_CHECK_ARCHITECTURE.md)** - Detailed system architecture
- **[Implementation Guide](IMPLEMENTATION_GUIDE.md)** - Add health checks to new services

## System Status

**Status:** ✅ Fully Implemented
**Services Monitored:** 10 (5 Flutter + 5 Docker)
**Health Check Types:** Liveness, Readiness, Dependency, Version

## Monitored Services

### Flutter Application Services

| Service | Version | Dependencies | Health Check File |
|---------|---------|--------------|-------------------|
| AudioService | 1.0.0 | None | `lib/core/health/implementations/audio_service_health.dart` |
| LLMService | 2.0.0 | None | `lib/core/health/implementations/llm_service_health.dart` |
| AIInsightsService | 1.0.0 | LLMService | `lib/core/health/implementations/ai_insights_service_health.dart` |
| TranscriptionCoordinator | 1.0.0 | AudioService | `lib/core/health/implementations/transcription_service_health.dart` |
| HealthCheckService | 1.0.0 | All Services | `lib/core/health/health_check_service.dart` |

### Docker Infrastructure Services

| Service | Container | Health Check | Endpoint |
|---------|-----------|--------------|----------|
| Redis | helix-redis | `redis-cli ping` | - |
| PostgreSQL | helix-postgres | `pg_isready` | - |
| Nginx | helix-nginx | HTTP `/health` | http://localhost:8080/health |
| Mock API | helix-mock-api | HTTP `/health` | http://localhost:1080/health |
| Docs | helix-docs | HTTP root | http://localhost:8000 |

## Health Check Endpoints

| Endpoint | Description | Response |
|----------|-------------|----------|
| `GET /health` | System health | Complete health status |
| `GET /health/live` | Liveness | Is app running? |
| `GET /health/ready` | Readiness | Can app serve requests? |
| `GET /health/services/{name}` | Service health | Individual service status |
| `GET /health/metrics` | Metrics | Health trends and metrics |
| `GET /health/dependencies` | Dependencies | Dependency graph |
| `GET /health/version` | Version | Version information |

## Health Status Levels

| Status | Score | Color | Meaning |
|--------|-------|-------|---------|
| **Healthy** | 100 | 🟢 Green | Fully operational |
| **Degraded** | 50 | 🟡 Yellow | Operational with limitations |
| **Unhealthy** | 0 | 🔴 Red | Not operational |
| **Unknown** | 25 | 🔵 Blue | Cannot determine status |

## Quick Commands

### Flutter App

```dart
// Check system health
final health = await HealthCheckService.instance.checkSystemHealth();
print('Health Score: ${health.overallHealthScore}/100');

// Check specific service
final audioHealth = await HealthCheckService.instance
    .checkServiceHealth('AudioService');
print('Audio: ${audioHealth.status}');

// Start monitoring
HealthCheckService.instance.startPeriodicHealthChecks(
  interval: Duration(minutes: 5),
);
```

### Docker Services

```bash
# Check all containers
docker ps --format "table {{.Names}}\t{{.Status}}"

# Check specific service
docker inspect helix-redis --format '{{.State.Health.Status}}'

# Run monitoring script
./scripts/health-check-monitor.sh

# View logs
tail -f logs/health-check.log
```

### API Endpoints

```bash
# System health
curl http://localhost:9100/health | jq

# Liveness
curl http://localhost:9100/health/live | jq

# Readiness
curl http://localhost:9100/health/ready | jq

# Service health
curl http://localhost:9100/health/services/AudioService | jq

# Metrics
curl http://localhost:9100/health/metrics | jq
```

## Configuration Files

| File | Purpose |
|------|---------|
| `config/health-dashboard.yaml` | Dashboard and alerting configuration |
| `config/health-monitoring.yaml` | Monitoring thresholds and rules |
| `docker-compose.yml` | Docker service health checks |
| `scripts/health-check-monitor.sh` | Monitoring script |

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│              Health Check Service (Central)              │
│  - Service Registration                                  │
│  - Periodic Health Checks                               │
│  - Health Aggregation                                   │
│  - Trend Analysis                                       │
└─────────────────────────────────────────────────────────┘
                           │
        ┌──────────────────┼──────────────────┐
        │                  │                  │
┌───────▼────────┐ ┌──────▼──────┐ ┌────────▼────────┐
│ AudioService   │ │ LLMService  │ │ AIInsights      │
│ Health Checker │ │ Health      │ │ Health Checker  │
└────────────────┘ └─────────────┘ └─────────────────┘
        │                  │                  │
┌───────▼────────┐ ┌──────▼──────┐ ┌────────▼────────┐
│ Liveness       │ │ Liveness    │ │ Liveness        │
│ Readiness      │ │ Readiness   │ │ Readiness       │
│ Dependencies   │ │ Dependencies│ │ Dependencies    │
└────────────────┘ └─────────────┘ └─────────────────┘
```

## Dependency Graph

```
TranscriptionCoordinator
    └── AudioService

AIInsightsService
    └── LLMService

Nginx
    └── Mock API

HealthCheckService
    ├── AudioService
    ├── LLMService
    ├── AIInsightsService
    └── TranscriptionCoordinator
```

## Alert Rules

| Alert | Severity | Duration | Channels |
|-------|----------|----------|----------|
| Service Down | Critical | 2 min | Console, Analytics |
| Service Degraded | Warning | 5 min | Console |
| High Response Time | Warning | 3 min | Console |
| Multiple Services Down | Emergency | 1 min | Console, Analytics |
| Dependency Failure | Warning | 5 min | Console |

## Metrics Tracked

- **response_time**: Service response time (ms)
- **health_score**: Overall health score (0-100)
- **service_availability**: Service availability (%)
- **failed_checks**: Number of failed health checks
- **dependency_health**: Health status of dependencies

## File Structure

```
/home/user/Helix-iOS/
├── lib/core/health/                    # Flutter health check infrastructure
│   ├── health_check_models.dart        # Data models
│   ├── service_health_checker.dart     # Interface and mixins
│   ├── health_check_service.dart       # Central service
│   ├── health_check_endpoint.dart      # HTTP endpoints
│   └── implementations/                # Service-specific implementations
│       ├── audio_service_health.dart
│       ├── llm_service_health.dart
│       ├── ai_insights_service_health.dart
│       └── transcription_service_health.dart
├── config/                             # Configuration files
│   ├── health-dashboard.yaml
│   └── health-monitoring.yaml
├── scripts/                            # Monitoring scripts
│   └── health-check-monitor.sh
├── docker/healthcheck/                 # Docker health scripts
│   ├── redis-health.sh
│   ├── postgres-health.sh
│   └── nginx-health.sh
└── docs/health-checks/                 # Documentation
    ├── README.md                       # This file
    ├── QUICK_START.md
    ├── HEALTH_CHECK_ARCHITECTURE.md
    └── IMPLEMENTATION_GUIDE.md
```

## Getting Started

1. **Read the Quick Start Guide**
   ```bash
   cat docs/health-checks/QUICK_START.md
   ```

2. **Start Docker Services**
   ```bash
   docker-compose up -d
   ```

3. **Run Health Monitor**
   ```bash
   ./scripts/health-check-monitor.sh
   ```

4. **Register Services in Flutter**
   ```dart
   final healthService = HealthCheckService.instance;
   healthService.registerService(AudioServiceHealth(audioService));
   healthService.startPeriodicHealthChecks();
   ```

## Common Use Cases

### Monitor System Health

```dart
healthService.healthStatusStream.listen((result) {
  if (result.overallStatus != HealthStatus.healthy) {
    print('⚠️ System health degraded');
    for (final service in result.unhealthyServices) {
      print('  - ${service.serviceName}: ${service.message}');
    }
  }
});
```

### Check Before Critical Operations

```dart
Future<void> performCriticalOperation() async {
  // Check health first
  final health = await healthService.checkSystemHealth();

  if (health.overallHealthScore < 70) {
    throw Exception('System health too low for critical operation');
  }

  // Proceed with operation
}
```

### Validate Dependencies

```dart
final issues = await healthService.validateDependencies();
if (issues.isNotEmpty) {
  print('Dependency issues detected:');
  issues.forEach((service, problems) {
    print('  $service: ${problems.join(", ")}');
  });
}
```

## Troubleshooting

### Service Shows Unhealthy

1. Check service logs
2. Verify dependencies are healthy
3. Review health check details
4. Check recent changes

### Health Checks Timeout

1. Reduce timeout value
2. Optimize health check logic
3. Check for blocking operations

### False Alerts

1. Adjust thresholds
2. Increase alert delay
3. Enable alert throttling

## Best Practices

1. ✅ Implement all check types (liveness, readiness, dependencies)
2. ✅ Keep checks fast (< 1 second)
3. ✅ Provide meaningful messages
4. ✅ Track all dependencies
5. ✅ Test health checks
6. ✅ Monitor trends
7. ✅ Act on alerts promptly

## Support & Resources

- **Documentation**: `/docs/health-checks/`
- **Configuration**: `/config/health-*.yaml`
- **Implementation Examples**: `/lib/core/health/implementations/`
- **Monitoring Script**: `/scripts/health-check-monitor.sh`

## License

Part of the Helix iOS Application

---

**Last Updated:** 2025-11-16
**Status:** ✅ Production Ready
