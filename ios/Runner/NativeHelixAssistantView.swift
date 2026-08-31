import Foundation
import HelixConversation
import HelixCore
import HelixPersistence
import HelixRuntime
import Observation
import SwiftUI

enum AssistantMessageKind: Equatable {
    case transcript
    case question
    case answer
    case reminder
    case error
}

enum AssistantMessageAuthorRole: Equatable {
    case user
    case participant
    case assistant
    case system
}

enum AssistantSpeakerAttribution: Equatable {
    case unknown
    case localEstimate(String)
    case sourceProvided(String)
    case userNamed(String)

    var displayName: String {
        switch self {
        case .unknown:
            return "Unknown speaker"
        case .localEstimate(let label):
            let cleaned = Self.cleaned(label)
            let lowercased = cleaned.lowercased()
            if lowercased.hasPrefix("speaker") {
                let suffix = String(cleaned.dropFirst("speaker".count))
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                return suffix.isEmpty ? "Estimated speaker" : "Estimated speaker \(suffix)"
            }
            return cleaned.isEmpty ? "Estimated speaker" : "Estimated speaker \(cleaned)"
        case .sourceProvided(let label):
            let cleaned = Self.cleaned(label)
            guard !cleaned.isEmpty else { return "Unknown speaker" }
            if cleaned.lowercased().hasPrefix("speaker") {
                return cleaned.prefix(1).uppercased() + String(cleaned.dropFirst())
            }
            return "Source speaker \(cleaned)"
        case .userNamed(let name):
            return Self.cleaned(name)
        }
    }

    fileprivate var confidenceRank: Int {
        switch self {
        case .unknown: return 0
        case .localEstimate: return 1
        case .sourceProvided: return 2
        case .userNamed: return 3
        }
    }

    private static func cleaned(_ value: String) -> String {
        value
            .replacingOccurrences(of: "_", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
    }
}

enum AssistantMessageNoteState: Equatable {
    case notEligible
    case ready
    case pendingAutoSave
    case saving
    case saved
    case failed
}

enum AssistantMessageHUDState: Equatable {
    case notRequested
    case glassesOffline
    case sending
    case delivered
    case deliveredToLeftLens
    case deliveredToRightLens
    case failed

    var actionLabel: String {
        switch self {
        case .sending: return "Sending to G1"
        case .delivered: return "On both lenses"
        case .deliveredToLeftLens: return "Delivered to left lens only"
        case .deliveredToRightLens: return "Delivered to right lens only"
        case .failed: return "G1 delivery failed"
        case .glassesOffline: return "G1 offline"
        case .notRequested: return "Send to G1"
        }
    }
}

struct AssistantConversationMessage: Identifiable, Equatable {
    let id: UUID
    let turnID: UUID
    var kind: AssistantMessageKind
    var text: String
    var authorName: String
    var authorRole: AssistantMessageAuthorRole
    let isAuthorEditable: Bool
    var speakerAttribution: AssistantSpeakerAttribution?
    var isFinal: Bool
    var providerName: String?
    var modelName: String?
    var answerDepth: AnswerDepth
    var noteState: AssistantMessageNoteState
    var knowledgeItemID: UUID?
    var ownsKnowledgeItem: Bool
    var previousKnowledgeItem: NativeKnowledgeItem?
    var hudState: AssistantMessageHUDState
    let createdAt: Date

    init(
        id: UUID = UUID(),
        turnID: UUID,
        kind: AssistantMessageKind,
        text: String,
        authorName: String,
        authorRole: AssistantMessageAuthorRole,
        isAuthorEditable: Bool = false,
        speakerAttribution: AssistantSpeakerAttribution? = nil,
        isFinal: Bool = true,
        providerName: String? = nil,
        modelName: String? = nil,
        answerDepth: AnswerDepth = .automatic,
        noteState: AssistantMessageNoteState = .notEligible,
        knowledgeItemID: UUID? = nil,
        ownsKnowledgeItem: Bool = false,
        previousKnowledgeItem: NativeKnowledgeItem? = nil,
        hudState: AssistantMessageHUDState = .notRequested,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.turnID = turnID
        self.kind = kind
        self.text = text
        self.authorName = authorName
        self.authorRole = authorRole
        self.isAuthorEditable = isAuthorEditable
        self.speakerAttribution = speakerAttribution
        self.isFinal = isFinal
        self.providerName = providerName
        self.modelName = modelName
        self.answerDepth = answerDepth
        self.noteState = noteState
        self.knowledgeItemID = knowledgeItemID
        self.ownsKnowledgeItem = ownsKnowledgeItem
        self.previousKnowledgeItem = previousKnowledgeItem
        self.hudState = hudState
        self.createdAt = createdAt
    }

    var canRequestDeeperAnswer: Bool {
        kind == .answer && isFinal && answerDepth == .automatic
    }
}

enum AssistantLiveOutcomePresentationPolicy {
    static func displayableQuestionResults(
        in turn: ConversationTurnResult
    ) -> [ConversationQuestionResult] {
        turn.questionResults.filter { $0.suppressionReason == nil }
    }

    static func suppressesEntireTurn(_ turn: ConversationTurnResult) -> Bool {
        !turn.questionResults.isEmpty && displayableQuestionResults(in: turn).isEmpty
    }
}

/// App-shell reducer that turns ordered runtime outcomes into stable messages.
/// It also merges partial/final updates and speaker enrichment without
/// collapsing earlier turns.
@MainActor
@Observable
final class AssistantConversationState {
    private(set) var messages: [AssistantConversationMessage] = []

    private var activeTurnID: UUID?
    private var activeAnswerID: UUID?
    private var activeSpeakerAttribution: AssistantSpeakerAttribution?
    private var suppressedAutomaticNoteIDs: Set<UUID> = []

    func startNewConversation() {
        messages.removeAll()
        activeTurnID = nil
        activeAnswerID = nil
        activeSpeakerAttribution = nil
        suppressedAutomaticNoteIDs.removeAll()
    }

    @discardableResult
    func appendManualQuestion(_ rawText: String) -> UUID? {
        let text = Self.trimmed(rawText)
        guard !text.isEmpty else { return nil }

        if let existing = messageIndex(
            in: activeTurnID,
            kind: .question,
            normalizedText: Self.normalized(text)
        ) {
            return messages[existing].id
        }

        let turnID = UUID()
        activeTurnID = turnID
        activeAnswerID = nil
        activeSpeakerAttribution = nil
        let message = AssistantConversationMessage(
            turnID: turnID,
            kind: .question,
            text: text,
            authorName: "You",
            authorRole: .user
        )
        messages.append(message)
        return message.id
    }

    @discardableResult
    func ingestTranscript(
        _ rawText: String,
        speakerAttribution: AssistantSpeakerAttribution = .unknown
    ) -> UUID? {
        let text = Self.trimmed(rawText)
        guard !text.isEmpty else { return nil }

        if let turnID = activeTurnID,
           !turnContainsAnswer(turnID),
           let existing = messageIndex(
               in: turnID,
               kinds: [.transcript, .question],
               normalizedText: Self.normalized(text)
           ) {
            enrichSpeaker(messageID: messages[existing].id, with: speakerAttribution)
            return messages[existing].id
        }

        let turnID = UUID()
        activeTurnID = turnID
        activeAnswerID = nil
        activeSpeakerAttribution = speakerAttribution
        let message = AssistantConversationMessage(
            turnID: turnID,
            kind: .transcript,
            text: text,
            authorName: speakerAttribution.displayName,
            authorRole: .participant,
            isAuthorEditable: true,
            speakerAttribution: speakerAttribution
        )
        messages.append(message)
        return message.id
    }

