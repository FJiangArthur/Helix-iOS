import Foundation
import XCTest
import HelixConversation
import HelixCore
import HelixG1
import HelixPersistence
import HelixRuntime
@testable import Even_Companion

private actor RecordingG1PacketWriter: G1PacketWriter {
    private(set) var writes: [(bytes: [UInt8], side: G1Side)] = []
    private var onWrite: (@Sendable ([UInt8], G1Side) -> Void)?

    func setOnWrite(_ handler: @escaping @Sendable ([UInt8], G1Side) -> Void) {
        onWrite = handler
    }

    func write(_ bytes: [UInt8], to side: G1Side) async {
        writes.append((bytes, side))
        onWrite?(bytes, side)
    }
}

private actor RunnerSourceOnlyUndoFailureStore: KnowledgeLibraryStore {
    private let previousItem: NativeKnowledgeItem
    private let currentItem: NativeKnowledgeItem

    init(content: String) {
        let id = UUID()
        previousItem = NativeKnowledgeItem(
            id: id,
            kind: .memory,
            text: content,
            source: KnowledgeMemorySource.automaticAnswer(category: "Fact", quality: .fast),
            createdAt: Date(timeIntervalSince1970: 1)
        )
        currentItem = NativeKnowledgeItem(
            id: id,
            kind: .memory,
            text: content,
            source: KnowledgeMemorySource.automaticAnswer(category: "Fact", quality: .smart),
            createdAt: Date(timeIntervalSince1970: 2)
        )
    }

    func snapshot() async -> NativeKnowledgeSnapshot {
        NativeKnowledgeSnapshot(memories: [currentItem])
    }

    func saveProject(_ project: NativeKnowledgeProject) async {}
    func setActiveProject(id: UUID?) async {}
    func ingestDocument(title: String, text: String, sourceURL: URL?) async {}
    func addFact(_ text: String, source: String) async {}
    func addMemory(_ text: String, source: String) async {}
    func addMemoryIfAbsent(
        _ text: String,
        source: String,
        deduplication: KnowledgeMemoryDeduplication
    ) async -> KnowledgeMemoryUpsertResult? {
        KnowledgeMemoryUpsertResult(
            item: currentItem,
            wasInserted: false,
            previousItem: previousItem
        )
    }
    func undoMemoryUpsert(_ result: KnowledgeMemoryUpsertResult) async {}
    func removeMemory(id: UUID) async {}
    func addTodo(_ title: String) async {}
    func completeTodo(id: UUID, isComplete: Bool) async {}
}

final class RunnerTests: XCTestCase {

    @MainActor
    func testAssistantConversationStateAppendsTurnsInsteadOfOverwriting() {
        let state = AssistantConversationState()

        state.appendManualQuestion("What is RAG?")
        state.ingestAnswer(
            "Retrieval-augmented generation grounds an answer in retrieved context.",
            providerName: "Test",
            modelName: "deterministic",
            isFinal: true
        )
        state.appendManualQuestion("Why use it?")
        state.ingestAnswer(
            "It improves factual grounding for project-specific questions.",
            providerName: "Test",
            modelName: "deterministic",
            isFinal: true
        )

        XCTAssertEqual(
            state.messages.map(\.text),
            [
                "What is RAG?",
                "Retrieval-augmented generation grounds an answer in retrieved context.",
                "Why use it?",
                "It improves factual grounding for project-specific questions."
            ]
        )
        XCTAssertEqual(state.messages.map(\.kind), [.question, .answer, .question, .answer])
        XCTAssertEqual(Set(state.messages.map(\.turnID)).count, 2)
    }

    @MainActor
    func testAssistantConversationStateMergesStreamingAnswerChunks() {
        let state = AssistantConversationState()
        state.appendManualQuestion("Explain attention.")

        state.ingestAnswer(
            "Attention lets",
            providerName: "Test",
            modelName: "stream",
            isFinal: false
        )
        state.ingestAnswer(
            "Attention lets a model weigh relevant tokens.",
            providerName: "Test",
            modelName: "stream",
            isFinal: true
        )

        XCTAssertEqual(state.messages.filter { $0.kind == .answer }.count, 1)
        XCTAssertEqual(state.messages.last?.text, "Attention lets a model weigh relevant tokens.")
        XCTAssertTrue(state.messages.last?.isFinal == true)
    }

    @MainActor
    func testDeeperAnswerAppendsSeparateBubbleWithItsActualModel() {
        let state = AssistantConversationState()
        state.appendManualQuestion("Explain retrieval grounding.")
        state.ingestAnswer(
            "Grounding connects an answer to retrieved evidence.",
            providerName: "OpenAI",
            modelName: "fast-light-model",
            isFinal: true
        )

        let deepAnswerID = state.ingestAnswer(
            "Grounding connects an answer to retrieved evidence.",
            providerName: "OpenAI",
            modelName: "reasoning-smart-model",
            isFinal: true,
            answerDepth: .deeper,
            forceNew: true
        )!
        state.markHUDSendRequested(deepAnswerID)

        let answers = state.messages.filter { $0.kind == .answer }
        XCTAssertEqual(answers.count, 2)
        XCTAssertEqual(answers.map(\.modelName), ["fast-light-model", "reasoning-smart-model"])
        XCTAssertTrue(answers[0].canRequestDeeperAnswer)
        XCTAssertFalse(answers[1].canRequestDeeperAnswer)
        XCTAssertEqual(answers.last?.hudState, .sending)
    }

    @MainActor
    func testAssistantHUDDeliveryPreservesSingleLensSideAndLabel() throws {
        let state = AssistantConversationState()
        state.appendManualQuestion("Where should this answer appear?")
        let answerID = try XCTUnwrap(state.ingestAnswer(
            "On the connected G1 lens.",
            providerName: "Test",
            modelName: "deterministic",
            isFinal: true
        ))

        state.markHUDDelivery(answerID, result: .deliveredToLeftLens)
        XCTAssertEqual(state.messages.last?.hudState, .deliveredToLeftLens)
        XCTAssertEqual(
            state.messages.last?.hudState.actionLabel,
            "Delivered to left lens only"
        )

        state.markHUDDelivery(answerID, result: .deliveredToRightLens)
        XCTAssertEqual(state.messages.last?.hudState, .deliveredToRightLens)
        XCTAssertEqual(
            state.messages.last?.hudState.actionLabel,
            "Delivered to right lens only"
        )
    }

    func testDuplicateNativeQuestionResultIsNotDisplayable() {
        let question = QuestionCandidate(text: "What is RAG?", confidence: 0.95)
        let turn = ConversationTurnResult(
            segment: TranscriptSegment(text: question.text, isFinal: true),
            question: question,
            answer: nil,
            passiveReminder: nil,
            questionResults: [
                ConversationQuestionResult(
                    question: question,
                    answer: nil,
                    suppressionReason: "Duplicate question suppressed."
                )
            ]
        )

        XCTAssertTrue(AssistantLiveOutcomePresentationPolicy.suppressesEntireTurn(turn))
        XCTAssertTrue(
            AssistantLiveOutcomePresentationPolicy.displayableQuestionResults(in: turn).isEmpty
        )
    }

    @MainActor
    func testDelayedDeeperAnswerStaysWithItsOriginalTurnAfterAnotherQuestionArrives() {
        let state = AssistantConversationState()
        state.appendManualQuestion("Question one?")
        let firstAnswerID = state.ingestAnswer(
            "Fast answer one.",
            providerName: "Test",
            modelName: "light",
            isFinal: true
        )!
        let firstTurnID = state.messages.first(where: { $0.id == firstAnswerID })!.turnID

        // This is the interleaving that happens while the deeper provider for
        // question one is still awaiting its response.
        state.appendManualQuestion("Question two?")
        let secondAnswerID = state.ingestAnswer(
            "Fast answer two.",
            providerName: "Test",
            modelName: "light",
            isFinal: true
        )!
        let secondTurnID = state.messages.first(where: { $0.id == secondAnswerID })!.turnID

        let deepAnswerID = state.ingestAnswer(
            "Deeper answer one.",
            providerName: "Test",
            modelName: "smart",
            isFinal: true,
            forceNew: true,
            turnID: firstTurnID
        )!

        XCTAssertEqual(state.messages.first(where: { $0.id == deepAnswerID })?.turnID, firstTurnID)
        XCTAssertNotEqual(firstTurnID, secondTurnID)
        XCTAssertEqual(
            state.messages.filter { $0.turnID == firstTurnID }.map(\.text),
            ["Question one?", "Fast answer one.", "Deeper answer one."]
        )
        XCTAssertEqual(
            state.messages.filter { $0.turnID == secondTurnID }.map(\.text),
            ["Question two?", "Fast answer two."]
        )
    }

    @MainActor
    func testMultiAnswerOutcomeCreatesOneOrderedHUDRequestContainingEveryAnswer() {
        let request = HelixNativeBridge.makeLiveTranscriptHUDRequest(
            sequence: 42,
            answers: ["First answer.", "Second answer."]
        )

        XCTAssertEqual(request?.sequence, 42)
        XCTAssertEqual(request?.answerCount, 2)
        XCTAssertEqual(request?.text, "First answer.\n\nSecond answer.")
    }

