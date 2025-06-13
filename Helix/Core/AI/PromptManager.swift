//
//  PromptManager.swift
//  Helix
//

import Foundation
import Combine

// MARK: - AI Persona Definition

struct AIPersona: Codable, Identifiable, Hashable {
    let id: UUID
    var name: String
    var description: String
    var systemPrompt: String
    var tone: PersonaTone
    var expertise: [String]
    var contextualBehaviors: [PromptConversationContext: String]
    var isBuiltIn: Bool
    var version: Int
    var createdDate: Date
    var lastModified: Date
    
    init(name: String, description: String, systemPrompt: String, tone: PersonaTone = .balanced, expertise: [String] = [], isBuiltIn: Bool = false) {
        self.id = UUID()
        self.name = name
        self.description = description
        self.systemPrompt = systemPrompt
        self.tone = tone
        self.expertise = expertise
        self.contextualBehaviors = [:]
        self.isBuiltIn = isBuiltIn
        self.version = 1
        self.createdDate = Date()
        self.lastModified = Date()
    }
}

enum PersonaTone: String, Codable, CaseIterable {
    case professional = "professional"
    case casual = "casual"
    case friendly = "friendly"
    case analytical = "analytical"
    case creative = "creative"
    case empathetic = "empathetic"
    case authoritative = "authoritative"
    case balanced = "balanced"
    
    var description: String {
        switch self {
        case .professional: return "Professional and formal communication style"
        case .casual: return "Relaxed and informal conversation tone"
        case .friendly: return "Warm and approachable personality"
        case .analytical: return "Data-driven and logical approach"
        case .creative: return "Imaginative and innovative thinking"
        case .empathetic: return "Understanding and emotionally aware"
        case .authoritative: return "Confident and knowledgeable guidance"
        case .balanced: return "Adaptive tone based on context"
        }
    }
}

// MARK: - Conversation Context Detection

/// Context categories for prompting
enum PromptConversationContext: String, Codable, CaseIterable {
    case meeting = "meeting"
    case casual = "casual"
    case interview = "interview"
    case presentation = "presentation"
    case negotiation = "negotiation"
    case learning = "learning"
    case social = "social"
    case professional = "professional"
    case creative = "creative"
    case problem_solving = "problem_solving"
    case debate = "debate"
    case brainstorming = "brainstorming"
    
    var description: String {
        switch self {
        case .meeting: return "Business meeting or formal discussion"
        case .casual: return "Informal conversation"
        case .interview: return "Job interview or formal questioning"
        case .presentation: return "Presenting information to audience"
        case .negotiation: return "Negotiating terms or agreements"
        case .learning: return "Educational or instructional context"
        case .social: return "Social gathering or networking"
        case .professional: return "Professional work environment"
        case .creative: return "Creative collaboration or artistic work"
        case .problem_solving: return "Working through problems or challenges"
        case .debate: return "Formal or informal debate"
        case .brainstorming: return "Generating ideas and solutions"
        }
    }
    
    var keywords: [String] {
        switch self {
        case .meeting: return ["meeting", "agenda", "minutes", "presentation", "discussion"]
        case .casual: return ["hey", "hi", "hello", "how are you", "what's up"]
        case .interview: return ["interview", "candidate", "position", "experience", "qualifications"]
        case .presentation: return ["present", "slide", "audience", "speaker", "topic"]
        case .negotiation: return ["deal", "terms", "agreement", "proposal", "offer"]
        case .learning: return ["learn", "teach", "study", "education", "knowledge"]
        case .social: return ["party", "event", "gathering", "friends", "social"]
        case .professional: return ["work", "business", "project", "deadline", "meeting"]
        case .creative: return ["idea", "creative", "design", "art", "innovation"]
        case .problem_solving: return ["problem", "solution", "issue", "fix", "resolve"]
        case .debate: return ["debate", "argument", "point", "counter", "discuss"]
        case .brainstorming: return ["brainstorm", "idea", "generate", "creative", "solution"]
        }
    }
}

// MARK: - Prompt Template

struct PromptTemplate: Codable, Identifiable, Hashable {
    let id: UUID
    var name: String
    var description: String
    var template: String
    var variables: [PromptVariable]
    var category: PromptCategory
    var isBuiltIn: Bool
    var usageCount: Int
    var lastUsed: Date?
    var createdDate: Date
    
