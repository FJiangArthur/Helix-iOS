# Architecture Document

## 1. System Overview

Helix is a real-time conversation analysis iOS application that integrates with Even Realities smart glasses to provide AI-powered insights displayed on the glasses HUD. The system processes live audio conversations, performs speaker identification, transcribes speech to text, and leverages LLM APIs for intelligent analysis including fact-checking.

## 2. High-Level Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│ Even Realities  │◄──►│   iOS App       │◄──►│  Cloud Services │
│    Glasses      │    │    (Helix)      │    │   (LLM APIs)    │
└─────────────────┘    └─────────────────┘    └─────────────────┘
        │                       │                       │
        │                       │                       │
   ┌────▼────┐            ┌─────▼─────┐           ┌─────▼─────┐
   │ HUD     │            │ Audio     │           │ OpenAI/   │
   │ Display │            │ Pipeline  │           │ Anthropic │
   └─────────┘            └───────────┘           └───────────┘
```

## 3. Core Components

### 3.1 Audio Processing Pipeline
- **AudioCaptureManager**: Captures audio from device microphones
- **NoiseReductionProcessor**: Removes background noise and echo
- **SpeakerDiarizationEngine**: Identifies and tracks multiple speakers
- **VoiceActivityDetector**: Detects speech segments and silence

### 3.2 Speech Recognition System
- **StreamingSTTService**: Real-time speech-to-text conversion
- **TranscriptionProcessor**: Post-processes transcription for accuracy
- **LanguageDetector**: Identifies spoken language
- **ConfidenceScorer**: Provides transcription quality metrics

### 3.3 AI Analysis Engine
- **ConversationContextManager**: Maintains conversation state and history
- **FactCheckingService**: Verifies factual claims against knowledge bases
- **ClaimDetector**: Identifies factual statements in conversations
- **LLMOrchestrator**: Manages multiple LLM provider integrations

### 3.4 Even Realities Integration
- **GlassesConnectionManager**: Handles Bluetooth LE communication
- **HUDRenderer**: Manages display rendering and positioning
- **GestureProcessor**: Processes user gestures for interaction
- **BatteryMonitor**: Tracks glasses battery status

### 3.5 Data Management
- **ConversationStore**: Local storage for conversation data
- **PrivacyManager**: Enforces data protection policies
- **SyncManager**: Handles cloud synchronization (optional)
- **CacheManager**: Optimizes local data storage

### 3.6 User Interface
- **ConversationViewController**: Real-time conversation monitoring
- **HistoryViewController**: Browse past conversations
- **SettingsViewController**: App configuration and preferences
- **OnboardingViewController**: Initial setup and tutorials

## 4. Data Flow Architecture

### 4.1 Real-time Processing Flow
```
Audio Input → Noise Reduction → Speaker Diarization → STT → Context Building → LLM Analysis → HUD Display
     ↓              ↓                ↓                ↓          ↓              ↓           ↓
  Raw Audio    Clean Audio    Speaker Segments   Text/Speaker  Conversation   Analysis    Visual
                                                              Context        Results     Feedback
```

### 4.2 Data Storage Flow
```
Conversation Data → Privacy Filter → Local Encryption → Core Data Storage
                                                             ↓
                                            Optional Cloud Sync (CloudKit)
```

## 5. Technology Stack

### 5.1 iOS Frameworks
- **SwiftUI**: Modern declarative UI framework
- **Combine**: Reactive programming for data flow
- **AVFoundation**: Audio capture and processing
- **Speech**: On-device speech recognition
- **Core ML**: Local machine learning inference
- **Core Data**: Local data persistence
- **Core Bluetooth**: Even Realities glasses communication

### 5.2 External Dependencies
- **OpenAI Swift SDK**: GPT integration for analysis
- **Anthropic SDK**: Claude integration for analysis
- **Whisper.cpp**: Local speech recognition option
- **Even Realities SDK**: Glasses hardware integration

### 5.3 Cloud Services
- **OpenAI API**: GPT-4 for conversation analysis
- **Anthropic API**: Claude for fact-checking
- **Azure Speech Services**: Backup STT service
- **CloudKit**: Optional data synchronization

## 6. Security & Privacy

### 6.1 Data Protection
- **End-to-end encryption** for all conversation data
- **Local-first architecture** with optional cloud sync
- **Automatic data expiration** based on user preferences
- **Zero-knowledge architecture** for cloud storage

### 6.2 Privacy Controls
- **Granular consent management** for each feature
- **Speaker anonymization** options
- **Selective data sharing** controls
- **GDPR/CCPA compliance** measures

## 7. Performance Requirements

### 7.1 Real-time Processing
- **Audio latency**: <100ms for capture to processing
- **STT latency**: <200ms for speech to text
- **LLM response time**: <2s for analysis results
- **HUD update frequency**: 60fps for smooth display

### 7.2 Resource Management
- **Memory usage**: <200MB sustained operation
- **CPU usage**: <30% average load
- **Battery impact**: <10% additional drain per hour
- **Network usage**: <1MB per minute of conversation

## 8. Scalability Considerations

### 8.1 Horizontal Scaling
- **Microservices architecture** for cloud components
- **Load balancing** for LLM API requests
- **Caching strategies** for frequently accessed data
- **CDN integration** for static resources

### 8.2 Vertical Scaling
- **Optimized algorithms** for mobile processing
- **Background processing** for non-critical tasks
- **Adaptive quality** based on device capabilities
- **Progressive enhancement** for feature availability

## 9. Integration Points

### 9.1 Even Realities Glasses
- **Bluetooth LE protocol** for communication
- **Custom HUD rendering** for text display
- **Gesture recognition** for user interaction
- **Battery status monitoring** for power management

### 9.2 LLM Providers
- **REST API integration** with rate limiting
- **Streaming responses** for real-time feedback
- **Fallback providers** for reliability
- **Cost optimization** through intelligent routing

## 10. Deployment Architecture

### 10.1 iOS App Distribution
- **App Store distribution** for general availability
- **TestFlight beta testing** for development cycles
- **Enterprise distribution** for business customers
- **Side-loading support** for development

### 10.2 Cloud Infrastructure
- **Multi-region deployment** for low latency
- **Auto-scaling groups** for demand management
- **Monitoring and alerting** for system health
- **Disaster recovery** for business continuity