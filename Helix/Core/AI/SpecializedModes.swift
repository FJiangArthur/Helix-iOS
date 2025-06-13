//
//  SpecializedModes.swift
//  Helix
//

import Foundation
import Combine

// MARK: - Specialized Mode Definitions

enum SpecializedMode: String, CaseIterable, Codable {
    case ghostWriter = "ghost_writer"
    case devilsAdvocate = "devils_advocate"
    case wingman = "wingman"
    case sherlockHolmes = "sherlock_holmes"
    case therapyAssistant = "therapy_assistant"
    case speedNetworking = "speed_networking"
    case interview = "interview"
    case creativeCollaboration = "creative_collaboration"
    
    var displayName: String {
        switch self {
        case .ghostWriter: return "Ghost Writer"
        case .devilsAdvocate: return "Devil's Advocate"
        case .wingman: return "Wingman"
        case .sherlockHolmes: return "Sherlock Holmes"
        case .therapyAssistant: return "Therapy Assistant"
        case .speedNetworking: return "Speed Networking"
        case .interview: return "Interview Coach"
        case .creativeCollaboration: return "Creative Collaborator"
        }
    }
    
    var description: String {
        switch self {
        case .ghostWriter:
            return "Generates responses for you to read aloud in conversations"
        case .devilsAdvocate:
            return "Presents counter-arguments to strengthen your positions"
        case .wingman:
            return "Social interaction coaching for personal relationships"
        case .sherlockHolmes:
            return "Analyzes micro-expressions and verbal cues for insights"
        case .therapyAssistant:
            return "Therapeutic communication technique suggestions"
        case .speedNetworking:
            return "Rapid conversation starters and networking tips"
        case .interview:
            return "Question preparation and response coaching"
        case .creativeCollaboration:
            return "Brainstorming facilitation and idea generation"
        }
    }
    
    var icon: String {
        switch self {
        case .ghostWriter: return "pencil.and.outline"
        case .devilsAdvocate: return "flame"
        case .wingman: return "heart.circle"
        case .sherlockHolmes: return "magnifyingglass.circle"
        case .therapyAssistant: return "heart.text.square"
        case .speedNetworking: return "person.2.circle"
        case .interview: return "person.crop.circle.badge.questionmark"
        case .creativeCollaboration: return "lightbulb.circle"
        }
    }
}

// MARK: - Mode Configuration

struct ModeConfiguration: Codable {
    let mode: SpecializedMode
    var isEnabled: Bool
    var customSettings: [String: String]
    var triggerPhrases: [String]
    var autoActivation: Bool
    var confidenceThreshold: Float
    var responseStyle: ResponseStyle
    
    init(mode: SpecializedMode) {
        self.mode = mode
        self.isEnabled = true
        self.customSettings = [:]
        self.triggerPhrases = []
        self.autoActivation = false
        self.confidenceThreshold = 0.7
        self.responseStyle = .balanced
    }
}

enum ResponseStyle: String, CaseIterable, Codable {
    case concise = "concise"
    case detailed = "detailed"
    case balanced = "balanced"
    case creative = "creative"
    case analytical = "analytical"
    
    var description: String {
        switch self {
        case .concise: return "Brief and to the point"
        case .detailed: return "Comprehensive and thorough"
        case .balanced: return "Moderate level of detail"
        case .creative: return "Imaginative and innovative"
        case .analytical: return "Data-driven and logical"
        }
    }
}

// MARK: - Mode Response

struct ModeResponse {
    let id: UUID
    let mode: SpecializedMode
    let content: String
    let alternatives: [String]
    let confidence: Float
    let context: ResponseContext
    let timing: ResponseTiming
    let metadata: [String: Any]
    
    init(mode: SpecializedMode, content: String, alternatives: [String] = [], confidence: Float = 1.0, context: ResponseContext = .general) {
        self.id = UUID()
        self.mode = mode
        self.content = content
        self.alternatives = alternatives
        self.confidence = confidence
        self.context = context
        self.timing = ResponseTiming.immediate
        self.metadata = [:]
    }
}

