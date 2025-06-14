//
//  CognitiveEnhancementSuite.swift
//  Helix
//

import Foundation
import Combine
import Vision
import CoreLocation

// MARK: - Memory Palace System

struct MemoryPalace: Codable, Identifiable {
    let id: UUID
    var name: String
    var description: String
    var locations: [MemoryLocation]
    var associatedTopics: [String]
    var createdDate: Date
    var lastUsed: Date
    var usageCount: Int
    
    init(name: String, description: String) {
        self.id = UUID()
        self.name = name
        self.description = description
        self.locations = []
        self.associatedTopics = []
        self.createdDate = Date()
        self.lastUsed = Date()
        self.usageCount = 0
    }
}

struct MemoryLocation: Codable, Identifiable {
    let id: UUID
    var name: String
    var description: String
    var position: SpatialPosition
    var associatedInformation: [MemoryItem]
    var visualCues: [VisualCue]
    var createdDate: Date
    
    init(name: String, description: String, position: SpatialPosition) {
        self.id = UUID()
        self.name = name
        self.description = description
        self.position = position
        self.associatedInformation = []
        self.visualCues = []
        self.createdDate = Date()
    }
}

struct SpatialPosition: Codable {
    let x: Float
    let y: Float
    let z: Float
    let orientation: Float // 0-360 degrees
}

struct MemoryItem: Codable, Identifiable {
    let id: UUID
    let content: String
    let type: MemoryItemType
    let associatedConversation: UUID?
    let createdDate: Date
    let strength: Float // 0.0 to 1.0
    var lastAccessed: Date
    
    init(content: String, type: MemoryItemType, associatedConversation: UUID? = nil) {
        self.id = UUID()
        self.content = content
        self.type = type
        self.associatedConversation = associatedConversation
        self.createdDate = Date()
        self.strength = 1.0
        self.lastAccessed = Date()
    }
}

enum MemoryItemType: String, Codable, CaseIterable {
    case fact = "fact"
    case person = "person"
    case event = "event"
    case concept = "concept"
    case reminder = "reminder"
    case insight = "insight"
}

struct VisualCue: Codable, Identifiable {
    let id: UUID
    let type: VisualCueType
    let description: String
    let color: CueColor
    let size: CueSize
    let animation: CueAnimation?
    
    init(type: VisualCueType, description: String, color: CueColor = .blue, size: CueSize = .medium) {
        self.id = UUID()
        self.type = type
        self.description = description
        self.color = color
        self.size = size
        self.animation = nil
    }
}

enum VisualCueType: String, Codable {
    case icon = "icon"
    case shape = "shape"
    case text = "text"
    case image = "image"
}

enum CueColor: String, Codable, CaseIterable {
    case red = "red"
    case blue = "blue"
    case green = "green"
    case yellow = "yellow"
    case purple = "purple"
    case orange = "orange"
    case white = "white"
}

enum CueSize: String, Codable {
    case small = "small"
    case medium = "medium"
    case large = "large"
}

enum CueAnimation: String, Codable {
    case pulse = "pulse"
    case fade = "fade"
    case bounce = "bounce"
    case rotate = "rotate"
}

// MARK: - Memory Palace Manager

protocol MemoryPalaceManagerProtocol {
    var memoryPalaces: AnyPublisher<[MemoryPalace], Never> { get }
    var activeMemoryPalace: AnyPublisher<MemoryPalace?, Never> { get }
    
    func createMemoryPalace(_ palace: MemoryPalace) throws
    func updateMemoryPalace(_ palace: MemoryPalace) throws
    func deleteMemoryPalace(_ palaceId: UUID) throws
    func activateMemoryPalace(_ palaceId: UUID)
    func deactivateMemoryPalace()
    
    func addMemoryItem(_ item: MemoryItem, to locationId: UUID) throws
    func linkConversationToMemory(_ conversationId: UUID, item: MemoryItem)
    func retrieveMemoriesFor(topic: String) -> [MemoryItem]
    func generateMemoryPalaceFor(topic: String) -> MemoryPalace
}

