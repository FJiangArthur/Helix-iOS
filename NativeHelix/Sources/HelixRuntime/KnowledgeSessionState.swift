import Foundation
import HelixConversation
import HelixCore
import HelixPersistence
import NaturalLanguage
import Observation

public enum AssistantNoteCategory: String, Equatable, Sendable {
    case fact = "Fact"
    case decision = "Decision"
    case actionItem = "Action item"
}

public struct AssistantNoteDraft: Equatable, Sendable {
    public let content: String
    public let category: AssistantNoteCategory

    public init(content: String, category: AssistantNoteCategory) {
        self.content = content
        self.category = category
    }
}

/// Conservative policy for automatic Knowledge capture. It intentionally
/// excludes uncertain, sensitive, truncated, and question-like content. A
/// user can still save an answer manually when the automatic policy declines.
public enum AssistantNoteCapturePolicy {
    /// Offline/keyless answers are useful for exercising the product flow,
    /// but they are canned fixtures rather than knowledge-worthy model
    /// output. Keep them available for an explicit manual save while never
    /// persisting them automatically.
    public static func permitsAutomaticCapture(answerModel: String?) -> Bool {
        let model = trimmed(answerModel ?? "").lowercased()
        return !model.isEmpty && !model.hasPrefix("deterministic")
    }

    public static func automaticDraft(
        question rawQuestion: String,
        answer rawAnswer: String
    ) -> AssistantNoteDraft? {
        let question = trimmed(rawQuestion)
        let answer = trimmed(rawAnswer)
        let questionLetterCount = question.unicodeScalars.reduce(into: 0) { count, scalar in
            if CharacterSet.letters.contains(scalar) { count += 1 }
        }
        guard question.count >= 4, questionLetterCount >= 3, answer.count >= 12 else {
            return nil
        }

        let normalizedAnswer = normalized(answer)
        let questionLeadPattern = #"^(?:(?:can|could|should|would|will|do|does|did|is|are|was|were|has|have|had)\s+(?:i|you|we|they|he|she|it|there)|(?:what|why|how|when|where|who|which)\s+(?:am|is|are|was|were|do|does|did|have|has|had|can|could|will|would|should|must))\b"#
        guard !hasQuestionTerminal(answer),
              normalizedAnswer.range(of: questionLeadPattern, options: .regularExpression) == nil else {
            return nil
        }
        let failureLikePrefixes = [
            "error:", "failed:", "failure:", "api key", "unauthorized",
            "i don't know", "i do not know", "not enough information"
        ]
        guard !failureLikePrefixes.contains(where: { normalizedAnswer.hasPrefix($0) }) else {
            return nil
        }
        let metaAnswerMarkers = [
            "cut off", "cut-off", "incomplete question", "question is incomplete",
            "please repeat", "repeat the question", "rephrase", "clarify the question",
            "could you clarify", "need more context", "needs more context",
            "not enough context", "insufficient context", "without more context"
        ]
        guard !metaAnswerMarkers.contains(where: { normalizedAnswer.contains($0) }) else {
            return nil
        }
        let lowConfidenceMarkers = ["maybe", "might", "not sure", "i think", "possibly", "could be"]
        guard !lowConfidenceMarkers.contains(where: { normalizedAnswer.contains($0) }) else {
            return nil
        }

        guard !containsSensitiveContent(question + " " + answer) else {
            return nil
        }

        let actionMarkers = [
            "action item", "next step", "follow up", "follow-up", "we need to",
            "i need to", "todo", "to-do"
        ]
        let decisionMarkers = [
            "decision", "decided", "agreed", "approved", "selected", "chosen",
            "will use", "will ship", "we'll use", "we will use"
        ]

        let category: AssistantNoteCategory
        if actionMarkers.contains(where: { normalizedAnswer.contains($0) }) {
            category = .actionItem
        } else if decisionMarkers.contains(where: { normalizedAnswer.contains($0) }) {
            category = .decision
        } else {
            let questionLead = normalized(question).split(separator: " ").first.map(String.init) ?? ""
            let directFactualQuestionLeads: Set<String> = ["what", "who", "when", "where", "which"]
            let explanatoryQuestionLeads: Set<String> = ["why", "how"]
            let explanatoryFactMarkers = [" is ", " are ", " uses ", " means ", " refers to ", " because "]
            let paddedAnswer = " \(normalizedAnswer) "
            let looksFactual = directFactualQuestionLeads.contains(questionLead)
                || (explanatoryQuestionLeads.contains(questionLead)
                    && explanatoryFactMarkers.contains(where: { paddedAnswer.contains($0) }))
            let wordCount = answer.split(whereSeparator: { $0.isWhitespace }).count
            guard looksFactual, answer.count >= 40, wordCount >= 6 else { return nil }
            category = .fact
        }

        return AssistantNoteDraft(
            content: "Question: \(question)\n\nAnswer: \(answer)",
            category: category
        )
    }

