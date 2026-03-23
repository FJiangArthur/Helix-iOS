# Helix Architecture Diagram

## Full System Overview

```mermaid
graph TB
    subgraph External["☁ External APIs"]
        OpenAI["OpenAI API"]
        Anthropic["Anthropic API"]
        DeepSeek["DeepSeek API"]
        Qwen["Qwen API"]
        Zhipu["Zhipu API"]
    end

    subgraph Hardware["Even Realities G1 Glasses"]
        GlassesHW["G1 Hardware"]
        GlassesMic["Glasses Microphone"]
        GlassesHUD["HUD Display"]
        GlassesTouchpad["Touchpad L/R"]
        GlassesTilt["Tilt Sensor"]
    end

    subgraph Frontend["Frontend — Flutter UI Layer"]
        App["HelixApp / MainScreen"]
        HomeScreen["HomeScreen<br/>(Assistant Tab)"]
        G1TestScreen["G1TestScreen<br/>(Glasses Tab)"]
        HistoryScreen["ConversationHistoryScreen<br/>(History Tab)"]
        DetailScreen["DetailAnalysisScreen<br/>(Detail Tab)"]
        SettingsScreen["SettingsScreen<br/>(Settings Tab)"]
        OnboardingScreen["OnboardingScreen"]
        RecordingScreen["RecordingScreen"]
        FileManagementScreen["FileManagementScreen"]
        AIAssistantScreen["AIAssistantScreen"]
        EvenFeaturesScreen["EvenFeaturesScreen"]
        EvenAIHistoryScreen["EvenAIHistoryScreen"]

        subgraph FeaturePages["Feature Sub-Pages"]
            BmpPage["BmpPage"]
            TextPage["TextPage"]
            NotificationPage["Notification Pages"]
        end

        subgraph Widgets["Shared Widgets"]
            AnimatedText["AnimatedTextStream"]
            GlassCard["GlassCard"]
            GlowButton["GlowButton"]
            HomeModules["HomeAssistantModules"]
            StatusIndicator["StatusIndicator"]
        end

        Theme["HelixTheme"]
    end

    subgraph BLEService["BLE Service — Bluetooth Communication"]
        BleManager["BleManager<br/>(MethodChannel bridge)"]
        Proto["Proto<br/>(Command encoder)"]
        EvenaiProto["EvenaiProto<br/>(AI data packets)"]
        GlassesProtocol["GlassesProtocol<br/>(HUD state encoding)"]
        BleReceive["BleReceive<br/>(Response parser)"]
    end

    subgraph ConversationService["Conversation Intelligence Service"]
        ConversationEngine["ConversationEngine<br/>(Pipeline orchestrator)"]
        ConversationContext["ConversationContext<br/>(History & prompts)"]
        ListeningSession["ConversationListeningSession<br/>(Speech recognition)"]
        HandoffMemory["HandoffMemory<br/>(Text handoff tracking)"]
    end

    subgraph AudioService["Audio Service"]
        AudioInterface["AudioService<br/>(Interface)"]
        AudioImpl["AudioServiceImpl<br/>(flutter_sound)"]
        AudioBuffer["AudioBufferManager<br/>(Glasses audio buffer)"]
        RecordingCoord["RecordingCoordinator<br/>(Unified toggle)"]
    end

    subgraph LLMService["LLM Service — AI Provider Layer"]
        LlmService["LlmService<br/>(Provider manager)"]
        LlmProvider["LlmProvider<br/>(Interface)"]
        OpenAiProvider["OpenAiProvider"]
        AnthropicProvider["AnthropicProvider"]
        DeepSeekProvider["DeepSeekProvider"]
        QwenProvider["QwenProvider"]
        ZhipuProvider["ZhipuProvider"]
        OpenAiCompatible["OpenAiCompatibleProvider<br/>(Base class)"]
    end

    subgraph HUDService["HUD / Display Service"]
        HudController["HudController<br/>(Screen & intent router)"]
        HudIntent["HudIntent<br/>(idle/liveListening/quickAsk/...)"]
        AnswerPresenter["GlassesAnswerPresenter<br/>(Paginated delivery)"]
        TextPaginator["TextPaginator<br/>(Page layout engine)"]
        TextService["TextService<br/>(Text transfer)"]
    end

    subgraph DashboardSvc["Dashboard Service"]
        DashboardService["DashboardService<br/>(Tilt-triggered dashboard)"]
        DashboardSnapshot["DashboardSnapshot<br/>(Data model)"]
    end

    subgraph GlassesCoordinator["Glasses Coordinator"]
        EvenAI["EvenAI<br/>(Session coordinator)"]
        FeaturesServices["FeaturesServices<br/>(BMP updates)"]
        BmpUpdateManager["BmpUpdateManager"]
    end

    subgraph ConfigService["Settings & Config Service"]
        SettingsManager["SettingsManager<br/>(SharedPreferences + SecureStorage)"]
        ProviderErrorState["ProviderErrorState"]
    end

    subgraph Models["Data Models"]
        AudioConfig["AudioConfiguration"]
        AudioChunk["AudioChunk"]
        BleHealthMetrics["BleHealthMetrics"]
        BleTransaction["BleTransaction"]
        AssistantProfile["AssistantProfile"]
        AssistantSession["AssistantSessionMeta"]
        EvenaiModel["EvenaiModel"]
    end

    %% ── Frontend Navigation ──
    App --> HomeScreen
    App --> G1TestScreen
    App --> HistoryScreen
    App --> DetailScreen
    App --> SettingsScreen
    App -.-> OnboardingScreen

    %% ── Frontend → Services ──
    HomeScreen --> ConversationEngine
    HomeScreen --> RecordingCoord
    HomeScreen --> EvenAI
    HomeScreen --> HudController
    G1TestScreen --> BleManager
    G1TestScreen --> EvenAI
    G1TestScreen --> FeaturesServices
    HistoryScreen --> ConversationEngine
    DetailScreen --> ConversationEngine
    DetailScreen --> LlmService
    SettingsScreen --> SettingsManager
    SettingsScreen --> LlmService
    SettingsScreen --> BleManager
    RecordingScreen --> AudioInterface
    AIAssistantScreen --> LlmService
    EvenFeaturesScreen --> FeaturesServices
    TextPage --> TextService

    %% ── Conversation Intelligence ──
    ConversationEngine --> LlmService
    ConversationEngine --> HudController
    ConversationEngine --> Proto
    ConversationEngine --> SettingsManager
    ConversationEngine --> TextPaginator
    ConversationEngine --> ConversationContext
    ListeningSession --> ConversationEngine
    ListeningSession --> BleManager

    %% ── Audio Pipeline ──
    RecordingCoord --> ListeningSession
    RecordingCoord --> AudioImpl
    RecordingCoord --> SettingsManager
    AudioImpl -.-> AudioInterface

    %% ── EvenAI Coordinator ──
    EvenAI --> AudioBuffer
    EvenAI --> HudController
    EvenAI --> ListeningSession
    EvenAI --> ConversationEngine
    EvenAI --> AnswerPresenter
    EvenAI --> Proto

    %% ── HUD/Display ──
    HudController --> Proto
    HudController --> BleManager
    AnswerPresenter --> Proto
    AnswerPresenter --> TextPaginator
    AnswerPresenter --> TextService
    TextService --> Proto
    TextService --> TextPaginator
    TextService --> HudController

    %% ── BLE Layer ──
    BleManager --> Proto
    Proto --> EvenaiProto
    Proto --> GlassesProtocol
    BleManager <--> GlassesHW
    GlassesMic --> AudioBuffer
    GlassesHUD <-- Proto
    GlassesTouchpad --> EvenAI
    GlassesTilt --> DashboardService

    %% ── Dashboard ──
    DashboardService --> BleManager
    DashboardService --> ConversationEngine
    DashboardService --> HudController
    DashboardService --> Proto
    DashboardService --> SettingsManager

    %% ── LLM Providers ──
    LlmService --> LlmProvider
    OpenAiProvider -.-> LlmProvider
    AnthropicProvider -.-> LlmProvider
    DeepSeekProvider -.-> LlmProvider
    QwenProvider -.-> LlmProvider
    ZhipuProvider -.-> LlmProvider
    DeepSeekProvider --> OpenAiCompatible
    QwenProvider --> OpenAiCompatible
    ZhipuProvider --> OpenAiCompatible
    OpenAiProvider --> OpenAI
    AnthropicProvider --> Anthropic
    DeepSeekProvider --> DeepSeek
    QwenProvider --> Qwen
    ZhipuProvider --> Zhipu

    %% ── Features ──
    FeaturesServices --> BmpUpdateManager
    FeaturesServices --> Proto
    FeaturesServices --> BleManager

    %% ── Styling ──
    classDef frontend fill:#1a1a2e,stroke:#00d4ff,color:#fff
    classDef service fill:#16213e,stroke:#0f3460,color:#fff
    classDef external fill:#0f3460,stroke:#e94560,color:#fff
    classDef hardware fill:#533483,stroke:#e94560,color:#fff
    classDef model fill:#2a2a4a,stroke:#7f8c8d,color:#ccc

    class App,HomeScreen,G1TestScreen,HistoryScreen,DetailScreen,SettingsScreen,OnboardingScreen,RecordingScreen,FileManagementScreen,AIAssistantScreen,EvenFeaturesScreen,EvenAIHistoryScreen,BmpPage,TextPage,NotificationPage,AnimatedText,GlassCard,GlowButton,HomeModules,StatusIndicator,Theme frontend
    class BleManager,Proto,EvenaiProto,GlassesProtocol,BleReceive,ConversationEngine,ConversationContext,ListeningSession,HandoffMemory,AudioInterface,AudioImpl,AudioBuffer,RecordingCoord,LlmService,LlmProvider,OpenAiProvider,AnthropicProvider,DeepSeekProvider,QwenProvider,ZhipuProvider,OpenAiCompatible,HudController,HudIntent,AnswerPresenter,TextPaginator,TextService,DashboardService,DashboardSnapshot,EvenAI,FeaturesServices,BmpUpdateManager,SettingsManager,ProviderErrorState service
    class OpenAI,Anthropic,DeepSeek,Qwen,Zhipu external
    class GlassesHW,GlassesMic,GlassesHUD,GlassesTouchpad,GlassesTilt hardware
    class AudioConfig,AudioChunk,BleHealthMetrics,BleTransaction,AssistantProfile,AssistantSession,EvenaiModel model
```

