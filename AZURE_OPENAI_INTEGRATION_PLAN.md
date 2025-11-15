# Azure OpenAI Integration Plan - Helix App

**Date**: 2025-11-14
**Goal**: Connect recording → transcription → AI analysis using Azure OpenAI API
**Timeline**: 2-3 hours on-campus implementation

---

## Prerequisites

### 1. Azure OpenAI API Access (Required)

You'll need these from your Azure OpenAI resource:

```json
{
  "azureOpenAIEndpoint": "https://YOUR-RESOURCE-NAME.openai.azure.com/",
  "azureOpenAIKey": "your-azure-api-key-here",
  "azureDeploymentName": "gpt-4",  // or your deployment name
  "azureApiVersion": "2024-02-15-preview"
}
```

**Where to put these**: `settings.local.json` (already gitignored)

### 2. Current Code Status

✅ **Working**:
- Audio recording (AudioServiceImpl)
- LLMServiceImplV2 (supports OpenAI)
- TranscriptionCoordinator (Native + Whisper)
- AIInsightsService

❌ **Not Connected**:
- Services not initialized in main()
- Recording doesn't trigger transcription
- No AI analysis displayed in UI

---

## Implementation Plan

### Phase 1: Azure OpenAI Provider Setup (30 min)

#### Step 1.1: Create Azure OpenAI Provider

**File**: `lib/services/ai_providers/azure_openai_provider.dart`

```dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'base_provider.dart';
import '../../models/analysis_result.dart';
import '../../core/utils/logging_service.dart';

class AzureOpenAIProvider extends BaseAIProvider {
  final String endpoint;
  final String apiKey;
  final String deploymentName;
  final String apiVersion;

  AzureOpenAIProvider({
    required this.endpoint,
    required this.apiKey,
    required this.deploymentName,
    required this.apiVersion,
    required LoggingService logger,
  }) : super(logger: logger, providerName: 'AzureOpenAI');

  @override
  Future<void> initialize(String apiKey) async {
    // Already initialized in constructor
    isAvailable = true;
  }

  @override
  Future<String> sendCompletion({required String prompt}) async {
    final url = Uri.parse(
      '$endpoint/openai/deployments/$deploymentName/chat/completions?api-version=$apiVersion'
    );

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'api-key': apiKey,
      },
      body: jsonEncode({
        'messages': [
          {'role': 'user', 'content': prompt}
        ],
        'max_tokens': 800,
        'temperature': 0.7,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['choices'][0]['message']['content'];
    } else {
      throw Exception('Azure OpenAI API error: ${response.statusCode} ${response.body}');
    }
  }

  // Implement other required methods from BaseAIProvider
  // For now, use sendCompletion as base and parse results

  @override
  Future<ConversationSummary> generateSummary({
    required String text,
    int maxWords = 200,
    bool includeKeyPoints = true,
    bool includeActionItems = true,
  }) async {
    final prompt = '''
Summarize this conversation in $maxWords words:

$text

${includeKeyPoints ? 'Include 3-5 key points.' : ''}
${includeActionItems ? 'Include action items if any.' : ''}
''';

    final result = await sendCompletion(prompt: prompt);

    return ConversationSummary(
      text: result,
      keyPoints: includeKeyPoints ? _extractKeyPoints(result) : [],
      actionItems: includeActionItems ? _extractActionItems(result) : [],
      topics: _extractTopics(result),
      wordCount: result.split(' ').length,
    );
  }

  @override
  Future<FactCheckResult> verifyFact({required String claim}) async {
    final prompt = '''
Fact-check this claim: "$claim"

Respond with:
1. Status: TRUE, FALSE, UNCERTAIN, or NEEDS_CONTEXT
2. Confidence: 0.0 to 1.0
3. Explanation: Brief explanation

Format: STATUS|CONFIDENCE|EXPLANATION
''';

    final result = await sendCompletion(prompt: prompt);
    final parts = result.split('|');

    return FactCheckResult(
      id: 'fact_${DateTime.now().millisecondsSinceEpoch}',
      claim: claim,
      status: _parseFactStatus(parts[0].trim()),
      confidence: double.tryParse(parts[1].trim()) ?? 0.5,
      explanation: parts.length > 2 ? parts[2].trim() : result,
    );
  }

  FactCheckStatus _parseFactStatus(String status) {
    switch (status.toUpperCase()) {
      case 'TRUE': return FactCheckStatus.verified;
      case 'FALSE': return FactCheckStatus.false_info;
      case 'UNCERTAIN': return FactCheckStatus.uncertain;
      default: return FactCheckStatus.needs_context;
    }
  }

  List<String> _extractKeyPoints(String text) {
    // Simple extraction - look for numbered points
    final lines = text.split('\n');
    return lines
        .where((line) => line.trim().startsWith(RegExp(r'\d+\.|•|-')))
        .map((line) => line.trim())
        .toList();
  }

  List<ActionItemResult> _extractActionItems(String text) {
    // Look for action-oriented phrases
    final actionWords = ['action', 'todo', 'task', 'need to', 'should', 'must'];
    final lines = text.toLowerCase().split('\n');

    return lines
        .where((line) => actionWords.any((word) => line.contains(word)))
        .map((line) => ActionItemResult(
          id: 'action_${DateTime.now().millisecondsSinceEpoch}',
          description: line.trim(),
          priority: ActionPriority.medium,
        ))
        .toList();
  }

  List<String> _extractTopics(String text) {
    // Simple topic extraction - just return first few capitalized words
    final words = text.split(' ');
    return words
        .where((w) => w.length > 3 && w[0].toUpperCase() == w[0])
        .take(5)
        .toList();
  }

  // Implement remaining BaseAIProvider methods similarly
  @override
  Future<List<String>> detectClaims({required String text}) async {
    final prompt = 'Extract factual claims from: $text';
    final result = await sendCompletion(prompt: prompt);
    return result.split('\n').where((s) => s.isNotEmpty).toList();
  }

  @override
  Future<List<ActionItemResult>> extractActionItems({
    required String text,
    bool includeDeadlines = true,
    bool includePriority = true,
  }) async {
    final prompt = 'Extract action items from: $text';
    final result = await sendCompletion(prompt: prompt);
    return _extractActionItems(result);
  }

  @override
  Future<SentimentAnalysisResult> analyzeSentiment({required String text}) async {
    final prompt = '''
Analyze sentiment of: "$text"
Respond: POSITIVE|NEGATIVE|NEUTRAL|score (0-1)
''';
    final result = await sendCompletion(prompt: prompt);
    final parts = result.split('|');

    return SentimentAnalysisResult(
      overall: _parseSentiment(parts[0]),
      score: double.tryParse(parts[1]) ?? 0.5,
    );
  }

  Sentiment _parseSentiment(String s) {
    switch (s.trim().toUpperCase()) {
      case 'POSITIVE': return Sentiment.positive;
      case 'NEGATIVE': return Sentiment.negative;
      default: return Sentiment.neutral;
    }
  }

  @override
  Future<Map<String, dynamic>> getUsageStats() async {
    return {
      'provider': 'AzureOpenAI',
      'endpoint': endpoint,
      'deployment': deploymentName,
    };
  }

  @override
  Future<void> dispose() async {
    isAvailable = false;
  }
}
```

