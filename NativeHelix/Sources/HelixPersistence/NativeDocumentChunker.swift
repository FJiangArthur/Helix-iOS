import Foundation

public struct NativeDocumentChunker: Sendable {
    public var maxCharacters: Int
    public var overlapCharacters: Int

    public init(maxCharacters: Int = 640, overlapCharacters: Int = 80) {
        self.maxCharacters = max(160, maxCharacters)
        self.overlapCharacters = max(0, min(overlapCharacters, self.maxCharacters / 3))
    }

    public func chunks(from text: String) -> [String] {
        let normalized = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return [] }

        let sentences = splitSentences(normalized)
        var chunks: [String] = []
        var current = ""

        for sentence in sentences {
            if current.isEmpty {
                current = sentence
            } else if current.count + 1 + sentence.count <= maxCharacters {
                current += " " + sentence
            } else {
                chunks.append(current)
                current = overlapSuffix(from: current, prefixing: sentence)
            }

            while current.count > maxCharacters {
                let split = splitLongChunk(current)
                chunks.append(split.head)
                current = overlapSuffix(from: split.head, prefixing: split.tail)
            }
        }

        if !current.isEmpty {
            chunks.append(current)
        }

        return chunks
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private func splitSentences(_ text: String) -> [String] {
        var sentences: [String] = []
        var current = ""
        for character in text {
            current.append(character)
            if ".!?".contains(character) {
                let trimmed = current.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    sentences.append(trimmed)
                }
                current = ""
            }
        }
        let remainder = current.trimmingCharacters(in: .whitespacesAndNewlines)
        if !remainder.isEmpty {
            sentences.append(remainder)
        }
        return sentences
    }

    private func splitLongChunk(_ text: String) -> (head: String, tail: String) {
        let words = text.split(separator: " ").map(String.init)
        var headWords: [String] = []
        var headLength = 0
        var tailWords = words

        while let word = tailWords.first {
            let candidateLength = headLength + (headWords.isEmpty ? 0 : 1) + word.count
            guard candidateLength <= maxCharacters || headWords.isEmpty else { break }
            headWords.append(word)
            headLength = candidateLength
            tailWords.removeFirst()
        }

        return (headWords.joined(separator: " "), tailWords.joined(separator: " "))
    }

    private func overlapSuffix(from previous: String, prefixing next: String) -> String {
        guard overlapCharacters > 0 else { return next }
        let suffix = String(previous.suffix(overlapCharacters))
            .split(separator: " ")
            .dropFirst()
            .joined(separator: " ")
        guard !suffix.isEmpty else { return next }
        return "\(suffix) \(next)"
    }
}