## Simplified Data Flow

```mermaid
flowchart LR
    subgraph Input
        Phone["Phone Mic"]
        Glasses["Glasses Mic"]
        Touch["Glasses Touchpad"]
        Tilt["Glasses Tilt"]
    end

    subgraph Processing
        Speech["Speech Recognition<br/>(iOS native)"]
        Engine["ConversationEngine<br/>(Question Detection)"]
        LLM["LLM Service<br/>(OpenAI/Anthropic/...)"]
    end

    subgraph Output
        MobileUI["Mobile UI<br/>(Flutter Screens)"]
        GlassesHUD["Glasses HUD"]
    end

    Phone --> Speech
    Glasses --> Speech
    Speech --> Engine
    Engine --> LLM
    LLM --> Engine
    Engine --> MobileUI
    Engine --> GlassesHUD
    Touch --> Engine
    Tilt --> Engine
```

## Service Dependency Map

```mermaid
flowchart TD
    main["main.dart"] --> SettingsManager
    main --> BleManager
    main --> LlmService
    main --> DashboardService
    main --> ConversationEngine

    ConversationEngine --> LlmService
    ConversationEngine --> HudController
    ConversationEngine --> SettingsManager
    ConversationEngine --> TextPaginator
    ConversationEngine --> Proto

    EvenAI --> ConversationListeningSession
    EvenAI --> HudController
    EvenAI --> AudioBufferManager
    EvenAI --> GlassesAnswerPresenter
    EvenAI --> Proto

    DashboardService --> BleManager
    DashboardService --> ConversationEngine
    DashboardService --> HudController
    DashboardService --> SettingsManager

    RecordingCoordinator --> ConversationListeningSession
    RecordingCoordinator --> AudioServiceImpl
    RecordingCoordinator --> SettingsManager

    ConversationListeningSession --> ConversationEngine
    ConversationListeningSession --> BleManager

    HudController --> Proto
    HudController --> BleManager

    GlassesAnswerPresenter --> Proto
    GlassesAnswerPresenter --> TextPaginator
    GlassesAnswerPresenter --> TextService

    TextService --> Proto
    TextService --> HudController
    TextService --> TextPaginator

    LlmService --> OpenAiProvider
    LlmService --> AnthropicProvider
    LlmService --> DeepSeekProvider
    LlmService --> QwenProvider
    LlmService --> ZhipuProvider

    Proto --> BleManager
    Proto --> EvenaiProto
    Proto --> GlassesProtocol

    FeaturesServices --> BmpUpdateManager
    FeaturesServices --> Proto
    FeaturesServices --> BleManager
```