    public static func isDuplicate(
        _ content: String,
        existingContents: [String],
        deduplication: KnowledgeMemoryDeduplication = .exact
    ) -> Bool {
        let candidate = KnowledgeMemoryText.duplicateKey(
            content,
            deduplication: deduplication
        )
        guard !candidate.isEmpty else { return false }
        return existingContents.contains {
            KnowledgeMemoryText.duplicateKey(
                $0,
                deduplication: deduplication
            ) == candidate
        }
    }

    public static func automaticDraft(statement rawStatement: String) -> AssistantNoteDraft? {
        automaticDrafts(statement: rawStatement).first
    }

    /// Splits a finalized utterance before classification so a question can
    /// never be smuggled into a saved decision merely because a later sentence
    /// ends in a period. This also handles Arabic/CJK punctuation and quoted or
    /// bracketed questions.
    public static func automaticDrafts(statement rawStatement: String) -> [AssistantNoteDraft] {
        // Inspect the unsplit utterance first. Credential formats such as JWTs
        // contain periods that sentence tokenizers treat as boundaries; no
        // credential fragment may become a separate, apparently benign note.
        guard !containsSensitiveContent(rawStatement) else { return [] }
        return sentenceCandidates(in: rawStatement).compactMap(classifyStatement)
    }

    private static func classifyStatement(_ rawStatement: String) -> AssistantNoteDraft? {
        let statement = trimmingBoundaryClosers(rawStatement)
        guard statement.count >= 12, statement.count <= 280,
              !hasQuestionTerminal(statement) else { return nil }

        let normalizedStatement = normalized(statement)
        guard !containsSensitiveContent(statement) else { return nil }
        let uncertaintyMarkers = ["maybe", "might", "not sure", "possibly", "could be", "i think"]
        guard !uncertaintyMarkers.contains(where: { normalizedStatement.contains($0) }) else {
            return nil
        }

        let decisionPattern = #"^(i|we|the team)\s+(decided|agreed|chose|confirmed|settled on)\b|^(decision|decision made)\s*[:\-]"#
        let actionPattern = #"^(action item|todo|to-do)\s*[:\-]|^(i|we|you|[\p{L}][\p{L}'-]{1,30})\s+(need(s)? to|must|will|should|have to|has to|am going to|are going to|is going to)\b"#
        let factPattern = #"^(remember|note)\s+(that\s+)?|^(my|our|the)\s+(email|phone|address|timezone|birthday|preference|favorite|deadline|meeting|appointment|launch|release|reservation|flight|project)\b.{0,50}\b(is|are|starts|ends|moved to|has moved to|has been moved to)\b"#

        let category: AssistantNoteCategory
        if normalizedStatement.range(of: decisionPattern, options: .regularExpression) != nil {
            category = .decision
        } else if normalizedStatement.range(of: actionPattern, options: .regularExpression) != nil {
            category = .actionItem
        } else if normalizedStatement.range(of: factPattern, options: .regularExpression) != nil {
            category = .fact
        } else {
            return nil
        }
        guard !hasLocalQuestionShape(normalizedStatement, category: category) else {
            return nil
        }
        return AssistantNoteDraft(content: statement, category: category)
    }

    private static let sensitiveTermPatterns = [
        #"\b(?:password|passcode|pin|secret|ssn|cvv)\b"#,
        #"\b(?:api[\s_\p{Pd}]*key|private[\s_\p{Pd}]*key|seed[\s_\p{Pd}]*phrase|social[\s_\p{Pd}]*security|credit[\s_\p{Pd}]*card|card[\s_\p{Pd}]*number)\b"#
    ]

