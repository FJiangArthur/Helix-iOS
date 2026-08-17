import Foundation
import HelixAI
import HelixCore
import Observation

public enum InsightDisplayAction: String, Codable, Sendable {
    case show
    case replace
    case queue
    case drop
}

public enum InsightUrgency: String, Codable, Sendable {
    case low
    case medium
    case high
}

public struct Insight: Identifiable, Equatable, Sendable {
    public let id: UUID
    public var text: String
    public var displayAction: InsightDisplayAction
    public var urgency: InsightUrgency
    public var confidence: Double
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        text: String,
        displayAction: InsightDisplayAction = .show,
        urgency: InsightUrgency = .low,
        confidence: Double = 0,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.text = text
        self.displayAction = displayAction
        self.urgency = urgency
        self.confidence = confidence
        self.createdAt = createdAt
    }
}

public struct InsightDecision: Identifiable, Equatable, Sendable {
    public enum Outcome: String, Sendable {
        case displayed
        case replaced
        case queued
        case dropped
        case deduplicated
        case deferred
        case silent
        case engineOwned
    }

    public let id: UUID
    public var outcome: Outcome
    public var trigger: String
    public var chunkText: String
    public var insightText: String?
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        outcome: Outcome,
        trigger: String,
        chunkText: String,
        insightText: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.outcome = outcome
        self.trigger = trigger
        self.chunkText = chunkText
        self.insightText = insightText
        self.createdAt = createdAt
    }
}

/// Merge-style proactive conversation insights (ported from the MentraOS
/// Merge miniapp): chunks live transcription, asks a lightweight LLM whether
/// a concise contextual insight is warranted, deduplicates, and orchestrates
/// what actually reaches the HUD.
///
/// One concrete coordinator, deliberately not a plugin platform — extract a
/// protocol only when a second consumer (captions, teleprompter) exists.
@MainActor
@Observable
public final class InsightCoordinator {
    public struct Configuration: Sendable {
        public var minFinalChars: Int = 12
        public var minSentenceChars: Int = 20
        public var intervalSeconds: TimeInterval = 8
        public var intervalMinChars: Int = 140
        public var maxPendingChunks: Int = 8
        public var displaySeconds: TimeInterval = 10
        public var maxQueued: Int = 3
        public var dedupWindow: Int = 12

        public init() {}
    }

    public private(set) var isEnabled = false
    public private(set) var activeInsight: Insight?
    public private(set) var insights: [Insight] = []
    public private(set) var decisions: [InsightDecision] = []
    public private(set) var isProcessing = false

    /// Fired when an insight wins arbitration and should be rendered.
    public var onDisplay: ((Insight) -> Void)?

    private let configuration: Configuration
    private var provider: (any HelixAnswerProvider)?
    private var maxResponseSentences = 1

    private var pendingChunks: [String] = []
    private var lastAnalyzedText = ""
    private var lastIntervalAnalysisAt = Date.distantPast
    private var recentInsightKeys: [String] = []
    private var displayQueue: [Insight] = []
    private var activeDisplayUntil: Date?
    private var queueDrainTask: Task<Void, Never>?
    private let now: @Sendable () -> Date

    public init(
        configuration: Configuration = Configuration(),
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.configuration = configuration
        self.now = now
    }

