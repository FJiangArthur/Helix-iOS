# Feature Flags System

## Overview

The Helix application includes a comprehensive feature flag system that allows for:

- **Configuration-based flag definitions**: Define flags in a centralized JSON configuration file
- **Runtime flag evaluation**: Evaluate flags at runtime based on environment and rollout percentages
- **Environment-specific overrides**: Different flag states for development, staging, and production
- **Type-safe flag access**: Type-safe Dart models using Freezed for all flag configurations
- **Integration with dependency injection**: Seamless integration with GetIt and Riverpod
- **A/B testing support**: Built-in support for experiments and gradual rollouts

## Architecture

### Components

1. **Configuration File** (`feature_flags.json`): Central configuration defining all feature flags
2. **Models** (`feature_flag_models.dart`): Type-safe Dart models using Freezed
3. **Service** (`feature_flag_service.dart`): Runtime evaluation and flag management
4. **Providers** (`feature_flag_provider.dart`): Riverpod providers for widget access
5. **Examples** (`feature_flag_examples.dart`): Usage examples and patterns

### File Structure

```
/home/user/Helix-iOS/
├── feature_flags.json                          # Configuration file
├── lib/
│   └── core/
│       └── config/
│           ├── feature_flag_models.dart        # Type-safe models
│           ├── feature_flag_service.dart       # Service implementation
│           ├── feature_flag_provider.dart      # Riverpod providers
│           └── feature_flag_examples.dart      # Usage examples
└── docs/
    └── FEATURE_FLAGS.md                        # This file
```

## Getting Started

### 1. Configuration File

The feature flags are defined in `/home/user/Helix-iOS/feature_flags.json`. Here's the structure:

```json
{
  "version": "1.0.0",
  "description": "Feature flags for controlling experimental features",
  "environments": {
    "development": { "enabled": true, "description": "..." },
    "staging": { "enabled": true, "description": "..." },
    "production": { "enabled": true, "description": "..." }
  },
  "flags": {
    "flagName": {
      "enabled": true,
      "description": "Description of the flag",
      "type": "feature",
      "metadata": {
        "category": "ai",
        "requiresRestart": false
      },
      "variants": {
        "development": true,
        "staging": true,
        "production": false
      },
      "config": {
        "key": "value"
      }
    }
  },
  "globalConfig": {
    "defaultEnvironment": "development",
    "allowEnvironmentOverride": true,
    "cacheEnabled": true,
    "cacheDuration": 300
  }
}
```

### 2. Generate Freezed Code

After modifying the models, run code generation:

```bash
cd /home/user/Helix-iOS
flutter pub run build_runner build --delete-conflicting-outputs
```

### 3. Initialization

The feature flag service is automatically initialized in the service locator:

```dart
// In lib/services/service_locator.dart
final featureFlagService = FeatureFlagService.instance;
await featureFlagService.initialize();
getIt.registerSingleton<FeatureFlagService>(featureFlagService);
```

## Usage Patterns

### Using Feature Flags in Services

For non-UI code (services, business logic), use GetIt to access the service:

```dart
import 'package:get_it/get_it.dart';
import 'package:flutter_helix/core/config/feature_flag_service.dart';

class MyService {
  final FeatureFlagService _featureFlags;

  MyService() : _featureFlags = GetIt.instance.get<FeatureFlagService>();

  void doSomething() {
    // Check if a flag is enabled
    if (_featureFlags.isEnabled('advancedAIAnalysis')) {
      // Use advanced features
    }

    // Get configuration value
    final threshold = _featureFlags.getConfig<double>(
      'enhancedFactChecking',
      'minimumConfidenceScore',
      defaultValue: 0.5,
    );

    // Use extension methods
    if (_featureFlags.isModelSelectionEnabled) {
      final models = _featureFlags.availableModels;
      // ...
    }
  }
}
```

### Using Feature Flags in Widgets

For UI code, use Riverpod providers:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_helix/core/config/feature_flag_provider.dart';

class MyWidget extends ConsumerWidget {
  const MyWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch a specific flag
    final isEnabled = ref.watch(featureFlagProvider('modelSelection'));

    // Use convenience providers
    final showAdvancedFeatures = ref.watch(advancedAIAnalysisEnabledProvider);

    return Column(
      children: [
        // Conditional UI
        if (isEnabled)
          Text('Feature enabled!'),

        // Different UI based on flag
        showAdvancedFeatures
          ? AdvancedWidget()
          : BasicWidget(),
      ],
    );
  }
}
```

### Accessing Configuration Values

```dart
// Get a single config value
final interval = _featureFlags.getConfig<int>(
  'conversationInsights',
  'summarizationInterval',
  defaultValue: 60,
);

