# Helix Flutter Migration Plan
## Complete iOS to Cross-Platform Migration Blueprint

### Executive Summary
Migrate the Helix iOS companion app for Even Realities smart glasses to Flutter for cross-platform deployment (iOS, Android, Web, Desktop). The migration will preserve all existing functionality while leveraging Flutter's cross-platform capabilities and the existing Flutter/Dart infrastructure in the `libs/` directory.

---

## Phase 1: Foundation & Core Architecture (2-3 weeks)

### Step 1.1: Project Setup & Dependencies
**Goal**: Establish Flutter project structure with all required dependencies

```
Set up the Flutter project structure and configure all necessary dependencies for cross-platform development. Create the main Flutter app in a new directory structure that mirrors the existing iOS architecture.

Key tasks:
1. Create new Flutter project structure under `/flutter_helix/`
2. Configure pubspec.yaml with all required dependencies:
   - flutter_blue_plus: ^1.4.4 (Bluetooth for Even Realities)
   - flutter_sound: ^9.2.13 (Audio processing)
   - provider: ^6.1.1 (State management)
   - dio: ^5.4.3+1 (HTTP client for AI APIs)
   - permission_handler: ^10.2.0 (Platform permissions)
   - audio_session: ^0.1.16 (Audio session management)
   - speech_to_text: ^6.6.0 (Local speech recognition)
   - shared_preferences: ^2.2.2 (Settings persistence)
   - dart_openai: ^5.1.0 (OpenAI integration)
   - get_it: ^7.6.4 (Dependency injection)
   - freezed: ^2.4.7 (Immutable data classes)
   - json_annotation: ^4.8.1 (JSON serialization)

3. Set up proper folder structure:
   lib/
     core/
       audio/
       ai/
       transcription/
       glasses/
       utils/
     ui/
       screens/
       widgets/
       providers/
     services/
     models/

4. Configure platform-specific permissions in android/app/src/main/AndroidManifest.xml and ios/Runner/Info.plist
5. Set up build configurations for different platforms
6. Initialize dependency injection container with get_it
```

### Step 1.2: Core Service Interfaces
**Goal**: Define Flutter service interfaces that mirror iOS protocols

```
Create the core service interfaces and abstract classes that will define the contract for all platform implementations. This step establishes the architectural foundation for dependency injection and testing.

Key tasks:
1. Create abstract interfaces for all core services:
   - AudioService (audio capture, processing, recording)
   - TranscriptionService (speech-to-text, both local and remote)
   - LLMService (AI analysis, fact-checking, summarization)
   - GlassesService (Bluetooth connectivity, HUD rendering)
   - SettingsService (app configuration, persistence)

2. Define data models using Freezed for immutability:
   - ConversationModel
   - TranscriptionSegment
   - AnalysisResult
   - GlassesConnectionState
   - AudioConfiguration

3. Create service locator pattern with get_it:
   - Register all service interfaces
   - Set up dependency resolution
   - Configure singleton vs factory patterns

4. Implement basic error handling and logging infrastructure:
   - Custom exception classes
   - Logging service with different levels
   - Error reporting mechanism

5. Set up constants and configuration classes:
   - API endpoints and keys
   - Audio processing parameters
   - Bluetooth service UUIDs for Even Realities
   - UI constants and themes
```

### Step 1.3: Audio Service Implementation
**Goal**: Port iOS AudioManager to Flutter with platform channels

```
Implement the core audio processing service that handles real-time audio capture, voice activity detection, and audio format conversion. This is the foundation for all transcription and analysis features.

Key implementation points:
1. Create AudioServiceImpl class implementing AudioService interface
2. Use flutter_sound for cross-platform audio recording
3. Implement platform channels for native audio processing where needed
4. Port iOS audio configuration (16kHz sample rate, format conversion)
5. Add voice activity detection using native libraries or FFI
6. Implement audio buffering and streaming for real-time processing
7. Create test mode infrastructure for unit testing
8. Add noise reduction preprocessing pipeline
9. Handle platform-specific audio session management
10. Implement recording storage for conversation history

Core components to implement:
- AudioCaptureEngine (real-time capture)
- AudioProcessor (format conversion, noise reduction)
- VoiceActivityDetector (VAD implementation)
- AudioRecorder (conversation storage)
- AudioConfiguration (settings management)

Testing requirements:
- Unit tests for audio format conversion
- Mock audio input for testing pipeline
- Integration tests with different audio sources
- Performance tests for real-time processing
```

