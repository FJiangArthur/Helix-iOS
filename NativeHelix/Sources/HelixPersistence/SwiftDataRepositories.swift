import Foundation
import HelixCore
import SwiftData

public actor SwiftDataSessionArchiveStore: SessionArchiveStore {
    private let container: ModelContainer

    public init(container: ModelContainer) {
        self.container = container
    }

    public func saveSession(_ session: NativeSessionSummary) async {
        do {
            let context = ModelContext(container)
            let record = try conversationRecord(id: session.id, context: context) ?? ConversationRecord(
                id: session.id,
                title: session.title,
                mode: session.mode,
                startedAt: session.startedAt
            )
            if record.modelContext == nil {
                context.insert(record)
            }

            record.title = session.title
            record.modeRawValue = session.mode.rawValue
            record.startedAt = session.startedAt
            record.endedAt = session.endedAt
            record.totalCostMicros = session.totalCostMicros
            record.projectID = try projectID(for: session.projectName, context: context)

            replaceSegments(on: record, preview: session.transcriptPreview, count: session.segmentCount, context: context)
            replaceAnswers(on: record, preview: session.answerPreview, count: session.answerCount, context: context)

            try context.save()
        } catch {
            assertionFailure("SwiftDataSessionArchiveStore failed to save session: \(error)")
        }
    }

    public func sessions() async -> [NativeSessionSummary] {
        do {
            let context = ModelContext(container)
            let conversations = try context.fetch(
                FetchDescriptor<ConversationRecord>(
                    sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
                )
            )
            let projects = try context.fetch(FetchDescriptor<ProjectRecord>())
            let projectNamesByID = Dictionary(uniqueKeysWithValues: projects.map { ($0.id, $0.name) })

            return conversations.map { record in
                let segments = record.segments.sorted { $0.startedAt < $1.startedAt }
                let answers = record.answers.sorted { $0.createdAt < $1.createdAt }
                return NativeSessionSummary(
                    id: record.id,
                    title: record.title,
                    mode: record.mode,
                    startedAt: record.startedAt,
                    endedAt: record.endedAt,
                    transcriptPreview: segments.first?.text ?? "",
                    answerPreview: answers.first?.answer ?? "",
                    projectName: record.projectID.flatMap { projectNamesByID[$0] },
                    totalCostMicros: record.totalCostMicros,
                    segmentCount: segments.count,
                    answerCount: answers.count
                )
            }
        } catch {
            assertionFailure("SwiftDataSessionArchiveStore failed to fetch sessions: \(error)")
            return []
        }
    }

    private func conversationRecord(id: UUID, context: ModelContext) throws -> ConversationRecord? {
        let descriptor = FetchDescriptor<ConversationRecord>(
            predicate: #Predicate { $0.id == id }
        )
        return try context.fetch(descriptor).first
    }

    private func projectID(for projectName: String?, context: ModelContext) throws -> UUID? {
        let trimmed = projectName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmed.isEmpty else { return nil }

        let projects = try context.fetch(FetchDescriptor<ProjectRecord>())
        if let existing = projects.first(where: { $0.name == trimmed }) {
            existing.updatedAt = Date()
            return existing.id
        }

        let project = ProjectRecord(name: trimmed, summary: "Session archive project", isActive: false)
        context.insert(project)
        return project.id
    }

    private func replaceSegments(
        on record: ConversationRecord,
        preview: String,
        count: Int,
        context: ModelContext
    ) {
        record.segments.forEach { context.delete($0) }
        record.segments.removeAll()

        let trimmed = preview.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let storedCount = max(1, count)
        for index in 0..<storedCount {
            let text = index == 0 ? trimmed : "Additional transcript segment \(index + 1)"
            let segment = TranscriptSegmentRecord(
                text: text,
                isFinal: true,
                startedAt: record.startedAt.addingTimeInterval(Double(index)),
                finalizedAt: record.startedAt.addingTimeInterval(Double(index + 1)),
                conversation: record
            )
            context.insert(segment)
            record.segments.append(segment)
        }
    }

    private func replaceAnswers(
        on record: ConversationRecord,
        preview: String,
        count: Int,
        context: ModelContext
    ) {
        record.answers.forEach { context.delete($0) }
        record.answers.removeAll()

        let trimmed = preview.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let storedCount = max(1, count)
        for index in 0..<storedCount {
            let answer = AnswerRecord(
                question: index == 0 ? record.title : "Follow-up \(index + 1)",
                answer: index == 0 ? trimmed : "Additional answer \(index + 1)",
                provider: .openAI,
                model: "native-archive",
                createdAt: record.startedAt.addingTimeInterval(Double(index + 1)),
                conversation: record
            )
            context.insert(answer)
            record.answers.append(answer)
        }
    }
}

