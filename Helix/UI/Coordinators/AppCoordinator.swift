import Foundation
import Combine
import AVFoundation

@MainActor
class AppCoordinator: ObservableObject {
    // Core services
    private let audioManager: AudioManagerProtocol
    private var speechRecognizer: SpeechRecognitionServiceProtocol
    private let speakerDiarization: SpeakerDiarizationEngineProtocol
    private let voiceActivityDetector: VoiceActivityDetectorProtocol
    private let noiseReducer: NoiseReductionProcessorProtocol
    // Transcription service
    var transcriptionCoordinator: TranscriptionCoordinatorProtocol
    private let llmService: LLMServiceProtocol
    private let glassesManager: GlassesManagerProtocol
    private let hudRenderer: HUDRendererProtocol
    private let conversationContext: ConversationContextManager
    /// ViewModel for the conversation view
    var conversationViewModel: ConversationViewModel
    
    // Published state
    @Published var isRecording = false
    @Published var connectionState: ConnectionState = .disconnected
    @Published var batteryLevel: Float = 0.0
    @Published var currentConversation: [ConversationMessage] = []
    @Published var recentAnalysis: [AnalysisResult] = []
    @Published var speakers: [Speaker] = []
    @Published var isProcessing = false
    @Published var errorMessage: String?
    @Published var discoveredDevices: [DiscoveredDevice] = []
    
    // Settings
    @Published var settings = AppSettings()
    
    // Conversation timing
    private var conversationStartDate: Date?
    private var durationTimer: AnyCancellable?
    
    /// Number of messages in the current conversation
    var messageCount: Int {
        currentConversation.count
    }
    
    /// Elapsed duration of the current conversation (seconds)
    @Published var conversationDuration: TimeInterval = 0
    
    private var cancellables = Set<AnyCancellable>()
    
    /// Initialise the coordinator.
    /// - Parameters:
    ///   - enableAudio: If `false`, skips setting up `AudioManager`, `VoiceActivityDetector`, `NoiseReductionProcessor` and related pipes.
    ///   - enableSpeech: If `false`, skips the `SpeechRecognitionService`.
    ///   - enableBluetooth: If `false`, the glasses / HUD stack is not initialised.
    ///   - enableAI: If `false`, the LLM stack is not initialised.
    ///   - settings: Optional initial app settings instance.  If `nil`, the default value is used.
    init(enableAudio: Bool = true,
         enableSpeech: Bool = true,
         enableBluetooth: Bool = true,
         enableAI: Bool = true,
         speechBackend: SpeechBackend? = nil,
         initialSettings settings: AppSettings = AppSettings()) {
        print("🚀 Initializing AppCoordinator...")
        
        // ----- CORE AUDIO / SPEECH STACK -----
        if enableAudio {
            print("📱 Initializing audio services…")
            self.audioManager = AudioManager()
            self.voiceActivityDetector = VoiceActivityDetector()
            self.noiseReducer = NoiseReductionProcessor()
        } else {
            self.audioManager = NoopAudioManager()
            self.voiceActivityDetector = NoopVoiceActivityDetector()
            self.noiseReducer = NoopNoiseReductionProcessor()
        }

        if enableSpeech {
            let backendChoice = speechBackend ?? settings.speechBackend
            switch backendChoice {
            case .local:
                debugLogger.log(.info, source: "AppCoordinator", message: "Using local iOS speech recognizer backend")
                self.speechRecognizer = SpeechRecognitionService()
            case .remoteWhisper:
                debugLogger.log(.info, source: "AppCoordinator", message: "Using remote OpenAI Whisper backend")
                self.speechRecognizer = RemoteWhisperRecognitionService(apiKey: settings.openAIKey)
            }

            self.speakerDiarization = SpeakerDiarizationEngine()
        } else {
            self.speechRecognizer = NoopSpeechRecognitionService()
            self.speakerDiarization = NoopSpeakerDiarizationEngine()
        }

        print("🎤 Initializing transcription coordinator…")
        self.transcriptionCoordinator = TranscriptionCoordinator(
            audioManager: self.audioManager,
            speechRecognizer: self.speechRecognizer,
            speakerDiarization: self.speakerDiarization,
            voiceActivityDetector: self.voiceActivityDetector,
            noiseReducer: self.noiseReducer
        )
        
        // ----- AI STACK -----
        if enableAI {
            print("🤖 Initializing AI services…")
            let openAIProvider = OpenAIProvider(apiKey: settings.openAIKey)
            self.llmService = LLMService(providers: [.openai: openAIProvider])
        } else {
            self.llmService = NoopLLMService()
        }
        
        // ----- GLASSES / HUD STACK -----
        if enableBluetooth {
            print("👓 Initializing glasses services…")
            self.glassesManager = GlassesManager()
            self.hudRenderer = HUDRenderer(glassesManager: self.glassesManager)
        } else {
            self.glassesManager = NoopGlassesManager()
            self.hudRenderer = NoopHUDRenderer()
        }
        
        // ----- CONVERSATION CONTEXT -----
        print("💬 Initializing conversation management…")
        self.conversationContext = ConversationContextManager()
        // Initialize conversation view model
        self.conversationViewModel = ConversationViewModel(transcriptionCoordinator: self.transcriptionCoordinator)
        
        print("🔗 Setting up subscriptions...")
        setupSubscriptions()
        setupDefaultSpeakers()
        
        print("✅ AppCoordinator initialization complete!")
        // Apply initial settings
        self.settings = settings
        configureServices(with: settings)

        print("✅ AppCoordinator initialization complete!")
    }

