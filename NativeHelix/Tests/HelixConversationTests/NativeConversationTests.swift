import XCTest
import HelixAI
import HelixConversation
import HelixCore
import HelixG1
import HelixPersistence
import HelixRuntime
import HelixSpeech
import SwiftData

final class NativeConversationTests: XCTestCase {
    func testQuestionDetectionAndDuplicateSuppression() {
        let detector = QuestionDetector()
        let suppressor = DuplicateQuestionSuppressor()

        let candidates = detector.detectQuestions(in: "What is RAG? What is RAG?")
        let unique = suppressor.uniqueQuestions(candidates)

        XCTAssertEqual(candidates.count, 2)
        XCTAssertEqual(unique.count, 1)
    }

    func testStatementDoesNotTriggerQuestion() {
        let questions = QuestionDetector().detectQuestions(in: "RAG combines retrieval with generation.")
        XCTAssertTrue(questions.isEmpty)
    }

    func testPassiveCorrectionReminderIsFast() {
        let finalizedAt = Date()
        let segment = TranscriptSegment(
            text: "RAG means random answer generation.",
            isFinal: true,
            finalizedAt: finalizedAt
        )

        let reminder = PassiveCorrectionDetector().reminder(
            for: segment,
            finalizedAt: finalizedAt.addingTimeInterval(0.05)
        )

        XCTAssertEqual(reminder?.reminder, "RAG means retrieval augmented generation.")
        XCTAssertLessThan(reminder?.latencyMs ?? 9999, 1000)
    }

    func testPassiveCorrectionProducesHudReminderPages() async throws {
        let engine = NativeConversationEngine(
            answerProvider: DeterministicAnswerProvider(),
            conversationStore: InMemoryConversationStore()
        )
        let segment = TranscriptSegment(
            text: "RAG means random answer generation.",
            isFinal: true,
            finalizedAt: Date()
        )

        let result = try await engine.processFinalSegment(segment, mode: .passive)

        XCTAssertEqual(result.passiveReminder?.reminder, "RAG means retrieval augmented generation.")
        XCTAssertEqual(result.hudPages.first?.text, "RAG means retrieval augmented generation.")
        XCTAssertEqual(result.hudPages.first?.packets.first?[0], G1PacketEncoder.commandByte)
        XCTAssertEqual(result.hudPages.first?.packets.first?[4], G1ScreenStatus.textPage.rawValue)
    }

    func testConversationEngineAnswersOnlyOneDuplicateQuestion() async throws {
        let engine = NativeConversationEngine(
            answerProvider: DeterministicAnswerProvider(),
            conversationStore: InMemoryConversationStore()
        )

        let segment = TranscriptSegment(text: "What is RAG?", isFinal: true, finalizedAt: Date())
        let first = try await engine.processFinalSegment(segment, mode: .general)
        let second = try await engine.processFinalSegment(segment, mode: .general)

        XCTAssertNotNil(first.answer)
        XCTAssertNil(second.answer)
        XCTAssertFalse(first.hudPages.isEmpty)
        XCTAssertTrue(second.hudPages.isEmpty)
    }

    func testActiveAnswerIsDirectAndPrecise() async throws {
        let engine = NativeConversationEngine(
            answerProvider: DeterministicAnswerProvider(),
            conversationStore: InMemoryConversationStore()
        )

        let answer = try await engine.answerActiveQuestion("What is an LLM?")

        XCTAssertTrue(answer.text.lowercased().contains("transformer"))
        XCTAssertTrue(AnswerStyleValidator().isDirectSpeakable(answer.text))
    }

    func testRagAnswerUsesProjectContext() async throws {
        let engine = NativeConversationEngine(
            answerProvider: DeterministicAnswerProvider(),
            conversationStore: InMemoryConversationStore()
        )

        let answer = try await engine.answerActiveQuestion(
            "What does the project say?",
            projectFacts: ["Helix displays answers on Even G1 glasses"]
        )

        XCTAssertTrue(answer.text.contains("Even G1 glasses"))
        XCTAssertEqual(answer.citations, ["project-context"])
    }

    func testActiveAnswerRoutesDeterministicWebSearchThroughConversationEngine() async throws {
        let engine = NativeConversationEngine(
            settings: HelixSettings(webSearchMode: .fakeDeterministic),
            answerProvider: DeterministicAnswerProvider(),
            webSearchService: DeterministicWebSearchService(),
            conversationStore: InMemoryConversationStore()
        )

        let answer = try await engine.answerActiveQuestion("What is RAG?")

        XCTAssertTrue(answer.text.contains("Based on web search evidence"))
        XCTAssertTrue(answer.text.contains("retrieved context"))
        XCTAssertEqual(answer.citations, ["web-search"])
        XCTAssertTrue(AnswerStyleValidator().isDirectSpeakable(answer.text))
    }

    func testRagAndWebSearchAnswerCarriesBothCitationSources() async throws {
        let engine = NativeConversationEngine(
            settings: HelixSettings(webSearchMode: .fakeDeterministic),
            answerProvider: DeterministicAnswerProvider(),
            webSearchService: DeterministicWebSearchService(),
            conversationStore: InMemoryConversationStore()
        )

        let answer = try await engine.answerActiveQuestion(
            "What does Helix preserve for RAG?",
            projectFacts: ["Helix keeps project context citations"]
        )

        XCTAssertTrue(answer.text.contains("project context citations"))
        XCTAssertTrue(answer.text.contains("RAG grounds generated answers"))
        XCTAssertEqual(answer.citations, ["project-context", "web-search"])
    }

    func testActiveSkillPresetsSanitizeAndExposeCustomSkill() {
        let custom = ActiveSkill(
            value: "custom-negotiation",
            label: "Custom Negotiation",
            prompt: "Answer with one concession and one boundary."
        )
        let settings = HelixSettings(activeSkillID: "mock-dsa", customSkills: [custom])

        XCTAssertEqual(settings.activeSkillID, "dsa")
        XCTAssertEqual(settings.activeSkill.label, "Data Structures & Algorithms")
        XCTAssertTrue(settings.selectableActiveSkills.contains { $0.value == "custom-negotiation" })
        XCTAssertEqual(
            ActiveSkill.sanitize("custom-negotiation", customSkills: [custom]),
            "custom-negotiation"
        )
        XCTAssertEqual(ActiveSkill.sanitize("unknown", customSkills: [custom]), "general-chat")
    }

    func testSessionMemoryCapsAndFormatsContext() {
        var memory = SessionMemory(maxEntries: 3)
        memory.appendTranscript("First transcript")
        memory.appendQuestion("What is RAG?", skillValue: "general-chat")
        memory.appendAnswer(
            AnswerResponse(text: "RAG grounds answers.", provider: .openAI, model: "test", citations: ["web-search"]),
            skillValue: "general-chat"
        )
        memory.appendSuppression("No help request.")

        XCTAssertEqual(memory.entries.count, 3)
        XCTAssertFalse(memory.contextLines().contains { $0.contains("First transcript") })
        XCTAssertTrue(memory.contextLines().contains { $0.contains("web-search") })
        XCTAssertEqual(memory.transcriptWindow(), "What is RAG?")
    }

    func testPassiveTriggerClassifierAnswersWaitsAndIgnores() {
        let classifier = PassiveTriggerClassifier()

        let direct = classifier.heuristicDecision(for: "How should I explain RAG?")
        let implicitAsk = classifier.heuristicDecision(for: "I am stuck on dynamic programming transitions")
        let filler = classifier.heuristicDecision(for: "okay")
        let short = classifier.heuristicDecision(for: "maybe later")

        XCTAssertEqual(direct.action, .answer)
        XCTAssertEqual(direct.kind, .directQuestion)
        XCTAssertEqual(implicitAsk.action, .answer)
        XCTAssertEqual(implicitAsk.kind, .implicitAsk)
        XCTAssertEqual(filler.action, .ignore)
        XCTAssertEqual(short.action, .wait)
    }