    @MainActor
    func testPartialSuccessBatchKeepsQuestionFailureAdjacentAndLaterAnswerVisible() {
        let state = AssistantConversationState()
        let failedQuestionID = state.ingestDetectedQuestion("What failed?")!
        let failedTurnID = state.messages.first(where: { $0.id == failedQuestionID })!.turnID
        state.ingestQuestionFailure(
            questionID: failedQuestionID,
            question: "What failed?",
            reason: "Provider timed out."
        )

        state.ingestDetectedQuestion("What succeeded?")
        state.ingestAnswer(
            "The second answer completed.",
            providerName: "Test",
            modelName: "light",
            isFinal: true
        )

        XCTAssertEqual(
            state.messages.map(\.text),
            [
                "What failed?",
                "Couldn’t answer \u{201c}What failed?\u{201d}: Provider timed out.",
                "What succeeded?",
                "The second answer completed."
            ]
        )
        XCTAssertEqual(state.messages[1].kind, .error)
        XCTAssertEqual(state.messages[1].turnID, failedTurnID)
        XCTAssertEqual(state.messages.last?.kind, .answer)
    }

    @MainActor
    func testStartingNewConversationClearsMessagesAndAllowsRepeatedQuestion() {
        let state = AssistantConversationState()
        state.appendManualQuestion("What is RAG?")
        state.ingestAnswer(
            "Retrieval-augmented generation grounds an answer in retrieved context.",
            providerName: "Test",
            modelName: "deterministic",
            isFinal: true
        )

        state.startNewConversation()

        XCTAssertTrue(state.messages.isEmpty)
        state.appendManualQuestion("What is RAG?")
        XCTAssertEqual(state.messages.map(\.text), ["What is RAG?"])
    }

    @MainActor
    func testLateTypedAnswerCannotRecreateItsClearedTurn() {
        let state = AssistantConversationState()
        let questionID = state.appendManualQuestion("What belongs to the old conversation?")!
        let oldTurnID = state.messages.first(where: { $0.id == questionID })!.turnID

        state.startNewConversation()
        let answerID = state.ingestAnswer(
            "This answer arrived too late.",
            providerName: "Test",
            modelName: "light",
            isFinal: true,
            turnID: oldTurnID
        )

        XCTAssertNil(answerID)
        XCTAssertTrue(state.messages.isEmpty)
    }

    @MainActor
    func testVoiceQuestionKeepsUnknownSpeakerUntilUserNamesThem() {
        let state = AssistantConversationState()
        state.ingestTranscript("Can we ship this on Friday?")
        state.ingestDetectedQuestion("Can we ship this on Friday?")

        XCTAssertEqual(state.messages.count, 1, "The detected question should promote the transcript, not duplicate it")
        XCTAssertEqual(state.messages[0].kind, .question)
        XCTAssertEqual(state.messages[0].authorName, "Unknown speaker")
        XCTAssertTrue(state.messages[0].isAuthorEditable)

        state.renameSpeaker(messageID: state.messages[0].id, to: "Sam")

        XCTAssertEqual(state.messages[0].authorName, "Sam")
        state.enrichSpeaker(
            messageID: state.messages[0].id,
            with: .sourceProvided("Speaker 0")
        )
        XCTAssertEqual(
            state.messages[0].authorName,
            "Sam",
            "A late diarization label must not overwrite a user-supplied name"
        )
    }

    @MainActor
    func testMarkAsMeMovesParticipantTurnToUserRoleAndAlignmentSemantics() {
        let state = AssistantConversationState()
        let transcriptID = state.ingestTranscript("Should I own this follow-up?")!
        state.ingestDetectedQuestion("Should I own this follow-up?")

        state.renameSpeaker(messageID: transcriptID, to: "You")

        let participantMessages = state.messages.filter { $0.turnID == state.messages[0].turnID }
        XCTAssertEqual(participantMessages.first?.authorName, "You")
        XCTAssertEqual(participantMessages.first?.authorRole, .user)
        XCTAssertEqual(participantMessages.first?.speakerAttribution, .userNamed("You"))
    }

    @MainActor
    func testSourceProvidedAndEstimatedSpeakerLabelsStayHonest() {
        let sourceState = AssistantConversationState()
        sourceState.ingestTranscript(
            "Can we ship this on Friday?",
            speakerAttribution: .sourceProvided("speaker_0")
        )
        sourceState.ingestDetectedQuestion(
            "Can we ship this on Friday?",
            speakerAttribution: .sourceProvided("speaker_0")
        )

        XCTAssertEqual(sourceState.messages.count, 1)
        XCTAssertEqual(sourceState.messages[0].authorName, "Speaker 0")
        XCTAssertTrue(sourceState.messages[0].isAuthorEditable)

        let estimatedState = AssistantConversationState()
        estimatedState.ingestTranscript(
            "I think the room is getting louder.",
            speakerAttribution: .localEstimate("Speaker 2")
        )

        XCTAssertEqual(estimatedState.messages[0].authorName, "Estimated speaker 2")
        XCTAssertTrue(estimatedState.messages[0].isAuthorEditable)
    }

    @MainActor
    func testLateDiarizationPromotesExistingBubbleWithoutReplayingAnswer() {
        let state = AssistantConversationState()
        let transcriptID = state.ingestTranscript("Can we ship this on Friday?")!
        state.ingestDetectedQuestion("Can we ship this on Friday?")
        state.ingestAnswer(
            "The decision should follow the release checklist and test evidence.",
            providerName: "OpenAI",
            modelName: "fast-light-model",
            isFinal: true
        )

        state.enrichSpeaker(
            messageID: transcriptID,
            with: .sourceProvided("Speaker 1")
        )

        XCTAssertEqual(state.messages.count, 2)
        XCTAssertEqual(state.messages.filter { $0.kind == .question }.count, 1)
        XCTAssertEqual(state.messages.filter { $0.kind == .answer }.count, 1)
        XCTAssertEqual(state.messages.first?.authorName, "Speaker 1")
    }

    func testAutomaticNoteCaptureCreatesStructuredContentAndDeduplicates() {
        let draft = AssistantNoteCapturePolicy.automaticDraft(
            question: "What is RAG?",
            answer: "Retrieval-augmented generation grounds an answer in retrieved context."
        )

        XCTAssertEqual(
            draft?.content,
            "Question: What is RAG?\n\nAnswer: Retrieval-augmented generation grounds an answer in retrieved context."
        )
        XCTAssertEqual(draft?.category, .fact)
        XCTAssertFalse(
            AssistantNoteCapturePolicy.isDuplicate(
                draft?.content ?? "",
                existingContents: [" question:  WHAT IS RAG? \n answer: A different trustworthy model paraphrase. "]
            ),
            "Manual/full-content dedupe must not infer automatic-answer provenance from text shape"
        )
        XCTAssertTrue(
            AssistantNoteCapturePolicy.isDuplicate(
                draft?.content ?? "",
                existingContents: [" question:  WHAT IS RAG? \n answer: A different trustworthy model paraphrase. "],
                deduplication: .automaticAnswer(quality: .fast)
            )
        )
    }

    func testAutomaticNoteCaptureRejectsEmptyAndFailureLikeAnswers() {
        XCTAssertNil(AssistantNoteCapturePolicy.automaticDraft(question: "Anything?", answer: ""))
        XCTAssertNil(
            AssistantNoteCapturePolicy.automaticDraft(
                question: "Anything?",
                answer: "Error: API key missing."
            )
        )
        XCTAssertNil(
            AssistantNoteCapturePolicy.automaticDraft(
                question: "Thoughts?",
                answer: "Maybe this could be fine, but I am not sure."
            )
        )
        XCTAssertNil(
            AssistantNoteCapturePolicy.automaticDraft(
                question: "Should I choose option A?",
                answer: "Option A has lower cost while option B has more features."
            ),
            "An advice-shaped question must not classify a neutral answer as an action item"
        )
        XCTAssertNil(
            AssistantNoteCapturePolicy.automaticDraft(
                question: "How should I improve this draft?",
                answer: "You should shorten the introduction and use a clearer opening example."
            ),
            "Ordinary assistant advice is not an explicit user action item"
        )
        XCTAssertNil(
            AssistantNoteCapturePolicy.automaticDraft(
                question: "Wh",
                answer: "We need to clarify because the question was cut off; please repeat it."
            ),
            "A cut-off device transcript must never become an automatic action item"
        )
        XCTAssertNil(
            AssistantNoteCapturePolicy.automaticDraft(
                question: "What should we do next?",
                answer: "Could you confirm which environment currently owns this deployment?"
            ),
            "A clarification question from the model must never become automatic Knowledge"
        )
    }

