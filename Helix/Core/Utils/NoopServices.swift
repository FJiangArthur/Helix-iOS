//
//  NoopServices.swift
//  Helix
//
//  Created as part of the safe-mode / minimal start-up infrastructure.
//  These lightweight "no-op" implementations conform to the same
//  protocols as the real services but perform no work and never touch
//  hardware resources (microphone, Bluetooth, network, etc.). They make
//  it possible to build and launch the application while selectively
//  disabling heavy subsystems via the `AppCoordinator` feature flags or
//  unit tests.

import Foundation
import Combine
import AVFoundation

// MARK: - Audio stack ---------------------------------------------------------

final class NoopAudioManager: AudioManagerProtocol {
    private let subject = PassthroughSubject<ProcessedAudio, AudioError>()

    var audioPublisher: AnyPublisher<ProcessedAudio, AudioError> {
        subject.eraseToAnyPublisher()
    }

    var isRecording: Bool { false }

    func startRecording() throws {
        // no-op
    }

    func stopRecording() {
        // no-op
    }

    func configure(sampleRate: Double, bufferDuration: TimeInterval) throws {
        // no-op
    }
}

final class NoopVoiceActivityDetector: VoiceActivityDetectorProtocol {
    func detectVoiceActivity(in buffer: AVAudioPCMBuffer) -> VoiceActivityResult {
        VoiceActivityResult(
            hasVoice: false,
            confidence: 0,
            energy: 0,
            spectralCentroid: 0,
            zeroCrossingRate: 0,
            timestamp: Date().timeIntervalSince1970
        )
    }

    func updateBackground(with buffer: AVAudioPCMBuffer) {
        // no-op
    }

    func setSensitivity(_ sensitivity: Float) {
        // no-op
    }
}

final class NoopNoiseReductionProcessor: NoiseReductionProcessorProtocol {
    func processBuffer(_ buffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer {
        buffer // unchanged
    }

    func updateNoiseProfile(_ buffer: AVAudioPCMBuffer) {
        // no-op
    }

    func setReductionLevel(_ level: Float) {
        // no-op
    }
}

// MARK: - Speech / diarization ------------------------------------------------

final class NoopSpeechRecognitionService: SpeechRecognitionServiceProtocol {
    private let subject = PassthroughSubject<TranscriptionResult, TranscriptionError>()

    var transcriptionPublisher: AnyPublisher<TranscriptionResult, TranscriptionError> {
        subject.eraseToAnyPublisher()
    }

    var isRecognizing: Bool { false }

    func startStreamingRecognition() {
        // no-op
    }

    func stopRecognition() {
        // no-op
    }

    func setLanguage(_ locale: Locale) {
        // no-op
    }

    func addCustomVocabulary(_ words: [String]) {
        // no-op
    }

    func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        // no-op
    }
}

final class NoopSpeakerDiarizationEngine: SpeakerDiarizationEngineProtocol {
    func identifySpeaker(in buffer: AVAudioPCMBuffer) -> SpeakerIdentification? { nil }

    func trainSpeakerModel(samples: [AVAudioPCMBuffer], speakerId: UUID) -> Bool { false }

    func addSpeaker(id: UUID, name: String?, isCurrentUser: Bool) { }

    func removeSpeaker(id: UUID) { }

    func getCurrentSpeakers() -> [Speaker] { [] }

    func resetSpeakerModels() { }
}

// MARK: - LLM -----------------------------------------------------------------

final class NoopLLMService: LLMServiceProtocol {
    func analyzeConversation(_ context: ConversationContext) -> AnyPublisher<AnalysisResult, LLMError> {
        Fail(error: .serviceUnavailable).eraseToAnyPublisher()
    }

    func analyzeWithCustomPrompt(_ prompt: String, context: ConversationContext) -> AnyPublisher<AnalysisResult, LLMError> {
        Fail(error: .serviceUnavailable).eraseToAnyPublisher()
    }

    func factCheck(_ claim: String, context: ConversationContext?) -> AnyPublisher<FactCheckResult, LLMError> {
        Fail(error: .serviceUnavailable).eraseToAnyPublisher()
    }

    func summarizeConversation(_ messages: [ConversationMessage]) -> AnyPublisher<String, LLMError> {
        Fail(error: .serviceUnavailable).eraseToAnyPublisher()
    }

    func detectClaims(in text: String) -> AnyPublisher<[FactualClaim], LLMError> {
        Fail(error: .serviceUnavailable).eraseToAnyPublisher()
    }

    func extractActionItems(from messages: [ConversationMessage]) -> AnyPublisher<[ActionItem], LLMError> {
        Fail(error: .serviceUnavailable).eraseToAnyPublisher()
    }

    func setCurrentPersona(_ persona: AIPersona) {
        // no-op
    }

    func generatePersonalizedResponse(_ messages: [ConversationMessage], conversationContext: Helix.ConversationContext) -> AnyPublisher<String, LLMError> {
        Fail(error: .serviceUnavailable).eraseToAnyPublisher()
    }
}

// MARK: - Glasses / HUD -------------------------------------------------------

final class NoopGlassesManager: GlassesManagerProtocol {
    private let connectionStateSubject = CurrentValueSubject<ConnectionState, Never>(.disconnected)
    private let batterySubject = CurrentValueSubject<Float, Never>(0)
    private let capabilitiesSubject = CurrentValueSubject<DisplayCapabilities, Never>(.default)

    var connectionState: AnyPublisher<ConnectionState, Never> { connectionStateSubject.eraseToAnyPublisher() }
    var batteryLevel: AnyPublisher<Float, Never> { batterySubject.eraseToAnyPublisher() }
    var displayCapabilities: AnyPublisher<DisplayCapabilities, Never> { capabilitiesSubject.eraseToAnyPublisher() }

    func connect() -> AnyPublisher<Void, GlassesError> {
        Just(()).setFailureType(to: GlassesError.self).eraseToAnyPublisher()
    }

    func disconnect() {
        // no-op
    }

    func displayText(_ text: String, at position: HUDPosition) -> AnyPublisher<Void, GlassesError> {
        Just(()).setFailureType(to: GlassesError.self).eraseToAnyPublisher()
    }

    func displayContent(_ content: HUDContent) -> AnyPublisher<Void, GlassesError> {
        Just(()).setFailureType(to: GlassesError.self).eraseToAnyPublisher()
    }

    func clearDisplay() { }

    func updateDisplaySettings(_ settings: DisplaySettings) { }

    func sendGestureCommand(_ command: GestureCommand) { }

    func startBatteryMonitoring() { }
    func stopBatteryMonitoring() { }
}

final class NoopHUDRenderer: HUDRendererProtocol {
    func render(_ content: HUDContent) -> AnyPublisher<Void, RenderError> {
        Just(()).setFailureType(to: RenderError.self).eraseToAnyPublisher()
    }

    func updateContent(_ content: HUDContent, with animation: HUDAnimation?) { }
    func clearAll() { }
    func setPriority(_ priority: DisplayPriority, for contentId: String) { }
    func getActiveDisplays() -> [HUDContent] { [] }
    func setDisplayCapabilities(_ capabilities: DisplayCapabilities) { }
}
