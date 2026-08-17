import Foundation
import HelixCore

/// Discovers the model IDs a provider offers so the UI can present a live,
/// editable list instead of a hard-coded value. Every supported provider
/// exposes an OpenAI-style `GET /models` endpoint (Anthropic included, with a
/// different auth header), so one service covers them all. When there is no
/// key or the network is unavailable, a curated fallback keeps the picker
/// populated.
public struct ProviderModelCatalog: Sendable {
    private let transport: any OpenAIDataTransport

    public init(transport: any OpenAIDataTransport = URLSessionOpenAIDataTransport()) {
        self.transport = transport
    }

    /// The role a model plays. Chat models power answers (Smart/Light);
    /// realtime and transcription models must not appear in the chat pickers
    /// because `/chat/completions` rejects them.
    public enum ModelRole: Sendable {
        case chat
        case realtime
        case transcription
    }

    /// Returns the selectable chat model IDs for `provider`.
    public func models(for provider: LlmProviderKind, apiKey: String?) async -> [String] {
        await models(for: provider, role: .chat, apiKey: apiKey)
    }

    /// Returns the selectable model IDs for `provider` in a given role. Live
    /// IDs (curated defaults first, then any additional live IDs) when a key
    /// is present and the endpoint responds; otherwise the curated fallback.
    public func models(for provider: LlmProviderKind, role: ModelRole, apiKey: String?) async -> [String] {
        let fallback = Self.fallbackModels(for: provider, role: role)
        let trimmed = apiKey?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmed.isEmpty else { return fallback }

        do {
            let live = try await liveModels(for: provider, apiKey: trimmed)
                .filter { Self.role(of: $0, for: provider) == role }
            guard !live.isEmpty else { return fallback }
            // Curated defaults first (in fallback order), then any genuinely
            // new live IDs the endpoint reported.
            var ordered = fallback
            for model in live where !ordered.contains(model) {
                ordered.append(model)
            }
            return ordered
        } catch {
            return fallback
        }
    }

    private func liveModels(for provider: LlmProviderKind, apiKey: String) async throws -> [String] {
        var request = URLRequest(url: Self.endpoint(for: provider).appendingPathComponent("models"))
        request.httpMethod = "GET"
        switch provider {
        case .anthropic:
            request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
            request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        default:
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await transport.data(for: request)
        guard (200..<300).contains(response.statusCode) else {
            throw HelixError.providerFailure("\(provider.rawValue) model discovery failed with HTTP \(response.statusCode).")
        }

        let payload = try JSONDecoder().decode(ModelsPayload.self, from: data)
        var seen = Set<String>()
        return payload.data
            .map(\.id)
            .filter { Self.role(of: $0, for: provider) != nil }
            .filter { seen.insert($0).inserted }
    }

    // MARK: - Endpoints

    static func endpoint(for provider: LlmProviderKind) -> URL {
        switch provider {
        case .openAI: return URL(string: "https://api.openai.com/v1")!
        case .anthropic: return URL(string: "https://api.anthropic.com/v1")!
        case .deepSeek: return URL(string: "https://api.deepseek.com/v1")!
        case .qwen: return URL(string: "https://dashscope.aliyuncs.com/compatible-mode/v1")!
        case .zhipu: return URL(string: "https://open.bigmodel.cn/api/paas/v4")!
        }
    }

    // MARK: - Model classification

    /// Classifies a model ID's role, or nil if it isn't a supported model for
    /// this provider (e.g. embeddings, moderation, image models).
    static func role(of id: String, for provider: LlmProviderKind) -> ModelRole? {
        let lowered = id.lowercased()
        // Role suffixes are provider-independent for the OpenAI family.
        if lowered.contains("transcribe") { return .transcription }
        if lowered.contains("realtime") { return .realtime }

        switch provider {
        case .openAI:
            let isChat = lowered.hasPrefix("gpt-") || lowered.hasPrefix("chatgpt")
                || lowered.hasPrefix("o1") || lowered.hasPrefix("o3") || lowered.hasPrefix("o4")
            return isChat ? .chat : nil
        case .anthropic:
            return lowered.hasPrefix("claude") ? .chat : nil
        case .deepSeek:
            return lowered.hasPrefix("deepseek") ? .chat : nil
        case .qwen:
            return lowered.hasPrefix("qwen") ? .chat : nil
        case .zhipu:
            return lowered.hasPrefix("glm") ? .chat : nil
        }
    }

    // MARK: - Fallbacks (from the CLAUDE.md provider table)

    public static func fallbackModels(for provider: LlmProviderKind) -> [String] {
        fallbackModels(for: provider, role: .chat)
    }

    public static func fallbackModels(for provider: LlmProviderKind, role: ModelRole) -> [String] {
        switch role {
        case .chat:
            switch provider {
            case .openAI: return ["gpt-4.1", "gpt-4.1-mini", "gpt-4.1-nano"]
            case .anthropic: return ["claude-sonnet-4", "claude-haiku-4"]
            case .deepSeek: return ["deepseek-chat", "deepseek-reasoner"]
            case .qwen: return ["qwen-turbo", "qwen-plus", "qwen-max"]
            case .zhipu: return ["glm-4-flash", "glm-4"]
            }
        case .realtime:
            return provider == .openAI ? ["gpt-realtime", "gpt-4o-mini-realtime"] : []
        case .transcription:
            return provider == .openAI ? ["gpt-4o-mini-transcribe", "gpt-4o-transcribe", "whisper-1"] : []
        }
    }

    private struct ModelsPayload: Decodable {
        struct Model: Decodable { var id: String }
        var data: [Model]
    }
}