    @discardableResult
    func ingestDetectedQuestion(
        _ rawText: String,
        speakerAttribution suppliedAttribution: AssistantSpeakerAttribution? = nil
    ) -> UUID? {
        let text = Self.trimmed(rawText)
        guard !text.isEmpty else { return nil }
        let normalizedText = Self.normalized(text)
        let speakerAttribution = suppliedAttribution ?? activeSpeakerAttribution ?? .unknown

        if let turnID = activeTurnID {
            if let existingQuestion = messageIndex(
                in: turnID,
                kind: .question,
                normalizedText: normalizedText
            ) {
                enrichSpeaker(messageID: messages[existingQuestion].id, with: speakerAttribution)
                return messages[existingQuestion].id
            }

            if !turnContainsAnswer(turnID),
               let transcriptIndex = messageIndex(
                   in: turnID,
                   kind: .transcript,
                   normalizedText: normalizedText
               ) {
                messages[transcriptIndex].kind = .question
                enrichSpeaker(messageID: messages[transcriptIndex].id, with: speakerAttribution)
                return messages[transcriptIndex].id
            }

            if !turnContainsAnswer(turnID) {
                let message = AssistantConversationMessage(
                    turnID: turnID,
                    kind: .question,
                    text: text,
                    authorName: speakerAttribution.displayName,
                    authorRole: .participant,
                    isAuthorEditable: true,
                    speakerAttribution: speakerAttribution
                )
                messages.append(message)
                return message.id
            }
        }

        if let latestQuestion = messages.last(where: { $0.kind == .question }),
           Self.normalized(latestQuestion.text) == normalizedText,
           messages.contains(where: { $0.turnID == latestQuestion.turnID && $0.kind == .answer }) {
            return latestQuestion.id
        }

        let turnID = UUID()
        activeTurnID = turnID
        activeAnswerID = nil
        activeSpeakerAttribution = speakerAttribution
        let message = AssistantConversationMessage(
            turnID: turnID,
            kind: .question,
            text: text,
            authorName: speakerAttribution.displayName,
            authorRole: .participant,
            isAuthorEditable: true,
            speakerAttribution: speakerAttribution
        )
        messages.append(message)
        return message.id
    }

    @discardableResult
    func ingestAnswer(
        _ rawText: String,
        providerName: String,
        modelName: String,
        isFinal: Bool,
        answerDepth: AnswerDepth = .automatic,
        forceNew: Bool = false,
        turnID requestedTurnID: UUID? = nil
    ) -> UUID? {
        let text = Self.trimmed(rawText)
        guard !text.isEmpty else { return nil }

        if let requestedTurnID,
           !messages.contains(where: { $0.turnID == requestedTurnID }) {
            // A delayed request from a cleared conversation must not recreate
            // an orphaned answer in the new conversation.
            return nil
        }
        let turnID = requestedTurnID ?? activeTurnID ?? UUID()
        if requestedTurnID == nil {
            activeTurnID = turnID
        }

        if !forceNew, let answerIndex = messages.firstIndex(where: {
            $0.id == activeAnswerID && $0.turnID == turnID && $0.kind == .answer
        }) {
            let existing = messages[answerIndex].text
            let shouldMerge = !messages[answerIndex].isFinal
                || text.hasPrefix(existing)
                || Self.normalized(existing) == Self.normalized(text)
            if shouldMerge {
                messages[answerIndex].text = text
                messages[answerIndex].isFinal = isFinal
                messages[answerIndex].providerName = Self.trimmedOptional(providerName)
                messages[answerIndex].modelName = Self.trimmedOptional(modelName)
                messages[answerIndex].answerDepth = answerDepth
                messages[answerIndex].noteState = isFinal ? .ready : .notEligible
                return messages[answerIndex].id
            }
        }

        let message = AssistantConversationMessage(
            turnID: turnID,
            kind: .answer,
            text: text,
            authorName: "Helix",
            authorRole: .assistant,
            isFinal: isFinal,
            providerName: Self.trimmedOptional(providerName),
            modelName: Self.trimmedOptional(modelName),
            answerDepth: answerDepth,
            noteState: isFinal ? .ready : .notEligible
        )
        if requestedTurnID == nil {
            activeAnswerID = message.id
        }
        messages.append(message)
        return message.id
    }

    func ingestReminder(_ rawText: String) {
        let text = Self.trimmed(rawText)
        guard !text.isEmpty else { return }
        guard messages.last?.kind != .reminder || Self.normalized(messages.last?.text ?? "") != Self.normalized(text) else {
            return
        }
        let turnID = activeTurnID ?? UUID()
        activeTurnID = turnID
        messages.append(
            AssistantConversationMessage(
                turnID: turnID,
                kind: .reminder,
                text: text,
                authorName: "Helix fact-check",
                authorRole: .assistant
            )
        )
    }

    func ingestFailure(_ rawText: String, turnID requestedTurnID: UUID? = nil) {
        let text = Self.trimmed(rawText)
        guard !text.isEmpty else { return }
        guard messages.last?.kind != .error || Self.normalized(messages.last?.text ?? "") != Self.normalized(text) else {
            return
        }
        if let requestedTurnID,
           !messages.contains(where: { $0.turnID == requestedTurnID }) {
            return
        }
        let turnID = requestedTurnID ?? activeTurnID ?? UUID()
        messages.append(
            AssistantConversationMessage(
                turnID: turnID,
                kind: .error,
                text: text,
                authorName: "System",
                authorRole: .system
            )
        )
    }

    func ingestQuestionFailure(
        questionID: UUID,
        question: String,
        reason rawReason: String
    ) {
        guard let questionMessage = messages.first(where: {
            $0.id == questionID && $0.kind == .question
        }) else { return }
        let reason = Self.trimmed(rawReason)
        guard !reason.isEmpty else { return }
        ingestFailure(
            "Couldn’t answer \u{201c}\(Self.trimmed(question))\u{201d}: \(reason)",
            turnID: questionMessage.turnID
        )
    }

    func renameSpeaker(messageID: UUID, to rawName: String) {
        guard let index = messages.firstIndex(where: { $0.id == messageID }),
              messages[index].isAuthorEditable else { return }
        let name = Self.trimmed(rawName)
        let normalizedName = name.lowercased()
        let canonicalName = normalizedName == "me" || normalizedName == "you" ? "You" : name
        let attribution: AssistantSpeakerAttribution = canonicalName.isEmpty
            ? .unknown
            : .userNamed(canonicalName)
        let turnID = messages[index].turnID
        applySpeakerAttribution(attribution, toTurnID: turnID, mayReplaceUserName: true)
    }

    func enrichSpeaker(messageID: UUID, with attribution: AssistantSpeakerAttribution) {
        guard attribution != .unknown,
              let message = messages.first(where: { $0.id == messageID }) else { return }
        applySpeakerAttribution(attribution, toTurnID: message.turnID, mayReplaceUserName: false)
    }

    func questionText(forAnswerID answerID: UUID) -> String? {
        guard let answer = messages.first(where: { $0.id == answerID && $0.kind == .answer }) else {
            return nil
        }
        return messages.last(where: { $0.turnID == answer.turnID && $0.kind == .question })?.text
    }

    func markNoteSaving(_ messageID: UUID) {
        updateMessage(messageID) { $0.noteState = .saving }
    }

    func markNotePending(_ messageID: UUID) {
        updateMessage(messageID) { $0.noteState = .pendingAutoSave }
    }

    @discardableResult
    func beginAutomaticNoteGracePeriod(_ messageID: UUID) -> Bool {
        guard !suppressedAutomaticNoteIDs.contains(messageID),
              let message = messages.first(where: { $0.id == messageID }),
              message.noteState == .ready || message.noteState == .failed else {
            return false
        }
        updateMessage(messageID) { $0.noteState = .pendingAutoSave }
        return true
    }

    func cancelPendingAutomaticNote(_ messageID: UUID) {
        guard messages.first(where: { $0.id == messageID })?.noteState == .pendingAutoSave else { return }
        suppressedAutomaticNoteIDs.insert(messageID)
        updateMessage(messageID) { $0.noteState = .ready }
    }

    func isAutomaticNotePending(_ messageID: UUID) -> Bool {
        messages.first(where: { $0.id == messageID })?.noteState == .pendingAutoSave
    }

