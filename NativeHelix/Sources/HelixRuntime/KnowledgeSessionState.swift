import Foundation
import HelixCore
import HelixPersistence
import Observation

@MainActor
@Observable
public final class NativeSessionArchiveState {
    public private(set) var sessions: [NativeSessionSummary] = []
    public private(set) var failureReason = ""

    private let store: SessionArchiveStore

    public init(store: SessionArchiveStore = InMemorySessionArchiveStore()) {
        self.store = store
    }

    public var archiveSummary: String {
        "\(sessions.count) session\(sessions.count == 1 ? "" : "s")"
    }

    public var totalCostSummary: String {
        let totalMicros = sessions.reduce(0) { $0 + $1.totalCostMicros }
        guard totalMicros > 0 else { return "Free" }
        return String(format: "$%.4f", Double(totalMicros) / 1_000_000)
    }

    public var activeProjectSummary: String {
        let projects = Set(sessions.compactMap(\.projectName))
        return "\(projects.count) active"
    }

    public func refresh() async {
        sessions = await store.sessions()
    }

    public func archiveSession(_ session: NativeSessionSummary) async {
        await store.saveSession(session)
        await refresh()
    }

    public func seedDemoSession() async {
        await archiveSession(
            NativeSessionSummary(
                title: "Native LLM Q&A",
                mode: .general,
                transcriptPreview: "What is retrieval augmented generation?",
                answerPreview: "RAG grounds generation with retrieved project context.",
                projectName: "Helix Native",
                totalCostMicros: 2_300,
                segmentCount: 1,
                answerCount: 1
            )
        )
    }
}

@MainActor
@Observable
public final class NativeKnowledgeLibraryState {
    public private(set) var snapshot: NativeKnowledgeSnapshot
    public private(set) var failureReason = ""

    private let store: KnowledgeLibraryStore

    public init(
        store: KnowledgeLibraryStore = InMemoryKnowledgeLibraryStore(),
        snapshot: NativeKnowledgeSnapshot = NativeKnowledgeSnapshot()
    ) {
        self.store = store
        self.snapshot = snapshot
    }

    public var activeProjectName: String {
        snapshot.activeProject?.name ?? "None"
    }

    public var reviewSummary: String {
        let openTodos = snapshot.openTodoCount
        return openTodos == 0 ? "No pending items" : "\(openTodos) open todo\(openTodos == 1 ? "" : "s")"
    }

    public var documentSummary: String {
        let count = snapshot.documents.count
        return "\(count) document\(count == 1 ? "" : "s")"
    }

    public func refresh() async {
        snapshot = await store.snapshot()
    }

    public func createProject(name: String, summary: String = "", activate: Bool = true) async {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        await store.saveProject(
            NativeKnowledgeProject(
                name: trimmedName,
                summary: summary.trimmingCharacters(in: .whitespacesAndNewlines),
                isActive: activate
            )
        )
        await refresh()
    }

    public func setActiveProject(id: UUID?) async {
        await store.setActiveProject(id: id)
        await refresh()
    }

    public func ingestDocument(title: String, text: String, sourceURL: URL? = nil) async {
        await store.ingestDocument(title: title, text: text, sourceURL: sourceURL)
        await refresh()
    }

    public func addFact(_ text: String, source: String = "Manual") async {
        await store.addFact(text, source: source)
        await refresh()
    }

    public func addMemory(_ text: String, source: String = "Manual") async {
        await store.addMemory(text, source: source)
        await refresh()
    }

    public func addTodo(_ title: String) async {
        await store.addTodo(title)
        await refresh()
    }

    public func completeTodo(id: UUID, isComplete: Bool) async {
        await store.completeTodo(id: id, isComplete: isComplete)
        await refresh()
    }

    public func seedDemoKnowledge() async {
        await createProject(
            name: "Helix Native",
            summary: "Native headless framework rewrite parity project.",
            activate: true
        )
        await addFact("Helix displays concise answers on Even G1 glasses.", source: "Native plan")
        await ingestDocument(
            title: "Native RAG Fixture",
            text: "Helix native RAG stores document chunks under the active project. Active answers should use imported document context when the user asks about project-specific behavior.",
            sourceURL: nil
        )
        await addMemory("User prefers direct speakable answers without meta phrasing.", source: "Conversation")
        await addTodo("Validate native G1 HUD on real hardware.")
    }
}