### Step 1.4: State Management Setup
**Goal**: Implement Provider-based state management architecture

```
Create the application-wide state management system using Provider pattern that replaces the iOS AppCoordinator functionality. This will handle all cross-service communication and UI state updates.

Key components:
1. AppProvider - Main application state coordinator
   - Manages service initialization and lifecycle
   - Coordinates communication between services
   - Handles app-wide settings and configuration
   - Manages navigation state and deep linking

2. ConversationProvider - Real-time conversation state
   - Current transcription text and segments
   - Speaker identification and timing
   - Conversation history and persistence
   - Real-time updates for UI components

3. AnalysisProvider - AI analysis results
   - Fact-checking results and claims
   - Conversation summaries and insights
   - Action items and follow-ups
   - Analysis history and caching

4. GlassesProvider - Even Realities connection state
   - Bluetooth connection status and device info
   - HUD content and rendering state
   - Battery level and device health
   - Touch gesture handling and commands

5. SettingsProvider - App configuration
   - User preferences and privacy settings
   - AI service configuration (providers, models)
   - Audio processing parameters
   - Theme and display settings

Implementation approach:
- Use ChangeNotifier pattern for reactive updates
- Implement proper dispose methods for resource cleanup
- Add loading states and error handling for all providers
- Create provider combination for complex state dependencies
- Set up proper testing infrastructure with provider mocking
```

---

## Phase 2: Core Services Implementation (3-4 weeks)

### Step 2.1: Bluetooth & Glasses Integration
**Goal**: Port Even Realities Bluetooth connectivity to Flutter

```
Implement the complete Bluetooth Low Energy integration with Even Realities smart glasses using flutter_blue_plus. Leverage existing implementations in libs/g1_flutter_blue_plus and libs/EvenDemoApp.

Core implementation:
1. GlassesServiceImpl class with flutter_blue_plus integration
2. Even Realities protocol implementation:
   - Nordic UART Service (6E400001-B5A3-F393-E0A9-E50E24DCCA9E)
   - TX/RX characteristics for bidirectional communication
   - Command structure and message framing
   - Heartbeat and connection management

3. Device discovery and connection management:
   - Scan for Even Realities devices with proper filtering
   - Connection state handling and reconnection logic
   - Device pairing and authentication if required
   - Multiple device support for future expansion

4. HUD content rendering and display:
   - Text rendering with formatting options
   - Real-time content updates and streaming
   - Display brightness and visibility controls
   - Content prioritization and queuing

5. Touch gesture and input handling:
   - Touch event processing from glasses
   - Gesture recognition and command mapping
   - User interaction feedback and confirmation

6. Battery and device health monitoring:
   - Battery level reporting and alerts
   - Connection quality and signal strength
   - Device status and error reporting

Platform considerations:
- Android Bluetooth permissions and location services
- iOS Core Bluetooth background processing
- Platform-specific pairing and connection flows
- Error handling for different Bluetooth stack behaviors

Testing approach:
- Mock Bluetooth service for unit testing
- Integration tests with actual Even Realities glasses
- Connection reliability and stress testing
- Battery optimization and power management tests
```

### Step 2.2: Speech Recognition Services
**Goal**: Implement dual speech recognition (local + Whisper API)

```
Create comprehensive speech-to-text functionality with both local on-device recognition and remote OpenAI Whisper API support. Implement backend switching and quality optimization.

Implementation components:

1. Local Speech Recognition (speech_to_text plugin):
   - Platform-specific configuration for iOS/Android
   - Real-time transcription with streaming results
   - Language detection and multi-language support
   - Confidence scoring and result filtering
   - Speaker identification integration

2. Remote Whisper API Integration:
   - Audio chunking and streaming to OpenAI API
   - Format conversion and compression for API efficiency
   - Batch processing for improved accuracy
   - Fallback mechanisms for network issues
   - Rate limiting and cost optimization

3. Hybrid Recognition System:
   - Automatic backend selection based on quality/speed needs
   - Real-time local processing with periodic Whisper validation
   - Quality comparison and accuracy metrics
   - User preference and automatic optimization

4. TranscriptionCoordinator:
   - Manages coordination between recognition backends
   - Handles result merging and timing synchronization
   - Implements speaker diarization and attribution
   - Provides unified transcription stream to UI

5. Advanced Features:
   - Punctuation and capitalization enhancement
   - Domain-specific vocabulary and customization
   - Real-time correction and editing capabilities
   - Transcription confidence and quality scoring

Performance optimization:
- Audio preprocessing for optimal recognition
- Network optimization for API calls
- Caching and result persistence
- Background processing for non-critical tasks

Testing strategy:
- Audio sample testing with known ground truth
- Network simulation for API reliability testing
- Performance benchmarking across platforms
- Accuracy comparison between local and remote backends
```