    /// Credential terms remain deliberately narrower than a generic "token"
    /// marker. Product/model discussions such as "token limit" and "token
    /// budget" are useful notes, while authentication material must never be
    /// captured without an explicit user action.
    private static let credentialPatterns = [
        #"\b(?:access|auth|authentication|bearer|oauth2?|refresh|session)[\s_\p{Pd}]*tokens?\b"#,
        #"\brecovery[\s_\p{Pd}]*codes?\b"#,
        #"\bauthorization\s*:\s*bearer\b"#,
        #"\bbearer\s+(?=[a-z0-9._~+/=-]{12,}\b)(?=[^\s]*[0-9._~+/=-])[a-z0-9._~+/=-]+\b"#,
        #"\beyj[a-z0-9_-]{6,}\.[a-z0-9_-]{6,}\.[a-z0-9_-]{6,}\b"#
    ]

    private static let questionTerminators: Set<Character> = ["?", "？", "؟"]

    private static let localQuestionTailPatterns = [
        #"\b(?:isn|aren|wasn|weren|don|doesn|didn)['’]t\s+(?:it|that|this|there|they|we|you|he|she)(?:\s+(?:though|really|exactly))?\s*[.!。！]*$"#,
        #"\b(?:can|couldn|won|wouldn|shouldn|hasn|haven|hadn)['’]t\s+(?:it|that|this|there|they|we|you|he|she)(?:\s+(?:though|really|exactly))?\s*[.!。！]*$"#,
        #"\b(?:am|is|are|was|were|do|does|did|can|could|will|would|should|shall|have|has|had)\s+(?:i|it|that|this|there|they|we|you|he|she)(?:\s+(?:though|really|exactly))?\s*[.!。！]*$"#,
        #",\s*(?:right|correct|yes\s+or\s+no)(?:\s+(?:though|really|exactly))?\s*[.!。！]*$"#
    ]

    private static let terminalWHQuestionRegex = try! NSRegularExpression(
        pattern: #"\b(?:what|which|when|where|who|whom|whose|why|how)\b"#,
        options: [.caseInsensitive]
    )
    private static let clauseAuxiliaries: Set<String> = [
        "am", "is", "are", "was", "were", "be", "been", "being",
        "do", "does", "did", "have", "has", "had", "can", "could",
        "will", "would", "should", "shall", "may", "might", "must"
    ]
    private static let clauseSubjectPronouns: Set<String> = [
        "i", "we", "you", "he", "she", "it", "they", "there"
    ]
    private static let clauseDeterminers: Set<String> = [
        "the", "a", "an", "my", "our", "your", "his", "her", "its", "their",
        "this", "that", "these", "those"
    ]
    private static let clauseSelectorNouns: Set<String> = [
        "day", "date", "time", "room", "airport", "offset", "people", "person",
        "name", "number", "option", "route", "timezone", "location", "place"
    ]
    private static let embeddingGovernorWords: Set<String> = [
        "remember", "note", "decide", "decided", "agree", "agreed", "choose", "chose",
        "confirm", "confirmed", "explain", "explains", "explained", "document", "documents",
        "documented", "describe", "describes", "described", "know", "knows", "knew",
        "understand", "understands", "show", "shows", "tell", "tells", "discuss",
        "discusses", "determine", "determines", "determined", "schedule", "scheduled"
    ]
    private static let actionGovernorPredecessors: Set<String> = [
        "to", "will", "must", "should", "can", "could", "would", "shall", "may", "might"
    ]

    private struct EmbeddingGovernor {
        let present: Bool
        let allowsArbitraryAuxiliarySubject: Bool
    }

    private static let boundaryCloserCharacters = CharacterSet(
        charactersIn: "\"'“”‘’()[]{}<>«»"
    )

