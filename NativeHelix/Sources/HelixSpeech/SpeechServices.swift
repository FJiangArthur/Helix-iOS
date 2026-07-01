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
    private let questionPrefixes = [
        "what", "why", "how", "when", "where", "who", "which",
        "can", "could", "should", "would", "is", "are", "do", "does"
    ]

    public init() {}

    public func detectQuestions(in transcript: String) -> [QuestionCandidate] {
        splitSentences(transcript)
            .compactMap { sentence in
                let trimmed = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
                guard isQuestion(trimmed) else { return nil }
                return QuestionCandidate(text: trimmed, confidence: trimmed.hasSuffix("?") ? 0.95 : 0.72)
            }
    }

    private func splitSentences(_ transcript: String) -> [String] {
        transcript
            .split(whereSeparator: { ".?!".contains($0) })
            .map(String.init)
    }

    private func isQuestion(_ sentence: String) -> Bool {
        guard !sentence.isEmpty else { return false }
        let lowercased = sentence.lowercased()
        if sentence.hasSuffix("?") { return true }
        return questionPrefixes.contains { lowercased == $0 || lowercased.hasPrefix($0 + " ") }
    }
}

public struct DuplicateQuestionSuppressor: Sendable {
    public init() {}

    public func uniqueQuestions(_ candidates: [QuestionCandidate]) -> [QuestionCandidate] {
        var seen = Set<String>()
        return candidates.filter { candidate in
            let key = candidate.text
                .lowercased()
                .replacingOccurrences(of: "[^a-z0-9 ]", with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return seen.insert(key).inserted
        }
    }
}
