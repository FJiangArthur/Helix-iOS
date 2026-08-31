import XCTest
import HelixAI
import HelixConversation
import HelixCore
import HelixPersistence
import HelixRuntime
import HelixSpeech

final class NativeQuestionPipelineRegressionTests: XCTestCase {
    func testQuestionDetectorRecognizesQuestionMarkWithoutInterrogativePrefix() {
        let questions = QuestionDetector().detectQuestions(in: "Tell me the current time?")

        XCTAssertEqual(questions.map(\.text), ["Tell me the current time?"])
        XCTAssertEqual(questions.first?.confidence, 0.95)
    }

    func testQuestionDetectorPreservesArabicQuestionMark() {
        let questions = QuestionDetector().detectQuestions(in: "هل هذا صحيح؟")

        XCTAssertEqual(questions.map(\.text), ["هل هذا صحيح؟"])
        XCTAssertEqual(questions.first?.confidence, 0.95)
    }

    func testQuestionDetectorAcceptsQuestionMarkBeforeClosingQuotesAndBrackets() {
        let questions = QuestionDetector().detectQuestions(
            in: #"She asked, "What changed?" (Why now?)"#
        )

        XCTAssertEqual(
            questions.map(\.text),
            [#"She asked, "What changed?""#, "(Why now?)"]
        )
        XCTAssertTrue(questions.allSatisfy { $0.confidence == 0.95 })
    }

    func testDistinctUnicodeQuestionsDoNotCollapseToOneDuplicateKey() async throws {
        let attempts = AnswerAttemptRecorder()
        let engine = NativeConversationEngine(
            answerProvider: RecordingAnswerProvider(recorder: attempts),
            conversationStore: InMemoryConversationStore()
        )

        let result = try await engine.processFinalSegment(
            TranscriptSegment(
                text: "什么是检索增强生成？它如何减少幻觉？",
                isFinal: true,
                finalizedAt: Date()
            ),
            mode: .general
        )

        let expected = ["什么是检索增强生成？", "它如何减少幻觉？"]
        XCTAssertEqual(result.questionResults.map(\.question.text), expected)

        // Providers run concurrently, so invocation order is intentionally
        // not a presentation-order contract. Verify both distinct questions
        // were answered exactly once; the ordered result assertion above is
        // what protects the user-visible spoken order.
        let questions = await attempts.questions
        XCTAssertEqual(questions.count, expected.count)
        XCTAssertEqual(Set(questions), Set(expected))
    }

    func testFinalSegmentAnswersEveryDistinctQuestion() async throws {
        let attempts = AnswerAttemptRecorder()
        let engine = NativeConversationEngine(
            answerProvider: RecordingAnswerProvider(recorder: attempts),
            conversationStore: InMemoryConversationStore()
        )

        let result = try await engine.processFinalSegment(
            TranscriptSegment(
                text: "What is retrieval augmented generation? How does it reduce hallucinations?",
                isFinal: true,
                finalizedAt: Date()
            ),
            mode: .general
        )

        let questions = await attempts.questions
        XCTAssertEqual(
            questions,
            ["What is retrieval augmented generation?", "How does it reduce hallucinations?"]
        )
        XCTAssertEqual(result.questionResults.map(\.question.text), questions)
        XCTAssertTrue(result.questionResults.allSatisfy { $0.answer != nil && !$0.hudPages.isEmpty })
    }

    func testQuestionsWithinOneSegmentAnswerConcurrentlyButReturnInSpeechOrder() async throws {
        let firstQuestion = "What is the slow first topic?"
        let secondQuestion = "How does the fast second topic work?"
        let controller = ControlledAnswerRecorder(blockedQuestions: [firstQuestion])
        let engine = NativeConversationEngine(
            answerProvider: ControlledAnswerProvider(controller: controller),
            conversationStore: InMemoryConversationStore()
        )

        let processing = Task {
            try await engine.processFinalSegment(
                TranscriptSegment(
                    text: "\(firstQuestion) \(secondQuestion)",
                    isFinal: true,
                    finalizedAt: Date()
                ),
                mode: .general
            )
        }
        await controller.waitUntilStarted(firstQuestion)
        try await Task.sleep(nanoseconds: 50_000_000)
        let startedBeforeRelease = await controller.startedQuestions
        await controller.release(firstQuestion)
        let result = try await processing.value

        XCTAssertTrue(startedBeforeRelease.contains(secondQuestion))
        XCTAssertEqual(
            result.questionResults.map(\.question.text),
            [firstQuestion, secondQuestion]
        )
        XCTAssertEqual(
            result.questionResults.compactMap(\.answer?.text),
            ["Answer for \(firstQuestion)", "Answer for \(secondQuestion)"]
        )
    }

    func testFirstQuestionFailureDoesNotEraseLaterSuccessfulAnswer() async throws {
        let firstQuestion = "What is the failing first topic?"
        let secondQuestion = "How does the successful second topic work?"
        let controller = ControlledAnswerRecorder(
            blockedQuestions: [firstQuestion],
            failingQuestions: [firstQuestion]
        )
        let engine = NativeConversationEngine(
            answerProvider: ControlledAnswerProvider(controller: controller),
            conversationStore: InMemoryConversationStore()
        )

        let processing = Task {
            try await engine.processFinalSegment(
                TranscriptSegment(
                    text: "\(firstQuestion) \(secondQuestion)",
                    isFinal: true,
                    finalizedAt: Date()
                ),
                mode: .general
            )
        }
        await controller.waitUntilFinished(secondQuestion)
        await controller.release(firstQuestion)
        let result = try await processing.value

        XCTAssertNotNil(result.questionResults[0].failureReason)
        XCTAssertNil(result.questionResults[0].answer)
        XCTAssertEqual(result.questionResults[1].answer?.text, "Answer for \(secondQuestion)")
        XCTAssertEqual(result.answer?.text, "Answer for \(secondQuestion)")
    }

    func testAudioFilePipelineEmitsAnAnswerForEveryDistinctQuestion() async throws {
        let engine = NativeConversationEngine(
            audioFileTranscriber: DeterministicAudioFileTranscriber(
                transcriptsByStem: [
                    "two-questions": "What is retrieval augmented generation? How does it reduce hallucinations?"
                ]
            ),
            answerProvider: DeterministicAnswerProvider(),
            conversationStore: InMemoryConversationStore()
        )

        var detectedQuestions: [String] = []
        var completedAnswerCount = 0
        let stream = await engine.processAudioFile(
            at: URL(fileURLWithPath: "/tmp/two-questions.wav"),
            mode: .general
        )
        for try await event in stream {
            switch event {
            case .questionDetected(let question):
                detectedQuestions.append(question.text)
            case .answerCompleted:
                completedAnswerCount += 1
            default:
                break
            }
        }

        XCTAssertEqual(
            detectedQuestions,
            ["What is retrieval augmented generation?", "How does it reduce hallucinations?"]
        )
        XCTAssertEqual(completedAnswerCount, 2)
    }

    func testAudioFileQuestionsStartProvidersConcurrentlyButEmitAnswersInSpeechOrder() async throws {
        let firstQuestion = "What is the slow first recording topic?"
        let secondQuestion = "How does the fast second recording topic work?"
        let controller = ControlledAnswerRecorder(blockedQuestions: [firstQuestion])
        let engine = NativeConversationEngine(
            audioFileTranscriber: DeterministicAudioFileTranscriber(
                transcriptsByStem: [
                    "recording-concurrency": "\(firstQuestion) \(secondQuestion)"
                ]
            ),
            answerProvider: ControlledAnswerProvider(controller: controller),
            conversationStore: InMemoryConversationStore()
        )
        let stream = await engine.processAudioFile(
            at: URL(fileURLWithPath: "/tmp/recording-concurrency.wav"),
            mode: .general
        )
        let collection = Task {
            var completed: [String] = []
            for try await event in stream {
                if case .answerCompleted(let answer) = event {
                    completed.append(answer.text)
                }
            }
            return completed
        }

        await controller.waitUntilStarted(firstQuestion)
        await controller.waitUntilFinished(secondQuestion)
        let startedBeforeRelease = await controller.startedQuestions
        await controller.release(firstQuestion)
        let completed = try await collection.value

        XCTAssertEqual(startedBeforeRelease.count, 2)
        XCTAssertEqual(Set(startedBeforeRelease), Set([firstQuestion, secondQuestion]))
        XCTAssertEqual(
            completed,
            ["Answer for \(firstQuestion)", "Answer for \(secondQuestion)"]
        )
    }

    func testQuestionCanRetryAfterAnswerProviderFailure() async throws {
        let attempts = AnswerAttemptRecorder(failFirstAttempt: true)
        let engine = NativeConversationEngine(
            answerProvider: RecordingAnswerProvider(recorder: attempts),
            conversationStore: InMemoryConversationStore()
        )
        let segment = TranscriptSegment(
            text: "What is retrieval augmented generation?",
            isFinal: true,
            finalizedAt: Date()
        )

        do {
            _ = try await engine.processFinalSegment(segment, mode: .general)
            XCTFail("The first provider attempt should fail")
        } catch AnswerAttemptRecorder.StubError.expectedFailure {
            // Expected: the retry below must not be poisoned by this failure.
        }

        let retry = try await engine.processFinalSegment(segment, mode: .general)

        let attemptCount = await attempts.attemptCount
        XCTAssertNotNil(retry.answer)
        XCTAssertEqual(attemptCount, 2)
    }

    func testDetectedQuestionCanAnswerAfterAutoAnswerIsEnabled() async throws {
        let attempts = AnswerAttemptRecorder()
        let engine = NativeConversationEngine(
            settings: HelixSettings(autoAnswer: false),
            answerProvider: RecordingAnswerProvider(recorder: attempts),
            conversationStore: InMemoryConversationStore()
        )
        let segment = TranscriptSegment(
            text: "What is retrieval augmented generation?",
            isFinal: true,
            finalizedAt: Date()
        )

        let detectionOnly = try await engine.processFinalSegment(segment, mode: .general)
        await engine.updateSettings(HelixSettings(autoAnswer: true))
        let answered = try await engine.processFinalSegment(segment, mode: .general)

        let attemptCount = await attempts.attemptCount
        XCTAssertNotNil(detectionOnly.question)
        XCTAssertNil(detectionOnly.answer)
        XCTAssertNotNil(answered.answer)
        XCTAssertEqual(attemptCount, 1)
    }

    func testStatementFormChineseQuestionUsesLiveClassifier() async throws {
        let statement = "我想知道检索增强生成是否能减少幻觉"
        let attempts = AnswerAttemptRecorder()
        let engine = NativeConversationEngine(
            answerProvider: RecordingAnswerProvider(recorder: attempts),
            conversationStore: InMemoryConversationStore(),
            questionClassifier: HybridQuestionClassifier(
                liveClassifier: StubLiveQuestionClassifier(
                    result: [QuestionCandidate(text: statement, confidence: 0.86)]
                )
            )
        )

        let result = try await engine.processFinalSegment(
            TranscriptSegment(text: statement, isFinal: true, finalizedAt: Date()),
            mode: .general
        )

        XCTAssertEqual(result.question?.text, statement)
        let answeredQuestions = await attempts.questions
        XCTAssertEqual(answeredQuestions, [statement])
    }

    func testLiveClassifierFailureFallsBackToChineseQuestionPunctuation() async {
        let classifier = HybridQuestionClassifier(
            liveClassifier: StubLiveQuestionClassifier(error: .expectedFailure),
            directQuestionFastPathConfidence: 1.0
        )

        let questions = await classifier.detectQuestions(
            in: "什么是检索增强生成？",
            sensitivity: .balanced
        )

        XCTAssertEqual(questions.map(\.text), ["什么是检索增强生成？"])
    }

    func testArabicAndQuotedExplicitQuestionsBypassLiveClassifier() async {
        let recorder = LiveClassifierInvocationRecorder()
        let classifier = HybridQuestionClassifier(
            liveClassifier: RecordingLiveQuestionClassifier(recorder: recorder)
        )

        let arabic = await classifier.detectQuestions(
            in: "هل هذا صحيح؟",
            sensitivity: .balanced
        )
        let quoted = await classifier.detectQuestions(
            in: #"She asked, "What changed?""#,
            sensitivity: .balanced
        )

        XCTAssertEqual(arabic.map(\.text), ["هل هذا صحيح؟"])
        XCTAssertEqual(quoted.map(\.text), [#"She asked, "What changed?""#])
        let invocationCount = await recorder.invocationCount
        XCTAssertEqual(invocationCount, 0)
    }

    func testQuestionDetectionSensitivityControlsAmbiguousLiveResult() async {
        let candidate = QuestionCandidate(text: "Perhaps retrieval could help", confidence: 0.55)
        let classifier = HybridQuestionClassifier(
            liveClassifier: StubLiveQuestionClassifier(result: [candidate])
        )

        let sensitive = await classifier.detectQuestions(
            in: candidate.text,
            sensitivity: .sensitive
        )
        let conservative = await classifier.detectQuestions(
            in: candidate.text,
            sensitivity: .conservative
        )

        XCTAssertEqual(sensitive.map(\.text), [candidate.text])
        XCTAssertTrue(conservative.isEmpty)
    }

    func testMixedExplicitAndImplicitQuestionsMergeHeuristicAndLiveResults() async {
        let transcript = "What changed? I wonder who approved it"
        let implicitQuestion = "I wonder who approved it"
        let classifier = HybridQuestionClassifier(
            liveClassifier: StubLiveQuestionClassifier(
                result: [QuestionCandidate(text: implicitQuestion, confidence: 0.88)]
            )
        )

        let questions = await classifier.detectQuestions(in: transcript, sensitivity: .balanced)

        XCTAssertEqual(questions.map(\.text), ["What changed?", implicitQuestion])
    }

    func testMixedImplicitAndExplicitQuestionsRemainInSpokenOrder() async {
        let implicitQuestion = "I wonder who approved it"
        let transcript = "\(implicitQuestion). What changed?"
        let classifier = HybridQuestionClassifier(
            liveClassifier: StubLiveQuestionClassifier(
                result: [QuestionCandidate(text: implicitQuestion, confidence: 0.88)]
            )
        )

        let questions = await classifier.detectQuestions(in: transcript, sensitivity: .balanced)

        XCTAssertEqual(questions.map(\.text), [implicitQuestion, "What changed?"])
    }

    func testAnswerProviderLiveClassifierParsesMultilingualJSON() async throws {
        let requestRecorder = AnswerRequestRecorder()
        let classifier = AnswerProviderQuestionLiveClassifier(
            provider: FixedTextAnswerProvider(
                text: #"{"questions":[{"text":"我们是否应该使用检索增强生成？","confidence":0.91}]}"#,
                requestRecorder: requestRecorder
            )
        )

        let questions = try await classifier.classify(
            QuestionDetectionPrompt(
                transcript: "我们是否应该使用检索增强生成？",
                sensitivity: .balanced
            )
        )

        XCTAssertEqual(questions.map(\.text), ["我们是否应该使用检索增强生成？"])
        XCTAssertEqual(questions.first?.confidence, 0.91)
        let providerPrompt = await requestRecorder.questions.first ?? ""
        XCTAssertTrue(providerPrompt.contains("我们是否应该使用检索增强生成？"))
        XCTAssertTrue(providerPrompt.contains("likely implicit requests"))
    }

    func testAnswerProviderLiveClassifierRejectsFabricatedQuestionsAndRestoresSourceOrder() async throws {
        let transcript = "I wonder who approved it. What changed?"
        let classifier = AnswerProviderQuestionLiveClassifier(
            provider: FixedTextAnswerProvider(
                text: #"{"questions":[{"text":"What changed?","confidence":0.95},{"text":"Who approved the acquisition?","confidence":0.99},{"text":"I wonder who approved it","confidence":0.82}]}"#,
                requestRecorder: nil
            )
        )

        let questions = try await classifier.classify(
            QuestionDetectionPrompt(transcript: transcript, sensitivity: .balanced)
        )

        XCTAssertEqual(
            questions.map(\.text),
            ["I wonder who approved it", "What changed?"]
        )
    }

    func testAnswerProviderLiveClassifierRetainsStatementWhenModelNormalizesQuestionPunctuation() async throws {
        let transcript = "I wonder who approved it."
        let classifier = AnswerProviderQuestionLiveClassifier(
            provider: FixedTextAnswerProvider(
                text: #"{"questions":[{"text":"I wonder who approved it?","confidence":0.88}]}"#,
                requestRecorder: nil
            )
        )

        let questions = try await classifier.classify(
            QuestionDetectionPrompt(transcript: transcript, sensitivity: .balanced)
        )

        XCTAssertEqual(questions.map(\.text), ["I wonder who approved it?"])
        XCTAssertEqual(questions.first?.confidence, 0.88)
    }

    func testProviderBodiesUseJSONOnlySystemPromptForQuestionClassification() throws {
        let request = AnswerRequest(
            question: "Detect questions in: 我想知道检索能否减少幻觉",
            activeSkill: ActiveSkill(
                value: "question-classification",
                label: "Question Classification",
                prompt: "Return only JSON."
            ),
            maxResponseSentences: 1
        )

        let openAIRequest = try OpenAIAnswerProvider(
            apiKey: "sk-test",
            model: "gpt-4.1-mini"
        ).makeURLRequest(for: request)
        let openAIData = try XCTUnwrap(openAIRequest.httpBody)
        let openAIBody = try XCTUnwrap(
            JSONSerialization.jsonObject(with: openAIData) as? [String: Any]
        )
        let messages = try XCTUnwrap(openAIBody["messages"] as? [[String: Any]])
        let openAISystem = try XCTUnwrap(messages.first?["content"] as? String)

        let anthropicRequest = try AnthropicAnswerProvider(
            apiKey: "sk-ant-test",
            model: "claude-haiku-4"
        ).makeURLRequest(for: request)
        let anthropicData = try XCTUnwrap(anthropicRequest.httpBody)
        let anthropicBody = try XCTUnwrap(
            JSONSerialization.jsonObject(with: anthropicData) as? [String: Any]
        )
        let anthropicSystem = try XCTUnwrap(anthropicBody["system"] as? String)

        for systemPrompt in [openAISystem, anthropicSystem] {
            XCTAssertTrue(systemPrompt.contains("Return only valid JSON"))
            XCTAssertFalse(systemPrompt.contains("speakable"))
            XCTAssertFalse(systemPrompt.contains("Answer directly"))
        }
    }

    func testOpenAIReasoningModelsOmitTemperatureAndTokenCap() throws {
        let request = AnswerRequest(question: "Analyze the tradeoffs", maxResponseSentences: 8)
        for model in ["gpt-5.2", "o1", "o3-mini", "o4"] {
            let urlRequest = try OpenAIAnswerProvider(
                apiKey: "sk-test",
                model: model
            ).makeURLRequest(for: request)
            let data = try XCTUnwrap(urlRequest.httpBody)
            let body = try XCTUnwrap(
                JSONSerialization.jsonObject(with: data) as? [String: Any]
            )

            XCTAssertNil(body["temperature"], model)
            XCTAssertNil(body["max_tokens"], model)
            XCTAssertNil(body["max_completion_tokens"], model)
        }

        let standardRequest = try OpenAIAnswerProvider(
            apiKey: "sk-test",
            model: "gpt-4.1"
        ).makeURLRequest(for: request)
        let standardData = try XCTUnwrap(standardRequest.httpBody)
        let standardBody = try XCTUnwrap(
            JSONSerialization.jsonObject(with: standardData) as? [String: Any]
        )
        XCTAssertEqual(standardBody["temperature"] as? Double, 0.2)
        XCTAssertEqual(standardBody["max_tokens"] as? Int, 2048)
    }

    @MainActor
    func testRuntimeSyncWiresQuestionClassifierToConfiguredLightModel() async {
        let settings = HelixSettings()
        let secrets = InMemorySecretStore()
        await secrets.setSecret("sk-test", named: "openai_api_key")
        let runtime = HelixRuntimeDependencies(
            settingsManager: NativeSettingsManager(
                settingsStore: InMemorySettingsStore(settings: settings),
                secretStore: secrets
            ),
            settings: settings
        )

        await runtime.syncEngine()

        let source = await runtime.assistantSession.currentQuestionClassifierDescription()
        let automaticProvider = await runtime.assistantSession.currentAutomaticAnswerProviderDescription()
        let deepProvider = await runtime.assistantSession.currentDeepAnswerProviderDescription()
        XCTAssertEqual(source, "live:openAI:gpt-4.1-mini + heuristic-fallback")
        XCTAssertEqual(automaticProvider, "openAI:gpt-4.1-mini")
        XCTAssertEqual(deepProvider, "openAI:gpt-4.1")
    }

    @MainActor
    func testAskDeeperUsesSeparateSmartProviderAndReturnsModelIdentity() async {
        let session = NativeAssistantSessionState(
            engine: NativeConversationEngine(
                answerProvider: ModelTaggedAnswerProvider(model: "fast-light-model"),
                deepAnswerProvider: ModelTaggedAnswerProvider(model: "reasoning-smart-model"),
                conversationStore: InMemoryConversationStore()
            )
        )

        let response = await session.askDeeper("Why does retrieval grounding reduce hallucinations?")

        XCTAssertEqual(response?.model, "reasoning-smart-model")
        XCTAssertEqual(session.currentAnswer, "Deep response from reasoning-smart-model")
        XCTAssertEqual(session.currentAnswerModel, "reasoning-smart-model")
        XCTAssertEqual(session.answerDepth, .deeper)
    }

    @MainActor
    func testConcurrentLiveTranscriptsProgressInParallelButApplyInTranscriptOrder() async {
        let firstQuestion = "What is the slow first question?"
        let secondQuestion = "What is the fast second question?"
        let controller = ControlledAnswerRecorder(blockedQuestions: [firstQuestion])
        let session = NativeAssistantSessionState(
            engine: NativeConversationEngine(
                answerProvider: ControlledAnswerProvider(controller: controller),
                conversationStore: InMemoryConversationStore()
            )
        )
        var committedQuestions: [String] = []
        session.setLiveTranscriptCommitHandler { outcome in
            if let question = outcome.turn?.question?.text {
                committedQuestions.append(question)
            }
        }

        let firstTask = Task {
            await session.processLiveTranscript(firstQuestion)
        }
        await controller.waitUntilStarted(firstQuestion)

        let secondTask = Task {
            await session.processLiveTranscript(secondQuestion)
        }
        await controller.waitUntilFinished(secondQuestion)

        // The second provider request completed while the first remained
        // blocked, proving final-transcript processing was not serialized.
        let startedQuestions = await controller.startedQuestions
        XCTAssertEqual(startedQuestions, [firstQuestion, secondQuestion])

        await controller.release(firstQuestion)
        _ = await (firstTask.value, secondTask.value)

        // UI state must still commit in transcript arrival order, so the later
        // (second) answer remains current even though it completed first.
        XCTAssertEqual(session.detectedQuestion, secondQuestion)
        XCTAssertEqual(session.currentAnswer, "Answer for \(secondQuestion)")
        XCTAssertEqual(committedQuestions, [firstQuestion, secondQuestion])
        XCTAssertEqual(session.committedLiveTranscriptOutcomes.map(\.sequence), [0, 1])
        XCTAssertEqual(
            session.committedLiveTranscriptOutcomes.flatMap { outcome in
                outcome.turn?.questionResults.map(\.question.text) ?? []
            },
            [firstQuestion, secondQuestion]
        )
    }

    @MainActor
    func testSlowFirstClassificationKeepsDuplicateOwnershipWithFirstSpeaker() async throws {
        let question = "Who owns the release decision?"
        let classifierController = ControlledFirstQuestionClassifierController()
        let attempts = AnswerAttemptRecorder()
        let session = NativeAssistantSessionState(
            engine: NativeConversationEngine(
                answerProvider: RecordingAnswerProvider(recorder: attempts),
                conversationStore: InMemoryConversationStore(),
                questionClassifier: ControlledFirstQuestionClassifier(
                    controller: classifierController
                )
            )
        )

        let firstTask = Task {
            await session.processLiveTranscript(
                question,
                sourceSegmentID: "speaker-a-turn",
                speaker: "Alice",
                speakerSource: .sourceProvided
            )
        }
        await classifierController.waitUntilFirstStarted()

        let secondTask = Task {
            await session.processLiveTranscript(
                question,
                sourceSegmentID: "speaker-b-turn",
                speaker: "Bob",
                speakerSource: .sourceProvided
            )
        }
        try await Task.sleep(nanoseconds: 50_000_000)
        let invocationsBeforeRelease = await classifierController.invocationCount
        XCTAssertEqual(
            invocationsBeforeRelease,
            1,
            "A later segment must wait until the first segment owns dedupe preparation"
        )

        await classifierController.releaseFirst()
        _ = await (firstTask.value, secondTask.value)

        let outcomes = session.committedLiveTranscriptOutcomes
        XCTAssertEqual(outcomes.map(\.segment.speaker), ["Alice", "Bob"])
        XCTAssertTrue(outcomes[0].answered)
        XCTAssertFalse(outcomes[1].answered)
        XCTAssertEqual(
            outcomes[1].turn?.questionResults.first?.suppressionReason,
            "Duplicate question suppressed."
        )
        let attemptedQuestions = await attempts.questions
        XCTAssertEqual(attemptedQuestions, [question])
    }

    @MainActor
    func testOldGenerationPreparationCompletionCannotAdvanceNewConversationGate() async throws {
        let controller = IndexedBlockingQuestionClassifierController(blockedInvocations: [1, 2])
        let session = NativeAssistantSessionState(
            engine: NativeConversationEngine(
                answerProvider: DeterministicAnswerProvider(),
                conversationStore: InMemoryConversationStore(),
                questionClassifier: IndexedBlockingQuestionClassifier(controller: controller)
            )
        )

        let oldTask = Task {
            await session.processLiveTranscript("Explain the old session topic")
        }
        await controller.waitUntilStarted(invocation: 1)

        await session.startNewConversation()
        let newFirstTask = Task {
            await session.processLiveTranscript("Explain the new first topic")
        }
        await controller.waitUntilStarted(invocation: 2)
        let newSecondTask = Task {
            await session.processLiveTranscript("Explain the new second topic")
        }
        try await Task.sleep(nanoseconds: 30_000_000)
        let beforeOldRelease = await controller.invocationCount
        XCTAssertEqual(beforeOldRelease, 2)

        await controller.release(invocation: 1)
        _ = await oldTask.value
        try await Task.sleep(nanoseconds: 30_000_000)
        let afterOldRelease = await controller.invocationCount
        XCTAssertEqual(
            afterOldRelease,
            2,
            "Old seq0 completion must not release the new generation's seq1"
        )

        await controller.release(invocation: 2)
        await controller.waitUntilStarted(invocation: 3)
        _ = await (newFirstTask.value, newSecondTask.value)

        let finalInvocationCount = await controller.invocationCount
        XCTAssertEqual(finalInvocationCount, 3)
        XCTAssertEqual(
            session.committedLiveTranscriptOutcomes.map(\.segment.text),
            ["Explain the new first topic", "Explain the new second topic"]
        )
    }

    @MainActor
    func testNewConversationDiscardsAnInFlightOldTurnAndResetsDedupe() async {
        let question = "What belongs to the previous conversation?"
        let controller = ControlledAnswerRecorder(blockedQuestions: [question])
        let session = NativeAssistantSessionState(
            engine: NativeConversationEngine(
                answerProvider: ControlledAnswerProvider(controller: controller),
                conversationStore: InMemoryConversationStore()
            )
        )

        let oldTask = Task {
            await session.processLiveTranscript(question)
        }
        await controller.waitUntilStarted(question)

        await session.startNewConversation()
        await controller.release(question)
        _ = await oldTask.value

        XCTAssertTrue(session.committedLiveTranscriptOutcomes.isEmpty)
        XCTAssertEqual(session.transcriptText, "")
        XCTAssertEqual(session.detectedQuestion, "")
        XCTAssertEqual(session.currentAnswer, "")
        XCTAssertTrue(session.eventLog.isEmpty)

        _ = await session.processLiveTranscript(question)

        XCTAssertEqual(session.committedLiveTranscriptOutcomes.count, 1)
        XCTAssertEqual(session.detectedQuestion, question)
        XCTAssertEqual(session.currentAnswer, "Answer for \(question)")
    }

    @MainActor
    func testNewConversationDiscardsAnInFlightAudioFixture() async {
        let transcriber = ControlledAudioFileTranscriber(
            transcript: "What belongs to the discarded audio fixture?"
        )
        let session = NativeAssistantSessionState(
            engine: NativeConversationEngine(
                audioFileTranscriber: transcriber,
                answerProvider: DeterministicAnswerProvider(),
                conversationStore: InMemoryConversationStore()
            )
        )

        let fixtureTask = Task {
            await session.runAudioFixture(at: URL(fileURLWithPath: "/tmp/discarded.wav"))
        }
        await transcriber.waitUntilStarted()
        await session.startNewConversation()
        await transcriber.release()
        await fixtureTask.value

        XCTAssertEqual(session.transcriptText, "")
        XCTAssertEqual(session.detectedQuestion, "")
        XCTAssertEqual(session.currentAnswer, "")
        XCTAssertTrue(session.eventLog.isEmpty)
        XCTAssertFalse(session.isRunning)
    }

    @MainActor
    func testNewConversationDiscardsInFlightManualAskWithoutEndingNewLiveTurn() async {
        let oldQuestion = "What belongs to the discarded manual request?"
        let newQuestion = "What belongs to the active live request?"
        let controller = ControlledAnswerRecorder(blockedQuestions: [oldQuestion, newQuestion])
        let provider = ControlledAnswerProvider(controller: controller)
        let session = NativeAssistantSessionState(
            engine: NativeConversationEngine(
                answerProvider: provider,
                conversationStore: InMemoryConversationStore()
            )
        )

        let oldTask = Task { await session.ask(oldQuestion) }
        await controller.waitUntilStarted(oldQuestion)
        await session.startNewConversation()

        let newTask = Task { await session.processLiveTranscript(newQuestion) }
        await controller.waitUntilStarted(newQuestion)
        await controller.release(oldQuestion)

        let oldResponse = await oldTask.value
        XCTAssertNil(oldResponse)
        XCTAssertTrue(session.isRunning, "The stale manual defer must not stop the new live turn")
        XCTAssertEqual(session.transcriptText, newQuestion)
        XCTAssertFalse(session.eventLog.contains("failure"))

        await controller.release(newQuestion)
        _ = await newTask.value
        XCTAssertEqual(session.detectedQuestion, newQuestion)
        XCTAssertEqual(session.currentAnswer, "Answer for \(newQuestion)")
        XCTAssertFalse(session.isRunning)
    }

    @MainActor
    func testNewConversationDiscardsInFlightDeepAskWithoutEndingNewLiveTurn() async {
        let oldQuestion = "Why should the discarded request think deeper?"
        let newQuestion = "What belongs to the replacement live request?"
        let controller = ControlledAnswerRecorder(blockedQuestions: [oldQuestion, newQuestion])
        let provider = ControlledAnswerProvider(controller: controller)
        let session = NativeAssistantSessionState(
            engine: NativeConversationEngine(
                answerProvider: provider,
                deepAnswerProvider: provider,
                conversationStore: InMemoryConversationStore()
            )
        )

        let oldTask = Task { await session.askDeeper(oldQuestion) }
        await controller.waitUntilStarted(oldQuestion)
        await session.startNewConversation()

        let newTask = Task { await session.processLiveTranscript(newQuestion) }
        await controller.waitUntilStarted(newQuestion)
        await controller.release(oldQuestion)

        let oldResponse = await oldTask.value
        XCTAssertNil(oldResponse)
        XCTAssertTrue(session.isRunning, "The stale deep defer must not stop the new live turn")
        XCTAssertEqual(session.transcriptText, newQuestion)
        XCTAssertFalse(session.eventLog.contains("failure"))

        await controller.release(newQuestion)
        _ = await newTask.value
        XCTAssertEqual(session.detectedQuestion, newQuestion)
        XCTAssertEqual(session.currentAnswer, "Answer for \(newQuestion)")
        XCTAssertEqual(session.answerDepth, .automatic)
        XCTAssertFalse(session.isRunning)
    }

    @MainActor
    func testLaterSpeakerEnrichmentUpsertsSegmentWithoutAnsweringTwice() async {
        let question = "What is retrieval grounding?"
        let attempts = AnswerAttemptRecorder()
        let store = InMemoryConversationStore()
        let session = NativeAssistantSessionState(
            engine: NativeConversationEngine(
                answerProvider: RecordingAnswerProvider(recorder: attempts),
                conversationStore: store
            )
        )

        _ = await session.processLiveTranscript(question, sourceSegmentID: "segment-7")
        let originalID = session.committedLiveTranscriptOutcomes.first?.segment.id
        let update = await session.processLiveTranscript(
            question,
            sourceSegmentID: "segment-7",
            speaker: "Estimated speaker 1",
            speakerSource: .localEnergyEstimate,
            speakerConfidence: 0.62
        )

        let answeredQuestions = await attempts.questions
        let storedSegments = await store.transcript()
        XCTAssertEqual(answeredQuestions, [question])
        XCTAssertEqual(session.committedLiveTranscriptOutcomes.count, 1)
        XCTAssertEqual(update?.segment.id, originalID)
        XCTAssertEqual(update?.segment.speaker, "Estimated speaker 1")
        XCTAssertEqual(update?.segment.speakerSource, .localEnergyEstimate)
        XCTAssertEqual(update?.segment.speakerConfidence, 0.62)
        XCTAssertEqual(update?.isMetadataUpdate, true)
        XCTAssertEqual(storedSegments.count, 1)
        XCTAssertEqual(storedSegments.first?.speaker, "Estimated speaker 1")
    }
}

private actor AnswerAttemptRecorder {
    enum StubError: Error {
        case expectedFailure
    }

    private(set) var questions: [String] = []
    private(set) var attemptCount = 0
    private let failFirstAttempt: Bool

    init(failFirstAttempt: Bool = false) {
        self.failFirstAttempt = failFirstAttempt
    }

    func response(for question: String) throws -> String {
        questions.append(question)
        attemptCount += 1
        if failFirstAttempt && attemptCount == 1 {
            throw StubError.expectedFailure
        }
        return "Answer for \(question)."
    }
}

private struct RecordingAnswerProvider: HelixAnswerProvider {
    let kind: LlmProviderKind = .openAI
    let model = "recording-test-provider"
    let recorder: AnswerAttemptRecorder

    func streamAnswer(for request: AnswerRequest) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    continuation.yield(try await recorder.response(for: request.question))
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}

private actor ControlledAnswerRecorder {
    enum StubError: Error {
        case expectedFailure
    }

    private(set) var startedQuestions: [String] = []
    private var finishedQuestions: Set<String> = []
    private var blockedQuestions: Set<String>
    private let failingQuestions: Set<String>
    private var releaseWaiters: [String: CheckedContinuation<Void, Never>] = [:]
    private var startWaiters: [String: [CheckedContinuation<Void, Never>]] = [:]
    private var finishWaiters: [String: [CheckedContinuation<Void, Never>]] = [:]

    init(blockedQuestions: Set<String>, failingQuestions: Set<String> = []) {
        self.blockedQuestions = blockedQuestions
        self.failingQuestions = failingQuestions
    }

    func answer(for question: String) async throws -> String {
        startedQuestions.append(question)
        startWaiters.removeValue(forKey: question)?.forEach { $0.resume() }

        if blockedQuestions.contains(question) {
            await withCheckedContinuation { continuation in
                releaseWaiters[question] = continuation
            }
        }

        finishedQuestions.insert(question)
        finishWaiters.removeValue(forKey: question)?.forEach { $0.resume() }
        if failingQuestions.contains(question) {
            throw StubError.expectedFailure
        }
        return "Answer for \(question)"
    }

    func waitUntilStarted(_ question: String) async {
        guard !startedQuestions.contains(question) else { return }
        await withCheckedContinuation { continuation in
            startWaiters[question, default: []].append(continuation)
        }
    }

    func waitUntilFinished(_ question: String) async {
        guard !finishedQuestions.contains(question) else { return }
        await withCheckedContinuation { continuation in
            finishWaiters[question, default: []].append(continuation)
        }
    }

    func release(_ question: String) {
        blockedQuestions.remove(question)
        releaseWaiters.removeValue(forKey: question)?.resume()
    }
}

private struct ControlledAnswerProvider: HelixAnswerProvider {
    let kind: LlmProviderKind = .openAI
    let model = "controlled-test-provider"
    let controller: ControlledAnswerRecorder

    func streamAnswer(for request: AnswerRequest) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    continuation.yield(try await controller.answer(for: request.question))
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}

private actor ControlledFirstQuestionClassifierController {
    private(set) var invocationCount = 0
    private var firstStartedWaiters: [CheckedContinuation<Void, Never>] = []
    private var firstRelease: CheckedContinuation<Void, Never>?

    func classify(_ transcript: String) async -> [QuestionCandidate] {
        invocationCount += 1
        if invocationCount == 1 {
            firstStartedWaiters.forEach { $0.resume() }
            firstStartedWaiters.removeAll()
            await withCheckedContinuation { continuation in
                firstRelease = continuation
            }
        }
        return [QuestionCandidate(text: transcript, confidence: 0.92)]
    }

    func waitUntilFirstStarted() async {
        guard invocationCount == 0 else { return }
        await withCheckedContinuation { continuation in
            firstStartedWaiters.append(continuation)
        }
    }

    func releaseFirst() {
        firstRelease?.resume()
        firstRelease = nil
    }
}

private struct ControlledFirstQuestionClassifier: QuestionClassifying {
    let controller: ControlledFirstQuestionClassifierController

    var sourceDescription: String { "controlled-order-test" }

    func detectQuestions(
        in transcript: String,
        sensitivity: QuestionDetectionSensitivity
    ) async -> [QuestionCandidate] {
        await controller.classify(transcript)
    }
}

private actor IndexedBlockingQuestionClassifierController {
    private let blockedInvocations: Set<Int>
    private(set) var invocationCount = 0
    private var startedWaiters: [Int: [CheckedContinuation<Void, Never>]] = [:]
    private var releases: [Int: CheckedContinuation<Void, Never>] = [:]

    init(blockedInvocations: Set<Int>) {
        self.blockedInvocations = blockedInvocations
    }

    func classify(_ transcript: String) async -> [QuestionCandidate] {
        invocationCount += 1
        let invocation = invocationCount
        startedWaiters.removeValue(forKey: invocation)?.forEach { $0.resume() }
        if blockedInvocations.contains(invocation) {
            await withCheckedContinuation { continuation in
                releases[invocation] = continuation
            }
        }
        return [QuestionCandidate(text: transcript, confidence: 0.92)]
    }

    func waitUntilStarted(invocation: Int) async {
        guard invocationCount < invocation else { return }
        await withCheckedContinuation { continuation in
            startedWaiters[invocation, default: []].append(continuation)
        }
    }

    func release(invocation: Int) {
        releases.removeValue(forKey: invocation)?.resume()
    }
}

private struct IndexedBlockingQuestionClassifier: QuestionClassifying {
    let controller: IndexedBlockingQuestionClassifierController

    var sourceDescription: String { "indexed-blocking-test" }

    func detectQuestions(
        in transcript: String,
        sensitivity: QuestionDetectionSensitivity
    ) async -> [QuestionCandidate] {
        await controller.classify(transcript)
    }
}

private actor ControlledAudioFileTranscriber: AudioFileTranscriber {
    private let transcript: String
    private var didStart = false
    private var releaseContinuation: CheckedContinuation<Void, Never>?
    private var startContinuations: [CheckedContinuation<Void, Never>] = []

    init(transcript: String) {
        self.transcript = transcript
    }

    func transcribeAudioFile(
        at url: URL,
        backend: TranscriptionBackend,
        model: String
    ) async throws -> TranscriptSegment {
        didStart = true
        startContinuations.forEach { $0.resume() }
        startContinuations.removeAll()
        await withCheckedContinuation { continuation in
            releaseContinuation = continuation
        }
        return TranscriptSegment(text: transcript, isFinal: true, finalizedAt: Date())
    }

    func waitUntilStarted() async {
        guard !didStart else { return }
        await withCheckedContinuation { continuation in
            startContinuations.append(continuation)
        }
    }

    func release() {
        releaseContinuation?.resume()
        releaseContinuation = nil
    }
}

private struct StubLiveQuestionClassifier: QuestionDetectionLiveClassifying {
    enum StubError: Error {
        case expectedFailure
    }

    var result: [QuestionCandidate] = []
    var error: StubError?

    init(result: [QuestionCandidate] = [], error: StubError? = nil) {
        self.result = result
        self.error = error
    }

    func classify(_ prompt: QuestionDetectionPrompt) async throws -> [QuestionCandidate] {
        if let error { throw error }
        return result
    }
}

private actor LiveClassifierInvocationRecorder {
    private(set) var invocationCount = 0

    func recordInvocation() {
        invocationCount += 1
    }
}

private struct RecordingLiveQuestionClassifier: QuestionDetectionLiveClassifying {
    let recorder: LiveClassifierInvocationRecorder

    func classify(_ prompt: QuestionDetectionPrompt) async throws -> [QuestionCandidate] {
        await recorder.recordInvocation()
        return []
    }
}

private struct FixedTextAnswerProvider: HelixAnswerProvider {
    let kind: LlmProviderKind = .openAI
    let model = "fixed-text-provider"
    let text: String
    var requestRecorder: AnswerRequestRecorder?

    func streamAnswer(for request: AnswerRequest) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                await requestRecorder?.record(request.question)
                continuation.yield(text)
                continuation.finish()
            }
        }
    }
}

private actor AnswerRequestRecorder {
    private(set) var questions: [String] = []

    func record(_ question: String) {
        questions.append(question)
    }
}

private struct ModelTaggedAnswerProvider: HelixAnswerProvider {
    let kind: LlmProviderKind = .openAI
    let model: String

    func streamAnswer(for request: AnswerRequest) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let prefix = request.activeSkill.value.hasSuffix("-deeper") ? "Deep" : "Automatic"
            continuation.yield("\(prefix) response from \(model)")
            continuation.finish()
        }
    }
}
