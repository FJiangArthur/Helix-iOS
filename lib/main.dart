import 'package:flutter/material.dart';

import 'app.dart';
import 'ble_manager.dart';
import 'services/hud_widget_registry.dart';
import 'services/hud_widgets/battery_widget.dart';
import 'services/hud_widgets/calendar_widget.dart';
import 'services/hud_widgets/clock_widget.dart';
import 'services/hud_widgets/news_widget.dart';
import 'services/hud_widgets/reminders_widget.dart';
import 'services/hud_widgets/todos_widget.dart';
import 'services/hud_widgets/weather_widget.dart';
import 'services/llm/llm_service.dart';
import 'services/settings_manager.dart';
import 'services/conversation_engine.dart';
import 'services/bitmap_hud/bitmap_hud_service.dart';
import 'services/dashboard_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize settings first (loads persisted preferences)
  await SettingsManager.instance.initialize();

  // Initialize BLE manager
  _initializeBleManager();

  // Initialize HUD widget registry (before dashboard service)
  await _initializeHudWidgets();

  // Initialize LLM service and wire to conversation engine
  await _initializeLlmService();

  // Initialize bitmap HUD service (registers bitmap widgets, starts timers)
  await BitmapHudService.instance.initialize();

  // Initialize the glasses tilt dashboard listeners
  await DashboardService.instance.initialize();

  runApp(const HelixApp());
}

Future<void> _initializeHudWidgets() async {
  final registry = HudWidgetRegistry.instance;
  registry.register(ClockWidget());
  registry.register(CalendarWidget());
  registry.register(WeatherWidget());
  registry.register(RemindersWidget());
  registry.register(TodosWidget());
  registry.register(NewsWidget());
  registry.register(BatteryWidget());
  await registry.initialize();
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