enum ResponseContext: String, Codable {
    case general = "general"
    case professional = "professional"
    case social = "social"
    case academic = "academic"
    case creative = "creative"
    case personal = "personal"
}

enum ResponseTiming: String, Codable {
    case immediate = "immediate"
    case delayed = "delayed"
    case onDemand = "on_demand"
}

// MARK: - Specialized Modes Manager

protocol SpecializedModesManagerProtocol {
    var activeMode: AnyPublisher<SpecializedMode?, Never> { get }
    var availableModes: AnyPublisher<[SpecializedMode], Never> { get }
    var modeConfigurations: AnyPublisher<[SpecializedMode: ModeConfiguration], Never> { get }
    
    func activateMode(_ mode: SpecializedMode)
    func deactivateMode()
    func configureMode(_ mode: SpecializedMode, configuration: ModeConfiguration)
    func generateResponse(for context: ModeContext) -> AnyPublisher<ModeResponse, ModeError>
    func detectModeFromContext(_ context: ModeContext) -> SpecializedMode?
}

class SpecializedModesManager: SpecializedModesManagerProtocol, ObservableObject {
    private let activeModeSubject = CurrentValueSubject<SpecializedMode?, Never>(nil)
    private let availableModesSubject = CurrentValueSubject<[SpecializedMode], Never>(SpecializedMode.allCases)
    private let modeConfigurationsSubject = CurrentValueSubject<[SpecializedMode: ModeConfiguration], Never>([:])
    
    private let modeHandlers: [SpecializedMode: SpecializedModeHandler]
    private let llmService: LLMServiceProtocol
    private let contextAnalyzer: ModeContextAnalyzer
    
    var activeMode: AnyPublisher<SpecializedMode?, Never> {
        activeModeSubject.eraseToAnyPublisher()
    }
    
    var availableModes: AnyPublisher<[SpecializedMode], Never> {
        availableModesSubject.eraseToAnyPublisher()
    }
    
    var modeConfigurations: AnyPublisher<[SpecializedMode: ModeConfiguration], Never> {
        modeConfigurationsSubject.eraseToAnyPublisher()
    }
    
    init(llmService: LLMServiceProtocol) {
        self.llmService = llmService
        self.contextAnalyzer = ModeContextAnalyzer()
        
        // Initialize mode handlers
        self.modeHandlers = [
            .ghostWriter: GhostWriterMode(llmService: llmService),
            .devilsAdvocate: DevilsAdvocateMode(llmService: llmService),
            .wingman: WingmanMode(llmService: llmService),
            .sherlockHolmes: SherlockHolmesMode(llmService: llmService),
            .therapyAssistant: TherapyAssistantMode(llmService: llmService),
            .speedNetworking: SpeedNetworkingMode(llmService: llmService),
            .interview: InterviewMode(llmService: llmService),
            .creativeCollaboration: CreativeCollaborationMode(llmService: llmService)
        ]
        
        initializeDefaultConfigurations()
    }
    
    func activateMode(_ mode: SpecializedMode) {
        activeModeSubject.send(mode)
        print("Activated specialized mode: \(mode.displayName)")
    }
    
    func deactivateMode() {
        activeModeSubject.send(nil)
        print("Deactivated specialized mode")
    }
    
    func configureMode(_ mode: SpecializedMode, configuration: ModeConfiguration) {
        var configurations = modeConfigurationsSubject.value
        configurations[mode] = configuration
        modeConfigurationsSubject.send(configurations)
    }
    