    func testAutomaticNoteCaptureRejectsSensitiveCredentials() {
        for sensitiveAnswer in [
            "Your password is hunter2 and it will unlock the account.",
            "The API key is sk-test-1234567890 for this environment.",
            "Use card number 4111111111111111 with CVV 123 for checkout.",
            "Your access token is access_1234567890abcdef for this environment.",
            "The auth token is auth_1234567890abcdef for this environment.",
            "Authorization: Bearer bearer_1234567890abcdef grants account access.",
            "The OAuth token is oauth_1234567890abcdef for this integration.",
            "The OAuth2 token is oauth2_1234567890abcdef for this integration.",
            "The refresh token is refresh_1234567890abcdef for this session.",
            "The refreshToken is refresh_abcdef1234567890 for this session.",
            "The session token is session_1234567890abcdef for this browser.",
            "Your recovery codes are 1042-8391 and 5920-1746 for account access.",
            "The signed credential is eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjM0NTY3ODkwIn0.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c."
        ] {
            XCTAssertNil(
                AssistantNoteCapturePolicy.automaticDraft(
                    question: "What should I remember?",
                    answer: sensitiveAnswer
                ),
                "Sensitive content must never be captured automatically: \(sensitiveAnswer)"
            )
        }

        for sensitiveStatement in [
            "The project access token is access_1234567890abcdef.",
            "The project recovery code is 1042-8391-5920-1746.",
            "The project credential is eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjM0NTY3ODkwIn0.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c."
        ] {
            XCTAssertNil(
                AssistantNoteCapturePolicy.automaticDraft(statement: sensitiveStatement),
                "Sensitive transcript content must never be captured automatically: \(sensitiveStatement)"
            )
        }
    }

    func testAutomaticNoteCaptureAllowsBenignModelTokenDiscussion() {
        let answerDraft = AssistantNoteCapturePolicy.automaticDraft(
            question: "What did we decide about the model context window?",
            answer: "We decided the model token limit will remain at 128,000 tokens for this deployment."
        )
        let statementDraft = AssistantNoteCapturePolicy.automaticDraft(
            statement: "The project token budget is 128,000 tokens."
        )

        XCTAssertEqual(answerDraft?.category, .decision)
        XCTAssertEqual(statementDraft?.category, .fact)
    }

    func testAutomaticNoteCaptureRejectsDeterministicModelProvenanceOnlyForAutomation() {
        XCTAssertFalse(
            AssistantNoteCapturePolicy.permitsAutomaticCapture(
                answerModel: "deterministic-native"
            )
        )
        XCTAssertFalse(
            AssistantNoteCapturePolicy.permitsAutomaticCapture(
                answerModel: "Deterministic UI Fixture"
            )
        )
        XCTAssertFalse(AssistantNoteCapturePolicy.permitsAutomaticCapture(answerModel: nil))
        XCTAssertTrue(
            AssistantNoteCapturePolicy.permitsAutomaticCapture(answerModel: "gpt-4.1-mini")
        )
    }

    func testAutomaticNoteCaptureClassifiesDecisionsAndActionItems() {
        let decision = AssistantNoteCapturePolicy.automaticDraft(
            question: "Which backend are we using?",
            answer: "We decided to use Apple Cloud for continuous transcription."
        )
        let action = AssistantNoteCapturePolicy.automaticDraft(
            question: "What happens next?",
            answer: "The next step is to validate the answer on G1 hardware."
        )

        XCTAssertEqual(decision?.category, .decision)
        XCTAssertEqual(action?.category, .actionItem)
    }

    func testAutomaticTranscriptCaptureClassifiesUsefulStatementsOnly() {
        XCTAssertEqual(
            AssistantNoteCapturePolicy.automaticDraft(
                statement: "We decided to ship the beta on Friday."
            )?.category,
            .decision
        )
        XCTAssertEqual(
            AssistantNoteCapturePolicy.automaticDraft(
                statement: "Action item: Art needs to send the release notes."
            )?.category,
            .actionItem
        )
        XCTAssertEqual(
            AssistantNoteCapturePolicy.automaticDraft(
                statement: "The launch meeting is at 10 AM."
            )?.category,
            .fact
        )
        XCTAssertNil(
            AssistantNoteCapturePolicy.automaticDraft(statement: "My deadline is tomorrow؟")
        )
        XCTAssertNil(
            AssistantNoteCapturePolicy.automaticDraft(statement: "My API key is sk-secret-value.")
        )
        XCTAssertNil(
            AssistantNoteCapturePolicy.automaticDraft(statement: "The weather is nice today.")
        )

        XCTAssertEqual(
            AssistantNoteCapturePolicy.automaticDrafts(
                statement: "My deadline is tomorrow؟ We decided to ship Friday."
            ),
            [AssistantNoteDraft(content: "We decided to ship Friday.", category: .decision)]
        )
        XCTAssertTrue(
            AssistantNoteCapturePolicy.automaticDrafts(
                statement: "My deadline is tomorrow?”"
            ).isEmpty,
            "Quoted questions must not pass direct transcript capture"
        )
        XCTAssertEqual(
            AssistantNoteCapturePolicy.automaticDrafts(
                statement: "My email is art@example.com."
            ).map(\.content),
            ["My email is art@example.com."]
        )
        XCTAssertEqual(
            AssistantNoteCapturePolicy.automaticDrafts(
                statement: "My meeting is with Dr. Smith."
            ).map(\.content),
            ["My meeting is with Dr. Smith."]
        )
    }

    @MainActor
    func testFinalizedDecisionTranscriptAutoSavesWithUndoOwnership() async {
        let knowledge = NativeKnowledgeLibraryState()
        let state = AssistantConversationState()
        let messageID = state.ingestTranscript("We decided to ship the beta on Friday.")!

        await AssistantNoteCaptureCoordinator.scheduleAutomaticTranscriptCapture(
            messageID: messageID,
            conversation: state,
            knowledgeLibrary: knowledge,
            graceNanoseconds: 0
        )

        XCTAssertEqual(knowledge.snapshot.memories.map(\.text), ["We decided to ship the beta on Friday."])
        XCTAssertEqual(state.messages.first?.noteState, .saved)
        XCTAssertTrue(state.messages.first?.ownsKnowledgeItem == true)

        await AssistantNoteCaptureCoordinator.removeFromKnowledge(
            answerID: messageID,
            conversation: state,
            knowledgeLibrary: knowledge
        )
        XCTAssertTrue(knowledge.snapshot.memories.isEmpty)
    }

    @MainActor
    func testQuestionDetectionSensitivityUpdatesRuntimeAndPersistentSettings() async {
        let runtime = HelixRuntimeDependencies()

        await runtime.setQuestionDetectionSensitivity(.sensitive)

        XCTAssertEqual(runtime.settings.questionDetectionSensitivity, .sensitive)
        let persisted = await runtime.settingsManager.settings()
        XCTAssertEqual(persisted.questionDetectionSensitivity, .sensitive)
    }

    @MainActor
    func testPendingAutomaticNoteCanBeUndoneBeforePersistence() {
        let state = AssistantConversationState()
        state.appendManualQuestion("What is RAG?")
        let answerID = state.ingestAnswer(
            "Retrieval-augmented generation grounds an answer in retrieved context.",
            providerName: "Test",
            modelName: "gpt-4.1-mini",
            isFinal: true
        )!

        XCTAssertTrue(state.beginAutomaticNoteGracePeriod(answerID))
        XCTAssertTrue(state.isAutomaticNotePending(answerID))

        state.cancelPendingAutomaticNote(answerID)

        XCTAssertFalse(state.isAutomaticNotePending(answerID))
        XCTAssertFalse(
            state.beginAutomaticNoteGracePeriod(answerID),
            "Undo should suppress another automatic save for the same answer"
        )
    }

    @MainActor
    func testAutomaticNoteCapturePersistsOnceInInternalKnowledge() async {
        let knowledge = NativeKnowledgeLibraryState()

        for _ in 0..<2 {
            let state = AssistantConversationState()
            state.appendManualQuestion("What is RAG?")
            let answerID = state.ingestAnswer(
                "Retrieval-augmented generation grounds an answer in retrieved context.",
                providerName: "Test",
                modelName: "gpt-4.1-mini",
                isFinal: true
            )!

            await AssistantNoteCaptureCoordinator.scheduleAutomaticCapture(
                answerID: answerID,
                conversation: state,
                knowledgeLibrary: knowledge,
                graceNanoseconds: 0
            )
        }

        XCTAssertEqual(knowledge.snapshot.memories.count, 1)
        XCTAssertEqual(
            knowledge.snapshot.memories.first?.source,
            KnowledgeMemorySource.automaticAnswer(category: "Fact")
        )
    }

    @MainActor
    func testDeterministicAnswerRequiresExplicitKnowledgeSave() async {
        let knowledge = NativeKnowledgeLibraryState()
        let state = AssistantConversationState()
        state.appendManualQuestion("What is RAG?")
        let answerID = state.ingestAnswer(
            "Retrieval-augmented generation grounds an answer in retrieved context.",
            providerName: "OpenAI",
            modelName: "deterministic-native",
            isFinal: true
        )!

        await AssistantNoteCaptureCoordinator.scheduleAutomaticCapture(
            answerID: answerID,
            conversation: state,
            knowledgeLibrary: knowledge,
            graceNanoseconds: 0
        )

        XCTAssertTrue(knowledge.snapshot.memories.isEmpty)
        XCTAssertEqual(state.messages.last?.noteState, .ready)

        await AssistantNoteCaptureCoordinator.captureImmediately(
            answerID: answerID,
            conversation: state,
            knowledgeLibrary: knowledge
        )

        XCTAssertEqual(knowledge.snapshot.memories.count, 1)
        XCTAssertEqual(state.messages.last?.noteState, .saved)
    }

