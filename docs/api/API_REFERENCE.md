# Helix API Reference

Complete reference documentation for all Helix APIs.

## Table of Contents

1. [Method Channel APIs](#method-channel-apis)
2. [Event Channel APIs](#event-channel-apis)
3. [External Provider APIs](#external-provider-apis)
4. [Version Management APIs](#version-management-apis)
5. [Data Models](#data-models)
6. [Error Codes](#error-codes)

---

## Method Channel APIs

### Bluetooth Method Channel

**Channel Name**: `method.bluetooth`
**Version**: 1.0.0
**Status**: Active

#### Methods

##### `startScan()`

Start scanning for Even Realities glasses.

**Parameters**: None

**Returns**: `String` - Status message

**Errors**:
- `BluetoothOff` - Bluetooth is not powered on

**Example**:
```dart
final result = await channel.invokeMethod('startScan');
print(result); // "Scanning for devices..."
```

---

##### `stopScan()`

Stop scanning for Bluetooth devices.

**Parameters**: None

**Returns**: `String` - Status message

**Example**:
```dart
final result = await channel.invokeMethod('stopScan');
print(result); // "Scan stopped"
```

---

##### `connectToGlasses(deviceName: String)`

Connect to paired Even Realities glasses.

**Parameters**:
- `deviceName` (String, required) - Name of the device pair (e.g., "Pair_123")

**Returns**: `String` - Connection status message

**Errors**:
- `DeviceNotFound` - Device not in paired devices list
- `PeripheralNotFound` - One or both peripherals not found

**Example**:
```dart
final result = await channel.invokeMethod('connectToGlasses', {
  'deviceName': 'Pair_123',
});
print(result); // "Connecting to Pair_123..."
```

---

##### `disconnectFromGlasses()`

Disconnect from all connected glasses.

**Parameters**: None

**Returns**: `String` - Disconnection status

**Example**:
```dart
final result = await channel.invokeMethod('disconnectFromGlasses');
print(result); // "Disconnected all devices."
```

---

##### `send(data: Uint8List, lr: String?)`

Send data to connected glasses.

**Parameters**:
- `data` (FlutterStandardTypedData, required) - Data to send
- `lr` (String, optional) - Target side:
  - `'L'` - Left device only
  - `'R'` - Right device only
  - `null` - Both devices

**Returns**: `void`

**Example**:
```dart
final data = Uint8List.fromList([0x01, 0x02, 0x03]);
await channel.invokeMethod('send', {
  'data': data,
  'lr': 'L', // Send to left device only
});
```

---

##### `startEvenAI(identifier: String)`

Start speech recognition with specified language.

**Parameters**:
- `identifier` (String, required) - Language code:
  - `'EN'` - English (US)
  - `'CN'` - Chinese
  - `'JP'` - Japanese
  - `'ES'` - Spanish
  - `'FR'` - French
  - `'DE'` - German
  - And more...

**Returns**: `String` - Status message

**Example**:
```dart
final result = await channel.invokeMethod('startEvenAI', 'EN');
print(result); // "Started Even AI speech recognition"
```

---

##### `stopEvenAI()`

Stop speech recognition.

**Parameters**: None

**Returns**: `String` - Status message

**Events**: Triggers final `eventSpeechRecognize` event with complete transcription

**Example**:
```dart
final result = await channel.invokeMethod('stopEvenAI');
print(result); // "Stopped Even AI speech recognition"
```

---

## Event Channel APIs

### Bluetooth Receive Event Channel

**Channel Name**: `eventBleReceive`
**Version**: 1.0.0
**Status**: Active

Receives data from connected Even Realities glasses.

**Event Data**:
```dart
{
  'type': String,      // Data type identifier
  'lr': String,        // Source side ('L' or 'R')
  'data': Uint8List,   // Raw data received
}
```

**Example**:
```dart
final channel = EventChannel('eventBleReceive');
channel.receiveBroadcastStream('eventBleReceive').listen((event) {
  final side = event['lr']; // 'L' or 'R'
  final data = event['data'] as Uint8List;
  print('Received from $side: ${data.length} bytes');
});
```

---

### Speech Recognition Event Channel

**Channel Name**: `eventSpeechRecognize`
**Version**: 1.0.0
**Status**: Active

Receives speech recognition results.

**Event Data**:
```dart
{
  'script': String,    // Recognized text
}
```

**Example**:
```dart
final channel = EventChannel('eventSpeechRecognize');
channel.receiveBroadcastStream('eventSpeechRecognize').listen((event) {
  final text = event['script'];
  print('Recognized: $text');
});
```

---

## External Provider APIs

### OpenAI Provider

**Version**: 1.0.0
**Status**: Active

#### Methods

##### `initialize(apiKey: String)`

Initialize the OpenAI provider.

**Parameters**:
- `apiKey` (String, required) - OpenAI API key

**Throws**: `Exception` if API key is invalid

**Example**:
```dart
final provider = OpenAIProvider(logger: logger);
await provider.initialize('sk-...');
```

---

##### `sendCompletion(...)`

Send a completion request to GPT models.

**Parameters**:
- `prompt` (String, required) - User prompt
- `systemPrompt` (String, optional) - System prompt
- `temperature` (double, optional, default: 0.7) - Response randomness
- `maxTokens` (int, optional, default: 1000) - Max response tokens
- `additionalParams` (Map, optional) - Additional parameters

**Returns**: `Future<String>` - Completion text

**Example**:
```dart
final response = await provider.sendCompletion(
  prompt: 'Explain quantum computing',
  systemPrompt: 'You are a helpful physics teacher',
  temperature: 0.5,
  maxTokens: 500,
);
```

---

##### `streamCompletion(...)`

Stream completion responses in real-time.

**Parameters**: Same as `sendCompletion`

**Returns**: `Stream<String>` - Stream of text chunks

**Example**:
```dart
await for (final chunk in provider.streamCompletion(
  prompt: 'Write a story',
)) {
  print(chunk); // Print each chunk as it arrives
}
```

---

##### `verifyFact(...)`

Verify a factual claim.

**Parameters**:
- `claim` (String, required) - Claim to verify
- `context` (String, optional) - Additional context
- `additionalContext` (List<String>, optional) - More context

**Returns**: `Future<FactCheckResult>`

**Example**:
```dart
final result = await provider.verifyFact(
  claim: 'The Earth is round',
  context: 'In a discussion about geography',
);
print('Status: ${result.status}');
print('Confidence: ${result.confidence}');
```

---

##### `generateSummary(...)`

Generate a conversation summary.

**Parameters**:
- `text` (String, required) - Text to summarize
- `maxWords` (int, optional, default: 200) - Max summary length
- `includeKeyPoints` (bool, optional, default: true)
- `includeActionItems` (bool, optional, default: true)

**Returns**: `Future<ConversationSummary>`

**Example**:
```dart
final summary = await provider.generateSummary(
  text: conversationText,
  maxWords: 150,
);
print('Summary: ${summary.summary}');
print('Key points: ${summary.keyPoints}');
```

---

##### `extractActionItems(...)`

Extract action items from text.

**Parameters**:
- `text` (String, required) - Text to analyze
- `includeDeadlines` (bool, optional, default: true)
- `includePriority` (bool, optional, default: true)

**Returns**: `Future<List<ActionItemResult>>`

**Example**:
```dart
final items = await provider.extractActionItems(
  text: meetingTranscript,
);
for (final item in items) {
  print('${item.priority}: ${item.description}');
  if (item.assignee != null) print('Assigned to: ${item.assignee}');
}
```

---

##### `analyzeSentiment(...)`

Analyze text sentiment.

**Parameters**:
- `text` (String, required) - Text to analyze
- `includeEmotions` (bool, optional, default: true)

**Returns**: `Future<SentimentAnalysisResult>`

**Example**:
```dart
final sentiment = await provider.analyzeSentiment(
  text: customerReview,
);
print('Overall: ${sentiment.overallSentiment}');
print('Confidence: ${sentiment.confidence}');
print('Emotions: ${sentiment.emotions}');
```

---

##### `detectClaims(...)`

Detect factual claims in text.

**Parameters**:
- `text` (String, required) - Text to analyze
- `confidenceThreshold` (double, optional, default: 0.7)

**Returns**: `Future<List<String>>` - List of detected claims

**Example**:
```dart
final claims = await provider.detectClaims(
  text: articleText,
  confidenceThreshold: 0.8,
);
for (final claim in claims) {
  print('Claim: $claim');
}
```

---

### Anthropic Provider

**Version**: 1.0.0
**Status**: Active

Supports all the same methods as OpenAI Provider with identical signatures.

**Differences**:
- Uses Claude models instead of GPT
- Different pricing structure
- Different token limits
- May produce different response styles

**Example**:
```dart
final provider = AnthropicProvider(logger: logger);
await provider.initialize('sk-ant-...');

final response = await provider.sendCompletion(
  prompt: 'Explain machine learning',
  temperature: 0.5,
);
```

---

## Version Management APIs

### APIVersionRouter

Manages API version routing and compatibility checking.

#### Methods

##### `routeMethodCall(...)`

Route a method call through version checking.

**Parameters**:
- `channelName` (String, required)
- `method` (String, required)
- `requestedVersion` (String, required)
- `arguments` (dynamic, required)
- `handler` (Function, required)

**Returns**: `Future<dynamic>`

**Throws**: `PlatformException` if version incompatible

**Example**:
```dart
final router = APIVersionRouter(logger: logger);
final result = await router.routeMethodCall(
  channelName: 'method.bluetooth',
  method: 'startScan',
  requestedVersion: '1.0.0',
  arguments: null,
  handler: (args) => actualImplementation(args),
);
```

---

##### `checkVersionCompatibility(...)`

Check if a version is compatible.

**Parameters**:
- `channelName` (String, required)
- `method` (String, required)
- `requestedVersion` (String, required)

**Returns**: `VersionCompatibilityResult`

**Example**:
```dart
final compatibility = router.checkVersionCompatibility(
  channelName: 'method.bluetooth',
  method: 'startScan',
  requestedVersion: '1.0.0',
);

if (compatibility.isCompatible) {
  print('✅ Version is compatible');
} else {
  print('❌ ${compatibility.errorMessage}');
}
```

---

##### `getVersionInfo()`

Get current API version information.

**Returns**: `Map<String, dynamic>`

**Example**:
```dart
final info = router.getVersionInfo();
print('Method Channel: ${info['methodChannelVersion']}');
print('Event Channel: ${info['eventChannelVersion']}');
```

---

##### `listEndpoints()`

List all available API endpoints with versions.

**Returns**: `Map<String, dynamic>`

**Example**:
```dart
final endpoints = router.listEndpoints();
print('Method Channels: ${endpoints['methodChannels']}');
print('Event Channels: ${endpoints['eventChannels']}');
```

---

### ExternalAPIVersionTracker

Tracks external API version usage and health.

#### Methods

##### `trackRequest(...)`

Track an API request.

**Parameters**:
- `provider` (String, required)
- `endpoint` (String, required)
- `requestHeaders` (Map<String, String>, required)
- `responseHeaders` (Map<String, dynamic>, optional)
- `statusCode` (int, optional)
- `errorMessage` (String, optional)

**Returns**: `Future<void>`

**Example**:
```dart
await tracker.trackRequest(
  provider: 'OpenAI',
  endpoint: '/chat/completions',
  requestHeaders: headers,
  responseHeaders: response.headers,
  statusCode: 200,
);
```

---

##### `getVersionState(...)`

Get version state for an API endpoint.

**Parameters**:
- `provider` (String, required)
- `endpoint` (String, required)

**Returns**: `APIVersionState?`

**Example**:
```dart
final state = tracker.getVersionState('OpenAI', '/chat/completions');
print('Total requests: ${state?.totalRequests}');
print('Failure rate: ${state?.failureRate}');
```

---

##### `getDeprecatedAPIs()`

Get list of deprecated APIs in use.

**Returns**: `List<APIVersionState>`

**Example**:
```dart
final deprecated = tracker.getDeprecatedAPIs();
for (final api in deprecated) {
  print('⚠️  ${api.provider}${api.endpoint}');
  print('Days until sunset: ${api.daysUntilSunset}');
}
```

---

##### `getAPIsNearingSunset(...)`

Get APIs approaching sunset date.

**Parameters**:
- `daysThreshold` (int, optional, default: 30)

**Returns**: `List<APIVersionState>`

**Example**:
```dart
final nearingSunset = tracker.getAPIsNearingSunset(daysThreshold: 30);
if (nearingSunset.isNotEmpty) {
  print('⚠️  APIs sunsetting within 30 days:');
  for (final api in nearingSunset) {
    print('${api.provider}${api.endpoint}: ${api.daysUntilSunset} days');
  }
}
```

---

##### `getHealthSummary()`

Get overall API health summary.

**Returns**: `Map<String, dynamic>`

**Example**:
```dart
final health = tracker.getHealthSummary();
print('Total endpoints: ${health['totalEndpoints']}');
print('Deprecated: ${health['deprecatedEndpoints']}');
print('Health score: ${health['healthScore']}%');
```

---

## Data Models

### FactCheckResult

Result of fact verification.

**Properties**:
- `id` (String) - Unique identifier
- `claim` (String) - The claim being verified
- `status` (FactCheckStatus) - Verification status
- `confidence` (double) - Confidence score (0.0-1.0)
- `sources` (List<String>) - Supporting sources
- `explanation` (String) - Detailed explanation
- `context` (String?) - Original context

**Example**:
```dart
final result = FactCheckResult(
  id: 'fact_123',
  claim: 'The Earth is round',
  status: FactCheckStatus.verified,
  confidence: 0.99,
  sources: ['NASA', 'Scientific consensus'],
  explanation: 'Well-established scientific fact...',
);
```

---

### ConversationSummary

Summary of a conversation.

**Properties**:
- `summary` (String) - Main summary text
- `keyPoints` (List<String>) - Key discussion points
- `decisions` (List<String>) - Decisions made
- `questions` (List<String>) - Questions raised
- `tone` (String?) - Conversational tone
- `topics` (List<String>) - Main topics
- `confidence` (double) - Summary confidence

**Example**:
```dart
final summary = ConversationSummary(
  summary: 'Discussion about project timeline...',
  keyPoints: ['Deadline extended', 'New requirements'],
  decisions: ['Use agile methodology'],
  questions: ['What about budget?'],
  tone: 'professional',
  topics: ['Project planning', 'Timeline'],
  confidence: 0.85,
);
```

---

### ActionItemResult

Extracted action item.

**Properties**:
- `id` (String) - Unique identifier
- `description` (String) - What needs to be done
- `assignee` (String?) - Who is responsible
- `dueDate` (DateTime?) - Deadline
- `priority` (ActionItemPriority) - Priority level
- `context` (String?) - Context/background
- `confidence` (double) - Extraction confidence

**Example**:
```dart
final item = ActionItemResult(
  id: 'action_456',
  description: 'Update documentation',
  assignee: 'John',
  dueDate: DateTime(2025, 12, 1),
  priority: ActionItemPriority.high,
  context: 'Mentioned in planning meeting',
  confidence: 0.90,
);
```

---

### SentimentAnalysisResult

Result of sentiment analysis.

**Properties**:
- `overallSentiment` (SentimentType) - Overall sentiment
- `confidence` (double) - Analysis confidence
- `emotions` (Map<String, double>) - Emotion scores
- `tone` (String?) - Tone description
- `keyPhrases` (List<String>) - Influential phrases

**Example**:
```dart
final result = SentimentAnalysisResult(
  overallSentiment: SentimentType.positive,
  confidence: 0.88,
  emotions: {
    'joy': 0.7,
    'trust': 0.6,
    'anticipation': 0.5,
  },
  tone: 'enthusiastic',
  keyPhrases: ['excited to', 'looking forward'],
);
```

---

## Error Codes

### Method Channel Errors

| Code | Description | Recovery |
|------|-------------|----------|
| `BluetoothOff` | Bluetooth is not powered on | Enable Bluetooth in settings |
| `DeviceNotFound` | Device not in paired list | Scan for devices first |
| `PeripheralNotFound` | Peripheral not available | Check device is powered on |
| `API_VERSION_INCOMPATIBLE` | API version not supported | Update app or use compatible version |
| `FlutterMethodNotImplemented` | Method not implemented | Check method name spelling |

### HTTP API Errors

| Status Code | Description | Recovery |
|------------|-------------|----------|
| 401 | Unauthorized | Check API key |
| 429 | Rate limit exceeded | Wait and retry |
| 500 | Server error | Retry with backoff |
| 503 | Service unavailable | Try again later |

---

## Enumerations

### FactCheckStatus

```dart
enum FactCheckStatus {
  verified,      // Claim is verified as true
  disputed,      // Claim is disputed/false
  uncertain,     // Cannot determine
  needsReview,   // Requires manual review
}
```

### SentimentType

```dart
enum SentimentType {
  positive,      // Positive sentiment
  negative,      // Negative sentiment
  neutral,       // Neutral sentiment
  mixed,         // Mixed sentiments
}
```

### ActionItemPriority

```dart
enum ActionItemPriority {
  urgent,        // Immediate action required
  high,          // High priority
  medium,        // Medium priority
  low,           // Low priority
}
```

### APIVersionEventType

```dart
enum APIVersionEventType {
  versionChange,      // API version changed
  deprecationNotice,  // API deprecated
  sunsetNotice,       // API approaching sunset
  error,              // API error occurred
  compatibility,      // Compatibility issue
  migration,          // Migration event
}
```

---

*Last Updated: 2025-11-16*
*Version: 1.0.0*