    func generateResponse(for context: ModeContext) -> AnyPublisher<ModeResponse, ModeError> {
        guard let activeMode = activeModeSubject.value else {
            return Fail(error: ModeError.noActiveModePresent)
                .eraseToAnyPublisher()
        }
        
        guard let handler = modeHandlers[activeMode] else {
            return Fail(error: ModeError.modeHandlerNotFound)
                .eraseToAnyPublisher()
        }
        
        let configuration = modeConfigurationsSubject.value[activeMode] ?? ModeConfiguration(mode: activeMode)
        
        return handler.generateResponse(for: context, configuration: configuration)
    }
    
    func detectModeFromContext(_ context: ModeContext) -> SpecializedMode? {
        return contextAnalyzer.detectOptimalMode(from: context)
    }
    
    private func initializeDefaultConfigurations() {
        var configurations: [SpecializedMode: ModeConfiguration] = [:]
        
        for mode in SpecializedMode.allCases {
            configurations[mode] = ModeConfiguration(mode: mode)
        }
        
        modeConfigurationsSubject.send(configurations)
    }
}

// MARK: - Mode Context

struct ModeContext {
    let messages: [ConversationMessage]
    let speakers: [Speaker]
    let currentSpeaker: Speaker?
    let conversationType: SocialContext
    let environmentalFactors: EnvironmentalFactors
    let userPreferences: UserPreferences
    let timestamp: TimeInterval
    
    init(messages: [ConversationMessage], speakers: [Speaker], currentSpeaker: Speaker? = nil, conversationType: SocialContext = .informal) {
        self.messages = messages
        self.speakers = speakers
        self.currentSpeaker = currentSpeaker
        self.conversationType = conversationType
        self.environmentalFactors = EnvironmentalFactors()
        self.userPreferences = UserPreferences()
        self.timestamp = Date().timeIntervalSince1970
    }
}

struct EnvironmentalFactors {
    let noiseLevel: Float
    let location: String?
    let timeOfDay: TimeOfDay
    let socialContext: SocialContext
    
    init(noiseLevel: Float = 0.0, location: String? = nil, timeOfDay: TimeOfDay = .unknown, socialContext: SocialContext = .unknown) {
        self.noiseLevel = noiseLevel
        self.location = location
        self.timeOfDay = timeOfDay
        self.socialContext = socialContext
    }
}

enum TimeOfDay: String, Codable {
    case morning = "morning"
    case afternoon = "afternoon"
    case evening = "evening"
    case night = "night"
    case unknown = "unknown"
}

enum SocialContext: String, Codable {
    case formal = "formal"
    case informal = "informal"
    case `public` = "public"
    case `private` = "private"
    case professional = "professional"
    case personal = "personal"
    case unknown = "unknown"
}

struct UserPreferences {
    let responseLength: ResponseLength
    let humorLevel: HumorLevel
    let assertivenessLevel: AssertivenessLevel
    let culturalContext: String?
    
    init(responseLength: ResponseLength = .medium, humorLevel: HumorLevel = .moderate, assertivenessLevel: AssertivenessLevel = .balanced, culturalContext: String? = nil) {
        self.responseLength = responseLength
        self.humorLevel = humorLevel
        self.assertivenessLevel = assertivenessLevel
        self.culturalContext = culturalContext
    }
}

enum ResponseLength: String, CaseIterable, Codable {
    case brief = "brief"
    case medium = "medium"
    case detailed = "detailed"
}

enum HumorLevel: String, CaseIterable, Codable {
    case none = "none"
    case subtle = "subtle"
    case moderate = "moderate"
    case high = "high"
}

enum AssertivenessLevel: String, CaseIterable, Codable {
    case passive = "passive"
    case balanced = "balanced"
    case assertive = "assertive"
    case aggressive = "aggressive"
}

// MARK: - Mode Handler Protocol

protocol SpecializedModeHandler {
    var mode: SpecializedMode { get }
    func generateResponse(for context: ModeContext, configuration: ModeConfiguration) -> AnyPublisher<ModeResponse, ModeError>
    func isApplicable(for context: ModeContext) -> Bool
    func getConfidence(for context: ModeContext) -> Float
}