    @MainActor
    func testConcurrentAutomaticCapturesShareOneOwnedReceipt() async {
        let knowledge = NativeKnowledgeLibraryState()
        let firstState = AssistantConversationState()
        let secondState = AssistantConversationState()
        firstState.appendManualQuestion("What is RAG?")
        secondState.appendManualQuestion("What is RAG?")
        let answer = "Retrieval-augmented generation grounds an answer in retrieved context."
        let firstAnswerID = firstState.ingestAnswer(
            answer,
            providerName: "Test",
            modelName: "gpt-4.1-mini",
            isFinal: true
        )!
        let secondAnswerID = secondState.ingestAnswer(
            answer,
            providerName: "Test",
            modelName: "gpt-4.1-mini",
            isFinal: true
        )!

        let firstTask = Task { @MainActor in
            await AssistantNoteCaptureCoordinator.scheduleAutomaticCapture(
                answerID: firstAnswerID,
                conversation: firstState,
                knowledgeLibrary: knowledge,
                graceNanoseconds: 0
            )
        }
        let secondTask = Task { @MainActor in
            await AssistantNoteCaptureCoordinator.scheduleAutomaticCapture(
                answerID: secondAnswerID,
                conversation: secondState,
                knowledgeLibrary: knowledge,
                graceNanoseconds: 0
            )
        }
        _ = await (firstTask.value, secondTask.value)

        XCTAssertEqual(knowledge.snapshot.memories.count, 1)
        XCTAssertEqual(
            [firstState.messages.last?.ownsKnowledgeItem, secondState.messages.last?.ownsKnowledgeItem]
                .compactMap { $0 }
                .filter { $0 }
                .count,
            1
        )
    }

    @MainActor
    func testManualQuestionAnswerDoesNotBlockAutomaticCapture() async {
        let knowledge = NativeKnowledgeLibraryState()
        let question = "What is RAG?"
        let answer = "Retrieval-augmented generation grounds an answer in retrieved context."
        let draft = AssistantNoteCapturePolicy.automaticDraft(question: question, answer: answer)!
        await knowledge.addMemory(draft.content, source: "Pre-existing")
        let preexistingID = knowledge.snapshot.memories.first!.id

        let state = AssistantConversationState()
        state.appendManualQuestion(question)
        let answerID = state.ingestAnswer(
            answer,
            providerName: "Test",
            modelName: "gpt-4.1-mini",
            isFinal: true
        )!
        await AssistantNoteCaptureCoordinator.scheduleAutomaticCapture(
            answerID: answerID,
            conversation: state,
            knowledgeLibrary: knowledge,
            graceNanoseconds: 0
        )

        XCTAssertNotEqual(state.messages.last?.knowledgeItemID, preexistingID)
        XCTAssertTrue(state.messages.last?.ownsKnowledgeItem == true)
        XCTAssertEqual(knowledge.snapshot.memories.count, 2)
        XCTAssertTrue(knowledge.snapshot.memories.contains(where: { $0.id == preexistingID }))
    }

    @MainActor
    func testManualExplicitAnswerSaveUsesFullContentSemantics() async {
        let knowledge = NativeKnowledgeLibraryState()
        let question = "What is RAG?"
        let firstState = AssistantConversationState()
        firstState.appendManualQuestion(question)
        let firstID = firstState.ingestAnswer(
            "Retrieval-augmented generation grounds an answer in retrieved context.",
            providerName: "Test",
            modelName: "gpt-4.1-mini",
            isFinal: true
        )!
        await AssistantNoteCaptureCoordinator.scheduleAutomaticCapture(
            answerID: firstID,
            conversation: firstState,
            knowledgeLibrary: knowledge,
            graceNanoseconds: 0
        )

        let manualState = AssistantConversationState()
        manualState.appendManualQuestion(question)
        let manualID = manualState.ingestAnswer(
            "RAG improves factual relevance by adding retrieved evidence to generation.",
            providerName: "OpenAI",
            modelName: "deterministic-native",
            isFinal: true
        )!
        await AssistantNoteCaptureCoordinator.captureImmediately(
            answerID: manualID,
            conversation: manualState,
            knowledgeLibrary: knowledge
        )

        XCTAssertEqual(knowledge.snapshot.memories.count, 2)
        XCTAssertEqual(
            knowledge.snapshot.memories.first(where: { $0.id == manualState.messages.last?.knowledgeItemID })?.text,
            "Question: \(question)\n\nAnswer: RAG improves factual relevance by adding retrieved evidence to generation."
        )
        XCTAssertFalse(
            KnowledgeMemorySource.isAutomaticAnswer(
                knowledge.snapshot.memories.first(where: { $0.id == manualState.messages.last?.knowledgeItemID })?.source ?? ""
            )
        )
    }

    @MainActor
    func testRemovingOwningFastAnswerResetsDeeperAnswerAndAllowsExactResave() async throws {
        let knowledge = NativeKnowledgeLibraryState()
        let state = AssistantConversationState()
        let questionID = try XCTUnwrap(state.appendManualQuestion("What is RAG?"))
        let turnID = try XCTUnwrap(state.messages.first(where: { $0.id == questionID })?.turnID)
        let fastID = try XCTUnwrap(state.ingestAnswer(
            "Retrieval-augmented generation grounds an answer in retrieved context.",
            providerName: "OpenAI",
            modelName: "gpt-4.1-mini",
            isFinal: true
        ))
        await AssistantNoteCaptureCoordinator.scheduleAutomaticCapture(
            answerID: fastID,
            conversation: state,
            knowledgeLibrary: knowledge,
            graceNanoseconds: 0
        )
        let deeperText = "RAG improves factual relevance by adding retrieved evidence to the model's generation step."
        let deeperID = try XCTUnwrap(state.ingestAnswer(
            deeperText,
            providerName: "OpenAI",
            modelName: "gpt-4.1",
            isFinal: true,
            answerDepth: .deeper,
            forceNew: true,
            turnID: turnID
        ))
        await AssistantNoteCaptureCoordinator.scheduleAutomaticCapture(
            answerID: deeperID,
            conversation: state,
            knowledgeLibrary: knowledge,
            graceNanoseconds: 0
        )

        let fast = try XCTUnwrap(state.messages.first(where: { $0.id == fastID }))
        let deeper = try XCTUnwrap(state.messages.first(where: { $0.id == deeperID }))
        XCTAssertEqual(fast.knowledgeItemID, deeper.knowledgeItemID)
        XCTAssertTrue(fast.ownsKnowledgeItem)
        XCTAssertTrue(deeper.ownsKnowledgeItem)
        XCTAssertEqual(
            deeper.previousKnowledgeItem?.text,
            "Question: What is RAG?\n\nAnswer: Retrieval-augmented generation grounds an answer in retrieved context."
        )

        await AssistantNoteCaptureCoordinator.removeFromKnowledge(
            answerID: deeperID,
            conversation: state,
            knowledgeLibrary: knowledge
        )

        XCTAssertEqual(
            knowledge.snapshot.memories.first?.text,
            "Question: What is RAG?\n\nAnswer: Retrieval-augmented generation grounds an answer in retrieved context."
        )
        XCTAssertEqual(state.messages.first(where: { $0.id == fastID })?.noteState, .saved)
        XCTAssertEqual(state.messages.first(where: { $0.id == deeperID })?.noteState, .ready)

        await AssistantNoteCaptureCoordinator.scheduleAutomaticCapture(
            answerID: deeperID,
            conversation: state,
            knowledgeLibrary: knowledge,
            graceNanoseconds: 0
        )
        XCTAssertTrue(state.messages.first(where: { $0.id == deeperID })?.ownsKnowledgeItem == true)

        await AssistantNoteCaptureCoordinator.removeFromKnowledge(
            answerID: fastID,
            conversation: state,
            knowledgeLibrary: knowledge
        )

        XCTAssertTrue(knowledge.snapshot.memories.isEmpty)
        for messageID in [fastID, deeperID] {
            let message = try XCTUnwrap(state.messages.first(where: { $0.id == messageID }))
            XCTAssertEqual(message.noteState, .ready)
            XCTAssertNil(message.knowledgeItemID)
            XCTAssertFalse(message.ownsKnowledgeItem)
        }

        await AssistantNoteCaptureCoordinator.captureImmediately(
            answerID: deeperID,
            conversation: state,
            knowledgeLibrary: knowledge
        )

        XCTAssertEqual(knowledge.snapshot.memories.count, 1)
        XCTAssertEqual(
            knowledge.snapshot.memories.first?.text,
            "Question: What is RAG?\n\nAnswer: \(deeperText)"
        )
        XCTAssertFalse(
            KnowledgeMemorySource.isAutomaticAnswer(
                knowledge.snapshot.memories.first?.source ?? ""
            )
        )
    }