    init(name: String, description: String, template: String, variables: [PromptVariable] = [], category: PromptCategory, isBuiltIn: Bool = false) {
        self.id = UUID()
        self.name = name
        self.description = description
        self.template = template
        self.variables = variables
        self.category = category
        self.isBuiltIn = isBuiltIn
        self.usageCount = 0
        self.lastUsed = nil
        self.createdDate = Date()
    }
    
    func render(with values: [String: String] = [:]) -> String {
        var rendered = template
        for variable in variables {
            let placeholder = "{{\(variable.name)}}"
            let value = values[variable.name] ?? variable.defaultValue
            rendered = rendered.replacingOccurrences(of: placeholder, with: value)
        }
        return rendered
    }
}

struct PromptVariable: Codable, Hashable {
    let name: String
    let description: String
    let type: VariableType
    let defaultValue: String
    let isRequired: Bool
    let options: [String]?
    
    enum VariableType: String, Codable {
        case text = "text"
        case number = "number"
        case boolean = "boolean"
        case selection = "selection"
        case multiSelection = "multiSelection"
    }
}

enum PromptCategory: String, Codable, CaseIterable {
    case factChecking = "fact_checking"
    case summarization = "summarization"
    case analysis = "analysis"
    case coaching = "coaching"
    case creative = "creative"
    case professional = "professional"
    case educational = "educational"
    case social = "social"
    case custom = "custom"
    
    var displayName: String {
        switch self {
        case .factChecking: return "Fact Checking"
        case .summarization: return "Summarization"
        case .analysis: return "Analysis"
        case .coaching: return "Coaching"
        case .creative: return "Creative"
        case .professional: return "Professional"
        case .educational: return "Educational"
        case .social: return "Social"
        case .custom: return "Custom"
        }
    }
}

// MARK: - Context Detector

protocol ContextDetectorProtocol {
    /// Detects the prompt context category from conversation messages
    func detectContext(from messages: [ConversationMessage]) -> PromptConversationContext
    /// Returns confidence score for a given prompt context
    func getContextConfidence(for context: PromptConversationContext, from messages: [ConversationMessage]) -> Float
}

class ContextDetector: ContextDetectorProtocol {
    private let keywordWeights: [PromptConversationContext: Float] = [
        .meeting: 1.0,
        .interview: 0.9,
        .presentation: 0.8,
        .negotiation: 0.8,
        .professional: 0.7,
        .learning: 0.6,
        .creative: 0.6,
        .problem_solving: 0.6,
        .debate: 0.5,
        .brainstorming: 0.5,
        .social: 0.4,
        .casual: 0.3
    ]
    
    func detectContext(from messages: [ConversationMessage]) -> PromptConversationContext {
        let scores = PromptConversationContext.allCases.map { context in
            (context, getContextConfidence(for: context, from: messages))
        }
        
        return scores.max(by: { $0.1 < $1.1 })?.0 ?? .casual
    }
    
    func getContextConfidence(for context: PromptConversationContext, from messages: [ConversationMessage]) -> Float {
        guard !messages.isEmpty else { return 0 }
        
        let combinedText = messages.map(\.content).joined(separator: " ").lowercased()
        let keywords = context.keywords
        
        let keywordMatches = keywords.reduce(0) { count, keyword in
            let occurrences = combinedText.components(separatedBy: keyword.lowercased()).count - 1
            return count + occurrences
        }
        
        let baseScore = Float(keywordMatches) / Float(keywords.count)
        let weightedScore = baseScore * (keywordWeights[context] ?? 0.5)
        
        return min(weightedScore, 1.0)
    }
}

// MARK: - Prompt Manager

protocol PromptManagerProtocol {
    var availablePersonas: AnyPublisher<[AIPersona], Never> { get }
    var availableTemplates: AnyPublisher<[PromptTemplate], Never> { get }
    var currentPersona: AnyPublisher<AIPersona?, Never> { get }
    
    func setCurrentPersona(_ persona: AIPersona)
    func createCustomPersona(_ persona: AIPersona) throws
    func updatePersona(_ persona: AIPersona) throws
    func deletePersona(_ personaId: UUID) throws
    
    func createTemplate(_ template: PromptTemplate) throws
    func updateTemplate(_ template: PromptTemplate) throws
    func deleteTemplate(_ templateId: UUID) throws
    
    func generatePrompt(for context: PromptConversationContext, with data: [String: String]) -> String
    func getPersonaForContext(_ context: PromptConversationContext) -> AIPersona?
    func resetToDefaults()
}