// Get all config for a flag
final config = _featureFlags.getAllConfig('whisperTranscription');
final fallback = config['fallbackToNative'] as bool?;
```

## Flag Types

### Feature Flags

Standard feature toggles for enabling/disabling functionality:

```json
{
  "modelSelection": {
    "enabled": true,
    "type": "feature",
    "description": "Allow users to select different AI models"
  }
}
```

### Experiments (A/B Tests)

Flags for running experiments with rollout percentages:

```json
{
  "abTestNewUI": {
    "enabled": true,
    "type": "experiment",
    "rolloutPercentage": {
      "development": 100,
      "staging": 50,
      "production": 10
    }
  }
}
```

### Debug Flags

Development and debugging features:

```json
{
  "advancedLogging": {
    "enabled": true,
    "type": "debug",
    "variants": {
      "development": true,
      "production": false
    }
  }
}
```

### Monitoring Flags

Performance and analytics features:

```json
{
  "performanceMonitoring": {
    "enabled": true,
    "type": "monitoring",
    "config": {
      "sampleRate": 1.0
    }
  }
}
```

## Available Feature Flags

### AI & ML Features

| Flag | Description | Default |
|------|-------------|---------|
| `modelSelection` | Allow users to select different AI models | Enabled (all envs) |
| `advancedAIAnalysis` | Advanced AI analysis with sentiment/topics | Development only |
| `enhancedFactChecking` | Multi-source fact checking with confidence | Enabled (dev/staging) |
| `conversationInsights` | Real-time conversation insights | Enabled (all envs) |
| `abTestModelComparison` | A/B test for model comparison | Development only |

### Transcription Features

| Flag | Description | Default |
|------|-------------|---------|
| `whisperTranscription` | Use Whisper API for transcription | Enabled (all envs) |

### UI & Interaction

| Flag | Description | Default |
|------|-------------|---------|
| `abTestNewUI` | A/B test for new UI design | Disabled |
| `voiceCommands` | Voice commands for hands-free control | Development only |

### System Features

| Flag | Description | Default |
|------|-------------|---------|
| `offlineMode` | Enable offline mode with local processing | Development only |
| `advancedLogging` | Enhanced logging for debugging | Enabled (dev/staging) |
| `performanceMonitoring` | Performance monitoring and metrics | Enabled (all envs) |
| `betaFeatures` | Umbrella flag for all beta features | Development only |

## Environment Management

### Setting Environment

```dart
// Programmatically set environment
final featureFlags = GetIt.instance.get<FeatureFlagService>();
featureFlags.setEnvironment(Environment.staging);
```

### Environment-Specific Behavior

Flags can have different states per environment:

```json
{
  "variants": {
    "development": true,   // Enabled in dev
    "staging": true,       // Enabled in staging
    "production": false    // Disabled in prod
  }
}
```

## Rollout Percentages

For gradual rollouts or A/B testing:

```json
{
  "rolloutPercentage": {
    "development": 100,  // 100% of dev users
    "staging": 50,       // 50% of staging users
    "production": 10     // 10% of prod users
  }
}
```

The rollout is deterministic based on the flag key hash, ensuring consistent user experience.

## Manual Overrides (Testing)

For testing purposes, you can manually override flags:

```dart
final featureFlags = GetIt.instance.get<FeatureFlagService>();

// Enable a flag
featureFlags.setOverride('offlineMode', true);

// Disable a flag
featureFlags.setOverride('advancedAIAnalysis', false);

// Remove override (return to config value)
featureFlags.removeOverride('offlineMode');

// Clear all overrides
featureFlags.clearOverrides();
```

**Note**: Overrides are runtime-only and not persisted.

## Debugging

### Debug Panel

Use the `FeatureFlagDebugPanel` widget to view and toggle flags:

```dart
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => FeatureFlagDebugPanel(),
  ),
);
```

### Export State

```dart
final featureFlags = GetIt.instance.get<FeatureFlagService>();
final state = featureFlags.exportState();
print(state);
// Output:
// {
//   'environment': 'Environment.development',
//   'enabledFlags': ['modelSelection', 'whisperTranscription', ...],
//   'overrides': {},
//   'cacheSize': 5,
//   'cacheValid': true
// }
```

### Logging

The service logs important events:

```
[FeatureFlagService] Initialized: environment=Environment.development
[FeatureFlagService] Feature flag override set: offlineMode = true
[FeatureFlagService] Environment changed to: Environment.staging
```

## Best Practices

### 1. Use Semantic Flag Names

✅ Good: `modelSelection`, `enhancedFactChecking`
❌ Bad: `feature1`, `newStuff`

### 2. Always Provide Descriptions

```json
{
  "description": "Enable offline mode with local processing"
}
```

### 3. Set Appropriate Defaults

- Development: Enable experimental features
- Staging: Mirror production with some extra features for testing
- Production: Only stable, well-tested features

### 4. Use Categories

Group related flags with categories:

```json
{
  "metadata": {
    "category": "ai"
  }
}
```

### 5. Document Configuration

```json
{
  "config": {
    "minimumConfidenceScore": 0.7,  // Double: 0.0-1.0
    "maxSourcesPerCheck": 3          // Int: max API calls
  }
}
```

### 6. Clean Up Old Flags

Remove flags that are:
- Fully rolled out (100% enabled everywhere)
- No longer needed
- Deprecated features

### 7. Use Type-Safe Access

```dart
// ✅ Type-safe
final threshold = featureFlags.getConfig<double>(
  'enhancedFactChecking',
  'minimumConfidenceScore',
  defaultValue: 0.5,
);