#### Step 1.2: Update LLMServiceImplV2 to Support Azure

**File**: `lib/services/implementations/llm_service_impl_v2.dart`

Add Azure provider initialization:

```dart
// Add to imports
import '../ai_providers/azure_openai_provider.dart';

// In LLMServiceImplV2 class, add field:
late final AzureOpenAIProvider? _azureProvider;

// Update initialize() method:
@override
Future<void> initialize({
  String? openAIKey,
  String? anthropicKey,
  String? azureEndpoint,
  String? azureKey,
  String? azureDeployment,
  LLMProvider? preferredProvider,
}) async {
  try {
    _logger.log(_tag, 'Initializing enhanced LLM service', LogLevel.info);

    _preferredProvider = preferredProvider ?? LLMProvider.openai;
    _currentProvider = _preferredProvider!;

    // Initialize Azure OpenAI if credentials provided
    if (azureEndpoint != null && azureKey != null && azureDeployment != null) {
      _azureProvider = AzureOpenAIProvider(
        endpoint: azureEndpoint,
        apiKey: azureKey,
        deploymentName: azureDeployment,
        apiVersion: '2024-02-15-preview',
        logger: _logger,
      );
      await _azureProvider!.initialize(azureKey);
      _providers[LLMProvider.azureOpenAI] = _azureProvider!;
      _logger.log(_tag, 'Azure OpenAI provider initialized', LogLevel.info);

      // Use Azure as current provider
      _currentProvider = LLMProvider.azureOpenAI;
    }

    // Rest of initialization...
  }
}
```

#### Step 1.3: Add Azure Config to settings.local.json

**File**: `settings.local.json`

```json
{
  "azureOpenAIEndpoint": "https://YOUR-RESOURCE.openai.azure.com/",
  "azureOpenAIKey": "paste-your-key-here",
  "azureDeploymentName": "gpt-4",
  "azureApiVersion": "2024-02-15-preview"
}
```