    @MainActor
    func testUndoingIdenticalSmartUpgradeRestoresFastCardAndResetsSmartCard() async throws {
        let knowledge = NativeKnowledgeLibraryState()
        let state = AssistantConversationState()
        let questionID = try XCTUnwrap(state.appendManualQuestion("What is RAG?"))
        let turnID = try XCTUnwrap(state.messages.first(where: { $0.id == questionID })?.turnID)
        let answer = "Retrieval-augmented generation grounds an answer in retrieved context."
        let fastID = try XCTUnwrap(state.ingestAnswer(
            answer,
            providerName: "OpenAI",
            modelName: "gpt-4.1-mini",
            isFinal: true
        ))
        await AssistantNoteCaptureCoordinator.scheduleAutomaticCapture(
            answerID: fastID,
            conversation: state,
            knowledgeLibrary: knowledge,
            graceNanoseconds: 0
        )
        let smartID = try XCTUnwrap(state.ingestAnswer(
            answer,
            providerName: "OpenAI",
            modelName: "gpt-4.1",
            isFinal: true,
            answerDepth: .deeper,
            forceNew: true,
            turnID: turnID
        ))
        await AssistantNoteCaptureCoordinator.scheduleAutomaticCapture(
            answerID: smartID,
            conversation: state,
            knowledgeLibrary: knowledge,
            graceNanoseconds: 0
        )

        XCTAssertEqual(
            KnowledgeMemorySource.automaticAnswerQuality(
                in: try XCTUnwrap(knowledge.snapshot.memories.first?.source)
            ),
            .smart
        )
        XCTAssertNotNil(state.messages.first(where: { $0.id == smartID })?.previousKnowledgeItem)

        await AssistantNoteCaptureCoordinator.removeFromKnowledge(
            answerID: smartID,
            conversation: state,
            knowledgeLibrary: knowledge
        )

        XCTAssertEqual(
            KnowledgeMemorySource.automaticAnswerQuality(
                in: try XCTUnwrap(knowledge.snapshot.memories.first?.source)
            ),
            .fast
        )
        let fast = try XCTUnwrap(state.messages.first(where: { $0.id == fastID }))
        XCTAssertEqual(fast.noteState, .saved)
        XCTAssertTrue(fast.ownsKnowledgeItem)
        XCTAssertNil(fast.previousKnowledgeItem)
        let smart = try XCTUnwrap(state.messages.first(where: { $0.id == smartID }))
        XCTAssertEqual(smart.noteState, .ready)
        XCTAssertNil(smart.knowledgeItemID)
        XCTAssertFalse(smart.ownsKnowledgeItem)
        XCTAssertNil(smart.previousKnowledgeItem)

        // A second tap on the already-undone SMART card is a no-op; the FAST
        // owner remains removable and does not enter a restore loop.
        await AssistantNoteCaptureCoordinator.removeFromKnowledge(
            answerID: smartID,
            conversation: state,
            knowledgeLibrary: knowledge
        )
        XCTAssertEqual(knowledge.snapshot.memories.count, 1)
        await AssistantNoteCaptureCoordinator.removeFromKnowledge(
            answerID: fastID,
            conversation: state,
            knowledgeLibrary: knowledge
        )
        XCTAssertTrue(knowledge.snapshot.memories.isEmpty)
    }

    @MainActor
    func testFailedSourceOnlyUndoKeepsCardTruthfullySaved() async throws {
        let question = "What is RAG?"
        let answer = "Retrieval-augmented generation grounds an answer in retrieved context."
        let content = "Question: \(question)\n\nAnswer: \(answer)"
        let knowledge = NativeKnowledgeLibraryState(
            store: RunnerSourceOnlyUndoFailureStore(content: content)
        )
        let state = AssistantConversationState()
        state.appendManualQuestion(question)
        let answerID = try XCTUnwrap(
            state.ingestAnswer(
                answer,
                providerName: "OpenAI",
                modelName: "gpt-4.1-mini",
                isFinal: true
            )
        )

        await AssistantNoteCaptureCoordinator.scheduleAutomaticCapture(
            answerID: answerID,
            conversation: state,
            knowledgeLibrary: knowledge,
            graceNanoseconds: 0
        )
        let beforeUndo = try XCTUnwrap(state.messages.first(where: { $0.id == answerID }))
        XCTAssertEqual(beforeUndo.noteState, .saved)
        XCTAssertTrue(beforeUndo.ownsKnowledgeItem)
        XCTAssertEqual(
            KnowledgeMemorySource.automaticAnswerQuality(
                in: try XCTUnwrap(knowledge.snapshot.memories.first?.source)
            ),
            .smart
        )

        await AssistantNoteCaptureCoordinator.removeFromKnowledge(
            answerID: answerID,
            conversation: state,
            knowledgeLibrary: knowledge
        )

        let afterUndo = try XCTUnwrap(state.messages.first(where: { $0.id == answerID }))
        XCTAssertEqual(afterUndo.noteState, .saved)
        XCTAssertTrue(afterUndo.ownsKnowledgeItem)
        XCTAssertNotNil(afterUndo.knowledgeItemID)
        XCTAssertEqual(afterUndo.previousKnowledgeItem, beforeUndo.previousKnowledgeItem)
        XCTAssertEqual(
            KnowledgeMemorySource.automaticAnswerQuality(
                in: try XCTUnwrap(knowledge.snapshot.memories.first?.source)
            ),
            .smart,
            "A no-op durable store must not be reported as a successful SMART-to-FAST rollback"
        )
    }

    @MainActor
    func testSavedAutomaticKnowledgeCanBeRemoved() async {
        let knowledge = NativeKnowledgeLibraryState()
        let state = AssistantConversationState()
        state.appendManualQuestion("What is RAG?")
        let answerID = state.ingestAnswer(
            "Retrieval-augmented generation grounds an answer in retrieved context.",
            providerName: "Test",
            modelName: "gpt-4.1-mini",
            isFinal: true
        )!
        await AssistantNoteCaptureCoordinator.scheduleAutomaticCapture(
            answerID: answerID,
            conversation: state,
            knowledgeLibrary: knowledge,
            graceNanoseconds: 0
        )

        XCTAssertEqual(knowledge.snapshot.memories.count, 1)
        XCTAssertEqual(state.messages.last?.noteState, .saved)

        await AssistantNoteCaptureCoordinator.removeFromKnowledge(
            answerID: answerID,
            conversation: state,
            knowledgeLibrary: knowledge
        )

        XCTAssertTrue(knowledge.snapshot.memories.isEmpty)
        XCTAssertEqual(state.messages.last?.noteState, .ready)
        XCTAssertNil(state.messages.last?.knowledgeItemID)
    }

    func testBluetoothConnectionPersistenceFallsBackToSecureStoreAfterReinstall() {
        let defaultsSuite = "BluetoothConnectionPersistenceTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: defaultsSuite)!
        defaults.removePersistentDomain(forName: defaultsSuite)
        defer {
            defaults.removePersistentDomain(forName: defaultsSuite)
        }

        let secureStore = InMemoryBluetoothConnectionSecureStore()
        let persistence = BluetoothConnectionPersistence(
            defaults: defaults,
            secureStore: secureStore
        )
        let expected = StoredBluetoothConnection(
            deviceName: "Pair_7",
            leftPeripheralID: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            rightPeripheralID: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
        )

        XCTAssertTrue(secureStore.save(expected.encoded(), for: BluetoothConnectionPersistence.secureStoreAccount))

        let restored = persistence.load()

        XCTAssertEqual(restored, expected)
        XCTAssertEqual(
            defaults.string(forKey: BluetoothConnectionPersistence.storedDeviceNameKey),
            expected.deviceName
        )
        XCTAssertEqual(
            defaults.string(forKey: BluetoothConnectionPersistence.storedLeftUUIDKey),
            expected.leftPeripheralID.uuidString
        )
        XCTAssertEqual(
            defaults.string(forKey: BluetoothConnectionPersistence.storedRightUUIDKey),
            expected.rightPeripheralID.uuidString
        )
    }

    func testBluetoothConnectionPersistenceBackfillsSecureStoreFromDefaults() {
        let defaultsSuite = "BluetoothConnectionPersistenceTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: defaultsSuite)!
        defaults.removePersistentDomain(forName: defaultsSuite)
        defer {
            defaults.removePersistentDomain(forName: defaultsSuite)
        }

        let expected = StoredBluetoothConnection(
            deviceName: "Pair_5",
            leftPeripheralID: UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")!,
            rightPeripheralID: UUID(uuidString: "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb")!
        )
        defaults.set(expected.deviceName, forKey: BluetoothConnectionPersistence.storedDeviceNameKey)
        defaults.set(expected.leftPeripheralID.uuidString, forKey: BluetoothConnectionPersistence.storedLeftUUIDKey)
        defaults.set(expected.rightPeripheralID.uuidString, forKey: BluetoothConnectionPersistence.storedRightUUIDKey)

        let secureStore = InMemoryBluetoothConnectionSecureStore()
        let persistence = BluetoothConnectionPersistence(
            defaults: defaults,
            secureStore: secureStore
        )

        let restored = persistence.load()

        XCTAssertEqual(restored, expected)
        XCTAssertEqual(
            secureStore.read(for: BluetoothConnectionPersistence.secureStoreAccount),
            expected.encoded()
        )
    }