class MemoryPalaceManager: MemoryPalaceManagerProtocol, ObservableObject {
    private let memoryPalacesSubject = CurrentValueSubject<[MemoryPalace], Never>([])
    private let activeMemoryPalaceSubject = CurrentValueSubject<MemoryPalace?, Never>(nil)
    
    private let storage: MemoryPalaceStorage
    private let memoryAssociator: MemoryAssociator
    
    var memoryPalaces: AnyPublisher<[MemoryPalace], Never> {
        memoryPalacesSubject.eraseToAnyPublisher()
    }
    
    var activeMemoryPalace: AnyPublisher<MemoryPalace?, Never> {
        activeMemoryPalaceSubject.eraseToAnyPublisher()
    }
    
    init(storage: MemoryPalaceStorage = MemoryPalaceStorage()) {
        self.storage = storage
        self.memoryAssociator = MemoryAssociator()
        
        loadStoredPalaces()
        createDefaultPalaces()
    }
    
    func createMemoryPalace(_ palace: MemoryPalace) throws {
        var palaces = memoryPalacesSubject.value
        palaces.append(palace)
        memoryPalacesSubject.send(palaces)
        
        try storage.save(palaces)
    }
    
    func updateMemoryPalace(_ palace: MemoryPalace) throws {
        var palaces = memoryPalacesSubject.value
        
        if let index = palaces.firstIndex(where: { $0.id == palace.id }) {
            palaces[index] = palace
            memoryPalacesSubject.send(palaces)
            
            try storage.save(palaces)
        }
    }
    
    func deleteMemoryPalace(_ palaceId: UUID) throws {
        var palaces = memoryPalacesSubject.value
        palaces.removeAll { $0.id == palaceId }
        memoryPalacesSubject.send(palaces)
        
        if activeMemoryPalaceSubject.value?.id == palaceId {
            activeMemoryPalaceSubject.send(nil)
        }
        
        try storage.save(palaces)
    }
    
    func activateMemoryPalace(_ palaceId: UUID) {
        let palace = memoryPalacesSubject.value.first { $0.id == palaceId }
        activeMemoryPalaceSubject.send(palace)
    }
    
    func deactivateMemoryPalace() {
        activeMemoryPalaceSubject.send(nil)
    }
    
    func addMemoryItem(_ item: MemoryItem, to locationId: UUID) throws {
        var palaces = memoryPalacesSubject.value
        
        for (palaceIndex, palace) in palaces.enumerated() {
            for (locationIndex, location) in palace.locations.enumerated() {
                if location.id == locationId {
                    palaces[palaceIndex].locations[locationIndex].associatedInformation.append(item)
                    memoryPalacesSubject.send(palaces)
                    
                    try storage.save(palaces)
                    return
                }
            }
        }
        
        throw MemoryPalaceError.locationNotFound
    }
    
    func linkConversationToMemory(_ conversationId: UUID, item: MemoryItem) {
        var enhancedItem = item
        enhancedItem.lastAccessed = Date()
        
        // Find relevant memory palace and location
        let relevantPalace = findRelevantPalace(for: item)
        
        if let palace = relevantPalace {
            try? addMemoryItem(enhancedItem, to: palace.locations.first?.id ?? UUID())
        }
    }
    
    func retrieveMemoriesFor(topic: String) -> [MemoryItem] {
        let palaces = memoryPalacesSubject.value
        
        return palaces.flatMap { palace in
            palace.locations.flatMap { location in
                location.associatedInformation.filter { item in
                    item.content.localizedCaseInsensitiveContains(topic) ||
                    palace.associatedTopics.contains { $0.localizedCaseInsensitiveContains(topic) }
                }
            }
        }
    }
    
