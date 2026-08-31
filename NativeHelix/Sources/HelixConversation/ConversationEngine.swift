import Foundation
import HelixAI
import HelixCore
import HelixG1
import HelixPersistence
import HelixSpeech

public struct ConversationQuestionResult: Equatable, Sendable {
    public var question: QuestionCandidate
    public var answer: AnswerResponse?
    public var hudPages: [G1HudPage]
    public var failureReason: String?
    public var suppressionReason: String?

    public init(
        question: QuestionCandidate,
        answer: AnswerResponse?,
        hudPages: [G1HudPage] = [],
        failureReason: String? = nil,
        suppressionReason: String? = nil
    ) {
        self.question = question
        self.answer = answer
        self.hudPages = hudPages
        self.failureReason = failureReason
        self.suppressionReason = suppressionReason
    }
}

public struct ConversationTurnResult: Equatable, Sendable {
    public var segment: TranscriptSegment
    public var question: QuestionCandidate?
    public var answer: AnswerResponse?
    public var passiveReminder: PassiveReminder?
    public var passiveTrigger: PassiveTriggerResult?
    public var hudPages: [G1HudPage]
    public var metrics: [RealtimeTurnMetrics]
    public var questionResults: [ConversationQuestionResult]

    public init(
        segment: TranscriptSegment,
        question: QuestionCandidate?,
        answer: AnswerResponse?,
        passiveReminder: PassiveReminder?,
        passiveTrigger: PassiveTriggerResult? = nil,
        hudPages: [G1HudPage] = [],
        metrics: [RealtimeTurnMetrics] = [],
        questionResults: [ConversationQuestionResult] = []
    ) {
        self.segment = segment
        self.question = question
        self.answer = answer
        self.passiveReminder = passiveReminder
        self.passiveTrigger = passiveTrigger
        self.hudPages = hudPages
        self.metrics = metrics
        self.questionResults = questionResults
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

private struct QuestionAnswerWork: Sendable {
    var index: Int
    var question: QuestionCandidate
}

private enum ProviderQuestionAnswerOutcome: @unchecked Sendable {
    case success(AnswerResponse)
    case failure(any Error)
}

public actor NativeConversationEngine {
    private var settings: HelixSettings
    private let audioFileTranscriber: AudioFileTranscriber
    private var answerProvider: HelixAnswerProvider
    private var deepAnswerProvider: HelixAnswerProvider
    private let webSearchService: WebSearchService
    private let conversationStore: ConversationStore
    private let knowledgeStore: ProjectKnowledgeStore?
    private let questionDetector: QuestionDetector
    private var questionClassifier: any QuestionClassifying
    private let duplicateSuppressor: DuplicateQuestionSuppressor
    private let passiveCorrectionDetector: PassiveCorrectionDetector
    private let passiveTriggerClassifier: any PassiveTriggerClassifying
    private let hudPresenter: G1HudPresenter
    private var answeredQuestionKeys: Set<String> = []
    private var pendingQuestionKeys: Set<String> = []
    private var sessionMemory: SessionMemory
    private var latencyMetrics: [RealtimeTurnMetrics] = []
    private var sessionGeneration: UInt64 = 0
    private var nextLivePreparationSequence: UInt64 = 0
    private var livePreparationWaiters: [UInt64: [CheckedContinuation<Void, Never>]] = [:]

    public init(
        settings: HelixSettings = HelixSettings(),
        audioFileTranscriber: AudioFileTranscriber = DeterministicAudioFileTranscriber(),
        answerProvider: HelixAnswerProvider,
        deepAnswerProvider: HelixAnswerProvider? = nil,
        webSearchService: WebSearchService = DisabledWebSearchService(),
        conversationStore: ConversationStore,
        knowledgeStore: ProjectKnowledgeStore? = nil,
        questionDetector: QuestionDetector = QuestionDetector(),
        questionClassifier: (any QuestionClassifying)? = nil,
        duplicateSuppressor: DuplicateQuestionSuppressor = DuplicateQuestionSuppressor(),
        passiveCorrectionDetector: PassiveCorrectionDetector = PassiveCorrectionDetector(),
        passiveTriggerClassifier: any PassiveTriggerClassifying = PassiveTriggerClassifier(),
        hudPresenter: G1HudPresenter = G1HudPresenter(),
        sessionMemory: SessionMemory = SessionMemory()
    ) {
        self.settings = settings
        self.audioFileTranscriber = audioFileTranscriber
        self.answerProvider = answerProvider
        self.deepAnswerProvider = deepAnswerProvider ?? answerProvider
        self.webSearchService = webSearchService
        self.conversationStore = conversationStore
        self.knowledgeStore = knowledgeStore
        self.questionDetector = questionDetector
        self.questionClassifier = questionClassifier ?? HybridQuestionClassifier(
            heuristicDetector: questionDetector,
            duplicateSuppressor: duplicateSuppressor
        )
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

    public func processFinalSegment(
        _ segment: TranscriptSegment,
        mode: ConversationMode,
        livePreparationSequence: UInt64? = nil
    ) async throws -> ConversationTurnResult {
        let generation = sessionGeneration
        if let livePreparationSequence {
            await waitForLivePreparationTurn(livePreparationSequence)
            try ensureCurrentSession(generation)
        }
        defer {
            if let livePreparationSequence {
                completeLivePreparation(livePreparationSequence, generation: generation)
            }
        }
        await conversationStore.save(segment: segment)
        try ensureCurrentSession(generation)
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
                if let livePreparationSequence {
                    completeLivePreparation(livePreparationSequence, generation: generation)
                }
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
            try ensureCurrentSession(generation)
            let triggerMetric = recordMetric(area: "passive-trigger", start: triggerStart, reportOnly: true)
            guard trigger.action == .answer else {
                sessionMemory.appendSuppression("Passive \(trigger.action.rawValue): \(trigger.reason)")
                if let livePreparationSequence {
                    completeLivePreparation(livePreparationSequence, generation: generation)
                }
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
            guard settings.autoAnswer, reserveQuestionIfAvailable(question.text) else {
                sessionMemory.appendSuppression("Passive answer suppressed.")
                if let livePreparationSequence {
                    completeLivePreparation(livePreparationSequence, generation: generation)
                }
                return ConversationTurnResult(
                    segment: segment,
                    question: question,
                    answer: nil,
                    passiveReminder: nil,
                    passiveTrigger: trigger,
                    metrics: [triggerMetric]
                )
            }
            if let livePreparationSequence {
                completeLivePreparation(livePreparationSequence, generation: generation)
            }

            do {
                let answerStart = Date()
                let request = try await makeAnswerRequest(question: question.text, mode: .passive)
                try ensureCurrentSession(generation)
                let answer = try await answerProvider.answer(for: request)
                try ensureCurrentSession(generation)
                let answerMetric = recordMetric(area: "passive-answer", start: answerStart, reportOnly: true)
                await conversationStore.save(answer: answer, for: question)
                try ensureCurrentSession(generation)
                remember(question: question.text, answer: answer)
                completeReservedQuestion(question.text)
                return ConversationTurnResult(
                    segment: segment,
                    question: question,
                    answer: answer,
                    passiveReminder: nil,
                    passiveTrigger: trigger,
                    hudPages: hudPresenter.textPages(for: answer.text),
                    metrics: [triggerMetric, answerMetric]
                )
            } catch {
                if sessionGeneration == generation {
                    releaseReservedQuestion(question.text)
                }
                throw error
            }
        }

        guard settings.autoDetectQuestions else {
            if let livePreparationSequence {
                completeLivePreparation(livePreparationSequence, generation: generation)
            }
            return ConversationTurnResult(segment: segment, question: nil, answer: nil, passiveReminder: nil)
        }

        try ensureCurrentSession(generation)
        let candidates = duplicateSuppressor.uniqueQuestions(
            await questionClassifier.detectQuestions(
                in: segment.text,
                sensitivity: settings.questionDetectionSensitivity
            )
        )
        try ensureCurrentSession(generation)
        guard !candidates.isEmpty else {
            if let livePreparationSequence {
                completeLivePreparation(livePreparationSequence, generation: generation)
            }
            return ConversationTurnResult(segment: segment, question: nil, answer: nil, passiveReminder: nil)
        }
        guard settings.autoAnswer else {
            if let livePreparationSequence {
                completeLivePreparation(livePreparationSequence, generation: generation)
            }
            return ConversationTurnResult(
                segment: segment,
                question: candidates.first,
                answer: nil,
                passiveReminder: nil,
                questionResults: candidates.map {
                    ConversationQuestionResult(question: $0, answer: nil)
                }
            )
        }

        let questionResults = try await answerCandidatesInParallel(
            candidates,
            mode: mode,
            generation: generation,
            livePreparationSequence: livePreparationSequence
        )

        let primaryResult = questionResults.first(where: { $0.answer != nil }) ?? questionResults[0]
        return ConversationTurnResult(
            segment: segment,
            question: primaryResult.question,
            answer: primaryResult.answer,
            passiveReminder: nil,
            hudPages: primaryResult.hudPages,
            questionResults: questionResults
        )
    }

    public func answerActiveQuestion(
        _ question: String,
        mode: ConversationMode = .general,
        projectID: String? = nil,
        projectFacts: [String] = []
    ) async throws -> AnswerResponse {
        try await answerActiveQuestion(
            question,
            mode: mode,
            projectID: projectID,
            projectFacts: projectFacts,
            using: answerProvider,
            depth: .automatic
        )
    }

    public func answerActiveQuestionDeep(
        _ question: String,
        mode: ConversationMode = .general,
        projectID: String? = nil,
        projectFacts: [String] = []
    ) async throws -> AnswerResponse {
        try await answerActiveQuestion(
            question,
            mode: mode,
            projectID: projectID,
            projectFacts: projectFacts,
            using: deepAnswerProvider,
            depth: .deeper
        )
    }

    private func answerActiveQuestion(
        _ question: String,
        mode: ConversationMode,
        projectID: String?,
        projectFacts: [String],
        using provider: any HelixAnswerProvider,
        depth: AnswerDepth
    ) async throws -> AnswerResponse {
        let generation = sessionGeneration
        var facts = projectFacts
        if let projectID, let knowledgeStore {
            facts.append(contentsOf: await knowledgeStore.facts(for: projectID, question: question))
            try ensureCurrentSession(generation)
        }

        let request = try await makeAnswerRequest(
            question: question,
            mode: mode,
            projectFacts: facts,
            depth: depth
        )
        try ensureCurrentSession(generation)
        let answer = try await provider.answer(for: request)
        try ensureCurrentSession(generation)
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

    public func answerActiveQuestionDeepTurn(
        _ question: String,
        mode: ConversationMode = .general,
        projectID: String? = nil,
        projectFacts: [String] = []
    ) async throws -> (answer: AnswerResponse, hudPages: [G1HudPage]) {
        let answer = try await answerActiveQuestionDeep(
            question,
            mode: mode,
            projectID: projectID,
            projectFacts: projectFacts
        )
        return (answer, hudPresenter.textPages(for: answer.text))
    }

    public func updateSettings(_ settings: HelixSettings) {
        self.settings = settings
    }

    public func setAnswerProvider(_ provider: HelixAnswerProvider) {
        answerProvider = provider
    }

    public func setDeepAnswerProvider(_ provider: HelixAnswerProvider) {
        deepAnswerProvider = provider
    }

    public func setQuestionClassifier(_ classifier: any QuestionClassifying) {
        questionClassifier = classifier
    }

    public func resetSession() {
        sessionGeneration &+= 1
        for continuations in livePreparationWaiters.values {
            continuations.forEach { $0.resume() }
        }
        livePreparationWaiters.removeAll()
        nextLivePreparationSequence = 0
        answeredQuestionKeys.removeAll()
        pendingQuestionKeys.removeAll()
        sessionMemory = SessionMemory(maxEntries: sessionMemory.maxEntries)
        latencyMetrics.removeAll()
    }

    public func updateTranscriptMetadata(_ segment: TranscriptSegment) async {
        await conversationStore.save(segment: segment)
    }

    public func currentAnswerProviderDescription() -> String {
        "\(answerProvider.kind.rawValue):\(answerProvider.model)"
    }

    public func currentDeepAnswerProviderDescription() -> String {
        "\(deepAnswerProvider.kind.rawValue):\(deepAnswerProvider.model)"
    }

    public func currentQuestionClassifierDescription() -> String {
        questionClassifier.sourceDescription
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

    private func questionKey(_ question: String) -> String {
        QuestionTextNormalizer.duplicateKey(for: question)
    }

    private func waitForLivePreparationTurn(_ sequence: UInt64) async {
        guard sequence > nextLivePreparationSequence else { return }
        await withCheckedContinuation { continuation in
            livePreparationWaiters[sequence, default: []].append(continuation)
        }
    }

    private func completeLivePreparation(_ sequence: UInt64, generation: UInt64) {
        guard generation == sessionGeneration,
              sequence == nextLivePreparationSequence else { return }
        nextLivePreparationSequence &+= 1
        livePreparationWaiters.removeValue(forKey: nextLivePreparationSequence)?
            .forEach { $0.resume() }
    }

    private func ensureCurrentSession(_ expectedGeneration: UInt64) throws {
        guard sessionGeneration == expectedGeneration else {
            throw CancellationError()
        }
    }

    private func reserveQuestionIfAvailable(_ question: String) -> Bool {
        let key = questionKey(question)
        guard !answeredQuestionKeys.contains(key), !pendingQuestionKeys.contains(key) else {
            return false
        }
        pendingQuestionKeys.insert(key)
        return true
    }

    private func completeReservedQuestion(_ question: String) {
        let key = questionKey(question)
        pendingQuestionKeys.remove(key)
        answeredQuestionKeys.insert(key)
    }

    private func releaseReservedQuestion(_ question: String) {
        pendingQuestionKeys.remove(questionKey(question))
    }

    private func makeAnswerRequest(
        question: String,
        mode: ConversationMode,
        projectFacts: [String] = [],
        depth: AnswerDepth = .automatic
    ) async throws -> AnswerRequest {
        let webResults = try await webSearchResults(for: question)
        let activeSkill: ActiveSkill
        let maxResponseSentences: Int
        switch depth {
        case .automatic:
            activeSkill = settings.activeSkill
            maxResponseSentences = settings.maxResponseSentences
        case .deeper:
            let configured = settings.activeSkill
            activeSkill = ActiveSkill(
                value: configured.value + "-deeper",
                label: configured.label + " — Deeper",
                prompt: configured.prompt + " Analyze the reasoning, tradeoffs, assumptions, and edge cases before concluding."
            )
            maxResponseSentences = min(10, max(6, settings.maxResponseSentences * 2))
        }
        return AnswerRequest(
            question: question,
            mode: mode,
            activeSkill: activeSkill,
            sessionMemoryContext: sessionMemory.contextLines(),
            maxResponseSentences: maxResponseSentences,
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

    private func answerCandidatesInParallel(
        _ candidates: [QuestionCandidate],
        mode: ConversationMode,
        generation: UInt64,
        projectID: String? = nil,
        projectFacts: [String] = [],
        livePreparationSequence: UInt64? = nil
    ) async throws -> [ConversationQuestionResult] {
        var results = candidates.map {
            ConversationQuestionResult(question: $0, answer: nil)
        }
        var work: [QuestionAnswerWork] = []

        for (index, question) in candidates.enumerated() {
            guard reserveQuestionIfAvailable(question.text) else {
                results[index].suppressionReason = "Duplicate question suppressed."
                continue
            }
            work.append(QuestionAnswerWork(index: index, question: question))
        }
        if let livePreparationSequence {
            completeLivePreparation(livePreparationSequence, generation: generation)
        }

        let provider = answerProvider
        let settingsSnapshot = settings
        let memoryContext = sessionMemory.contextLines()
        let searchService = webSearchService
        let projectKnowledgeStore = knowledgeStore
        let maxConcurrentAnswers = 3
        var providerOutcomes: [Int: ProviderQuestionAnswerOutcome] = [:]

        for batchStart in stride(from: 0, to: work.count, by: maxConcurrentAnswers) {
            let batchEnd = min(work.count, batchStart + maxConcurrentAnswers)
            let batch = Array(work[batchStart..<batchEnd])
            let completed = await withTaskGroup(
                of: (Int, ProviderQuestionAnswerOutcome).self,
                returning: [(Int, ProviderQuestionAnswerOutcome)].self
            ) { group in
                for prepared in batch {
                    group.addTask {
                        do {
                            try await self.ensureCurrentSession(generation)
                            let webResults: [WebSearchResult]
                            switch settingsSnapshot.webSearchMode {
                            case .disabled:
                                webResults = []
                            case .fakeDeterministic, .live:
                                webResults = try await searchService.search(
                                    question: prepared.question.text
                                )
                                try await self.ensureCurrentSession(generation)
                            }
                            var requiredFacts = projectFacts
                            if let projectID, let projectKnowledgeStore {
                                requiredFacts.append(
                                    contentsOf: await projectKnowledgeStore.facts(
                                        for: projectID,
                                        question: prepared.question.text
                                    )
                                )
                                try await self.ensureCurrentSession(generation)
                            }
                            let request = AnswerRequest(
                                question: prepared.question.text,
                                mode: mode,
                                activeSkill: settingsSnapshot.activeSkill,
                                sessionMemoryContext: memoryContext,
                                maxResponseSentences: settingsSnapshot.maxResponseSentences,
                                requiredFacts: requiredFacts,
                                projectContext: requiredFacts,
                                webSearchResults: webResults
                            )
                            try await self.ensureCurrentSession(generation)
                            let answer = try await provider.answer(for: request)
                            try await self.ensureCurrentSession(generation)
                            return (
                                prepared.index,
                                .success(answer)
                            )
                        } catch {
                            return (prepared.index, .failure(error))
                        }
                    }
                }

                var batchResults: [(Int, ProviderQuestionAnswerOutcome)] = []
                for await result in group {
                    batchResults.append(result)
                }
                return batchResults
            }
            for (index, outcome) in completed {
                providerOutcomes[index] = outcome
            }
        }

        try ensureCurrentSession(generation)
        var firstError: (any Error)?
        var successfulAnswerCount = 0
        for prepared in work.sorted(by: { $0.index < $1.index }) {
            switch providerOutcomes[prepared.index] {
            case .success(let answer):
                await conversationStore.save(answer: answer, for: prepared.question)
                try ensureCurrentSession(generation)
                remember(question: prepared.question.text, answer: answer)
                completeReservedQuestion(prepared.question.text)
                successfulAnswerCount += 1
                results[prepared.index] = ConversationQuestionResult(
                    question: prepared.question,
                    answer: answer,
                    hudPages: hudPresenter.textPages(for: answer.text)
                )
            case .failure(let error):
                releaseReservedQuestion(prepared.question.text)
                results[prepared.index].failureReason = error.localizedDescription
                if firstError == nil { firstError = error }
            case nil:
                releaseReservedQuestion(prepared.question.text)
                results[prepared.index].failureReason = "Question answer task did not complete."
                if firstError == nil {
                    firstError = HelixError.providerFailure("Question answer task did not complete.")
                }
            }
        }

        if let firstError, successfulAnswerCount == 0 { throw firstError }
        return results
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
        let generation = sessionGeneration
        continuation.yield(.transcriptionStarted(url))
        let segment = try await audioFileTranscriber.transcribeAudioFile(
            at: url,
            backend: settings.transcriptionBackend,
            model: settings.transcriptionModel
        )
        try ensureCurrentSession(generation)
        await conversationStore.save(segment: segment)
        try ensureCurrentSession(generation)
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
                guard settings.autoAnswer else {
                    let reason = "Passive auto-answer disabled."
                    sessionMemory.appendSuppression(reason)
                    continuation.yield(.suppressed(reason))
                    return
                }

                guard reserveQuestionIfAvailable(question.text) else {
                    let reason = "Duplicate passive question suppressed."
                    sessionMemory.appendSuppression(reason)
                    continuation.yield(.suppressed(reason))
                    return
                }

                do {
                    try await streamAnswer(
                        for: question,
                        mode: .passive,
                        projectFacts: projectFacts,
                        continuation: continuation
                    )
                    completeReservedQuestion(question.text)
                } catch {
                    releaseReservedQuestion(question.text)
                    throw error
                }
            }
            return
        }

        guard settings.autoDetectQuestions else {
            continuation.yield(.suppressed("Question detection disabled."))
            return
        }

        let candidates = duplicateSuppressor.uniqueQuestions(
            await questionClassifier.detectQuestions(
                in: segment.text,
                sensitivity: settings.questionDetectionSensitivity
            )
        )
        guard !candidates.isEmpty else {
            continuation.yield(.suppressed("No question detected."))
            return
        }

        guard settings.autoAnswer else {
            for question in candidates {
                continuation.yield(.questionDetected(question))
            }
            continuation.yield(.suppressed("Auto-answer disabled."))
            return
        }

        for question in candidates {
            continuation.yield(.questionDetected(question))
        }

        let answerStart = Date()
        let results = try await answerCandidatesInParallel(
            candidates,
            mode: mode,
            generation: generation,
            projectID: projectID,
            projectFacts: projectFacts
        )
        continuation.yield(
            .latencyMetric(
                recordMetric(area: "\(mode.rawValue)-answer", start: answerStart, reportOnly: true)
            )
        )
        for result in results {
            guard let answer = result.answer else {
                continuation.yield(
                    .suppressed(
                        result.failureReason
                            ?? result.suppressionReason
                            ?? "Question answer suppressed."
                    )
                )
                continue
            }
            continuation.yield(.answerStarted(result.question))
            continuation.yield(.answerChunk(answer.text))
            continuation.yield(.answerCompleted(answer))
            continuation.yield(.hudPagesUpdated(result.hudPages))
        }
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