---

### Phase 2: Initialize Services in main() (15 min)

#### Step 2.1: Update main.dart

**File**: `lib/main.dart`

```dart
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter/services.dart';

import 'app.dart';
import 'ble_manager.dart';
import 'services/service_locator.dart';
import 'services/implementations/llm_service_impl_v2.dart';
import 'services/transcription/transcription_coordinator.dart';
import 'core/utils/logging_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize logging
  final logger = LoggingService.instance;

  // Load Azure OpenAI config
  final config = await _loadConfig();

  // Initialize service locator
  await setupServiceLocator();

  // Initialize LLM service with Azure OpenAI
  final llmService = ServiceLocator.instance.get<LLMServiceImplV2>();
  await llmService.initialize(
    azureEndpoint: config['azureOpenAIEndpoint'],
    azureKey: config['azureOpenAIKey'],
    azureDeployment: config['azureDeploymentName'],
    preferredProvider: LLMProvider.azureOpenAI,
  );

  logger.log('main', 'LLM service initialized with Azure OpenAI', LogLevel.info);

  // Initialize TranscriptionCoordinator
  final transcriptionCoord = TranscriptionCoordinator.instance;
  await transcriptionCoord.initialize();

  logger.log('main', 'Transcription coordinator initialized', LogLevel.info);

  // Initialize BLE manager
  _initializeBleManager();

  runApp(const HelixApp());
}

Future<Map<String, String>> _loadConfig() async {
  try {
    final jsonString = await rootBundle.loadString('settings.local.json');
    final jsonData = json.decode(jsonString) as Map<String, dynamic>;
    return jsonData.map((k, v) => MapEntry(k, v.toString()));
  } catch (e) {
    print('⚠️  Failed to load settings.local.json: $e');
    print('⚠️  Make sure you have Azure OpenAI credentials configured!');
    return {};
  }
}

void _initializeBleManager() {
  final bleManager = BleManager.get();
  bleManager.setMethodCallHandler();
  bleManager.startListening();
}
```

#### Step 2.2: Update pubspec.yaml

Make sure `settings.local.json` is included:

```yaml
flutter:
  assets:
    - settings.local.json
```

---

### Phase 3: Connect Recording to Transcription (30 min)

#### Step 3.1: Create Simple Transcription Service

Since Azure OpenAI doesn't have Whisper API directly, we'll use native iOS transcription first, then optionally add Azure Speech later.

**File**: `lib/screens/recording_screen.dart`

Add transcription integration:

```dart
import '../services/transcription/transcription_coordinator.dart';
import '../services/service_locator.dart';
import '../services/implementations/llm_service_impl_v2.dart';

class _RecordingScreenState extends State<RecordingScreen> {
  // ... existing fields ...

  final _transcriptionCoord = TranscriptionCoordinator.instance;
  LLMServiceImplV2? _llmService;
  String _transcriptionText = '';
  String _aiAnalysis = '';

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    await _initializeAudioService();

    // Get LLM service from service locator
    try {
      _llmService = ServiceLocator.instance.get<LLMServiceImplV2>();

      // Subscribe to transcription stream
      _transcriptionCoord.transcriptStream.listen((segment) {
        setState(() {
          _transcriptionText += segment.text + ' ';
        });

        // Trigger AI analysis every 10 words
        if (_transcriptionText.split(' ').length % 10 == 0) {
          _analyzeTranscript();
        }
      });
    } catch (e) {
      print('Failed to get LLM service: $e');
    }
  }

  Future<void> _analyzeTranscript() async {
    if (_llmService == null || _transcriptionText.isEmpty) return;

    try {
      final result = await _llmService!.analyzeConversation(
        _transcriptionText,
        type: AnalysisType.summary,
      );

      setState(() {
        _aiAnalysis = result.summary?.text ?? 'No analysis available';
      });
    } catch (e) {
      print('AI analysis failed: $e');
    }
  }

  Future<void> _toggleRecording() async {
    if (!_isInitialized) return;

    try {
      if (_isRecording) {
        // Stop recording
        await _audioService.stopRecording();
        await _transcriptionCoord.stopTranscription();

        // Final analysis
        await _analyzeTranscript();

        setState(() {
          _isRecording = false;
          _recordingDuration = Duration.zero;
          _audioLevel = 0.0;
        });

        // Show results
        if (mounted) {
          _showResultsDialog();
        }
      } else {
        // Start recording AND transcription
        await _audioService.startRecording();
        await _transcriptionCoord.startTranscription(languageCode: 'en-US');

        setState(() {
          _isRecording = true;
          _transcriptionText = '';
          _aiAnalysis = '';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: $e';
        _isRecording = false;
      });
    }
  }

  void _showResultsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Recording Analysis'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Transcription:',
                style: TextStyle(fontWeight: FontWeight.bold)),
              Text(_transcriptionText.isEmpty ? 'No speech detected' : _transcriptionText),
              const SizedBox(height: 16),
              const Text('AI Analysis:',
                style: TextStyle(fontWeight: FontWeight.bold)),
              Text(_aiAnalysis.isEmpty ? 'No analysis available' : _aiAnalysis),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  // Add to build() method to show real-time transcription
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Recording')),
      body: Column(
        children: [
          // ... existing recording UI ...

          // Add real-time transcription display
          if (_isRecording && _transcriptionText.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Transcription:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(_transcriptionText),

                  if (_aiAnalysis.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Text('AI Analysis:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(_aiAnalysis),
                  ],
                ],
              ),
            ),

          // ... rest of UI ...
        ],
      ),
    );
  }
}
```

