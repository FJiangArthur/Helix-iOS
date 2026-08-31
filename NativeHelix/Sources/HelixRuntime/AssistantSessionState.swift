import Foundation
import HelixAI
import HelixConversation
import HelixCore
import HelixG1
import Observation

public struct NativeLiveTranscriptOutcome: Equatable, Sendable {
    public var conversationGeneration: UInt64
    public var sequence: UInt64
    public var segment: TranscriptSegment
    public var turn: ConversationTurnResult?
    public var failureReason: String?
    public var isMetadataUpdate: Bool

    public init(
        conversationGeneration: UInt64 = 0,
        sequence: UInt64,
        segment: TranscriptSegment,
        turn: ConversationTurnResult? = nil,
        failureReason: String? = nil,
        isMetadataUpdate: Bool = false
    ) {
        self.conversationGeneration = conversationGeneration
        self.sequence = sequence
        self.segment = segment
        self.turn = turn
        self.failureReason = failureReason
        self.isMetadataUpdate = isMetadataUpdate
    }

    public var answered: Bool {
        turn?.questionResults.contains(where: { $0.answer != nil }) == true
            || turn?.answer != nil
    }
}

private struct LiveSpeakerMetadata: Sendable {
    var speaker: String
    var source: TranscriptSpeakerSource?
    var confidence: Double?
}

@MainActor
@Observable
public final class NativeAssistantSessionState {
    public private(set) var mode: ConversationMode
    public private(set) var isRunning = false
    public private(set) var isListening = false
    public private(set) var transcriptText = ""
    public private(set) var detectedQuestion = ""
    public private(set) var currentAnswer = ""
    public private(set) var currentAnswerProvider = ""
    public private(set) var currentAnswerModel = ""
    public private(set) var answerDepth: AnswerDepth = .automatic
    public private(set) var passiveReminder = ""
    public private(set) var passiveTriggerSummary = ""
    public private(set) var activeSkill = ActiveSkill.skill(for: ActiveSkill.defaultValue)
    public private(set) var sessionMemory = SessionMemory()
    public private(set) var latencyMetrics: [RealtimeTurnMetrics] = []
    public private(set) var hudPages: [G1HudPage] = []
    public private(set) var lastSuppression = ""
    public private(set) var failureReason = ""
    public private(set) var eventLog: [String] = []
    /// Ordered, durable-in-memory outcomes for finalized live transcript turns.
    /// Consumers diff by `sequence`; even when Observation coalesces rapid
    /// mutations, every question in `turn.questionResults` remains available.
    public private(set) var committedLiveTranscriptOutcomes: [NativeLiveTranscriptOutcome] = []

    private let engine: NativeConversationEngine
    private var nextLiveTranscriptSequence: UInt64 = 0
    private var nextLiveTranscriptSequenceToApply: UInt64 = 0
    private var completedLiveTranscriptOutcomes: [UInt64: NativeLiveTranscriptOutcome] = [:]
    private var activeLiveTranscriptCount = 0
    private var liveConversationGeneration: UInt64 = 0
    private var activeLiveSegmentSequences: [String: UInt64] = [:]
    private var liveSegmentKeyBySequence: [UInt64: String] = [:]
    private var pendingSpeakerMetadata: [UInt64: LiveSpeakerMetadata] = [:]
    @ObservationIgnored
    private var liveTranscriptCommitHandler: ((NativeLiveTranscriptOutcome) -> Void)?
    @ObservationIgnored
    private var liveTranscriptCommitObservers: [
        UUID: (NativeLiveTranscriptOutcome) -> Void
    ] = [:]

    public init(
        engine: NativeConversationEngine,
        mode: ConversationMode = .general
    ) {
        self.engine = engine
        self.mode = mode
    }

    public var statusText: String {
        if isRunning { return "Running" }
        if !failureReason.isEmpty { return "Failed" }
        if !currentAnswer.isEmpty { return "Answered" }
        if !passiveReminder.isEmpty { return "Reminder ready" }
        return "Ready"
    }

    public var hudSummary: String {
        hudPages.isEmpty ? "No pages" : "\(hudPages.count) page\(hudPages.count == 1 ? "" : "s")"
    }

    public var memorySummary: String {
        "\(sessionMemory.entries.count) recent item\(sessionMemory.entries.count == 1 ? "" : "s")"
    }

