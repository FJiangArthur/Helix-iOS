import Foundation
import HelixCore

public protocol ConversationStore: Sendable {
    func save(segment: TranscriptSegment) async
    func save(answer: AnswerResponse, for question: QuestionCandidate) async
    func transcript() async -> [TranscriptSegment]
}

public actor InMemoryConversationStore: ConversationStore {
    private var segments: [TranscriptSegment] = []
    private var answers: [(QuestionCandidate, AnswerResponse)] = []

    public init() {}

    public func save(segment: TranscriptSegment) async {
        segments.append(segment)
    }

    public func save(answer: AnswerResponse, for question: QuestionCandidate) async {
        answers.append((question, answer))
    }

    public func transcript() async -> [TranscriptSegment] {
        segments
    }
}

public protocol ProjectKnowledgeStore: Sendable {
    func seed(projectID: String, facts: [String]) async
    func facts(for projectID: String, question: String) async -> [String]
}

public actor InMemoryProjectKnowledgeStore: ProjectKnowledgeStore {
    private var factsByProjectID: [String: [String]] = [:]

    public init() {}

    public func seed(projectID: String, facts: [String]) async {
        factsByProjectID[projectID] = facts
    }

    public func facts(for projectID: String, question: String) async -> [String] {
        factsByProjectID[projectID] ?? []
    }
}

public protocol SessionArchiveStore: Sendable {
    func saveSession(_ session: NativeSessionSummary) async
    func sessions() async -> [NativeSessionSummary]
}

public actor InMemorySessionArchiveStore: SessionArchiveStore {
    private var archivedSessions: [NativeSessionSummary]

    public init(sessions: [NativeSessionSummary] = []) {
        self.archivedSessions = sessions
    }

    public func saveSession(_ session: NativeSessionSummary) async {
        if let index = archivedSessions.firstIndex(where: { $0.id == session.id }) {
            archivedSessions[index] = session
        } else {
            archivedSessions.append(session)
        }
        archivedSessions.sort { $0.startedAt > $1.startedAt }
    }

    public func sessions() async -> [NativeSessionSummary] {
        archivedSessions.sorted { $0.startedAt > $1.startedAt }
    }
}

public protocol KnowledgeLibraryStore: Sendable {
    func snapshot() async -> NativeKnowledgeSnapshot
    func saveProject(_ project: NativeKnowledgeProject) async
    func setActiveProject(id: UUID?) async
    func ingestDocument(title: String, text: String, sourceURL: URL?) async
    func addFact(_ text: String, source: String) async
    func addMemory(_ text: String, source: String) async
    func addTodo(_ title: String) async
    func completeTodo(id: UUID, isComplete: Bool) async
}