// ❌ Not type-safe
final config = featureFlags.getAllConfig('enhancedFactChecking');
final threshold = config['minimumConfidenceScore']; // dynamic
```

### 8. Cache Considerations

The service caches flag evaluations for 5 minutes by default. To force a reload:

```dart
await featureFlags.reload();
```

## Adding New Flags

1. **Add to configuration file**:

```json
{
  "flags": {
    "myNewFeature": {
      "enabled": true,
      "description": "Description of my new feature",
      "type": "feature",
      "metadata": {
        "category": "experimental",
        "requiresRestart": false,
        "addedDate": "2025-11-16"
      },
      "variants": {
        "development": true,
        "staging": false,
        "production": false
      },
      "config": {
        "someOption": "value"
      }
    }
  }
}
```

2. **Add convenience provider (optional)**:

```dart
// In feature_flag_provider.dart
final myNewFeatureEnabledProvider = Provider<bool>((ref) {
  return ref.watch(featureFlagProvider('myNewFeature'));
});
```

3. **Add extension method (optional)**:

```dart
// In feature_flag_service.dart, in FeatureFlagExtensions
extension FeatureFlagExtensions on FeatureFlagService {
  bool get isMyNewFeatureEnabled => isEnabled('myNewFeature');
  String? get someOption => getConfig<String>('myNewFeature', 'someOption');
}
```

4. **Use the flag**:

```dart
if (featureFlags.isMyNewFeatureEnabled) {
  // Feature code
}
```

## Migration Guide

If you have existing feature toggles in your code, here's how to migrate:

### Before

```dart
const bool USE_NEW_MODEL = true;

if (USE_NEW_MODEL) {
  // ...
}
```

### After

1. Add flag to `feature_flags.json`:

```json
{
  "useNewModel": {
    "enabled": true,
    "description": "Use new AI model",
    "type": "feature",
    "variants": {
      "development": true,
      "staging": true,
      "production": false
    }
  }
}
```

2. Update code:

```dart
final featureFlags = GetIt.instance.get<FeatureFlagService>();

if (featureFlags.isEnabled('useNewModel')) {
  // ...
}
```

## Troubleshooting

### Flags not loading

- Verify `feature_flags.json` exists in the project root
- Check console for initialization errors
- Ensure service is registered in `service_locator.dart`

### Flag always returning false

- Check the `enabled` field in configuration
- Verify the environment variant is set correctly
- Check rollout percentage if specified
- Look for any manual overrides

### Changes not reflecting

- Cache may be active (default 5 minutes)
- Call `featureFlags.reload()` to force refresh
- Check `_isCacheValid()` status

### Type errors with config

- Ensure you're using the correct type parameter
- Provide a default value
- Check the JSON configuration has the correct type

## Performance Considerations

- **Caching**: Flags are cached for 5 minutes by default
- **Evaluation**: Flag evaluation is O(1) with cache
- **Memory**: Minimal overhead, all flags loaded at startup
- **Reloading**: Avoid frequent reloads in production

## Security

- **No sensitive data**: Never store secrets in feature flags
- **Configuration file**: Keep `feature_flags.json` in version control
- **Overrides**: Runtime overrides are not persisted
- **Production**: Be careful with production overrides

## Future Enhancements

Potential improvements for the feature flag system:

1. **Remote configuration**: Load flags from a remote server
2. **User-specific flags**: Target specific users or groups
3. **Analytics integration**: Track flag usage and impact
4. **Scheduled rollouts**: Automatically change flags at specific times
5. **Flag dependencies**: Define flags that depend on other flags
6. **Persistence**: Save user-specific overrides locally
7. **Web dashboard**: Manage flags via web interface

## Support

For questions or issues with the feature flag system:

1. Check this documentation
2. Review examples in `feature_flag_examples.dart`
3. Check console logs for debugging information
4. Use the debug panel to inspect flag state

## References

- [GetIt Documentation](https://pub.dev/packages/get_it)
- [Riverpod Documentation](https://riverpod.dev/)
- [Freezed Documentation](https://pub.dev/packages/freezed)
- [Feature Flag Best Practices](https://martinfowler.com/articles/feature-toggles.html)
