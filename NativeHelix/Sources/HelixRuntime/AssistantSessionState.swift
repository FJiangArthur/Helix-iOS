import Foundation
import HelixConversation
import HelixCore
import HelixG1
import Observation

@MainActor
@Observable
public final class NativeAssistantSessionState {
    public private(set) var mode: ConversationMode
    public private(set) var isRunning = false
    public private(set) var transcriptText = ""
    public private(set) var detectedQuestion = ""
    public private(set) var currentAnswer = ""
    public private(set) var passiveReminder = ""
    public private(set) var hudPages: [G1HudPage] = []
    public private(set) var lastSuppression = ""
    public private(set) var failureReason = ""
    public private(set) var eventLog: [String] = []

    private let engine: NativeConversationEngine

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

    public func setMode(_ mode: ConversationMode) {
        self.mode = mode
    }

    public func runAudioFixture(
        at url: URL,
        mode requestedMode: ConversationMode? = nil,
        projectID: String? = nil,
        projectFacts: [String] = []
    ) async {
        let runMode = requestedMode ?? mode
        resetForRun(mode: runMode)
        isRunning = true
        defer { isRunning = false }

        do {
            let stream = await engine.processAudioFile(
                at: url,
                mode: runMode,
                projectID: projectID,
                projectFacts: projectFacts
            )
            for try await event in stream {
                apply(event)
            }
        } catch {
            failureReason = error.localizedDescription
            eventLog.append("failure")
        }
    }

    public func ask(
        _ question: String,
        mode requestedMode: ConversationMode? = nil,
        projectID: String? = nil,
        projectFacts: [String] = []
    ) async {
        let trimmedQuestion = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuestion.isEmpty else {
            lastSuppression = "Empty question suppressed."
            eventLog.append("suppressed")
            return
        }

        let runMode = requestedMode ?? mode
        resetForRun(mode: runMode)
        detectedQuestion = trimmedQuestion
        isRunning = true
        eventLog.append("manualQuestion")
        defer { isRunning = false }

        do {
            let turn = try await engine.answerActiveQuestionTurn(
                trimmedQuestion,
                mode: runMode,
                projectID: projectID,
                projectFacts: projectFacts
            )
            currentAnswer = turn.answer.text
            hudPages = turn.hudPages
            eventLog.append("answerCompleted")
            eventLog.append("hudPagesUpdated")
        } catch {
            failureReason = error.localizedDescription
            eventLog.append("failure")
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
            eventLog.append("answerCompleted")
        case .passiveReminder(let reminder):
            passiveReminder = reminder.reminder
            eventLog.append("passiveReminder")
        case .hudPagesUpdated(let pages):
            hudPages = pages
            eventLog.append("hudPagesUpdated")
        case .suppressed(let reason):
            lastSuppression = reason
            eventLog.append("suppressed")
        }
    }

    private func resetForRun(mode: ConversationMode) {
        self.mode = mode
        transcriptText = ""
        detectedQuestion = ""
        currentAnswer = ""
        passiveReminder = ""
        hudPages = []
        lastSuppression = ""
        failureReason = ""
        eventLog = []
    }
}
