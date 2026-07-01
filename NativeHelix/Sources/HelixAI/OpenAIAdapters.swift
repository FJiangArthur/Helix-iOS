import Foundation
import HelixCore

public protocol OpenAIDataTransport: Sendable {
    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

public struct URLSessionOpenAIDataTransport: OpenAIDataTransport {
    public init() {}

    public func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw HelixError.providerFailure("OpenAI returned a non-HTTP response.")
        }
        return (data, httpResponse)
    }
}

public struct OpenAIModelDiscoveryService: Sendable {
    public static let fallbackModels = [
        "gpt-4.1",
        "gpt-4.1-mini",
        "gpt-4.1-nano",
        "gpt-4o-realtime",
        "gpt-4o-mini-realtime",
        "gpt-4o-transcribe",
        "gpt-4o-mini-transcribe"
    ]

    private let apiKey: String?
    private let endpoint: URL
    private let transport: any OpenAIDataTransport

    public init(
        apiKey: String?,
        endpoint: URL = URL(string: "https://api.openai.com/v1")!,
        transport: any OpenAIDataTransport = URLSessionOpenAIDataTransport()
    ) {
        self.apiKey = apiKey?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.endpoint = endpoint
        self.transport = transport
    }

    public func availableModels() async -> [String] {
        guard let apiKey, !apiKey.isEmpty else {
            return Self.fallbackModels
        }

        do {
            let models = try await liveModels(apiKey: apiKey)
            return models.isEmpty ? Self.fallbackModels : models
        } catch {
            return Self.fallbackModels
        }
    }

    private func liveModels(apiKey: String) async throws -> [String] {
        var request = URLRequest(url: endpoint.appendingPathComponent("models"))
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await transport.data(for: request)
        guard (200..<300).contains(response.statusCode) else {
            throw HelixError.providerFailure("OpenAI model discovery failed with HTTP \(response.statusCode).")
        }

        let payload = try JSONDecoder().decode(OpenAIModelsPayload.self, from: data)
        var seen = Set<String>()
        return payload.data
            .map(\.id)
            .filter(Self.isSupportedModelID)
            .filter { seen.insert($0).inserted }
            .sorted()
    }

    private static func isSupportedModelID(_ id: String) -> Bool {
        let lowercased = id.lowercased()
        return lowercased.hasPrefix("gpt-")
            || lowercased.hasPrefix("o")
            || lowercased.contains("realtime")
            || lowercased.contains("transcribe")
    }

    private struct OpenAIModelsPayload: Decodable {
        struct Model: Decodable {
            var id: String
        }

        var data: [Model]
    }
}

public struct OpenAIAnswerProvider: HelixAnswerProvider {
    public let kind: LlmProviderKind = .openAI
    public let model: String

    private let apiKey: String
    private let endpoint: URL
    private let transport: any OpenAIDataTransport

    public init(
        apiKey: String,
        model: String,
        endpoint: URL = URL(string: "https://api.openai.com/v1")!,
        transport: any OpenAIDataTransport = URLSessionOpenAIDataTransport()
    ) {
        self.apiKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        self.model = model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "gpt-4.1-mini" : model.trimmingCharacters(in: .whitespacesAndNewlines)
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
            throw HelixError.missingApiKey("OpenAI")
        }

        var urlRequest = URLRequest(url: endpoint.appendingPathComponent("chat/completions"))
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
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
            _ = data
            throw HelixError.providerFailure("OpenAI answer failed with HTTP \(response.statusCode).")
        }

        let payload = try JSONDecoder().decode(OpenAIChatCompletionPayload.self, from: data)
        let text = payload.choices.first?.message.content.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !text.isEmpty else {
            throw HelixError.providerFailure("OpenAI answer response was empty.")
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
            "temperature": 0.2,
            "messages": [
                [
                    "role": "system",
                    "content": systemPrompt(for: request)
                ],
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

    private struct OpenAIChatCompletionPayload: Decodable {
        struct Choice: Decodable {
            struct Message: Decodable {
                var content: String
            }

            var message: Message
        }

        var model: String?
        var choices: [Choice]
    }
}
