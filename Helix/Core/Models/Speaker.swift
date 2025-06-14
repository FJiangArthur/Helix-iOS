import Foundation

/// Shared Speaker model used across modules
public struct Speaker: Codable, Identifiable {
    public let id: UUID
    public let name: String?
    public let isCurrentUser: Bool
    public let createdAt: Date
    public var lastSeen: Date?
    public var voiceModel: SpeakerModel?
    
    public init(id: UUID = UUID(), name: String? = nil, isCurrentUser: Bool = false, createdAt: Date = Date(), lastSeen: Date? = nil, voiceModel: SpeakerModel? = nil) {
        self.id = id
        self.name = name
        self.isCurrentUser = isCurrentUser
        self.createdAt = createdAt
        self.lastSeen = lastSeen
        self.voiceModel = voiceModel
    }
}