## Native iOS Platform Bridge

```mermaid
graph TB
    subgraph FlutterLayer["Flutter / Dart Layer"]
        BleManager_D["BleManager"]
        ListeningSession_D["ConversationListeningSession"]
        ConvEngine_D["ConversationEngine"]
    end

    subgraph PlatformChannels["Platform Channels"]
        MethodCh["MethodChannel<br/>'method.bluetooth'"]
        EventBle["EventChannel<br/>'eventBleReceive'"]
        EventSpeech["EventChannel<br/>'eventSpeechRecognize'"]
    end

    subgraph NativeiOS["Native iOS Layer (Swift)"]
        AppDelegate["AppDelegate<br/>(Channel wiring)"]

        subgraph BluetoothStack["Bluetooth Stack"]
            BluetoothMgr["BluetoothManager<br/>(CBCentralManager)"]
            GattProto["GattProtocal<br/>(BLE command IDs)"]
            ServiceIds["ServiceIdentifiers<br/>(UART UUIDs)"]
            PcmConverter["PcmConverter<br/>(LC3 -> PCM)"]
        end

        subgraph SpeechStack["Speech / Transcription Stack"]
            SpeechRecog["SpeechStreamRecognizer<br/>(SFSpeechRecognizer)"]
            OpenAIRT["OpenAIRealtimeTranscriber<br/>(WebSocket to OpenAI)"]
            AudioResamp["AudioResampler<br/>(16kHz -> 24kHz)"]
        end

        subgraph Peripherals["CoreBluetooth Peripherals"]
            LeftGlass["Left Peripheral<br/>(CBPeripheral)"]
            RightGlass["Right Peripheral<br/>(CBPeripheral)"]
        end
    end

    subgraph ExternalRT["External Realtime API"]
        OpenAIWS["OpenAI Realtime API<br/>(WebSocket wss://)"]
    end

    %% Flutter -> Native
    BleManager_D -- "send / startScan /<br/>connectToGlasses" --> MethodCh
    ListeningSession_D -- "startEvenAI /<br/>stopEvenAI" --> MethodCh
    MethodCh --> AppDelegate

    %% Native -> Flutter
    AppDelegate --> BluetoothMgr
    AppDelegate --> SpeechRecog
    BluetoothMgr -- "glassesConnected /<br/>glassesDisconnected /<br/>foundPairedGlasses" --> MethodCh
    MethodCh --> BleManager_D
    BluetoothMgr -- "BLE data / VoiceChunk" --> EventBle
    EventBle --> BleManager_D
    SpeechRecog -- "partial / final text" --> EventSpeech
    EventSpeech --> ListeningSession_D
    ListeningSession_D --> ConvEngine_D

    %% Native internals
    BluetoothMgr --> GattProto
    BluetoothMgr --> ServiceIds
    BluetoothMgr --> PcmConverter
    BluetoothMgr <--> LeftGlass
    BluetoothMgr <--> RightGlass

    SpeechRecog --> OpenAIRT
    SpeechRecog --> AudioResamp
    OpenAIRT -- "wss:// audio stream" --> OpenAIWS
    OpenAIWS -- "transcript / response" --> OpenAIRT

    LeftGlass -- "mic PCM data" --> SpeechRecog
    RightGlass -- "mic PCM data" --> SpeechRecog

    %% Transcription backends
    SpeechRecog -. "Apple Cloud" .-> AppleSpeech["Apple Speech<br/>(SFSpeechRecognizer)"]
    SpeechRecog -. "Apple On-Device" .-> AppleLocal["Apple On-Device<br/>(SFSpeechRecognizer<br/>requiresOnDeviceRecognition)"]
    SpeechRecog -. "OpenAI" .-> OpenAIRT
```

