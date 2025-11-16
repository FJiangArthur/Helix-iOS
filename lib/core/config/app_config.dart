import 'dart:convert';
import 'dart:io';

import '../../utils/app_logger.dart';

/// Application configuration loaded from llm_config.local.json
/// Falls back to environment variables if file not found
class AppConfig {
  final String llmEndpoint;
  final String llmApiKey;
  final String defaultModel;
  final Map<String, String> models;
  final String? whisperEndpoint;
  final String? whisperModel;

  AppConfig({
    required this.llmEndpoint,
    required this.llmApiKey,
    required this.defaultModel,
    required this.models,
    this.whisperEndpoint,
    this.whisperModel,
  });

  /// Load configuration from file or environment variables
  static Future<AppConfig> load() async {
    try {
      // Try to load from local file first
      final File file = File('llm_config.local.json');
      if (await file.exists()) {
        final String contents = await file.readAsString();
        final dynamic json = jsonDecode(contents);
        return _fromJson(json);
      }
    } catch (e) {
      appLogger.w('Failed to load llm_config.local.json', error: e);
    }

    // Fallback to environment variables
    final apiKey = const String.fromEnvironment('LLM_API_KEY');
    if (apiKey.isEmpty) {
      throw Exception(
        'No configuration found. Create llm_config.local.json from template',
      );
    }

    return AppConfig(
      llmEndpoint: const String.fromEnvironment(
        'LLM_ENDPOINT',
        defaultValue: 'https://llm.art-ai.me/v1/chat/completions',
      ),
      llmApiKey: apiKey,
      defaultModel: const String.fromEnvironment(
        'LLM_MODEL',
        defaultValue: 'gpt-4.1-mini',
      ),
      models: {
        'fast': 'gpt-4.1-mini',
        'balanced': 'gpt-4.1',
        'advanced': 'o1',
        'reasoning': 'o1-mini',
      },
    );
  }

  static AppConfig _fromJson(Map<String, dynamic> json) {
    return AppConfig(
      llmEndpoint: json['llmEndpoint'] as String,
      llmApiKey: json['llmApiKey'] as String,
      defaultModel: json['llmModel'] as String,
      models: Map<String, String>.from(json['llmModels'] as Map),
      whisperEndpoint: json['transcription']?['whisperEndpoint'] as String?,
      whisperModel: json['transcription']?['whisperModel'] as String?,
    );
  }

  /// Get model name for a specific use case
  String getModel(String type) {
    return models[type] ?? defaultModel;
  }

  @override
  String toString() {
    return 'AppConfig(endpoint: $llmEndpoint, model: $defaultModel, hasWhisper: ${whisperEndpoint != null})';
  }
}