// MARK: - Ghost Writer Mode

class GhostWriterMode: SpecializedModeHandler {
    let mode: SpecializedMode = .ghostWriter
    private let llmService: LLMServiceProtocol
    
    init(llmService: LLMServiceProtocol) {
        self.llmService = llmService
    }
    
    func generateResponse(for context: ModeContext, configuration: ModeConfiguration) -> AnyPublisher<ModeResponse, ModeError> {
        let prompt = createGhostWriterPrompt(context: context, configuration: configuration)
        
        return llmService.analyzeWithCustomPrompt(prompt, context: createLLMContext(from: context))
            .map { analysisResult in
                let content = self.extractResponseContent(from: analysisResult)
                let alternatives = self.generateAlternatives(content: content, context: context)
                
                return ModeResponse(
                    mode: .ghostWriter,
                    content: content,
                    alternatives: alternatives,
                    confidence: analysisResult.confidence,
                    context: self.mapToResponseContext(context.conversationType)
                )
            }
            .mapError { _ in ModeError.responseGenerationFailed }
            .eraseToAnyPublisher()
    }
    
    func isApplicable(for context: ModeContext) -> Bool {
        // Ghost writer is applicable when user needs help responding
        return context.messages.count > 0 && context.currentSpeaker?.isCurrentUser == false
    }
    
    func getConfidence(for context: ModeContext) -> Float {
        // Higher confidence in formal or professional settings
        switch context.conversationType {
        case .formal, .professional: return 0.9
        case .informal: return 0.6
        default: return 0.4
        }
    }
    
    private func createGhostWriterPrompt(context: ModeContext, configuration: ModeConfiguration) -> String {
        let recentMessages = Array(context.messages.suffix(3))
        let conversationText = recentMessages.map { "\($0.content)" }.joined(separator: "\n")
        
        let styleInstruction = getStyleInstruction(for: configuration.responseStyle)
        let lengthInstruction = getLengthInstruction(for: context.userPreferences.responseLength)
        
        return """
        You are a Ghost Writer assistant. Generate a natural, contextually appropriate response that the user can speak aloud in this conversation.
        
        Conversation context:
        \(conversationText)
        
        Instructions:
        - \(styleInstruction)
        - \(lengthInstruction)
        - Make it sound natural and conversational
        - Consider the tone and style of the conversation
        - Provide a response that advances the conversation meaningfully
        
        Generate 1-2 sentences that the user can say next:
        """
    }
    
    private func getStyleInstruction(for style: ResponseStyle) -> String {
        switch style {
        case .concise: return "Keep the response brief and to the point"
        case .detailed: return "Provide a thoughtful, comprehensive response"
        case .balanced: return "Strike a balance between brevity and completeness"
        case .creative: return "Use creative and engaging language"
        case .analytical: return "Focus on logical reasoning and facts"
        }
    }
    
    private func getLengthInstruction(for length: ResponseLength) -> String {
        switch length {
        case .brief: return "Maximum 1 sentence"
        case .medium: return "1-2 sentences"
        case .detailed: return "2-3 sentences maximum"
        }
    }
    
    private func generateAlternatives(content: String, context: ModeContext) -> [String] {
        // Generate alternative phrasings (simplified implementation)
        return [
            "Alternative: " + content.replacingOccurrences(of: "I think", with: "In my opinion"),
            "Alternative: " + content.replacingOccurrences(of: "Yes", with: "Absolutely")
        ]
    }
    
    private func extractResponseContent(from result: AnalysisResult) -> String {
        switch result.content {
        case .text(let text): return text
        default: return "I'd like to add my perspective on this topic."
        }
    }
    
    private func createLLMContext(from context: ModeContext) -> ConversationContext {
        return ConversationContext(
            messages: context.messages,
            speakers: context.speakers,
            analysisType: .clarification,
            metadata: ConversationMetadata(tags: ["ghost_writer"])
        )
    }
    
