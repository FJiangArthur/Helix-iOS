import Foundation
import Combine
import AVFoundation

@MainActor
class AppCoordinator: ObservableObject {
    // Core services
    private let audioManager: AudioManagerProtocol
    private let speechRecognizer: SpeechRecognitionServiceProtocol
    private let speakerDiarization: SpeakerDiarizationEngineProtocol
    private let voiceActivityDetector: VoiceActivityDetectorProtocol
    private let noiseReducer: NoiseReductionProcessorProtocol
    // Transcription service
    let transcriptionCoordinator: TranscriptionCoordinatorProtocol
    private let llmService: LLMServiceProtocol
    private let glassesManager: GlassesManagerProtocol
    private let hudRenderer: HUDRendererProtocol
    private let conversationContext: ConversationContextManager
    
    // Published state
    @Published var isRecording = false
    @Published var connectionState: ConnectionState = .disconnected
    @Published var batteryLevel: Float = 0.0
    @Published var currentConversation: [ConversationMessage] = []
    @Published var recentAnalysis: [AnalysisResult] = []
    @Published var speakers: [Speaker] = []
    @Published var isProcessing = false
    @Published var errorMessage: String?
    
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
    
    init() {
        // Initialize core services
        self.audioManager = AudioManager()
        self.speechRecognizer = SpeechRecognitionService()
        self.speakerDiarization = SpeakerDiarizationEngine()
        self.voiceActivityDetector = VoiceActivityDetector()
        self.noiseReducer = NoiseReductionProcessor()
        
        self.transcriptionCoordinator = TranscriptionCoordinator(
            audioManager: audioManager,
            speechRecognizer: speechRecognizer,
            speakerDiarization: speakerDiarization,
            voiceActivityDetector: voiceActivityDetector,
            noiseReducer: noiseReducer
        )
        
        // Initialize AI services
        let openAIProvider = OpenAIProvider(apiKey: settings.openAIKey)
        self.llmService = LLMService(providers: [.openai: openAIProvider])
        
        // Initialize glasses services
        self.glassesManager = GlassesManager()
        self.hudRenderer = HUDRenderer(glassesManager: glassesManager)
        
        // Initialize conversation management
        self.conversationContext = ConversationContextManager()
        // Initialize conversation view model
        self.conversationViewModel = ConversationViewModel(transcriptionCoordinator: transcriptionCoordinator)
        
        setupSubscriptions()
        setupDefaultSpeakers()
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
        
        transcriptionCoordinator.startConversationTranscription()
    }
    
    func stopConversation() {
        guard isRecording else { return }
        
        isRecording = false
        isProcessing = false
        // Stop duration timer
        durationTimer?.cancel()
        
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
        return conversationContext.exportConversation()
    }
    
    func updateSettings(_ newSettings: AppSettings) {
        settings = newSettings
        
        // Update service configurations
        configureServices(with: newSettings)
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
        
        // Conversation updates
        transcriptionCoordinator.conversationPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.errorMessage = error.localizedDescription
                    self?.isProcessing = false
                }
            } receiveValue: { [weak self] update in
                self?.handleConversationUpdate(update)
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
        // Add message to conversation
        currentConversation.append(update.message)
        conversationContext.addMessage(update.message)
        
        // Update speakers list if new speaker
        if update.isNewSpeaker, let speaker = update.speaker {
            if !speakers.contains(where: { $0.id == speaker.id }) {
                speakers.append(speaker)
            }
        }
        
        // Process for AI analysis if enabled
        if settings.enableFactChecking || settings.enableAutoSummary {
            processMessageForAnalysis(update.message)
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
}

// MARK: - App Settings

struct AppSettings: Codable {
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
    
    static let `default` = AppSettings()
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