class PromptManager: PromptManagerProtocol, ObservableObject {
    private let personasSubject = CurrentValueSubject<[AIPersona], Never>([])
    private let templatesSubject = CurrentValueSubject<[PromptTemplate], Never>([])
    private let currentPersonaSubject = CurrentValueSubject<AIPersona?, Never>(nil)
    
    private let contextDetector: ContextDetectorProtocol
    private let storage: PromptStorageProtocol
    
    var availablePersonas: AnyPublisher<[AIPersona], Never> {
        personasSubject.eraseToAnyPublisher()
    }
    
    var availableTemplates: AnyPublisher<[PromptTemplate], Never> {
        templatesSubject.eraseToAnyPublisher()
    }
    
    var currentPersona: AnyPublisher<AIPersona?, Never> {
        currentPersonaSubject.eraseToAnyPublisher()
    }
    
    init(contextDetector: ContextDetectorProtocol = ContextDetector(), storage: PromptStorageProtocol = PromptStorage()) {
        self.contextDetector = contextDetector
        self.storage = storage
        
        loadStoredData()
        initializeDefaultPersonas()
        initializeDefaultTemplates()
    }
    
    // MARK: - Persona Management
    
    func setCurrentPersona(_ persona: AIPersona) {
        currentPersonaSubject.send(persona)
        storage.saveCurrentPersona(persona)
    }
    
    func createCustomPersona(_ persona: AIPersona) throws {
        var newPersona = persona
        newPersona.isBuiltIn = false
        
        var personas = personasSubject.value
        personas.append(newPersona)
        personasSubject.send(personas)
        
        try storage.savePersonas(personas)
    }
    
    func updatePersona(_ persona: AIPersona) throws {
        guard !persona.isBuiltIn else {
            throw PromptError.cannotModifyBuiltInPersona
        }
        
        var personas = personasSubject.value
        if let index = personas.firstIndex(where: { $0.id == persona.id }) {
            var updatedPersona = persona
            updatedPersona.version += 1
            updatedPersona.lastModified = Date()
            personas[index] = updatedPersona
            
            personasSubject.send(personas)
            try storage.savePersonas(personas)
        }
    }
    
    func deletePersona(_ personaId: UUID) throws {
        var personas = personasSubject.value
        
        guard let index = personas.firstIndex(where: { $0.id == personaId }) else {
            throw PromptError.personaNotFound
        }
        
        guard !personas[index].isBuiltIn else {
            throw PromptError.cannotDeleteBuiltInPersona
        }
        
        personas.remove(at: index)
        personasSubject.send(personas)
        try storage.savePersonas(personas)
    }
    
    // MARK: - Template Management
    
    func createTemplate(_ template: PromptTemplate) throws {
        var templates = templatesSubject.value
        templates.append(template)
        templatesSubject.send(templates)
        
        try storage.saveTemplates(templates)
    }
    
    func updateTemplate(_ template: PromptTemplate) throws {
        guard !template.isBuiltIn else {
            throw PromptError.cannotModifyBuiltInTemplate
        }
        
        var templates = templatesSubject.value
        if let index = templates.firstIndex(where: { $0.id == template.id }) {
            templates[index] = template
            templatesSubject.send(templates)
            try storage.saveTemplates(templates)
        }
    }
    
    func deleteTemplate(_ templateId: UUID) throws {
        var templates = templatesSubject.value
        
        guard let index = templates.firstIndex(where: { $0.id == templateId }) else {
            throw PromptError.templateNotFound
        }
        
        guard !templates[index].isBuiltIn else {
            throw PromptError.cannotDeleteBuiltInTemplate
        }
        
        templates.remove(at: index)
        templatesSubject.send(templates)
        try storage.saveTemplates(templates)
    }
    
    // MARK: - Prompt Generation
    
    func generatePrompt(for context: PromptConversationContext, with data: [String: String] = [:]) -> String {
        let persona = currentPersonaSubject.value ?? getPersonaForContext(context) ?? getDefaultPersona()
        let contextualBehavior = persona.contextualBehaviors[context] ?? ""
        
        var prompt = persona.systemPrompt
        
        if !contextualBehavior.isEmpty {
            prompt += "\n\nContext-specific instructions for \(context.description):\n\(contextualBehavior)"
        }
        
        // Add data placeholders if provided
        for (key, value) in data {
            prompt = prompt.replacingOccurrences(of: "{{\(key)}}", with: value)
        }
        
        return prompt
    }
    
