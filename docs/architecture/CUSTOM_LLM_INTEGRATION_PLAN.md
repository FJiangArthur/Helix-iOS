# Custom LLM Integration Plan - llm.art-ai.me

**Status**: Ready for Implementation
**Endpoint**: `https://llm.art-ai.me/v1/chat/completions`
**Validation**: ✅ All tests passed (3/3)
**Timeline**: 2-3 days for MVP

## Overview

This plan replaces the Azure OpenAI integration with a custom LLM router endpoint. The custom endpoint has been validated and supports OpenAI-compatible API with models: gpt-4.1, gpt-4.1-mini, o1, o1-mini, and Whisper.

## Configuration Architecture

### Security Strategy
- **Template File**: `llm_config.local.json.template` (committed to git)
- **Actual Config**: `llm_config.local.json` (gitignored)
- **Flutter Integration**: Load config at runtime from local file
- **Fallback**: Environment variables for CI/CD

### Configuration Structure
```json
{
  "llmEndpoint": "https://llm.art-ai.me/v1/chat/completions",
  "llmApiKey": "sk-YOUR-API-KEY-HERE",
  "llmModel": "gpt-4.1-mini",
  "llmModels": {
    "fast": "gpt-4.1-mini",
    "balanced": "gpt-4.1",
    "advanced": "o1",
    "reasoning": "o1-mini"
  },
  "transcription": {
    "whisperEndpoint": "https://llm.art-ai.me/v1/audio/transcriptions",
    "whisperModel": "whisper-1"
  }
}
```

## Phase 1: Configuration & Service Setup (Day 1)

### Step 1.1: Create Configuration Loader
**File**: `lib/core/config/app_config.dart` (NEW)

```dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';

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

  static Future<AppConfig> load() async {
    try {
      // Try to load from local file first
      final file = File('llm_config.local.json');
      if (await file.exists()) {
        final contents = await file.readAsString();
        final json = jsonDecode(contents);
        return _fromJson(json);
      }
    } catch (e) {
      print('Failed to load llm_config.local.json: $e');
    }

    // Fallback to environment variables
    final apiKey = const String.fromEnvironment('LLM_API_KEY');
    if (apiKey.isEmpty) {
      throw Exception('No configuration found. Create llm_config.local.json');
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
}
```

### Step 1.2: Update LLMServiceImplV2 to Use Config
**File**: `lib/services/implementations/llm_service_impl_v2.dart`

**Changes**:
1. Add config parameter to constructor
2. Remove hardcoded API keys
3. Use config values for endpoint and model selection

```dart
class LLMServiceImplV2 implements LLMService {
  final AppConfig config;
  final OpenAIProvider _openAIProvider;

  LLMServiceImplV2({required this.config})
      : _openAIProvider = OpenAIProvider(
          apiKey: config.llmApiKey,
          baseUrl: config.llmEndpoint,
        );

  // ... rest of implementation
}
```

### Step 1.3: Update Service Locator
**File**: `lib/services/service_locator.dart`

```dart
Future<void> setupServiceLocator() async {
  final getIt = GetIt.instance;

  // Load config first
  final config = await AppConfig.load();
  getIt.registerSingleton<AppConfig>(config);

  // Initialize services with config
  getIt.registerLazySingleton<LLMServiceImplV2>(
    () => LLMServiceImplV2(config: getIt.get<AppConfig>()),
  );

  getIt.registerLazySingleton<FactCheckingService>(
    () => FactCheckingService(
      llmService: getIt.get<LLMServiceImplV2>(),
    ),
  );

  getIt.registerLazySingleton<AIInsightsService>(
    () => AIInsightsService(
      llmService: getIt.get<LLMServiceImplV2>(),
    ),
  );

  getIt.registerLazySingleton<TranscriptionCoordinator>(
    () => TranscriptionCoordinator(
      nativeService: NativeTranscriptionService(),
      whisperService: WhisperTranscriptionService(
        apiKey: config.llmApiKey,
        endpoint: config.whisperEndpoint ??
                  '${config.llmEndpoint.replaceAll('/chat/completions', '')}/audio/transcriptions',
      ),
    ),
  );
}
```

### Step 1.4: Initialize in main()
**File**: `lib/main.dart`

```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize services
  await setupServiceLocator();

  _initializeBleManager();

  runApp(const HelixApp());
}
```

## Phase 2: Minimal AI Integration (Day 1-2)

### Step 2.1: Create Simple Analysis Provider
**File**: `lib/features/conversation/presentation/providers/analysis_provider.dart` (NEW)

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import '../../../../services/implementations/llm_service_impl_v2.dart';

final analysisProvider = StateNotifierProvider<AnalysisNotifier, AnalysisState>((ref) {
  return AnalysisNotifier();
});

class AnalysisState {
  final String? summary;
  final List<String> actionItems;
  final bool isAnalyzing;
  final String? error;

  AnalysisState({
    this.summary,
    this.actionItems = const [],
    this.isAnalyzing = false,
    this.error,
  });

