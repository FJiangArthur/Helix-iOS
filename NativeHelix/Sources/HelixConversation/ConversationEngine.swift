import Foundation
import HelixAI
import HelixCore
import HelixG1
import HelixPersistence
import HelixSpeech

public struct ConversationTurnResult: Equatable, Sendable {
    public var segment: TranscriptSegment
    public var question: QuestionCandidate?
    public var answer: AnswerResponse?
    public var passiveReminder: PassiveReminder?
    public var passiveTrigger: PassiveTriggerResult?
    public var hudPages: [G1HudPage]
    public var metrics: [RealtimeTurnMetrics]

    public init(
        segment: TranscriptSegment,
        question: QuestionCandidate?,
        answer: AnswerResponse?,
        passiveReminder: PassiveReminder?,
        passiveTrigger: PassiveTriggerResult? = nil,
        hudPages: [G1HudPage] = [],
        metrics: [RealtimeTurnMetrics] = []
    ) {
        self.segment = segment
        self.question = question
        self.answer = answer
        self.passiveReminder = passiveReminder
        self.passiveTrigger = passiveTrigger
        self.hudPages = hudPages
        self.metrics = metrics
    }
}

public enum NativeConversationEvent: Equatable, Sendable {
    case transcriptionStarted(URL)
    case transcriptFinal(TranscriptSegment)
    case questionDetected(QuestionCandidate)
    case answerStarted(QuestionCandidate)
    case answerChunk(String)
    case answerCompleted(AnswerResponse)
    case passiveReminder(PassiveReminder)
    case passiveTrigger(PassiveTriggerResult)
    case hudPagesUpdated([G1HudPage])
    case latencyMetric(RealtimeTurnMetrics)
    case suppressed(String)
}

public struct PassiveCorrectionDetector: Sendable {
    private let falseClaims: [String: String]

    public init(falseClaims: [String: String] = [
        "rag means random answer generation": "RAG means retrieval augmented generation."
    ]) {
        self.falseClaims = falseClaims
    }

    public func reminder(for segment: TranscriptSegment, finalizedAt: Date = Date()) -> PassiveReminder? {
        let lowercased = segment.text.lowercased()
        guard let match = falseClaims.first(where: { lowercased.contains($0.key) }) else {
            return nil
        }
        let finalized = segment.finalizedAt ?? finalizedAt
        let latency = max(0, Int(finalizedAt.timeIntervalSince(finalized) * 1000))
        return PassiveReminder(claim: match.key, reminder: match.value, latencyMs: latency)
    }
}