---

### Phase 4: Add LLMProvider Enum (5 min)

**File**: `lib/core/utils/constants.dart` (create if doesn't exist)

```dart
enum LLMProvider {
  openai,
  anthropic,
  azureOpenAI,
}
```

---

## Testing Steps (On Campus)

### 1. Configure Azure OpenAI (5 min)

Edit `settings.local.json`:
```json
{
  "azureOpenAIEndpoint": "https://your-resource.openai.azure.com/",
  "azureOpenAIKey": "your-actual-key",
  "azureDeploymentName": "gpt-4",
  "azureApiVersion": "2024-02-15-preview"
}
```

### 2. Build and Run (2 min)

```bash
flutter run -d 00008150-001514CC3C00401C
```

### 3. Test Recording + AI Analysis (5 min)

1. Open app
2. Go to Recording tab
3. Tap record button
4. **Speak clearly**: "Today we discussed the new feature roadmap. We need to complete the API integration by next Friday."
5. Tap stop
6. **Expected**: Dialog shows:
   - Transcription of your speech
   - AI summary/analysis

### 4. Debug if Failed

Check logs for:
```bash
flutter logs | grep "LLM\|Azure\|Transcription"
```

Common issues:
- ❌ `401 Unauthorized` → Check API key
- ❌ `404 Not Found` → Check deployment name
- ❌ `No transcription` → Check microphone permission
- ❌ `Service not initialized` → Check main() initialization

---

## File Checklist

Before testing, make sure these files exist/are modified:

- [ ] `lib/services/ai_providers/azure_openai_provider.dart` (NEW)
- [ ] `lib/services/implementations/llm_service_impl_v2.dart` (MODIFIED)
- [ ] `lib/main.dart` (MODIFIED)
- [ ] `lib/screens/recording_screen.dart` (MODIFIED)
- [ ] `lib/core/utils/constants.dart` (NEW - add LLMProvider enum)
- [ ] `settings.local.json` (MODIFIED - add Azure config)
- [ ] `pubspec.yaml` (MODIFIED - add assets)

---

## Success Criteria

✅ App starts without errors
✅ Recording works (no crash)
✅ Native transcription appears in real-time
✅ AI analysis appears after recording
✅ Dialog shows both transcription and analysis

---

## Troubleshooting

### Azure OpenAI Specific Issues

**Problem**: `ResourceNotFound` error
**Fix**: Deployment name must match exactly (case-sensitive)

**Problem**: `InvalidRequestError`
**Fix**: Check API version matches your deployment

**Problem**: Slow responses
**Fix**: Normal for campus WiFi, may take 3-5 seconds

### iOS Transcription Issues

**Problem**: No transcription
**Fix**:
1. Check microphone permission in Settings
2. Speak louder/clearer
3. Check language is set to 'en-US'

---

## Next Steps (After Basic Works)

Once you confirm Azure OpenAI works:

1. **Add fact-checking**: Connect to FactCheckingService
2. **Add insights**: Connect to AIInsightsService
3. **Display in AI Assistant tab**: Wire up ai_assistant_screen.dart
4. **Add streaming**: Real-time AI analysis during recording
5. **Add retry logic**: Handle network failures gracefully

---

## Notes

- **4-5 sec delay on first record**: Normal - iOS initializing audio session
- **Use campus WiFi**: Required for Azure OpenAI access
- **API costs**: Azure OpenAI charges per token, monitor usage
- **Privacy**: All audio/text sent to Azure cloud - ensure compliance

---

**Ready to test when you're on campus! 🚀**
