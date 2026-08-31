import Foundation
import HelixAI
import HelixCore
import HelixSpeech

public struct QuestionDetectionPrompt: Equatable, Sendable {
    public var transcript: String
    public var sensitivity: QuestionDetectionSensitivity

    public init(transcript: String, sensitivity: QuestionDetectionSensitivity) {
        self.transcript = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        self.sensitivity = sensitivity
    }
}

public protocol QuestionDetectionLiveClassifying: Sendable {
    var providerDescription: String? { get }
    func classify(_ prompt: QuestionDetectionPrompt) async throws -> [QuestionCandidate]
}

public extension QuestionDetectionLiveClassifying {
    var providerDescription: String? { nil }
}

public protocol QuestionClassifying: Sendable {
    var sourceDescription: String { get }
    func detectQuestions(
        in transcript: String,
        sensitivity: QuestionDetectionSensitivity
    ) async -> [QuestionCandidate]
}

public extension QuestionClassifying {
    var sourceDescription: String { "heuristic" }
}

/// Uses the configured lightweight LLM for ambiguous or statement-form asks,
/// while retaining an immediate punctuation fast path and offline fallback.
public struct HybridQuestionClassifier: QuestionClassifying {
    private let liveClassifier: (any QuestionDetectionLiveClassifying)?
    private let heuristicDetector: QuestionDetector
    private let duplicateSuppressor: DuplicateQuestionSuppressor
    private let directQuestionFastPathConfidence: Double

    public init(
        liveClassifier: (any QuestionDetectionLiveClassifying)? = nil,
        heuristicDetector: QuestionDetector = QuestionDetector(),
        duplicateSuppressor: DuplicateQuestionSuppressor = DuplicateQuestionSuppressor(),
        directQuestionFastPathConfidence: Double = 0.95
    ) {
        self.liveClassifier = liveClassifier
        self.heuristicDetector = heuristicDetector
        self.duplicateSuppressor = duplicateSuppressor
        self.directQuestionFastPathConfidence = min(1, max(0, directQuestionFastPathConfidence))
    }

    public func detectQuestions(
        in transcript: String,
        sensitivity: QuestionDetectionSensitivity
    ) async -> [QuestionCandidate] {
        let trimmed = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        let heuristic = filtered(
            duplicateSuppressor.uniqueQuestions(heuristicDetector.detectQuestions(in: trimmed)),
            sensitivity: sensitivity
        )
        if !heuristic.isEmpty,
           isSingleExplicitQuestion(trimmed),
           heuristic.allSatisfy({ $0.confidence >= directQuestionFastPathConfidence }) {
            return heuristic
        }

        guard let liveClassifier else { return heuristic }
        do {
            let live = try await liveClassifier.classify(
                QuestionDetectionPrompt(transcript: trimmed, sensitivity: sensitivity)
            )
            let merged = filtered(
                duplicateSuppressor.uniqueQuestions(heuristic + live),
                sensitivity: sensitivity
            )
            return orderedByTranscriptPosition(merged, in: trimmed)
        } catch {
            return heuristic
        }
    }

    public var sourceDescription: String {
        guard let liveClassifier else { return "heuristic" }
        return "live:\(liveClassifier.providerDescription ?? "custom") + heuristic-fallback"
    }

    private func isSingleExplicitQuestion(_ transcript: String) -> Bool {
        let questionMarks: Set<Character> = ["?", "？", "؟"]
        let closingPunctuation: Set<Character> = [
            "\"", "'", "”", "’", "»", "›", ")", "]", "}", "）", "］", "｝", "】", "」", "』"
        ]
        let marks = transcript.reduce(into: 0) { count, character in
            if questionMarks.contains(character) { count += 1 }
        }
        guard marks == 1 else { return false }

        var terminalCharacters = Array(transcript.trimmingCharacters(in: .whitespacesAndNewlines))
        while terminalCharacters.last.map(closingPunctuation.contains) == true {
            terminalCharacters.removeLast()
        }
        guard terminalCharacters.last.map(questionMarks.contains) == true else { return false }
        terminalCharacters.removeLast()

        // A later explicit question must not bypass live classification for an
        // earlier statement-form question in the same finalized segment.
        let earlierSentenceBoundary: Set<Character> = [".", "!", "。", "！", "?", "？", "؟"]
        return !terminalCharacters.contains(where: earlierSentenceBoundary.contains)
    }

    private func filtered(
        _ candidates: [QuestionCandidate],
        sensitivity: QuestionDetectionSensitivity
    ) -> [QuestionCandidate] {
        candidates.compactMap { candidate in
            let text = candidate.text.trimmingCharacters(in: .whitespacesAndNewlines)
            let confidence = min(1, max(0, candidate.confidence))
            guard !text.isEmpty, confidence >= sensitivity.minimumConfidence else { return nil }
            return QuestionCandidate(id: candidate.id, text: text, confidence: confidence)
        }
    }

    private func orderedByTranscriptPosition(
        _ candidates: [QuestionCandidate],
        in transcript: String
    ) -> [QuestionCandidate] {
        candidates.enumerated().sorted { lhs, rhs in
            let leftOffset = transcriptOffset(of: lhs.element.text, in: transcript)
            let rightOffset = transcriptOffset(of: rhs.element.text, in: transcript)

            switch (leftOffset, rightOffset) {
            case let (left?, right?) where left != right:
                return left < right
            case (_?, nil):
                return true
            case (nil, _?):
                return false
            default:
                // Preserve detector order when the model paraphrases text that
                // cannot be placed in the source transcript, or for a tie.
                return lhs.offset < rhs.offset
            }
        }.map(\.element)
    }

