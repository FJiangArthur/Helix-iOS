import Foundation
import HelixCore

public struct AnthropicAnswerProvider: HelixAnswerProvider {
    public let kind: LlmProviderKind = .anthropic
    public let model: String

    private let apiKey: String
    private let endpoint: URL
    private let transport: any OpenAIDataTransport

    public init(
        apiKey: String,
        model: String,
        endpoint: URL = URL(string: "https://api.anthropic.com/v1")!,
        transport: any OpenAIDataTransport = URLSessionOpenAIDataTransport()
    ) {
        self.apiKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        self.model = model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "claude-haiku-4" : model.trimmingCharacters(in: .whitespacesAndNewlines)
        self.endpoint = endpoint
        self.transport = transport
    }

    public func streamAnswer(for request: AnswerRequest) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let answer = try await completeAnswer(for: request)
                    for word in answer.text.split(separator: " ") {
                        continuation.yield(String(word) + " ")
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    public func makeURLRequest(for request: AnswerRequest) throws -> URLRequest {
        guard !apiKey.isEmpty else {
            throw HelixError.missingApiKey("Anthropic")
        }

        var urlRequest = URLRequest(url: endpoint.appendingPathComponent("messages"))
        urlRequest.httpMethod = "POST"
        urlRequest.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        urlRequest.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONSerialization.data(
            withJSONObject: makeBody(for: request),
            options: [.sortedKeys]
        )
        return urlRequest
    }

    public func completeAnswer(for request: AnswerRequest) async throws -> AnswerResponse {
        let urlRequest = try makeURLRequest(for: request)
        let (data, response) = try await transport.data(for: urlRequest)
        guard (200..<300).contains(response.statusCode) else {
            throw HelixError.providerFailure("Anthropic answer failed with HTTP \(response.statusCode).")
        }

        let payload = try JSONDecoder().decode(AnthropicMessagePayload.self, from: data)
        let text = payload.content
            .filter { $0.type == "text" }
            .compactMap(\.text)
            .joined()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            throw HelixError.providerFailure("Anthropic answer response was empty.")
        }

        return AnswerResponse(
            text: text,
            provider: kind,
            model: payload.model ?? model,
            citations: request.citationSources
        )
    }

    private func makeBody(for request: AnswerRequest) -> [String: Any] {
        [
            "model": model,
            "max_tokens": 1024,
            "temperature": 0.2,
            "system": systemPrompt(for: request),
            "messages": [
                [
                    "role": "user",
                    "content": userPrompt(for: request)
                ]
            ]
        ]
    }

    private func systemPrompt(for request: AnswerRequest) -> String {
        [
            "You are Helix, a real-time assistant for smart glasses.",
            "Answer directly with speakable wording. Do not use meta phrases like 'you could say'.",
            "Keep the answer within \(request.maxResponseSentences) short sentence\(request.maxResponseSentences == 1 ? "" : "s") unless the user asks otherwise.",
            "Active skill: \(request.activeSkill.label). \(request.activeSkill.prompt)"
        ].joined(separator: " ")
    }

    private func userPrompt(for request: AnswerRequest) -> String {
        var sections = ["Question:\n\(request.question)"]
        if !request.sessionMemoryContext.isEmpty {
            sections.append("Recent session memory:\n\(request.sessionMemoryContext.joined(separator: "\n"))")
        }
        if !request.projectContext.isEmpty {
            sections.append("Project context:\n\(request.projectContext.joined(separator: "\n"))")
        }
        if !request.webSearchResults.isEmpty {
            sections.append(
                "Web evidence:\n" + request.webSearchResults.map { result in
                    "- \(result.title): \(result.snippet)"
                }.joined(separator: "\n")
            )
        }
        return sections.joined(separator: "\n\n")
    }

    private struct AnthropicMessagePayload: Decodable {
        struct ContentBlock: Decodable {
            var type: String
            var text: String?
        }

        var model: String?
        var content: [ContentBlock]
    }
}

/// Builds the concrete answer provider for the active settings and API key.
/// Falls back to `DeterministicAnswerProvider` when no key is stored so the
/// pipeline stays functional (and testable) without credentials.
public struct HelixAnswerProviderFactory: Sendable {
    public init() {}

    public func makeProvider(settings: HelixSettings, apiKey: String?) -> any HelixAnswerProvider {
        let trimmedKey = apiKey?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmedKey.isEmpty else {
            return DeterministicAnswerProvider(kind: settings.llmProvider)
        }

        let model = settings.llmModel
        switch settings.llmProvider {
        case .openAI:
            return OpenAIAnswerProvider(apiKey: trimmedKey, model: model)
        case .anthropic:
            return AnthropicAnswerProvider(apiKey: trimmedKey, model: model)
        case .deepSeek:
            return OpenAIAnswerProvider(
                apiKey: trimmedKey,
                model: model,
                kind: .deepSeek,
                endpoint: URL(string: "https://api.deepseek.com/v1")!
            )
        case .qwen:
            return OpenAIAnswerProvider(
                apiKey: trimmedKey,
                model: model,
                kind: .qwen,
                endpoint: URL(string: "https://dashscope.aliyuncs.com/compatible-mode/v1")!
            )
        case .zhipu:
            return OpenAIAnswerProvider(
                apiKey: trimmedKey,
                model: model,
                kind: .zhipu,
                endpoint: URL(string: "https://open.bigmodel.cn/api/paas/v4")!
            )
        }
    }
}
