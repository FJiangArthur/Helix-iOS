import Foundation

public enum ConversationMode: String, Codable, CaseIterable, Sendable {
    case general
    case interview
    case passive
}

public enum TranscriptionBackend: String, Codable, CaseIterable, Sendable {
    case appleOnDevice
    case appleCloud
    case openAITranscription
    case openAIRealtime
}

public enum LlmProviderKind: String, Codable, CaseIterable, Sendable {
    case openAI
    case anthropic
    case deepSeek
    case qwen
    case zhipu
}

public enum HudRenderPath: String, Codable, CaseIterable, Sendable {
    case bitmap
    case text
}

public enum WebSearchMode: String, Codable, CaseIterable, Sendable {
    case disabled
    case fakeDeterministic
    case live
}

public struct ProviderModelSelection: Codable, Equatable, Sendable {
    public var smartModel: String
    public var lightModel: String
    public var realtimeModel: String?
    public var transcriptionModel: String?

    public init(
        smartModel: String,
        lightModel: String,
        realtimeModel: String? = nil,
        transcriptionModel: String? = nil
    ) {
        self.smartModel = smartModel
        self.lightModel = lightModel
        self.realtimeModel = realtimeModel
        self.transcriptionModel = transcriptionModel
    }
}

public struct ProviderConfiguration: Codable, Equatable, Identifiable, Sendable {
    public var id: LlmProviderKind { kind }
    public var kind: LlmProviderKind
    public var displayName: String
    public var modelSelection: ProviderModelSelection
    public var apiKeySecretName: String
    public var isEnabled: Bool

    public init(
        kind: LlmProviderKind,
        displayName: String,
        modelSelection: ProviderModelSelection,
        apiKeySecretName: String,
        isEnabled: Bool = true
    ) {
        self.kind = kind
        self.displayName = displayName
        self.modelSelection = modelSelection
        self.apiKeySecretName = apiKeySecretName
        self.isEnabled = isEnabled
    }
}

public struct HelixSettings: Codable, Equatable, Sendable {
    public var maxResponseSentences: Int
    public var transcriptionBackend: TranscriptionBackend
    public var transcriptionModel: String
    public var llmProvider: LlmProviderKind
    public var llmModel: String
    public var hudRenderPath: HudRenderPath
    public var autoDetectQuestions: Bool
    public var autoAnswer: Bool
    public var webSearchMode: WebSearchMode
    public var liveFactCheckEnabled: Bool
    public var evalGateEnabled: Bool
    public var providers: [ProviderConfiguration]

    public init(
        maxResponseSentences: Int = 3,
        transcriptionBackend: TranscriptionBackend = .openAITranscription,
        transcriptionModel: String = "gpt-4o-mini-transcribe",
        llmProvider: LlmProviderKind = .openAI,
        llmModel: String = "gpt-4.1-mini",
        hudRenderPath: HudRenderPath = .bitmap,
        autoDetectQuestions: Bool = true,
        autoAnswer: Bool = true,
        webSearchMode: WebSearchMode = .disabled,
        liveFactCheckEnabled: Bool = true,
        evalGateEnabled: Bool = false,
        providers: [ProviderConfiguration] = Self.defaultProviderConfigurations
    ) {
        self.maxResponseSentences = max(1, min(10, maxResponseSentences))
        self.transcriptionBackend = transcriptionBackend
        self.transcriptionModel = transcriptionModel
        self.llmProvider = llmProvider
        self.llmModel = llmModel
        self.hudRenderPath = hudRenderPath
        self.autoDetectQuestions = autoDetectQuestions
        self.autoAnswer = autoAnswer
        self.webSearchMode = webSearchMode
        self.liveFactCheckEnabled = liveFactCheckEnabled
        self.evalGateEnabled = evalGateEnabled
        self.providers = providers
    }

    public var activeProviderConfiguration: ProviderConfiguration? {
        providers.first { $0.kind == llmProvider }
    }

