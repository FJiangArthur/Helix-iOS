# Feature Flags - Quick Start Guide

## What Are Feature Flags?

Feature flags allow you to enable/disable features without deploying new code. Use them for:
- Gradual rollouts
- A/B testing
- Environment-specific features
- Emergency kill switches

## Setup (One-Time)

### 1. Generate Freezed Code

```bash
cd /home/user/Helix-iOS
flutter pub run build_runner build --delete-conflicting-outputs
```

### 2. Verify Configuration

Check that `/home/user/Helix-iOS/feature_flags.json` exists. If not, create it from the template.

## Quick Usage Examples

### In Services (Non-UI Code)

```dart
import 'package:get_it/get_it.dart';
import 'package:flutter_helix/core/config/feature_flag_service.dart';

class MyService {
  final _flags = GetIt.instance.get<FeatureFlagService>();

  void doWork() {
    // Simple check
    if (_flags.isEnabled('modelSelection')) {
      // Feature code here
    }

    // Get config value
    final threshold = _flags.getConfig<double>(
      'enhancedFactChecking',
      'minimumConfidenceScore',
      defaultValue: 0.5,
    );

    // Use extension method
    if (_flags.isAdvancedAIAnalysisEnabled) {
      // Feature code here
    }
  }
}
```

### In Widgets (UI Code)

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_helix/core/config/feature_flag_provider.dart';

class MyWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch a flag
    final enabled = ref.watch(featureFlagProvider('modelSelection'));

    // Use convenience provider
    final showAdvanced = ref.watch(advancedAIAnalysisEnabledProvider);

    return Column(
      children: [
        if (enabled) Text('Feature is on!'),
        if (showAdvanced) AdvancedFeatures(),
      ],
    );
  }
}
```

## Adding a New Flag

### 1. Edit `feature_flags.json`

```json
{
  "flags": {
    "myFeature": {
      "enabled": true,
      "description": "My awesome new feature",
      "type": "feature",
      "metadata": {
        "category": "experimental",
        "requiresRestart": false
      },
      "variants": {
        "development": true,
        "staging": false,
        "production": false
      }
    }
  }
}
```

### 2. Use It

```dart
if (featureFlags.isEnabled('myFeature')) {
  // Your feature code
}
```

## Common Patterns

### Conditional Features

```dart
// In a widget
if (ref.watch(featureFlagProvider('voiceCommands'))) {
  return VoiceCommandButton();
}
return Container();
```

### Different Behavior Per Environment

Flags automatically use the right variant for your environment:
- Development: All experimental features
- Staging: Testing features
- Production: Only stable features

### A/B Testing

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

## Available Flags

| Flag | What It Does |
|------|--------------|
| `modelSelection` | Let users choose AI models |
| `advancedAIAnalysis` | Advanced sentiment/topic analysis |
| `enhancedFactChecking` | Multi-source fact checking |
| `whisperTranscription` | Use Whisper for transcription |
| `conversationInsights` | Real-time conversation summaries |
| `offlineMode` | Work without internet |
| `voiceCommands` | Hands-free voice control |
| `advancedLogging` | Detailed debug logs |
| `performanceMonitoring` | Track performance metrics |

## Testing

### Enable a Flag Temporarily

```dart
final flags = GetIt.instance.get<FeatureFlagService>();
flags.setOverride('myFeature', true);  // Enable
flags.setOverride('myFeature', false); // Disable
flags.removeOverride('myFeature');     // Back to normal
```

### Debug Panel

See all flags and their states:

```dart
import 'package:flutter_helix/core/config/feature_flag_examples.dart';

// Navigate to debug panel
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => FeatureFlagDebugPanel(),
  ),
);
```

## Need More Info?

See the full documentation: `/home/user/Helix-iOS/docs/dev/FEATURE_FLAGS.md`

## Troubleshooting

**Q: My flag isn't working?**
- Check `feature_flags.json` exists
- Verify `enabled: true` and correct `variants` for your environment
- Run code generation if you changed models

**Q: How do I know my environment?**
```dart
final env = featureFlags.currentEnvironment;
print(env); // Environment.development
```

**Q: Changes not showing?**
- Flags are cached for 5 minutes
- Reload: `await featureFlags.reload()`