    func testBluetoothConnectionPersistenceClearRemovesDefaultsAndSecureStore() {
        let defaultsSuite = "BluetoothConnectionPersistenceTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: defaultsSuite)!
        defaults.removePersistentDomain(forName: defaultsSuite)
        defer {
            defaults.removePersistentDomain(forName: defaultsSuite)
        }

        let secureStore = InMemoryBluetoothConnectionSecureStore()
        let persistence = BluetoothConnectionPersistence(
            defaults: defaults,
            secureStore: secureStore
        )
        let stored = StoredBluetoothConnection(
            deviceName: "Pair_8",
            leftPeripheralID: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!,
            rightPeripheralID: UUID(uuidString: "44444444-4444-4444-4444-444444444444")!
        )

        persistence.save(stored)
        persistence.clear()

        XCTAssertNil(persistence.load())
        XCTAssertNil(defaults.string(forKey: BluetoothConnectionPersistence.storedDeviceNameKey))
        XCTAssertNil(defaults.string(forKey: BluetoothConnectionPersistence.storedLeftUUIDKey))
        XCTAssertNil(defaults.string(forKey: BluetoothConnectionPersistence.storedRightUUIDKey))
        XCTAssertNil(secureStore.read(for: BluetoothConnectionPersistence.secureStoreAccount))
    }

    func testAudioResamplerUpsamplesPCM16Data() {
        let input = [Int16](0..<8)
        let inputData = input.withUnsafeBufferPointer { Data(buffer: $0) }

        let output = AudioResampler.resample(
            pcm16Data: inputData,
            fromRate: 16000,
            toRate: 24000
        )

        let outputSamples = output.withUnsafeBytes {
            Array($0.bindMemory(to: Int16.self))
        }

        // 8 samples at 16k -> 12 at 24k. The converter's low-pass filter
        // rings at the tail, so assert energy preservation, not the exact
        // final sample.
        XCTAssertEqual(outputSamples.count, 12)
        XCTAssertEqual(outputSamples.first, input.first)
        XCTAssertEqual(outputSamples.max(), input.max())
    }

    func testRealtimeTranscriberFailsFastWithoutApiKey() {
        let transcriber = OpenAIRealtimeTranscriber()
        let expectation = expectation(description: "Missing API key surfaces immediately")

        transcriber.start(
            apiKey: "",
            model: "gpt-4o-mini-transcribe",
            language: "en"
        ) { result in
            switch result {
            case .success:
                XCTFail("Expected failure for missing API key")
            case .failure(let error):
                guard let transcriberError = error as? OpenAIRealtimeTranscriber.TranscriberError else {
                    XCTFail("Unexpected error type: \(error)")
                    expectation.fulfill()
                    return
                }
                XCTAssertEqual(
                    transcriberError.errorDescription,
                    "OpenAI API key is required for realtime transcription"
                )
            }
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1.0)
    }

    func testConversationSessionConfigIncludesInstructionsAndTextModalities() {
        let transcriber = OpenAIRealtimeTranscriber()
        transcriber.debugConfigureForTesting(
            mode: .conversation,
            language: "ja",
            systemPrompt: "Coach me for interviews."
        )

        let event = transcriber.debugSessionConfigEvent()

        XCTAssertEqual(event["type"] as? String, "session.update")
        let session = event["session"] as? [String: Any]
        XCTAssertEqual(session?["instructions"] as? String, "Coach me for interviews.")
        // Conversation mode streams spoken replies, so audio is a modality.
        XCTAssertEqual(session?["modalities"] as? [String], ["text", "audio"])

        let transcription = session?["input_audio_transcription"] as? [String: Any]
        XCTAssertEqual(transcription?["model"] as? String, "gpt-4o-mini-transcribe")
        XCTAssertEqual(transcription?["language"] as? String, "ja")
    }

    func testHandleMessageRoutesTranscriptAndResponseCallbacks() {
        let transcriber = OpenAIRealtimeTranscriber()
        let expectation = expectation(description: "Callbacks invoked")
        expectation.expectedFulfillmentCount = 4

        var transcriptEvents: [(String, Bool)] = []
        var responseEvents: [(String, Bool)] = []

        transcriber.onTranscript = { text, isFinal in
            transcriptEvents.append((text, isFinal))
            expectation.fulfill()
        }
        transcriber.onResponse = { text, isFinal in
            responseEvents.append((text, isFinal))
            expectation.fulfill()
        }

        transcriber.debugHandleMessage(
            #"{"type":"conversation.item.input_audio_transcription.delta","delta":"Hello"}"#
        )
        transcriber.debugHandleMessage(
            #"{"type":"conversation.item.input_audio_transcription.completed","transcript":"Hello there"}"#
        )
        transcriber.debugHandleMessage(
            #"{"type":"response.text.delta","delta":"Hi"}"#
        )
        transcriber.debugHandleMessage(
            #"{"type":"response.text.done"}"#
        )

        wait(for: [expectation], timeout: 1.0)

        XCTAssertEqual(transcriptEvents.map(\.0), ["Hello", "Hello there"])
        XCTAssertEqual(transcriptEvents.map(\.1), [false, true])
        XCTAssertEqual(responseEvents.map(\.0), ["Hi", ""])
        XCTAssertEqual(responseEvents.map(\.1), [false, true])
    }

    func testHandleMessageMapsAuthenticationErrorsToFriendlyCopy() {
        let transcriber = OpenAIRealtimeTranscriber()
        let expectation = expectation(description: "Auth error surfaces friendly copy")

        var capturedError: String?
        transcriber.onError = { message in
            capturedError = message
            expectation.fulfill()
        }

        transcriber.debugHandleMessage(
            #"{"type":"error","error":{"message":"HTTP 401 unauthorized"}}"#
        )

        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(capturedError, "OpenAI API key is invalid or expired")
    }
}

private final class InMemoryBluetoothConnectionSecureStore: BluetoothConnectionSecureStore {
    private var storage: [String: Data] = [:]

    func read(for account: String) -> Data? {
        storage[account]
    }

    @discardableResult
    func save(_ data: Data, for account: String) -> Bool {
        storage[account] = data
        return true
    }

    func delete(for account: String) {
        storage.removeValue(forKey: account)
    }
}

final class SpeechQuestionPipelineRegressionTests: XCTestCase {
    override func tearDown() {
        SpeechStreamRecognizer.shared.stopRecognition(emitFinal: false)
        SpeechStreamRecognizer.shared.detachEventHandler()
        super.tearDown()
    }

    func testFullLocaleIdentifiersMapToSupportedSpeechAndTranscriptionLanguages() {
        let supportedSpeechLocales: Set<String> = [
            "en-US", "zh-Hans-CN", "zh-Hant-TW", "es-US", "es-ES",
            "ru-RU", "ko-KR", "ja-JP", "fr-FR", "de-DE", "nl-NL",
            "nb-NO", "da-DK", "sv-SE", "fi-FI", "it-IT"
        ]

        XCTAssertEqual(
            SpeechStreamRecognizer.speechLocaleIdentifier(
                for: "zh-Hans-US",
                supportedLocaleIdentifiers: supportedSpeechLocales
            ),
            "zh-Hans-CN"
        )
        XCTAssertEqual(
            SpeechStreamRecognizer.speechLocaleIdentifier(
                for: "es-US",
                supportedLocaleIdentifiers: supportedSpeechLocales
            ),
            "es-US"
        )

        let expectedLanguageCodes = [
            "CN": "zh", "zh-Hans-US": "zh", "EN": "en", "en-US": "en",
            "RU": "ru", "ru-RU": "ru", "KR": "ko", "ko-KR": "ko",
            "JP": "ja", "ja-JP": "ja", "ES": "es", "es-US": "es",
            "FR": "fr", "fr-FR": "fr", "DE": "de", "de-DE": "de",
            "NL": "nl", "nl-NL": "nl", "NB": "nb", "nb-NO": "nb",
            "DA": "da", "da-DK": "da", "SV": "sv", "sv-SE": "sv",
            "FI": "fi", "fi-FI": "fi", "IT": "it", "it-IT": "it"
        ]
        for (identifier, expected) in expectedLanguageCodes {
            XCTAssertEqual(
                SpeechStreamRecognizer.transcriptionLanguageCode(for: identifier),
                expected,
                identifier
            )
        }
    }

    func testWhisperPeriodicBatchAndStopFlushAreDeliveredAsDistinctFinalSegments() {
        let recognizer = SpeechStreamRecognizer.shared
        recognizer.stopRecognition(emitFinal: false)

        let finalEvents = expectation(description: "Both completed Whisper batches are final")
        finalEvents.expectedFulfillmentCount = 2
        var finalScripts: [String] = []

        recognizer.attachEventHandler { payload in
            guard payload["isFinal"] as? Bool == true,
                  let script = payload["script"] as? String else { return }
            finalScripts.append(script)
            finalEvents.fulfill()
        }

        let started = expectation(description: "Whisper recognizer starts")
        recognizer.startRecognition(
            identifier: "EN",
            source: "glasses",
            backend: .whisper,
            apiKey: "unit-test-key",
            model: "whisper-1"
        ) { result in
            if case .failure(let error) = result {
                XCTFail("Whisper recognizer failed to start: \(error)")
            }
            started.fulfill()
        }
        wait(for: [started], timeout: 1)

        // Periodic batch responses currently arrive with isFinal=false even
        // though the HTTP response is a stable, completed transcription.
        recognizer.whisperTranscriber.onTranscript?("What is RAG?", false)
        recognizer.stopRecognition(emitFinal: true)

        // The async tail response can arrive after stopRecognition returns.
        recognizer.whisperTranscriber.onTranscript?("How does RAG work?", true)

        wait(for: [finalEvents], timeout: 1)
        XCTAssertEqual(finalScripts, ["What is RAG?", "How does RAG work?"])
    }