    func generateMemoryPalaceFor(topic: String) -> MemoryPalace {
        var palace = MemoryPalace(name: "\(topic) Palace", description: "Generated memory palace for \(topic)")
        
        // Create 5 standard locations
        let locations = [
            MemoryLocation(name: "Entrance", description: "Starting point for \(topic)", position: SpatialPosition(x: 0, y: 0, z: 0, orientation: 0)),
            MemoryLocation(name: "Central Hall", description: "Main concepts of \(topic)", position: SpatialPosition(x: 10, y: 0, z: 0, orientation: 90)),
            MemoryLocation(name: "Left Wing", description: "Details and examples", position: SpatialPosition(x: 10, y: 10, z: 0, orientation: 180)),
            MemoryLocation(name: "Right Wing", description: "Related topics", position: SpatialPosition(x: 10, y: -10, z: 0, orientation: 0)),
            MemoryLocation(name: "Archive", description: "Historical context", position: SpatialPosition(x: 20, y: 0, z: 0, orientation: 270))
        ]
        
        palace.locations = locations
        palace.associatedTopics = [topic]
        
        return palace
    }
    
    private func loadStoredPalaces() {
        if let stored = storage.load() {
            memoryPalacesSubject.send(stored)
        }
    }
    
    private func createDefaultPalaces() {
        guard memoryPalacesSubject.value.isEmpty else { return }
        
        let defaultPalace = generateMemoryPalaceFor(topic: "General Knowledge")
        try? createMemoryPalace(defaultPalace)
    }
    
    private func findRelevantPalace(for item: MemoryItem) -> MemoryPalace? {
        let palaces = memoryPalacesSubject.value
        
        return palaces.first { palace in
            palace.associatedTopics.contains { topic in
                item.content.localizedCaseInsensitiveContains(topic)
            }
        } ?? palaces.first
    }
}

// MARK: - Name and Face Recognition

struct PersonProfile: Codable, Identifiable {
    let id: UUID
    var name: String
    var faceEmbedding: Data?
    var personalInfo: PersonalInfo
    var conversationHistory: [UUID] // Conversation IDs
    var lastSeen: Date?
    var interactionCount: Int
    var relationshipType: RelationshipType
    var tags: [String]
    
    init(name: String, personalInfo: PersonalInfo = PersonalInfo()) {
        self.id = UUID()
        self.name = name
        self.faceEmbedding = nil
        self.personalInfo = personalInfo
        self.conversationHistory = []
        self.lastSeen = nil
        self.interactionCount = 0
        self.relationshipType = .acquaintance
        self.tags = []
    }
}

struct PersonalInfo: Codable {
    var company: String?
    var jobTitle: String?
    var interests: [String]
    var notes: [String]
    var importantDates: [ImportantDate]
    var contactInformation: ContactInfo?
    var socialMediaHandles: [String: String] // Platform: Handle
    
    init() {
        self.company = nil
        self.jobTitle = nil
        self.interests = []
        self.notes = []
        self.importantDates = []
        self.contactInformation = nil
        self.socialMediaHandles = [:]
    }
}

struct ImportantDate: Codable, Identifiable {
    let id: UUID
    let date: Date
    let description: String
    let type: DateType
    
    init(date: Date, description: String, type: DateType) {
        self.id = UUID()
        self.date = date
        self.description = description
        self.type = type
    }
}

enum DateType: String, Codable, CaseIterable {
    case birthday = "birthday"
    case anniversary = "anniversary"
    case meeting = "meeting"
    case deadline = "deadline"
    case reminder = "reminder"
}

struct ContactInfo: Codable {
    var email: String?
    var phone: String?
    var address: String?
    var website: String?
}

enum RelationshipType: String, Codable, CaseIterable {
    case family = "family"
    case friend = "friend"
    case colleague = "colleague"
    case acquaintance = "acquaintance"
    case professional = "professional"
    case client = "client"
    case vendor = "vendor"
}

// MARK: - Face Recognition Manager

protocol FaceRecognitionManagerProtocol {
    var recognizedPersons: AnyPublisher<[PersonProfile], Never> { get }
    var isEnabled: AnyPublisher<Bool, Never> { get }
    