    private func transcriptOffset(of candidate: String, in transcript: String) -> Int? {
        let full = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
        var withoutAddedTerminal = full
        let removableTerminal: Set<Character> = [
            "?", "？", "؟", "\"", "'", "”", "’", "»", "›",
            ")", "]", "}", "）", "］", "｝", "】", "」", "』"
        ]
        while withoutAddedTerminal.last.map(removableTerminal.contains) == true {
            withoutAddedTerminal.removeLast()
        }

        for searchText in [full, withoutAddedTerminal] where !searchText.isEmpty {
            if let range = transcript.range(
                of: searchText,
                options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive]
            ) {
                return transcript.distance(from: transcript.startIndex, to: range.lowerBound)
            }
        }
        return nil
    }
}

/// Adapts the normal provider abstraction to a compact question-classification
/// request. Runtime wires this to the provider's light model, independently of
/// the automatic answer and manual deep-answer providers.
public struct AnswerProviderQuestionLiveClassifier: QuestionDetectionLiveClassifying {
    private let provider: any HelixAnswerProvider

    public init(provider: any HelixAnswerProvider) {
        self.provider = provider
    }

    public var providerDescription: String? {
        "\(provider.kind.rawValue):\(provider.model)"
    }

    public func classify(_ prompt: QuestionDetectionPrompt) async throws -> [QuestionCandidate] {
        let request = AnswerRequest(
            question: classificationPrompt(for: prompt),
            activeSkill: ActiveSkill(
                value: "question-classification",
                label: "Question Classification",
                prompt: "Return only the requested JSON. Do not answer the questions."
            ),
            maxResponseSentences: 1
        )
        let response = try await provider.answer(for: request)
        return try Self.parse(response.text, transcript: prompt.transcript)
    }

    private func classificationPrompt(for prompt: QuestionDetectionPrompt) -> String {
        let sensitivityInstruction: String
        switch prompt.sensitivity {
        case .conservative:
            sensitivityInstruction = "Only include clear questions or direct requests for information."
        case .balanced:
            sensitivityInstruction = "Include clear questions and likely implicit requests for information."
        case .sensitive:
            sensitivityInstruction = "Also include plausible statement-form or indirect requests for information."
        }

        return """
        Detect every genuine question or request for information in this transcript, in any language. Preserve the speaker's language and terminal question punctuation. \(sensitivityInstruction) Do not answer anything. Return only JSON in this exact shape: {"questions":[{"text":"...","confidence":0.0}]}. Use an empty questions array when none are present.

        Transcript:
        \(prompt.transcript)
        """
    }

    private static func parse(
        _ rawText: String,
        transcript: String
    ) throws -> [QuestionCandidate] {
        let trimmed = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let start = trimmed.firstIndex(where: { $0 == "{" || $0 == "[" }),
              let end = trimmed.lastIndex(where: { $0 == "}" || $0 == "]" }),
              start <= end,
              let data = String(trimmed[start...end]).data(using: .utf8) else {
            throw HelixError.providerFailure("Question classifier returned invalid JSON.")
        }

        let decoder = JSONDecoder()
        let items: [QuestionPayload]
        if let wrapper = try? decoder.decode(ResponsePayload.self, from: data) {
            items = wrapper.questions
        } else {
            items = try decoder.decode([QuestionPayload].self, from: data)
        }

        let located = items.enumerated().compactMap { index, item -> (Int, Int, QuestionCandidate)? in
            let text = item.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty,
                  let range = transcriptRange(matching: text, in: transcript) else {
                return nil
            }
            return (
                transcript.distance(from: transcript.startIndex, to: range.lowerBound),
                index,
                QuestionCandidate(
                    text: text,
                    confidence: min(1, max(0, item.confidence ?? 0.5))
                )
            )
        }
        return located.sorted {
            $0.0 == $1.0 ? $0.1 < $1.1 : $0.0 < $1.0
        }.map(\.2)
    }

    /// The classifier is asked to preserve punctuation, but models commonly
    /// turn an implicit statement-form ask ending in `.` into the same text
    /// ending in `?`. Reconcile only that terminal punctuation difference so
    /// the candidate remains source-grounded without admitting paraphrases or
    /// fabricated questions.
    private static func transcriptRange(
        matching candidate: String,
        in transcript: String
    ) -> Range<String.Index>? {
        let options: String.CompareOptions = [
            .caseInsensitive, .diacriticInsensitive, .widthInsensitive
        ]
        if let exact = transcript.range(of: candidate, options: options) {
            return exact
        }

        let questionTerminators: Set<Character> = ["?", "？", "؟"]
        let boundaryClosers: Set<Character> = [
            "\"", "'", "”", "’", "»", "›", ")", "]", "}",
            "）", "］", "｝", "】", "」", "』"
        ]
        var characters = Array(candidate.trimmingCharacters(in: .whitespacesAndNewlines))
        while characters.last.map(boundaryClosers.contains) == true {
            characters.removeLast()
        }
        guard characters.last.map(questionTerminators.contains) == true else {
            return nil
        }
        characters.removeLast()
        let sourceText = String(characters).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sourceText.isEmpty else { return nil }
        return transcript.range(of: sourceText, options: options)
    }

    private struct ResponsePayload: Decodable {
        var questions: [QuestionPayload]
    }

    private struct QuestionPayload: Decodable {
        var text: String
        var confidence: Double?
    }
}