public actor NativeConversationEngine {
    private let settings: HelixSettings
    private let audioFileTranscriber: AudioFileTranscriber
    private let answerProvider: HelixAnswerProvider
    private let webSearchService: WebSearchService
    private let conversationStore: ConversationStore
    private let knowledgeStore: ProjectKnowledgeStore?
    private let questionDetector: QuestionDetector
    private let duplicateSuppressor: DuplicateQuestionSuppressor
    private let passiveCorrectionDetector: PassiveCorrectionDetector
    private let passiveTriggerClassifier: any PassiveTriggerClassifying
    private let hudPresenter: G1HudPresenter
    private var answeredQuestionKeys: Set<String> = []
    private var sessionMemory: SessionMemory
    private var latencyMetrics: [RealtimeTurnMetrics] = []

    public init(
        settings: HelixSettings = HelixSettings(),
        audioFileTranscriber: AudioFileTranscriber = DeterministicAudioFileTranscriber(),
        answerProvider: HelixAnswerProvider,
        webSearchService: WebSearchService = DisabledWebSearchService(),
        conversationStore: ConversationStore,
        knowledgeStore: ProjectKnowledgeStore? = nil,
        questionDetector: QuestionDetector = QuestionDetector(),
        duplicateSuppressor: DuplicateQuestionSuppressor = DuplicateQuestionSuppressor(),
        passiveCorrectionDetector: PassiveCorrectionDetector = PassiveCorrectionDetector(),
        passiveTriggerClassifier: any PassiveTriggerClassifying = PassiveTriggerClassifier(),
        hudPresenter: G1HudPresenter = G1HudPresenter(),
        sessionMemory: SessionMemory = SessionMemory()
    ) {
        self.settings = settings
        self.audioFileTranscriber = audioFileTranscriber
        self.answerProvider = answerProvider
        self.webSearchService = webSearchService
        self.conversationStore = conversationStore
        self.knowledgeStore = knowledgeStore
        self.questionDetector = questionDetector
        self.duplicateSuppressor = duplicateSuppressor
        self.passiveCorrectionDetector = passiveCorrectionDetector
        self.passiveTriggerClassifier = passiveTriggerClassifier
        self.hudPresenter = hudPresenter
        self.sessionMemory = sessionMemory
    }

    public func processAudioFile(
        at url: URL,
        mode: ConversationMode,
        projectID: String? = nil,
        projectFacts: [String] = []
    ) -> AsyncThrowingStream<NativeConversationEvent, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    try await self.runAudioFilePipeline(
                        at: url,
                        mode: mode,
                        projectID: projectID,
                        projectFacts: projectFacts,
                        continuation: continuation
                    )
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    public func processFinalSegment(_ segment: TranscriptSegment, mode: ConversationMode) async throws -> ConversationTurnResult {
        await conversationStore.save(segment: segment)
        sessionMemory.appendTranscript(segment.text)

        if mode == .passive {
            let reminder = passiveCorrectionDetector.reminder(for: segment)
            if let reminder {
                sessionMemory.appendPassiveReminder(reminder)
            }
            let correctionMetric = recordMetric(
                area: "passive-correction",
                start: segment.finalizedAt ?? Date(),
                reportOnly: true
            )
            guard reminder == nil else {
                return ConversationTurnResult(
                    segment: segment,
                    question: nil,
                    answer: nil,
                    passiveReminder: reminder,
                    hudPages: reminder.map { hudPresenter.textPages(for: $0.reminder) } ?? [],
                    metrics: [correctionMetric]
                )
            }

            let triggerStart = Date()
            let trigger = try await passiveTriggerClassifier.decision(
                for: segment,
                transcriptWindow: sessionMemory.transcriptWindow(),
                settings: settings
            )
            let triggerMetric = recordMetric(area: "passive-trigger", start: triggerStart, reportOnly: true)
            guard trigger.action == .answer else {
                sessionMemory.appendSuppression("Passive \(trigger.action.rawValue): \(trigger.reason)")
                return ConversationTurnResult(
                    segment: segment,
                    question: nil,
                    answer: nil,
                    passiveReminder: nil,
                    passiveTrigger: trigger,
                    metrics: [triggerMetric]
                )
            }

            let question = passiveQuestionCandidate(from: segment, trigger: trigger)
            guard markQuestionIfNew(question.text), settings.autoAnswer else {
                sessionMemory.appendSuppression("Passive answer suppressed.")
                return ConversationTurnResult(
                    segment: segment,
                    question: question,
                    answer: nil,
                    passiveReminder: nil,
                    passiveTrigger: trigger,
                    metrics: [triggerMetric]
                )
            }

            let answerStart = Date()
            let request = try await makeAnswerRequest(question: question.text, mode: .passive)
            let answer = try await answerProvider.answer(for: request)
            let answerMetric = recordMetric(area: "passive-answer", start: answerStart, reportOnly: true)
            await conversationStore.save(answer: answer, for: question)
            remember(question: question.text, answer: answer)
            return ConversationTurnResult(
                segment: segment,
                question: question,
                answer: answer,
                passiveReminder: nil,
                passiveTrigger: trigger,
                hudPages: hudPresenter.textPages(for: answer.text),
                metrics: [triggerMetric, answerMetric]
            )
        }

        guard settings.autoDetectQuestions else {
            return ConversationTurnResult(segment: segment, question: nil, answer: nil, passiveReminder: nil)
        }

        let candidates = duplicateSuppressor.uniqueQuestions(questionDetector.detectQuestions(in: segment.text))
        guard let question = candidates.first, markQuestionIfNew(question.text), settings.autoAnswer else {
            return ConversationTurnResult(segment: segment, question: candidates.first, answer: nil, passiveReminder: nil)
        }

        let request = try await makeAnswerRequest(question: question.text, mode: mode)
        let answer = try await answerProvider.answer(for: request)
        await conversationStore.save(answer: answer, for: question)
        remember(question: question.text, answer: answer)
        return ConversationTurnResult(
            segment: segment,
            question: question,
            answer: answer,
            passiveReminder: nil,
            hudPages: hudPresenter.textPages(for: answer.text)
        )
    }

    public func answerActiveQuestion(
        _ question: String,
        mode: ConversationMode = .general,
        projectID: String? = nil,
        projectFacts: [String] = []
    ) async throws -> AnswerResponse {
        var facts = projectFacts
        if let projectID, let knowledgeStore {
            facts.append(contentsOf: await knowledgeStore.facts(for: projectID, question: question))
        }

        let request = try await makeAnswerRequest(
            question: question,
            mode: mode,
            projectFacts: facts
        )
        let answer = try await answerProvider.answer(for: request)
        remember(question: question, answer: answer)
        return answer
    }

    public func answerActiveQuestionTurn(
        _ question: String,
        mode: ConversationMode = .general,
        projectID: String? = nil,
        projectFacts: [String] = []
    ) async throws -> (answer: AnswerResponse, hudPages: [G1HudPage]) {
        let answer = try await answerActiveQuestion(
            question,
            mode: mode,
            projectID: projectID,
            projectFacts: projectFacts
        )
        return (answer, hudPresenter.textPages(for: answer.text))
    }

    public func currentSessionMemory() -> SessionMemory {
        sessionMemory
    }

    public func currentLatencyMetrics() -> [RealtimeTurnMetrics] {
        latencyMetrics
    }

    public func currentActiveSkill() -> ActiveSkill {
        settings.activeSkill
    }

    private func markQuestionIfNew(_ question: String) -> Bool {
        let key = question
            .lowercased()
            .replacingOccurrences(of: "[^a-z0-9 ]", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return answeredQuestionKeys.insert(key).inserted
    }

    private func makeAnswerRequest(
        question: String,
        mode: ConversationMode,
        projectFacts: [String] = []
    ) async throws -> AnswerRequest {
        let webResults = try await webSearchResults(for: question)
        return AnswerRequest(
            question: question,
            mode: mode,
            activeSkill: settings.activeSkill,
            sessionMemoryContext: sessionMemory.contextLines(),
            maxResponseSentences: settings.maxResponseSentences,
            requiredFacts: projectFacts,
            projectContext: projectFacts,
            webSearchResults: webResults
        )
    }

    private func passiveQuestionCandidate(
        from segment: TranscriptSegment,
        trigger: PassiveTriggerResult
    ) -> QuestionCandidate {
        questionDetector.detectQuestions(in: segment.text).first
            ?? QuestionCandidate(text: segment.text, confidence: trigger.confidence)
    }

    private func remember(question: String, answer: AnswerResponse) {
        sessionMemory.appendQuestion(question, skillValue: settings.activeSkillID)
        sessionMemory.appendAnswer(answer, skillValue: settings.activeSkillID)
    }

    private func recordMetric(area: String, start: Date, reportOnly: Bool = false) -> RealtimeTurnMetrics {
        let metric = RealtimeTurnMetrics(
            area: area,
            latencyMs: Int(max(0, Date().timeIntervalSince(start) * 1000)),
            reportOnly: reportOnly
        )
        latencyMetrics.append(metric)
        if latencyMetrics.count > 20 {
            latencyMetrics = Array(latencyMetrics.suffix(20))
        }
        return metric
    }

    private func webSearchResults(for question: String) async throws -> [WebSearchResult] {
        switch settings.webSearchMode {
        case .disabled:
            return []
        case .fakeDeterministic, .live:
            return try await webSearchService.search(question: question)
        }
    }

    private func runAudioFilePipeline(
        at url: URL,
        mode: ConversationMode,
        projectID: String?,
        projectFacts: [String],
        continuation: AsyncThrowingStream<NativeConversationEvent, Error>.Continuation
    ) async throws {
        continuation.yield(.transcriptionStarted(url))
        let segment = try await audioFileTranscriber.transcribeAudioFile(
            at: url,
            backend: settings.transcriptionBackend,
            model: settings.transcriptionModel
        )
        await conversationStore.save(segment: segment)
        sessionMemory.appendTranscript(segment.text)
        continuation.yield(.transcriptFinal(segment))

        if mode == .passive {
            if let reminder = passiveCorrectionDetector.reminder(for: segment) {
                sessionMemory.appendPassiveReminder(reminder)
                continuation.yield(.latencyMetric(recordMetric(area: "passive-correction", start: segment.finalizedAt ?? Date(), reportOnly: true)))
                continuation.yield(.passiveReminder(reminder))
                continuation.yield(.hudPagesUpdated(hudPresenter.textPages(for: reminder.reminder)))
            } else {
                let triggerStart = Date()
                let trigger = try await passiveTriggerClassifier.decision(
                    for: segment,
                    transcriptWindow: sessionMemory.transcriptWindow(),
                    settings: settings
                )
                continuation.yield(.latencyMetric(recordMetric(area: "passive-trigger", start: triggerStart, reportOnly: true)))
                continuation.yield(.passiveTrigger(trigger))
                guard trigger.action == .answer else {
                    let reason = "Passive \(trigger.action.rawValue): \(trigger.reason)"
                    sessionMemory.appendSuppression(reason)
                    continuation.yield(.suppressed(reason))
                    return
                }

                let question = passiveQuestionCandidate(from: segment, trigger: trigger)
                continuation.yield(.questionDetected(question))
                guard markQuestionIfNew(question.text) else {
                    let reason = "Duplicate passive question suppressed."
                    sessionMemory.appendSuppression(reason)
                    continuation.yield(.suppressed(reason))
                    return
                }

                guard settings.autoAnswer else {
                    let reason = "Passive auto-answer disabled."
                    sessionMemory.appendSuppression(reason)
                    continuation.yield(.suppressed(reason))
                    return
                }

                try await streamAnswer(
                    for: question,
                    mode: .passive,
                    projectFacts: projectFacts,
                    continuation: continuation
                )
            }
            return
        }

        guard settings.autoDetectQuestions else {
            continuation.yield(.suppressed("Question detection disabled."))
            return
        }

        let candidates = duplicateSuppressor.uniqueQuestions(questionDetector.detectQuestions(in: segment.text))
        guard let question = candidates.first else {
            continuation.yield(.suppressed("No question detected."))
            return
        }

        continuation.yield(.questionDetected(question))
        guard markQuestionIfNew(question.text) else {
            continuation.yield(.suppressed("Duplicate question suppressed."))
            return
        }

        guard settings.autoAnswer else {
            continuation.yield(.suppressed("Auto-answer disabled."))
            return
        }

        var facts = projectFacts
        if let projectID, let knowledgeStore {
            facts.append(contentsOf: await knowledgeStore.facts(for: projectID, question: question.text))
        }
        try await streamAnswer(
            for: question,
            mode: mode,
            projectFacts: facts,
            continuation: continuation
        )
    }

    private func streamAnswer(
        for question: QuestionCandidate,
        mode: ConversationMode,
        projectFacts: [String],
        continuation: AsyncThrowingStream<NativeConversationEvent, Error>.Continuation
    ) async throws {
        continuation.yield(.answerStarted(question))
        let request = try await makeAnswerRequest(
            question: question.text,
            mode: mode,
            projectFacts: projectFacts
        )
        let answerStart = Date()
        var chunks: [String] = []
        for try await chunk in answerProvider.streamAnswer(for: request) {
            chunks.append(chunk)
            continuation.yield(.answerChunk(chunk))
        }
        continuation.yield(.latencyMetric(recordMetric(area: "\(mode.rawValue)-answer", start: answerStart, reportOnly: true)))
        let answer = AnswerResponse(
            text: chunks.joined(),
            provider: answerProvider.kind,
            model: answerProvider.model,
            citations: request.citationSources
        )
        await conversationStore.save(answer: answer, for: question)
        remember(question: question.text, answer: answer)
        continuation.yield(.answerCompleted(answer))
        continuation.yield(.hudPagesUpdated(hudPresenter.textPages(for: answer.text)))
    }
}