    public var latencySummary: String {
        guard let latest = latencyMetrics.last else { return "No latency data" }
        return "\(latest.area): \(latest.latencyMs) ms"
    }

    public func setMode(_ mode: ConversationMode) {
        self.mode = mode
    }

    public func setListening(_ isListening: Bool) {
        self.isListening = isListening
        eventLog.append(isListening ? "listeningStarted" : "listeningStopped")
    }

    public func updateEngineSettings(_ settings: HelixSettings) async {
        await engine.updateSettings(settings)
    }

    public func setAnswerProvider(_ provider: any HelixAnswerProvider) async {
        await engine.setAnswerProvider(provider)
    }

    public func setDeepAnswerProvider(_ provider: any HelixAnswerProvider) async {
        await engine.setDeepAnswerProvider(provider)
    }

    public func setQuestionClassifier(_ classifier: any QuestionClassifying) async {
        await engine.setQuestionClassifier(classifier)
    }

    public func currentQuestionClassifierDescription() async -> String {
        await engine.currentQuestionClassifierDescription()
    }

    public func currentAutomaticAnswerProviderDescription() async -> String {
        await engine.currentAnswerProviderDescription()
    }

    public func currentDeepAnswerProviderDescription() async -> String {
        await engine.currentDeepAnswerProviderDescription()
    }

    public func setLiveTranscriptCommitHandler(
        _ handler: ((NativeLiveTranscriptOutcome) -> Void)?
    ) {
        liveTranscriptCommitHandler = handler
    }

    /// Adds a commit observer without displacing another runtime consumer.
    /// Automatic Knowledge capture and the G1 bridge both need every ordered
    /// outcome, even when no Assistant view is mounted.
    @discardableResult
    public func addLiveTranscriptCommitHandler(
        _ handler: @escaping (NativeLiveTranscriptOutcome) -> Void
    ) -> UUID {
        let id = UUID()
        liveTranscriptCommitObservers[id] = handler
        return id
    }

    public func removeLiveTranscriptCommitHandler(id: UUID) {
        liveTranscriptCommitObservers.removeValue(forKey: id)
    }

    /// Feeds one finalized live-transcription segment through the conversation
    /// pipeline. Unlike `ask`/`runAudioFixture`, state is merged (not reset) so
    /// an ongoing listening session accumulates transcript, questions, and
    /// answers turn by turn.
    @discardableResult
    public func processLiveTranscript(
        _ text: String,
        sourceSegmentID: String? = nil,
        speaker: String? = nil,
        speakerSource: TranscriptSpeakerSource? = nil,
        speakerConfidence: Double? = nil
    ) async -> NativeLiveTranscriptOutcome? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let normalizedSpeaker = speaker?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let normalizedSpeaker, !normalizedSpeaker.isEmpty {
            let enrichment = await enrichLiveSegmentIfPresent(
                text: trimmed,
                sourceSegmentID: sourceSegmentID,
                metadata: LiveSpeakerMetadata(
                    speaker: normalizedSpeaker,
                    source: speakerSource,
                    confidence: speakerConfidence
                )
            )
            if enrichment.handled { return enrichment.outcome }
        }

        let segment = TranscriptSegment(
            text: trimmed,
            isFinal: true,
            startedAt: Date(),
            finalizedAt: Date(),
            sourceSegmentID: sourceSegmentID,
            speaker: normalizedSpeaker,
            speakerSource: speakerSource,
            speakerConfidence: speakerConfidence
        )
        let sequence = nextLiveTranscriptSequence
        let conversationGeneration = liveConversationGeneration
        let segmentKey = liveSegmentKey(text: trimmed, sourceSegmentID: sourceSegmentID)
        nextLiveTranscriptSequence += 1
        activeLiveSegmentSequences[segmentKey] = sequence
        liveSegmentKeyBySequence[sequence] = segmentKey
        transcriptText = trimmed
        eventLog.append("transcriptFinal")
        activeLiveTranscriptCount += 1
        isRunning = true

        var outcome: NativeLiveTranscriptOutcome
        do {
            let turn = try await engine.processFinalSegment(
                segment,
                mode: mode,
                livePreparationSequence: sequence
            )
            outcome = NativeLiveTranscriptOutcome(
                conversationGeneration: conversationGeneration,
                sequence: sequence,
                segment: segment,
                turn: turn
            )
        } catch {
            outcome = NativeLiveTranscriptOutcome(
                conversationGeneration: conversationGeneration,
                sequence: sequence,
                segment: segment,
                failureReason: error.localizedDescription
            )
        }