    func enableFaceRecognition()
    func disableFaceRecognition()
    func addPersonProfile(_ profile: PersonProfile, faceImage: Data?) throws
    func updatePersonProfile(_ profile: PersonProfile) throws
    func recognizeFace(from imageData: Data) -> AnyPublisher<PersonProfile?, FaceRecognitionError>
    func trainFaceModel(for personId: UUID, with images: [Data]) -> AnyPublisher<Void, FaceRecognitionError>
}

class FaceRecognitionManager: FaceRecognitionManagerProtocol, ObservableObject {
    private let recognizedPersonsSubject = CurrentValueSubject<[PersonProfile], Never>([])
    private let isEnabledSubject = CurrentValueSubject<Bool, Never>(false)
    
    private let storage: PersonProfileStorage
    private let faceAnalyzer: FaceAnalyzer
    
    var recognizedPersons: AnyPublisher<[PersonProfile], Never> {
        recognizedPersonsSubject.eraseToAnyPublisher()
    }
    
    var isEnabled: AnyPublisher<Bool, Never> {
        isEnabledSubject.eraseToAnyPublisher()
    }
    
    init() {
        self.storage = PersonProfileStorage()
        self.faceAnalyzer = FaceAnalyzer()
        
        loadStoredProfiles()
    }
    
    func enableFaceRecognition() {
        isEnabledSubject.send(true)
        print("Face recognition enabled")
    }
    
    func disableFaceRecognition() {
        isEnabledSubject.send(false)
        print("Face recognition disabled")
    }
    
    func addPersonProfile(_ profile: PersonProfile, faceImage: Data?) throws {
        var enhancedProfile = profile
        
        if let imageData = faceImage {
            enhancedProfile.faceEmbedding = try faceAnalyzer.generateEmbedding(from: imageData)
        }
        
        var profiles = recognizedPersonsSubject.value
        profiles.append(enhancedProfile)
        recognizedPersonsSubject.send(profiles)
        
        try storage.save(profiles)
    }
    
    func updatePersonProfile(_ profile: PersonProfile) throws {
        var profiles = recognizedPersonsSubject.value
        
        if let index = profiles.firstIndex(where: { $0.id == profile.id }) {
            profiles[index] = profile
            recognizedPersonsSubject.send(profiles)
            
            try storage.save(profiles)
        }
    }
    
    func recognizeFace(from imageData: Data) -> AnyPublisher<PersonProfile?, FaceRecognitionError> {
        guard isEnabledSubject.value else {
            return Just(nil)
                .setFailureType(to: FaceRecognitionError.self)
                .eraseToAnyPublisher()
        }
        
        return faceAnalyzer.recognizeFace(imageData: imageData, knownProfiles: recognizedPersonsSubject.value)
    }
    
    func trainFaceModel(for personId: UUID, with images: [Data]) -> AnyPublisher<Void, FaceRecognitionError> {
        return faceAnalyzer.trainFaceModel(personId: personId, images: images)
    }
    
    private func loadStoredProfiles() {
        if let stored = storage.load() {
            recognizedPersonsSubject.send(stored)
        }
    }
}

// MARK: - Attention Direction System

struct AttentionCue: Identifiable {
    let id: UUID
    let type: AttentionCueType
    let direction: AttentionDirection
    let intensity: Float // 0.0 to 1.0
    let priority: AttentionPriority
    let duration: TimeInterval
    let reason: String
    
    init(type: AttentionCueType, direction: AttentionDirection, intensity: Float, priority: AttentionPriority, reason: String, duration: TimeInterval = 3.0) {
        self.id = UUID()
        self.type = type
        self.direction = direction
        self.intensity = intensity
        self.priority = priority
        self.duration = duration
        self.reason = reason
    }
}

enum AttentionCueType: String, CaseIterable, Codable {
    case visual = "visual"
    case audio = "audio"
    case haptic = "haptic"
    case combined = "combined"
}

enum AttentionDirection: String, CaseIterable, Codable, Hashable {
    case left = "left"
    case right = "right"
    case forward = "forward"
    case behind = "behind"
    case up = "up"
    case down = "down"
}