    func markNoteSaved(
        _ messageID: UUID,
        knowledgeItemID: UUID,
        ownsKnowledgeItem: Bool = true,
        previousKnowledgeItem: NativeKnowledgeItem? = nil
    ) {
        updateMessage(messageID) {
            $0.noteState = .saved
            $0.knowledgeItemID = knowledgeItemID
            $0.ownsKnowledgeItem = ownsKnowledgeItem
            $0.previousKnowledgeItem = previousKnowledgeItem
        }
    }

    func markNoteReady(_ messageID: UUID) {
        updateMessage(messageID) {
            $0.noteState = .ready
            $0.knowledgeItemID = nil
            $0.ownsKnowledgeItem = false
            $0.previousKnowledgeItem = nil
        }
    }

    func reconcileNotesAfterUndo(
        knowledgeItemID: UUID,
        restoredItem: NativeKnowledgeItem?,
        undoneMessageID: UUID? = nil
    ) {
        for index in messages.indices where messages[index].knowledgeItemID == knowledgeItemID {
            // The card whose mutation the user explicitly undid is ready to
            // save again even when a source-only SMART→FAST rollback kept the
            // exact same text and item id. Content equality alone cannot prove
            // that this card's mutation is still present.
            if messages[index].id == undoneMessageID {
                messages[index].noteState = .ready
                messages[index].knowledgeItemID = nil
                messages[index].ownsKnowledgeItem = false
                messages[index].previousKnowledgeItem = nil
                continue
            }
            guard let restoredItem,
                  let content = noteContent(for: messages[index]),
                  KnowledgeMemoryText.duplicateKey(content)
                    == KnowledgeMemoryText.duplicateKey(restoredItem.text),
                  noteProvenance(for: messages[index], matches: restoredItem) else {
                messages[index].noteState = .ready
                messages[index].knowledgeItemID = nil
                messages[index].ownsKnowledgeItem = false
                messages[index].previousKnowledgeItem = nil
                continue
            }
            messages[index].noteState = .saved
            messages[index].knowledgeItemID = restoredItem.id
        }
    }

    private func noteProvenance(
        for message: AssistantConversationMessage,
        matches restoredItem: NativeKnowledgeItem
    ) -> Bool {
        guard let restoredQuality = KnowledgeMemorySource.automaticAnswerQuality(
            in: restoredItem.source
        ) else { return true }
        guard message.kind == .answer else { return false }
        let messageQuality: KnowledgeAutomaticAnswerQuality = message.answerDepth == .deeper
            ? .smart
            : .fast
        return messageQuality == restoredQuality
    }

    private func noteContent(for message: AssistantConversationMessage) -> String? {
        if message.kind == .transcript {
            return AssistantNoteCapturePolicy.automaticDraft(statement: message.text)?.content
        }
        guard message.kind == .answer,
              let question = messages.last(where: {
                  $0.turnID == message.turnID && $0.kind == .question
              })?.text else { return nil }
        return AssistantNoteCapturePolicy.automaticDraft(
            question: question,
            answer: message.text
        )?.content
    }

    func markNoteFailed(_ messageID: UUID) {
        updateMessage(messageID) { $0.noteState = .failed }
    }

    func markNoteNotEligible(_ messageID: UUID) {
        updateMessage(messageID) { $0.noteState = .notEligible }
    }

    func markHUDSendRequested(_ messageID: UUID) {
        updateMessage(messageID) { $0.hudState = .sending }
    }

    func markHUDOffline(_ messageID: UUID) {
        updateMessage(messageID) { $0.hudState = .glassesOffline }
    }

    func markHUDDelivery(_ messageID: UUID, result: G1HUDDeliveryResult) {
        updateMessage(messageID) {
            switch result {
            case .deliveredToBothLenses:
                $0.hudState = .delivered
            case .deliveredToLeftLens:
                $0.hudState = .deliveredToLeftLens
            case .deliveredToRightLens:
                $0.hudState = .deliveredToRightLens
            case .failed:
                $0.hudState = .failed
            }
        }
    }

    private func updateMessage(_ messageID: UUID, update: (inout AssistantConversationMessage) -> Void) {
        guard let index = messages.firstIndex(where: { $0.id == messageID }) else { return }
        update(&messages[index])
    }

    private func applySpeakerAttribution(
        _ attribution: AssistantSpeakerAttribution,
        toTurnID turnID: UUID,
        mayReplaceUserName: Bool
    ) {
        let representsUser: Bool
        if case .userNamed(let name) = attribution {
            representsUser = name.caseInsensitiveCompare("You") == .orderedSame
                || name.caseInsensitiveCompare("Me") == .orderedSame
        } else {
            representsUser = false
        }

        for index in messages.indices where messages[index].turnID == turnID
            && messages[index].isAuthorEditable
            && (messages[index].authorRole == .participant || messages[index].authorRole == .user) {
            let current = messages[index].speakerAttribution ?? .unknown
            if !mayReplaceUserName, case .userNamed = current { continue }
            guard mayReplaceUserName || attribution.confidenceRank >= current.confidenceRank else {
                continue
            }
            messages[index].speakerAttribution = attribution
            messages[index].authorName = attribution.displayName
            messages[index].authorRole = representsUser ? .user : .participant
        }
        if activeTurnID == turnID {
            let current = activeSpeakerAttribution ?? .unknown
            if mayReplaceUserName || attribution.confidenceRank >= current.confidenceRank {
                activeSpeakerAttribution = attribution
            }
        }
    }

    private func messageIndex(
        in turnID: UUID?,
        kind: AssistantMessageKind,
        normalizedText: String
    ) -> Int? {
        messageIndex(in: turnID, kinds: [kind], normalizedText: normalizedText)
    }

    private func messageIndex(
        in turnID: UUID?,
        kinds: [AssistantMessageKind],
        normalizedText: String
    ) -> Int? {
        guard let turnID else { return nil }
        return messages.firstIndex {
            $0.turnID == turnID
                && kinds.contains($0.kind)
                && Self.normalized($0.text) == normalizedText
        }
    }

    private func turnContainsAnswer(_ turnID: UUID) -> Bool {
        messages.contains { $0.turnID == turnID && $0.kind == .answer }
    }

    private static func trimmed(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func trimmedOptional(_ text: String) -> String? {
        let value = trimmed(text)
        return value.isEmpty ? nil : value
    }

    private static func normalized(_ text: String) -> String {
        trimmed(text)
            .lowercased()
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
    }
}

@MainActor
enum AssistantNoteCaptureCoordinator {
    static func scheduleAutomaticCapture(
        answerID: UUID,
        conversation: AssistantConversationState,
        knowledgeLibrary: NativeKnowledgeLibraryState,
        graceNanoseconds: UInt64 = 4_000_000_000
    ) async {
        guard let answer = conversation.messages.first(where: { $0.id == answerID }),
              AssistantNoteCapturePolicy.permitsAutomaticCapture(
                  answerModel: answer.modelName
              ) else {
            // Leave the finalized answer ready for an explicit save even
            // though its fixture provenance excludes automatic persistence.
            conversation.markNoteReady(answerID)
            return
        }
        guard let draft = eligibleDraft(answerID: answerID, conversation: conversation) else {
            conversation.markNoteNotEligible(answerID)
            return
        }
        let quality: KnowledgeAutomaticAnswerQuality = answer.answerDepth == .deeper
            ? .smart
            : .fast
        guard conversation.beginAutomaticNoteGracePeriod(answerID) else { return }
        try? await Task.sleep(nanoseconds: graceNanoseconds)
        guard !Task.isCancelled, conversation.isAutomaticNotePending(answerID) else { return }
        await persist(
            draft,
            answerID: answerID,
            conversation: conversation,
            knowledgeLibrary: knowledgeLibrary,
            source: KnowledgeMemorySource.automaticAnswer(
                category: draft.category.rawValue,
                quality: quality
            ),
            deduplication: .automaticAnswer(quality: quality)
        )
    }

