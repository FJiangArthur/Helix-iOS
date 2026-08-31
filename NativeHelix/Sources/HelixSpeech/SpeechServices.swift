import Foundation
import HelixCore

public protocol AudioFileTranscriber: Sendable {
    func transcribeAudioFile(at url: URL, backend: TranscriptionBackend, model: String) async throws -> TranscriptSegment
}

public struct DeterministicAudioFileTranscriber: AudioFileTranscriber {
    private let transcriptsByStem: [String: String]

    public init(transcriptsByStem: [String: String] = [:]) {
        self.transcriptsByStem = transcriptsByStem
    }

    public func transcribeAudioFile(at url: URL, backend: TranscriptionBackend, model: String) async throws -> TranscriptSegment {
        let stem = url.deletingPathExtension().lastPathComponent
        let text = transcriptsByStem[stem] ?? "What is retrieval augmented generation for an LLM?"
        return TranscriptSegment(text: text, isFinal: true, finalizedAt: Date())
    }
}

public struct QuestionDetector: Sendable {
    private struct SentenceFragment {
        var text: String
        var endedWithQuestionMark: Bool
    }

    private let questionPrefixes = [
        "what", "why", "how", "when", "where", "who", "which",
        "can", "could", "should", "would", "is", "are", "do", "does"
    ]

    public init() {}

    public func detectQuestions(in transcript: String) -> [QuestionCandidate] {
        splitSentences(transcript)
            .compactMap { fragment in
                let trimmed = fragment.text.trimmingCharacters(in: .whitespacesAndNewlines)
                guard isQuestion(trimmed, endedWithQuestionMark: fragment.endedWithQuestionMark) else {
                    return nil
                }
                return QuestionCandidate(
                    text: trimmed,
                    confidence: fragment.endedWithQuestionMark ? 0.95 : 0.72
                )
            }
    }

    private func splitSentences(_ transcript: String) -> [SentenceFragment] {
        var fragments: [SentenceFragment] = []
        var current = ""
        let characters = Array(transcript)
        var index = 0

        while index < characters.count {
            let character = characters[index]
            guard ".?!。？！؟".contains(character) else {
                current.append(character)
                index += 1
                continue
            }

            let trimmed = current.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                let endedWithQuestionMark = "?？؟".contains(character)
                var fragmentText = endedWithQuestionMark
                    ? trimmed + String(character)
                    : trimmed
                index += 1
                while index < characters.count,
                      "\"'”’»›)]}）］｝】」』".contains(characters[index]) {
                    fragmentText.append(characters[index])
                    index += 1
                }
                fragments.append(
                    SentenceFragment(
                        text: fragmentText,
                        endedWithQuestionMark: endedWithQuestionMark
                    )
                )
            } else {
                index += 1
            }
            current = ""
        }

        let trailing = current.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trailing.isEmpty {
            fragments.append(SentenceFragment(text: trailing, endedWithQuestionMark: false))
        }
        return fragments
    }

    private func isQuestion(_ sentence: String, endedWithQuestionMark: Bool) -> Bool {
        guard !sentence.isEmpty else { return false }
        if endedWithQuestionMark { return true }
        let lowercased = sentence.lowercased()
        return questionPrefixes.contains { lowercased == $0 || lowercased.hasPrefix($0 + " ") }
    }
}

public enum QuestionTextNormalizer {
    public static func duplicateKey(for text: String) -> String {
        text
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}

public struct DuplicateQuestionSuppressor: Sendable {
    public init() {}

    public func uniqueQuestions(_ candidates: [QuestionCandidate]) -> [QuestionCandidate] {
        var seen = Set<String>()
        return candidates.filter { candidate in
            let key = QuestionTextNormalizer.duplicateKey(for: candidate.text)
            return seen.insert(key).inserted
        }
    }
}