    private static func sentenceCandidates(in text: String) -> [String] {
        let tokenizer = NLTokenizer(unit: .sentence)
        tokenizer.string = text
        var sentences: [String] = []
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            let candidate = trimmed(String(text[range]))
            if !candidate.isEmpty { sentences.append(candidate) }
            return true
        }
        let fallback = trimmed(text)
        return sentences.isEmpty && !fallback.isEmpty ? [fallback] : sentences
    }

    private static func hasQuestionTerminal(_ text: String) -> Bool {
        let withoutClosers = text.trimmingCharacters(
            in: .whitespacesAndNewlines.union(boundaryCloserCharacters)
        )
        guard let final = withoutClosers.last else { return false }
        return questionTerminators.contains(final)
    }

    /// Live question classification can be unavailable, so transcript capture
    /// keeps a small local backstop for high-confidence English question forms.
    /// A trailing WH noun/fragment is too ambiguous to save without a live
    /// classifier. Embedded clauses remain eligible, such as "how the model
    /// works" and "which gives us three days".
    private static func hasLocalQuestionShape(
        _ normalizedText: String,
        category: AssistantNoteCategory
    ) -> Bool {
        if localQuestionTailPatterns.contains(where: {
            normalizedText.range(of: $0, options: .regularExpression) != nil
        }) {
            return true
        }
        let fullRange = NSRange(normalizedText.startIndex..., in: normalizedText)
        guard let whMatch = terminalWHQuestionRegex.matches(
            in: normalizedText,
            range: fullRange
        ).last else { return false }
        let tailLocation = NSMaxRange(whMatch.range)
        let prefixRange = NSRange(location: 0, length: whMatch.range.location)
        let tailRange = NSRange(
            location: tailLocation,
            length: fullRange.location + fullRange.length - tailLocation
        )
        guard let stringWHRange = Range(whMatch.range, in: normalizedText),
              let stringTailRange = Range(tailRange, in: normalizedText),
              let stringPrefixRange = Range(prefixRange, in: normalizedText) else { return true }
        let prefix = normalizedText[stringPrefixRange].trimmingCharacters(in: .whitespacesAndNewlines)
        let followsClauseComma = prefix.hasSuffix(",") || prefix.hasSuffix("，")
        return !looksLikeEmbeddedWHClause(
            String(normalizedText[stringTailRange]),
            whWord: String(normalizedText[stringWHRange]).lowercased(),
            followsClauseComma: followsClauseComma,
            governor: embeddingGovernor(
                String(prefix),
                category: category
            )
        )
    }

    private static func looksLikeEmbeddedWHClause(
        _ rawTail: String,
        whWord: String,
        followsClauseComma: Bool,
        governor: EmbeddingGovernor
    ) -> Bool {
        let tokens = wordTokens(in: rawTail)
        guard let first = tokens.first else { return false }

        let auxiliaryIndex = tokens.firstIndex(where: clauseAuxiliaries.contains)
        let relativePronoun = ["which", "who", "whom", "whose"].contains(whWord)
        let directFiniteRelative = relativePronoun &&
            tokens.count >= 2 &&
            (clauseAuxiliaries.contains(first) || looksLikeFiniteVerb(first))
        if followsClauseComma { return directFiniteRelative }
        if !governor.present { return false }
        if whWord == "how", ["many", "much"].contains(first) { return false }
        if clauseSubjectPronouns.contains(first), tokens.count >= 2 {
            let predicate = tokens[1]
            return clauseAuxiliaries.contains(predicate) ||
                looksLikeFiniteVerb(predicate) ||
                tokens.count >= 3
        }
        if clauseDeterminers.contains(first) {
            if let auxiliaryIndex, auxiliaryIndex >= 1 { return true }
            if tokens.count >= 3, looksLikeFiniteVerb(tokens[tokens.count - 1]) { return true }
        }
        if let auxiliaryIndex,
           auxiliaryIndex >= 1,
           !clauseSelectorNouns.contains(first) {
            return true
        }
        if looksLikeFiniteVerb(first) { return true }
        if tokens.count >= 2, looksLikeFiniteVerb(tokens[1]) { return true }
        if ["how", "when", "where", "why"].contains(whWord) {
            if let auxiliaryIndex, auxiliaryIndex >= 1 { return true }
        }
        if governor.allowsArbitraryAuxiliarySubject, auxiliaryIndex != nil { return true }
        return directFiniteRelative
    }

    private static func embeddingGovernor(
        _ prefix: String,
        category: AssistantNoteCategory
    ) -> EmbeddingGovernor {
        let tokens = wordTokens(in: prefix)
        guard let last = tokens.last else {
            return EmbeddingGovernor(present: false, allowsArbitraryAuxiliarySubject: false)
        }
        if embeddingGovernorWords.contains(last) || looksLikeFiniteVerb(last) {
            return EmbeddingGovernor(present: true, allowsArbitraryAuxiliarySubject: true)
        }
        if clauseAuxiliaries.contains(last) {
            return EmbeddingGovernor(present: true, allowsArbitraryAuxiliarySubject: false)
        }
        let actionBaseVerbGovernor = category == .actionItem &&
            tokens.count >= 2 &&
            actionGovernorPredecessors.contains(tokens[tokens.count - 2])
        return EmbeddingGovernor(
            present: actionBaseVerbGovernor,
            allowsArbitraryAuxiliarySubject: actionBaseVerbGovernor
        )
    }

    private static func wordTokens(in text: String) -> [String] {
        let tokenizer = NLTokenizer(unit: .word)
        tokenizer.string = text
        var tokens: [String] = []
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            let token = text[range]
                .lowercased()
                .trimmingCharacters(in: CharacterSet(charactersIn: "'’"))
            if !token.isEmpty { tokens.append(token) }
            return true
        }
        return tokens
    }

    private static func looksLikeFiniteVerb(_ token: String) -> Bool {
        token.count >= 4 &&
            (token.hasSuffix("s") || token.hasSuffix("ed") || token.hasSuffix("ing"))
    }

    private static func trimmingBoundaryClosers(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines.union(boundaryCloserCharacters))
    }

    private static func trimmed(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func containsSensitiveContent(_ text: String) -> Bool {
        let candidate = normalized(text.precomposedStringWithCompatibilityMapping)
        return (sensitiveTermPatterns + credentialPatterns).contains { pattern in
            candidate.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
        }
    }

    private static func normalized(_ text: String) -> String {
        trimmed(text)
            .lowercased()
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
    }
}