    private func mapToResponseContext(_ conversationType: SocialContext) -> ResponseContext {
        switch conversationType {
        case .formal, .professional: return .professional
        case .informal: return .social
        case .`public`: return .social
        case .`private`: return .personal
        default: return .general
        }
    }
}

// MARK: - Devil's Advocate Mode

class DevilsAdvocateMode: SpecializedModeHandler {
    let mode: SpecializedMode = .devilsAdvocate
    private let llmService: LLMServiceProtocol
    
    init(llmService: LLMServiceProtocol) {
        self.llmService = llmService
    }
    
    func generateResponse(for context: ModeContext, configuration: ModeConfiguration) -> AnyPublisher<ModeResponse, ModeError> {
        let prompt = createDevilsAdvocatePrompt(context: context, configuration: configuration)
        
        return llmService.analyzeWithCustomPrompt(prompt, context: createLLMContext(from: context))
            .map { analysisResult in
                let content = self.extractResponseContent(from: analysisResult)
                
                return ModeResponse(
                    mode: .devilsAdvocate,
                    content: content,
                    confidence: analysisResult.confidence,
                    context: .professional
                )
            }
            .mapError { _ in ModeError.responseGenerationFailed }
            .eraseToAnyPublisher()
    }
    
    func isApplicable(for context: ModeContext) -> Bool {
        // Devil's advocate is useful in debates, discussions, and decision-making
        return context.conversationType == .formal || 
               context.conversationType == .professional
    }
    
    func getConfidence(for context: ModeContext) -> Float {
        switch context.conversationType {
        case .formal, .professional: return 0.9
        default: return 0.4
        }
    }
    
    private func createDevilsAdvocatePrompt(context: ModeContext, configuration: ModeConfiguration) -> String {
        let recentMessages = Array(context.messages.suffix(3))
        let conversationText = recentMessages.map { "\($0.content)" }.joined(separator: "\n")
        
        return """
        You are a Devil's Advocate assistant. Identify potential counterarguments, weaknesses, or alternative perspectives to strengthen the discussion.
        
        Recent conversation:
        \(conversationText)
        
        Provide constructive counterpoints or alternative viewpoints that could:
        - Challenge assumptions
        - Identify potential risks or downsides
        - Present alternative solutions
        - Strengthen the overall argument through critical examination
        
        Be respectful but thought-provoking in your analysis:
        """
    }
    
    private func extractResponseContent(from result: AnalysisResult) -> String {
        switch result.content {
        case .text(let text): return text
        default: return "Consider this alternative perspective..."
        }
    }
    
    private func createLLMContext(from context: ModeContext) -> ConversationContext {
        return ConversationContext(
            messages: context.messages,
            speakers: context.speakers,
            analysisType: .clarification,
            metadata: ConversationMetadata(tags: ["devils_advocate", "critical_thinking"])
        )
    }
}

// MARK: - Placeholder Mode Implementations

class WingmanMode: SpecializedModeHandler {
    let mode: SpecializedMode = .wingman
    private let llmService: LLMServiceProtocol
    
    init(llmService: LLMServiceProtocol) {
        self.llmService = llmService
    }
    
    func generateResponse(for context: ModeContext, configuration: ModeConfiguration) -> AnyPublisher<ModeResponse, ModeError> {
        // Implementation for social interaction coaching
        return Just(ModeResponse(mode: .wingman, content: "Great conversation starter: Ask about their interests in this topic."))
            .setFailureType(to: ModeError.self)
            .eraseToAnyPublisher()
    }
    
    func isApplicable(for context: ModeContext) -> Bool {
        return context.conversationType == .informal
    }
    
    func getConfidence(for context: ModeContext) -> Float {
        return context.conversationType == .informal ? 0.8 : 0.3
    }
}