    func testPassiveTriggerJSONParserAcceptsDirectAndCompletionPayloads() throws {
        let parser = PassiveTriggerJSONParser()
        let direct = try parser.parse(
            Data(#"{"action":"answer","kind":"implicitAsk","confidence":0.82,"reason":"needs help"}"#.utf8)
        )
        let completion = try parser.parse(
            Data(#"{"choices":[{"message":{"content":"{\"action\":\"wait\",\"kind\":\"ambiguous\",\"confidence\":0.55,\"reason\":\"needs more context\"}"}}]}"#.utf8)
        )

        XCTAssertEqual(direct.action, .answer)
        XCTAssertEqual(direct.kind, .implicitAsk)
        XCTAssertEqual(completion.action, .wait)
        XCTAssertEqual(completion.reason, "needs more context")
    }

    func testPassiveModeAnswersDirectQuestionAndRecordsMemory() async throws {
        let engine = NativeConversationEngine(
            answerProvider: DeterministicAnswerProvider(),
            conversationStore: InMemoryConversationStore()
        )

        let result = try await engine.processFinalSegment(
            TranscriptSegment(text: "How should I define RAG?", isFinal: true, finalizedAt: Date()),
            mode: .passive
        )
        let memory = await engine.currentSessionMemory()
        let metrics = await engine.currentLatencyMetrics()

        XCTAssertEqual(result.passiveTrigger?.action, .answer)
        XCTAssertNotNil(result.answer)
        XCTAssertFalse(result.hudPages.isEmpty)
        XCTAssertTrue(memory.contextLines().contains { $0.contains("How should I define RAG") })
        XCTAssertTrue(metrics.contains { $0.area == "passive-answer" })
    }

    func testPassiveModeIgnoresMonologueWithoutCorrection() async throws {
        let engine = NativeConversationEngine(
            answerProvider: DeterministicAnswerProvider(),
            conversationStore: InMemoryConversationStore()
        )

        let result = try await engine.processFinalSegment(
            TranscriptSegment(text: "RAG combines retrieval with generation.", isFinal: true, finalizedAt: Date()),
            mode: .passive
        )

        XCTAssertEqual(result.passiveTrigger?.action, .ignore)
        XCTAssertNil(result.answer)
        XCTAssertNil(result.passiveReminder)
    }

    func testOpenAIModelDiscoveryFiltersModelsAndFallsBackWithoutKey() async {
        let payload = Data(#"{"data":[{"id":"gpt-4.1-mini"},{"id":"tts-1"},{"id":"gpt-4o-mini-transcribe"},{"id":"legacy"}]}"#.utf8)
        let transport = FakeOpenAITransport(data: payload)
        let service = OpenAIModelDiscoveryService(
            apiKey: "sk-test",
            endpoint: URL(string: "https://unit.test/v1")!,
            transport: transport
        )

        let models = await service.availableModels()
        let fallback = await OpenAIModelDiscoveryService(apiKey: nil, transport: transport).availableModels()
        let lastURL = await transport.lastRequest?.url?.absoluteString

        XCTAssertEqual(models, ["gpt-4.1-mini", "gpt-4o-mini-transcribe"])
        XCTAssertTrue(fallback.contains("gpt-4.1-mini"))
        XCTAssertEqual(lastURL, "https://unit.test/v1/models")
    }

    func testOpenAIAnswerProviderBuildsRequestAndParsesAnswer() async throws {
        let payload = Data(#"{"model":"gpt-4.1-mini","choices":[{"message":{"content":"Use retrieval before generation."}}]}"#.utf8)
        let transport = FakeOpenAITransport(data: payload)
        let provider = OpenAIAnswerProvider(
            apiKey: " sk-test ",
            model: "gpt-4.1-mini",
            endpoint: URL(string: "https://unit.test/v1")!,
            transport: transport
        )
        let request = AnswerRequest(
            question: "What is RAG?",
            activeSkill: ActiveSkill.skill(for: "programming"),
            sessionMemoryContext: ["answer: Prior answer"],
            projectContext: ["Helix cites project context"],
            webSearchResults: [
                WebSearchResult(title: "RAG", snippet: "Retrieval augments generation.")
            ]
        )

        let answer = try await provider.completeAnswer(for: request)
        let body = await transport.lastBodyString ?? ""

        XCTAssertEqual(answer.text, "Use retrieval before generation.")
        XCTAssertEqual(answer.citations, ["project-context", "web-search"])
        XCTAssertTrue(body.contains("Programming"))
        XCTAssertTrue(body.contains("Prior answer"))
        XCTAssertTrue(body.contains("Helix cites project context"))
        XCTAssertTrue(body.contains("Retrieval augments generation"))
    }

    func testOpenAIAudioFileTranscriberBuildsMultipartRequestAndParsesTranscript() async throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("helix-audio-\(UUID().uuidString).wav")
        try Data("fake audio".utf8).write(to: fileURL)
        defer {
            try? FileManager.default.removeItem(at: fileURL)
        }
        let transport = FakeOpenAIAudioTransport(data: Data(#"{"text":"What is RAG?"}"#.utf8))
        let transcriber = OpenAIAudioFileTranscriber(
            apiKey: "sk-test",
            endpoint: URL(string: "https://unit.test/v1")!,
            transport: transport
        )

        let segment = try await transcriber.transcribeAudioFile(
            at: fileURL,
            backend: .openAITranscription,
            model: "gpt-4o-mini-transcribe"
        )
        let body = await transport.lastBodyString ?? ""
        let lastURL = await transport.lastRequest?.url?.absoluteString

        XCTAssertEqual(segment.text, "What is RAG?")
        XCTAssertEqual(lastURL, "https://unit.test/v1/audio/transcriptions")
        XCTAssertTrue(body.contains("gpt-4o-mini-transcribe"))
        XCTAssertTrue(body.contains("fake audio"))
    }

    func testActiveQuestionUsesNativeKnowledgeStoreAndProducesHudPages() async throws {
        let knowledgeStore = InMemoryProjectKnowledgeStore()
        await knowledgeStore.seed(
            projectID: "native-rewrite",
            facts: ["Helix native rewrite keeps Even G1 HUD parity"]
        )
        let engine = NativeConversationEngine(
            answerProvider: DeterministicAnswerProvider(),
            conversationStore: InMemoryConversationStore(),
            knowledgeStore: knowledgeStore
        )

        let turn = try await engine.answerActiveQuestionTurn(
            "What does the native rewrite preserve?",
            projectID: "native-rewrite"
        )

        XCTAssertTrue(turn.answer.text.contains("Even G1 HUD parity"))
        XCTAssertEqual(turn.answer.citations, ["project-context"])
        XCTAssertFalse(turn.hudPages.isEmpty)
        XCTAssertEqual(turn.hudPages.first?.pageNumber, 1)
        XCTAssertEqual(turn.hudPages.first?.packets.first?[0], G1PacketEncoder.commandByte)
    }

    func testAudioFilePipelineEmitsTranscriptQuestionStreamingAnswerAndHudEvents() async throws {
        let transcriber = DeterministicAudioFileTranscriber(
            transcriptsByStem: ["llm-question": "What is an LLM?"]
        )
        let engine = NativeConversationEngine(
            audioFileTranscriber: transcriber,
            answerProvider: DeterministicAnswerProvider(),
            conversationStore: InMemoryConversationStore()
        )

        let events = try await collectEvents(
            from: engine.processAudioFile(
                at: URL(fileURLWithPath: "/tmp/llm-question.wav"),
                mode: .general
            )
        )

        XCTAssertTrue(events.contains { event in
            if case .transcriptFinal(let segment) = event {
                return segment.text == "What is an LLM?"
            }
            return false
        })
        XCTAssertTrue(events.contains { event in
            if case .questionDetected(let question) = event {
                return question.text == "What is an LLM"
            }
            return false
        })
        XCTAssertTrue(events.contains { event in
            if case .answerChunk(let chunk) = event {
                return chunk.lowercased().contains("transformer")
            }
            return false
        })
        XCTAssertTrue(events.contains { event in
            if case .answerCompleted(let answer) = event {
                return answer.text.lowercased().contains("transformer")
            }
            return false
        })
        XCTAssertTrue(events.contains { event in
            if case .hudPagesUpdated(let pages) = event {
                return pages.first?.packets.first?[0] == G1PacketEncoder.commandByte
            }
            return false
        })
    }

    func testAudioFilePipelineUsesKnowledgeStoreForRagAnswerEvents() async throws {
        let knowledgeStore = InMemoryProjectKnowledgeStore()
        await knowledgeStore.seed(
            projectID: "native-rewrite",
            facts: ["Native Helix keeps project context citations"]
        )
        let engine = NativeConversationEngine(
            audioFileTranscriber: DeterministicAudioFileTranscriber(
                transcriptsByStem: ["project-question": "What does the project preserve?"]
            ),
            answerProvider: DeterministicAnswerProvider(),
            conversationStore: InMemoryConversationStore(),
            knowledgeStore: knowledgeStore
        )

        let events = try await collectEvents(
            from: engine.processAudioFile(
                at: URL(fileURLWithPath: "/tmp/project-question.wav"),
                mode: .general,
                projectID: "native-rewrite"
            )
        )

        XCTAssertTrue(events.contains { event in
            if case .answerCompleted(let answer) = event {
                return answer.text.contains("project context citations") && answer.citations == ["project-context"]
            }
            return false
        })
    }

    func testAudioFilePipelineRoutesFakeWebSearchIntoAnswerEvents() async throws {
        let engine = NativeConversationEngine(
            settings: HelixSettings(webSearchMode: .fakeDeterministic),
            audioFileTranscriber: DeterministicAudioFileTranscriber(
                transcriptsByStem: ["rag-question": "What is RAG?"]
            ),
            answerProvider: DeterministicAnswerProvider(),
            webSearchService: DeterministicWebSearchService(),
            conversationStore: InMemoryConversationStore()
        )

        let events = try await collectEvents(
            from: engine.processAudioFile(
                at: URL(fileURLWithPath: "/tmp/rag-question.wav"),
                mode: .general
            )
        )

        XCTAssertTrue(events.contains { event in
            if case .answerCompleted(let answer) = event {
                return answer.text.contains("retrieved context") && answer.citations == ["web-search"]
            }
            return false
        })
        XCTAssertTrue(events.contains { event in
            if case .hudPagesUpdated(let pages) = event {
                return pages.first?.text.contains("retrieved context") == true
            }
            return false
        })
    }

    func testAudioFilePipelineEmitsPassiveReminderWithoutAnswerEvents() async throws {
        let engine = NativeConversationEngine(
            audioFileTranscriber: DeterministicAudioFileTranscriber(
                transcriptsByStem: ["false-claim": "RAG means random answer generation."]
            ),
            answerProvider: DeterministicAnswerProvider(),
            conversationStore: InMemoryConversationStore()
        )

        let events = try await collectEvents(
            from: engine.processAudioFile(
                at: URL(fileURLWithPath: "/tmp/false-claim.wav"),
                mode: .passive
            )
        )

        XCTAssertTrue(events.contains { event in
            if case .passiveReminder(let reminder) = event {
                return reminder.reminder == "RAG means retrieval augmented generation."
            }
            return false
        })
        XCTAssertFalse(events.contains { event in
            if case .answerCompleted = event { return true }
            return false
        })
    }

    func testAudioFilePipelineSuppressesStatementsAndDuplicateQuestions() async throws {
        let engine = NativeConversationEngine(
            audioFileTranscriber: DeterministicAudioFileTranscriber(
                transcriptsByStem: ["statement": "RAG combines retrieval with generation."]
            ),
            answerProvider: DeterministicAnswerProvider(),
            conversationStore: InMemoryConversationStore()
        )

        let statementEvents = try await collectEvents(
            from: engine.processAudioFile(
                at: URL(fileURLWithPath: "/tmp/statement.wav"),
                mode: .general
            )
        )
        XCTAssertTrue(statementEvents.contains(.suppressed("No question detected.")))

        let duplicateTranscriber = DeterministicAudioFileTranscriber(
            transcriptsByStem: ["duplicate": "What is RAG?"]
        )
        let duplicateEngine = NativeConversationEngine(
            audioFileTranscriber: duplicateTranscriber,
            answerProvider: DeterministicAnswerProvider(),
            conversationStore: InMemoryConversationStore()
        )
        _ = try await collectEvents(
            from: duplicateEngine.processAudioFile(
                at: URL(fileURLWithPath: "/tmp/duplicate.wav"),
                mode: .general
            )
        )
        let duplicateEvents = try await collectEvents(
            from: duplicateEngine.processAudioFile(
                at: URL(fileURLWithPath: "/tmp/duplicate.wav"),
                mode: .general
            )
        )
        XCTAssertTrue(duplicateEvents.contains(.suppressed("Duplicate question suppressed.")))
    }

    func testG1PacketEncoderUsesExpectedHeaderAndPacketSize() {
        let packets = G1PacketEncoder().encodeTextPage(String(repeating: "a", count: 400))

        XCTAssertGreaterThan(packets.count, 1)
        XCTAssertEqual(packets[0][0], G1PacketEncoder.commandByte)
        XCTAssertEqual(packets[0][4], G1ScreenStatus.textPage.rawValue)
        XCTAssertTrue(packets.allSatisfy { $0.count <= G1PacketEncoder.maxPacketLength })
    }

    func testG1HudPresenterPaginatesAndPacketizesAnswerText() {
        let pages = G1HudPresenter(
            paginator: HudPaginator(maxCharactersPerPage: 24),
            encoder: G1PacketEncoder()
        ).textPages(for: "Helix streams concise answer pages to the Even G1 display.")

        XCTAssertGreaterThan(pages.count, 1)
        XCTAssertEqual(pages.first?.pageNumber, 1)
        XCTAssertEqual(pages.last?.pageCount, pages.count)
        XCTAssertTrue(pages.allSatisfy { $0.packets.allSatisfy { $0.count <= G1PacketEncoder.maxPacketLength } })
        XCTAssertEqual(pages.first?.packets.first?[4], G1ScreenStatus.textPage.rawValue)
    }

    @MainActor
    func testNativeG1DeviceStateTracksDualConnectionAndHudPackets() {
        let device = NativeG1DeviceState(
            hudPresenter: G1HudPresenter(
                paginator: HudPaginator(maxCharactersPerPage: 24),
                encoder: G1PacketEncoder()
            )
        )

        device.setConnection(left: true, right: false)
        XCTAssertEqual(device.connectionSummary, "Left only")
        device.setConnection(left: true, right: true)
        XCTAssertEqual(device.connectionSummary, "Dual connected")

        device.presentText("Helix streams concise answer pages to the Even G1 display.")

        XCTAssertTrue(device.hasActiveAnswer)
        XCTAssertGreaterThan(device.hudPages.count, 1)
        XCTAssertEqual(device.currentPageSummary, "1 of \(device.hudPages.count)")
        XCTAssertEqual(device.lastPacketHeader.first, G1PacketEncoder.commandByte)
        XCTAssertEqual(device.lastPacketHeader[4], G1ScreenStatus.textPage.rawValue)
        XCTAssertEqual(device.sentPacketCount, device.hudPages.flatMap(\.packets).count)
    }

    @MainActor
    func testNativeG1DeviceStateRoutesTouchpadForPageNavigationAndManualAsk() {
        let device = NativeG1DeviceState(
            hudPresenter: G1HudPresenter(
                paginator: HudPaginator(maxCharactersPerPage: 18),
                encoder: G1PacketEncoder()
            )
        )

        let manualAsk = device.handleTouchpad(notifyIndex: 1, side: .right)
        XCTAssertEqual(manualAsk, .evenAIStart)
        XCTAssertEqual(device.lastTouchpadSummary, "EvenAI start")

        device.presentText("One two three four five six seven eight nine ten eleven twelve.")
        let next = device.handleTouchpad(notifyIndex: 1, side: .right)
        XCTAssertEqual(next, .nextPage)
        XCTAssertEqual(device.currentPageSummary, "2 of \(device.hudPages.count)")

        let previous = device.handleTouchpad(notifyIndex: 1, side: .left)
        XCTAssertEqual(previous, .previousPage)
        XCTAssertEqual(device.currentPageSummary, "1 of \(device.hudPages.count)")

        let exit = device.handleTouchpad(notifyIndex: 0, side: .left)
        XCTAssertEqual(exit, .exit)
        XCTAssertFalse(device.hasActiveAnswer)
        XCTAssertTrue(device.hudPages.isEmpty)
    }

    func testEvalRunnerProducesPassingReport() async {
        let report = await NativeConversationEvalRunner().run(gitSha: "test", simulatorUdid: "local")

        XCTAssertEqual(report.overall, .pass)
        XCTAssertTrue(report.checks.contains { $0.id == "P01" && $0.status == .pass })
        XCTAssertTrue(report.checks.contains { $0.id == "R01" && $0.status == .pass })
    }

    func testEvalReportWriterCreatesJsonAndMarkdownArtifacts() async throws {
        let outputDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("helix-native-eval-\(UUID().uuidString)")
        defer {
            try? FileManager.default.removeItem(at: outputDirectory)
        }

        let artifact = try await HelixNativeEvalGateHarness().runAndWriteReport(
            outputDirectory: outputDirectory,
            gitSha: "test-sha",
            simulatorUdid: "test-simulator"
        )
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(
            EvalReport.self,
            from: Data(contentsOf: artifact.jsonURL)
        )
        let markdown = try String(contentsOf: artifact.markdownURL, encoding: .utf8)

        XCTAssertEqual(artifact.jsonURL.lastPathComponent, "helix_eval_report.json")
        XCTAssertEqual(artifact.markdownURL.lastPathComponent, "helix_eval_report.md")
        XCTAssertEqual(decoded.overall, .pass)
        XCTAssertEqual(decoded.gitSha, "test-sha")
        XCTAssertEqual(decoded.simulatorUdid, "test-simulator")
        XCTAssertTrue(markdown.contains("# Helix Conversation Eval Report"))
        XCTAssertTrue(markdown.contains("| T01 | transcription | PASS |"))
        XCTAssertTrue(markdown.contains("| W01 | web-search | PASS |"))
    }

    func testRuntimeFeatureCatalogIsHeadlessAndCoversProductAreas() {
        let catalog = HelixRuntimeFeatureCatalog()

        XCTAssertEqual(HelixRuntimeFeature.allCases.count, 17)
        XCTAssertTrue(catalog.identifiers.contains("assistant-session"))
        XCTAssertTrue(catalog.identifiers.contains("g1-device"))
        XCTAssertTrue(catalog.identifiers.contains("knowledge-library"))
        XCTAssertTrue(catalog.identifiers.contains("skill-presets"))
        XCTAssertTrue(catalog.identifiers.contains("session-memory"))
        XCTAssertTrue(catalog.identifiers.contains("model-discovery"))
        XCTAssertFalse(catalog.identifiers.contains { $0.contains("nav-") })
    }

    @MainActor
    func testHelixRuntimeBootstrapsPersistentDependenciesForHeadlessFramework() async {
        let suiteName = "helix.native.runtime.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let dependencies = try! HelixRuntimeDependencies.nativePersistent(
            isStoredInMemoryOnly: true,
            userDefaults: defaults,
            settingsKey: "settings.\(UUID().uuidString)",
            keychainService: "com.artjiang.helix.native.runtime.tests.\(UUID().uuidString)"
        )

        await dependencies.refreshSettings()
        await dependencies.knowledgeLibrary.createProject(
            name: "Native Runtime Target",
            summary: "Headless dependency bootstrap",
            activate: true
        )
        await dependencies.knowledgeLibrary.addFact(
            "Native Helix runtime target owns dependency bootstrap.",
            source: "RuntimeTarget"
        )
        let activeProjectID = dependencies.knowledgeLibrary.snapshot.activeProject?.id.uuidString
        await dependencies.assistantSession.ask(
            "What owns dependency bootstrap?",
            projectID: activeProjectID
        )

        XCTAssertEqual(dependencies.activeProviderName, "OpenAI")
        XCTAssertEqual(dependencies.knowledgeLibrary.activeProjectName, "Native Runtime Target")
        XCTAssertTrue(dependencies.assistantSession.currentAnswer.contains("dependency bootstrap"))
        XCTAssertEqual(dependencies.assistantSession.hudSummary, "1 page")
    }

    func testNativeSettingsDefaultProviderMatrixCoversConfiguredLLMs() {
        let settings = HelixSettings()

        XCTAssertEqual(settings.providers.map(\.kind), [.openAI, .anthropic, .deepSeek, .qwen, .zhipu])
        XCTAssertEqual(settings.activeProviderConfiguration?.modelSelection.smartModel, "gpt-4.1")
        XCTAssertEqual(settings.activeProviderConfiguration?.modelSelection.lightModel, "gpt-4.1-mini")
        XCTAssertEqual(settings.activeProviderConfiguration?.modelSelection.transcriptionModel, "gpt-4o-mini-transcribe")
        XCTAssertEqual(settings.hudRenderPath, .bitmap)
        XCTAssertEqual(settings.webSearchMode, .disabled)
        XCTAssertTrue(settings.liveFactCheckEnabled)
        XCTAssertFalse(settings.evalGateEnabled)
    }

    func testNativeSettingsClampMaxResponseSentences() {
        XCTAssertEqual(HelixSettings(maxResponseSentences: -3).maxResponseSentences, 1)
        XCTAssertEqual(HelixSettings(maxResponseSentences: 99).maxResponseSentences, 10)
    }

    func testNativeSettingsManagerStoresProviderSecretsSeparately() async {
        let manager = NativeSettingsManager(
            settingsStore: InMemorySettingsStore(),
            secretStore: InMemorySecretStore()
        )

        await manager.setProviderApiKey(" sk-openai-test ", for: .openAI)
        await manager.setProviderApiKey("sk-anthropic-test", for: .anthropic)

        let openAIKey = await manager.apiKey(for: .openAI)
        let anthropicKey = await manager.apiKey(for: .anthropic)

        XCTAssertEqual(openAIKey, "sk-openai-test")
        XCTAssertEqual(anthropicKey, "sk-anthropic-test")

        let readiness = await manager.providerReadiness()
        XCTAssertTrue(readiness.first { $0.provider == .openAI }?.hasApiKey == true)
        XCTAssertTrue(readiness.first { $0.provider == .anthropic }?.hasApiKey == true)
        XCTAssertTrue(readiness.first { $0.provider == .deepSeek }?.hasApiKey == false)
    }

    func testNativeSettingsManagerSelectProviderUpdatesActiveModels() async {
        let manager = NativeSettingsManager(
            settingsStore: InMemorySettingsStore(),
            secretStore: InMemorySecretStore()
        )

        let updated = await manager.selectProvider(.anthropic)

        XCTAssertEqual(updated.llmProvider, .anthropic)
        XCTAssertEqual(updated.llmModel, "claude-sonnet-4")
        XCTAssertEqual(updated.transcriptionModel, "gpt-4o-mini-transcribe")
    }

    func testNativeSettingsManagerModelOverrideFollowsActiveProvider() async {
        let manager = NativeSettingsManager(
            settingsStore: InMemorySettingsStore(),
            secretStore: InMemorySecretStore()
        )

        _ = await manager.selectProvider(.openAI)
        let updated = await manager.updateProviderModels(
            provider: .openAI,
            smartModel: "gpt-4.1-custom",
            lightModel: "gpt-4.1-nano-custom",
            realtimeModel: "gpt-4o-realtime",
            transcriptionModel: "gpt-4o-transcribe"
        )

        XCTAssertEqual(updated.llmModel, "gpt-4.1-custom")
        XCTAssertEqual(updated.transcriptionModel, "gpt-4o-transcribe")
        XCTAssertEqual(updated.activeProviderConfiguration?.modelSelection.lightModel, "gpt-4.1-nano-custom")
    }

    func testNativeSettingsManagerConversationAndTranscriptionControls() async {
        let manager = NativeSettingsManager(
            settingsStore: InMemorySettingsStore(),
            secretStore: InMemorySecretStore()
        )

        var updated = await manager.updateConversationControls(
            maxResponseSentences: 7,
            autoDetectQuestions: false,
            autoAnswer: false,
            liveFactCheckEnabled: false
        )
        updated = await manager.updateTranscription(
            backend: .appleOnDevice,
            model: "custom-local-speech"
        )
        updated = await manager.upsertCustomSkill(
            ActiveSkill(value: "custom-system", label: "Custom System", prompt: "Answer with tradeoffs.")
        )
        updated = await manager.updateActiveSkill("custom-system")

        XCTAssertEqual(updated.maxResponseSentences, 7)
        XCTAssertFalse(updated.autoDetectQuestions)
        XCTAssertFalse(updated.autoAnswer)
        XCTAssertFalse(updated.liveFactCheckEnabled)
        XCTAssertEqual(updated.transcriptionBackend, .appleOnDevice)
        XCTAssertEqual(updated.transcriptionModel, "custom-local-speech")
        XCTAssertEqual(updated.activeSkillID, "custom-system")
        XCTAssertEqual(updated.activeSkill.prompt, "Answer with tradeoffs.")
    }

    func testUserDefaultsSettingsStorePersistsNativeSettingsAcrossInstances() async {
        let suiteName = "helix.native.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }
        let key = "settings.\(UUID().uuidString)"
        let firstStore = UserDefaultsSettingsStore(userDefaults: defaults, settingsKey: key)
        let manager = NativeSettingsManager(
            settingsStore: firstStore,
            secretStore: InMemorySecretStore()
        )

        _ = await manager.selectProvider(.anthropic)
        _ = await manager.updateConversationControls(
            maxResponseSentences: 8,
            autoDetectQuestions: false,
            autoAnswer: false,
            liveFactCheckEnabled: false
        )
        _ = await manager.updateTranscription(
            backend: .appleCloud,
            model: "native-apple-cloud"
        )
        _ = await manager.updateHudRenderPath(.text)
        _ = await manager.updateWebSearchMode(.fakeDeterministic)
        _ = await manager.setEvalGateEnabled(true)
        _ = await manager.upsertCustomSkill(
            ActiveSkill(value: "custom-light", label: "Custom Light", prompt: "Keep answers sparse.")
        )
        _ = await manager.updateActiveSkill("custom-light")

        let secondStore = UserDefaultsSettingsStore(userDefaults: defaults, settingsKey: key)
        let reloaded = await secondStore.loadSettings()

        XCTAssertEqual(reloaded.llmProvider, .anthropic)
        XCTAssertEqual(reloaded.llmModel, "claude-sonnet-4")
        XCTAssertEqual(reloaded.maxResponseSentences, 8)
        XCTAssertFalse(reloaded.autoDetectQuestions)
        XCTAssertFalse(reloaded.autoAnswer)
        XCTAssertFalse(reloaded.liveFactCheckEnabled)
        XCTAssertEqual(reloaded.transcriptionBackend, .appleCloud)
        XCTAssertEqual(reloaded.transcriptionModel, "native-apple-cloud")
        XCTAssertEqual(reloaded.hudRenderPath, .text)
        XCTAssertEqual(reloaded.webSearchMode, .fakeDeterministic)
        XCTAssertTrue(reloaded.evalGateEnabled)
        XCTAssertEqual(reloaded.activeSkillID, "custom-light")
        XCTAssertEqual(reloaded.activeSkill.label, "Custom Light")
    }

    func testKeychainSecretStoreRoundTripsProviderSecretWhenAvailable() async throws {
        let store = KeychainSecretStore(service: "com.artjiang.helix.native.tests.\(UUID().uuidString)")
        let secretName = "openai_api_key_\(UUID().uuidString)"

        await store.setSecret(" sk-native-keychain-test ", named: secretName)
        guard let saved = await store.secret(named: secretName) else {
            throw XCTSkip("Command-line Keychain access is unavailable in this environment.")
        }

        XCTAssertEqual(saved, "sk-native-keychain-test")
        let hasSavedSecret = await store.hasSecret(named: secretName)
        XCTAssertTrue(hasSavedSecret)

        await store.clearSecret(named: secretName)
        let clearedSecret = await store.secret(named: secretName)
        let hasClearedSecret = await store.hasSecret(named: secretName)
        XCTAssertNil(clearedSecret)
        XCTAssertFalse(hasClearedSecret)
    }

    @MainActor
    func testNativeKnowledgeLibraryStoreTracksProjectsItemsAndTodoCompletion() async throws {
        let store = InMemoryKnowledgeLibraryStore()
        let state = NativeKnowledgeLibraryState(store: store)

        await state.createProject(name: " Helix Native ", summary: " Headless rewrite ", activate: true)
        await state.addFact(" Helix displays answers on Even G1 glasses. ", source: " Plan ")
        await state.ingestDocument(
            title: " Native RAG Notes ",
            text: "Document chunks describe project context retrieval. Imported notes should become answer context.",
            sourceURL: nil
        )
        await state.addMemory(" Direct answers only. ", source: " Preference ")
        await state.addTodo(" Validate native HUD ")

        XCTAssertEqual(state.activeProjectName, "Helix Native")
        XCTAssertEqual(state.snapshot.projects.first?.summary, "Headless rewrite")
        XCTAssertEqual(state.snapshot.projects.first?.factCount, 1)
        XCTAssertEqual(state.snapshot.projects.first?.documentCount, 1)
        XCTAssertEqual(state.snapshot.documents.first?.title, "Native RAG Notes")
        XCTAssertEqual(state.snapshot.documents.first?.chunkCount, 1)
        XCTAssertTrue(state.snapshot.documents.first?.preview.contains("project context retrieval") == true)
        XCTAssertEqual(state.snapshot.facts.first?.text, "Helix displays answers on Even G1 glasses.")
        XCTAssertEqual(state.snapshot.facts.first?.source, "Plan")
        XCTAssertEqual(state.snapshot.memories.first?.text, "Direct answers only.")
        XCTAssertEqual(state.reviewSummary, "1 open todo")

        let todoID = try XCTUnwrap(state.snapshot.todos.first?.id)
        await state.completeTodo(id: todoID, isComplete: true)

        XCTAssertEqual(state.snapshot.openTodoCount, 0)
        XCTAssertEqual(state.reviewSummary, "No pending items")
        XCTAssertTrue(state.snapshot.todos.first?.isComplete == true)
    }

    func testSwiftDataKnowledgeLibraryStorePersistsProjectsFactsMemoriesTodos() async throws {
        let container = try HelixSwiftDataSchema.makeModelContainer(isStoredInMemoryOnly: true)
        let firstStore = SwiftDataKnowledgeLibraryStore(container: container)
        let firstState = await NativeKnowledgeLibraryState(store: firstStore)

        await firstState.createProject(name: " Helix Native ", summary: " SwiftData store ", activate: true)
        await firstState.addFact(" Answers render on Even G1. ", source: " Plan ")
        await firstState.ingestDocument(
            title: " Native Architecture Notes ",
            text: "SwiftData document chunks preserve native project context for RAG answers.",
            sourceURL: URL(string: "https://example.com/native-notes")
        )
        await firstState.addMemory(" Avoid meta phrasing. ", source: " Preference ")
        await firstState.addTodo(" Verify native eval gate ")

        let activeProjectName = await firstState.activeProjectName
        let firstFactCount = await firstState.snapshot.projects.first?.factCount
        XCTAssertEqual(activeProjectName, "Helix Native")
        XCTAssertEqual(firstFactCount, 1)

        let secondStore = SwiftDataKnowledgeLibraryStore(container: container)
        var snapshot = await secondStore.snapshot()

        XCTAssertEqual(snapshot.activeProject?.name, "Helix Native")
        XCTAssertEqual(snapshot.activeProject?.summary, "SwiftData store")
        XCTAssertEqual(snapshot.activeProject?.factCount, 1)
        XCTAssertEqual(snapshot.activeProject?.documentCount, 1)
        XCTAssertEqual(snapshot.documents.first?.title, "Native Architecture Notes")
        XCTAssertEqual(snapshot.documents.first?.sourceURL, URL(string: "https://example.com/native-notes"))
        XCTAssertTrue(snapshot.documents.first?.preview.contains("SwiftData document chunks") == true)
        XCTAssertEqual(snapshot.facts.first?.text, "Answers render on Even G1.")
        XCTAssertEqual(snapshot.facts.first?.source, "Plan")
        XCTAssertEqual(snapshot.memories.first?.text, "Avoid meta phrasing.")
        XCTAssertEqual(snapshot.memories.first?.source, "Preference")
        XCTAssertEqual(snapshot.todos.first?.text, "Verify native eval gate")
        XCTAssertFalse(snapshot.todos.first?.isComplete ?? true)

        let todoID = try XCTUnwrap(snapshot.todos.first?.id)
        await secondStore.completeTodo(id: todoID, isComplete: true)
        snapshot = await secondStore.snapshot()

        XCTAssertEqual(snapshot.openTodoCount, 0)
        XCTAssertTrue(snapshot.todos.first?.isComplete == true)
    }

    @MainActor
    func testSwiftDataKnowledgeLibraryStoreFeedsProjectKnowledgeForRag() async throws {
        let container = try HelixSwiftDataSchema.makeModelContainer(isStoredInMemoryOnly: true)
        let store = SwiftDataKnowledgeLibraryStore(container: container)
        let state = NativeKnowledgeLibraryState(store: store)

        await state.createProject(name: " Helix Native ", summary: " Shared RAG store ", activate: true)
        await state.addFact(" Helix native RAG answers cite Even G1 HUD parity. ", source: " Plan ")
        await state.ingestDocument(
            title: "Document RAG",
            text: "Imported documents say native RAG retrieves project chunks for precise active answers."
        )
        let projectID = try XCTUnwrap(state.snapshot.activeProject?.id.uuidString)

        let factsByID = await store.facts(for: projectID, question: "What retrieves project chunks?")
        let factsByName = await store.facts(for: "Helix Native", question: "What retrieves project chunks?")

        XCTAssertTrue(factsByID.first?.contains("retrieves project chunks") == true)
        XCTAssertEqual(factsByName, factsByID)
    }

    @MainActor
    func testDocumentBackedRagAnswerUsesImportedNativeChunks() async throws {
        let store = InMemoryKnowledgeLibraryStore()
        let state = NativeKnowledgeLibraryState(store: store)
        await state.createProject(name: "Native Docs", summary: "Document-backed RAG", activate: true)
        await state.ingestDocument(
            title: "G1 HUD Contract",
            text: "Imported project notes say Helix native answers must preserve Even G1 HUD pagination and touchpad page navigation."
        )
        let projectID = try XCTUnwrap(state.snapshot.activeProject?.id.uuidString)
        let engine = NativeConversationEngine(
            answerProvider: DeterministicAnswerProvider(),
            conversationStore: InMemoryConversationStore(),
            knowledgeStore: store
        )

        let answer = try await engine.answerActiveQuestion(
            "What must native answers preserve?",
            projectID: projectID
        )

        XCTAssertTrue(answer.text.contains("Even G1 HUD pagination"))
        XCTAssertEqual(answer.citations, ["project-context"])
    }

    @MainActor
    func testNativeSessionArchiveStateSummarizesSessionsForSessionsTab() async {
        let store = InMemorySessionArchiveStore()
        let state = NativeSessionArchiveState(store: store)

        await state.archiveSession(
            NativeSessionSummary(
                title: "First",
                mode: .general,
                startedAt: Date(timeIntervalSince1970: 1),
                projectName: "Helix Native",
                totalCostMicros: 1_500,
                segmentCount: 1,
                answerCount: 1
            )
        )
        await state.archiveSession(
            NativeSessionSummary(
                title: "Second",
                mode: .interview,
                startedAt: Date(timeIntervalSince1970: 2),
                projectName: "Helix Native",
                totalCostMicros: 2_500,
                segmentCount: 2,
                answerCount: 1
            )
        )

        XCTAssertEqual(state.archiveSummary, "2 sessions")
        XCTAssertEqual(state.totalCostSummary, "$0.0040")
        XCTAssertEqual(state.activeProjectSummary, "1 active")
        XCTAssertEqual(state.sessions.map(\.title), ["Second", "First"])
    }

    func testSwiftDataSessionArchiveStorePersistsSessionSummaries() async throws {
        let container = try HelixSwiftDataSchema.makeModelContainer(isStoredInMemoryOnly: true)
        let startedAt = Date(timeIntervalSince1970: 1_750_000_000)
        let session = NativeSessionSummary(
            title: "Native RAG Q&A",
            mode: .interview,
            startedAt: startedAt,
            endedAt: startedAt.addingTimeInterval(120),
            transcriptPreview: "What does Helix preserve?",
            answerPreview: "Helix preserves Even G1 HUD parity.",
            projectName: "Helix Native",
            totalCostMicros: 9_200,
            segmentCount: 2,
            answerCount: 1
        )

        let firstStore = SwiftDataSessionArchiveStore(container: container)
        await firstStore.saveSession(session)

        let secondStore = SwiftDataSessionArchiveStore(container: container)
        let sessions = await secondStore.sessions()
        let saved = try XCTUnwrap(sessions.first)

        XCTAssertEqual(sessions.count, 1)
        XCTAssertEqual(saved.id, session.id)
        XCTAssertEqual(saved.title, "Native RAG Q&A")
        XCTAssertEqual(saved.mode, .interview)
        XCTAssertEqual(saved.startedAt, startedAt)
        XCTAssertEqual(saved.endedAt, startedAt.addingTimeInterval(120))
        XCTAssertEqual(saved.transcriptPreview, "What does Helix preserve?")
        XCTAssertEqual(saved.answerPreview, "Helix preserves Even G1 HUD parity.")
        XCTAssertEqual(saved.projectName, "Helix Native")
        XCTAssertEqual(saved.totalCostMicros, 9_200)
        XCTAssertEqual(saved.segmentCount, 2)
        XCTAssertEqual(saved.answerCount, 1)
    }

    @MainActor
    func testHelixRuntimeDependenciesRefreshProviderStatusRowsFromSettingsManager() async {
        let manager = NativeSettingsManager(
            settingsStore: InMemorySettingsStore(),
            secretStore: InMemorySecretStore()
        )
        await manager.setProviderApiKey("sk-test-openai", for: .openAI)
        let dependencies = HelixRuntimeDependencies(settingsManager: manager)

        await dependencies.refreshSettings()

        XCTAssertEqual(dependencies.activeProviderName, "OpenAI")
        XCTAssertEqual(dependencies.activeProviderReadiness?.hasApiKey, true)
        XCTAssertTrue(dependencies.providerStatusRows.contains("OpenAI: enabled, key set, gpt-4.1"))
        XCTAssertTrue(dependencies.providerStatusRows.contains("Anthropic: enabled, missing key, claude-sonnet-4"))
    }

    @MainActor
    func testHelixRuntimeDependenciesRefreshesNativeSessionsAndKnowledge() async {
        let sessionState = NativeSessionArchiveState(
            store: InMemorySessionArchiveStore(
                sessions: [
                    NativeSessionSummary(
                        title: "Archived Native Session",
                        mode: .general,
                        projectName: "Helix Native",
                        segmentCount: 1,
                        answerCount: 1
                    )
                ]
            )
        )
        let knowledgeState = NativeKnowledgeLibraryState(
            store: InMemoryKnowledgeLibraryStore(
                projects: [
                    NativeKnowledgeProject(
                        name: "Helix Native",
                        summary: "Framework rewrite",
                        isActive: true,
                        documentCount: 1,
                        factCount: 1
                    )
                ],
                facts: [
                    NativeKnowledgeItem(
                        kind: .fact,
                        text: "Native Helix keeps Even G1 parity.",
                        source: "Plan"
                    )
                ]
            )
        )
        let dependencies = HelixRuntimeDependencies(
            settingsManager: NativeSettingsManager(
                settingsStore: InMemorySettingsStore(),
                secretStore: InMemorySecretStore()
            ),
            sessionArchive: sessionState,
            knowledgeLibrary: knowledgeState
        )

        await dependencies.refreshSettings()

        XCTAssertEqual(dependencies.sessionArchive.archiveSummary, "1 session")
        XCTAssertEqual(dependencies.sessionArchive.sessions.first?.title, "Archived Native Session")
        XCTAssertEqual(dependencies.knowledgeLibrary.activeProjectName, "Helix Native")
        XCTAssertEqual(dependencies.knowledgeLibrary.snapshot.facts.first?.source, "Plan")
    }

    @MainActor
    func testHelixRuntimeDependenciesNativePersistentSharesKnowledgeWithAssistantRag() async throws {
        let suiteName = "helix.native.persistent.tests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }
        let dependencies = try HelixRuntimeDependencies.nativePersistent(
            isStoredInMemoryOnly: true,
            userDefaults: defaults,
            settingsKey: "settings.\(UUID().uuidString)",
            keychainService: "com.artjiang.helix.native.persistent.tests.\(UUID().uuidString)"
        )

        await dependencies.knowledgeLibrary.createProject(
            name: "Helix Native",
            summary: "Shared SwiftData context",
            activate: true
        )
        await dependencies.knowledgeLibrary.addFact(
            "Helix Native shares SwiftData knowledge with active answers.",
            source: "Native store"
        )
        let projectID = try XCTUnwrap(dependencies.knowledgeLibrary.snapshot.activeProject?.id.uuidString)

        await dependencies.assistantSession.ask(
            "What does the native app share?",
            projectID: projectID
        )

        XCTAssertTrue(dependencies.assistantSession.currentAnswer.contains("SwiftData knowledge"))
        XCTAssertEqual(dependencies.assistantSession.hudSummary, "1 page")
        XCTAssertEqual(dependencies.knowledgeLibrary.snapshot.facts.first?.source, "Native store")
    }

    @MainActor
    func testHelixRuntimeDependenciesMutateSettingsForRuntimeSettings() async {
        let dependencies = HelixRuntimeDependencies(
            settingsManager: NativeSettingsManager(
                settingsStore: InMemorySettingsStore(),
                secretStore: InMemorySecretStore()
            )
        )

        await dependencies.refreshSettings()
        await dependencies.selectProvider(.qwen)
        await dependencies.updateMaxResponseSentences(99)
        await dependencies.setAutoDetectQuestions(false)
        await dependencies.setAutoAnswer(false)
        await dependencies.setLiveFactCheckEnabled(false)
        await dependencies.updateTranscription(backend: .appleCloud, model: "apple-cloud-native")
        await dependencies.updateHudRenderPath(.text)
        await dependencies.updateWebSearchMode(.fakeDeterministic)
        await dependencies.setEvalGateEnabled(true)
        await dependencies.upsertCustomSkill(
            ActiveSkill(value: "custom-behavior", label: "Custom Behavior", prompt: "Answer with one impact metric.")
        )
        await dependencies.updateActiveSkill("custom-behavior")
        await dependencies.setApiKey("sk-qwen-native", for: .qwen)

        XCTAssertEqual(dependencies.settings.llmProvider, .qwen)
        XCTAssertEqual(dependencies.settings.llmModel, "qwen-plus")
        XCTAssertEqual(dependencies.settings.maxResponseSentences, 10)
        XCTAssertFalse(dependencies.settings.autoDetectQuestions)
        XCTAssertFalse(dependencies.settings.autoAnswer)
        XCTAssertFalse(dependencies.settings.liveFactCheckEnabled)
        XCTAssertEqual(dependencies.settings.transcriptionBackend, .appleCloud)
        XCTAssertEqual(dependencies.settings.transcriptionModel, "apple-cloud-native")
        XCTAssertEqual(dependencies.settings.hudRenderPath, .text)
        XCTAssertEqual(dependencies.settings.webSearchMode, .fakeDeterministic)
        XCTAssertTrue(dependencies.settings.evalGateEnabled)
        XCTAssertEqual(dependencies.settings.activeSkillID, "custom-behavior")
        XCTAssertTrue(dependencies.providerReadiness.first { $0.provider == .qwen }?.hasApiKey == true)
    }

    @MainActor
    func testNativeAssistantSessionRunsActiveAudioFixtureIntoDisplayState() async {
        let engine = NativeConversationEngine(
            audioFileTranscriber: DeterministicAudioFileTranscriber(
                transcriptsByStem: ["assistant-question": "What is an LLM?"]
            ),
            answerProvider: DeterministicAnswerProvider(),
            conversationStore: InMemoryConversationStore()
        )
        let session = NativeAssistantSessionState(engine: engine)

        await session.runAudioFixture(
            at: URL(fileURLWithPath: "/tmp/assistant-question.wav"),
            mode: .general
        )

        XCTAssertEqual(session.statusText, "Answered")
        XCTAssertEqual(session.transcriptText, "What is an LLM?")
        XCTAssertEqual(session.detectedQuestion, "What is an LLM")
        XCTAssertTrue(session.currentAnswer.lowercased().contains("transformer"))
        XCTAssertFalse(session.hudPages.isEmpty)
        XCTAssertTrue(session.eventLog.contains("answerCompleted"))
    }

    @MainActor
    func testNativeAssistantSessionRunsPassiveAudioFixtureIntoReminderState() async {
        let engine = NativeConversationEngine(
            audioFileTranscriber: DeterministicAudioFileTranscriber(
                transcriptsByStem: ["assistant-false-claim": "RAG means random answer generation."]
            ),
            answerProvider: DeterministicAnswerProvider(),
            conversationStore: InMemoryConversationStore()
        )
        let session = NativeAssistantSessionState(engine: engine)

        await session.runAudioFixture(
            at: URL(fileURLWithPath: "/tmp/assistant-false-claim.wav"),
            mode: .passive
        )

        XCTAssertEqual(session.statusText, "Reminder ready")
        XCTAssertEqual(session.transcriptText, "RAG means random answer generation.")
        XCTAssertEqual(session.passiveReminder, "RAG means retrieval augmented generation.")
        XCTAssertTrue(session.currentAnswer.isEmpty)
        XCTAssertFalse(session.hudPages.isEmpty)
        XCTAssertTrue(session.eventLog.contains("passiveReminder"))
    }

    @MainActor
    func testNativeAssistantSessionRunsManualAskIntoAnswerAndHudState() async {
        let engine = NativeConversationEngine(
            answerProvider: DeterministicAnswerProvider(),
            conversationStore: InMemoryConversationStore()
        )
        let session = NativeAssistantSessionState(engine: engine)

        await session.ask(
            "  What should Helix preserve?  ",
            mode: .general,
            projectFacts: ["Helix keeps native Even G1 HUD output"]
        )

        XCTAssertEqual(session.statusText, "Answered")
        XCTAssertEqual(session.detectedQuestion, "What should Helix preserve?")
        XCTAssertTrue(session.currentAnswer.contains("Even G1 HUD output"))
        XCTAssertFalse(session.hudPages.isEmpty)
        XCTAssertTrue(session.eventLog.contains("manualQuestion"))
        XCTAssertTrue(session.eventLog.contains("hudPagesUpdated"))
    }

    func testLiveOpenAIAnswerProviderWithEnvironmentKeyWhenRequested() async throws {
        let environment = ProcessInfo.processInfo.environment
        guard environment["HELIX_RUN_LIVE_OPENAI_EVAL"] == "1" else {
            throw XCTSkip("Set HELIX_RUN_LIVE_OPENAI_EVAL=1 to run the live OpenAI smoke test.")
        }
        guard let apiKey = environment["OPENAI_API_KEY"], !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            XCTFail("OPENAI_API_KEY is required when HELIX_RUN_LIVE_OPENAI_EVAL=1.")
            return
        }

        let discoveredModels = await OpenAIModelDiscoveryService(apiKey: apiKey).availableModels()
        let model = environment["HELIX_OPENAI_EVAL_MODEL"]
            ?? discoveredModels.first { $0 == "gpt-4.1-mini" }
            ?? "gpt-4.1-mini"
        let provider = OpenAIAnswerProvider(apiKey: apiKey, model: model)
        let answer = try await provider.completeAnswer(
            for: AnswerRequest(
                question: "Reply with a short confirmation that Native Helix live Q&A works.",
                activeSkill: ActiveSkill.skill(for: "general-chat"),
                maxResponseSentences: 1
            )
        )

        XCTAssertFalse(answer.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        XCTAssertTrue(AnswerStyleValidator().isDirectSpeakable(answer.text))
    }

    @MainActor
    func testSwiftDataSchemaPersistsConversationAndKnowledgeRecords() throws {
        let container = try HelixSwiftDataSchema.makeModelContainer(isStoredInMemoryOnly: true)
        let context = container.mainContext

        let conversation = ConversationRecord(title: "LLM Q&A", mode: .interview)
        conversation.segments.append(
            TranscriptSegmentRecord(text: "What is retrieval augmented generation?", isFinal: true)
        )
        conversation.answers.append(
            AnswerRecord(
                question: "What is retrieval augmented generation?",
                answer: "RAG combines retrieval with generation.",
                provider: .openAI,
                model: "gpt-4.1"
            )
        )

        let project = ProjectRecord(name: "Helix Native")
        let document = KnowledgeDocumentRecord(title: "Architecture Notes", project: project)
        document.chunks.append(
            DocumentChunkRecord(
                ordinal: 0,
                text: "Helix displays answers on Even G1 glasses.",
                tokenCount: 8,
                embeddingModel: "text-embedding-3-small",
                embeddingVector: [0.1, 0.2]
            )
        )
        let fact = FactRecord(
            text: "Helix displays answers on Even G1 glasses.",
            source: "Architecture Notes",
            projectID: project.id
        )

        context.insert(conversation)
        context.insert(project)
        context.insert(fact)
        try context.save()

        let conversations = try context.fetch(FetchDescriptor<ConversationRecord>())
        let projects = try context.fetch(FetchDescriptor<ProjectRecord>())
        let facts = try context.fetch(FetchDescriptor<FactRecord>())

        XCTAssertEqual(conversations.first?.mode, .interview)
        XCTAssertEqual(conversations.first?.segments.first?.text, "What is retrieval augmented generation?")
        XCTAssertEqual(conversations.first?.answers.first?.provider, .openAI)
        XCTAssertEqual(projects.first?.documents.first?.chunks.first?.embeddingVector, [0.1, 0.2])
        XCTAssertEqual(facts.first?.projectID, project.id)
    }

    private func collectEvents(
        from stream: AsyncThrowingStream<NativeConversationEvent, Error>
    ) async throws -> [NativeConversationEvent] {
        var events: [NativeConversationEvent] = []
        for try await event in stream {
            events.append(event)
        }
        return events
    }
}

private actor FakeOpenAITransport: OpenAIDataTransport {
    private let data: Data
    private let statusCode: Int
    private(set) var lastRequest: URLRequest?
    private(set) var lastBodyString: String?

    init(data: Data, statusCode: Int = 200) {
        self.data = data
        self.statusCode = statusCode
    }

    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        lastRequest = request
        lastBodyString = request.httpBody.flatMap { String(data: $0, encoding: .utf8) }
        let response = HTTPURLResponse(
            url: request.url ?? URL(string: "https://unit.test")!,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: nil
        )!
        return (data, response)
    }
}

private actor FakeOpenAIAudioTransport: OpenAIAudioDataTransport {
    private let data: Data
    private let statusCode: Int
    private(set) var lastRequest: URLRequest?
    private(set) var lastBodyString: String?

    init(data: Data, statusCode: Int = 200) {
        self.data = data
        self.statusCode = statusCode
    }

    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        lastRequest = request
        lastBodyString = request.httpBody.flatMap { String(data: $0, encoding: .utf8) }
        let response = HTTPURLResponse(
            url: request.url ?? URL(string: "https://unit.test")!,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: nil
        )!
        return (data, response)
    }
}
