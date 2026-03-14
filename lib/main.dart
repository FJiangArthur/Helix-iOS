import 'package:flutter/material.dart';

import 'app.dart';
import 'ble_manager.dart';
import 'services/llm/llm_service.dart';
import 'services/settings_manager.dart';
import 'services/conversation_engine.dart';
import 'services/dashboard_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize settings first (loads persisted preferences)
  await SettingsManager.instance.initialize();

  // Initialize BLE manager
  _initializeBleManager();

  // Initialize LLM service and wire to conversation engine
  await _initializeLlmService();

  // Initialize the glasses tilt dashboard listeners
  await DashboardService.instance.initialize();

  runApp(const HelixApp());
}

void _initializeBleManager() {
  final bleManager = BleManager.get();
  bleManager.setMethodCallHandler();
  bleManager.startListening();
}

Future<void> _initializeLlmService() async {
  final llmService = LlmService.instance;
  llmService.initializeDefaults();

  final settings = SettingsManager.instance;

  // Load API keys from secure storage and configure providers
  for (final providerId in [
    'openai',
    'anthropic',
    'deepseek',
    'qwen',
    'zhipu',
  ]) {
    final apiKey = await settings.getApiKey(providerId);
    if (apiKey != null && apiKey.isNotEmpty) {
      llmService.setApiKey(providerId, apiKey);
    }
  }

  // Set active provider from settings
  try {
    llmService.setActiveProvider(
      settings.activeProviderId,
      model: settings.activeModel,
    );
  } catch (e) {
    // Provider not registered, fall back to openai
    llmService.setActiveProvider('openai');
  }

  // Wire LlmService into ConversationEngine
  ConversationEngine.setLlmServiceGetter(() => LlmService.instance);

  // Apply conversation settings
  final engine = ConversationEngine.instance;
  engine.autoDetectQuestions = settings.autoDetectQuestions;
  engine.autoAnswerQuestions = settings.autoAnswerQuestions;
}