    public func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        if !enabled {
            pendingChunks = []
            displayQueue = []
            queueDrainTask?.cancel()
        }
    }

    /// The dedicated lightweight provider — never the engine's own instance,
    /// so insight calls can't contend with answer streaming.
    public func setProvider(_ provider: (any HelixAnswerProvider)?, maxResponseSentences: Int = 1) {
        self.provider = provider
        self.maxResponseSentences = maxResponseSentences
    }

    /// Feeds one transcription update. `engineAnswered` marks utterances the
    /// conversation engine already answered — insights skip those entirely
    /// (mutual exclusion, so the HUD never shows two takes on one question).
    public func handleTranscript(_ text: String, isFinal: Bool, engineAnswered: Bool = false) async {
        guard isEnabled else { return }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if engineAnswered {
            recordDedupKey(for: trimmed)
            decisions.append(InsightDecision(outcome: .engineOwned, trigger: isFinal ? "final" : "interim", chunkText: trimmed))
            lastAnalyzedText = trimmed
            return
        }

        guard let trigger = trigger(for: trimmed, isFinal: isFinal) else { return }

        enqueueChunk(trimmed)
        lastAnalyzedText = trimmed
        lastIntervalAnalysisAt = now()
        await analyzePendingChunks(trigger: trigger)
    }

    // MARK: - Triggers (Merge thresholds)

    private func trigger(for text: String, isFinal: Bool) -> String? {
        if isFinal {
            guard text.count >= configuration.minFinalChars, text != lastAnalyzedText else { return nil }
            return "final"
        }

        let sentenceTerminators: Set<Character> = [".", "!", "?", "。", "！", "？"]
        if let last = text.last, sentenceTerminators.contains(last), text.count >= configuration.minSentenceChars,
           text != lastAnalyzedText {
            return "sentence"
        }

        if text.count >= configuration.intervalMinChars,
           now().timeIntervalSince(lastIntervalAnalysisAt) >= configuration.intervalSeconds {
            return "interval"
        }

        return nil
    }

    private func enqueueChunk(_ text: String) {
        pendingChunks.append(text)
        if pendingChunks.count > configuration.maxPendingChunks {
            pendingChunks.removeFirst(pendingChunks.count - configuration.maxPendingChunks)
        }
    }

    // MARK: - Analysis

    private func analyzePendingChunks(trigger: String) async {
        guard let provider, !pendingChunks.isEmpty, !isProcessing else { return }
        let chunk = pendingChunks.joined(separator: "\n")
        pendingChunks = []
        isProcessing = true
        defer { isProcessing = false }

        let request = AnswerRequest(
            question: Self.insightPrompt(for: chunk),
            mode: .passive,
            activeSkill: ActiveSkill.skill(for: ActiveSkill.defaultValue),
            sessionMemoryContext: [],
            maxResponseSentences: maxResponseSentences,
            requiredFacts: [],
            projectContext: [],
            webSearchResults: []
        )

        guard let response = try? await provider.answer(for: request) else {
            decisions.append(InsightDecision(outcome: .silent, trigger: trigger, chunkText: chunk))
            return
        }

        guard let parsed = Self.parseInsightResponse(response.text) else {
            decisions.append(InsightDecision(outcome: .silent, trigger: trigger, chunkText: chunk))
            return
        }

        process(parsed, trigger: trigger, chunk: chunk)
    }

    /// Exposed for tests: run the orchestration on an already-parsed result.
    public func process(_ insight: Insight?, trigger: String, chunk: String) {
        guard let insight else {
            decisions.append(InsightDecision(outcome: .deferred, trigger: trigger, chunkText: chunk))
            return
        }

        let key = Self.normalizedKey(insight.text)
        if recentInsightKeys.contains(key) {
            decisions.append(InsightDecision(outcome: .deduplicated, trigger: trigger, chunkText: chunk, insightText: insight.text))
            return
        }

        if insight.displayAction == .drop {
            decisions.append(InsightDecision(outcome: .dropped, trigger: trigger, chunkText: chunk, insightText: insight.text))
            return
        }

        recordDedupKey(for: insight.text)
        insights.append(insight)
        if insights.count > 50 {
            insights.removeFirst(insights.count - 50)
        }

        let displayBusy = activeDisplayUntil.map { $0 > now() } ?? false
        if !displayBusy {
            display(insight)
            decisions.append(InsightDecision(outcome: .displayed, trigger: trigger, chunkText: chunk, insightText: insight.text))
        } else if insight.urgency == .high || insight.displayAction == .replace {
            display(insight)
            decisions.append(InsightDecision(outcome: .replaced, trigger: trigger, chunkText: chunk, insightText: insight.text))
        } else if displayQueue.count < configuration.maxQueued {
            displayQueue.append(insight)
            scheduleQueueDrain()
            decisions.append(InsightDecision(outcome: .queued, trigger: trigger, chunkText: chunk, insightText: insight.text))
        } else {
            decisions.append(InsightDecision(outcome: .dropped, trigger: trigger, chunkText: chunk, insightText: insight.text))
        }
    }

    // MARK: - Display orchestration

    private func display(_ insight: Insight) {
        activeInsight = insight
        activeDisplayUntil = now().addingTimeInterval(configuration.displaySeconds)
        onDisplay?(insight)
    }

    private func scheduleQueueDrain() {
        guard queueDrainTask == nil else { return }
        let delay = max(0, activeDisplayUntil?.timeIntervalSince(now()) ?? 0)
        queueDrainTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            await self?.drainQueue()
        }
    }

    private func drainQueue() {
        queueDrainTask = nil
        guard !displayQueue.isEmpty else { return }
        let next = displayQueue.removeFirst()
        display(next)
        if !displayQueue.isEmpty {
            scheduleQueueDrain()
        }
    }

    private func recordDedupKey(for text: String) {
        recentInsightKeys.append(Self.normalizedKey(text))
        if recentInsightKeys.count > configuration.dedupWindow {
            recentInsightKeys.removeFirst(recentInsightKeys.count - configuration.dedupWindow)
        }
    }

    // MARK: - Prompt & parsing

    static func insightPrompt(for chunk: String) -> String {
        """
        You monitor a live conversation and decide whether a short proactive \
        insight would help the wearer. Reply with STRICT JSON only, no prose: \
        {"type":"insight"|"defer"|"silent","text":"...","displayAction":"show"|"replace"|"queue"|"drop","urgency":"low"|"medium"|"high","confidence":0.0}
        Only produce type "insight" for genuinely useful facts, corrections, \
        or context. Prefer "silent" for small talk. Transcript chunk:
        \(chunk)
        """
    }

    public static func parseInsightResponse(_ text: String) -> Insight? {
        // Providers occasionally wrap JSON in code fences or prose — extract
        // the outermost object defensively.
        guard let start = text.firstIndex(of: "{"), let end = text.lastIndex(of: "}") else { return nil }
        let json = String(text[start...end])
        guard let data = json.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = object["type"] as? String else { return nil }

        guard type == "insight", let insightText = object["text"] as? String,
              !insightText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }

        return Insight(
            text: insightText.trimmingCharacters(in: .whitespacesAndNewlines),
            displayAction: (object["displayAction"] as? String).flatMap(InsightDisplayAction.init(rawValue:)) ?? .show,
            urgency: (object["urgency"] as? String).flatMap(InsightUrgency.init(rawValue:)) ?? .low,
            confidence: object["confidence"] as? Double ?? 0
        )
    }

    static func normalizedKey(_ text: String) -> String {
        text.lowercased()
            .replacingOccurrences(of: "[^a-z0-9 ]", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