## Conversation Intelligence Pipeline (Sequence)

```mermaid
sequenceDiagram
    participant Mic as Microphone<br/>(Phone/Glasses)
    participant Native as iOS Native<br/>(SpeechStreamRecognizer)
    participant Session as ConversationListeningSession
    participant Engine as ConversationEngine
    participant LLM as LlmService
    participant HUD as HudController
    participant Proto as Proto
    participant Glasses as G1 Glasses HUD

    Mic->>Native: Audio PCM stream
    Native->>Native: Speech recognition (Apple/OpenAI)

    loop Partial results
        Native->>Session: eventSpeechRecognize (partial text)
        Session->>Engine: onTranscriptionUpdate(text)
        Engine->>Engine: Progressive sentence finalization
        Engine-->>Engine: Emit TranscriptSnapshot stream
    end

    Native->>Session: eventSpeechRecognize (final text)
    Session->>Engine: onTranscriptionFinalized(text)
    Engine->>Engine: Schedule question analysis

    alt Auto-detect question found
        Engine->>Engine: _analyzeTranscriptForQuestion()
        Engine-->>Engine: Emit QuestionDetectionResult
        Engine->>Engine: _generateResponse(question)
        Engine->>LLM: streamResponse(systemPrompt, messages)
        LLM-->>Engine: Stream<String> chunks

        loop Streaming response chunks
            Engine->>Engine: Buffer + emit aiResponseStream
            Engine->>Proto: sendEvenAIData(chunk, isStreaming)
            Proto->>Glasses: BLE L+R (AI frame)
        end

        Engine->>Engine: Record ConversationTurn
        Engine->>Engine: Persist history (SharedPreferences)
        Engine->>HUD: Status -> listening
    end

    alt Silence detected (5s)
        Engine->>LLM: getResponse(suggestion prompt)
        LLM-->>Engine: ProactiveSuggestion JSON
        Engine-->>Engine: Emit proactiveSuggestionStream
    end

    alt Interview mode + behavioral question
        Engine->>Engine: _checkForBehavioralQuestion()
        Engine-->>Engine: Emit CoachingPrompt (STAR)
    end
```

