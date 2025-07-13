// ABOUTME: App-wide constants for configuration, UUIDs, and settings
// ABOUTME: Centralized location for all hardcoded values and configuration parameters

/// API Endpoints and Configuration
class APIConstants {
  // OpenAI Configuration
  static const String openAIBaseURL = 'https://api.openai.com/v1';
  static const String whisperEndpoint = '/audio/transcriptions';
  static const String chatCompletionsEndpoint = '/chat/completions';
  static const String defaultOpenAIModel = 'gpt-3.5-turbo';
  
  // Anthropic Configuration
  static const String anthropicBaseURL = 'https://api.anthropic.com/v1';
  static const String anthropicMessagesEndpoint = '/messages';
  static const String defaultAnthropicModel = 'anthropic-3-sonnet-20240229';
  
  // Request Configuration
  static const Duration apiTimeout = Duration(seconds: 30);
  static const int maxRetries = 3;
  static const Duration retryDelay = Duration(seconds: 2);
}

/// Bluetooth Service UUIDs for Even Realities Glasses
class BluetoothConstants {
  // Nordic UART Service (NUS) UUIDs
  static const String nordicUARTServiceUUID = '6E400001-B5A3-F393-E0A9-E50E24DCCA9E';
  static const String nordicUARTTXCharacteristicUUID = '6E400002-B5A3-F393-E0A9-E50E24DCCA9E';
  static const String nordicUARTRXCharacteristicUUID = '6E400003-B5A3-F393-E0A9-E50E24DCCA9E';
  
  // Device Identification
  static const String evenRealitiesManufacturerName = 'Even Realities';
  static const List<String> targetDeviceNames = ['G1', 'Even G1', 'Even Realities G1'];
  
  // Connection Configuration
  static const Duration scanTimeout = Duration(seconds: 30);
  static const Duration connectionTimeout = Duration(seconds: 10);
  static const Duration heartbeatInterval = Duration(seconds: 5);
  static const int maxReconnectionAttempts = 3;
}

/// Audio Processing Configuration
class AudioConstants {
  // Recording Configuration
  static const int sampleRate = 16000; // 16kHz for optimal speech recognition
  static const int bitRate = 64000; // 64kbps for good quality
  static const int numChannels = 1; // Mono recording
  
  // Voice Activity Detection
  static const double voiceActivityThreshold = 0.01;
  static const Duration silenceTimeout = Duration(milliseconds: 1500);
  static const Duration minimumSpeechDuration = Duration(milliseconds: 500);
  
  // Audio Processing
  static const Duration audioChunkDuration = Duration(seconds: 30); // For Whisper API
  static const int bufferSizeFrames = 4096;
  
  // File Storage
  static const String audioFileExtension = '.wav';
  static const String recordingsDirectory = 'recordings';
}

/// UI Constants and Themes
class UIConstants {
  // App Branding
  static const String appName = 'Helix';
  static const String appTagline = 'AI-Powered Conversation Intelligence';
  
  // Navigation
  static const int tabCount = 5;
  static const List<String> tabLabels = [
    'Conversation',
    'Analysis', 
    'Glasses',
    'History',
    'Settings'
  ];
  
  // Animation Durations
  static const Duration defaultAnimationDuration = Duration(milliseconds: 300);
  static const Duration fastAnimationDuration = Duration(milliseconds: 150);
  static const Duration slowAnimationDuration = Duration(milliseconds: 500);
  
  // UI Spacing
  static const double defaultPadding = 16.0;
  static const double smallPadding = 8.0;
  static const double largePadding = 24.0;
  static const double borderRadius = 12.0;
  
  // Real-time Updates
  static const Duration transcriptionUpdateInterval = Duration(milliseconds: 100);
  static const Duration statusUpdateInterval = Duration(milliseconds: 500);
}

/// Data Storage and Persistence
class StorageConstants {
  // SharedPreferences Keys
  static const String userSettingsKey = 'user_settings';
  static const String apiKeysKey = 'api_keys';
  static const String devicePreferencesKey = 'device_preferences';
  static const String lastConnectedGlassesKey = 'last_connected_glasses';
  
  // Database Configuration
  static const String databaseName = 'helix_conversations.db';
  static const int databaseVersion = 1;
  
  // Cache Configuration
  static const Duration cacheExpiration = Duration(hours: 24);
  static const int maxCacheSize = 100; // MB
  static const int maxConversationHistory = 1000;
}

/// AI Analysis Configuration
class AnalysisConstants {
  // Fact-checking
  static const int maxClaimsPerAnalysis = 10;
  static const double minimumConfidenceThreshold = 0.7;
  static const Duration analysisTimeout = Duration(minutes: 2);
  
  // Conversation Analysis
  static const int minimumWordsForAnalysis = 50;
  static const Duration batchAnalysisDelay = Duration(seconds: 5);
  
  // Prompt Templates
  static const String factCheckPromptTemplate = '''
Analyze the following conversation segment for factual claims that can be verified:

{conversation_text}

Please identify any specific factual claims and provide verification with sources.
Format your response as JSON with the following structure:
{
  "claims": [
    {
      "claim": "statement to verify",
      "verification": "verified/disputed/uncertain",
      "confidence": 0.0-1.0,
      "sources": ["source1", "source2"]
    }
  ]
}
''';
  
  static const String summaryPromptTemplate = '''
Provide a concise summary of the following conversation:

{conversation_text}

Include:
- Key topics discussed
- Main points and decisions
- Action items (if any)
- Overall tone and sentiment

Keep the summary under 200 words.
''';
}

/// Error Messages and User Feedback
class MessageConstants {
  // Audio Errors
  static const String microphonePermissionRequired = 
      'Microphone access is required for conversation transcription. Please enable it in Settings.';
  static const String audioRecordingFailed = 
      'Failed to start recording. Please check your microphone and try again.';
  
  // Bluetooth Errors
  static const String bluetoothPermissionRequired = 
      'Bluetooth access is required to connect to your Even Realities glasses.';
  static const String glassesNotFound = 
      'No Even Realities glasses found. Make sure they are powered on and nearby.';
  static const String connectionLost = 
      'Connection to glasses lost. Attempting to reconnect...';
  
  // AI Service Errors
  static const String apiKeyRequired = 
      'API key is required for AI analysis. Please configure it in Settings.';
  static const String analysisUnavailable = 
      'AI analysis is temporarily unavailable. Please try again later.';
  
  // Network Errors
  static const String noInternetConnection = 
      'No internet connection. Some features may be limited.';
  static const String requestTimeout = 
      'Request timed out. Please check your connection and try again.';
  
  // Success Messages
  static const String glassesConnected = 'Successfully connected to Even Realities glasses!';
  static const String recordingStarted = 'Recording started. Speak naturally for best results.';
  static const String analysisComplete = 'Conversation analysis complete.';
}