# Model Lifecycle Management

A comprehensive system for managing AI model versions, deployments, performance monitoring, and audit logging.

## Features

- ✅ **Semantic Versioning**: Track model versions with semantic versioning (MAJOR.MINOR.PATCH)
- ✅ **Version Control**: Register, activate, deprecate, and retire model versions
- ✅ **Rollback Support**: Quick rollback to previous stable versions
- ✅ **Performance Monitoring**: Track latency, success rate, confidence, and cost metrics
- ✅ **Quality Thresholds**: Enforce minimum performance standards before deployment
- ✅ **Audit Logging**: Complete audit trail of all lifecycle events
- ✅ **Policy Enforcement**: Automated policy checks for deployments and deprecations
- ✅ **Compliance Reports**: Generate reports for audits and compliance

## Quick Start

### 1. Initialize the Manager

```dart
import 'package:helix/services/model_lifecycle/model_lifecycle_manager.dart';

final lifecycleManager = ModelLifecycleManager(
  logger: LoggingService(),
);

await lifecycleManager.initialize();
```

### 2. Register a Model

```dart
final model = ModelVersion(
  version: '1.0.0',
  modelId: 'gpt-4-turbo',
  provider: 'OpenAI',
  displayName: 'GPT-4 Turbo',
  releaseDate: DateTime.now(),
  status: ModelStatus.active,
  capabilities: ModelCapabilities(
    supportsStreaming: true,
    maxContextTokens: 128000,
    maxOutputTokens: 4096,
  ),
  costInfo: ModelCostInfo(
    inputCostPer1k: 0.01,
    outputCostPer1k: 0.03,
  ),
  createdAt: DateTime.now(),
  updatedAt: DateTime.now(),
);

await lifecycleManager.registerModel(model);
```

### 3. Activate the Model

```dart
await lifecycleManager.activateModel('gpt-4-turbo', '1.0.0');
```

### 4. Track Performance

```dart
// After each inference
await lifecycleManager.recordInference(
  modelId: 'gpt-4-turbo',
  version: '1.0.0',
  result: InferenceResult(
    success: true,
    latencyMs: 1234.5,
    confidence: 0.95,
    inputTokens: 100,
    outputTokens: 50,
  ),
);
```

### 5. Evaluate Model

```dart
final report = await lifecycleManager.evaluateModel(
  modelId: 'gpt-4-turbo',
  version: '1.0.0',
);

if (report.status == EvaluationStatus.passed) {
  print('Model meets all quality thresholds');
} else {
  print('Model evaluation failed');
  print('Recommendations: ${report.recommendations}');
}
```

## Core Components

### ModelLifecycleManager
Central manager providing unified access to all lifecycle operations.

### ModelRegistry
Manages model versions, activations, and deprecations.

### ModelEvaluator
Monitors performance and enforces quality thresholds.

### LifecyclePolicy
Enforces deployment policies and lifecycle rules.

### ModelAuditLog
Records all lifecycle events for compliance and debugging.

## Usage Examples

### Deploying a New Version

```dart
// 1. Register new version
await lifecycleManager.registerModel(newVersion);

// 2. Check if deployment is approved
final decision = await lifecycleManager.canDeployModel(
  modelId: 'gpt-4-turbo',
  version: '2.0.0',
);

if (decision.approved) {
  // 3. Activate new version
  await lifecycleManager.activateModel('gpt-4-turbo', '2.0.0');

  // Old versions are automatically deprecated
}
```

### Rolling Back

```dart
await lifecycleManager.rollbackModel('gpt-4-turbo', '1.0.0');
```

### Deprecating a Model

```dart
await lifecycleManager.deprecateModel(
  'gpt-3.5-turbo',
  '1.0.0',
  reason: 'Superseded by GPT-4',
  replacementVersion: '2.0.0',
  gracePeriodDays: 90,
);
```

### Getting Audit History

```dart
final history = lifecycleManager.getModelHistory('gpt-4-turbo');

for (final entry in history) {
  print('${entry.timestamp}: ${entry.action.name}');
}
```

### Generating Compliance Reports

```dart
final report = await lifecycleManager.generateComplianceReport(
  startDate: DateTime(2024, 1, 1),
  endDate: DateTime.now(),
);

print('Total events: ${report.totalEvents}');
print('Critical events: ${report.criticalEvents}');
```

## Configuration

### Evaluation Configuration

```dart
final evaluationConfig = EvaluationConfig(
  metricsUpdateInterval: 100,
  minSamplesForEvaluation: 50,
  maxErrorRate: 0.05,
  minSuccessRate: 0.95,
  maxLatencyMs: 5000,
  minConfidence: 0.7,
);

await lifecycleManager.initialize(
  evaluationConfig: evaluationConfig,
);
```

### Policy Configuration

```dart
final policyConfig = PolicyConfig(
  enforcePerformanceThresholds: true,
  deprecateOldVersionsOnNewDeployment: true,
  enableAutomaticRetirement: true,
  defaultGracePeriodDays: 90,
  eolWarningThresholdDays: 30,
  maxCostPerRequest: 0.10,
);

await lifecycleManager.initialize(
  policyConfig: policyConfig,
);
```

## Model Status Lifecycle

```
inactive → testing → canary → active → deprecated → retired
```

- **inactive**: Registered but not deployed
- **testing**: In staging environment
- **canary**: Limited production traffic
- **active**: Full production deployment
- **deprecated**: Marked for removal
- **retired**: Permanently removed

## Performance Metrics

The system tracks:
- Average latency (ms)
- P95 and P99 latency
- Success rate (%)
- Error rate (%)
- Average confidence score
- Token usage
- Estimated costs

## Audit Events

All operations are logged:
- Version registration
- Activation/deactivation
- Deprecation/retirement
- Rollbacks
- Metrics updates
- Threshold violations
- Configuration changes

## Best Practices

1. **Use Semantic Versioning**: Always use MAJOR.MINOR.PATCH format
2. **Test Before Production**: Use testing/canary status before activating
3. **Monitor Continuously**: Record all inference results
4. **Plan Deprecations**: Give adequate grace period (90+ days)
5. **Export Audit Logs**: Regular exports for compliance
6. **Review Metrics**: Check evaluation reports before promoting versions

## Documentation

For comprehensive documentation, see:
- [Complete Guide](/docs/MODEL_LIFECYCLE_MANAGEMENT.md)
- [API Reference](/docs/MODEL_LIFECYCLE_MANAGEMENT.md#api-reference)
- [Best Practices](/docs/MODEL_LIFECYCLE_MANAGEMENT.md#best-practices)

## Files

```
lib/services/model_lifecycle/
├── model_version.dart              # Model version data structures
├── model_registry.dart             # Version registry and management
├── model_audit_log.dart            # Audit logging system
├── model_evaluator.dart            # Performance monitoring
├── lifecycle_policy.dart           # Policy enforcement
├── model_lifecycle_manager.dart    # Central facade
└── README.md                       # This file
```

## Dependencies

```yaml
dependencies:
  freezed_annotation: ^2.4.1
  shared_preferences: ^2.2.2

dev_dependencies:
  freezed: ^2.4.5
  build_runner: ^2.4.7
```

## Generating Code

Some files use code generation. Run:

```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

## License

Part of the Helix iOS project.