    public static let defaultProviderConfigurations: [ProviderConfiguration] = [
        ProviderConfiguration(
            kind: .openAI,
            displayName: "OpenAI",
            modelSelection: ProviderModelSelection(
                smartModel: "gpt-4.1",
                lightModel: "gpt-4.1-mini",
                realtimeModel: "gpt-4o-mini-realtime",
                transcriptionModel: "gpt-4o-mini-transcribe"
            ),
            apiKeySecretName: "openai_api_key"
        ),
        ProviderConfiguration(
            kind: .anthropic,
            displayName: "Anthropic",
            modelSelection: ProviderModelSelection(smartModel: "claude-sonnet-4", lightModel: "claude-haiku-4"),
            apiKeySecretName: "anthropic_api_key"
        ),
        ProviderConfiguration(
            kind: .deepSeek,
            displayName: "DeepSeek",
            modelSelection: ProviderModelSelection(smartModel: "deepseek-chat", lightModel: "deepseek-chat"),
            apiKeySecretName: "deepseek_api_key"
        ),
        ProviderConfiguration(
            kind: .qwen,
            displayName: "Qwen",
            modelSelection: ProviderModelSelection(smartModel: "qwen-plus", lightModel: "qwen-turbo"),
            apiKeySecretName: "qwen_api_key"
        ),
        ProviderConfiguration(
            kind: .zhipu,
            displayName: "Zhipu",
            modelSelection: ProviderModelSelection(smartModel: "glm-4", lightModel: "glm-4-flash"),
            apiKeySecretName: "zhipu_api_key"
        )
    ]
}

public struct TranscriptSegment: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public var text: String
    public var isFinal: Bool
    public var startedAt: Date
    public var finalizedAt: Date?

    public init(
        id: UUID = UUID(),
        text: String,
        isFinal: Bool,
        startedAt: Date = Date(),
        finalizedAt: Date? = nil
    ) {
        self.id = id
        self.text = text
        self.isFinal = isFinal
        self.startedAt = startedAt
        self.finalizedAt = finalizedAt
    }
}

public struct QuestionCandidate: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public var text: String
    public var confidence: Double

    public init(id: UUID = UUID(), text: String, confidence: Double) {
        self.id = id
        self.text = text
        self.confidence = confidence
    }
}

public struct AnswerRequest: Codable, Equatable, Sendable {
    public var question: String
    public var mode: ConversationMode
    public var requiredFacts: [String]
    public var projectContext: [String]
    public var webSearchResults: [WebSearchResult]

    public init(
        question: String,
        mode: ConversationMode = .general,
        requiredFacts: [String] = [],
        projectContext: [String] = [],
        webSearchResults: [WebSearchResult] = []
    ) {
        self.question = question
        self.mode = mode
        self.requiredFacts = requiredFacts
        self.projectContext = projectContext
        self.webSearchResults = webSearchResults
    }

    public var citationSources: [String] {
        var sources: [String] = []
        if !projectContext.isEmpty {
            sources.append("project-context")
        }
        if !webSearchResults.isEmpty {
            sources.append("web-search")
        }
        return sources
    }
}

public struct WebSearchResult: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public var title: String
    public var snippet: String
    public var url: URL?

    public init(id: UUID = UUID(), title: String, snippet: String, url: URL? = nil) {
        self.id = id
        self.title = title
        self.snippet = snippet
        self.url = url
    }
}

public struct AnswerResponse: Codable, Equatable, Sendable {
    public var text: String
    public var provider: LlmProviderKind
    public var model: String
    public var citations: [String]

    public init(text: String, provider: LlmProviderKind, model: String, citations: [String] = []) {
        self.text = text
        self.provider = provider
        self.model = model
        self.citations = citations
    }
}

public struct PassiveReminder: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public var claim: String
    public var reminder: String
    public var latencyMs: Int

    public init(id: UUID = UUID(), claim: String, reminder: String, latencyMs: Int) {
        self.id = id
        self.claim = claim
        self.reminder = reminder
        self.latencyMs = latencyMs
    }
}

