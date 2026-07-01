import Foundation

public enum HelixRuntimeFeature: String, CaseIterable, Sendable {
    case assistantSession = "assistant-session"
    case g1Device = "g1-device"
    case sessionArchive = "session-archive"
    case knowledgeLibrary = "knowledge-library"
    case providerSettings = "provider-settings"
    case liveMode = "mode-live"
    case passiveMode = "mode-passive"
    case activeAnswer = "active-answer"
    case skillPresets = "skill-presets"
    case sessionMemory = "session-memory"
    case passiveTrigger = "passive-trigger"
    case ragProject = "rag-project"
    case webSearch = "web-search"
    case modelDiscovery = "model-discovery"
    case latencyReporting = "latency-reporting"
    case g1Hud = "g1-hud"
    case transcription = "transcription"

    public var identifier: String { rawValue }
}

public struct HelixRuntimeFeatureCatalog: Sendable {
    public let features: [HelixRuntimeFeature]

    public init(features: [HelixRuntimeFeature] = HelixRuntimeFeature.allCases) {
        self.features = features
    }

    public var identifiers: [String] {
        features.map(\.identifier)
    }
}