## Glasses Interaction Flow (Sequence)

```mermaid
sequenceDiagram
    participant User as User Action
    participant GlassesHW as G1 Glasses
    participant BLE as BleManager
    participant EvenAI as EvenAI Coordinator
    participant Session as ConversationListeningSession
    participant HudCtrl as HudController
    participant Dashboard as DashboardService
    participant Proto as Proto
    participant Presenter as GlassesAnswerPresenter

    Note over User,GlassesHW: Glasses triggers EvenAI start (double-tap)
    GlassesHW->>BLE: BLE notify (0xF5 evenaiStart)
    BLE->>EvenAI: toStartEvenAIByOS()
    EvenAI->>Session: startSession(source: glasses)
    Session->>Session: invokeMethod("startEvenAI")
    EvenAI->>HudCtrl: beginLiveListening()
    HudCtrl->>Proto: pushScreen(0x01)
    Proto->>GlassesHW: Show EvenAI screen

    Note over User,GlassesHW: Recording ends
    GlassesHW->>BLE: BLE notify (evenaiRecordOver)
    BLE->>EvenAI: recordOverByOS()
    EvenAI->>Session: finalizePendingTranscript()
    EvenAI->>Session: stopSession()

    Note over User,GlassesHW: Right touchpad tap (analyze)
    GlassesHW->>BLE: BLE notify (pageForward)
    BLE->>EvenAI: handleRightTouch()
    alt Intent = liveListening
        EvenAI->>EvenAI: forceQuestionAnalysis()
    else Intent = quickAsk
        EvenAI->>Presenter: nextPage()
        Presenter->>Proto: sendEvenAIData(nextPageText)
        Proto->>GlassesHW: Display next page
    end

    Note over User,GlassesHW: Left touchpad tap (pause/back)
    GlassesHW->>BLE: BLE notify (pageBack)
    BLE->>EvenAI: handleLeftTouch()
    alt Intent = liveListening
        EvenAI->>Session: pauseTranscription()
        EvenAI->>Proto: Flash "PAUSED"
    else Intent = quickAsk
        EvenAI->>Presenter: previousPage()
    end

    Note over User,GlassesHW: Head tilt up (dashboard)
    GlassesHW->>BLE: BLE notify (0xF5 headUp)
    BLE->>Dashboard: handleDeviceEvent(headUp)
    Dashboard->>Dashboard: Build DashboardSnapshot
    Dashboard->>HudCtrl: beginDashboard()
    Dashboard->>Proto: sendEvenAIData(snapshot text)
    Proto->>GlassesHW: Display dashboard overlay
    Dashboard->>Dashboard: Start auto-hide timer
```