        // A provider from the previous conversation may finish after the user
        // clears the session. Its result is intentionally returned to its caller
        // for diagnostics, but can never repopulate observable UI state.
        guard conversationGeneration == liveConversationGeneration else {
            return outcome
        }
        if let metadata = pendingSpeakerMetadata.removeValue(forKey: sequence) {
            outcome = outcome.applyingSpeakerMetadata(metadata, isUpdate: false)
            await engine.updateTranscriptMetadata(outcome.segment)
        }
        completedLiveTranscriptOutcomes[sequence] = outcome
        applyCompletedLiveTranscriptOutcomesInOrder()
        activeLiveTranscriptCount -= 1
        isRunning = activeLiveTranscriptCount > 0
        await refreshRuntimeState(ifCurrent: conversationGeneration)
        return outcome
    }

    /// Starts a clean conversation and invalidates every in-flight live turn.
    /// Late provider completions from the old generation are discarded.
    public func startNewConversation() async {
        liveConversationGeneration &+= 1
        let conversationGeneration = liveConversationGeneration
        nextLiveTranscriptSequence = 0
        nextLiveTranscriptSequenceToApply = 0
        completedLiveTranscriptOutcomes.removeAll()
        committedLiveTranscriptOutcomes.removeAll()
        activeLiveSegmentSequences.removeAll()
        liveSegmentKeyBySequence.removeAll()
        pendingSpeakerMetadata.removeAll()
        activeLiveTranscriptCount = 0
        isRunning = false
        resetForRun(mode: mode)
        await engine.resetSession()
        await refreshRuntimeState(ifCurrent: conversationGeneration)
    }

    public func runAudioFixture(
        at url: URL,
        mode requestedMode: ConversationMode? = nil,
        projectID: String? = nil,
        projectFacts: [String] = []
    ) async {
        let fixtureGeneration = liveConversationGeneration
        let runMode = requestedMode ?? mode
        resetForRun(mode: runMode)
        isRunning = true
        defer {
            if fixtureGeneration == liveConversationGeneration {
                isRunning = false
            }
        }

        do {
            let stream = await engine.processAudioFile(
                at: url,
                mode: runMode,
                projectID: projectID,
                projectFacts: projectFacts
            )
            for try await event in stream {
                guard fixtureGeneration == liveConversationGeneration else { return }
                apply(event)
            }
            guard fixtureGeneration == liveConversationGeneration else { return }
            await refreshRuntimeState(ifCurrent: fixtureGeneration)
        } catch {
            guard fixtureGeneration == liveConversationGeneration else { return }
            failureReason = error.localizedDescription
            eventLog.append("failure")
        }
    }

    @discardableResult
    public func ask(
        _ question: String,
        mode requestedMode: ConversationMode? = nil,
        projectID: String? = nil,
        projectFacts: [String] = []
    ) async -> AnswerResponse? {
        let trimmedQuestion = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuestion.isEmpty else {
            lastSuppression = "Empty question suppressed."
            eventLog.append("suppressed")
            return nil
        }

        let operationGeneration = liveConversationGeneration
        let runMode = requestedMode ?? mode
        resetForRun(mode: runMode)
        detectedQuestion = trimmedQuestion
        isRunning = true
        eventLog.append("manualQuestion")
        defer {
            if operationGeneration == liveConversationGeneration {
                isRunning = false
            }
        }

        do {
            let turn = try await engine.answerActiveQuestionTurn(
                trimmedQuestion,
                mode: runMode,
                projectID: projectID,
                projectFacts: projectFacts
            )
            guard operationGeneration == liveConversationGeneration else { return nil }
            currentAnswer = turn.answer.text
            currentAnswerProvider = turn.answer.provider.rawValue
            currentAnswerModel = turn.answer.model
            answerDepth = .automatic
            hudPages = turn.hudPages
            eventLog.append("answerCompleted")
            eventLog.append("hudPagesUpdated")
            await refreshRuntimeState(ifCurrent: operationGeneration)
            guard operationGeneration == liveConversationGeneration else { return nil }
            return turn.answer
        } catch {
            guard operationGeneration == liveConversationGeneration else { return nil }
            failureReason = error.localizedDescription
            eventLog.append("failure")
            return nil
        }
    }

    /// Re-answers a question with the separately configured smart/reasoning
    /// provider. Automatic live answers continue to use the light provider.
    @discardableResult
    public func askDeeper(
        _ question: String,
        mode requestedMode: ConversationMode? = nil,
        projectID: String? = nil,
        projectFacts: [String] = []
    ) async -> AnswerResponse? {
        let trimmedQuestion = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuestion.isEmpty else {
            lastSuppression = "Empty question suppressed."
            eventLog.append("suppressed")
            return nil
        }

        let operationGeneration = liveConversationGeneration
        let runMode = requestedMode ?? mode
        mode = runMode
        detectedQuestion = trimmedQuestion
        currentAnswer = ""
        currentAnswerProvider = ""
        currentAnswerModel = ""
        answerDepth = .deeper
        failureReason = ""
        isRunning = true
        eventLog.append("deepAnswerStarted")
        defer {
            if operationGeneration == liveConversationGeneration {
                isRunning = false
            }
        }

        do {
            let turn = try await engine.answerActiveQuestionDeepTurn(
                trimmedQuestion,
                mode: runMode,
                projectID: projectID,
                projectFacts: projectFacts
            )
            guard operationGeneration == liveConversationGeneration else { return nil }
            currentAnswer = turn.answer.text
            currentAnswerProvider = turn.answer.provider.rawValue
            currentAnswerModel = turn.answer.model
            hudPages = turn.hudPages
            eventLog.append("deepAnswerCompleted")
            eventLog.append("hudPagesUpdated")
            await refreshRuntimeState(ifCurrent: operationGeneration)
            guard operationGeneration == liveConversationGeneration else { return nil }
            return turn.answer
        } catch {
            guard operationGeneration == liveConversationGeneration else { return nil }
            failureReason = error.localizedDescription
            eventLog.append("failure")
            return nil
        }
    }

    public func apply(_ event: NativeConversationEvent) {
        switch event {
        case .transcriptionStarted(let url):
            eventLog.append("transcriptionStarted:\(url.lastPathComponent)")
        case .transcriptFinal(let segment):
            transcriptText = segment.text
            eventLog.append("transcriptFinal")
        case .questionDetected(let question):
            detectedQuestion = question.text
            eventLog.append("questionDetected")
        case .answerStarted:
            currentAnswer = ""
            eventLog.append("answerStarted")
        case .answerChunk(let chunk):
            currentAnswer += chunk
            eventLog.append("answerChunk")
        case .answerCompleted(let answer):
            currentAnswer = answer.text
            currentAnswerProvider = answer.provider.rawValue
            currentAnswerModel = answer.model
            answerDepth = .automatic
            eventLog.append("answerCompleted")
        case .passiveReminder(let reminder):
            passiveReminder = reminder.reminder
            eventLog.append("passiveReminder")
        case .passiveTrigger(let trigger):
            passiveTriggerSummary = "\(trigger.action.rawValue): \(trigger.reason)"
            eventLog.append("passiveTrigger")
        case .hudPagesUpdated(let pages):
            hudPages = pages
            eventLog.append("hudPagesUpdated")
        case .latencyMetric(let metric):
            latencyMetrics.append(metric)
            eventLog.append("latencyMetric")
        case .suppressed(let reason):
            lastSuppression = reason
            eventLog.append("suppressed")
        }
    }

    private func refreshRuntimeState(ifCurrent generation: UInt64? = nil) async {
        let refreshedActiveSkill = await engine.currentActiveSkill()
        let refreshedSessionMemory = await engine.currentSessionMemory()
        let refreshedLatencyMetrics = await engine.currentLatencyMetrics()
        if let generation, generation != liveConversationGeneration { return }
        activeSkill = refreshedActiveSkill
        sessionMemory = refreshedSessionMemory
        latencyMetrics = refreshedLatencyMetrics
    }

    private func enrichLiveSegmentIfPresent(
        text: String,
        sourceSegmentID: String?,
        metadata: LiveSpeakerMetadata
    ) async -> (handled: Bool, outcome: NativeLiveTranscriptOutcome?) {
        let key = liveSegmentKey(text: text, sourceSegmentID: sourceSegmentID)

        if let sequence = activeLiveSegmentSequences[key] {
            if let buffered = completedLiveTranscriptOutcomes[sequence] {
                let updated = buffered.applyingSpeakerMetadata(metadata, isUpdate: false)
                completedLiveTranscriptOutcomes[sequence] = updated
                await engine.updateTranscriptMetadata(updated.segment)
            } else {
                pendingSpeakerMetadata[sequence] = metadata
            }
            return (true, nil)
        }

        if let index = committedLiveTranscriptOutcomes.lastIndex(where: { outcome in
            liveSegmentKey(
                text: outcome.segment.text,
                sourceSegmentID: outcome.segment.sourceSegmentID
            ) == key
        }) {
            let updated = committedLiveTranscriptOutcomes[index]
                .applyingSpeakerMetadata(metadata, isUpdate: true)
            committedLiveTranscriptOutcomes[index] = updated
            await engine.updateTranscriptMetadata(updated.segment)
            eventLog.append("transcriptSpeakerUpdated")
            return (true, updated)
        }

        return (false, nil)
    }

    private func liveSegmentKey(text: String, sourceSegmentID: String?) -> String {
        let sourceID = sourceSegmentID?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !sourceID.isEmpty { return "source:\(sourceID)" }
        let normalizedText = text
            .lowercased()
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
        return "text:\(normalizedText)"
    }

    private func applyCompletedLiveTranscriptOutcomesInOrder() {
        while let outcome = completedLiveTranscriptOutcomes.removeValue(
            forKey: nextLiveTranscriptSequenceToApply
        ) {
            applyLiveTranscriptOutcome(outcome)
            committedLiveTranscriptOutcomes.append(outcome)
            liveTranscriptCommitHandler?(outcome)
            for observer in liveTranscriptCommitObservers.values {
                observer(outcome)
            }
            if let key = liveSegmentKeyBySequence.removeValue(forKey: outcome.sequence),
               activeLiveSegmentSequences[key] == outcome.sequence {
                activeLiveSegmentSequences.removeValue(forKey: key)
            }
            nextLiveTranscriptSequenceToApply += 1
        }
    }

    private func applyLiveTranscriptOutcome(_ outcome: NativeLiveTranscriptOutcome) {
        guard let turn = outcome.turn else {
            failureReason = outcome.failureReason ?? "Live transcript processing failed."
            eventLog.append("failure")
            return
        }

        if let question = turn.question {
            detectedQuestion = question.text
            eventLog.append("questionDetected")
        }
        if let answer = turn.answer {
            currentAnswer = answer.text
            currentAnswerProvider = answer.provider.rawValue
            currentAnswerModel = answer.model
            answerDepth = .automatic
            eventLog.append("answerCompleted")
        }
        if let reminder = turn.passiveReminder {
            passiveReminder = reminder.reminder
            eventLog.append("passiveReminder")
        }
        if let trigger = turn.passiveTrigger {
            passiveTriggerSummary = "\(trigger.action.rawValue): \(trigger.reason)"
            eventLog.append("passiveTrigger")
        }
        if !turn.hudPages.isEmpty {
            hudPages = turn.hudPages
            eventLog.append("hudPagesUpdated")
        }
        failureReason = ""
    }

    private func resetForRun(mode: ConversationMode) {
        self.mode = mode
        transcriptText = ""
        detectedQuestion = ""
        currentAnswer = ""
        currentAnswerProvider = ""
        currentAnswerModel = ""
        answerDepth = .automatic
        passiveReminder = ""
        passiveTriggerSummary = ""
        hudPages = []
        lastSuppression = ""
        failureReason = ""
        eventLog = []
    }
}

private extension NativeLiveTranscriptOutcome {
    func applyingSpeakerMetadata(
        _ metadata: LiveSpeakerMetadata,
        isUpdate: Bool
    ) -> NativeLiveTranscriptOutcome {
        var updated = self
        updated.segment.speaker = metadata.speaker
        updated.segment.speakerSource = metadata.source
        updated.segment.speakerConfidence = metadata.confidence.map { min(1, max(0, $0)) }
        if var turn = updated.turn {
            turn.segment = updated.segment
            updated.turn = turn
        }
        updated.isMetadataUpdate = isUpdate
        return updated
    }
}