    func testCancelledWhisperSessionDropsAnAsyncTailFromBeforeNewConversation() {
        let recognizer = SpeechStreamRecognizer.shared
        recognizer.stopRecognition(emitFinal: false)

        let staleFinal = expectation(description: "Cancelled tail must not be emitted")
        staleFinal.isInverted = true
        recognizer.attachEventHandler { payload in
            if payload["isFinal"] as? Bool == true {
                staleFinal.fulfill()
            }
        }

        let started = expectation(description: "Whisper recognizer starts")
        recognizer.startRecognition(
            identifier: "EN",
            source: "glasses",
            backend: .whisper,
            apiKey: "unit-test-key",
            model: "whisper-1"
        ) { _ in
            started.fulfill()
        }
        wait(for: [started], timeout: 1)

        let staleCallback = recognizer.whisperTranscriber.onTranscript
        recognizer.stopRecognition(emitFinal: false)
        staleCallback?("Should the cleared chat reappear?", true)

        wait(for: [staleFinal], timeout: 0.15)
    }

    func testRealtimeGracefulStopDeliversMatchingCompletedTranscriptBeforeDisconnect() {
        let transcriber = OpenAIRealtimeTranscriber()
        let final = expectation(description: "Tail final delivered")
        var wasStillAwaitingWhenDelivered = false
        transcriber.onTranscript = { text, isFinal in
            guard isFinal else { return }
            XCTAssertEqual(text, "What changed?")
            wasStillAwaitingWhenDelivered = transcriber.debugIsAwaitingGracefulStop
            final.fulfill()
        }
        transcriber.debugBeginGracefulStopForTesting(
            awaitingItemID: "tail-item",
            partialText: "What changed"
        )

        transcriber.debugHandleMessage(
            #"{"type":"conversation.item.input_audio_transcription.completed","item_id":"tail-item","transcript":"What changed?"}"#
        )

        wait(for: [final], timeout: 1)
        XCTAssertTrue(wasStillAwaitingWhenDelivered)
        XCTAssertFalse(transcriber.debugIsAwaitingGracefulStop)
    }

    func testRealtimeGracefulStopHasBoundedTimeoutAndFallsBackToPartial() {
        let transcriber = OpenAIRealtimeTranscriber()
        let fallback = expectation(description: "Partial promoted on timeout")
        transcriber.onTranscript = { text, isFinal in
            guard isFinal else { return }
            XCTAssertEqual(text, "Unfinished tail")
            fallback.fulfill()
        }
        transcriber.debugBeginGracefulStopForTesting(
            awaitingItemID: "tail-item",
            partialText: "Unfinished tail"
        )

        transcriber.debugForceGracefulStopTimeout()

        wait(for: [fallback], timeout: 1)
        XCTAssertFalse(transcriber.debugIsAwaitingGracefulStop)
    }

    @MainActor
    func testRealtimeImmediateRestartRejectsLateFinalFromPriorSocketSession() {
        let transcriber = OpenAIRealtimeTranscriber()
        var finals: [String] = []
        transcriber.onTranscript = { text, isFinal in
            if isFinal { finals.append(text) }
        }

        let oldSession = transcriber.debugBeginSessionForTesting()
        transcriber.debugBeginGracefulStopForTesting(
            awaitingItemID: "old-tail",
            partialText: "Old unfinished tail"
        )
        let newSession = transcriber.debugBeginSessionForTesting()

        transcriber.debugHandleMessage(
            #"{"type":"conversation.item.input_audio_transcription.completed","item_id":"old-tail","transcript":"Old final must be ignored"}"#,
            sessionToken: oldSession
        )
        transcriber.debugHandleMessage(
            #"{"type":"conversation.item.input_audio_transcription.completed","item_id":"new-item","transcript":"New session final"}"#,
            sessionToken: newSession
        )

        XCTAssertEqual(finals, ["New session final"])
        XCTAssertFalse(transcriber.debugIsAwaitingGracefulStop)
    }

    func testWhisperDiarizationEmitsDistinctOrderedSubturnsWithoutAggregate() {
        let segments = [
            SpeakerTurnDetector.SpeakerSegment(
                text: "What changed?",
                speaker: "other",
                startTime: 0,
                endTime: 0.8
            ),
            SpeakerTurnDetector.SpeakerSegment(
                text: "The release moved to Friday.",
                speaker: "wearer",
                startTime: 2.5,
                endTime: 4.0
            ),
        ]

        let subturns = WhisperDiarizationEmissionPolicy.subturns(
            segments: segments,
            recognitionGeneration: 7,
            batch: 3
        )

        XCTAssertEqual(subturns.map(\.text), ["What changed?", "The release moved to Friday."])
        XCTAssertEqual(subturns.map(\.segmentID), ["whisper-7-3-0", "whisper-7-3-1"])
        XCTAssertEqual(Set(subturns.map(\.segmentID)).count, 2)
        XCTAssertFalse(subturns.map(\.text).contains("What changed? The release moved to Friday."))

        let repeated = WhisperDiarizationEmissionPolicy.subturns(
            segments: [
                SpeakerTurnDetector.SpeakerSegment(
                    text: "Same question?",
                    speaker: "other",
                    startTime: 5,
                    endTime: 6
                ),
                SpeakerTurnDetector.SpeakerSegment(
                    text: "Same question?",
                    speaker: "wearer",
                    startTime: 8,
                    endTime: 9
                ),
            ],
            recognitionGeneration: 7,
            batch: 4
        )
        XCTAssertEqual(repeated.map(\.text), ["Same question?", "Same question?"])
        XCTAssertEqual(Set(repeated.map(\.segmentID)).count, 2)
    }

    func testWhisperOutOfOrderHTTPResponsesDrainCallbacksInChunkOrder() throws {
        let transcriber = WhisperBatchTranscriber()
        let callbacks = expectation(description: "Ordered verbose callbacks")
        callbacks.expectedFulfillmentCount = 2
        var received: [String] = []
        transcriber.onVerboseTranscript = { text, _, _ in
            received.append(text)
            callbacks.fulfill()
        }

        let chunkOne = try JSONSerialization.data(withJSONObject: [
            "text": "first chunk",
            "words": [["word": "first", "start": 0.0, "end": 0.2],
                      ["word": "chunk", "start": 0.25, "end": 0.45]],
        ])
        let chunkTwo = try JSONSerialization.data(withJSONObject: [
            "text": "second chunk",
            "words": [["word": "second", "start": 0.55, "end": 0.75],
                      ["word": "chunk", "start": 0.8, "end": 1.0]],
        ])

        transcriber.enqueueResponseForTesting(data: chunkTwo, chunkIndex: 2)
        transcriber.enqueueResponseForTesting(data: chunkOne, chunkIndex: 1)

        wait(for: [callbacks], timeout: 2)
        XCTAssertEqual(received, ["first chunk", "second chunk"])
    }

    func testWhisperQueuedOldEpochCallbackCannotEnterRestartedSession() throws {
        let transcriber = WhisperBatchTranscriber()
        let staleCallback = expectation(description: "Old callback suppressed")
        staleCallback.isInverted = true
        transcriber.onVerboseTranscript = { _, _, _ in staleCallback.fulfill() }
        let oldChunk = try JSONSerialization.data(withJSONObject: [
            "text": "old session",
            "words": [["word": "old", "start": 0.0, "end": 0.2]],
        ])

        // Queue parsing on the old epoch, then synchronously advance the epoch
        // before the callback can execute on the main queue.
        transcriber.enqueueResponseForTesting(data: oldChunk, chunkIndex: 1)
        transcriber.start(apiKey: "test", chunkDurationSec: 60)
        transcriber.stop()

        wait(for: [staleCallback], timeout: 0.2)
    }

    @MainActor
    func testNewConversationClearsLocalHUDAnswerState() {
        let runtime = HelixRuntimeDependencies()
        let bridge = HelixNativeBridge(runtime: runtime)
        bridge.presentToGlasses("Private answer from the prior conversation")
        XCTAssertTrue(runtime.g1DeviceState.hasActiveAnswer)
        XCTAssertFalse(runtime.g1DeviceState.hudPages.isEmpty)

        bridge.stopListeningForNewConversation()

        XCTAssertFalse(runtime.g1DeviceState.hasActiveAnswer)
        XCTAssertTrue(runtime.g1DeviceState.hudPages.isEmpty)
        XCTAssertEqual(runtime.g1DeviceState.eventLog.last, "hud:clear")
    }

    @MainActor
    func testNewConversationOrdersPhysicalExitAfterOldHUDPackets() async {
        let runtime = HelixRuntimeDependencies()
        runtime.g1DeviceState.setConnection(left: true, right: true)
        let writer = RecordingG1PacketWriter()
        let transport = G1CommandTransport(
            writer: writer,
            ackTimeoutNs: 100_000_000
        )
        await writer.setOnWrite { bytes, side in
            guard let command = bytes.first, [0x4E, 0x18].contains(command) else { return }
            Task { await transport.handleInbound([command, 0xC9], from: side) }
        }
        let bridge = HelixNativeBridge(runtime: runtime, transport: transport)

        let delivered = expectation(description: "Old HUD screen ACKed")
        bridge.presentToGlasses("Old private answer that must be cleared") { _ in delivered.fulfill() }
        await fulfillment(of: [delivered], timeout: 2)
        bridge.stopListeningForNewConversation()
        await bridge.waitForPresentationResetForTesting()

        let sentLog = await transport.sentLog
        XCTAssertGreaterThanOrEqual(sentLog.count, 4)
        XCTAssertEqual(sentLog.suffix(2).map(\.bytes), [[0x18], [0x18]])
        XCTAssertFalse(runtime.g1DeviceState.hasActiveAnswer)
    }