### Step 2.3: AI/LLM Integration
**Goal**: Port multi-provider AI analysis system to Flutter

```
Implement the complete AI analysis pipeline with support for multiple LLM providers (OpenAI, Anthropic). Create comprehensive fact-checking, summarization, and conversation analysis capabilities.

Core AI Services:

1. LLMServiceImpl - Multi-provider AI orchestration:
   - OpenAI GPT integration with dart_openai package
   - Anthropic Claude API integration with custom HTTP client
   - Provider fallback and load balancing
   - Response caching and optimization
   - Rate limiting and cost management

2. ClaimDetectionService - Real-time fact-checking:
   - Extract factual claims from transcribed conversation
   - Query LLMs for fact verification and source citation
   - Provide confidence scores and supporting evidence
   - Handle controversial topics with balanced perspectives
   - Cache fact-check results for performance

3. ConversationAnalyzer - Comprehensive conversation analysis:
   - Generate conversation summaries and key insights
   - Extract action items and follow-up tasks
   - Identify important topics and themes
   - Analyze conversation tone and sentiment
   - Provide personalized insights and recommendations

4. PromptManager - Template and persona management:
   - Structured prompt templates for different analysis types
   - Persona-based prompting for specialized contexts
   - Dynamic prompt generation based on conversation context
   - A/B testing infrastructure for prompt optimization
   - Multi-language prompt support

5. AnalysisCoordinator - Results aggregation and coordination:
   - Coordinate multiple AI analysis requests
   - Merge and prioritize analysis results
   - Handle real-time vs batch analysis modes
   - Manage analysis history and persistence
   - Provide unified analysis stream to UI

Implementation details:
- Dio HTTP client for all API communications
- JSON serialization with freezed and json_annotation
- Error handling and retry logic for API failures
- Background processing for non-urgent analysis
- Result caching with shared_preferences or hive

Security and privacy:
- API key management and secure storage
- User consent and privacy controls
- Local processing options where possible
- Data retention and deletion policies

Testing approach:
- Mock AI responses for consistent testing
- Integration tests with actual AI APIs
- Performance benchmarking for analysis speed
- Accuracy validation with known conversation samples
```

### Step 2.4: Data Persistence & History
**Goal**: Implement conversation history and settings persistence

```
Create comprehensive data persistence layer for conversation history, user settings, and analysis results. Implement local storage with optional cloud synchronization.

Data Storage Components:

1. ConversationRepository - Conversation and transcription storage:
   - SQLite database with drift package for complex queries
   - Conversation metadata (date, duration, participants)
   - Transcription segments with timing and speaker attribution
   - Audio file references and storage management
   - Full-text search capabilities for conversation content

2. AnalysisRepository - AI analysis results storage:
   - Analysis results linked to conversations
   - Fact-check results with citations and confidence scores
   - Summaries, action items, and insights
   - Analysis history and trending topics
   - Performance metrics and accuracy tracking

3. SettingsRepository - User preferences and configuration:
   - App settings with shared_preferences
   - AI provider preferences and API configurations
   - Audio processing parameters and quality settings
   - Privacy and consent management
   - Backup and restore functionality

4. CacheManager - Intelligent caching system:
   - API response caching for performance
   - Offline functionality with local data
   - Cache invalidation and cleanup strategies
   - Memory management and storage optimization

Data Models and Serialization:
- Freezed data classes for immutable models
- JSON serialization for API communication
- Database schemas with proper indexing
- Migration strategies for schema updates

Synchronization and Backup:
- Optional cloud storage integration (Google Drive, iCloud)
- Conflict resolution for multi-device usage
- Data export in standard formats (JSON, CSV)
- Privacy-preserving synchronization options

Performance Optimization:
- Lazy loading for large conversation histories
- Pagination for UI components
- Background data processing and cleanup
- Database query optimization and indexing

Testing and Validation:
- Repository unit tests with mock data
- Database migration testing
- Performance testing with large datasets
- Data integrity and backup validation
```

---

## Phase 3: User Interface Migration (2-3 weeks)

### Step 3.1: Core UI Components & Navigation
**Goal**: Create Flutter equivalent of SwiftUI views and tab navigation

