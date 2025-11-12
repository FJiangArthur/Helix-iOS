# Helix Architecture Documentation

## 1. System Overview

Helix is a Flutter-based companion app for Even Realities smart glasses that provides real-time conversation analysis and AI-powered insights displayed directly on the glasses HUD. The app processes live audio, performs speech-to-text conversion, and sends conversation data to LLM APIs for fact-checking, summarization, and contextual assistance.

## 2. High-Level Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│ Even Realities  │◄──►│  Flutter App    │◄──►│  Cloud Services │
│    Glasses      │    │    (Helix)      │    │   (LLM APIs)    │
└─────────────────┘    └─────────────────┘    └─────────────────┘
        │                       │                       │
        │                       │                       │
   ┌────▼────┐            ┌─────▼─────┐           ┌─────▼─────┐
   │ HUD     │            │ AI Engine │           │ OpenAI/   │
   │ Display │            │ Pipeline  │           │ Anthropic │
   └─────────┘            └───────────┘           └───────────┘
```

## 3. Technology Stack

### 3.1 Core Technologies
- **Platform**: Flutter 3.24+ (Dart 3.5+)
- **State Management**: Riverpod + Freezed
- **Dependency Injection**: get_it
- **Audio Processing**: flutter_sound, audio_session
- **Speech Recognition**: speech_to_text
- **AI Integration**: OpenAI GPT, Anthropic APIs
- **Bluetooth**: flutter_bluetooth_serial (Even Realities glasses)

### 3.2 External APIs
- **OpenAI API**: GPT-4 for conversation analysis and fact-checking
- **Anthropic API**: Advanced reasoning capabilities
- **Whisper API**: Speech-to-text transcription

## 4. Project Structure

```
lib/
├── core/                           # Core business logic and services
│   └── utils/                     # Utility classes and extensions
│       ├── constants.dart         # App-wide constants and configuration
│       ├── exceptions.dart        # Custom exception definitions
│       └── logging_service.dart   # Centralized logging system
├── features/                       # Feature-based organization
│   ├── conversation/              # Main conversation feature (UI)
│   ├── analysis/                  # AI analysis results display
│   ├── settings/                  # App configuration
│   └── history/                   # Conversation history
├── models/                        # Data models with Freezed
│   ├── analysis_result.dart       # AI analysis result models
│   ├── conversation_model.dart    # Conversation data models
│   ├── transcription_segment.dart # Speech transcription models
│   └── glasses_connection_state.dart # Hardware connection models
├── providers/                     # Riverpod providers
│   └── app_state_provider.dart   # Global application state
├── services/                      # Business logic services
│   ├── ai_providers/             # AI provider implementations
│   │   ├── base_provider.dart    # Abstract provider interface
│   │   ├── openai_provider.dart  # OpenAI GPT-4 integration
│   │   └── anthropic_provider.dart # Anthropic integration
│   ├── implementations/          # Service implementations
│   │   ├── llm_service_impl_v2.dart # Enhanced multi-provider LLM service
│   │   ├── audio_service_impl.dart  # Audio recording implementation
│   │   └── transcription_service_impl.dart # Speech-to-text implementation
│   ├── fact_checking_service.dart # Real-time fact verification
│   ├── ai_insights_service.dart  # Conversation intelligence
│   ├── llm_service.dart          # LLM service interface
│   ├── audio_service.dart        # Audio recording interface
│   └── service_locator.dart      # Dependency injection setup
├── ui/                           # User interface components
│   ├── screens/                  # Full-screen views
│   ├── widgets/                  # Reusable UI components
│   └── theme/                    # App theming
└── main.dart                     # Application entry point
```

## 5. Core Components

### 5.1 AI Analysis Engine (Epic 2.2)

#### **Multi-Provider LLM Service**
- **Location**: `lib/services/implementations/llm_service_impl_v2.dart`
- **Features**:
  - OpenAI GPT-4 and Anthropic provider support
  - Automatic failover and health monitoring
  - Performance-based provider selection
  - Usage analytics and cost estimation
  - Configurable retry logic with exponential backoff

#### **AI Providers Architecture**
```
BaseAIProvider (Abstract)
├── OpenAIProvider
│   ├── GPT-4 Turbo integration
│   ├── Streaming support
│   ├── Function calling capabilities
│   └── Cost optimization
└── AnthropicProvider
    ├── Advanced reasoning
    ├── Structured output
    ├── High-quality analysis
    └── Streaming responses