    /// Back-compat convenience initialiser so existing call-sites that do
    /// `AppCoordinator()` continue to compile.  It simply forwards to the
    /// designated initialiser with every subsystem enabled.
    convenience init() {
        self.init(enableAudio: true, enableSpeech: true, enableBluetooth: true, enableAI: true, initialSettings: AppSettings())
    }
    
    // MARK: - Public Interface
    
    func startConversation() {
        guard !isRecording else { return }
        
        isRecording = true
        isProcessing = true
        // Reset conversation history and timing
        currentConversation.removeAll()
        conversationStartDate = Date()
        // Reset duration and start timer
        conversationDuration = 0
        durationTimer?.cancel()
        durationTimer = Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self, let start = self.conversationStartDate else { return }
                self.conversationDuration = Date().timeIntervalSince(start)
            }
        
        // Start recording storage for audio playback history
        audioManager.startStoringRecording()
        
        transcriptionCoordinator.startConversationTranscription()
    }
    
    func stopConversation() {
        guard isRecording else { return }
        
        isRecording = false
        isProcessing = false
        // Stop duration timer
        durationTimer?.cancel()
        
        // Stop recording storage and save the recording
        audioManager.stopStoringRecording()
        if let savedURL = audioManager.saveLastRecording(filename: "conversation_\(Int(Date().timeIntervalSince1970)).wav") {
            let _ = RecordingHistoryManager.shared.saveRecording(from: savedURL, date: conversationStartDate ?? Date())
        }
        
        transcriptionCoordinator.stopConversationTranscription()
    }
    
    func connectToGlasses() {
        glassesManager.connect()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        self?.errorMessage = error.localizedDescription
                    }
                },
                receiveValue: { [weak self] _ in
                    self?.errorMessage = nil
                }
            )
            .store(in: &cancellables)
    }
    
    func connectToDevice(_ device: DiscoveredDevice) {
        glassesManager.connectToDevice(device)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        self?.errorMessage = error.localizedDescription
                    }
                },
                receiveValue: { [weak self] _ in
                    self?.errorMessage = nil
                }
            )
            .store(in: &cancellables)
    }
    
    func stopScanning() {
        glassesManager.stopScanning()
    }
    
    func disconnectFromGlasses() {
        glassesManager.disconnect()
    }
    
    func addSpeaker(name: String, isCurrentUser: Bool = false) {
        let speaker = Speaker(name: name, isCurrentUser: isCurrentUser)
        speakers.append(speaker)
        transcriptionCoordinator.addSpeaker(speaker)
        conversationContext.addSpeaker(speaker)
    }
    
    func trainSpeaker(_ speakerId: UUID, with samples: [AVAudioPCMBuffer]) {
        transcriptionCoordinator.trainSpeaker(speakerId, with: samples)
    }
    
    func clearConversation() {
        // Clear all conversation data and timing
        currentConversation.removeAll()
        recentAnalysis.removeAll()
        conversationContext.clearHistory()
        hudRenderer.clearAll()
        conversationStartDate = nil
        conversationDuration = 0
        durationTimer?.cancel()
    }
    
    func exportConversation() -> ConversationExport {
        let export = conversationContext.exportConversation()
        ConversationHistoryManager.shared.saveConversation(export)
        return export
    }
    
    func updateSettings(_ newSettings: AppSettings) {
        let oldSettings = settings
        settings = newSettings
        
        // Handle speech backend change
        if oldSettings.speechBackend != newSettings.speechBackend {
            // Stop current recording if active
            let wasRecording = isRecording
            if wasRecording {
                stopConversation()
            }
            
            // Update speech recognition service
            updateSpeechRecognitionService(backend: newSettings.speechBackend)
            
            // Restart recording if it was active
            if wasRecording {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.startConversation()
                }
            }
        }
        
        // Update service configurations
        configureServices(with: newSettings)
    }
    
    private func updateSpeechRecognitionService(backend: SpeechBackend) {
        // Stop current recognition if active
        if isRecording {
            stopConversation()
        }
        
        // Create new speech recognizer based on backend
        switch backend {
        case .local:
            speechRecognizer = SpeechRecognitionService()
            print("✅ Switched to local speech recognition")
        case .remoteWhisper:
            if settings.openAIKey.isEmpty {
                errorMessage = "OpenAI API key required for Whisper transcription. Please configure your API key in Settings."
                return
            }
            speechRecognizer = RemoteWhisperRecognitionService(apiKey: settings.openAIKey)
            print("✅ Switched to remote Whisper speech recognition")
        }
        
        // Recreate transcription coordinator with new speech recognizer
        transcriptionCoordinator = TranscriptionCoordinator(
            audioManager: audioManager,
            speechRecognizer: speechRecognizer,
            speakerDiarization: speakerDiarization,
            voiceActivityDetector: voiceActivityDetector,
            noiseReducer: noiseReducer
        )
        
        // Update conversation view model with new coordinator
        conversationViewModel = ConversationViewModel(transcriptionCoordinator: transcriptionCoordinator)
        
        // Re-setup subscriptions for the new coordinator
        setupTranscriptionSubscriptions()
    }
    
    // MARK: - Private Methods
    
    private func setupSubscriptions() {
        // Glasses connection state
        glassesManager.connectionState
            .receive(on: DispatchQueue.main)
            .assign(to: \.connectionState, on: self)
            .store(in: &cancellables)
        
        // Battery level
        glassesManager.batteryLevel
            .receive(on: DispatchQueue.main)
            .assign(to: \.batteryLevel, on: self)
            .store(in: &cancellables)
        
        // Discovered devices
        glassesManager.discoveredDevices
            .receive(on: DispatchQueue.main)
            .assign(to: \.discoveredDevices, on: self)
            .store(in: &cancellables)
        
        // Conversation updates
        transcriptionCoordinator.conversationPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.errorMessage = error.localizedDescription
                    self?.isProcessing = false
                }
            } receiveValue: { [weak self] update in
                // Don't append here - let ConversationViewModel handle it
                self?.isProcessing = false
                self?.handleConversationUpdate(update)
            }
            .store(in: &cancellables)

        // Keep currentConversation in sync with VM messages so History export
        // never says “no conversation found”.
        conversationViewModel.$messages
            .receive(on: DispatchQueue.main)
            .sink { [weak self] msgs in
                self?.currentConversation = msgs
            }
            .store(in: &cancellables)
    }
    
    private func setupTranscriptionSubscriptions() {
        // Conversation updates
        transcriptionCoordinator.conversationPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.errorMessage = error.localizedDescription
                    self?.isProcessing = false
                }
            } receiveValue: { [weak self] update in
                // Don't append here - let ConversationViewModel handle it
                self?.isProcessing = false
                self?.handleConversationUpdate(update)
            }
            .store(in: &cancellables)

        // Keep currentConversation in sync with VM messages so History export
        // never says "no conversation found".
        conversationViewModel.$messages
            .receive(on: DispatchQueue.main)
            .sink { [weak self] msgs in
                self?.currentConversation = msgs
            }
            .store(in: &cancellables)
    }
    
    private func setupDefaultSpeakers() {
        // Add current user as default speaker
        let currentUser = Speaker(name: "You", isCurrentUser: true)
        speakers.append(currentUser)
        transcriptionCoordinator.addSpeaker(currentUser)
        conversationContext.addSpeaker(currentUser)
    }
    
    private func handleConversationUpdate(_ update: ConversationUpdate) {
        // Add message to conversation context and history
        conversationContext.addMessage(update.message)
        
        // Update speakers list if new speaker
        if update.isNewSpeaker, let speaker = update.speaker {
            if !speakers.contains(where: { $0.id == speaker.id }) {
                speakers.append(speaker)
            }
        }
        
        // Process for AI analysis based on settings
        if settings.enableFactChecking {
            processMessageForFactCheck(update.message)
        }
        if settings.enableAutoSummary {
            processConversationSummary()
        }
        if settings.enableActionItems {
            processConversationActionItems()
        }
        
        isProcessing = false
    }
    
    private func processMessageForAnalysis(_ message: ConversationMessage) {
        guard !message.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        let context = ConversationContext(
            messages: Array(currentConversation.suffix(5)), // Last 5 messages for context
            speakers: speakers,
            analysisType: .factCheck
        )
        
        // Detect claims first
        llmService.detectClaims(in: message.content)
            .flatMap { [weak self] claims -> AnyPublisher<[AnalysisResult], LLMError> in
                guard let self = self, !claims.isEmpty else {
                    return Just([]).setFailureType(to: LLMError.self).eraseToAnyPublisher()
                }
                
                let factCheckPublishers = claims.map { claim in
                    self.llmService.factCheck(claim.text, context: context)
                        .map { factCheckResult in
                            AnalysisResult(
                                type: .factCheck,
                                content: .factCheck(factCheckResult),
                                confidence: factCheckResult.confidence,
                                provider: .openai
                            )
                        }
                }
                
                return Publishers.MergeMany(factCheckPublishers)
                    .collect()
                    .eraseToAnyPublisher()
            }
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        print("Analysis failed: \(error)")
                        self?.errorMessage = "Analysis failed: \(error.localizedDescription)"
                    }
                },
                receiveValue: { [weak self] results in
                    self?.handleAnalysisResults(results)
                }
            )
            .store(in: &cancellables)
    }
    
    private func handleAnalysisResults(_ results: [AnalysisResult]) {
        recentAnalysis.append(contentsOf: results)
        
        // Display critical results on HUD
        for result in results {
            if case .factCheck(let factCheckResult) = result.content,
               !factCheckResult.isAccurate && factCheckResult.severity == .critical {
                
                let hudContent = HUDContentFactory.createFactCheckDisplay(factCheckResult)
                hudRenderer.render(hudContent)
                    .sink(receiveCompletion: { _ in }, receiveValue: { _ in })
                    .store(in: &cancellables)
            }
        }
    }
    
    private func configureServices(with settings: AppSettings) {
        // Configure audio settings
        do {
            try audioManager.configure(
                sampleRate: 16000,
                bufferDuration: settings.audioBufferDuration
            )
        } catch {
            errorMessage = "Failed to configure audio: \(error.localizedDescription)"
        }
        
        // Configure speech recognition
        if let language = settings.primaryLanguage {
            speechRecognizer.setLanguage(language)
        }
        
        // Configure noise reduction
        noiseReducer.setReductionLevel(settings.noiseReductionLevel)
        
        // Configure voice activity detection
        voiceActivityDetector.setSensitivity(settings.voiceSensitivity)
    }
    
    private func processMessageForFactCheck(_ message: ConversationMessage) {
        processMessageForAnalysis(message)
    }
    
    private func processConversationSummary() {
        llmService.summarizeConversation(currentConversation)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { [weak self] summary in
                    // Handle summary
                }
            )
            .store(in: &cancellables)
    }
    
    private func processConversationActionItems() {
        llmService.extractActionItems(from: currentConversation)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { [weak self] items in
                    // Handle action items
                }
            )
            .store(in: &cancellables)
    }
}

