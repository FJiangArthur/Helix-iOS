# Helix Architecture Document

## 1. System Overview

Helix is a Flutter-based companion app for Even Realities smart glasses that provides real-time conversation recording, transcription, and AI-powered analysis. The architecture follows a **clean slate, incremental approach** that eliminates complexity while maintaining functionality.

## 2. Core Design Philosophy

### 2.1 "Linus Torvalds" Principles
- **Good Taste**: Simple data structures with clear ownership
- **No Complex State Management**: Direct service-to-UI communication
- **Incremental Building**: Each component works before adding the next
- **Eliminate Special Cases**: Clean, predictable data flow

### 2.2 Clean Architecture
```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│ Even Realities  │◄──►│  Flutter App    │◄──►│  Cloud Services │
│    Glasses      │    │    (Helix)      │    │   (LLM APIs)    │
└─────────────────┘    └─────────────────┘    └─────────────────┘
        │                       │                       │
        │                       │                       │
   ┌────▼────┐            ┌─────▼─────┐           ┌─────▼─────┐
   │ HUD     │            │ Audio     │           │ OpenAI/   │
   │ Display │            │ Service   │           │ Anthropic │
   └─────────┘            └───────────┘           └───────────┘
```

## 3. Current Implementation (Proven)

### 3.1 Audio Foundation ✅ COMPLETED
```
lib/
├── services/
│   ├── audio_service.dart          # Clean interface
│   └── implementations/
│       └── audio_service_impl.dart # flutter_sound implementation
├── models/
│   └── audio_configuration.dart    # Immutable config with Freezed
├── screens/
│   ├── recording_screen.dart       # Direct service integration
│   └── file_management_screen.dart # Simple file operations
└── core/utils/
    └── exceptions.dart             # Audio-specific exceptions
```

**Working Features:**
- Real-time audio recording with flutter_sound
- Live audio level visualization
- Recording timer with actual elapsed time
- File management with playback
- Permission handling

### 3.2 Future Components (Planned Incremental Addition)

**Phase 2: Speech-to-Text (Steps 6-9)**
- TranscriptionService using flutter speech_to_text
- Real-time transcription display
- Basic speaker identification
- Conversation persistence

**Phase 3: Smart Data Management (Steps 10-12)**
- Conversation sessions and organization
- Search and filtering capabilities
- Export functionality

**Phase 4: AI Analysis (Steps 13-15)**
- LLM service integration (OpenAI/Anthropic)
- Fact-checking capabilities
- Conversation insights and summaries

**Phase 5: Smart Glasses (Steps 16-18)**
- Even Realities Bluetooth integration
- HUD display rendering
- Gesture controls

## 4. Data Flow Architecture

### 4.1 Current Simple Data Flow
```
AudioService ──► UI (StatefulWidget)
     │              │
     ├─ audioLevelStream ──► Visual Indicator
     ├─ recordingDurationStream ──► Timer Display  
     └─ currentRecordingPath ──► File Management
```

**Key Principles:**
- **No Central State Manager**: UI directly consumes service streams
- **Clear Data Ownership**: AudioService owns all audio-related state
- **Simple Communication**: Streams for real-time data, direct calls for actions

### 4.2 Future Data Flow (Incremental)
```
Phase 2: AudioService ──► TranscriptionService ──► UI
Phase 3: Multiple Services ──► Simple Data Models ──► UI
Phase 4: Services ──► LLM Analysis ──► Enhanced UI
Phase 5: All Services ──► Glasses HUD + Mobile UI
```

## 5. Technology Stack

### 5.1 Current Stack (Proven Working)
```yaml
Framework: Flutter 3.24+
Language: Dart 3.5+
Audio: flutter_sound ^9.2.13
Permissions: permission_handler ^10.2.0
Data Models: freezed_annotation ^2.4.1, json_annotation ^4.8.1
State Management: Plain StatefulWidget + Streams
iOS Target: iOS 15.0+
```

### 5.2 Future Additions (By Phase)
**Phase 2: Speech-to-Text**
- speech_to_text package
- Basic transcription models

**Phase 3: Data Management**  
- sqflite for local database
- path_provider for file handling

**Phase 4: AI Integration**
- http/dio for API calls
- OpenAI/Anthropic API clients

**Phase 5: Bluetooth Glasses**
- flutter_bluetooth_serial
- Even Realities SDK integration

## 6. Security & Privacy

### 6.1 Current Implementation
- **Local-only storage**: Audio files in device temp directory
- **Permission-based access**: User controls microphone access
- **No cloud sync**: All data stays on device
- **Simple file cleanup**: Users can delete recordings

### 6.2 Future Privacy Enhancements
- **Optional cloud sync** with encryption
- **Conversation expiration** settings
- **Speaker anonymization** for shared data
- **Granular AI analysis** consent

## 7. Performance Requirements

### 7.1 Current Benchmarks (Achieved)
- **Audio Recording**: Real-time 16kHz sampling
- **UI Updates**: 30fps audio level visualization
- **Memory Usage**: <50MB for basic audio recording
- **Battery Impact**: Minimal additional drain
- **File I/O**: Instant playback of recorded audio

### 7.2 Future Performance Targets
- **STT Latency**: <500ms for real-time transcription
- **LLM Response**: <3s for analysis results
- **Glasses HUD**: 60fps for smooth display updates
- **Overall Memory**: <200MB with all features

## 8. Deployment Strategy

### 8.1 Incremental Deployment
- **Phase-by-phase releases**: Each phase is a deployable app
- **Feature flags**: Enable/disable features as they're built
- **TestFlight distribution**: Continuous beta testing
- **App Store updates**: Regular incremental improvements

### 8.2 Quality Assurance
- **Build verification**: Each step must build and run
- **Function testing**: Manual verification of each feature
- **Device testing**: Real iOS device validation
- **User feedback**: Early user testing for each phase

## 9. Migration Strategy

### 9.1 From Previous Architecture
- ✅ **Eliminated**: AppStateProvider god object
- ✅ **Eliminated**: Service Locator pattern
- ✅ **Eliminated**: Complex UI hierarchy
- ✅ **Simplified**: Direct service-to-UI communication

### 9.2 Lessons Learned
- **Complexity is the enemy**: Simple solutions work better
- **Incremental is safer**: Build working features step-by-step
- **Direct communication**: Eliminate unnecessary abstractions
- **Good taste wins**: Clean data structures over complex coordinators