    @MainActor
    func testHudPacketsAreAckGatedLeftBeforeRightAndReportBothLenses() async {
        let runtime = HelixRuntimeDependencies()
        runtime.g1DeviceState.setConnection(left: true, right: true)
        let writer = RecordingG1PacketWriter()
        let transport = G1CommandTransport(writer: writer, ackTimeoutNs: 100_000_000)
        await writer.setOnWrite { bytes, side in
            guard bytes.first == G1PacketEncoder.commandByte else { return }
            Task { await transport.handleInbound([G1PacketEncoder.commandByte, 0xC9], from: side) }
        }
        let bridge = HelixNativeBridge(runtime: runtime, transport: transport)
        let completion = expectation(description: "Both lenses acknowledged")
        var result: G1HUDDeliveryResult?

        // One logical HUD page, but multiple UTF-8 packets.
        bridge.presentToGlasses(String(repeating: "界", count: 100)) {
            result = $0
            completion.fulfill()
        }
        await fulfillment(of: [completion], timeout: 2)

        let writes = await writer.writes.filter { $0.bytes.first == G1PacketEncoder.commandByte }
        XCTAssertEqual(result, .deliveredToBothLenses)
        XCTAssertEqual(writes.count, 4)
        XCTAssertEqual(writes.map(\.side), [.left, .left, .right, .right])
        XCTAssertEqual(writes.map { $0.bytes[3] }, [0, 1, 0, 1])
    }

    @MainActor
    func testTouchpadPageDeliveryUpdatesActiveAnswerLensTruth() async {
        let runtime = HelixRuntimeDependencies()
        runtime.g1DeviceState.setConnection(left: true, right: true)
        let writer = RecordingG1PacketWriter()
        let transport = G1CommandTransport(writer: writer, ackTimeoutNs: 100_000_000)
        await writer.setOnWrite { bytes, side in
            guard bytes.first == G1PacketEncoder.commandByte else { return }
            let currentPage = bytes.count > 7 ? bytes[7] : 0
            let status: UInt8 = currentPage == 2 && side == .right ? 0xCA : 0xC9
            Task { await transport.handleInbound([G1PacketEncoder.commandByte, status], from: side) }
        }
        let bridge = HelixNativeBridge(runtime: runtime, transport: transport)
        let firstPageDelivered = expectation(description: "First page delivery reported")
        let secondPageDelivered = expectation(description: "Touchpad page delivery reported")
        var results: [G1HUDDeliveryResult] = []

        let multiPageAnswer = Array(repeating: "delivery truth must follow every page", count: 12)
            .joined(separator: " ")
        bridge.presentToGlasses(multiPageAnswer) { result in
            results.append(result)
            if results.count == 1 {
                firstPageDelivered.fulfill()
            } else if results.count == 2 {
                secondPageDelivered.fulfill()
            }
        }
        await fulfillment(of: [firstPageDelivered], timeout: 2)
        XCTAssertGreaterThan(runtime.g1DeviceState.hudPages.count, 1)
        XCTAssertEqual(results, [.deliveredToBothLenses])

        bridge.handleTouchpadForTesting(notifyIndex: 1, side: .right)
        await fulfillment(of: [secondPageDelivered], timeout: 2)

        XCTAssertEqual(runtime.g1DeviceState.currentPageIndex, 1)
        XCTAssertEqual(results, [.deliveredToBothLenses, .deliveredToLeftLens])
    }

    @MainActor
    func testHudLeftFailureAbortsBeforeAnyRightWrite() async {
        let runtime = HelixRuntimeDependencies()
        runtime.g1DeviceState.setConnection(left: true, right: true)
        let writer = RecordingG1PacketWriter()
        let transport = G1CommandTransport(writer: writer, ackTimeoutNs: 100_000_000)
        await writer.setOnWrite { bytes, side in
            guard bytes.first == G1PacketEncoder.commandByte else { return }
            Task { await transport.handleInbound([G1PacketEncoder.commandByte, 0xCA], from: side) }
        }
        let bridge = HelixNativeBridge(runtime: runtime, transport: transport)
        let completion = expectation(description: "Left failure reported")
        var result: G1HUDDeliveryResult?

        bridge.presentToGlasses("Answer") {
            result = $0
            completion.fulfill()
        }
        await fulfillment(of: [completion], timeout: 2)

        let writes = await writer.writes.filter { $0.bytes.first == G1PacketEncoder.commandByte }
        XCTAssertEqual(result, .failed)
        XCTAssertEqual(writes.count, G1CommandTransport.maxAttempts)
        XCTAssertTrue(writes.allSatisfy { $0.side == .left })
    }

    @MainActor
    func testHudRightOnlyConnectionWritesRightAndReportsPartialDelivery() async {
        let runtime = HelixRuntimeDependencies()
        runtime.g1DeviceState.setConnection(left: false, right: true)
        let writer = RecordingG1PacketWriter()
        let transport = G1CommandTransport(writer: writer, ackTimeoutNs: 100_000_000)
        await writer.setOnWrite { bytes, side in
            guard bytes.first == G1PacketEncoder.commandByte else { return }
            Task { await transport.handleInbound([G1PacketEncoder.commandByte, 0xCB], from: side) }
        }
        let bridge = HelixNativeBridge(runtime: runtime, transport: transport)
        let completion = expectation(description: "Right lens acknowledged")
        var result: G1HUDDeliveryResult?

        bridge.presentToGlasses("Answer") {
            result = $0
            completion.fulfill()
        }
        await fulfillment(of: [completion], timeout: 2)

        let writes = await writer.writes.filter { $0.bytes.first == G1PacketEncoder.commandByte }
        XCTAssertEqual(result, .deliveredToRightLens)
        XCTAssertFalse(writes.isEmpty)
        XCTAssertTrue(writes.allSatisfy { $0.side == .right })
    }

    @MainActor
    func testHudRightFailureAfterLeftSuccessReportsLeftOnly() async {
        let runtime = HelixRuntimeDependencies()
        runtime.g1DeviceState.setConnection(left: true, right: true)
        let writer = RecordingG1PacketWriter()
        let transport = G1CommandTransport(writer: writer, ackTimeoutNs: 100_000_000)
        await writer.setOnWrite { bytes, side in
            guard bytes.first == G1PacketEncoder.commandByte else { return }
            let status: UInt8 = side == .left ? 0xC9 : 0xCA
            Task { await transport.handleInbound([G1PacketEncoder.commandByte, status], from: side) }
        }
        let bridge = HelixNativeBridge(runtime: runtime, transport: transport)
        let completion = expectation(description: "Partial delivery reported")
        var result: G1HUDDeliveryResult?

        bridge.presentToGlasses("Answer") {
            result = $0
            completion.fulfill()
        }
        await fulfillment(of: [completion], timeout: 2)

        let writes = await writer.writes.filter { $0.bytes.first == G1PacketEncoder.commandByte }
        XCTAssertEqual(result, .deliveredToLeftLens)
        XCTAssertEqual(writes.filter { $0.side == .left }.count, 1)
        XCTAssertEqual(writes.filter { $0.side == .right }.count, G1CommandTransport.maxAttempts)
    }

    @MainActor
    func testSingleLensConnectAndDisconnectEventsPreserveReadySide() async {
        let runtime = HelixRuntimeDependencies()
        let writer = RecordingG1PacketWriter()
        let transport = G1CommandTransport(writer: writer, ackTimeoutNs: 100_000_000)
        await writer.setOnWrite { bytes, side in
            guard let command = bytes.first, [0x4D, 0x26].contains(command) else { return }
            Task { await transport.handleInbound([command, 0xC9], from: side) }
        }
        let bridge = HelixNativeBridge(runtime: runtime, transport: transport)

        bridge.handleBleEvent("glassesConnected", arguments: [
            "partial": "true",
            "connectedSide": "R",
            "rightDeviceName": "G1_R_42",
        ])
        XCTAssertFalse(runtime.g1DeviceState.leftLensConnected)
        XCTAssertTrue(runtime.g1DeviceState.rightLensConnected)
        XCTAssertEqual(bridge.connectionPhase, "Connected (right lens)")

        // A left-side disconnect must not erase an already-ready right link.
        bridge.handleBleEvent("glassesDisconnected", arguments: [
            "status": "disconnected",
            "disconnectedSide": "L",
        ])
        XCTAssertFalse(runtime.g1DeviceState.leftLensConnected)
        XCTAssertTrue(runtime.g1DeviceState.rightLensConnected)

        bridge.handleBleEvent("glassesDisconnected", arguments: ["status": "poweredOff"])
        XCTAssertFalse(runtime.g1DeviceState.leftLensConnected)
        XCTAssertFalse(runtime.g1DeviceState.rightLensConnected)
    }
}
