// ABOUTME: Examples of how to use feature flags in the application
// ABOUTME: This file demonstrates various usage patterns for feature flags

// ignore_for_file: avoid_print

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import 'feature_flag_service.dart';
import 'feature_flag_provider.dart';
import 'feature_flag_models.dart';

/// Example 1: Using feature flags with GetIt (in services)
class ExampleService {
  final FeatureFlagService _featureFlags;

  ExampleService() : _featureFlags = GetIt.instance.get<FeatureFlagService>();

  Future<void> processData() async {
    // Check if advanced AI analysis is enabled
    if (_featureFlags.isAdvancedAIAnalysisEnabled) {
      print('Using advanced AI analysis');
      // Use advanced analysis
    } else {
      print('Using basic analysis');
      // Use basic analysis
    }

    // Get configuration value
    final minConfidence = _featureFlags.getConfig<double>(
      'enhancedFactChecking',
      'minimumConfidenceScore',
      defaultValue: 0.5,
    );
    print('Using confidence threshold: $minConfidence');

    // Check multiple flags
    if (_featureFlags.isWhisperTranscriptionEnabled &&
        _featureFlags.fallbackToNative == true) {
      print('Whisper enabled with native fallback');
    }
  }
}

/// Example 2: Using feature flags with Riverpod in widgets
class ExampleWidget extends ConsumerWidget {
  const ExampleWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch a specific feature flag
    final isModelSelectionEnabled = ref.watch(modelSelectionEnabledProvider);

    // Watch available models if model selection is enabled
    final availableModels = ref.watch(availableModelsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Feature Flag Example'),
      ),
      body: Column(
        children: [
          // Conditionally show UI based on feature flag
          if (isModelSelectionEnabled)
            DropdownButton<String>(
              items: availableModels
                      ?.map((model) => DropdownMenuItem(
                            value: model,
                            child: Text(model),
                          ))
                      .toList() ??
                  [],
              onChanged: (value) {
                // Handle model selection
              },
            ),

          // Show different UI based on flag
          ref.watch(featureFlagProvider('abTestNewUI'))
              ? const NewUIComponent()
              : const ClassicUIComponent(),

          // Use flag config in UI
          Consumer(
            builder: (context, ref, child) {
              final config = ref.watch(
                  featureFlagConfigProvider('conversationInsights'));
              final interval = config?.config['summarizationInterval'] ?? 60;

              return Text('Summary every $interval seconds');
            },
          ),
        ],
      ),
    );
  }
}

/// Example 3: Conditional feature rendering
class FeatureGatedWidget extends ConsumerWidget {
  const FeatureGatedWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Get feature flag service
    final featureFlags = ref.watch(featureFlagServiceProvider);

    return Column(
      children: [
        // Voice commands button (only if enabled)
        if (featureFlags.isVoiceCommandsEnabled)
          ElevatedButton(
            onPressed: () {
              // Handle voice command
            },
            child: const Text('Voice Commands'),
          ),

        // Beta features badge
        if (featureFlags.areBetaFeaturesEnabled)
          const Chip(
            label: Text('Beta'),
            backgroundColor: Colors.orange,
          ),

        // Performance monitoring widget
        if (featureFlags.isPerformanceMonitoringEnabled)
          const PerformanceMonitorWidget(),
      ],
    );
  }
}

/// Example 4: Using feature flags in initialization
class ExampleApp extends StatefulWidget {
  const ExampleApp({super.key});

  @override
  State<ExampleApp> createState() => _ExampleAppState();
}

class _ExampleAppState extends State<ExampleApp> {
  late FeatureFlagService _featureFlags;

  @override
  void initState() {
    super.initState();
    _featureFlags = GetIt.instance.get<FeatureFlagService>();
    _configureBasedOnFlags();
  }

  void _configureBasedOnFlags() {
    // Configure logging based on flag
    if (_featureFlags.isAdvancedLoggingEnabled) {
      final logLevel = _featureFlags.logLevel ?? 'info';
      print('Configuring logger with level: $logLevel');
      // Configure logger
    }

    // Set up performance monitoring
    if (_featureFlags.isPerformanceMonitoringEnabled) {
      final sampleRate = _featureFlags.getConfig<double>(
        'performanceMonitoring',
        'sampleRate',
        defaultValue: 1.0,
      );
      print('Performance monitoring enabled with sample rate: $sampleRate');
      // Initialize monitoring
    }
  }

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: ExampleWidget(),
    );
  }
}

