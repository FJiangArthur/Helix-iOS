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
        if let index = segments.firstIndex(where: { $0.id == segment.id }) {
            segments[index] = segment
        } else {
            segments.append(segment)
        }
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

public struct KnowledgeMemoryUpsertResult: Equatable, Sendable {
    public var item: NativeKnowledgeItem
    public var wasInserted: Bool
    public var previousItem: NativeKnowledgeItem?

    public init(
        item: NativeKnowledgeItem,
        wasInserted: Bool,
        previousItem: NativeKnowledgeItem? = nil
    ) {
        self.item = item
        self.wasInserted = wasInserted
        self.previousItem = previousItem
    }

    public var didMutate: Bool { wasInserted || previousItem != nil }
}

public enum KnowledgeAutomaticAnswerQuality: Int, Equatable, Sendable {
    case fast = 0
    case smart = 1
}

/// Dedupe is an explicit call-site decision. In particular, a note merely
/// looking like `Question:/Answer:` does not prove that it came from Helix's
/// automatic answer capture.
public enum KnowledgeMemoryDeduplication: Equatable, Sendable {
    case exact
    case automaticAnswer(quality: KnowledgeAutomaticAnswerQuality)
}

/// Newly captured automatic answers carry an unambiguous source marker. Old
/// records are intentionally left untouched and are not retroactively treated
/// as automatic, because their provenance cannot be proven.
public enum KnowledgeMemorySource {
    public static let automaticAnswerMarker = "Helix Knowledge · Automatic answer"

    public static func automaticAnswer(
        category: String,
        quality: KnowledgeAutomaticAnswerQuality = .fast
    ) -> String {
        let trimmedCategory = category.trimmingCharacters(in: .whitespacesAndNewlines)
        let qualityMarker = quality == .smart ? "SMART" : "FAST"
        return trimmedCategory.isEmpty
            ? "\(automaticAnswerMarker) · \(qualityMarker)"
            : "\(automaticAnswerMarker) · \(qualityMarker) · \(trimmedCategory)"
    }

    public static func isAutomaticAnswer(_ source: String) -> Bool {
        let trimmedSource = source.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedSource == automaticAnswerMarker
            || trimmedSource.hasPrefix(automaticAnswerMarker + " · ")
    }

    public static func automaticAnswerQuality(
        in source: String
    ) -> KnowledgeAutomaticAnswerQuality? {
        guard isAutomaticAnswer(source) else { return nil }
        let components = source
            .split(separator: "·")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() }
        return components.contains("SMART") ? .smart : .fast
    }
}

public enum KnowledgeMemoryText {
    public static func duplicateKey(
        _ text: String,
        deduplication: KnowledgeMemoryDeduplication = .exact
    ) -> String {
        switch deduplication {
        case .exact:
            return normalized(text)
        case .automaticAnswer:
            let question = automaticAnswerQuestion(in: text)
            let normalizedText = normalized(question ?? text)
            return "automatic-answer:" + normalizedQuestion(normalizedText)
        }
    }

    private static func normalized(_ text: String) -> String {
        text
            .precomposedStringWithCompatibilityMapping
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
    }

    private static func normalizedQuestion(_ text: String) -> String {
        let boundaryNoise = CharacterSet(
            charactersIn: "\"'“”‘’()[]{}«»「」『』（）"
        ).union(.whitespacesAndNewlines)
        let terminalNoise: Set<Character> = [
            ".", "!", "?", "。", "！", "？", "؟",
            "\"", "'", "”", "’", ")", "]", "}", "»", "」", "』", "）"
        ]
        var result = text.trimmingCharacters(in: boundaryNoise)
        while let last = result.last, terminalNoise.contains(last) {
            result.removeLast()
        }
        return result.trimmingCharacters(in: boundaryNoise)
    }

    private static func automaticAnswerQuestion(in text: String) -> String? {
        let pattern = #"(?is)^\s*(?:q|question)\s*:\s*(.*?)\s*\n+\s*(?:a|answer)\s*:"#
        guard let expression = try? NSRegularExpression(pattern: pattern),
              let match = expression.firstMatch(
                  in: text,
                  range: NSRange(text.startIndex..., in: text)
              ),
              match.numberOfRanges > 1,
              let questionRange = Range(match.range(at: 1), in: text) else {
            return nil
        }
        return String(text[questionRange])
    }
}

