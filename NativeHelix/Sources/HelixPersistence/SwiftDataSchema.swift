import Foundation
import SwiftData
import HelixCore

@Model
public final class ConversationRecord {
    @Attribute(.unique) public var id: UUID
    public var title: String
    public var modeRawValue: String
    public var startedAt: Date
    public var endedAt: Date?
    public var totalCostMicros: Int
    public var projectID: UUID?

    @Relationship(deleteRule: .cascade, inverse: \TranscriptSegmentRecord.conversation)
    public var segments: [TranscriptSegmentRecord] = []

    @Relationship(deleteRule: .cascade, inverse: \AnswerRecord.conversation)
    public var answers: [AnswerRecord] = []

    public init(
        id: UUID = UUID(),
        title: String,
        mode: ConversationMode,
        startedAt: Date = Date(),
        endedAt: Date? = nil,
        totalCostMicros: Int = 0,
        projectID: UUID? = nil
    ) {
        self.id = id
        self.title = title
        self.modeRawValue = mode.rawValue
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.totalCostMicros = totalCostMicros
        self.projectID = projectID
    }

    public var mode: ConversationMode {
        ConversationMode(rawValue: modeRawValue) ?? .general
    }
}

@Model
public final class TranscriptSegmentRecord {
    @Attribute(.unique) public var id: UUID
    public var text: String
    public var isFinal: Bool
    public var startedAt: Date
    public var finalizedAt: Date?
    public var conversation: ConversationRecord?

    public init(
        id: UUID = UUID(),
        text: String,
        isFinal: Bool,
        startedAt: Date = Date(),
        finalizedAt: Date? = nil,
        conversation: ConversationRecord? = nil
    ) {
        self.id = id
        self.text = text
        self.isFinal = isFinal
        self.startedAt = startedAt
        self.finalizedAt = finalizedAt
        self.conversation = conversation
    }
}

@Model
public final class AnswerRecord {
    @Attribute(.unique) public var id: UUID
    public var question: String
    public var answer: String
    public var providerRawValue: String
    public var model: String
    public var citations: [String]
    public var createdAt: Date
    public var latencyMs: Int
    public var costMicros: Int
    public var conversation: ConversationRecord?

    public init(
        id: UUID = UUID(),
        question: String,
        answer: String,
        provider: LlmProviderKind,
        model: String,
        citations: [String] = [],
        createdAt: Date = Date(),
        latencyMs: Int = 0,
        costMicros: Int = 0,
        conversation: ConversationRecord? = nil
    ) {
        self.id = id
        self.question = question
        self.answer = answer
        self.providerRawValue = provider.rawValue
        self.model = model
        self.citations = citations
        self.createdAt = createdAt
        self.latencyMs = latencyMs
        self.costMicros = costMicros
        self.conversation = conversation
    }

    public var provider: LlmProviderKind {
        LlmProviderKind(rawValue: providerRawValue) ?? .openAI
    }
}

@Model
public final class ProjectRecord {
    @Attribute(.unique) public var id: UUID
    public var name: String
    public var summary: String
    public var isActive: Bool
    public var createdAt: Date
    public var updatedAt: Date

    @Relationship(deleteRule: .cascade, inverse: \KnowledgeDocumentRecord.project)
    public var documents: [KnowledgeDocumentRecord] = []

    public init(
        id: UUID = UUID(),
        name: String,
        summary: String = "",
        isActive: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.summary = summary
        self.isActive = isActive
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

@Model
public final class KnowledgeDocumentRecord {
    @Attribute(.unique) public var id: UUID
    public var title: String
    public var sourceURL: URL?
    public var importedAt: Date
    public var project: ProjectRecord?

    @Relationship(deleteRule: .cascade, inverse: \DocumentChunkRecord.document)
    public var chunks: [DocumentChunkRecord] = []

    public init(
        id: UUID = UUID(),
        title: String,
        sourceURL: URL? = nil,
        importedAt: Date = Date(),
        project: ProjectRecord? = nil
    ) {
        self.id = id
        self.title = title
        self.sourceURL = sourceURL
        self.importedAt = importedAt
        self.project = project
    }
}

@Model
public final class DocumentChunkRecord {
    @Attribute(.unique) public var id: UUID
    public var ordinal: Int
    public var text: String
    public var tokenCount: Int
    public var embeddingModel: String?
    public var embeddingVector: [Double]
    public var document: KnowledgeDocumentRecord?

    public init(
        id: UUID = UUID(),
        ordinal: Int,
        text: String,
        tokenCount: Int = 0,
        embeddingModel: String? = nil,
        embeddingVector: [Double] = [],
        document: KnowledgeDocumentRecord? = nil
    ) {
        self.id = id
        self.ordinal = ordinal
        self.text = text
        self.tokenCount = tokenCount
        self.embeddingModel = embeddingModel
        self.embeddingVector = embeddingVector
        self.document = document
    }
}

@Model
public final class FactRecord {
    @Attribute(.unique) public var id: UUID
    public var text: String
    public var source: String
    public var confidence: Double
    public var projectID: UUID?
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        text: String,
        source: String = "",
        confidence: Double = 1,
        projectID: UUID? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.text = text
        self.source = source
        self.confidence = confidence
        self.projectID = projectID
        self.createdAt = createdAt
    }
}

@Model
public final class MemoryRecord {
    @Attribute(.unique) public var id: UUID
    public var text: String
    public var tags: [String]
    public var projectID: UUID?
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        text: String,
        tags: [String] = [],
        projectID: UUID? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.text = text
        self.tags = tags
        self.projectID = projectID
        self.createdAt = createdAt
    }
}

@Model
public final class TodoRecord {
    @Attribute(.unique) public var id: UUID
    public var title: String
    public var isComplete: Bool
    public var dueAt: Date?
    public var projectID: UUID?
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        title: String,
        isComplete: Bool = false,
        dueAt: Date? = nil,
        projectID: UUID? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.isComplete = isComplete
        self.dueAt = dueAt
        self.projectID = projectID
        self.createdAt = createdAt
    }
}

@Model
public final class SettingsMetadataRecord {
    @Attribute(.unique) public var key: String
    public var value: String
    public var updatedAt: Date

    public init(key: String, value: String, updatedAt: Date = Date()) {
        self.key = key
        self.value = value
        self.updatedAt = updatedAt
    }
}

public enum HelixSwiftDataSchema {
    public static var models: [any PersistentModel.Type] {
        [
            ConversationRecord.self,
            TranscriptSegmentRecord.self,
            AnswerRecord.self,
            ProjectRecord.self,
            KnowledgeDocumentRecord.self,
            DocumentChunkRecord.self,
            FactRecord.self,
            MemoryRecord.self,
            TodoRecord.self,
            SettingsMetadataRecord.self
        ]
    }

    public static func makeModelContainer(isStoredInMemoryOnly: Bool = false) throws -> ModelContainer {
        let schema = Schema(models)
        let configuration = ModelConfiguration(
            "HelixNativeStore",
            schema: schema,
            isStoredInMemoryOnly: isStoredInMemoryOnly
        )
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}