```

#### **Real-Time Fact Checking**
- **Location**: `lib/services/fact_checking_service.dart`
- **Features**:
  - AI-powered claim detection in conversation text
  - Multi-step fact verification pipeline
  - Confidence scoring (0.0-1.0)
  - Source attribution and explanations
  - Priority-based queue management
  - Rate limiting and throttling

#### **AI Insights Engine**
- **Location**: `lib/services/ai_insights_service.dart`
- **Features**:
  - Real-time conversation intelligence
  - Action item extraction with deadlines
  - Sentiment analysis with emotional breakdown
  - Topic identification and relevance scoring
  - Contextual suggestions and recommendations
  - Configurable insight types

### 5.2 Audio Processing Pipeline

#### **Audio Service**
- **Interface**: `lib/services/audio_service.dart`
- **Implementation**: `lib/services/implementations/audio_service_impl.dart`
- **Features**:
  - Real-time audio capture (16kHz, mono)
  - Voice activity detection
  - Audio level monitoring for waveform
  - Permission management
  - File saving and playback

#### **Real-Time Transcription**
- **Location**: `lib/services/real_time_transcription_service.dart`
- **Features**:
  - Streaming speech-to-text conversion
  - Speaker diarization
  - Confidence scoring
  - Multi-language support
  - Integration with OpenAI Whisper API

### 5.3 Hardware Integration

#### **Smart Glasses Service**
- **Interface**: `lib/services/glasses_service.dart`
- **Implementation**: `lib/services/implementations/glasses_service_impl.dart`
- **Features**:
  - Bluetooth connectivity to Even Realities glasses
  - Real-time HUD content rendering
  - Battery monitoring
  - Display control and positioning

### 5.4 Data Models

#### **Analysis Results**
```dart
// Comprehensive AI analysis container
@freezed
class AnalysisResult with _$AnalysisResult {
  // Fact-checking results
  List<FactCheckResult>? factChecks;
  
  // Conversation summary
  ConversationSummary? summary;
  
  // Extracted action items
  List<ActionItemResult>? actionItems;
  
  // Sentiment analysis
  SentimentAnalysisResult? sentiment;
  
  // Processing metadata
  String provider;
  double confidence;
  Duration processingTime;
}
```

#### **Conversation Models**
- **TranscriptionSegment**: Real-time speech segments
- **ConversationModel**: Complete conversation data
- **AudioConfiguration**: Recording settings
- **GlassesConnectionState**: Hardware connection status

## 6. Data Flow Architecture

### 6.1 Real-Time Processing Flow
```
Audio Input → Voice Detection → Speech-to-Text → AI Analysis → Insights Generation → HUD Display
     ↓              ↓                ↓              ↓              ↓                ↓
  Raw Audio    Activity Detection   Text/Speaker  Fact-Check    Action Items      Visual
               & Noise Reduction                  Summary       Sentiment         Feedback
                                                 Insights      Topics            
```

### 6.2 AI Analysis Pipeline
```
Transcription Stream → Fact Checking Service → Claim Detection → Verification
                    → AI Insights Service → Conversation Analysis → Insights Generation
                    → LLM Service → Provider Selection → API Calls → Result Processing