// MARK: - App Settings

struct AppSettings: Codable, Equatable {
    var openAIKey: String = ""
    var anthropicKey: String = ""
    var enableFactChecking: Bool = true
    var enableAutoSummary: Bool = true
    var enableActionItems: Bool = true
    var primaryLanguage: Locale? = Locale(identifier: "en-US")
    var audioBufferDuration: TimeInterval = 0.005
    var noiseReductionLevel: Float = 0.5
    var voiceSensitivity: Float = 0.5
    var glassesAutoConnect: Bool = true
    var displayBrightness: Float = 0.8
    var factCheckSeverityFilter: FactCheckResult.FactCheckSeverity = .significant
    var maxConversationHistory: Int = 100
    var autoExport: Bool = false
    var privacyMode: Bool = false

    // Which backend to use for speech recognition
    var speechBackend: SpeechBackend = .local
    
    static let `default` = AppSettings()
}

// MARK: - Speech Backend Selection

enum SpeechBackend: String, Codable, CaseIterable, Hashable {
    case local
    case remoteWhisper
    
    var description: String {
        switch self {
        case .local: return "On-device"
        case .remoteWhisper: return "OpenAI Whisper (remote)"
        }
    }
}

// MARK: - Extensions

extension AppCoordinator {
    /// Whether the glasses are currently connected
    var isConnectedToGlasses: Bool {
        connectionState.isConnected
    }
    
    /// Number of unique speakers in the current conversation
    var speakerCount: Int {
        Set(currentConversation.compactMap { $0.speakerId }).count
    }
}