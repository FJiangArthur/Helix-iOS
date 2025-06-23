import Foundation
import Combine
import AVFoundation

protocol TranscriptionCoordinatorProtocol {
    var conversationPublisher: AnyPublisher<ConversationUpdate, TranscriptionError> { get }
    
    func startConversationTranscription()
    func stopConversationTranscription()
    func addSpeaker(_ speaker: Speaker)
    func trainSpeaker(_ speakerId: UUID, with samples: [AVAudioPCMBuffer])
}

struct ConversationUpdate {
    let message: ConversationMessage
    let speaker: Speaker?
    let isNewSpeaker: Bool
    let timestamp: TimeInterval
}

struct ConversationMessage {
    let id: UUID
    let content: String
    let speakerId: UUID?
    let confidence: Float
    let timestamp: TimeInterval
    let isFinal: Bool
    let wordTimings: [WordTiming]
    let originalText: String
    
    init(from transcriptionResult: TranscriptionResult, speakerId: UUID? = nil) {
        self.id = UUID()
        self.content = transcriptionResult.text
        self.speakerId = speakerId ?? transcriptionResult.speakerId
        self.confidence = transcriptionResult.confidence
        self.timestamp = transcriptionResult.timestamp
        self.isFinal = transcriptionResult.isFinal
        self.wordTimings = transcriptionResult.wordTimings
        self.originalText = transcriptionResult.text
    }
    
    init(content: String, speakerId: UUID?, confidence: Float, timestamp: TimeInterval, isFinal: Bool, wordTimings: [WordTiming], originalText: String) {
        self.id = UUID()
        self.content = content
        self.speakerId = speakerId
        self.confidence = confidence
        self.timestamp = timestamp
        self.isFinal = isFinal
        self.wordTimings = wordTimings
        self.originalText = originalText
    }
}

class TranscriptionCoordinator: TranscriptionCoordinatorProtocol {
    private let audioManager: AudioManagerProtocol
    private let speechRecognizer: SpeechRecognitionServiceProtocol
    private let speakerDiarization: SpeakerDiarizationEngineProtocol
    private let voiceActivityDetector: VoiceActivityDetectorProtocol
    private let transcriptionProcessor: TranscriptionProcessor
    private let noiseReducer: NoiseReductionProcessorProtocol
    
    private let conversationSubject = PassthroughSubject<ConversationUpdate, TranscriptionError>()
    private var cancellables = Set<AnyCancellable>()
    
    private var isTranscribing = false
    private var currentSpeakers: [UUID: Speaker] = [:]
    private var unknownSpeakerCounter = 0
    private var lastVoiceActivity: TimeInterval = 0
    private var backgroundNoiseProfile: AVAudioPCMBuffer?
    
    // Streaming transcription state
    private var activeTranscriptionMessage: ConversationMessage?
    private var lastPartialTranscriptionTime: TimeInterval = 0
    
    // Configuration
    private let minSpeechDuration: TimeInterval = 0.5
    private let maxSilenceDuration: TimeInterval = 2.0
    private let speakerChangeThreshold: Float = 0.3
    
    var conversationPublisher: AnyPublisher<ConversationUpdate, TranscriptionError> {
        conversationSubject.eraseToAnyPublisher()
    }
    
    init(
        audioManager: AudioManagerProtocol,
        speechRecognizer: SpeechRecognitionServiceProtocol,
        speakerDiarization: SpeakerDiarizationEngineProtocol,
        voiceActivityDetector: VoiceActivityDetectorProtocol,
        transcriptionProcessor: TranscriptionProcessor = TranscriptionProcessor(),
        noiseReducer: NoiseReductionProcessorProtocol
    ) {
        self.audioManager = audioManager
        self.speechRecognizer = speechRecognizer
        self.speakerDiarization = speakerDiarization
        self.voiceActivityDetector = voiceActivityDetector
        self.transcriptionProcessor = transcriptionProcessor
        self.noiseReducer = noiseReducer
        
        setupSubscriptions()
    }
    
    func startConversationTranscription() {
        guard !isTranscribing else {
            return
        }
        
        do {
            try audioManager.startRecording()
            speechRecognizer.startStreamingRecognition()
            isTranscribing = true
        } catch {
            conversationSubject.send(completion: .failure(.audioEngineError(error)))
        }
    }
    
    func stopConversationTranscription() {
        guard isTranscribing else { return }
        
        audioManager.stopRecording()
        speechRecognizer.stopRecognition()
        isTranscribing = false
    }
    
    func addSpeaker(_ speaker: Speaker) {
        currentSpeakers[speaker.id] = speaker
        speakerDiarization.addSpeaker(id: speaker.id, name: speaker.name, isCurrentUser: speaker.isCurrentUser)
    }
    
    func trainSpeaker(_ speakerId: UUID, with samples: [AVAudioPCMBuffer]) {
        guard currentSpeakers[speakerId] != nil else {
            return
        }
        
        speakerDiarization.trainSpeakerModel(samples: samples, speakerId: speakerId)
    }
    