## LLM Provider Class Hierarchy

```mermaid
classDiagram
    class LlmProvider {
        <<abstract>>
        +String name
        +String id
        +List~String~ availableModels
        +String defaultModel
        +updateApiKey(String)
        +queryAvailableModels() Future~List~String~~
        +supportsRealtimeModel(String) bool
        +streamResponse() Stream~String~
        +getResponse() Future~String~
        +testConnection(String) Future~bool~
    }

    class OpenAiProvider {
        -String _apiKey
        +name = "OpenAI"
        +id = "openai"
        +defaultModel = "gpt-4o"
        +queryAvailableModels()
        +supportsRealtimeModel()
    }

    class AnthropicProvider {
        -String _apiKey
        +name = "Anthropic"
        +id = "anthropic"
        +defaultModel = "sonnet-4-20250514"
    }

    class OpenAiCompatibleProvider {
        <<abstract>>
        +String baseUrl
        +streamResponse()
        +getResponse()
        +testConnection()
    }

    class DeepSeekProvider {
        +name = "DeepSeek"
        +id = "deepseek"
        +baseUrl = "api.deepseek.com"
    }

    class QwenProvider {
        +name = "Qwen"
        +id = "qwen"
        +baseUrl = "dashscope..."
    }

    class ZhipuProvider {
        +name = "Zhipu"
        +id = "zhipu"
        +baseUrl = "open.bigmodel..."
    }

    class LlmService {
        -Map providers
        -Map apiKeys
        -String _activeProviderId
        +registerProvider()
        +setApiKey()
        +setActiveProvider()
        +streamResponse()
        +getResponse()
        +testConnection()
        +initializeDefaults()
    }

    class ChatMessage {
        +String role
        +String content
        +DateTime timestamp
        +toJson()
    }

    LlmProvider <|-- OpenAiProvider
    LlmProvider <|-- AnthropicProvider
    LlmProvider <|-- OpenAiCompatibleProvider
    OpenAiCompatibleProvider <|-- DeepSeekProvider
    OpenAiCompatibleProvider <|-- QwenProvider
    OpenAiCompatibleProvider <|-- ZhipuProvider
    LlmService o-- LlmProvider : manages many
    LlmProvider ..> ChatMessage : uses
```

## HUD Intent State Machine

```mermaid
stateDiagram-v2
    [*] --> idle

    idle --> liveListening : EvenAI start<br/>(glasses double-tap)
    idle --> quickAsk : User asks question<br/>(askQuestion)
    idle --> textTransfer : Send text to glasses<br/>(TextService.startSendText)
    idle --> notification : Notification received<br/>(Proto.sendNotify)
    idle --> dashboard : Head tilt up<br/>(DashboardService)

    liveListening --> idle : EvenAI stop / exit
    liveListening --> quickAsk : Question detected → answer

    quickAsk --> idle : Answer delivered / timeout
    quickAsk --> liveListening : Resume listening

    textTransfer --> idle : Transfer complete / exit

    notification --> idle : Auto-dismiss / touch

    dashboard --> idle : Auto-hide timer / touch
    dashboard --> liveListening : Resume if was listening
    dashboard --> quickAsk : Restore if was answering

    note right of liveListening
        Left touch: pause/resume
        Right touch: force analyze
    end note

    note right of quickAsk
        Left touch: prev page
        Right touch: next page
    end note
```

