import XCTest
import HelixAI
import HelixCore
import HelixPersistence

final class ModelCatalogTests: XCTestCase {
    func testFallbackModelsWhenNoKey() async {
        let catalog = ProviderModelCatalog(transport: CapturingTransport(bodyJSON: "{}", statusCode: 401))

        for provider in LlmProviderKind.allCases {
            let models = await catalog.models(for: provider, apiKey: nil)
            XCTAssertEqual(models, ProviderModelCatalog.fallbackModels(for: provider))
        }
    }

    func testFallbackModelsWhenDiscoveryFails() async {
        let catalog = ProviderModelCatalog(transport: CapturingTransport(bodyJSON: "nonsense", statusCode: 500))
        let models = await catalog.models(for: .openAI, apiKey: "sk-test")
        XCTAssertEqual(models, ProviderModelCatalog.fallbackModels(for: .openAI))
    }

    func testLiveOpenAIModelsMergeWithFallbackAndFilter() async {
        let json = """
        {"data": [
            {"id": "gpt-4.1"},
            {"id": "gpt-5-preview"},
            {"id": "text-embedding-3-small"},
            {"id": "o3-mini"}
        ]}
        """
        let catalog = ProviderModelCatalog(transport: CapturingTransport(bodyJSON: json))
        let models = await catalog.models(for: .openAI, apiKey: "sk-test")

        // Curated defaults on top (fallback order), embeddings filtered out.
        XCTAssertEqual(Array(models.prefix(3)), ["gpt-4.1", "gpt-4.1-mini", "gpt-4.1-nano"])
        XCTAssertTrue(models.contains("gpt-5-preview"))
        XCTAssertTrue(models.contains("o3-mini"))
        XCTAssertFalse(models.contains("text-embedding-3-small"))
    }

    func testChatPickerExcludesRealtimeAndTranscriptionModels() async {
        let json = """
        {"data": [
            {"id": "gpt-4.1"},
            {"id": "gpt-realtime"},
            {"id": "gpt-4o-mini-transcribe"}
        ]}
        """
        let catalog = ProviderModelCatalog(transport: CapturingTransport(bodyJSON: json))

        let chat = await catalog.models(for: .openAI, role: .chat, apiKey: "sk-test")
        XCTAssertTrue(chat.contains("gpt-4.1"))
        XCTAssertFalse(chat.contains("gpt-realtime"))
        XCTAssertFalse(chat.contains("gpt-4o-mini-transcribe"))

        let realtime = await catalog.models(for: .openAI, role: .realtime, apiKey: "sk-test")
        XCTAssertTrue(realtime.contains("gpt-realtime"))
        XCTAssertFalse(realtime.contains("gpt-4.1"))

        let transcription = await catalog.models(for: .openAI, role: .transcription, apiKey: "sk-test")
        XCTAssertTrue(transcription.contains("gpt-4o-mini-transcribe"))
        XCTAssertFalse(transcription.contains("gpt-4.1"))
    }