    private func setupSubscriptions() {
        // Audio processing pipeline
        audioManager.audioPublisher
            .receive(on: DispatchQueue.global(qos: .userInitiated))
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        self?.conversationSubject.send(completion: .failure(.audioEngineError(error)))
                    }
                },
                receiveValue: { [weak self] processedAudio in
                    self?.processAudioFrame(processedAudio)
                }
            )
            .store(in: &cancellables)
        
        // Transcription processing
        speechRecognizer.transcriptionPublisher
            .receive(on: DispatchQueue.global(qos: .userInitiated))
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        self?.conversationSubject.send(completion: .failure(error))
                    }
                },
                receiveValue: { [weak self] transcriptionResult in
                    self?.processTranscriptionResult(transcriptionResult)
                }
            )
            .store(in: &cancellables)
    }
    
    private func processAudioFrame(_ processedAudio: ProcessedAudio) {
        // Apply noise reduction
        let cleanedBuffer = noiseReducer.processBuffer(processedAudio.buffer)
        
        // Pass every buffer to the speech recognizer to avoid missing speech
        // due to an overly-aggressive VAD threshold on certain devices / noisy
        // environments.  We still compute voice activity so other components
        // (e.g. diarization, energy graphs) can use it, but transcription no
        // longer depends on VAD firing first.

        let voiceActivity = voiceActivityDetector.detectVoiceActivity(in: cleanedBuffer)

        if !voiceActivity.hasVoice {
            voiceActivityDetector.updateBackground(with: cleanedBuffer)
            noiseReducer.updateNoiseProfile(cleanedBuffer)
        } else {
            lastVoiceActivity = Date().timeIntervalSince1970
        }

        speechRecognizer.processAudioBuffer(cleanedBuffer)
    }
    
    private func processTranscriptionResult(_ result: TranscriptionResult) {
        // Skip completely empty transcriptions
        let trimmedText = result.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else {
            return
        }
        
        let currentTime = Date().timeIntervalSince1970
        
        // Process transcription for better quality
        let processedResult = transcriptionProcessor.processTranscription(result)
        
        // Attempt speaker identification
        let speakerInfo = identifySpeakerForTranscription(processedResult)
        
        if result.isFinal {
            // Final result: create or update the active message
            let finalMessage = ConversationMessage(
                from: processedResult,
                speakerId: speakerInfo.speakerId
            )
            
            // If we have an active partial message, this final result replaces it
            // Otherwise, this is a new final message
            let update = ConversationUpdate(
                message: finalMessage,
                speaker: speakerInfo.speaker,
                isNewSpeaker: speakerInfo.isNewSpeaker,
                timestamp: currentTime
            )
            
            // Clear active transcription state
            activeTranscriptionMessage = nil
            lastPartialTranscriptionTime = 0
            
            DispatchQueue.main.async { [weak self] in
                self?.conversationSubject.send(update)
            }
            
            
        } else {
            // Partial result: update live transcription
            // Only send partial updates if there's substantial content or time has passed
            let timeSinceLastPartial = currentTime - lastPartialTranscriptionTime
            let shouldSendPartial = trimmedText.count > 3 || timeSinceLastPartial > 0.5
            
            if shouldSendPartial {
                let partialMessage = ConversationMessage(
                    from: processedResult,
                    speakerId: speakerInfo.speakerId
                )
                
                let update = ConversationUpdate(
                    message: partialMessage,
                    speaker: speakerInfo.speaker,
                    isNewSpeaker: speakerInfo.isNewSpeaker,
                    timestamp: currentTime
                )
                
                // Update state
                activeTranscriptionMessage = partialMessage
                lastPartialTranscriptionTime = currentTime
                
                DispatchQueue.main.async { [weak self] in
                    self?.conversationSubject.send(update)
                }
            }
        }
    }
    
    private func identifySpeakerForTranscription(_ result: TranscriptionResult) -> (speakerId: UUID?, speaker: Speaker?, isNewSpeaker: Bool) {
        // For now, we'll use a simplified approach since we don't have the actual audio buffer
        // In a complete implementation, this would analyze the audio characteristics
        
        if let explicitSpeakerId = result.speakerId,
           let speaker = currentSpeakers[explicitSpeakerId] {
            return (explicitSpeakerId, speaker, false)
        }
        
        // Check if we can identify based on existing speaker models
        // This would require the actual audio buffer in a real implementation
        
        // For demo purposes, create unknown speaker if we have multiple speakers
        if currentSpeakers.count > 1 {
            // Simple heuristic: alternate between known speakers or create new ones
            let unknownSpeakerId = UUID()
            let unknownSpeaker = Speaker(
                id: unknownSpeakerId,
                name: "Speaker \(unknownSpeakerCounter + 1)",
                isCurrentUser: false
            )
            
            unknownSpeakerCounter += 1
            addSpeaker(unknownSpeaker)
            
            return (unknownSpeakerId, unknownSpeaker, true)
        }
        
        // Default to first speaker or current user
        if let firstSpeaker = currentSpeakers.values.first {
            return (firstSpeaker.id, firstSpeaker, false)
        }
        
        // Create default speaker if none exist
        let defaultSpeakerId = UUID()
        let defaultSpeaker = Speaker(
            id: defaultSpeakerId,
            name: "Current User",
            isCurrentUser: true
        )
        
        addSpeaker(defaultSpeaker)
        return (defaultSpeakerId, defaultSpeaker, true)
    }
}