## ConversationEngine Streams & Events

```mermaid
graph LR
    subgraph Inputs["Input Events"]
        TU["onTranscriptionUpdate()"]
        TF["onTranscriptionFinalized()"]
        RR["onRealtimeResponse()"]
        AQ["askQuestion()"]
        FM["forceQuestionAnalysis()"]
        SM["setMode()"]
    end

    subgraph Engine["ConversationEngine"]
        State["Internal State<br/>- _history<br/>- _finalizedSegments<br/>- _partialTranscription<br/>- _mode<br/>- _isActive"]
        QD["Question Detection<br/>(LLM analysis)"]
        RG["Response Generation<br/>(LLM streaming)"]
        PS["Proactive Suggestions<br/>(silence timer)"]
        CP["Coaching Prompts<br/>(STAR method)"]
        PCA["Post-Conversation<br/>Analysis"]
    end

    subgraph OutputStreams["Output Streams"]
        TS["transcriptionStream<br/>(String)"]
        TSS["transcriptSnapshotStream<br/>(TranscriptSnapshot)"]
        ARS["aiResponseStream<br/>(String)"]
        MS["modeStream<br/>(ConversationMode)"]
        QDS["questionDetectedStream<br/>(DetectedQuestion)"]
        QDRS["questionDetectionStream<br/>(QuestionDetectionResult)"]
        SS["statusStream<br/>(EngineStatus)"]
        PSS["proactiveSuggestionStream<br/>(ProactiveSuggestion)"]
        CS["coachingStream<br/>(CoachingPrompt)"]
        FCS["followUpChipsStream<br/>(List&lt;String&gt;)"]
        PES["providerErrorStream<br/>(ProviderErrorState?)"]
        PCAS["postConversationAnalysisStream<br/>(Map?)"]
    end

    TU --> State
    TF --> State
    RR --> State
    AQ --> State
    FM --> QD
    SM --> State

    State --> QD
    QD --> RG
    State --> PS
    State --> CP
    State --> PCA

    State --> TS
    State --> TSS
    RG --> ARS
    SM --> MS
    QD --> QDS
    QD --> QDRS
    State --> SS
    PS --> PSS
    CP --> CS
    RG --> FCS
    RG --> PES
    PCA --> PCAS
```

## Settings Domain Map

```mermaid
graph TB
    subgraph SettingsManager["SettingsManager (Singleton)"]
        subgraph LLMSettings["LLM Settings"]
            ActiveProvider["activeProviderId<br/>(openai/anthropic/deepseek/qwen/zhipu)"]
            ActiveModel["activeModel"]
            Temperature["temperature (0.0-1.0)"]
        end

        subgraph ConvSettings["Conversation Settings"]
            AutoDetect["autoDetectQuestions"]
            AutoAnswer["autoAnswerQuestions"]
            ConvMode["conversationMode<br/>(general/interview/passive)"]
            ProfileId["assistantProfileId"]
            QuickAskPreset["defaultQuickAskPreset<br/>(concise/speakForMe/interview/factCheck)"]
            Language["language (en/zh)"]
            AutoSummary["autoShowSummary"]
            AutoFollowUps["autoShowFollowUps"]
            AssistantProfiles["assistantProfiles<br/>(List&lt;AssistantProfile&gt;)"]
        end

        subgraph AudioSettings["Audio Settings"]
            NoiseReduction["noiseReduction"]
            VAD["voiceActivityDetection"]
            VADSens["vadSensitivity (0.0-1.0)"]
        end

        subgraph TranscriptionSettings["Transcription Settings"]
            TBackend["transcriptionBackend<br/>(openai/appleCloud/appleOnDevice)"]
            SessionMode["openAISessionMode<br/>(transcription/realtime)"]
            TModel["transcriptionModel"]
            RTPrompt["openAIRealtimePrompt"]
            MicSource["preferredMicSource<br/>(auto/glasses/phone)"]
        end

        subgraph GlassesSettings["Glasses Settings"]
            AutoConn["autoConnect"]
            HUDBright["hudBrightness (0.0-1.0)"]
            DispMode["displayMode<br/>(minimal/standard/detailed)"]
            DashTilt["dashboardTiltEnabled"]
        end

        subgraph UISettings["UI Settings"]
            ThemeSetting["theme (dark/light/system)"]
        end
    end

    subgraph Storage["Storage Backend"]
        SharedPrefs["SharedPreferences<br/>(general settings)"]
        SecureStore["FlutterSecureStorage<br/>(API keys only)"]
    end

    SettingsManager --> SharedPrefs
    SettingsManager --> SecureStore
    SettingsManager -- "onSettingsChanged<br/>Stream" --> Consumers["All Consumers"]
```