    static func captureImmediately(
        answerID: UUID,
        conversation: AssistantConversationState,
        knowledgeLibrary: NativeKnowledgeLibraryState
    ) async {
        guard let draft = eligibleDraft(answerID: answerID, conversation: conversation) else {
            conversation.markNoteNotEligible(answerID)
            return
        }
        await persist(
            draft,
            answerID: answerID,
            conversation: conversation,
            knowledgeLibrary: knowledgeLibrary,
            source: "Helix Knowledge · \(draft.category.rawValue)",
            deduplication: .exact
        )
    }

    static func scheduleAutomaticTranscriptCapture(
        messageID: UUID,
        conversation: AssistantConversationState,
        knowledgeLibrary: NativeKnowledgeLibraryState,
        graceNanoseconds: UInt64 = 4_000_000_000
    ) async {
        guard let draft = eligibleTranscriptDraft(
            messageID: messageID,
            conversation: conversation
        ) else {
            conversation.markNoteNotEligible(messageID)
            return
        }
        // Transcript bubbles start hidden from note actions. Once the policy
        // has accepted this finalized statement, expose it as eligible before
        // entering the same undo grace period used by answer captures.
        conversation.markNoteReady(messageID)
        guard conversation.beginAutomaticNoteGracePeriod(messageID) else { return }
        try? await Task.sleep(nanoseconds: graceNanoseconds)
        guard !Task.isCancelled, conversation.isAutomaticNotePending(messageID) else { return }
        await persist(
            draft,
            answerID: messageID,
            conversation: conversation,
            knowledgeLibrary: knowledgeLibrary,
            source: "Helix Knowledge · \(draft.category.rawValue)",
            deduplication: .exact
        )
    }

    static func removeFromKnowledge(
        answerID: UUID,
        conversation: AssistantConversationState,
        knowledgeLibrary: NativeKnowledgeLibraryState
    ) async {
        guard let message = conversation.messages.first(where: { $0.id == answerID }),
              message.ownsKnowledgeItem,
              let knowledgeItemID = message.knowledgeItemID else { return }
        guard let currentItem = knowledgeLibrary.snapshot.memories.first(where: {
            $0.id == knowledgeItemID
        }) else {
            conversation.reconcileNotesAfterUndo(
                knowledgeItemID: knowledgeItemID,
                restoredItem: nil,
                undoneMessageID: answerID
            )
            return
        }
        conversation.markNoteSaving(answerID)
        let mutation = KnowledgeMemoryUpsertResult(
            item: currentItem,
            wasInserted: message.previousKnowledgeItem == nil,
            previousItem: message.previousKnowledgeItem
        )
        await knowledgeLibrary.undoMemoryUpsert(mutation)
        let restoredItem = knowledgeLibrary.snapshot.memories.first(where: { $0.id == knowledgeItemID })
        let undoSucceeded = message.previousKnowledgeItem == nil
            ? restoredItem == nil
            : restoredItem == message.previousKnowledgeItem
        if !undoSucceeded {
            // Keep the durable item identity so another tap retries removal
            // instead of accidentally creating a second memory.
            conversation.markNoteSaved(
                answerID,
                knowledgeItemID: knowledgeItemID,
                ownsKnowledgeItem: true,
                previousKnowledgeItem: message.previousKnowledgeItem
            )
        } else {
            conversation.reconcileNotesAfterUndo(
                knowledgeItemID: knowledgeItemID,
                restoredItem: restoredItem,
                undoneMessageID: answerID
            )
        }
    }

    private static func eligibleDraft(
        answerID: UUID,
        conversation: AssistantConversationState
    ) -> AssistantNoteDraft? {
        guard let message = conversation.messages.first(where: { $0.id == answerID }) else {
            return nil
        }
        if message.kind == .transcript {
            return AssistantNoteCapturePolicy.automaticDraft(statement: message.text)
        }
        guard message.kind == .answer else { return nil }
        guard let question = conversation.questionText(forAnswerID: answerID),
              let draft = AssistantNoteCapturePolicy.automaticDraft(question: question, answer: message.text) else {
            return nil
        }
        return draft
    }

    private static func eligibleTranscriptDraft(
        messageID: UUID,
        conversation: AssistantConversationState
    ) -> AssistantNoteDraft? {
        guard let message = conversation.messages.first(where: {
            $0.id == messageID && $0.kind == .transcript
        }) else { return nil }
        return AssistantNoteCapturePolicy.automaticDraft(statement: message.text)
    }

    private static func persist(
        _ draft: AssistantNoteDraft,
        answerID: UUID,
        conversation: AssistantConversationState,
        knowledgeLibrary: NativeKnowledgeLibraryState,
        source: String,
        deduplication: KnowledgeMemoryDeduplication
    ) async {
        guard let answer = conversation.messages.first(where: { $0.id == answerID }),
              answer.noteState != .saving,
              answer.noteState != .saved else { return }
        conversation.markNoteSaving(answerID)
        let result = await knowledgeLibrary.addMemoryIfAbsent(
            draft.content,
            source: source,
            deduplication: deduplication
        )
        if let result {
            conversation.markNoteSaved(
                answerID,
                knowledgeItemID: result.item.id,
                ownsKnowledgeItem: result.didMutate,
                previousKnowledgeItem: result.previousItem
            )
        } else {
            conversation.markNoteFailed(answerID)
        }
    }

}

typealias AssistantDeepAnswerHandler = @MainActor (String) async -> AnswerResponse?

@MainActor
struct NativeAssistantView: View {
    let runtime: HelixRuntimeDependencies
    let bridge: HelixNativeBridge
    @Binding var draftQuestion: String
    let deepAnswerHandler: AssistantDeepAnswerHandler

    @State private var conversation = AssistantConversationState()
    @State private var consumedLiveOutcomeSequences: Set<UInt64> = []
    @State private var liveOutcomeParticipantMessageIDs: [UInt64: Set<UUID>] = [:]
    @State private var liveOutcomeAnswerMessageIDs: [UInt64: Set<UUID>] = [:]
    @State private var hudRequestedOutcomeSequences: Set<UInt64> = []
    @State private var hudDeliveryResultsByOutcomeSequence: [UInt64: G1HUDDeliveryResult] = [:]
    @State private var automaticKnowledgeTargetsByMessageID: [
        UUID: Set<AssistantAutomaticKnowledgeTarget>
    ] = [:]
#if targetEnvironment(simulator)
    @State private var didInjectUITestSpeakerFixture = false
#endif

    init(
        runtime: HelixRuntimeDependencies,
        bridge: HelixNativeBridge,
        draftQuestion: Binding<String>,
        deepAnswerHandler: AssistantDeepAnswerHandler? = nil
    ) {
        self.runtime = runtime
        self.bridge = bridge
        _draftQuestion = draftQuestion
        self.deepAnswerHandler = deepAnswerHandler ?? { question in
            await runtime.assistantSession.askDeeper(
                question,
                mode: runtime.assistantSession.mode
            )
        }
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                AssistantWorkspacePanel(
                    runtime: runtime,
                    bridge: bridge,
                    draftQuestion: $draftQuestion,
                    conversation: conversation,
                    deepAnswerHandler: deepAnswerHandler,
                    automaticKnowledgeTargetsByMessageID: automaticKnowledgeTargetsByMessageID,
                    startNewConversation: startNewConversation
                )
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
            .scrollContentBackground(.hidden)
            .onChange(of: conversation.messages.last?.id) { _, messageID in
                guard let messageID else { return }
                withAnimation(.easeOut(duration: 0.2)) {
                    proxy.scrollTo(messageID, anchor: .bottom)
                }
            }
        }
        .task {
            bridge.onLiveTranscriptHUDSendRequested = { sequence in
                hudRequestedOutcomeSequences.insert(sequence)
                markHUDRequestedMessages(for: sequence)
            }
            bridge.onLiveTranscriptHUDDeliveryResult = { sequence, result in
                hudDeliveryResultsByOutcomeSequence[sequence] = result
                markHUDDeliveryMessages(for: sequence, result: result)
            }
            let outcomes = runtime.assistantSession.committedLiveTranscriptOutcomes
            if outcomes.isEmpty {
                synchronizeCurrentRuntimeState(isFinal: !runtime.assistantSession.isRunning)
            } else {
                consumeCommittedLiveTranscriptOutcomes(outcomes)
            }
#if targetEnvironment(simulator)
            injectUITestSpeakerFixtureIfRequested()
#endif
        }
        .onChange(of: runtime.assistantSession.committedLiveTranscriptOutcomes) { _, outcomes in
            consumeCommittedLiveTranscriptOutcomes(outcomes)
        }
        .onChange(of: runtime.automaticKnowledgeCapture.receipts) { _, _ in
            synchronizeAutomaticKnowledgeReceipts()
        }
    }