```
Implement the main user interface structure using Flutter widgets that replicate the iOS app's five-tab navigation and core UI components.

Navigation Structure:

1. MainApp - Application root with material design:
   - MaterialApp configuration with custom theme
   - Route management and deep linking support
   - Global navigation context and state management
   - Error boundary and crash handling UI

2. MainTabView - Bottom navigation with five tabs:
   - Conversation tab (real-time transcription and interaction)
   - Analysis tab (AI insights and fact-checking results)
   - Glasses tab (Even Realities connection and status)
   - History tab (conversation history and search)
   - Settings tab (app configuration and preferences)

3. Core UI Components:
   - HelixAppBar - Custom app bar with status indicators
   - ConnectionStatusWidget - Bluetooth and service status
   - LoadingOverlay - Loading states with proper animations
   - ErrorDialog - Consistent error display and recovery
   - SettingsCard - Reusable settings UI components

Theme and Design System:
- Material Design 3 with custom color scheme
- Dark/light theme support with user preference
- Consistent typography and spacing
- Accessibility support with proper semantics
- Responsive design for different screen sizes

State Integration:
- Provider integration for all tab views
- Proper state preservation during navigation
- Loading and error states for each tab
- Deep linking support for external navigation

Testing Approach:
- Widget tests for all UI components
- Navigation testing with flutter_test
- Golden file testing for visual consistency
- Accessibility testing with semantics
```

---

## Implementation Prompts

### Prompt 1: Project Setup & Core Architecture
```
Create a new Flutter project for Helix cross-platform app migration. Set up the complete project structure with proper dependencies and folder organization.

Tasks:
1. Create Flutter project with proper package name and organization
2. Configure pubspec.yaml with all required dependencies:
   - flutter_blue_plus: ^1.4.4
   - flutter_sound: ^9.2.13
   - provider: ^6.1.1
   - dio: ^5.4.3+1
   - permission_handler: ^10.2.0
   - audio_session: ^0.1.16
   - speech_to_text: ^6.6.0
   - shared_preferences: ^2.2.2
   - dart_openai: ^5.1.0
   - get_it: ^7.6.4
   - freezed: ^2.4.7
   - json_annotation: ^4.8.1
   - build_runner: ^2.4.7
   - json_serializable: ^6.7.1

3. Create folder structure and initialize dependency injection
4. Set up platform permissions and basic error handling
5. Ensure all setup follows Flutter best practices

This prompt begins the foundation phase with proper project structure and dependencies for cross-platform development.
```

### Prompt 2: Core Service Interfaces & Models
```
Create the core service interfaces and data models that define the architecture for the Helix Flutter app. This establishes the foundation for all service implementations.

Tasks:
1. Create abstract service interfaces (AudioService, TranscriptionService, LLMService, GlassesService, SettingsService)
2. Define Freezed data models (ConversationModel, TranscriptionSegment, AnalysisResult, etc.)
3. Set up service locator with get_it
4. Create custom exception classes and logging infrastructure
5. Add JSON serialization code generation setup

This prompt establishes the architectural foundation with clear contracts for all services.
```

**Continue with the remaining 13 prompts following the same pattern...**

---

## Success Metrics & Validation

### Technical Success Criteria
- [ ] Cross-platform deployment on iOS, Android, Web, Desktop
- [ ] Real-time audio processing with <100ms latency
- [ ] 95%+ transcription accuracy with hybrid recognition
- [ ] Stable Bluetooth connectivity with Even Realities glasses
- [ ] AI analysis completion within 30 seconds for 10-minute conversations
- [ ] 90%+ test coverage across all core services
- [ ] App store approval on all target platforms
- [ ] Performance benchmarks meeting or exceeding iOS version

### User Experience Criteria
- [ ] Intuitive onboarding process (<5 minutes setup)
- [ ] Seamless cross-platform synchronization
- [ ] Accessible design meeting WCAG guidelines
- [ ] Responsive performance on low-end devices
- [ ] Offline functionality for core features
- [ ] Multi-language support for major markets
- [ ] Professional UI/UX matching platform conventions

### Business Success Criteria
- [ ] Feature parity with existing iOS application
- [ ] Reduced development maintenance overhead
- [ ] Expanded market reach to Android users
- [ ] Web accessibility for broader audience
- [ ] Enterprise deployment capabilities
- [ ] Scalable architecture for future feature additions
- [ ] Cost-effective cross-platform maintenance model

This comprehensive migration plan provides a structured approach to transforming the Helix iOS app into a full-featured cross-platform Flutter application while maintaining all existing functionality and adding new platform-specific capabilities.