enum AttentionPriority: String, CaseIterable, Codable, Hashable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case urgent = "urgent"
}

protocol AttentionDirectionSystemProtocol {
    var activeCues: AnyPublisher<[AttentionCue], Never> { get }
    var settings: AnyPublisher<AttentionSettings, Never> { get }
    
    func updateSettings(_ newSettings: AttentionSettings)
    func addAttentionCue(_ cue: AttentionCue)
    func clearCues()
    func detectActiveSpeaker(from audioLevels: [UUID: Float]) -> UUID?
    func generateDirectionalCue(for speakerId: UUID, speakers: [Speaker]) -> AttentionCue?
}

struct AttentionSettings: Codable {
    var isEnabled: Bool
    var enabledCueTypes: Set<AttentionCueType>
    var sensitivity: Float // 0.0 to 1.0
    var autoHighlightActiveSpeaker: Bool
    var eyeTrackingIntegration: Bool
    var maxConcurrentCues: Int
    
    static let `default` = AttentionSettings(
        isEnabled: true,
        enabledCueTypes: [.visual],
        sensitivity: 0.5,
        autoHighlightActiveSpeaker: true,
        eyeTrackingIntegration: false,
        maxConcurrentCues: 3
    )
}

class AttentionDirectionSystem: AttentionDirectionSystemProtocol, ObservableObject {
    private let activeCuesSubject = CurrentValueSubject<[AttentionCue], Never>([])
    private let settingsSubject = CurrentValueSubject<AttentionSettings, Never>(.default)
    
    private let spatialAudioAnalyzer: SpatialAudioAnalyzer
    private var cueExpirationTimers: [UUID: Timer] = [:]
    
    var activeCues: AnyPublisher<[AttentionCue], Never> {
        activeCuesSubject.eraseToAnyPublisher()
    }
    
    var settings: AnyPublisher<AttentionSettings, Never> {
        settingsSubject.eraseToAnyPublisher()
    }
    
    init() {
        self.spatialAudioAnalyzer = SpatialAudioAnalyzer()
    }
    
    func updateSettings(_ newSettings: AttentionSettings) {
        settingsSubject.send(newSettings)
    }
    
    func addAttentionCue(_ cue: AttentionCue) {
        var cues = activeCuesSubject.value
        
        // Remove oldest cue if at max capacity
        let settings = settingsSubject.value
        if cues.count >= settings.maxConcurrentCues {
            if let oldestCue = cues.min(by: { $0.priority.rawValue < $1.priority.rawValue }) {
                removeCue(oldestCue.id)
            }
        }
        
        cues.append(cue)
        activeCuesSubject.send(cues)
        
        // Set expiration timer
        let timer = Timer.scheduledTimer(withTimeInterval: cue.duration, repeats: false) { [weak self] _ in
            self?.removeCue(cue.id)
        }
        cueExpirationTimers[cue.id] = timer
    }
    
    func clearCues() {
        // Cancel all timers
        cueExpirationTimers.values.forEach { $0.invalidate() }
        cueExpirationTimers.removeAll()
        
        activeCuesSubject.send([])
    }
    
    func detectActiveSpeaker(from audioLevels: [UUID: Float]) -> UUID? {
        return audioLevels.max(by: { $0.value < $1.value })?.key
    }
    
    func generateDirectionalCue(for speakerId: UUID, speakers: [Speaker]) -> AttentionCue? {
        guard let speaker = speakers.first(where: { $0.id == speakerId }) else {
            return nil
        }
        
        // Simplified directional logic (in real implementation, would use spatial audio analysis)
        let direction: AttentionDirection = .forward // Placeholder
        
        return AttentionCue(
            type: .visual,
            direction: direction,
            intensity: 0.7,
            priority: .medium,
            reason: "\(speaker.name) is speaking"
        )
    }
    
    private func removeCue(_ cueId: UUID) {
        var cues = activeCuesSubject.value
        cues.removeAll { $0.id == cueId }
        activeCuesSubject.send(cues)
        
        cueExpirationTimers[cueId]?.invalidate()
        cueExpirationTimers.removeValue(forKey: cueId)
    }
}