    private func synchronizeCurrentRuntimeState(isFinal: Bool) {
        conversation.ingestTranscript(runtime.assistantSession.transcriptText)
        conversation.ingestDetectedQuestion(runtime.assistantSession.detectedQuestion)
        ingestRuntimeAnswer(runtime.assistantSession.currentAnswer, isFinal: isFinal)
        conversation.ingestReminder(runtime.assistantSession.passiveReminder)
        conversation.ingestFailure(runtime.assistantSession.failureReason)
    }

#if targetEnvironment(simulator)
    private func injectUITestSpeakerFixtureIfRequested() {
        guard _isDebugAssertConfiguration(),
              !didInjectUITestSpeakerFixture,
              ProcessInfo.processInfo.arguments.contains("--helix-ui-speaker-fixture") else {
            return
        }
        didInjectUITestSpeakerFixture = true
        conversation.ingestTranscript(
            "Alice owns the launch review.",
            speakerAttribution: .sourceProvided("Alice")
        )
        conversation.ingestTranscript(
            "I will send the revised deck by noon.",
            speakerAttribution: .unknown
        )
    }
#endif

    private func ingestRuntimeAnswer(_ answer: String, isFinal: Bool) {
        guard let answerID = conversation.ingestAnswer(
            answer,
            providerName: runtime.assistantSession.currentAnswerProvider,
            modelName: runtime.assistantSession.currentAnswerModel,
            isFinal: isFinal
        ) else { return }

        guard isFinal else { return }
        if !bridge.isGlassesConnected {
            conversation.markHUDOffline(answerID)
        }
        Task {
            await AssistantNoteCaptureCoordinator.scheduleAutomaticCapture(
                answerID: answerID,
                conversation: conversation,
                knowledgeLibrary: runtime.knowledgeLibrary
            )
        }
    }

    private func consumeCommittedLiveTranscriptOutcomes(_ outcomes: [NativeLiveTranscriptOutcome]) {
        let orderedOutcomes = outcomes.sorted {
            if $0.sequence == $1.sequence {
                return !$0.isMetadataUpdate && $1.isMetadataUpdate
            }
            return $0.sequence < $1.sequence
        }

        for outcome in orderedOutcomes {
            let attribution = speakerAttribution(for: outcome.segment)
            if outcome.isMetadataUpdate,
               let messageIDs = liveOutcomeParticipantMessageIDs[outcome.sequence] {
                for messageID in messageIDs {
                    conversation.enrichSpeaker(messageID: messageID, with: attribution)
                }
                continue
            }

            // If the view is first created after native state has already
            // replaced an outcome with its metadata-enriched version, ingest
            // that full snapshot once instead of dropping its turn/answer.
            guard consumedLiveOutcomeSequences.insert(outcome.sequence).inserted else { continue }
            let transcriptMessageID = conversation.ingestTranscript(
                outcome.segment.text,
                speakerAttribution: attribution
            )
            var participantMessageIDs: Set<UUID> = []
            var answerMessageIDs: Set<UUID> = []
            if let transcriptMessageID {
                participantMessageIDs.insert(transcriptMessageID)
                bindAutomaticKnowledgeTargets(
                    runtime.automaticKnowledgeCapture.targets(
                        conversationGeneration: outcome.conversationGeneration,
                        sequence: outcome.sequence,
                        kind: .transcript
                    ),
                    to: transcriptMessageID
                )
            }
            liveOutcomeParticipantMessageIDs[outcome.sequence] = participantMessageIDs

            guard let turn = outcome.turn else {
                conversation.ingestFailure(outcome.failureReason ?? "Live transcript processing failed.")
                synchronizeAutomaticKnowledgeReceipts()
                continue
            }

            if AssistantLiveOutcomePresentationPolicy.suppressesEntireTurn(turn) {
                // Preserve what the distinct source speaker actually said,
                // while suppressing only the duplicate question/answer card.
                liveOutcomeParticipantMessageIDs[outcome.sequence] = participantMessageIDs
                synchronizeAutomaticKnowledgeReceipts()
                continue
            }

            if turn.questionResults.isEmpty {
                if let question = turn.question {
                    let messageIDs = ingestCommittedQuestion(
                        question.text,
                        answer: turn.answer,
                        speakerAttribution: attribution,
                        conversationGeneration: outcome.conversationGeneration,
                        sequence: outcome.sequence,
                        resultIndex: 0
                    )
                    if let questionID = messageIDs.questionID {
                        participantMessageIDs.insert(questionID)
                    }
                    if let answerID = messageIDs.answerID { answerMessageIDs.insert(answerID) }
                }
            } else {
                for (resultIndex, result) in turn.questionResults.enumerated()
                    where result.suppressionReason == nil {
                    let messageIDs = ingestCommittedQuestion(
                        result.question.text,
                        answer: result.answer,
                        speakerAttribution: attribution,
                        conversationGeneration: outcome.conversationGeneration,
                        sequence: outcome.sequence,
                        resultIndex: resultIndex
                    )
                    if let questionID = messageIDs.questionID {
                        participantMessageIDs.insert(questionID)
                    }
                    if let answerID = messageIDs.answerID { answerMessageIDs.insert(answerID) }
                    if result.answer == nil,
                       let questionID = messageIDs.questionID,
                       let failureReason = result.failureReason {
                        conversation.ingestQuestionFailure(
                            questionID: questionID,
                            question: result.question.text,
                            reason: failureReason
                        )
                    }
                }
            }

            liveOutcomeParticipantMessageIDs[outcome.sequence] = participantMessageIDs
            liveOutcomeAnswerMessageIDs[outcome.sequence] = answerMessageIDs
            if hudRequestedOutcomeSequences.contains(outcome.sequence) {
                markHUDRequestedMessages(for: outcome.sequence)
            } else if !bridge.isGlassesConnected {
                for answerID in answerMessageIDs {
                    conversation.markHUDOffline(answerID)
                }
            }
            if let result = hudDeliveryResultsByOutcomeSequence[outcome.sequence] {
                markHUDDeliveryMessages(for: outcome.sequence, result: result)
            }

            if let reminder = turn.passiveReminder {
                conversation.ingestReminder(reminder.reminder)
            }
            synchronizeAutomaticKnowledgeReceipts()
        }
    }

    private func ingestCommittedQuestion(
        _ question: String,
        answer: AnswerResponse?,
        speakerAttribution: AssistantSpeakerAttribution,
        conversationGeneration: UInt64,
        sequence: UInt64,
        resultIndex: Int
    ) -> (questionID: UUID?, answerID: UUID?) {
        let questionID = conversation.ingestDetectedQuestion(
            question,
            speakerAttribution: speakerAttribution
        )
        guard let answer,
              let answerID = conversation.ingestAnswer(
                  answer.text,
                  providerName: answer.provider.rawValue,
                  modelName: answer.model,
                  isFinal: true
              ) else { return (questionID, nil) }
        let target = AssistantAutomaticKnowledgeTarget(
            conversationGeneration: conversationGeneration,
            sequence: sequence,
            kind: .answer,
            index: resultIndex
        )
        if runtime.automaticKnowledgeCapture.receipts[target] != nil {
            bindAutomaticKnowledgeTargets(Set([target]), to: answerID)
        }
        return (questionID, answerID)
    }