    func getPersonaForContext(_ context: PromptConversationContext) -> AIPersona? {
        let personas = personasSubject.value
        
        // Look for personas with specific contextual behaviors for this context
        return personas.first { persona in
            persona.contextualBehaviors.keys.contains(context)
        }
    }
    
    func resetToDefaults() {
        initializeDefaultPersonas()
        initializeDefaultTemplates()
        
        if let defaultPersona = personasSubject.value.first(where: { $0.name == "General Assistant" }) {
            setCurrentPersona(defaultPersona)
        }
    }
    
    // MARK: - Private Methods
    
    private func loadStoredData() {
        if let storedPersonas = storage.loadPersonas() {
            personasSubject.send(storedPersonas)
        }
        
        if let storedTemplates = storage.loadTemplates() {
            templatesSubject.send(storedTemplates)
        }
        
        if let currentPersona = storage.loadCurrentPersona() {
            currentPersonaSubject.send(currentPersona)
        }
    }
    
    private func getDefaultPersona() -> AIPersona {
        return personasSubject.value.first(where: { $0.name == "General Assistant" }) ??
               personasSubject.value.first ??
               AIPersona(name: "Default", description: "Default assistant", systemPrompt: "You are a helpful assistant.")
    }
    
    private func initializeDefaultPersonas() {
        let defaultPersonas = [
            AIPersona(
                name: "General Assistant",
                description: "Balanced assistant for general conversation analysis",
                systemPrompt: "You are an intelligent assistant helping analyze conversations in real-time. Provide helpful, accurate, and contextually appropriate responses. Focus on being helpful while being concise for display on smart glasses.",
                tone: .balanced,
                expertise: ["general knowledge", "conversation analysis"],
                isBuiltIn: true
            ),
            
            AIPersona(
                name: "Fact Checker",
                description: "Specialized in verifying claims and providing accurate information",
                systemPrompt: "You are a fact-checking specialist. Analyze statements for accuracy, provide corrections when needed, and cite reliable sources. Be precise and focus on verifiable information.",
                tone: .analytical,
                expertise: ["fact checking", "research", "verification"],
                isBuiltIn: true
            ),
            
            AIPersona(
                name: "Meeting Assistant",
                description: "Optimized for business meetings and professional discussions",
                systemPrompt: "You are a professional meeting assistant. Track action items, summarize key points, and provide meeting insights. Focus on productivity and clear communication.",
                tone: .professional,
                expertise: ["meetings", "business", "productivity"],
                isBuiltIn: true
            ),
            
            AIPersona(
                name: "Social Coach",
                description: "Provides social interaction guidance and communication tips",
                systemPrompt: "You are a social interaction coach. Provide helpful suggestions for conversations, detect social cues, and offer communication advice. Be supportive and encouraging.",
                tone: .empathetic,
                expertise: ["social skills", "communication", "relationships"],
                isBuiltIn: true
            ),
            
            AIPersona(
                name: "Learning Companion",
                description: "Educational support for learning conversations",
                systemPrompt: "You are an educational companion. Help explain concepts, provide definitions, and support learning discussions. Make complex topics accessible and engaging.",
                tone: .friendly,
                expertise: ["education", "explanations", "learning"],
                isBuiltIn: true
            )
        ]
        
        // Add contextual behaviors
        var personas = defaultPersonas
        personas[1].contextualBehaviors[.meeting] = "Focus on identifying actionable items and key decisions. Summarize complex discussions clearly."
        personas[2].contextualBehaviors[.interview] = "Provide strategic coaching for interview responses. Highlight strengths and suggest improvements."
        personas[3].contextualBehaviors[.social] = "Offer conversation starters and help navigate social dynamics gracefully."
        personas[4].contextualBehaviors[.learning] = "Break down complex concepts into digestible parts. Encourage questions and exploration."
        
        if personasSubject.value.isEmpty {
            personasSubject.send(personas)
            try? storage.savePersonas(personas)
            
            // Set default current persona
            if let defaultPersona = personas.first {
                currentPersonaSubject.send(defaultPersona)
                storage.saveCurrentPersona(defaultPersona)
            }
        }
    }
    