public enum AssistantAutomaticKnowledgeTargetKind: String, Equatable, Hashable, Sendable {
    case transcript
    case answer
}

public struct AssistantAutomaticKnowledgeTarget: Equatable, Hashable, Sendable {
    public let conversationGeneration: UInt64
    public let sequence: UInt64
    public let kind: AssistantAutomaticKnowledgeTargetKind
    public let index: Int

    public init(
        conversationGeneration: UInt64,
        sequence: UInt64,
        kind: AssistantAutomaticKnowledgeTargetKind,
        index: Int
    ) {
        self.conversationGeneration = conversationGeneration
        self.sequence = sequence
        self.kind = kind
        self.index = index
    }
}

public enum AssistantAutomaticKnowledgeReceiptState: String, Equatable, Sendable {
    case pending
    case saving
    case saved
    case failed
    case cancelled
}

public struct AssistantAutomaticKnowledgeReceipt: Equatable, Sendable {
    public let target: AssistantAutomaticKnowledgeTarget
    public let draft: AssistantNoteDraft
    public var state: AssistantAutomaticKnowledgeReceiptState
    public var knowledgeItemID: UUID?
    public var ownsKnowledgeItem: Bool
    public var previousKnowledgeItem: NativeKnowledgeItem?
}

/// Runtime-owned automatic capture. It is fed by committed engine outcomes,
/// independent of whether the Assistant SwiftUI screen is mounted. Receipts
/// let the UI expose a truthful grace period, durable state, and scoped Undo.
@MainActor
@Observable
public final class NativeAutomaticKnowledgeCaptureState {
    public private(set) var receipts: [
        AssistantAutomaticKnowledgeTarget: AssistantAutomaticKnowledgeReceipt
    ] = [:]

    private let knowledgeLibrary: NativeKnowledgeLibraryState
    private let graceNanoseconds: UInt64
    @ObservationIgnored
    private var captureTasks: [AssistantAutomaticKnowledgeTarget: Task<Void, Never>] = [:]

    public init(
        knowledgeLibrary: NativeKnowledgeLibraryState,
        graceNanoseconds: UInt64 = 4_000_000_000
    ) {
        self.knowledgeLibrary = knowledgeLibrary
        self.graceNanoseconds = graceNanoseconds
    }

    public func schedule(_ outcome: NativeLiveTranscriptOutcome) {
        guard !outcome.isMetadataUpdate else { return }
        for (target, draft) in Self.candidates(for: outcome) {
            enqueue(target: target, draft: draft)
        }
    }

    public func targets(
        conversationGeneration: UInt64,
        sequence: UInt64,
        kind: AssistantAutomaticKnowledgeTargetKind
    ) -> Set<AssistantAutomaticKnowledgeTarget> {
        Set(receipts.keys.filter {
            $0.conversationGeneration == conversationGeneration
                && $0.sequence == sequence
                && $0.kind == kind
        })
    }

    public func cancel(_ targets: Set<AssistantAutomaticKnowledgeTarget>) {
        for target in targets {
            guard var receipt = receipts[target], receipt.state == .pending else { continue }
            captureTasks.removeValue(forKey: target)?.cancel()
            receipt.state = .cancelled
            receipt.knowledgeItemID = nil
            receipt.ownsKnowledgeItem = false
            receipt.previousKnowledgeItem = nil
            receipts[target] = receipt
        }
    }

    public func captureImmediately(
        _ targets: Set<AssistantAutomaticKnowledgeTarget>
    ) async {
        for target in targets {
            captureTasks.removeValue(forKey: target)?.cancel()
            await capture(target, isExplicitSave: true)
        }
    }