    private func markHUDRequestedMessages(for sequence: UInt64) {
        for answerID in liveOutcomeAnswerMessageIDs[sequence] ?? [] {
            conversation.markHUDSendRequested(answerID)
        }
    }

    private func markHUDDeliveryMessages(for sequence: UInt64, result: G1HUDDeliveryResult) {
        for answerID in liveOutcomeAnswerMessageIDs[sequence] ?? [] {
            conversation.markHUDDelivery(answerID, result: result)
        }
    }

    private func bindAutomaticKnowledgeTargets(
        _ targets: Set<AssistantAutomaticKnowledgeTarget>,
        to messageID: UUID
    ) {
        guard !targets.isEmpty else { return }
        var existing = automaticKnowledgeTargetsByMessageID[messageID] ?? []
        existing.formUnion(targets)
        automaticKnowledgeTargetsByMessageID[messageID] = existing
    }

    private func synchronizeAutomaticKnowledgeReceipts() {
        let allReceipts = runtime.automaticKnowledgeCapture.receipts
        for (messageID, targets) in automaticKnowledgeTargetsByMessageID {
            let receipts = targets.compactMap { allReceipts[$0] }
            guard !receipts.isEmpty else { continue }
            let states = Set(receipts.map(\.state))
            if states.contains(.saving) {
                conversation.markNoteSaving(messageID)
            } else if states.contains(.pending) {
                conversation.markNotePending(messageID)
            } else if states.contains(.failed) {
                conversation.markNoteFailed(messageID)
            } else if let saved = receipts.first(where: { $0.state == .saved }),
                      let knowledgeItemID = receipts.first(where: {
                          $0.state == .saved && $0.ownsKnowledgeItem
                      })?.knowledgeItemID ?? saved.knowledgeItemID {
                conversation.markNoteSaved(
                    messageID,
                    knowledgeItemID: knowledgeItemID,
                    ownsKnowledgeItem: receipts.contains {
                        $0.state == .saved && $0.ownsKnowledgeItem
                    }
                )
            } else if states == [.cancelled] {
                conversation.markNoteReady(messageID)
            }
        }
    }

    private func speakerAttribution(for segment: TranscriptSegment) -> AssistantSpeakerAttribution {
        guard let speaker = segment.speaker?.trimmingCharacters(in: .whitespacesAndNewlines),
              !speaker.isEmpty else { return .unknown }
        switch segment.speakerSource {
        case .sourceProvided:
            return .sourceProvided(speaker)
        case .localEnergyEstimate:
            return .localEstimate(speaker)
        case nil:
            // A label without provenance is not safe to present as identity.
            return .unknown
        }
    }

    private func startNewConversation() {
        // Always invalidate the recognizer generation. A provider tail can
        // still be in flight after the visible listening flag turns off.
        bridge.stopListeningForNewConversation()

        Task {
            await runtime.assistantSession.startNewConversation()
            consumedLiveOutcomeSequences.removeAll()
            liveOutcomeParticipantMessageIDs.removeAll()
            liveOutcomeAnswerMessageIDs.removeAll()
            hudRequestedOutcomeSequences.removeAll()
            automaticKnowledgeTargetsByMessageID.removeAll()
            draftQuestion = ""
            conversation.startNewConversation()
        }
    }
}

@MainActor
private struct AssistantWorkspacePanel: View {
    let runtime: HelixRuntimeDependencies
    let bridge: HelixNativeBridge
    @Binding var draftQuestion: String
    let conversation: AssistantConversationState
    let deepAnswerHandler: AssistantDeepAnswerHandler
    let automaticKnowledgeTargetsByMessageID: [
        UUID: Set<AssistantAutomaticKnowledgeTarget>
    ]
    let startNewConversation: () -> Void

    @State private var editingSpeakerMessageID: UUID?
    @State private var speakerNameDraft = ""
    @State private var isConfirmingNewConversation = false
    @State private var deeperRequestsInFlight: Set<UUID> = []