    func testAnthropicUsesXApiKeyHeaderAndEndpoint() async {
        let transport = CapturingTransport(bodyJSON: #"{"data": [{"id": "claude-opus-4"}]}"#)
        let catalog = ProviderModelCatalog(transport: transport)

        let models = await catalog.models(for: .anthropic, apiKey: "sk-ant-test")

        let request = await transport.lastRequest
        XCTAssertEqual(request?.url?.absoluteString, "https://api.anthropic.com/v1/models")
        XCTAssertEqual(request?.value(forHTTPHeaderField: "x-api-key"), "sk-ant-test")
        XCTAssertEqual(request?.value(forHTTPHeaderField: "anthropic-version"), "2023-06-01")
        XCTAssertNil(request?.value(forHTTPHeaderField: "Authorization"))
        XCTAssertTrue(models.contains("claude-opus-4"))
    }

    func testOpenAICompatibleProvidersUseBearerAndOwnEndpoint() async {
        let cases: [(LlmProviderKind, String)] = [
            (.openAI, "https://api.openai.com/v1/models"),
            (.deepSeek, "https://api.deepseek.com/v1/models"),
            (.qwen, "https://dashscope.aliyuncs.com/compatible-mode/v1/models"),
            (.zhipu, "https://open.bigmodel.cn/api/paas/v4/models")
        ]

        for (provider, expectedURL) in cases {
            let transport = CapturingTransport(bodyJSON: #"{"data": []}"#)
            _ = await ProviderModelCatalog(transport: transport).models(for: provider, apiKey: "key")
            let request = await transport.lastRequest
            XCTAssertEqual(request?.url?.absoluteString, expectedURL, "wrong endpoint for \(provider)")
            XCTAssertEqual(request?.value(forHTTPHeaderField: "Authorization"), "Bearer key")
        }
    }

    func testOpenAIFilterKeepsChatgptAndReasoningModelsButDropsNonChat() async {
        let json = """
        {"data": [
            {"id": "chatgpt-4o-latest"},
            {"id": "o3-mini"},
            {"id": "o4-mini"},
            {"id": "omni-moderation-latest"},
            {"id": "gpt-4.1"}
        ]}
        """
        let models = await ProviderModelCatalog(transport: CapturingTransport(bodyJSON: json))
            .models(for: .openAI, apiKey: "sk-test")

        XCTAssertTrue(models.contains("chatgpt-4o-latest"))
        XCTAssertTrue(models.contains("o3-mini"))
        XCTAssertTrue(models.contains("o4-mini"))
        XCTAssertFalse(models.contains("omni-moderation-latest"))
    }

    func testProviderSpecificFiltering() async {
        // Anthropic endpoint returning a stray non-claude id must drop it.
        let json = #"{"data": [{"id": "claude-haiku-4"}, {"id": "gpt-4.1"}]}"#
        let models = await ProviderModelCatalog(transport: CapturingTransport(bodyJSON: json))
            .models(for: .anthropic, apiKey: "k")
        XCTAssertTrue(models.contains("claude-haiku-4"))
        XCTAssertFalse(models.contains("gpt-4.1"))
    }
}

final class ProviderModelUpdateTests: XCTestCase {
    func testUpdatingChatModelsPreservesRealtimeAndTranscription() async {
        let manager = NativeSettingsManager(
            settingsStore: InMemorySettingsStore(),
            secretStore: InMemorySecretStore()
        )

        // OpenAI ships with realtime + transcription models by default.
        let before = await manager.settings()
        let openAIBefore = before.providers.first { $0.kind == .openAI }?.modelSelection
        XCTAssertNotNil(openAIBefore?.realtimeModel)
        XCTAssertNotNil(openAIBefore?.transcriptionModel)

        let after = await manager.updateProviderModels(
            provider: .openAI,
            smartModel: "gpt-4.1",
            lightModel: "gpt-4.1-nano"
        )

        let openAIAfter = after.providers.first { $0.kind == .openAI }?.modelSelection
        XCTAssertEqual(openAIAfter?.smartModel, "gpt-4.1")
        XCTAssertEqual(openAIAfter?.lightModel, "gpt-4.1-nano")
        XCTAssertEqual(openAIAfter?.realtimeModel, openAIBefore?.realtimeModel)
        XCTAssertEqual(openAIAfter?.transcriptionModel, openAIBefore?.transcriptionModel)
    }
}

private actor CapturingTransport: OpenAIDataTransport {
    private let bodyJSON: String
    private let statusCode: Int
    private(set) var lastRequest: URLRequest?

    init(bodyJSON: String, statusCode: Int = 200) {
        self.bodyJSON = bodyJSON
        self.statusCode = statusCode
    }

    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        lastRequest = request
        let response = HTTPURLResponse(
            url: request.url ?? URL(string: "https://unit.test")!,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: nil
        )!
        return (Data(bodyJSON.utf8), response)
    }
}