public actor InMemoryKnowledgeLibraryStore: KnowledgeLibraryStore, ProjectKnowledgeStore {
    private var projects: [NativeKnowledgeProject]
    private var documents: [NativeKnowledgeDocument]
    private var documentChunksByProjectID: [UUID: [String]]
    private var facts: [NativeKnowledgeItem]
    private var memories: [NativeKnowledgeItem]
    private var todos: [NativeKnowledgeItem]
    private let chunker: NativeDocumentChunker

    public init(
        projects: [NativeKnowledgeProject] = [],
        documents: [NativeKnowledgeDocument] = [],
        documentChunksByProjectID: [UUID: [String]] = [:],
        facts: [NativeKnowledgeItem] = [],
        memories: [NativeKnowledgeItem] = [],
        todos: [NativeKnowledgeItem] = [],
        chunker: NativeDocumentChunker = NativeDocumentChunker()
    ) {
        self.projects = projects
        self.documents = documents
        self.documentChunksByProjectID = documentChunksByProjectID
        self.facts = facts
        self.memories = memories
        self.todos = todos
        self.chunker = chunker
    }

    public func snapshot() async -> NativeKnowledgeSnapshot {
        NativeKnowledgeSnapshot(
            projects: projects.sorted { $0.updatedAt > $1.updatedAt },
            documents: documents.sorted { $0.importedAt > $1.importedAt },
            facts: facts.sorted { $0.createdAt > $1.createdAt },
            memories: memories.sorted { $0.createdAt > $1.createdAt },
            todos: todos.sorted { lhs, rhs in
                if lhs.isComplete != rhs.isComplete {
                    return !lhs.isComplete
                }
                return lhs.createdAt > rhs.createdAt
            }
        )
    }

    public func saveProject(_ project: NativeKnowledgeProject) async {
        var updated = project
        updated.updatedAt = Date()
        if updated.isActive {
            projects = projects.map { existing in
                var inactive = existing
                inactive.isActive = false
                return inactive
            }
        }
        if let index = projects.firstIndex(where: { $0.id == updated.id }) {
            projects[index] = updated
        } else {
            projects.append(updated)
        }
    }

    public func setActiveProject(id: UUID?) async {
        projects = projects.map { project in
            var updated = project
            updated.isActive = project.id == id
            updated.updatedAt = updated.isActive ? Date() : project.updatedAt
            return updated
        }
    }

    public func ingestDocument(title: String, text: String, sourceURL: URL?) async {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let chunks = chunker.chunks(from: text)
        guard !trimmedTitle.isEmpty, !chunks.isEmpty else { return }

        let activeProjectID = await ensureActiveProjectID()
        let preview = chunks.first.map { String($0.prefix(160)) } ?? ""
        documents.append(
            NativeKnowledgeDocument(
                projectID: activeProjectID,
                title: trimmedTitle,
                sourceURL: sourceURL,
                chunkCount: chunks.count,
                preview: preview
            )
        )
        documentChunksByProjectID[activeProjectID, default: []].append(contentsOf: chunks)
        if let index = projects.firstIndex(where: { $0.id == activeProjectID }) {
            projects[index].documentCount += 1
            projects[index].updatedAt = Date()
        }
    }

    public func addFact(_ text: String, source: String) async {
        guard let item = Self.makeItem(kind: .fact, text: text, source: source) else { return }
        facts.append(item)
        incrementActiveProjectFactCount()
    }

    public func addMemory(_ text: String, source: String) async {
        guard let item = Self.makeItem(kind: .memory, text: text, source: source) else { return }
        memories.append(item)
    }

    public func addTodo(_ title: String) async {
        guard let item = Self.makeItem(kind: .todo, text: title, source: "") else { return }
        todos.append(item)
    }

    public func completeTodo(id: UUID, isComplete: Bool) async {
        guard let index = todos.firstIndex(where: { $0.id == id }) else { return }
        todos[index].isComplete = isComplete
    }

    public func seed(projectID: String, facts: [String]) async {
        let projectUUID = UUID(uuidString: projectID) ?? UUID()
        if !projects.contains(where: { $0.id == projectUUID || $0.name == projectID }) {
            projects.append(
                NativeKnowledgeProject(
                    id: projectUUID,
                    name: projectID,
                    summary: "Seeded project context"
                )
            )
        }
        let project = projects.first { $0.id == projectUUID || $0.name == projectID }
        for fact in facts {
            guard let item = Self.makeItem(kind: .fact, text: fact, source: "Seed") else { continue }
            self.facts.append(item)
        }
        if let projectID = project?.id, let index = projects.firstIndex(where: { $0.id == projectID }) {
            projects[index].factCount += facts.count
            projects[index].updatedAt = Date()
        }
    }

    public func facts(for projectID: String, question: String) async -> [String] {
        guard let project = project(for: projectID) else { return [] }
        let normalizedQuestion = Self.normalized(question)
        let factTexts = facts.map(\.text)
        let chunkTexts = documentChunksByProjectID[project.id] ?? []
        let combined = factTexts + chunkTexts
        guard !normalizedQuestion.isEmpty else { return combined }
        return combined.sorted { lhs, rhs in
            Self.matchScore(text: lhs, normalizedQuestion: normalizedQuestion) >
                Self.matchScore(text: rhs, normalizedQuestion: normalizedQuestion)
        }
    }

    private static func makeItem(kind: NativeKnowledgeItem.Kind, text: String, source: String) -> NativeKnowledgeItem? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return NativeKnowledgeItem(
            kind: kind,
            text: trimmed,
            source: source.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    private func incrementActiveProjectFactCount() {
        guard let index = projects.firstIndex(where: { $0.isActive }) else { return }
        projects[index].factCount += 1
        projects[index].updatedAt = Date()
    }

    private func ensureActiveProjectID() async -> UUID {
        if let active = projects.first(where: { $0.isActive }) {
            return active.id
        }
        let project = NativeKnowledgeProject(
            name: "Inbox",
            summary: "Imported native knowledge documents.",
            isActive: true
        )
        projects.append(project)
        return project.id
    }

    private func project(for identifier: String) -> NativeKnowledgeProject? {
        let trimmed = identifier.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if let uuid = UUID(uuidString: trimmed), let project = projects.first(where: { $0.id == uuid }) {
            return project
        }
        return projects.first { $0.name.caseInsensitiveCompare(trimmed) == .orderedSame }
    }

    private static func normalized(_ value: String) -> String {
        value
            .lowercased()
            .replacingOccurrences(of: "[^a-z0-9 ]", with: " ", options: .regularExpression)
            .split(separator: " ")
            .joined(separator: " ")
    }

    private static func matchScore(text: String, normalizedQuestion: String) -> Int {
        let questionTerms = Set(normalizedQuestion.split(separator: " ").map(String.init))
        guard !questionTerms.isEmpty else { return 0 }
        let textTerms = Set(normalized(text).split(separator: " ").map(String.init))
        return questionTerms.intersection(textTerms).count
    }
}

public protocol SettingsStore: Sendable {
    func loadSettings() async -> HelixSettings
    func saveSettings(_ settings: HelixSettings) async
    func updateSettings(_ transform: @Sendable (HelixSettings) -> HelixSettings) async -> HelixSettings
}

public actor InMemorySettingsStore: SettingsStore {
    private var settings: HelixSettings

    public init(settings: HelixSettings = HelixSettings()) {
        self.settings = settings
    }

    public func loadSettings() async -> HelixSettings {
        settings
    }

    public func saveSettings(_ settings: HelixSettings) async {
        self.settings = settings
    }

    public func updateSettings(_ transform: @Sendable (HelixSettings) -> HelixSettings) async -> HelixSettings {
        let updated = transform(settings)
        settings = updated
        return updated
    }
}

public protocol SecretStore: Sendable {
    func setSecret(_ value: String?, named name: String) async
    func secret(named name: String) async -> String?
    func hasSecret(named name: String) async -> Bool
    func clearSecret(named name: String) async
}

public actor InMemorySecretStore: SecretStore {
    private var secrets: [String: String] = [:]

    public init() {}

    public func setSecret(_ value: String?, named name: String) async {
        let normalizedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedName.isEmpty else { return }

        let normalizedValue = value?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let normalizedValue, !normalizedValue.isEmpty {
            secrets[normalizedName] = normalizedValue
        } else {
            secrets.removeValue(forKey: normalizedName)
        }
    }

    public func secret(named name: String) async -> String? {
        secrets[name]
    }

    public func hasSecret(named name: String) async -> Bool {
        secrets[name] != nil
    }

    public func clearSecret(named name: String) async {
        secrets.removeValue(forKey: name)
    }
}

public struct ProviderReadiness: Equatable, Sendable {
    public var provider: LlmProviderKind
    public var isEnabled: Bool
    public var hasApiKey: Bool
    public var smartModel: String
    public var lightModel: String

    public init(
        provider: LlmProviderKind,
        isEnabled: Bool,
        hasApiKey: Bool,
        smartModel: String,
        lightModel: String
    ) {
        self.provider = provider
        self.isEnabled = isEnabled
        self.hasApiKey = hasApiKey
        self.smartModel = smartModel
        self.lightModel = lightModel
    }
}

public actor NativeSettingsManager {
    private let settingsStore: SettingsStore
    private let secretStore: SecretStore

    public init(settingsStore: SettingsStore, secretStore: SecretStore) {
        self.settingsStore = settingsStore
        self.secretStore = secretStore
    }

    public func settings() async -> HelixSettings {
        await settingsStore.loadSettings()
    }

    public func setProviderApiKey(_ apiKey: String?, for provider: LlmProviderKind) async {
        let current = await settingsStore.loadSettings()
        guard let configuration = current.providers.first(where: { $0.kind == provider }) else { return }
        await secretStore.setSecret(apiKey, named: configuration.apiKeySecretName)
    }

    public func apiKey(for provider: LlmProviderKind) async -> String? {
        let current = await settingsStore.loadSettings()
        guard let configuration = current.providers.first(where: { $0.kind == provider }) else { return nil }
        return await secretStore.secret(named: configuration.apiKeySecretName)
    }

    public func selectProvider(_ provider: LlmProviderKind) async -> HelixSettings {
        await settingsStore.updateSettings { settings in
            var updated = settings
            guard let configuration = updated.providers.first(where: { $0.kind == provider && $0.isEnabled }) else {
                return settings
            }
            updated.llmProvider = provider
            updated.llmModel = configuration.modelSelection.smartModel
            if let transcriptionModel = configuration.modelSelection.transcriptionModel {
                updated.transcriptionModel = transcriptionModel
            }
            return updated
        }
    }

    public func updateProviderModels(
        provider: LlmProviderKind,
        smartModel: String,
        lightModel: String,
        realtimeModel: String? = nil,
        transcriptionModel: String? = nil
    ) async -> HelixSettings {
        await settingsStore.updateSettings { settings in
            var updated = settings
            guard let index = updated.providers.firstIndex(where: { $0.kind == provider }) else {
                return settings
            }
            updated.providers[index].modelSelection = ProviderModelSelection(
                smartModel: smartModel,
                lightModel: lightModel,
                realtimeModel: realtimeModel,
                transcriptionModel: transcriptionModel
            )
            if updated.llmProvider == provider {
                updated.llmModel = smartModel
                if let transcriptionModel {
                    updated.transcriptionModel = transcriptionModel
                }
            }
            return updated
        }
    }

    public func updateConversationControls(
        maxResponseSentences: Int? = nil,
        autoDetectQuestions: Bool? = nil,
        autoAnswer: Bool? = nil,
        liveFactCheckEnabled: Bool? = nil
    ) async -> HelixSettings {
        await settingsStore.updateSettings { settings in
            HelixSettings(
                maxResponseSentences: maxResponseSentences ?? settings.maxResponseSentences,
                transcriptionBackend: settings.transcriptionBackend,
                transcriptionModel: settings.transcriptionModel,
                llmProvider: settings.llmProvider,
                llmModel: settings.llmModel,
                hudRenderPath: settings.hudRenderPath,
                autoDetectQuestions: autoDetectQuestions ?? settings.autoDetectQuestions,
                autoAnswer: autoAnswer ?? settings.autoAnswer,
                webSearchMode: settings.webSearchMode,
                liveFactCheckEnabled: liveFactCheckEnabled ?? settings.liveFactCheckEnabled,
                evalGateEnabled: settings.evalGateEnabled,
                providers: settings.providers
            )
        }
    }

    public func updateTranscription(
        backend: TranscriptionBackend,
        model: String
    ) async -> HelixSettings {
        await settingsStore.updateSettings { settings in
            var updated = settings
            updated.transcriptionBackend = backend
            updated.transcriptionModel = model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? settings.transcriptionModel
                : model.trimmingCharacters(in: .whitespacesAndNewlines)
            return updated
        }
    }

    public func updateHudRenderPath(_ renderPath: HudRenderPath) async -> HelixSettings {
        await settingsStore.updateSettings { settings in
            var updated = settings
            updated.hudRenderPath = renderPath
            return updated
        }
    }

    public func updateWebSearchMode(_ mode: WebSearchMode) async -> HelixSettings {
        await settingsStore.updateSettings { settings in
            var updated = settings
            updated.webSearchMode = mode
            return updated
        }
    }

    public func setEvalGateEnabled(_ isEnabled: Bool) async -> HelixSettings {
        await settingsStore.updateSettings { settings in
            var updated = settings
            updated.evalGateEnabled = isEnabled
            return updated
        }
    }

    public func providerReadiness() async -> [ProviderReadiness] {
        let current = await settingsStore.loadSettings()
        var readiness: [ProviderReadiness] = []
        for configuration in current.providers {
            readiness.append(
                ProviderReadiness(
                    provider: configuration.kind,
                    isEnabled: configuration.isEnabled,
                    hasApiKey: await secretStore.hasSecret(named: configuration.apiKeySecretName),
                    smartModel: configuration.modelSelection.smartModel,
                    lightModel: configuration.modelSelection.lightModel
                )
            )
        }
        return readiness
    }
}