class SherlockHolmesMode: SpecializedModeHandler {
    let mode: SpecializedMode = .sherlockHolmes
    private let llmService: LLMServiceProtocol
    
    init(llmService: LLMServiceProtocol) {
        self.llmService = llmService
    }
    
    func generateResponse(for context: ModeContext, configuration: ModeConfiguration) -> AnyPublisher<ModeResponse, ModeError> {
        // Implementation for observation and deduction analysis
        return Just(ModeResponse(mode: .sherlockHolmes, content: "Observation: Notice the change in speaking pace when discussing financial topics."))
            .setFailureType(to: ModeError.self)
            .eraseToAnyPublisher()
    }
    
    func isApplicable(for context: ModeContext) -> Bool {
        return true // Can analyze any conversation
    }
    
    func getConfidence(for context: ModeContext) -> Float {
        return 0.6
    }
}

class TherapyAssistantMode: SpecializedModeHandler {
    let mode: SpecializedMode = .therapyAssistant
    private let llmService: LLMServiceProtocol
    
    init(llmService: LLMServiceProtocol) {
        self.llmService = llmService
    }
    
    func generateResponse(for context: ModeContext, configuration: ModeConfiguration) -> AnyPublisher<ModeResponse, ModeError> {
        // Implementation for therapeutic communication suggestions
        return Just(ModeResponse(mode: .therapyAssistant, content: "Try reflecting their emotions: 'It sounds like this situation is really frustrating for you.'"))
            .setFailureType(to: ModeError.self)
            .eraseToAnyPublisher()
    }
    
    func isApplicable(for context: ModeContext) -> Bool {
        return context.environmentalFactors.socialContext == .personal
    }
    
    func getConfidence(for context: ModeContext) -> Float {
        return 0.7
    }
}

class SpeedNetworkingMode: SpecializedModeHandler {
    let mode: SpecializedMode = .speedNetworking
    private let llmService: LLMServiceProtocol
    
    init(llmService: LLMServiceProtocol) {
        self.llmService = llmService
    }
    
    func generateResponse(for context: ModeContext, configuration: ModeConfiguration) -> AnyPublisher<ModeResponse, ModeError> {
        return Just(ModeResponse(mode: .speedNetworking, content: "Time for a transition: 'That's fascinating! How did you get started in that field?'"))
            .setFailureType(to: ModeError.self)
            .eraseToAnyPublisher()
    }
    
    func isApplicable(for context: ModeContext) -> Bool {
        return context.conversationType == .informal || context.conversationType == .professional
    }
    
    func getConfidence(for context: ModeContext) -> Float {
        return 0.6
    }
}

class InterviewMode: SpecializedModeHandler {
    let mode: SpecializedMode = .interview
    private let llmService: LLMServiceProtocol
    
    init(llmService: LLMServiceProtocol) {
        self.llmService = llmService
    }
    
    func generateResponse(for context: ModeContext, configuration: ModeConfiguration) -> AnyPublisher<ModeResponse, ModeError> {
        return Just(ModeResponse(mode: .interview, content: "Strong answer structure: Situation, Task, Action, Result. Highlight your specific contribution."))
            .setFailureType(to: ModeError.self)
            .eraseToAnyPublisher()
    }
    
    func isApplicable(for context: ModeContext) -> Bool {
        return context.conversationType == .professional
    }
    
    func getConfidence(for context: ModeContext) -> Float {
        return context.conversationType == .professional ? 0.9 : 0.2
    }
}

class CreativeCollaborationMode: SpecializedModeHandler {
    let mode: SpecializedMode = .creativeCollaboration
    private let llmService: LLMServiceProtocol
    
    init(llmService: LLMServiceProtocol) {
        self.llmService = llmService
    }
    
    func generateResponse(for context: ModeContext, configuration: ModeConfiguration) -> AnyPublisher<ModeResponse, ModeError> {
        return Just(ModeResponse(mode: .creativeCollaboration, content: "Build on that idea: 'What if we took that concept and applied it to...'"))
            .setFailureType(to: ModeError.self)
            .eraseToAnyPublisher()
    }
    
