import Foundation
import HelixCore

public protocol HelixAnswerProvider: Sendable {
    var kind: LlmProviderKind { get }
    var model: String { get }
    func streamAnswer(for request: AnswerRequest) -> AsyncThrowingStream<String, Error>
}

public extension HelixAnswerProvider {
    func answer(for request: AnswerRequest) async throws -> AnswerResponse {
        var chunks: [String] = []
        for try await chunk in streamAnswer(for: request) {
            chunks.append(chunk)
        }
        return AnswerResponse(
            text: chunks.joined(),
            provider: kind,
            model: model,
            citations: request.citationSources
        )
    }
}

public struct DeterministicAnswerProvider: HelixAnswerProvider {
    public let kind: LlmProviderKind
    public let model: String

    public init(kind: LlmProviderKind = .openAI, model: String = "deterministic-native") {
        self.kind = kind
        self.model = model
    }

    public func streamAnswer(for request: AnswerRequest) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                let text = Self.makeAnswer(for: request)
                for word in text.split(separator: " ") {
                    continuation.yield(String(word) + " ")
                }
                continuation.finish()
            }
        }
    }

    private static func makeAnswer(for request: AnswerRequest) -> String {
        if !request.webSearchResults.isEmpty {
            let evidence = request.webSearchResults.map(\.snippet).joined(separator: " ")
            if !request.projectContext.isEmpty {
                let facts = request.requiredFacts.isEmpty ? request.projectContext : request.requiredFacts
                return "Use the project context: \(facts.joined(separator: ", ")). Web evidence: \(evidence)"
            }
            return "Based on web search evidence: \(evidence)"
        }

        if !request.projectContext.isEmpty {
            let facts = request.requiredFacts.isEmpty ? request.projectContext : request.requiredFacts
            return "Use the project context: \(facts.joined(separator: ", "))."
        }

        switch request.mode {
        case .interview:
            return "Answer directly with situation, action, result, and one measurable impact."
        case .passive:
            return "Noted. No active answer is needed unless a correction is required."
        case .general:
            return "An LLM uses transformer attention to predict useful next tokens from context."
        }
    }
}

public struct AnswerStyleValidator: Sendable {
    private let bannedPhrases = [
        "you could say",
        "here's a suggestion",
        "you might say",
        "try saying"
    ]

    public init() {}

    public func isDirectSpeakable(_ answer: String) -> Bool {
        let lowercased = answer.lowercased()
        return !bannedPhrases.contains { lowercased.contains($0) }
    }
}

public struct FakeWebSearchSynthesizer: Sendable {
    public init() {}

    public func answer(question: String, snippets: [String]) -> AnswerResponse {
        let evidence = snippets.isEmpty ? "No indexed result was provided." : snippets.joined(separator: " ")
        return AnswerResponse(
            text: "Based on search evidence: \(evidence)",
            provider: .openAI,
            model: "fake-web-search",
            citations: snippets.isEmpty ? [] : ["fake-web-search"]
        )
    }
}

public protocol WebSearchService: Sendable {
    func search(question: String) async throws -> [WebSearchResult]
}

public struct DisabledWebSearchService: WebSearchService {
    public init() {}

    public func search(question: String) async throws -> [WebSearchResult] {
        []
    }
}

public struct DeterministicWebSearchService: WebSearchService {
    private let resultsByQuestionKey: [String: [WebSearchResult]]

    public init(resultsByQuestionKey: [String: [WebSearchResult]] = [:]) {
        self.resultsByQuestionKey = resultsByQuestionKey
    }

    public func search(question: String) async throws -> [WebSearchResult] {
        let key = Self.normalizedKey(question)
        if let results = resultsByQuestionKey[key] {
            return results
        }
        if key.contains("rag") || key.contains("retrieval") {
            return [
                WebSearchResult(
                    title: "Retrieval augmented generation",
                    snippet: "RAG grounds generated answers with retrieved context before synthesis."
                )
            ]
        }
        return [
            WebSearchResult(
                title: "Deterministic search result",
                snippet: "Helix can route web evidence into concise active answers."
            )
        ]
    }

    private static func normalizedKey(_ question: String) -> String {
        question
            .lowercased()
            .replacingOccurrences(of: "[^a-z0-9 ]", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
