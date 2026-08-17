import XCTest
import HelixAI
import HelixConversation
import HelixCore
import HelixPersistence
import HelixRuntime

final class NativeRuntimeWiringTests: XCTestCase {
    func testProviderFactoryFallsBackToDeterministicWithoutKey() {
        let factory = HelixAnswerProviderFactory()

        let missingKey = factory.makeProvider(settings: HelixSettings(), apiKey: nil)
        let blankKey = factory.makeProvider(settings: HelixSettings(), apiKey: "   ")

        XCTAssertTrue(missingKey is DeterministicAnswerProvider)
        XCTAssertTrue(blankKey is DeterministicAnswerProvider)
    }

    func testProviderFactoryBuildsRealProviderPerKind() {
        let factory = HelixAnswerProviderFactory()

        for kind in LlmProviderKind.allCases {
            let settings = HelixSettings(llmProvider: kind, llmModel: "test-model")
            let provider = factory.makeProvider(settings: settings, apiKey: "sk-test")
            XCTAssertEqual(provider.kind, kind)
            XCTAssertEqual(provider.model, "test-model")
            XCTAssertFalse(provider is DeterministicAnswerProvider)
        }
    }

    func testEngineUpdateSettingsChangesActiveSkillAndProvider() async {
        let engine = NativeConversationEngine(
            answerProvider: DeterministicAnswerProvider(),
            conversationStore: InMemoryConversationStore()
        )

        await engine.updateSettings(HelixSettings(activeSkillID: "dsa"))
        let skill = await engine.currentActiveSkill()
        XCTAssertEqual(skill.value, "dsa")

        await engine.setAnswerProvider(OpenAIAnswerProvider(apiKey: "sk-test", model: "gpt-4.1-mini"))
        let description = await engine.currentAnswerProviderDescription()
        XCTAssertEqual(description, "openAI:gpt-4.1-mini")
    }

    @MainActor
    func testProcessLiveTranscriptAnswersQuestionAndKeepsState() async {
        let session = NativeAssistantSessionState(
            engine: NativeConversationEngine(
                answerProvider: DeterministicAnswerProvider(),
                conversationStore: InMemoryConversationStore()
            )
        )

        await session.processLiveTranscript("What is an LLM?")

        XCTAssertEqual(session.transcriptText, "What is an LLM?")
        XCTAssertTrue(session.detectedQuestion.hasPrefix("What is an LLM"))
        XCTAssertFalse(session.currentAnswer.isEmpty)
        XCTAssertFalse(session.hudPages.isEmpty)

        // A follow-up statement without a question must not clear the answer.
        await session.processLiveTranscript("That makes sense to me.")
        XCTAssertFalse(session.currentAnswer.isEmpty)
        XCTAssertEqual(session.transcriptText, "That makes sense to me.")
    }

    @MainActor
    func testRuntimeSyncEnginePushesSettingsIntoPipeline() async {
        let runtime = HelixRuntimeDependencies()
        await runtime.setAutoDetectQuestions(false)

        await runtime.assistantSession.processLiveTranscript("What is an LLM?")
        XCTAssertTrue(runtime.assistantSession.currentAnswer.isEmpty)

        await runtime.setAutoDetectQuestions(true)
        await runtime.assistantSession.processLiveTranscript("What is a transformer?")
        XCTAssertFalse(runtime.assistantSession.currentAnswer.isEmpty)
    }

    @MainActor
    func testRuntimeSetListeningTogglesStateAndLog() {
        let runtime = HelixRuntimeDependencies()

        runtime.assistantSession.setListening(true)
        XCTAssertTrue(runtime.assistantSession.isListening)
        XCTAssertTrue(runtime.assistantSession.eventLog.contains("listeningStarted"))

        runtime.assistantSession.setListening(false)
        XCTAssertFalse(runtime.assistantSession.isListening)
    }

    func testAnthropicProviderBuildsRequestWithHeaders() throws {
        let provider = AnthropicAnswerProvider(apiKey: "sk-ant-test", model: "claude-haiku-4")
        let request = AnswerRequest(
            question: "What is RAG?",
            mode: .general,
            activeSkill: ActiveSkill.skill(for: ActiveSkill.defaultValue),
            sessionMemoryContext: [],
            maxResponseSentences: 3,
            requiredFacts: [],
            projectContext: [],
            webSearchResults: []
        )

        let urlRequest = try provider.makeURLRequest(for: request)

        XCTAssertEqual(urlRequest.url?.lastPathComponent, "messages")
        XCTAssertEqual(urlRequest.value(forHTTPHeaderField: "x-api-key"), "sk-ant-test")
        XCTAssertEqual(urlRequest.value(forHTTPHeaderField: "anthropic-version"), "2023-06-01")
        let body = try XCTUnwrap(urlRequest.httpBody)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(json["model"] as? String, "claude-haiku-4")
    }
}