    public func removeOwned(
        _ targets: Set<AssistantAutomaticKnowledgeTarget>
    ) async {
        for target in targets {
            guard let receipt = receipts[target],
                  receipt.state == .saved,
                  receipt.ownsKnowledgeItem,
                  let itemID = receipt.knowledgeItemID else { continue }
            guard let currentItem = knowledgeLibrary.snapshot.memories.first(where: {
                $0.id == itemID
            }) else {
                resetReceipts(referencing: itemID, restoredItem: nil)
                continue
            }
            let mutation = KnowledgeMemoryUpsertResult(
                item: currentItem,
                wasInserted: receipt.previousKnowledgeItem == nil,
                previousItem: receipt.previousKnowledgeItem
            )
            await knowledgeLibrary.undoMemoryUpsert(mutation)
            let restoredItem = knowledgeLibrary.snapshot.memories.first(where: { $0.id == itemID })
            if let expected = receipt.previousKnowledgeItem {
                guard restoredItem == expected else { continue }
            } else {
                guard restoredItem == nil else { continue }
            }
            resetReceipts(referencing: itemID, restoredItem: restoredItem)
        }
    }

    private func resetReceipts(
        referencing itemID: UUID,
        restoredItem: NativeKnowledgeItem?
    ) {
        let referencedTargets = receipts.compactMap { target, receipt in
            receipt.knowledgeItemID == itemID ? target : nil
        }
        for target in referencedTargets {
            guard var receipt = receipts[target] else { continue }
            if let restoredItem,
               KnowledgeMemoryText.duplicateKey(receipt.draft.content)
                == KnowledgeMemoryText.duplicateKey(restoredItem.text) {
                receipt.state = .saved
                receipt.knowledgeItemID = restoredItem.id
                receipts[target] = receipt
                continue
            }
            captureTasks.removeValue(forKey: target)?.cancel()
            receipt.state = .cancelled
            receipt.knowledgeItemID = nil
            receipt.ownsKnowledgeItem = false
            receipt.previousKnowledgeItem = nil
            receipts[target] = receipt
        }
    }

    private func enqueue(
        target: AssistantAutomaticKnowledgeTarget,
        draft: AssistantNoteDraft
    ) {
        guard receipts[target] == nil else { return }
        receipts[target] = AssistantAutomaticKnowledgeReceipt(
            target: target,
            draft: draft,
            state: .pending,
            knowledgeItemID: nil,
            ownsKnowledgeItem: false,
            previousKnowledgeItem: nil
        )
        captureTasks[target] = Task { [weak self] in
            guard let self else { return }
            if self.graceNanoseconds > 0 {
                do {
                    try await Task.sleep(nanoseconds: self.graceNanoseconds)
                } catch {
                    return
                }
            }
            guard !Task.isCancelled else { return }
            await self.capture(target, isExplicitSave: false)
        }
    }

    private func capture(
        _ target: AssistantAutomaticKnowledgeTarget,
        isExplicitSave: Bool
    ) async {
        guard var receipt = receipts[target], receipt.state != .saved else { return }
        receipt.state = .saving
        receipts[target] = receipt

        let isAutomaticAnswer = !isExplicitSave && target.kind == .answer
        let deduplication: KnowledgeMemoryDeduplication = isAutomaticAnswer
            ? .automaticAnswer(quality: .fast)
            : .exact
        let source = isAutomaticAnswer
            ? KnowledgeMemorySource.automaticAnswer(
                category: receipt.draft.category.rawValue,
                quality: .fast
            )
            : "Helix Knowledge · \(receipt.draft.category.rawValue)"
        let result = await knowledgeLibrary.addMemoryIfAbsent(
            receipt.draft.content,
            source: source,
            deduplication: deduplication
        )
        captureTasks.removeValue(forKey: target)
        guard var current = receipts[target], current.state == .saving else { return }
        guard let result else {
            current.state = .failed
            receipts[target] = current
            return
        }
        current.state = .saved
        current.knowledgeItemID = result.item.id
        current.ownsKnowledgeItem = result.didMutate
        current.previousKnowledgeItem = result.previousItem
        receipts[target] = current
    }