public protocol KnowledgeLibraryStore: Sendable {
    func snapshot() async -> NativeKnowledgeSnapshot
    func saveProject(_ project: NativeKnowledgeProject) async
    func setActiveProject(id: UUID?) async
    func ingestDocument(title: String, text: String, sourceURL: URL?) async
    func addFact(_ text: String, source: String) async
    func addMemory(_ text: String, source: String) async
    func addMemoryIfAbsent(
        _ text: String,
        source: String,
        deduplication: KnowledgeMemoryDeduplication
    ) async -> KnowledgeMemoryUpsertResult?
    func undoMemoryUpsert(_ result: KnowledgeMemoryUpsertResult) async
    func removeMemory(id: UUID) async
    func addTodo(_ title: String) async
    func completeTodo(id: UUID, isComplete: Bool) async
}

public extension KnowledgeLibraryStore {
    func addMemoryIfAbsent(
        _ text: String,
        source: String
    ) async -> KnowledgeMemoryUpsertResult? {
        await addMemoryIfAbsent(text, source: source, deduplication: .exact)
    }
}

public actor InMemoryKnowledgeLibraryStore: KnowledgeLibraryStore, ProjectKnowledgeStore {
    private var projects: [NativeKnowledgeProject]
    private var documents: [NativeKnowledgeDocument]
    private var documentChunksByProjectID: [UUID: [String]]
    private var facts: [NativeKnowledgeItem]
    private var memories: [NativeKnowledgeItem]
    private var memoryProjectIDByMemoryID: [UUID: UUID]
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
        self.memoryProjectIDByMemoryID = [:]
        self.todos = todos
        self.chunker = chunker
        if let activeProjectID = projects.first(where: { $0.isActive })?.id {
            for memory in memories {
                self.memoryProjectIDByMemoryID[memory.id] = activeProjectID
            }
        }
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
        setMemoryProjectID(activeProjectID, for: item.id)
    }

    public func addMemoryIfAbsent(
        _ text: String,
        source: String,
        deduplication: KnowledgeMemoryDeduplication = .exact
    ) async -> KnowledgeMemoryUpsertResult? {
        guard let item = Self.makeItem(kind: .memory, text: text, source: source) else { return nil }
        let key = KnowledgeMemoryText.duplicateKey(
            item.text,
            deduplication: deduplication
        )
        let scopedProjectID = activeProjectID
        let matchingIndex = memories.firstIndex {
            guard memoryProjectIDByMemoryID[$0.id] == scopedProjectID else {
                return false
            }
            if case .automaticAnswer = deduplication {
                guard KnowledgeMemorySource.isAutomaticAnswer($0.source) else {
                    return false
                }
            }
            return KnowledgeMemoryText.duplicateKey(
                $0.text,
                deduplication: deduplication
            ) == key
        }
        if let matchingIndex {
            let existing = memories[matchingIndex]
            guard case .automaticAnswer(let incomingQuality) = deduplication else {
                return KnowledgeMemoryUpsertResult(item: existing, wasInserted: false)
            }
            let exactKey = KnowledgeMemoryText.duplicateKey(item.text)
            let existingExactKey = KnowledgeMemoryText.duplicateKey(existing.text)
            let existingQuality = KnowledgeMemorySource.automaticAnswerQuality(in: existing.source) ?? .fast
            let exactRepeat = exactKey == existingExactKey
            let shouldUpgradeQuality = incomingQuality.rawValue > existingQuality.rawValue
            let shouldRefreshSameQuality = incomingQuality == existingQuality && !exactRepeat
            guard shouldUpgradeQuality || shouldRefreshSameQuality else {
                return KnowledgeMemoryUpsertResult(item: existing, wasInserted: false)
            }

            let updated = NativeKnowledgeItem(
                id: existing.id,
                kind: existing.kind,
                text: item.text,
                source: item.source,
                isComplete: existing.isComplete,
                createdAt: Date()
            )
            memories[matchingIndex] = updated
            return KnowledgeMemoryUpsertResult(
                item: updated,
                wasInserted: false,
                previousItem: existing
            )
        }
        memories.append(item)
        setMemoryProjectID(scopedProjectID, for: item.id)
        return KnowledgeMemoryUpsertResult(item: item, wasInserted: true)
    }

    public func undoMemoryUpsert(_ result: KnowledgeMemoryUpsertResult) async {
        guard result.didMutate,
              let index = memories.firstIndex(where: { $0.id == result.item.id }) else { return }
        if let previousItem = result.previousItem {
            memories[index] = previousItem
        } else if result.wasInserted {
            memories.remove(at: index)
            memoryProjectIDByMemoryID.removeValue(forKey: result.item.id)
        }
    }

    public func removeMemory(id: UUID) async {
        memories.removeAll { $0.id == id }
        memoryProjectIDByMemoryID.removeValue(forKey: id)
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

    private var activeProjectID: UUID? {
        projects.first(where: { $0.isActive })?.id
    }

    private func setMemoryProjectID(_ projectID: UUID?, for memoryID: UUID) {
        if let projectID {
            memoryProjectIDByMemoryID[memoryID] = projectID
        } else {
            memoryProjectIDByMemoryID.removeValue(forKey: memoryID)
        }
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
            // Preserve existing realtime/transcription selections when the
            // caller only updates the chat (smart/light) models.
            let existing = updated.providers[index].modelSelection
            updated.providers[index].modelSelection = ProviderModelSelection(
                smartModel: smartModel,
                lightModel: lightModel,
                realtimeModel: realtimeModel ?? existing.realtimeModel,
                transcriptionModel: transcriptionModel ?? existing.transcriptionModel
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
        questionDetectionSensitivity: QuestionDetectionSensitivity? = nil,
        autoAnswer: Bool? = nil,
        liveFactCheckEnabled: Bool? = nil
    ) async -> HelixSettings {
        await settingsStore.updateSettings { settings in
            var updated = settings
            if let maxResponseSentences {
                updated.maxResponseSentences = max(1, min(10, maxResponseSentences))
            }
            if let autoDetectQuestions {
                updated.autoDetectQuestions = autoDetectQuestions
            }
            if let questionDetectionSensitivity {
                updated.questionDetectionSensitivity = questionDetectionSensitivity
            }
            if let autoAnswer {
                updated.autoAnswer = autoAnswer
            }
            if let liveFactCheckEnabled {
                updated.liveFactCheckEnabled = liveFactCheckEnabled
            }
            return updated
        }
    }

    public func setInsightsEnabled(_ isEnabled: Bool) async -> HelixSettings {
        await settingsStore.updateSettings { settings in
            var updated = settings
            updated.insightsEnabled = isEnabled
            return updated
        }
    }

    /// Glasses hardware configuration. Values are clamped to firmware ranges
    /// (angle 0–60, height 0–8, depth 0–9, brightness 0–63).
    public func updateGlassesDisplay(
        headUpAngle: Int? = nil,
        displayHeight: Int? = nil,
        displayDepth: Int? = nil,
        brightness: Int? = nil,
        autoBrightness: Bool? = nil,
        glassesNotificationsEnabled: Bool? = nil,
        dashboardEnabled: Bool? = nil
    ) async -> HelixSettings {
        await settingsStore.updateSettings { settings in
            var updated = settings
            if let headUpAngle {
                updated.headUpAngle = max(0, min(60, headUpAngle))
            }
            if let displayHeight {
                updated.displayHeight = max(0, min(8, displayHeight))
            }
            if let displayDepth {
                updated.displayDepth = max(0, min(9, displayDepth))
            }
            if let brightness {
                updated.brightness = max(0, min(63, brightness))
            }
            if let autoBrightness {
                updated.autoBrightness = autoBrightness
            }
            if let glassesNotificationsEnabled {
                updated.glassesNotificationsEnabled = glassesNotificationsEnabled
            }
            if let dashboardEnabled {
                updated.dashboardEnabled = dashboardEnabled
            }
            return updated
        }
    }

    public func updateActiveSkill(_ value: String) async -> HelixSettings {
        await settingsStore.updateSettings { settings in
            var updated = settings
            updated.activeSkillID = ActiveSkill.sanitize(value, customSkills: settings.customSkills)
            return updated
        }
    }

    public func upsertCustomSkill(_ skill: ActiveSkill) async -> HelixSettings {
        await settingsStore.updateSettings { settings in
            let sanitized = ActiveSkill(
                value: skill.value,
                label: skill.label,
                prompt: skill.prompt,
                isBuiltIn: false
            )
            guard !sanitized.value.isEmpty, !sanitized.label.isEmpty, !sanitized.prompt.isEmpty else {
                return settings
            }

            var updated = settings
            if let index = updated.customSkills.firstIndex(where: { $0.value == sanitized.value }) {
                updated.customSkills[index] = sanitized
            } else {
                updated.customSkills.append(sanitized)
            }
            updated.activeSkillID = ActiveSkill.sanitize(updated.activeSkillID, customSkills: updated.customSkills)
            return updated
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
