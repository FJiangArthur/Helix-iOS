import Foundation
import HelixCore

public enum PassiveTriggerAction: String, Codable, Sendable {
    case answer
    case ignore
    case wait
}

public enum PassiveTriggerKind: String, Codable, Sendable {
    case directQuestion
    case implicitAsk
    case rhetorical
    case monologue
    case filler
    case ambiguous
}

public struct PassiveTriggerResult: Codable, Equatable, Sendable {
    public var action: PassiveTriggerAction
    public var kind: PassiveTriggerKind
    public var confidence: Double
    public var reason: String

    public init(
        action: PassiveTriggerAction,
        kind: PassiveTriggerKind,
        confidence: Double,
        reason: String
    ) {
        self.action = action
        self.kind = kind
        self.confidence = min(1, max(0, confidence))
        self.reason = reason.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

public struct PassiveTriggerPrompt: Equatable, Sendable {
    public var currentSegment: String
    public var transcriptWindow: String
    public var skill: ActiveSkill

    public init(currentSegment: String, transcriptWindow: String, skill: ActiveSkill) {
        self.currentSegment = currentSegment
        self.transcriptWindow = transcriptWindow
        self.skill = skill
    }
}

public protocol PassiveTriggerLiveClassifying: Sendable {
    func classify(_ prompt: PassiveTriggerPrompt) async throws -> PassiveTriggerResult
}

public protocol PassiveTriggerClassifying: Sendable {
    func decision(
        for segment: TranscriptSegment,
        transcriptWindow: String,
        settings: HelixSettings
    ) async throws -> PassiveTriggerResult
}

public struct PassiveTriggerClassifier: PassiveTriggerClassifying {
    private let liveClassifier: (any PassiveTriggerLiveClassifying)?
    private let liveThreshold: Double

    public init(
        liveClassifier: (any PassiveTriggerLiveClassifying)? = nil,
        liveThreshold: Double = 0.70
    ) {
        self.liveClassifier = liveClassifier
        self.liveThreshold = liveThreshold
    }

    public func decision(
        for segment: TranscriptSegment,
        transcriptWindow: String,
        settings: HelixSettings
    ) async throws -> PassiveTriggerResult {
        let heuristic = heuristicDecision(for: segment.text)
        if heuristic.action != .wait || heuristic.confidence >= liveThreshold {
            return heuristic
        }

        guard let liveClassifier else {
            return heuristic
        }

        do {
            return try await liveClassifier.classify(
                PassiveTriggerPrompt(
                    currentSegment: segment.text,
                    transcriptWindow: transcriptWindow,
                    skill: settings.activeSkill
                )
            )
        } catch {
            return heuristic
        }
    }

    public func heuristicDecision(for text: String) -> PassiveTriggerResult {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = Self.normalized(trimmed)
        guard !normalized.isEmpty else {
            return PassiveTriggerResult(action: .ignore, kind: .filler, confidence: 0.98, reason: "Empty passive segment.")
        }

        if Self.fillerPhrases.contains(normalized) {
            return PassiveTriggerResult(action: .ignore, kind: .filler, confidence: 0.96, reason: "Filler or acknowledgement.")
        }

        let words = normalized.split(separator: " ")
        if trimmed.hasSuffix("?") || Self.questionPrefixes.contains(where: { normalized == $0 || normalized.hasPrefix($0 + " ") }) {
            return PassiveTriggerResult(action: .answer, kind: .directQuestion, confidence: 0.95, reason: "Direct question detected.")
        }

        if Self.rhetoricalMarkers.contains(where: { normalized.contains($0) }) {
            return PassiveTriggerResult(action: .ignore, kind: .rhetorical, confidence: 0.83, reason: "Rhetorical or self-directed phrasing.")
        }

        if Self.implicitAskMarkers.contains(where: { normalized.contains($0) }) {
            return PassiveTriggerResult(action: .answer, kind: .implicitAsk, confidence: 0.78, reason: "Implicit help request detected.")
        }

        if words.count < 4 {
            return PassiveTriggerResult(action: .wait, kind: .ambiguous, confidence: 0.64, reason: "Too short for a passive answer.")
        }

        if normalized.contains(" i wonder ") || normalized.hasPrefix("i wonder ") {
            return PassiveTriggerResult(action: .wait, kind: .ambiguous, confidence: 0.58, reason: "Ambiguous thought, waiting for more context.")
        }

        return PassiveTriggerResult(action: .ignore, kind: .monologue, confidence: 0.82, reason: "No help request detected.")
    }

    private static let questionPrefixes = [
        "what", "why", "how", "when", "where", "who", "which",
        "can", "could", "should", "would", "is", "are", "do", "does",
        "tell me", "explain", "walk me through"
    ]

    private static let implicitAskMarkers = [
        "i am stuck",
        "i'm stuck",
        "i dont know how",
        "i don't know how",
        "need help",
        "can someone explain",
        "not sure how",
        "help me",
        "walk me through"
    ]

    private static let rhetoricalMarkers = [
        "you know what i mean",
        "isn't it",
        "right?",
        "does that make sense"
    ]

    private static let fillerPhrases: Set<String> = [
        "ok",
        "okay",
        "yeah",
        "yes",
        "no",
        "right",
        "thanks",
        "thank you",
        "um",
        "uh",
        "mm hmm",
        "got it"
    ]

    private static func normalized(_ value: String) -> String {
        value
            .lowercased()
            .replacingOccurrences(of: "[^a-z0-9 '?]", with: " ", options: .regularExpression)
            .split(separator: " ")
            .joined(separator: " ")
    }
}

public struct PassiveTriggerJSONParser: Sendable {
    public init() {}

    public func parse(_ data: Data) throws -> PassiveTriggerResult {
        let decoder = JSONDecoder()
        if let direct = try? decoder.decode(PassiveTriggerPayload.self, from: data) {
            return direct.result
        }
        let completion = try decoder.decode(PassiveTriggerCompletionPayload.self, from: data)
        guard let content = completion.choices.first?.message.content.data(using: .utf8) else {
            throw HelixError.providerFailure("Passive classifier response was empty.")
        }
        return try parse(content)
    }

    private struct PassiveTriggerPayload: Decodable {
        var action: PassiveTriggerAction
        var kind: PassiveTriggerKind?
        var confidence: Double?
        var reason: String?

        var result: PassiveTriggerResult {
            PassiveTriggerResult(
                action: action,
                kind: kind ?? .ambiguous,
                confidence: confidence ?? 0.5,
                reason: reason ?? "Classifier decision."
            )
        }
    }

    private struct PassiveTriggerCompletionPayload: Decodable {
        struct Choice: Decodable {
            struct Message: Decodable {
                var content: String
            }

            var message: Message
        }

        var choices: [Choice]
    }
}