    func isApplicable(for context: ModeContext) -> Bool {
        return context.conversationType == .informal || context.conversationType == .`public`
    }
    
    func getConfidence(for context: ModeContext) -> Float {
        return context.conversationType == .informal ? 0.8 : 0.4
    }
}

// MARK: - Mode Context Analyzer

class ModeContextAnalyzer {
    func detectOptimalMode(from context: ModeContext) -> SpecializedMode? {
        let handlers: [SpecializedModeHandler] = [
            GhostWriterMode(llmService: MockLLMService()),
            DevilsAdvocateMode(llmService: MockLLMService()),
            WingmanMode(llmService: MockLLMService()),
            InterviewMode(llmService: MockLLMService())
        ]
        
        return handlers
            .filter { $0.isApplicable(for: context) }
            .max(by: { $0.getConfidence(for: context) < $1.getConfidence(for: context) })?
            .mode
    }
}

// MARK: - Mock LLM Service for Mode Handlers

private class MockLLMService: LLMServiceProtocol {
    func analyzeConversation(_ context: ConversationContext) -> AnyPublisher<AnalysisResult, LLMError> {
        return Just(AnalysisResult(type: .clarification, content: .text("Mock response")))
            .setFailureType(to: LLMError.self)
            .eraseToAnyPublisher()
    }
    
    func analyzeWithCustomPrompt(_ prompt: String, context: ConversationContext) -> AnyPublisher<AnalysisResult, LLMError> {
        return Just(AnalysisResult(type: .clarification, content: .text("Mock custom response")))
            .setFailureType(to: LLMError.self)
            .eraseToAnyPublisher()
    }
    
    func factCheck(_ claim: String, context: ConversationContext?) -> AnyPublisher<FactCheckResult, LLMError> {
        return Just(FactCheckResult(claim: claim, isAccurate: true, explanation: "Mock", sources: [], confidence: 0.8, alternativeInfo: nil, category: .general, severity: .minor))
            .setFailureType(to: LLMError.self)
            .eraseToAnyPublisher()
    }
    
    func summarizeConversation(_ messages: [ConversationMessage]) -> AnyPublisher<String, LLMError> {
        return Just("Mock summary")
            .setFailureType(to: LLMError.self)
            .eraseToAnyPublisher()
    }
    
    func detectClaims(in text: String) -> AnyPublisher<[FactualClaim], LLMError> {
        return Just([])
            .setFailureType(to: LLMError.self)
            .eraseToAnyPublisher()
    }
    
    func extractActionItems(from messages: [ConversationMessage]) -> AnyPublisher<[ActionItem], LLMError> {
        return Just([])
            .setFailureType(to: LLMError.self)
            .eraseToAnyPublisher()
    }
    
    func setCurrentPersona(_ persona: AIPersona) {}
    
    func generatePersonalizedResponse(_ messages: [ConversationMessage], conversationContext: Helix.ConversationContext) -> AnyPublisher<String, LLMError> {
        return Just("Mock personalized response")
            .setFailureType(to: LLMError.self)
            .eraseToAnyPublisher()
    }
}

// MARK: - Errors

enum ModeError: LocalizedError {
    case noActiveModePresent
    case modeHandlerNotFound
    case responseGenerationFailed
    case invalidConfiguration
    case contextInsufficientForMode
    
    var errorDescription: String? {
        switch self {
        case .noActiveModePresent:
            return "No specialized mode is currently active"
        case .modeHandlerNotFound:
            return "Handler for the specified mode was not found"
        case .responseGenerationFailed:
            return "Failed to generate response for the current mode"
        case .invalidConfiguration:
            return "Invalid configuration for the specified mode"
        case .contextInsufficientForMode:
            return "Insufficient context to activate the requested mode"
        }
    }
}