## Singleton Initialization Order

```mermaid
sequenceDiagram
    participant Main as main()
    participant SM as SettingsManager
    participant BLE as BleManager
    participant LLM as LlmService
    participant CE as ConversationEngine
    participant DS as DashboardService
    participant App as HelixApp (Flutter)

    Main->>SM: initialize()<br/>(load SharedPreferences)
    SM-->>Main: ready

    Main->>BLE: get() + setMethodCallHandler()
    BLE->>BLE: startListening()<br/>(subscribe eventBleReceive)

    Main->>LLM: initializeDefaults()<br/>(register 5 providers)
    loop For each provider
        Main->>SM: getApiKey(providerId)
        SM-->>Main: apiKey?
        Main->>LLM: setApiKey(providerId, key)
    end
    Main->>LLM: setActiveProvider(settings.activeProviderId)
    Main->>CE: setLlmServiceGetter(() => LlmService.instance)
    Main->>CE: Apply autoDetect/autoAnswer settings

    Main->>DS: initialize()<br/>(subscribe BLE events, engine status,<br/>settings changes, HUD intents)

    Main->>App: runApp(HelixApp)
    App->>App: Check onboarding -> MainScreen
    App->>App: Build 5-tab IndexedStack
```

## Technology Stack Overview

```mermaid
graph TB
    subgraph AppLayer["Application Layer"]
        Flutter["Flutter 3.35+ / Dart 3.9+"]
    end

    subgraph UILayer["UI & State"]
        MaterialDesign["Material Design 3"]
        StatefulWidgets["StatefulWidget + Streams"]
        GetX["GetX (reactive BLE state)"]
        Freezed["Freezed + JsonSerializable<br/>(immutable models)"]
    end

    subgraph ServiceLayer["Service Layer"]
        Singletons["Singleton Services<br/>(~15 services)"]
        StreamArch["Dart Streams<br/>(broadcast controllers)"]
    end

    subgraph PlatformBridge["Platform Bridge"]
        MethodChannel["MethodChannel<br/>(method.bluetooth)"]
        EventChannels["EventChannels<br/>(eventBleReceive,<br/>eventSpeechRecognize)"]
    end

    subgraph NativeLayer["Native iOS"]
        CoreBT["CoreBluetooth<br/>(CBCentralManager)"]
        Speech["Speech Framework<br/>(SFSpeechRecognizer)"]
        AVFoundation["AVFoundation<br/>(AVAudioEngine)"]
    end

    subgraph Networking["Networking"]
        HTTP["http package<br/>(LLM REST APIs)"]
        WebSocket["URLSessionWebSocketTask<br/>(OpenAI Realtime)"]
    end

    subgraph Storage["Local Storage"]
        SharedPrefs["SharedPreferences"]
        SecureStorage["FlutterSecureStorage<br/>(Keychain)"]
        FileSystem["path_provider<br/>(audio files)"]
    end

    subgraph ExternalAPIs["External Cloud APIs"]
        OpenAI["OpenAI<br/>(GPT-4o, Realtime, Transcription)"]
        Anthropic["Anthropic<br/>(Sonnet)"]
        DeepSeek["DeepSeek"]
        Qwen["Qwen / DashScope"]
        Zhipu["Zhipu / BigModel"]
        AppleSpeech["Apple Speech Servers"]
    end

    AppLayer --> UILayer
    UILayer --> ServiceLayer
    ServiceLayer --> PlatformBridge
    PlatformBridge --> NativeLayer
    ServiceLayer --> Networking
    ServiceLayer --> Storage
    Networking --> ExternalAPIs
    NativeLayer --> ExternalAPIs
```