    private func initializeDefaultTemplates() {
        let defaultTemplates = [
            PromptTemplate(
                name: "Fact Check Analysis",
                description: "Template for analyzing factual claims",
                template: "Analyze this claim for accuracy: '{{claim}}'. Provide verification status, explanation, and reliable sources if available.",
                variables: [
                    PromptVariable(name: "claim", description: "The factual claim to verify", type: .text, defaultValue: "", isRequired: true, options: nil)
                ],
                category: .factChecking,
                isBuiltIn: true
            ),
            
            PromptTemplate(
                name: "Meeting Summary",
                description: "Template for summarizing meeting discussions",
                template: "Summarize this meeting discussion focusing on: {{focus_areas}}. Include key decisions, action items, and next steps.",
                variables: [
                    PromptVariable(name: "focus_areas", description: "Specific areas to focus on", type: .text, defaultValue: "key decisions and action items", isRequired: false, options: nil)
                ],
                category: .summarization,
                isBuiltIn: true
            ),
            
            PromptTemplate(
                name: "Communication Coaching",
                description: "Template for providing communication feedback",
                template: "Analyze this conversation for communication effectiveness. Focus on {{analysis_type}} and provide constructive feedback.",
                variables: [
                    PromptVariable(name: "analysis_type", description: "Type of analysis to perform", type: .selection, defaultValue: "overall communication", isRequired: false, options: ["overall communication", "persuasion techniques", "active listening", "clarity", "emotional intelligence"])
                ],
                category: .coaching,
                isBuiltIn: true
            )
        ]
        
        if templatesSubject.value.isEmpty {
            templatesSubject.send(defaultTemplates)
            try? storage.saveTemplates(defaultTemplates)
        }
    }
}

// MARK: - Errors

enum PromptError: LocalizedError {
    case personaNotFound
    case templateNotFound
    case cannotModifyBuiltInPersona
    case cannotDeleteBuiltInPersona
    case cannotModifyBuiltInTemplate
    case cannotDeleteBuiltInTemplate
    case invalidTemplate
    case storageFailed
    
    var errorDescription: String? {
        switch self {
        case .personaNotFound:
            return "Persona not found"
        case .templateNotFound:
            return "Template not found"
        case .cannotModifyBuiltInPersona:
            return "Cannot modify built-in persona"
        case .cannotDeleteBuiltInPersona:
            return "Cannot delete built-in persona"
        case .cannotModifyBuiltInTemplate:
            return "Cannot modify built-in template"
        case .cannotDeleteBuiltInTemplate:
            return "Cannot delete built-in template"
        case .invalidTemplate:
            return "Invalid template format"
        case .storageFailed:
            return "Failed to save to storage"
        }
    }
}

// MARK: - Storage Protocol

protocol PromptStorageProtocol {
    func savePersonas(_ personas: [AIPersona]) throws
    func loadPersonas() -> [AIPersona]?
    func saveTemplates(_ templates: [PromptTemplate]) throws
    func loadTemplates() -> [PromptTemplate]?
    func saveCurrentPersona(_ persona: AIPersona)
    func loadCurrentPersona() -> AIPersona?
}

class PromptStorage: PromptStorageProtocol {
    private let userDefaults = UserDefaults.standard
    private let personasKey = "ai_personas"
    private let templatesKey = "prompt_templates"
    private let currentPersonaKey = "current_persona"
    
    func savePersonas(_ personas: [AIPersona]) throws {
        let data = try JSONEncoder().encode(personas)
        userDefaults.set(data, forKey: personasKey)
    }
    
    func loadPersonas() -> [AIPersona]? {
        guard let data = userDefaults.data(forKey: personasKey) else { return nil }
        return try? JSONDecoder().decode([AIPersona].self, from: data)
    }
    
    func saveTemplates(_ templates: [PromptTemplate]) throws {
        let data = try JSONEncoder().encode(templates)
        userDefaults.set(data, forKey: templatesKey)
    }
    
    func loadTemplates() -> [PromptTemplate]? {
        guard let data = userDefaults.data(forKey: templatesKey) else { return nil }
        return try? JSONDecoder().decode([PromptTemplate].self, from: data)
    }
    
    func saveCurrentPersona(_ persona: AIPersona) {
        let data = try? JSONEncoder().encode(persona)
        userDefaults.set(data, forKey: currentPersonaKey)
    }
    
    func loadCurrentPersona() -> AIPersona? {
        guard let data = userDefaults.data(forKey: currentPersonaKey) else { return nil }
        return try? JSONDecoder().decode(AIPersona.self, from: data)
    }
}