```

### 6.3 Service Dependencies
```
main.dart
├── ServiceLocator (get_it)
├── LLMService (Multi-provider)
│   ├── OpenAIProvider
│   └── AnthropicProvider
├── FactCheckingService
├── AIInsightsService
├── AudioService
├── TranscriptionService
└── GlassesService
```

## 7. State Management

### 7.1 Riverpod Providers
- **Global State**: Application-wide state management
- **Feature State**: Feature-specific state isolation
- **Service Providers**: Singleton service instances
- **UI State**: Component-level reactive state

### 7.2 Data Flow Patterns
- **Streams**: Real-time data updates (audio, transcription, insights)
- **FutureProviders**: Async operations (API calls, file operations)
- **StateNotifiers**: Complex state management
- **AutoDispose**: Automatic memory management

## 8. Performance Architecture

### 8.1 Real-Time Requirements
- **Audio Latency**: <100ms capture to processing
- **Transcription Latency**: <500ms speech to text
- **AI Analysis**: <2 seconds for comprehensive analysis
- **UI Updates**: 60fps smooth rendering
- **Memory Usage**: <200MB sustained operation

### 8.2 Optimization Strategies
- **Provider Failover**: Automatic switching on failures
- **Caching**: Intelligent result caching (10-minute timeout)
- **Queue Management**: Priority-based processing
- **Batch Processing**: Efficient multi-segment analysis
- **Memory Management**: Circular buffers and automatic cleanup

## 9. Error Handling & Resilience

### 9.1 Provider Health Monitoring
- **Failure Detection**: Automatic provider health checks
- **Cooldown Periods**: 5-minute recovery windows
- **Performance Tracking**: Response time optimization
- **Graceful Degradation**: Fallback to available providers

### 9.2 Network Resilience
- **Retry Logic**: Exponential backoff with jitter
- **Offline Queue**: Local storage for failed requests
- **Rate Limiting**: Respect API quotas and limits
- **Timeout Handling**: Configurable request timeouts

## 10. Security & Privacy

### 10.1 Data Protection
- **Local Processing**: Audio processing on-device when possible
- **Encrypted Communication**: HTTPS for all API calls
- **No Persistent Storage**: Conversations not stored without consent
- **API Key Security**: Secure credential management

### 10.2 Privacy Controls
- **User Consent**: Explicit permission for data processing
- **Data Minimization**: Only necessary data sent to APIs
- **Retention Policies**: Configurable data retention
- **Anonymization**: Speaker identity protection options

## 11. Testing Strategy

### 11.1 Test Architecture
```
test/
├── unit/                    # Unit tests for services and models
│   └── services/           # Service-specific test suites
├── integration/            # Integration tests for workflows
└── widget_test.dart       # UI component tests
```

### 11.2 Testing Approaches
- **Unit Tests**: Core business logic validation
- **Integration Tests**: End-to-end workflow testing
- **Widget Tests**: UI component behavior
- **Mock Services**: Isolated testing environments

## 12. Deployment & CI/CD

### 12.1 Development Workflow
- **Feature Branches**: Epic-based development
- **Linear Integration**: Issue tracking and progress
- **Pre-commit Hooks**: Code quality enforcement
- **Automated Testing**: CI pipeline validation

### 12.2 Build Configuration
- **Flutter Channels**: Stable channel for production
- **Platform Support**: iOS, Android, macOS, Windows, Linux
- **Environment Management**: Development, staging, production
- **Asset Management**: Optimized resource bundling

## 13. Monitoring & Analytics

### 13.1 Performance Monitoring
- **Response Time Tracking**: AI provider performance
- **Error Rate Monitoring**: Failure detection and alerting
- **Usage Analytics**: Feature adoption and usage patterns
- **Resource Usage**: Memory, CPU, and battery impact

### 13.2 Health Metrics
- **Service Availability**: Provider uptime monitoring
- **API Quota Usage**: Cost and limit tracking
- **User Experience**: Latency and error metrics
- **System Performance**: Real-time performance dashboards

## 14. Future Architecture Considerations

### 14.1 Scalability
- **Local AI Models**: On-device processing capabilities
- **Edge Computing**: Reduced cloud dependencies
- **Multi-Language Support**: Internationalization
- **Advanced Analytics**: Enhanced conversation insights

### 14.2 Integration Expansion
- **Additional LLM Providers**: Gemini, Llama, etc.
- **Hardware Ecosystem**: Support for multiple AR/VR devices
- **Enterprise Features**: Team collaboration and analytics
- **API Ecosystem**: Third-party integrations and webhooks

---

*This architecture documentation reflects the current implementation as of Epic 2.2 completion. For implementation details and development guidelines, see the Developer Guide and API documentation.*