// MARK: - Supporting Classes

class MemoryAssociator {
    func findAssociations(for item: MemoryItem, in palaces: [MemoryPalace]) -> [MemoryItem] {
        // Find related memory items based on content similarity
        return []
    }
}

class MemoryPalaceStorage {
    private let userDefaults = UserDefaults.standard
    private let key = "memory_palaces"
    
    func save(_ palaces: [MemoryPalace]) throws {
        let data = try JSONEncoder().encode(palaces)
        userDefaults.set(data, forKey: key)
    }
    
    func load() -> [MemoryPalace]? {
        guard let data = userDefaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode([MemoryPalace].self, from: data)
    }
}

class PersonProfileStorage {
    private let userDefaults = UserDefaults.standard
    private let key = "person_profiles"
    
    func save(_ profiles: [PersonProfile]) throws {
        let data = try JSONEncoder().encode(profiles)
        userDefaults.set(data, forKey: key)
    }
    
    func load() -> [PersonProfile]? {
        guard let data = userDefaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode([PersonProfile].self, from: data)
    }
}

class FaceAnalyzer {
    func generateEmbedding(from imageData: Data) throws -> Data {
        // In real implementation, would use Vision framework for face detection and embedding
        return Data() // Placeholder
    }
    
    func recognizeFace(imageData: Data, knownProfiles: [PersonProfile]) -> AnyPublisher<PersonProfile?, FaceRecognitionError> {
        return Future { promise in
            // Simulate face recognition processing
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) {
                // In real implementation, would compare face embeddings
                promise(.success(nil)) // No match found
            }
        }
        .eraseToAnyPublisher()
    }
    
    func trainFaceModel(for personId: UUID, with images: [Data]) -> AnyPublisher<Void, FaceRecognitionError> {
        return Future { promise in
            // Simulate model training
            DispatchQueue.global().asyncAfter(deadline: .now() + 2.0) {
                promise(.success(()))
            }
        }
        .eraseToAnyPublisher()
    }
}

class SpatialAudioAnalyzer {
    func analyzeDirection(for audioData: Data) -> AttentionDirection {
        // Analyze audio data to determine direction
        return .forward // Placeholder
    }
    
    func calculateIntensity(for audioLevel: Float) -> Float {
        return min(max(audioLevel / 100.0, 0.0), 1.0)
    }
}

// MARK: - Errors

enum MemoryPalaceError: LocalizedError {
    case locationNotFound
    case palaceNotFound
    case invalidMemoryItem
    case storageFailed
    
    var errorDescription: String? {
        switch self {
        case .locationNotFound: return "Memory location not found"
        case .palaceNotFound: return "Memory palace not found"
        case .invalidMemoryItem: return "Invalid memory item"
        case .storageFailed: return "Failed to save memory palace"
        }
    }
}

enum FaceRecognitionError: LocalizedError {
    case noFaceDetected
    case multiplefacesDetected
    case embeddingGenerationFailed
    case modelTrainingFailed
    case permissionDenied
    case deviceNotSupported
    
    var errorDescription: String? {
        switch self {
        case .noFaceDetected: return "No face detected in image"
        case .multipleTracesDetected: return "Multiple faces detected"
        case .embeddingGenerationFailed: return "Failed to generate face embedding"
        case .modelTrainingFailed: return "Face model training failed"
        case .permissionDenied: return "Camera permission denied"
        case .deviceNotSupported: return "Face recognition not supported on this device"
        }
    }
}

// MARK: - Extensions for AttentionCueType Set Codable

extension Set: @retroactive RawRepresentable where Element: RawRepresentable, Element.RawValue == String {
    public var rawValue: String {
        return Array(self).map { $0.rawValue }.joined(separator: ",")
    }
    
    public init?(rawValue: String) {
        let elements = rawValue.components(separatedBy: ",").compactMap { Element(rawValue: $0) }
        self.init(elements)
    }
}