public struct NativeSessionSummary: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public var title: String
    public var mode: ConversationMode
    public var startedAt: Date
    public var endedAt: Date?
    public var transcriptPreview: String
    public var answerPreview: String
    public var projectName: String?
    public var totalCostMicros: Int
    public var segmentCount: Int
    public var answerCount: Int

    public init(
        id: UUID = UUID(),
        title: String,
        mode: ConversationMode,
        startedAt: Date = Date(),
        endedAt: Date? = nil,
        transcriptPreview: String = "",
        answerPreview: String = "",
        projectName: String? = nil,
        totalCostMicros: Int = 0,
        segmentCount: Int = 0,
        answerCount: Int = 0
    ) {
        self.id = id
        self.title = title
        self.mode = mode
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.transcriptPreview = transcriptPreview
        self.answerPreview = answerPreview
        self.projectName = projectName
        self.totalCostMicros = totalCostMicros
        self.segmentCount = segmentCount
        self.answerCount = answerCount
    }
}

public struct NativeKnowledgeProject: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public var name: String
    public var summary: String
    public var isActive: Bool
    public var documentCount: Int
    public var factCount: Int
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        name: String,
        summary: String = "",
        isActive: Bool = false,
        documentCount: Int = 0,
        factCount: Int = 0,
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.summary = summary
        self.isActive = isActive
        self.documentCount = documentCount
        self.factCount = factCount
        self.updatedAt = updatedAt
    }
}

public struct NativeKnowledgeItem: Codable, Equatable, Identifiable, Sendable {
    public enum Kind: String, Codable, Sendable {
        case fact
        case memory
        case todo
    }

    public let id: UUID
    public var kind: Kind
    public var text: String
    public var source: String
    public var isComplete: Bool
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        kind: Kind,
        text: String,
        source: String = "",
        isComplete: Bool = false,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.kind = kind
        self.text = text
        self.source = source
        self.isComplete = isComplete
        self.createdAt = createdAt
    }
}

public struct NativeKnowledgeDocument: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public var projectID: UUID?
    public var title: String
    public var sourceURL: URL?
    public var importedAt: Date
    public var chunkCount: Int
    public var preview: String

    public init(
        id: UUID = UUID(),
        projectID: UUID? = nil,
        title: String,
        sourceURL: URL? = nil,
        importedAt: Date = Date(),
        chunkCount: Int = 0,
        preview: String = ""
    ) {
        self.id = id
        self.projectID = projectID
        self.title = title
        self.sourceURL = sourceURL
        self.importedAt = importedAt
        self.chunkCount = chunkCount
        self.preview = preview
    }
}

public struct NativeKnowledgeSnapshot: Codable, Equatable, Sendable {
    public var projects: [NativeKnowledgeProject]
    public var documents: [NativeKnowledgeDocument]
    public var facts: [NativeKnowledgeItem]
    public var memories: [NativeKnowledgeItem]
    public var todos: [NativeKnowledgeItem]

    public init(
        projects: [NativeKnowledgeProject] = [],
        documents: [NativeKnowledgeDocument] = [],
        facts: [NativeKnowledgeItem] = [],
        memories: [NativeKnowledgeItem] = [],
        todos: [NativeKnowledgeItem] = []
    ) {
        self.projects = projects
        self.documents = documents
        self.facts = facts
        self.memories = memories
        self.todos = todos
    }

    public var activeProject: NativeKnowledgeProject? {
        projects.first { $0.isActive }
    }

    public var openTodoCount: Int {
        todos.filter { !$0.isComplete }.count
    }
}

public enum HelixError: Error, LocalizedError, Equatable, Sendable {
    case missingApiKey(String)
    case timeout(String)
    case unsupportedBackend(String)
    case invalidInput(String)
    case providerFailure(String)

    public var errorDescription: String? {
        switch self {
        case .missingApiKey(let provider):
            return "Missing API key for \(provider)."
        case .timeout(let stage):
            return "Timed out during \(stage)."
        case .unsupportedBackend(let backend):
            return "Unsupported backend: \(backend)."
        case .invalidInput(let reason):
            return "Invalid input: \(reason)."
        case .providerFailure(let reason):
            return "Provider failed: \(reason)."
        }
    }
}