    private static func candidates(
        for outcome: NativeLiveTranscriptOutcome
    ) -> [(AssistantAutomaticKnowledgeTarget, AssistantNoteDraft)] {
        var candidates: [(AssistantAutomaticKnowledgeTarget, AssistantNoteDraft)] = []
        var detectedQuestionKeys: [String] = []
        if let turn = outcome.turn {
            if turn.questionResults.isEmpty {
                if let question = turn.question?.text {
                    detectedQuestionKeys.append(normalizedQuestionKey(question))
                }
                if let question = turn.question?.text,
                   let answer = turn.answer,
                   AssistantNoteCapturePolicy.permitsAutomaticCapture(
                       answerModel: answer.model
                   ),
                   let draft = AssistantNoteCapturePolicy.automaticDraft(
                       question: question,
                       answer: answer.text
                   ) {
                    candidates.append((
                        AssistantAutomaticKnowledgeTarget(
                            conversationGeneration: outcome.conversationGeneration,
                            sequence: outcome.sequence,
                            kind: .answer,
                            index: 0
                        ),
                        draft
                    ))
                }
            } else {
                for (index, result) in turn.questionResults.enumerated() {
                    // A duplicate-suppressed result is still a question. Keep
                    // it out of transcript-note capture even though it does
                    // not create a second automatic answer note.
                    detectedQuestionKeys.append(normalizedQuestionKey(result.question.text))
                    guard result.suppressionReason == nil,
                          let answer = result.answer,
                          AssistantNoteCapturePolicy.permitsAutomaticCapture(
                              answerModel: answer.model
                          ),
                          let draft = AssistantNoteCapturePolicy.automaticDraft(
                              question: result.question.text,
                              answer: answer.text
                          ) else { continue }
                    candidates.append((
                        AssistantAutomaticKnowledgeTarget(
                            conversationGeneration: outcome.conversationGeneration,
                            sequence: outcome.sequence,
                            kind: .answer,
                            index: index
                        ),
                        draft
                    ))
                }
            }
        }

        for (index, draft) in AssistantNoteCapturePolicy
            .automaticDrafts(statement: outcome.segment.text)
            .enumerated() {
            let draftKey = normalizedQuestionKey(draft.content)
            let overlapsDetectedQuestion = detectedQuestionKeys.contains { questionKey in
                questionKeysOverlap(draftKey, questionKey)
            }
            guard !overlapsDetectedQuestion else { continue }
            candidates.append((
                AssistantAutomaticKnowledgeTarget(
                    conversationGeneration: outcome.conversationGeneration,
                    sequence: outcome.sequence,
                    kind: .transcript,
                    index: index
                ),
                draft
            ))
        }
        return candidates
    }

    private static let questionKeyTerminalPunctuation = CharacterSet(
        charactersIn: ".!?。！？؟"
    )

    private static func normalizedQuestionKey(_ text: String) -> String {
        text
            .precomposedStringWithCompatibilityMapping
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: questionKeyTerminalPunctuation)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
    }

    /// Classifier output is an exact spoken span, but it may normalize the
    /// span's terminal punctuation. Match that span inside a larger transcript
    /// whenever its neighbors are semantic boundaries (space or punctuation),
    /// without treating a substring inside another word as a question match.
    private static func questionKeysOverlap(_ lhs: String, _ rhs: String) -> Bool {
        lhs == rhs
            || containsQuestionSpan(container: lhs, candidate: rhs)
            || containsQuestionSpan(container: rhs, candidate: lhs)
    }

    private static func containsQuestionSpan(container: String, candidate: String) -> Bool {
        guard !container.isEmpty, !candidate.isEmpty else { return false }
        var searchStart = container.startIndex
        while searchStart < container.endIndex,
              let range = container.range(
                  of: candidate,
                  range: searchStart..<container.endIndex
              ) {
            let hasLeadingBoundary = range.lowerBound == container.startIndex
                || !isQuestionKeyWordCharacter(container[container.index(before: range.lowerBound)])
            let hasTrailingBoundary = range.upperBound == container.endIndex
                || !isQuestionKeyWordCharacter(container[range.upperBound])
            if hasLeadingBoundary, hasTrailingBoundary { return true }
            searchStart = range.upperBound
        }
        return false
    }

    private static func isQuestionKeyWordCharacter(_ character: Character) -> Bool {
        character.isLetter || character.isNumber
    }
}

@MainActor
@Observable
public final class NativeSessionArchiveState {
    public private(set) var sessions: [NativeSessionSummary] = []
    public private(set) var failureReason = ""

    private let store: SessionArchiveStore

    public init(store: SessionArchiveStore = InMemorySessionArchiveStore()) {
        self.store = store
    }