    var body: some View {
        NativeSection("Assistant", subtitle: runtime.assistantSession.mode.nativeSummary) {
            VStack(alignment: .leading, spacing: 14) {
                Picker("Conversation mode", selection: modeBinding) {
                    ForEach(ConversationMode.allCases, id: \.self) { mode in
                        Text(mode.nativeTitle).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                AssistantControlBar(
                    statusText: listeningStatusText,
                    statusTint: statusTint,
                    isListening: runtime.assistantSession.isListening,
                    canSaveSession: !conversation.messages.isEmpty,
                    toggleListening: bridge.toggleListening,
                    newConversation: { isConfirmingNewConversation = true },
                    saveSession: saveSession
                )

                if !bridge.speechError.isEmpty {
                    Text(bridge.speechError)
                        .font(.footnote)
                        .foregroundStyle(NativeHelixTheme.amber)
                        .fixedSize(horizontal: false, vertical: true)
                }

                CompactTagGrid(values: contextTags)

                AssistantComposer(
                    draftQuestion: $draftQuestion,
                    isRunning: runtime.assistantSession.isRunning,
                    submit: askQuestion
                )

                Divider()

                if conversation.messages.isEmpty {
                    NativeEmptyState(
                        title: "Start a conversation",
                        detail: "Typed questions and finalized speech appear as individual messages. Source speaker labels are shown when available; local estimates and unknown voices stay editable.",
                        symbolName: "bubble.left.and.bubble.right"
                    )
                } else {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(conversation.messages) { message in
                            AssistantChatBubble(
                                message: message,
                                isGlassesConnected: bridge.isGlassesConnected,
                                canRequestDeeperAnswer: message.canRequestDeeperAnswer,
                                isRequestingDeeperAnswer: deeperRequestsInFlight.contains(message.id),
                                editSpeaker: { beginEditingSpeaker(message) },
                                sendToGlasses: { sendToGlasses(message) },
                                saveNote: { saveNote(message) },
                                requestDeeperAnswer: { requestDeeperAnswer(message) }
                            )
                            .id(message.id)
                        }
                    }
                    .accessibilityIdentifier("assistant-chat-thread")
                }

                if runtime.assistantSession.isListening && !bridge.livePartialTranscript.isEmpty {
                    AssistantLiveTranscriptBubble(text: bridge.livePartialTranscript)
                }
            }
        }
        .alert("Name speaker", isPresented: speakerEditorPresented) {
            TextField("Speaker name", text: $speakerNameDraft)
            Button("Save") { saveSpeakerName() }
            Button("Mark as Me") { saveSpeakerName("You") }
            Button("Cancel", role: .cancel) { editingSpeakerMessageID = nil }
        } message: {
            Text("The transcript did not include a verified identity. Add a name only when you know who spoke.")
        }
        .confirmationDialog(
            "Start a new conversation?",
            isPresented: $isConfirmingNewConversation,
            titleVisibility: .visible
        ) {
            Button("Start New Conversation", role: .destructive, action: startNewConversation)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Helix will stop listening and clear this conversation. Saved Knowledge stays available.")
        }
    }

    private var modeBinding: Binding<ConversationMode> {
        Binding(
            get: { runtime.assistantSession.mode },
            set: { runtime.assistantSession.setMode($0) }
        )
    }

    private var listeningStatusText: String {
        if runtime.assistantSession.isListening {
            return runtime.assistantSession.isRunning ? "Answering…" : "Listening"
        }
        return runtime.assistantSession.statusText
    }

    private var statusTint: Color {
        if runtime.assistantSession.isListening { return NativeHelixTheme.teal }
        return runtime.assistantSession.isRunning ? NativeHelixTheme.green : NativeHelixTheme.secondaryInk
    }

    private var contextTags: [String] {
        [
            "\(runtime.activeProviderName) provider",
            bridge.isGlassesConnected ? "G1 connected" : "G1 offline",
            "Auto Knowledge on"
        ]
    }

    private var speakerEditorPresented: Binding<Bool> {
        Binding(
            get: { editingSpeakerMessageID != nil },
            set: { isPresented in
                if !isPresented { editingSpeakerMessageID = nil }
            }
        )
    }

    private func askQuestion() {
        let question = draftQuestion.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty else { return }
        guard let questionID = conversation.appendManualQuestion(question),
              let questionTurnID = conversation.messages.first(where: { $0.id == questionID })?.turnID else {
            return
        }
        draftQuestion = ""

        Task {
            guard let answer = await runtime.assistantSession.ask(
                question,
                mode: runtime.assistantSession.mode
            ) else { return }
            guard let answerID = conversation.ingestAnswer(
                answer.text,
                providerName: answer.provider.rawValue,
                modelName: answer.model,
                isFinal: true,
                turnID: questionTurnID
            ) else { return }

            if bridge.isGlassesConnected {
                conversation.markHUDSendRequested(answerID)
                bridge.presentToGlasses(answer.text) { result in
                    conversation.markHUDDelivery(answerID, result: result)
                }
            } else {
                conversation.markHUDOffline(answerID)
            }
            await AssistantNoteCaptureCoordinator.scheduleAutomaticCapture(
                answerID: answerID,
                conversation: conversation,
                knowledgeLibrary: runtime.knowledgeLibrary
            )
        }
    }

    private func sendToGlasses(_ message: AssistantConversationMessage) {
        guard message.kind == .answer else { return }
        guard bridge.isGlassesConnected else {
            conversation.markHUDOffline(message.id)
            return
        }
        conversation.markHUDSendRequested(message.id)
        bridge.presentToGlasses(message.text) { result in
            conversation.markHUDDelivery(message.id, result: result)
        }
    }

    private func saveNote(_ message: AssistantConversationMessage) {
        if let targets = automaticKnowledgeTargetsByMessageID[message.id], !targets.isEmpty {
            switch message.noteState {
            case .pendingAutoSave:
                runtime.automaticKnowledgeCapture.cancel(targets)
            case .saved:
                Task {
                    await runtime.automaticKnowledgeCapture.removeOwned(targets)
                }
            case .saving:
                break
            case .notEligible, .ready, .failed:
                Task {
                    await runtime.automaticKnowledgeCapture.captureImmediately(targets)
                }
            }
            return
        }
        if message.noteState == .pendingAutoSave {
            conversation.cancelPendingAutomaticNote(message.id)
            return
        }
        Task {
            if message.noteState == .saved {
                await AssistantNoteCaptureCoordinator.removeFromKnowledge(
                    answerID: message.id,
                    conversation: conversation,
                    knowledgeLibrary: runtime.knowledgeLibrary
                )
            } else {
                await AssistantNoteCaptureCoordinator.captureImmediately(
                    answerID: message.id,
                    conversation: conversation,
                    knowledgeLibrary: runtime.knowledgeLibrary
                )
            }
        }
    }

    private func requestDeeperAnswer(_ message: AssistantConversationMessage) {
        guard message.canRequestDeeperAnswer,
              let question = conversation.questionText(forAnswerID: message.id),
              deeperRequestsInFlight.insert(message.id).inserted else { return }
        let originalTurnID = message.turnID
        Task {
            defer { deeperRequestsInFlight.remove(message.id) }
            guard let answer = await deepAnswerHandler(question) else {
                let failure = runtime.assistantSession.failureReason
                conversation.ingestFailure(
                    failure.isEmpty ? "Helix could not produce a deeper answer." : failure,
                    turnID: originalTurnID
                )
                return
            }

            guard let answerID = conversation.ingestAnswer(
                answer.text,
                providerName: answer.provider.rawValue,
                modelName: answer.model,
                isFinal: true,
                answerDepth: .deeper,
                forceNew: true,
                turnID: originalTurnID
            ) else { return }

            if bridge.isGlassesConnected {
                // This is a local enqueue/request, not a protocol ACK.
                conversation.markHUDSendRequested(answerID)
                bridge.presentToGlasses(answer.text) { result in
                    conversation.markHUDDelivery(answerID, result: result)
                }
            } else {
                conversation.markHUDOffline(answerID)
            }
            // The four-second undo window is note work, not model work. Keep
            // it detached from the request lifetime so the original automatic
            // answer stops showing "Thinking…" as soon as the deeper answer
            // is visible.
            Task {
                await AssistantNoteCaptureCoordinator.scheduleAutomaticCapture(
                    answerID: answerID,
                    conversation: conversation,
                    knowledgeLibrary: runtime.knowledgeLibrary
                )
            }
        }
    }

    private func beginEditingSpeaker(_ message: AssistantConversationMessage) {
        guard message.isAuthorEditable else { return }
        editingSpeakerMessageID = message.id
        speakerNameDraft = message.authorName == "Unknown speaker" ? "" : message.authorName
    }

    private func saveSpeakerName(_ name: String? = nil) {
        guard let editingSpeakerMessageID else { return }
        conversation.renameSpeaker(
            messageID: editingSpeakerMessageID,
            to: name ?? speakerNameDraft
        )
        self.editingSpeakerMessageID = nil
    }

    private func saveSession() {
        let questions = conversation.messages.filter { $0.kind == .question }
        let answers = conversation.messages.filter { $0.kind == .answer }
        let transcripts = conversation.messages.filter { $0.kind == .transcript || $0.kind == .question }
        let reminders = conversation.messages.filter { $0.kind == .reminder }
        let title = questions.first?.text ?? transcripts.first?.text ?? "Native Helix Session"

        Task {
            await runtime.sessionArchive.archiveSession(
                NativeSessionSummary(
                    title: title,
                    mode: runtime.assistantSession.mode,
                    transcriptPreview: transcripts.last?.text ?? "",
                    answerPreview: answers.last?.text ?? "",
                    projectName: runtime.knowledgeLibrary.snapshot.activeProject?.name,
                    segmentCount: transcripts.count,
                    answerCount: answers.count,
                    skillValue: runtime.assistantSession.activeSkill.value,
                    transcriptTurns: transcripts.map(\.text),
                    answers: answers.map(\.text),
                    passiveReminders: reminders.map(\.text),
                    latencyMetrics: runtime.assistantSession.latencyMetrics
                )
            )
        }
    }
}

private struct AssistantControlBar: View {
    let statusText: String
    let statusTint: Color
    let isListening: Bool
    let canSaveSession: Bool
    let toggleListening: () -> Void
    let newConversation: () -> Void
    let saveSession: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            NativeStatusPill(text: statusText, tint: statusTint)
            Spacer(minLength: 0)
            NativeIconButton(
                symbolName: isListening ? "stop.fill" : "mic.fill",
                isPrimary: true,
                accessibilityLabel: isListening ? "Stop listening" : "Start listening",
                action: toggleListening
            )
            NativeIconButton(
                symbolName: "square.and.pencil",
                accessibilityLabel: "New conversation",
                action: newConversation
            )
            NativeIconButton(
                symbolName: "tray.and.arrow.down",
                isDisabled: !canSaveSession,
                accessibilityLabel: "Save current session",
                action: saveSession
            )
        }
    }
}

private struct AssistantComposer: View {
    @Binding var draftQuestion: String
    let isRunning: Bool
    let submit: () -> Void

    private var isSubmitDisabled: Bool {
        draftQuestion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isRunning
    }

    var body: some View {
        HStack(spacing: 10) {
            TextField("Ask or paste a question", text: $draftQuestion, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.body)
                .lineLimit(1...4)
                .padding(.horizontal, 12)
                .frame(minHeight: 44)
                .background(NativeHelixTheme.background)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(NativeHelixTheme.hairline)
                }
                .submitLabel(.send)
                .onSubmit {
                    if !isSubmitDisabled { submit() }
                }

            NativeIconButton(
                symbolName: isRunning ? "hourglass" : "arrow.up",
                isPrimary: true,
                isDisabled: isSubmitDisabled,
                accessibilityLabel: "Ask Helix",
                action: submit
            )
        }
    }
}