  AnalysisState copyWith({
    String? summary,
    List<String>? actionItems,
    bool? isAnalyzing,
    String? error,
  }) {
    return AnalysisState(
      summary: summary ?? this.summary,
      actionItems: actionItems ?? this.actionItems,
      isAnalyzing: isAnalyzing ?? this.isAnalyzing,
      error: error ?? this.error,
    );
  }
}

class AnalysisNotifier extends StateNotifier<AnalysisState> {
  AnalysisNotifier() : super(AnalysisState());

  final _llmService = GetIt.instance.get<LLMServiceImplV2>();

  Future<void> analyzeConversation(String transcription) async {
    state = state.copyWith(isAnalyzing: true, error: null);

    try {
      final result = await _llmService.analyzeConversation(
        transcription,
        type: AnalysisType.quick,
        priority: AnalysisPriority.normal,
      );

      state = state.copyWith(
        isAnalyzing: false,
        summary: result.summary,
        actionItems: result.actionItems,
      );
    } catch (e) {
      state = state.copyWith(
        isAnalyzing: false,
        error: e.toString(),
      );
    }
  }

  void reset() {
    state = AnalysisState();
  }
}
```

### Step 2.2: Connect Recording to Transcription
**File**: Update `lib/features/conversation/presentation/conversation_tab.dart`

Add transcription trigger when recording stops:

```dart
// In _RecordingScreenState or wherever recording is managed

Future<void> _stopRecording() async {
  await _audioService.stopRecording();

  // Get the audio file path
  final audioPath = _audioService.currentRecordingPath;
  if (audioPath != null) {
    _transcribeAudio(audioPath);
  }
}

Future<void> _transcribeAudio(String audioPath) async {
  setState(() => _isTranscribing = true);

  try {
    final transcriptionService = GetIt.instance.get<TranscriptionCoordinator>();
    final result = await transcriptionService.transcribeAudio(audioPath);

    if (result.text.isNotEmpty) {
      // Trigger AI analysis
      ref.read(analysisProvider.notifier).analyzeConversation(result.text);
    }
  } catch (e) {
    print('Transcription failed: $e');
  } finally {
    setState(() => _isTranscribing = false);
  }
}
```

### Step 2.3: Display Analysis Results
Add to conversation UI:

```dart
// In conversation_tab.dart UI

Consumer(
  builder: (context, ref, child) {
    final analysis = ref.watch(analysisProvider);

    if (analysis.isAnalyzing) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (analysis.error != null) {
      return Text('Error: ${analysis.error}');
    }

    if (analysis.summary != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Summary:', style: Theme.of(context).textTheme.titleMedium),
          Text(analysis.summary!),
          const SizedBox(height: 16),
          if (analysis.actionItems.isNotEmpty) ...[
            Text('Action Items:', style: Theme.of(context).textTheme.titleMedium),
            ...analysis.actionItems.map((item) =>
              Text('• $item')
            ),
          ],
        ],
      );
    }

    return const Text('Record a conversation to see analysis');
  },
)
```

## Phase 3: Testing (Day 2-3)

### Test Cases

1. **Configuration Loading**
   - [ ] App loads with `settings.local.json` present
   - [ ] App shows error if config missing
   - [ ] Config values are correctly loaded

2. **Recording → Transcription**
   - [ ] Audio recording completes successfully
   - [ ] Transcription is triggered after recording
   - [ ] Transcription text is received

3. **Transcription → AI Analysis**
   - [ ] Analysis starts after transcription
   - [ ] Loading indicator shows during analysis
   - [ ] Results display correctly

4. **Error Handling**
   - [ ] Network errors show friendly message
   - [ ] API errors are logged
   - [ ] App doesn't crash on failures

### Manual Testing Steps

1. Verify `llm_config.local.json` exists with your API key (already created)
2. Run app: `flutter run -d 00008150-001514CC3C00401C`
3. Press record button
4. Speak for 10-15 seconds
5. Stop recording
6. Verify transcription appears
7. Verify AI analysis appears within 2-3 seconds
8. Check console for any errors

## Phase 4: Optimization (Day 3+)

### Performance Improvements
- Cache analysis results
- Implement request debouncing
- Add streaming responses for real-time feedback
- Optimize model selection based on content length

### UI Enhancements
- Add skeleton loaders
- Show partial results as they arrive
- Add ability to regenerate analysis
- Display confidence scores

## Security Checklist

- [x] `llm_config.local.json` is in `.gitignore`
- [x] Template file has placeholder API key
- [x] No hardcoded credentials in code
- [ ] Environment variable fallback implemented
- [ ] API key validation on startup
- [ ] Secure storage for production (Keychain/Keystore)

## Rollback Plan

If integration fails:
1. Keep audio recording functional (already working)
2. Disable AI features gracefully
3. Show "AI features unavailable" message
4. Log errors for debugging

## Success Criteria

- [x] Custom LLM endpoint validated (Python tests passed)
- [ ] Config loading working
- [ ] Recording triggers transcription
- [ ] Transcription triggers AI analysis
- [ ] Results display in UI
- [ ] No API keys in git commits
- [ ] App stable with features enabled

## Next Steps After MVP

1. Add conversation history with analysis
2. Implement real-time streaming analysis
3. Add multiple analysis modes (quick, detailed, fact-check)
4. Integrate with smart glasses HUD
5. Add offline mode with cached responses