// MARK: - Conversation Context Manager

class ConversationContextManager {
    private var conversationHistory: [ConversationMessage] = []
    private var speakers: [UUID: Speaker] = [:]
    private let maxHistorySize = 100
    private let contextWindowSize = 20
    
    func addMessage(_ message: ConversationMessage) {
        conversationHistory.append(message)
        
        // Maintain history size limit
        if conversationHistory.count > maxHistorySize {
            conversationHistory.removeFirst(conversationHistory.count - maxHistorySize)
        }
    }
    
    func addSpeaker(_ speaker: Speaker) {
        speakers[speaker.id] = speaker
    }
    
    func getRecentContext(messageCount: Int = 20) -> [ConversationMessage] {
        let count = min(messageCount, conversationHistory.count)
        return Array(conversationHistory.suffix(count))
    }
    
    func getConversationSummary() -> ConversationSummary {
        let totalMessages = conversationHistory.count
        let speakerCount = Set(conversationHistory.compactMap { $0.speakerId }).count
        let averageConfidence = conversationHistory.map { $0.confidence }.reduce(0, +) / Float(max(totalMessages, 1))
        
        let startTime = conversationHistory.first?.timestamp ?? Date().timeIntervalSince1970
        let endTime = conversationHistory.last?.timestamp ?? Date().timeIntervalSince1970
        let duration = endTime - startTime
        
        return ConversationSummary(
            messageCount: totalMessages,
            speakerCount: speakerCount,
            duration: duration,
            averageConfidence: averageConfidence,
            startTime: startTime,
            endTime: endTime
        )
    }
    
    func getSpeakerStatistics() -> [SpeakerStatistics] {
        var speakerStats: [UUID: SpeakerStatistics] = [:]
        
        for message in conversationHistory {
            guard let speakerId = message.speakerId else { continue }
            
            if speakerStats[speakerId] == nil {
                speakerStats[speakerId] = SpeakerStatistics(
                    speakerId: speakerId,
                    speaker: speakers[speakerId],
                    messageCount: 0,
                    totalWords: 0,
                    averageConfidence: 0.0,
                    speakingTime: 0.0
                )
            }
            
            let wordCount = message.content.components(separatedBy: .whitespacesAndNewlines).count
            let messageDuration = message.wordTimings.last?.endTime ?? 0.0 - (message.wordTimings.first?.startTime ?? 0.0)
            
            var currentStats = speakerStats[speakerId]!
            currentStats.messageCount += 1
            currentStats.totalWords += wordCount
            let newConfidence = (currentStats.averageConfidence + message.confidence) / 2.0
            currentStats.averageConfidence = newConfidence
            currentStats.speakingTime += messageDuration
            speakerStats[speakerId] = currentStats
        }
        
        return Array(speakerStats.values)
    }
    
    func clearHistory() {
        conversationHistory.removeAll()
    }
    
    func exportConversation() -> ConversationExport {
        return ConversationExport(
            messages: conversationHistory,
            speakers: Array(speakers.values),
            summary: getConversationSummary(),
            exportDate: Date()
        )
    }
}

// MARK: - Supporting Types

struct ConversationSummary {
    let messageCount: Int
    let speakerCount: Int
    let duration: TimeInterval
    let averageConfidence: Float
    let startTime: TimeInterval
    let endTime: TimeInterval
}

struct SpeakerStatistics {
    let speakerId: UUID
    let speaker: Speaker?
    var messageCount: Int
    var totalWords: Int
    var averageConfidence: Float
    var speakingTime: TimeInterval
    
    var wordsPerMessage: Float {
        messageCount > 0 ? Float(totalWords) / Float(messageCount) : 0.0
    }
    
    var wordsPerMinute: Float {
        speakingTime > 0 ? Float(totalWords) / Float(speakingTime / 60.0) : 0.0
    }
}

struct ConversationExport: Codable, Identifiable {
    let id: UUID = UUID()
    let messages: [ConversationMessage]
    let speakers: [Speaker]
    let summary: ConversationSummary
    let exportDate: Date
}

// Make types Codable for export functionality
extension ConversationMessage: Codable {
    enum CodingKeys: String, CodingKey {
        case id, content, speakerId, confidence, timestamp, isFinal, wordTimings, originalText
    }
}

extension ConversationSummary: Codable {}