private struct AssistantChatBubble: View {
    let message: AssistantConversationMessage
    let isGlassesConnected: Bool
    let canRequestDeeperAnswer: Bool
    let isRequestingDeeperAnswer: Bool
    let editSpeaker: () -> Void
    let sendToGlasses: () -> Void
    let saveNote: () -> Void
    let requestDeeperAnswer: () -> Void

    private var isUser: Bool { message.authorRole == .user }

    var body: some View {
        HStack {
            if isUser { Spacer(minLength: 44) }

            VStack(alignment: .leading, spacing: 7) {
                AssistantMessageHeader(message: message, editSpeaker: editSpeaker)

                Text(message.text)
                    .font(.body)
                    .foregroundStyle(NativeHelixTheme.ink)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)

                if message.kind == .transcript && message.noteState != .notEligible {
                    AssistantTranscriptNoteAction(message: message, saveNote: saveNote)
                }

                if message.kind == .answer {
                    AssistantAnswerMetadata(message: message)
                    AssistantAnswerActions(
                        message: message,
                        isGlassesConnected: isGlassesConnected,
                        canRequestDeeperAnswer: canRequestDeeperAnswer,
                        isRequestingDeeperAnswer: isRequestingDeeperAnswer,
                        sendToGlasses: sendToGlasses,
                        saveNote: saveNote,
                        requestDeeperAnswer: requestDeeperAnswer
                    )
                }
            }
            .padding(12)
            .frame(maxWidth: 560, alignment: .leading)
            .background(bubbleColor)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(borderColor)
            }

            if !isUser { Spacer(minLength: 30) }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(message.authorName): \(message.text)")
    }

    private var bubbleColor: Color {
        switch message.authorRole {
        case .user:
            return NativeHelixTheme.teal.opacity(0.12)
        case .assistant:
            return NativeHelixTheme.green.opacity(0.08)
        case .participant:
            return NativeHelixTheme.indigo.opacity(0.08)
        case .system:
            return NativeHelixTheme.amber.opacity(0.08)
        }
    }

    private var borderColor: Color {
        switch message.authorRole {
        case .user: return NativeHelixTheme.teal.opacity(0.28)
        case .assistant: return NativeHelixTheme.green.opacity(0.24)
        case .participant: return NativeHelixTheme.indigo.opacity(0.22)
        case .system: return NativeHelixTheme.amber.opacity(0.24)
        }
    }
}

private struct AssistantTranscriptNoteAction: View {
    let message: AssistantConversationMessage
    let saveNote: () -> Void

    var body: some View {
        Button(action: saveNote) {
            Label(label, systemImage: symbol)
        }
        .font(.caption.weight(.semibold))
        .buttonStyle(.plain)
        .foregroundStyle(NativeHelixTheme.indigo)
        .disabled(
            message.noteState == .saving
                || (message.noteState == .saved && !message.ownsKnowledgeItem)
        )
    }

    private var label: String {
        switch message.noteState {
        case .pendingAutoSave: return "Undo auto-save"
        case .saving: return "Saving…"
        case .saved:
            return message.ownsKnowledgeItem ? "Remove from Knowledge" : "Already in Knowledge"
        case .failed: return "Retry Knowledge save"
        case .ready: return "Save to Knowledge"
        case .notEligible: return "Not saved"
        }
    }

    private var symbol: String {
        switch message.noteState {
        case .pendingAutoSave: return "arrow.uturn.backward.circle"
        case .saving: return "hourglass"
        case .saved: return message.ownsKnowledgeItem ? "trash" : "checkmark.circle"
        case .failed: return "arrow.clockwise"
        default: return "note.text.badge.plus"
        }
    }
}

private struct AssistantMessageHeader: View {
    let message: AssistantConversationMessage
    let editSpeaker: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: symbolName)
                .font(.caption.weight(.semibold))
            if message.isAuthorEditable {
                Button(action: editSpeaker) {
                    HStack(spacing: 3) {
                        Text(message.authorName)
                        Image(systemName: "pencil")
                            .font(.caption2)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Edit speaker name for \(message.authorName)")
            } else {
                Text(message.authorName)
            }
            Spacer(minLength: 6)
            Text(message.createdAt.formatted(date: .omitted, time: .shortened))
                .font(.caption2)
                .foregroundStyle(NativeHelixTheme.secondaryInk)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(NativeHelixTheme.secondaryInk)
    }

    private var symbolName: String {
        switch message.kind {
        case .transcript: return "waveform"
        case .question: return "questionmark.bubble"
        case .answer: return "sparkles"
        case .reminder: return "checkmark.shield"
        case .error: return "exclamationmark.triangle"
        }
    }
}

private struct AssistantAnswerMetadata: View {
    let message: AssistantConversationMessage

    var body: some View {
        HStack(spacing: 6) {
            if let providerName = message.providerName {
                Text(providerName)
            }
            if let modelName = message.modelName {
                Text("·")
                Text(modelName)
            }
            if !message.isFinal {
                Text("· Streaming…")
            }
        }
        .font(.caption2)
        .foregroundStyle(NativeHelixTheme.secondaryInk)
        .lineLimit(1)
    }
}

private struct AssistantAnswerActions: View {
    let message: AssistantConversationMessage
    let isGlassesConnected: Bool
    let canRequestDeeperAnswer: Bool
    let isRequestingDeeperAnswer: Bool
    let sendToGlasses: () -> Void
    let saveNote: () -> Void
    let requestDeeperAnswer: () -> Void

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 14) {
                actionButtons
            }
            VStack(alignment: .leading, spacing: 9) {
                actionButtons
            }
        }
        .font(.caption.weight(.semibold))
        .buttonStyle(.plain)
        .foregroundStyle(NativeHelixTheme.indigo)
    }

    @ViewBuilder
    private var actionButtons: some View {
        Group {
            Button(action: sendToGlasses) {
                Label(hudLabel, systemImage: "eyeglasses")
            }
            .disabled(!isGlassesConnected)
            .accessibilityHint(isGlassesConnected ? "Queues this answer for the G1 display" : "Connect G1 glasses first")

            Button(action: saveNote) {
                Label(noteLabel, systemImage: noteSymbol)
            }
            .disabled(
                message.noteState == .saving
                    || message.noteState == .notEligible
                    || (message.noteState == .saved && !message.ownsKnowledgeItem)
            )

            if canRequestDeeperAnswer {
                Button(action: requestDeeperAnswer) {
                    Label(
                        isRequestingDeeperAnswer ? "Thinking…" : "Think deeper",
                        systemImage: isRequestingDeeperAnswer ? "hourglass" : "brain.head.profile"
                    )
                }
                .disabled(isRequestingDeeperAnswer)
            }
        }
    }

    private var hudLabel: String {
        message.hudState.actionLabel
    }

    private var noteLabel: String {
        switch message.noteState {
        case .notEligible: return "Not saved"
        case .ready: return "Save to Knowledge"
        case .pendingAutoSave: return "Undo auto-save"
        case .saving: return "Saving…"
        case .saved:
            return message.ownsKnowledgeItem ? "Remove from Knowledge" : "Already in Knowledge"
        case .failed: return "Retry Knowledge save"
        }
    }

    private var noteSymbol: String {
        switch message.noteState {
        case .saved: return message.ownsKnowledgeItem ? "trash" : "checkmark.circle"
        case .pendingAutoSave: return "arrow.uturn.backward.circle"
        case .saving: return "hourglass"
        case .failed: return "arrow.clockwise"
        default: return "note.text.badge.plus"
        }
    }
}

private struct AssistantLiveTranscriptBubble: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "waveform")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(NativeHelixTheme.teal)
                .symbolEffect(.variableColor.iterative, isActive: true)
            VStack(alignment: .leading, spacing: 3) {
                Text("Unknown speaker · listening")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(NativeHelixTheme.secondaryInk)
                Text(text)
                    .font(.footnote)
                    .foregroundStyle(NativeHelixTheme.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(NativeHelixTheme.teal.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityLabel("Live transcript from unknown speaker: \(text)")
    }
}