    public var archiveSummary: String {
        "\(sessions.count) session\(sessions.count == 1 ? "" : "s")"
    }

    public var totalCostSummary: String {
        let totalMicros = sessions.reduce(0) { $0 + $1.totalCostMicros }
        guard totalMicros > 0 else { return "Free" }
        return String(format: "$%.4f", Double(totalMicros) / 1_000_000)
    }

    public var activeProjectSummary: String {
        let projects = Set(sessions.compactMap(\.projectName))
        return "\(projects.count) active"
    }

    public func refresh() async {
        sessions = await store.sessions()
    }

    public func archiveSession(_ session: NativeSessionSummary) async {
        await store.saveSession(session)
        await refresh()
    }

    public func seedDemoSession() async {
        await archiveSession(
            NativeSessionSummary(
                title: "Native LLM Q&A",
                mode: .general,
                transcriptPreview: "What is retrieval augmented generation?",
                answerPreview: "RAG grounds generation with retrieved project context.",
                projectName: "Helix Native",
                totalCostMicros: 2_300,
                segmentCount: 1,
                answerCount: 1
            )
        )
    }
}

@MainActor
@Observable
public final class NativeKnowledgeLibraryState {
    public private(set) var snapshot: NativeKnowledgeSnapshot
    public private(set) var failureReason = ""

    private let store: KnowledgeLibraryStore

    public init(
        store: KnowledgeLibraryStore = InMemoryKnowledgeLibraryStore(),
        snapshot: NativeKnowledgeSnapshot = NativeKnowledgeSnapshot()
    ) {
        self.store = store
        self.snapshot = snapshot
    }

    public var activeProjectName: String {
        snapshot.activeProject?.name ?? "None"
    }

    public var reviewSummary: String {
        let openTodos = snapshot.openTodoCount
        return openTodos == 0 ? "No pending items" : "\(openTodos) open todo\(openTodos == 1 ? "" : "s")"
    }

    public var documentSummary: String {
        let count = snapshot.documents.count
        return "\(count) document\(count == 1 ? "" : "s")"
    }

    public func refresh() async {
        snapshot = await store.snapshot()
    }

    public func createProject(name: String, summary: String = "", activate: Bool = true) async {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        await store.saveProject(
            NativeKnowledgeProject(
                name: trimmedName,
                summary: summary.trimmingCharacters(in: .whitespacesAndNewlines),
                isActive: activate
            )
        )
        await refresh()
    }

    public func setActiveProject(id: UUID?) async {
        await store.setActiveProject(id: id)
        await refresh()
    }

    public func ingestDocument(title: String, text: String, sourceURL: URL? = nil) async {
        await store.ingestDocument(title: title, text: text, sourceURL: sourceURL)
        await refresh()
    }

    public func addFact(_ text: String, source: String = "Manual") async {
        await store.addFact(text, source: source)
        await refresh()
    }

    public func addMemory(_ text: String, source: String = "Manual") async {
        await store.addMemory(text, source: source)
        await refresh()
    }

    public func addMemoryIfAbsent(
        _ text: String,
        source: String = "Manual",
        deduplication: KnowledgeMemoryDeduplication = .exact
    ) async -> KnowledgeMemoryUpsertResult? {
        let result = await store.addMemoryIfAbsent(
            text,
            source: source,
            deduplication: deduplication
        )
        await refresh()
        return result
    }

    public func undoMemoryUpsert(_ result: KnowledgeMemoryUpsertResult) async {
        await store.undoMemoryUpsert(result)
        await refresh()
    }

    public func removeMemory(id: UUID) async {
        await store.removeMemory(id: id)
        await refresh()
    }

    public func addTodo(_ title: String) async {
        await store.addTodo(title)
        await refresh()
    }

    public func completeTodo(id: UUID, isComplete: Bool) async {
        await store.completeTodo(id: id, isComplete: isComplete)
        await refresh()
    }

    public func seedDemoKnowledge() async {
        await createProject(
            name: "Helix Native",
            summary: "Native headless framework rewrite parity project.",
            activate: true
        )
        await addFact("Helix displays concise answers on Even G1 glasses.", source: "Native plan")
        await ingestDocument(
            title: "Native RAG Fixture",
            text: "Helix native RAG stores document chunks under the active project. Active answers should use imported document context when the user asks about project-specific behavior.",
            sourceURL: nil
        )
        await addMemory("User prefers direct speakable answers without meta phrasing.", source: "Conversation")
        await addTodo("Validate native G1 HUD on real hardware.")
    }
}