/// Example 5: Feature flag debugging widget
class FeatureFlagDebugPanel extends ConsumerWidget {
  const FeatureFlagDebugPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final featureFlags = ref.watch(featureFlagServiceProvider);
    final enabledFlags = ref.watch(enabledFlagsProvider);
    final currentEnv = ref.watch(currentEnvironmentProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Feature Flags Debug'),
      ),
      body: ListView(
        children: [
          ListTile(
            title: const Text('Current Environment'),
            subtitle: Text(currentEnv.toString()),
          ),
          const Divider(),
          ListTile(
            title: Text('Enabled Flags (${enabledFlags.length})'),
          ),
          ...enabledFlags.map((flagKey) {
            final flag = featureFlags.getFlag(flagKey);
            return ListTile(
              title: Text(flagKey),
              subtitle: Text(flag?.description ?? ''),
              trailing: Switch(
                value: true,
                onChanged: (value) {
                  // Allow toggling for testing
                  if (value) {
                    featureFlags.removeOverride(flagKey);
                  } else {
                    featureFlags.setOverride(flagKey, false);
                  }
                },
              ),
            );
          }),
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton(
              onPressed: () {
                // Export state for debugging
                final state = featureFlags.exportState();
                print('Feature Flag State: $state');
              },
              child: const Text('Export State'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Example 6: Environment-specific configuration
class EnvironmentConfigExample {
  final FeatureFlagService _featureFlags;

  EnvironmentConfigExample()
      : _featureFlags = GetIt.instance.get<FeatureFlagService>();

  void configureForEnvironment() {
    final env = _featureFlags.currentEnvironment;

    switch (env) {
      case Environment.development:
        // Enable all debug features
        print('Development mode: all debug features enabled');
        break;
      case Environment.staging:
        // Enable some debug features
        print('Staging mode: limited debug features');
        break;
      case Environment.production:
        // Disable debug features
        print('Production mode: debug features disabled');
        break;
    }
  }

  // Override environment for testing
  void switchToStaging() {
    _featureFlags.setEnvironment(Environment.staging);
    print('Switched to staging environment');
  }
}

/// Example 7: A/B Testing
class ABTestingExample extends ConsumerWidget {
  const ABTestingExample({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final featureFlags = ref.watch(featureFlagServiceProvider);
    final isModelComparisonEnabled =
        ref.watch(featureFlagProvider('abTestModelComparison'));

    if (!isModelComparisonEnabled) {
      return const Text('A/B test not active');
    }

    // Get A/B test configuration
    final modelA = featureFlags.getConfig<String>(
      'abTestModelComparison',
      'modelA',
      defaultValue: 'gpt-4.1-mini',
    );
    final modelB = featureFlags.getConfig<String>(
      'abTestModelComparison',
      'modelB',
      defaultValue: 'gpt-5',
    );
    final sampleRate = featureFlags.getConfig<double>(
      'abTestModelComparison',
      'sampleRate',
      defaultValue: 0.5,
    );

    // Randomly assign variant based on sample rate
    final useModelB = _shouldUseVariantB(sampleRate ?? 0.5);

    return Text(
      'Using model: ${useModelB ? modelB : modelA}',
    );
  }

  bool _shouldUseVariantB(double sampleRate) {
    // In production, use a proper A/B testing library
    // This is just for demonstration
    return DateTime.now().millisecondsSinceEpoch % 100 < (sampleRate * 100);
  }
}

// Placeholder widgets
class NewUIComponent extends StatelessWidget {
  const NewUIComponent({super.key});

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Text('New UI Design'),
      ),
    );
  }
}

class ClassicUIComponent extends StatelessWidget {
  const ClassicUIComponent({super.key});

  @override
  Widget build(BuildContext context) {
    return const ListTile(
      title: Text('Classic UI Design'),
    );
  }
}

class PerformanceMonitorWidget extends StatelessWidget {
  const PerformanceMonitorWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(8.0),
        child: Text('Performance: 60 FPS'),
      ),
    );
  }
}