public actor SwiftDataKnowledgeLibraryStore: KnowledgeLibraryStore, ProjectKnowledgeStore {
    private let container: ModelContainer
    private let chunker: NativeDocumentChunker

    public init(container: ModelContainer, chunker: NativeDocumentChunker = NativeDocumentChunker()) {
        self.container = container
        self.chunker = chunker
    }

    public func snapshot() async -> NativeKnowledgeSnapshot {
        do {
            let context = ModelContext(container)
            let projects = try context.fetch(
                FetchDescriptor<ProjectRecord>(
                    sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
                )
            )
            let facts = try context.fetch(
                FetchDescriptor<FactRecord>(
                    sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
                )
            )
            let memories = try context.fetch(
                FetchDescriptor<MemoryRecord>(
                    sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
                )
            )
            let todos = try context.fetch(
                FetchDescriptor<TodoRecord>(
                    sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
                )
            )
            let documents = try context.fetch(
                FetchDescriptor<KnowledgeDocumentRecord>(
                    sortBy: [SortDescriptor(\.importedAt, order: .reverse)]
                )
            )

            let nativeProjects = projects.map { project in
                NativeKnowledgeProject(
                    id: project.id,
                    name: project.name,
                    summary: project.summary,
                    isActive: project.isActive,
                    documentCount: project.documents.count,
                    factCount: facts.filter { $0.projectID == project.id }.count,
                    updatedAt: project.updatedAt
                )
            }

            let nativeTodos = todos
                .map(Self.nativeItem)
                .sorted { lhs, rhs in
                    if lhs.isComplete != rhs.isComplete {
                        return !lhs.isComplete
                    }
                    return lhs.createdAt > rhs.createdAt
                }

            return NativeKnowledgeSnapshot(
                projects: nativeProjects,
                documents: documents.map(Self.nativeDocument),
                facts: facts.map(Self.nativeItem),
                memories: memories.map(Self.nativeItem),
                todos: nativeTodos
            )
        } catch {
            assertionFailure("SwiftDataKnowledgeLibraryStore failed to fetch snapshot: \(error)")
            return NativeKnowledgeSnapshot()
        }
    }

    public func saveProject(_ project: NativeKnowledgeProject) async {
        do {
            let context = ModelContext(container)
            if project.isActive {
                let allProjects = try context.fetch(FetchDescriptor<ProjectRecord>())
                allProjects.forEach { $0.isActive = false }
            }

            let record = try projectRecord(id: project.id, context: context) ?? ProjectRecord(
                id: project.id,
                name: project.name,
                summary: project.summary,
                isActive: project.isActive,
                updatedAt: project.updatedAt
            )
            if record.modelContext == nil {
                context.insert(record)
            }
            record.name = project.name.trimmingCharacters(in: .whitespacesAndNewlines)
            record.summary = project.summary.trimmingCharacters(in: .whitespacesAndNewlines)
            record.isActive = project.isActive
            record.updatedAt = Date()

            try context.save()
        } catch {
            assertionFailure("SwiftDataKnowledgeLibraryStore failed to save project: \(error)")
        }
    }

    public func setActiveProject(id: UUID?) async {
        do {
            let context = ModelContext(container)
            let projects = try context.fetch(FetchDescriptor<ProjectRecord>())
            for project in projects {
                project.isActive = project.id == id
                if project.isActive {
                    project.updatedAt = Date()
                }
            }
            try context.save()
        } catch {
            assertionFailure("SwiftDataKnowledgeLibraryStore failed to set active project: \(error)")
        }
    }

    public func addFact(_ text: String, source: String) async {
        guard let trimmed = Self.trimmedNonEmpty(text) else { return }
        do {
            let context = ModelContext(container)
            let activeProjectID = try activeProjectID(context: context)
            context.insert(
                FactRecord(
                    text: trimmed,
                    source: source.trimmingCharacters(in: .whitespacesAndNewlines),
                    projectID: activeProjectID
                )
            )
            try touchActiveProject(context: context)
            try context.save()
        } catch {
            assertionFailure("SwiftDataKnowledgeLibraryStore failed to add fact: \(error)")
        }
    }

    public func ingestDocument(title: String, text: String, sourceURL: URL?) async {
        guard let trimmedTitle = Self.trimmedNonEmpty(title) else { return }
        let chunks = chunker.chunks(from: text)
        guard !chunks.isEmpty else { return }

        do {
            let context = ModelContext(container)
            let project = try activeProject(context: context) ?? createInboxProject(context: context)
            let document = KnowledgeDocumentRecord(
                title: trimmedTitle,
                sourceURL: sourceURL,
                project: project
            )
            context.insert(document)
            project.documents.append(document)

            for (index, chunkText) in chunks.enumerated() {
                let chunk = DocumentChunkRecord(
                    ordinal: index,
                    text: chunkText,
                    tokenCount: Self.approximateTokenCount(chunkText),
                    embeddingModel: "native-keyword-v1",
                    document: document
                )
                context.insert(chunk)
                document.chunks.append(chunk)
            }
            project.updatedAt = Date()
            try context.save()
        } catch {
            assertionFailure("SwiftDataKnowledgeLibraryStore failed to ingest document: \(error)")
        }
    }

    public func addMemory(_ text: String, source: String) async {
        guard let trimmed = Self.trimmedNonEmpty(text) else { return }
        do {
            let context = ModelContext(container)
            let activeProjectID = try activeProjectID(context: context)
            let sourceTag = source.trimmingCharacters(in: .whitespacesAndNewlines)
            context.insert(
                MemoryRecord(
                    text: trimmed,
                    tags: sourceTag.isEmpty ? [] : [sourceTag],
                    projectID: activeProjectID
                )
            )
            try context.save()
        } catch {
            assertionFailure("SwiftDataKnowledgeLibraryStore failed to add memory: \(error)")
        }
    }

    public func addTodo(_ title: String) async {
        guard let trimmed = Self.trimmedNonEmpty(title) else { return }
        do {
            let context = ModelContext(container)
            let activeProjectID = try activeProjectID(context: context)
            context.insert(TodoRecord(title: trimmed, projectID: activeProjectID))
            try context.save()
        } catch {
            assertionFailure("SwiftDataKnowledgeLibraryStore failed to add todo: \(error)")
        }
    }

    public func completeTodo(id: UUID, isComplete: Bool) async {
        do {
            let context = ModelContext(container)
            let descriptor = FetchDescriptor<TodoRecord>(
                predicate: #Predicate { $0.id == id }
            )
            guard let todo = try context.fetch(descriptor).first else { return }
            todo.isComplete = isComplete
            try context.save()
        } catch {
            assertionFailure("SwiftDataKnowledgeLibraryStore failed to complete todo: \(error)")
        }
    }

    public func seed(projectID: String, facts: [String]) async {
        do {
            let context = ModelContext(container)
            let project = try projectRecord(for: projectID, context: context) ?? ProjectRecord(
                id: UUID(uuidString: projectID) ?? UUID(),
                name: projectID,
                summary: "Seeded project context",
                isActive: false
            )
            if project.modelContext == nil {
                context.insert(project)
            }

            for fact in facts {
                guard let trimmed = Self.trimmedNonEmpty(fact) else { continue }
                context.insert(FactRecord(text: trimmed, source: "Seed", projectID: project.id))
            }
            project.updatedAt = Date()
            try context.save()
        } catch {
            assertionFailure("SwiftDataKnowledgeLibraryStore failed to seed project facts: \(error)")
        }
    }

    public func facts(for projectID: String, question: String) async -> [String] {
        do {
            let context = ModelContext(container)
            guard let project = try projectRecord(for: projectID, context: context) else {
                return []
            }
            let facts = try context.fetch(FetchDescriptor<FactRecord>())
            let normalizedQuestion = Self.normalized(question)
            let projectFacts = facts
                .filter { $0.projectID == project.id }
                .sorted { $0.createdAt > $1.createdAt }
                .map(\.text)
            let projectChunks = project.documents
                .flatMap(\.chunks)
                .sorted { $0.ordinal < $1.ordinal }
                .map(\.text)
            let combined = projectFacts + projectChunks

            guard !normalizedQuestion.isEmpty else {
                return combined
            }

            let ranked = combined.sorted { lhs, rhs in
                Self.matchScore(text: lhs, normalizedQuestion: normalizedQuestion) >
                    Self.matchScore(text: rhs, normalizedQuestion: normalizedQuestion)
            }
            return ranked
        } catch {
            assertionFailure("SwiftDataKnowledgeLibraryStore failed to fetch project facts: \(error)")
            return []
        }
    }

    private func projectRecord(id: UUID, context: ModelContext) throws -> ProjectRecord? {
        let descriptor = FetchDescriptor<ProjectRecord>(
            predicate: #Predicate { $0.id == id }
        )
        return try context.fetch(descriptor).first
    }

    private func projectRecord(for identifier: String, context: ModelContext) throws -> ProjectRecord? {
        let trimmed = identifier.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let projects = try context.fetch(FetchDescriptor<ProjectRecord>())
        if let uuid = UUID(uuidString: trimmed), let project = projects.first(where: { $0.id == uuid }) {
            return project
        }
        return projects.first { $0.name.caseInsensitiveCompare(trimmed) == .orderedSame }
    }

    private func activeProjectID(context: ModelContext) throws -> UUID? {
        try context.fetch(FetchDescriptor<ProjectRecord>()).first { $0.isActive }?.id
    }

    private func activeProject(context: ModelContext) throws -> ProjectRecord? {
        try context.fetch(FetchDescriptor<ProjectRecord>()).first { $0.isActive }
    }

    private func createInboxProject(context: ModelContext) throws -> ProjectRecord {
        let project = ProjectRecord(
            name: "Inbox",
            summary: "Imported native knowledge documents.",
            isActive: true
        )
        let projects = try context.fetch(FetchDescriptor<ProjectRecord>())
        projects.forEach { $0.isActive = false }
        context.insert(project)
        return project
    }

    private func touchActiveProject(context: ModelContext) throws {
        guard let project = try context.fetch(FetchDescriptor<ProjectRecord>()).first(where: { $0.isActive }) else {
            return
        }
        project.updatedAt = Date()
    }

    private static func trimmedNonEmpty(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
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

    private static func approximateTokenCount(_ text: String) -> Int {
        max(1, Int(ceil(Double(text.count) / 4.0)))
    }

    private static func nativeDocument(_ record: KnowledgeDocumentRecord) -> NativeKnowledgeDocument {
        let chunks = record.chunks.sorted { $0.ordinal < $1.ordinal }
        return NativeKnowledgeDocument(
            id: record.id,
            projectID: record.project?.id,
            title: record.title,
            sourceURL: record.sourceURL,
            importedAt: record.importedAt,
            chunkCount: chunks.count,
            preview: chunks.first.map { String($0.text.prefix(160)) } ?? ""
        )
    }

    private static func nativeItem(_ record: FactRecord) -> NativeKnowledgeItem {
        NativeKnowledgeItem(
            id: record.id,
            kind: .fact,
            text: record.text,
            source: record.source,
            createdAt: record.createdAt
        )
    }

    private static func nativeItem(_ record: MemoryRecord) -> NativeKnowledgeItem {
        NativeKnowledgeItem(
            id: record.id,
            kind: .memory,
            text: record.text,
            source: record.tags.first ?? "",
            createdAt: record.createdAt
        )
    }

    private static func nativeItem(_ record: TodoRecord) -> NativeKnowledgeItem {
        NativeKnowledgeItem(
            id: record.id,
            kind: .todo,
            text: record.title,
            isComplete: record.isComplete,
            createdAt: record.createdAt
        )
    }
}
