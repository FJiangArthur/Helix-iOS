import Foundation
import HelixConversation
import HelixCore
import HelixPersistence
import HelixRuntime
import SwiftData
import XCTest

private actor RuntimeSourceOnlyUndoFailureStore: KnowledgeLibraryStore {
    private let previousItem: NativeKnowledgeItem
    private let currentItem: NativeKnowledgeItem
    private var upsertCount = 0

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
        defer { upsertCount += 1 }
        if upsertCount == 0 {
            return KnowledgeMemoryUpsertResult(
                item: currentItem,
                wasInserted: false,
                previousItem: previousItem
            )
        }
        return KnowledgeMemoryUpsertResult(item: currentItem, wasInserted: false)
    }
    func undoMemoryUpsert(_ result: KnowledgeMemoryUpsertResult) async {}
    func removeMemory(id: UUID) async {}
    func addTodo(_ title: String) async {}
    func completeTodo(id: UUID, isComplete: Bool) async {}
}

final class KnowledgeRemovalTests: XCTestCase {
    @MainActor
    func testInMemoryKnowledgeStateRemovesOnlySelectedMemory() async throws {
        let state = NativeKnowledgeLibraryState(store: InMemoryKnowledgeLibraryStore())
        await state.addMemory("Keep this memory", source: "Test")
        await state.addMemory("Remove this memory", source: "Test")

        let removedID = try XCTUnwrap(
            state.snapshot.memories.first(where: { $0.text == "Remove this memory" })?.id
        )
        await state.removeMemory(id: removedID)

        XCTAssertEqual(state.snapshot.memories.map(\.text), ["Keep this memory"])
    }

    func testSwiftDataKnowledgeStoreDurablyRemovesMemory() async throws {
        let container = try HelixSwiftDataSchema.makeModelContainer(isStoredInMemoryOnly: true)
        let store = SwiftDataKnowledgeLibraryStore(container: container)
        await store.addMemory("Durable removable memory", source: "Test")

        let initialSnapshot = await store.snapshot()
        let memoryID = try XCTUnwrap(initialSnapshot.memories.first?.id)
        await store.removeMemory(id: memoryID)

        let reloaded = await SwiftDataKnowledgeLibraryStore(container: container).snapshot()
        XCTAssertTrue(reloaded.memories.isEmpty)
    }

    func testInMemoryKnowledgeStoreAtomicallyUpsertsConcurrentMemory() async throws {
        let store = InMemoryKnowledgeLibraryStore()

        async let first = store.addMemoryIfAbsent("  Same durable memory  ", source: "First")
        async let second = store.addMemoryIfAbsent("same durable   memory", source: "Second")
        let (firstResult, secondResult) = await (first, second)
        let results = [try XCTUnwrap(firstResult), try XCTUnwrap(secondResult)]

        XCTAssertEqual(results.filter(\.wasInserted).count, 1)
        let snapshot = await store.snapshot()
        XCTAssertEqual(snapshot.memories.count, 1)
    }

    func testSwiftDataKnowledgeStoreAtomicallyUpsertsConcurrentMemory() async throws {
        let container = try HelixSwiftDataSchema.makeModelContainer(isStoredInMemoryOnly: true)
        let store = SwiftDataKnowledgeLibraryStore(container: container)

        async let first = store.addMemoryIfAbsent("Same SwiftData memory", source: "First")
        async let second = store.addMemoryIfAbsent(" same swiftdata   memory ", source: "Second")
        let (firstResult, secondResult) = await (first, second)
        let results = [try XCTUnwrap(firstResult), try XCTUnwrap(secondResult)]

        XCTAssertEqual(results.filter(\.wasInserted).count, 1)
        let snapshot = await store.snapshot()
        XCTAssertEqual(snapshot.memories.count, 1)
    }

    func testAutomaticAnswersUpdateOneQuestionIdentityAcrossProviderParaphrases() async throws {
        let stores: [any KnowledgeLibraryStore] = [
            InMemoryKnowledgeLibraryStore(),
            SwiftDataKnowledgeLibraryStore(
                container: try HelixSwiftDataSchema.makeModelContainer(isStoredInMemoryOnly: true)
            )
        ]

        for store in stores {
            let first = await store.addMemoryIfAbsent(
                "Question: What is the capital of France?\n\nAnswer: Paris is the capital of France.",
                source: KnowledgeMemorySource.automaticAnswer(category: "Fact"),
                deduplication: .automaticAnswer(quality: .fast)
            )
            let duplicate = await store.addMemoryIfAbsent(
                "Q: what is the capital of France？\nA: France's capital city is Paris.",
                source: KnowledgeMemorySource.automaticAnswer(category: "Fact"),
                deduplication: .automaticAnswer(quality: .fast)
            )
            let quoted = await store.addMemoryIfAbsent(
                "Question: “What is the capital of France?”\n\nAnswer: Paris remains France's capital.",
                source: KnowledgeMemorySource.automaticAnswer(category: "Fact"),
                deduplication: .automaticAnswer(quality: .fast)
            )
            let quotedSmart = await store.addMemoryIfAbsent(
                "Question: “What is the capital of France?”\n\nAnswer: Paris remains France's capital.",
                source: KnowledgeMemorySource.automaticAnswer(category: "Fact", quality: .smart),
                deduplication: .automaticAnswer(quality: .smart)
            )

            let firstResult = try XCTUnwrap(first)
            let duplicateResult = try XCTUnwrap(duplicate)
            let quotedResult = try XCTUnwrap(quoted)
            let quotedSmartResult = try XCTUnwrap(quotedSmart)
            XCTAssertTrue(firstResult.wasInserted)
            XCTAssertFalse(duplicateResult.wasInserted)
            XCTAssertTrue(duplicateResult.didMutate)
            XCTAssertEqual(duplicateResult.item.id, firstResult.item.id)
            XCTAssertEqual(duplicateResult.previousItem, firstResult.item)
            XCTAssertFalse(quotedResult.wasInserted)
            XCTAssertEqual(quotedResult.item.id, firstResult.item.id)
            XCTAssertEqual(quotedResult.previousItem, duplicateResult.item)
            XCTAssertFalse(quotedSmartResult.wasInserted)
            XCTAssertTrue(quotedSmartResult.didMutate)
            XCTAssertEqual(quotedSmartResult.item.id, firstResult.item.id)
            XCTAssertEqual(quotedSmartResult.previousItem, quotedResult.item)
            XCTAssertEqual(
                KnowledgeMemorySource.automaticAnswerQuality(in: quotedSmartResult.item.source),
                .smart
            )
            let snapshot = await store.snapshot()
            XCTAssertEqual(snapshot.memories.count, 1)
            XCTAssertEqual(
                snapshot.memories.first?.text,
                "Question: “What is the capital of France?”\n\nAnswer: Paris remains France's capital."
            )
        }
    }

    func testManualAnswerDoesNotBlockAutomaticAnswerDedupe() async throws {
        let stores: [any KnowledgeLibraryStore] = [
            InMemoryKnowledgeLibraryStore(),
            SwiftDataKnowledgeLibraryStore(
                container: try HelixSwiftDataSchema.makeModelContainer(isStoredInMemoryOnly: true)
            )
        ]

        for store in stores {
            await store.addMemory(
                "Question: What is the capital of France?\n\nAnswer: A manually saved answer.",
                source: "Manual"
            )
            await store.addMemory(
                "Q: what is the capital of France？\nA: A second manual research note.",
                source: "Manual"
            )

            let duplicate = await store.addMemoryIfAbsent(
                "Question: WHAT IS THE CAPITAL OF FRANCE\n\nAnswer: A later automatic paraphrase.",
                source: KnowledgeMemorySource.automaticAnswer(category: "Fact"),
                deduplication: .automaticAnswer(quality: .fast)
            )

            XCTAssertTrue(try XCTUnwrap(duplicate).wasInserted)
            let snapshot = await store.snapshot()
            XCTAssertEqual(snapshot.memories.count, 3)
            XCTAssertTrue(snapshot.memories.contains { $0.text == "Question: What is the capital of France?\n\nAnswer: A manually saved answer." })
            XCTAssertTrue(snapshot.memories.contains { $0.text == "Q: what is the capital of France？\nA: A second manual research note." })
        }
    }

    func testManualExplicitUpsertUsesFullContentInsteadOfQuestionOnly() async throws {
        let stores: [any KnowledgeLibraryStore] = [
            InMemoryKnowledgeLibraryStore(),
            SwiftDataKnowledgeLibraryStore(
                container: try HelixSwiftDataSchema.makeModelContainer(isStoredInMemoryOnly: true)
            )
        ]

        for store in stores {
            let first = await store.addMemoryIfAbsent(
                "Question: What is the capital of France?\n\nAnswer: Paris is the capital of France.",
                source: "Manual"
            )
            let paraphrase = await store.addMemoryIfAbsent(
                "Q: what is the capital of France？\nA: France's capital city is Paris.",
                source: "Manual"
            )
            let exactDuplicate = await store.addMemoryIfAbsent(
                "  Question: What is the capital of France?\n\nAnswer: Paris is the capital of France.  ",
                source: "Manual"
            )

            XCTAssertTrue(try XCTUnwrap(first).wasInserted)
            XCTAssertTrue(try XCTUnwrap(paraphrase).wasInserted)
            XCTAssertFalse(try XCTUnwrap(exactDuplicate).wasInserted)
            let snapshot = await store.snapshot()
            XCTAssertEqual(snapshot.memories.count, 2)
        }
    }

    func testAutomaticAnswerDedupeIsScopedToActiveProject() async throws {
        let stores: [any KnowledgeLibraryStore] = [
            InMemoryKnowledgeLibraryStore(),
            SwiftDataKnowledgeLibraryStore(
                container: try HelixSwiftDataSchema.makeModelContainer(isStoredInMemoryOnly: true)
            )
        ]

        for store in stores {
            let firstProject = NativeKnowledgeProject(name: "First", isActive: true)
            let secondProject = NativeKnowledgeProject(name: "Second", isActive: true)

            await store.saveProject(firstProject)
            let first = await store.addMemoryIfAbsent(
                "Question: What is RAG?\n\nAnswer: Retrieval-augmented generation uses retrieved context.",
                source: KnowledgeMemorySource.automaticAnswer(category: "Fact"),
                deduplication: .automaticAnswer(quality: .fast)
            )
            await store.saveProject(secondProject)
            let second = await store.addMemoryIfAbsent(
                "Question: What is RAG?\n\nAnswer: RAG grounds an answer in retrieved context.",
                source: KnowledgeMemorySource.automaticAnswer(category: "Fact"),
                deduplication: .automaticAnswer(quality: .fast)
            )
            let duplicateInSecond = await store.addMemoryIfAbsent(
                "  Question: What is RAG?\n\nAnswer: RAG grounds an answer in retrieved context.  ",
                source: KnowledgeMemorySource.automaticAnswer(category: "Fact"),
                deduplication: .automaticAnswer(quality: .fast)
            )

            XCTAssertTrue(try XCTUnwrap(first).wasInserted)
            XCTAssertTrue(try XCTUnwrap(second).wasInserted)
            XCTAssertFalse(try XCTUnwrap(duplicateInSecond).wasInserted)
            let snapshot = await store.snapshot()
            XCTAssertEqual(snapshot.memories.count, 2)
            XCTAssertEqual(try XCTUnwrap(duplicateInSecond).item.id, try XCTUnwrap(second).item.id)
        }
    }

    func testExactMemoryUpsertDedupeIsScopedToActiveProjectAcrossStores() async throws {
        let stores: [any KnowledgeLibraryStore] = [
            InMemoryKnowledgeLibraryStore(),
            SwiftDataKnowledgeLibraryStore(
                container: try HelixSwiftDataSchema.makeModelContainer(isStoredInMemoryOnly: true)
            )
        ]

        for store in stores {
            let firstProject = NativeKnowledgeProject(name: "Exact First", isActive: true)
            let secondProject = NativeKnowledgeProject(name: "Exact Second", isActive: true)

            await store.saveProject(firstProject)
            let firstResult = await store.addMemoryIfAbsent(
                "Same project-local memory",
                source: "Manual"
            )
            let first = try XCTUnwrap(firstResult)
            await store.saveProject(secondProject)
            let secondResult = await store.addMemoryIfAbsent(
                "Same project-local memory",
                source: "Manual"
            )
            let duplicateResult = await store.addMemoryIfAbsent(
                " same project-local memory ",
                source: "Manual"
            )
            let second = try XCTUnwrap(secondResult)
            let duplicateInSecond = try XCTUnwrap(duplicateResult)

            XCTAssertTrue(first.wasInserted)
            XCTAssertTrue(second.wasInserted)
            XCTAssertFalse(duplicateInSecond.wasInserted)
            XCTAssertNotEqual(first.item.id, second.item.id)
            XCTAssertEqual(duplicateInSecond.item.id, second.item.id)
            let snapshot = await store.snapshot()
            XCTAssertEqual(snapshot.memories.count, 2)
        }
    }

    func testSmartAutomaticAnswerSupersedesFastReversiblyAndCannotBeDowngraded() async throws {
        let stores: [any KnowledgeLibraryStore] = [
            InMemoryKnowledgeLibraryStore(),
            SwiftDataKnowledgeLibraryStore(
                container: try HelixSwiftDataSchema.makeModelContainer(isStoredInMemoryOnly: true)
            )
        ]

        for store in stores {
            let fastResult = await store.addMemoryIfAbsent(
                "Question: Why is the sky blue?\n\nAnswer: Air scatters blue light.",
                source: KnowledgeMemorySource.automaticAnswer(category: "Fact", quality: .fast),
                deduplication: .automaticAnswer(quality: .fast)
            )
            let smartResult = await store.addMemoryIfAbsent(
                "Question: Why is the sky blue?\n\nAnswer: Air scatters blue light.",
                source: KnowledgeMemorySource.automaticAnswer(category: "Fact", quality: .smart),
                deduplication: .automaticAnswer(quality: .smart)
            )
            let downgradeResult = await store.addMemoryIfAbsent(
                "Question: Why is the sky blue?\n\nAnswer: A later fast paraphrase.",
                source: KnowledgeMemorySource.automaticAnswer(category: "Fact", quality: .fast),
                deduplication: .automaticAnswer(quality: .fast)
            )
            let exactRepeatResult = await store.addMemoryIfAbsent(
                "  Question: Why is the sky blue?\n\nAnswer: Air scatters blue light.  ",
                source: KnowledgeMemorySource.automaticAnswer(category: "Fact", quality: .smart),
                deduplication: .automaticAnswer(quality: .smart)
            )
            let fast = try XCTUnwrap(fastResult)
            let smart = try XCTUnwrap(smartResult)
            let downgrade = try XCTUnwrap(downgradeResult)
            let exactRepeat = try XCTUnwrap(exactRepeatResult)

            XCTAssertEqual(fast.item.id, smart.item.id)
            XCTAssertEqual(fast.item.text, smart.item.text)
            XCTAssertEqual(
                smart.item.source,
                KnowledgeMemorySource.automaticAnswer(category: "Fact", quality: .smart)
            )
            XCTAssertEqual(smart.previousItem, fast.item)
            XCTAssertTrue(smart.didMutate)
            XCTAssertFalse(downgrade.didMutate)
            XCTAssertEqual(downgrade.item, smart.item)
            XCTAssertFalse(exactRepeat.didMutate)
            XCTAssertEqual(exactRepeat.item, smart.item)

            await store.undoMemoryUpsert(smart)
            var snapshot = await store.snapshot()
            XCTAssertEqual(snapshot.memories, [fast.item])
            await store.undoMemoryUpsert(fast)
            snapshot = await store.snapshot()
            XCTAssertTrue(snapshot.memories.isEmpty)
        }
    }

    @MainActor
    func testRuntimeFailedSourceOnlyUndoDoesNotCancelSiblingReceipt() async throws {
        let question = "What is retrieval-augmented generation?"
        let firstAnswer = "Retrieval-augmented generation grounds an answer in retrieved context."
        let secondAnswer = "RAG adds retrieved evidence before the model generates its response."
        let firstContent = "Question: \(question)\n\nAnswer: \(firstAnswer)"
        let knowledge = NativeKnowledgeLibraryState(
            store: RuntimeSourceOnlyUndoFailureStore(content: firstContent)
        )
        let capture = NativeAutomaticKnowledgeCaptureState(
            knowledgeLibrary: knowledge,
            graceNanoseconds: 0
        )

        func outcome(sequence: UInt64, answer: String) -> NativeLiveTranscriptOutcome {
            let segment = TranscriptSegment(text: question, isFinal: true)
            let candidate = QuestionCandidate(text: question, confidence: 0.99)
            return NativeLiveTranscriptOutcome(
                conversationGeneration: 55,
                sequence: sequence,
                segment: segment,
                turn: ConversationTurnResult(
                    segment: segment,
                    question: candidate,
                    answer: AnswerResponse(
                        text: answer,
                        provider: .openAI,
                        model: "gpt-4.1-mini"
                    ),
                    passiveReminder: nil
                )
            )
        }

        capture.schedule(outcome(sequence: 0, answer: firstAnswer))
        for _ in 0..<200 where capture.receipts.values.contains(where: {
            $0.state == .pending || $0.state == .saving
        }) {
            await Task.yield()
        }
        capture.schedule(outcome(sequence: 1, answer: secondAnswer))
        for _ in 0..<200 where capture.receipts.values.contains(where: {
            $0.state == .pending || $0.state == .saving
        }) {
            await Task.yield()
        }

        let owner = try XCTUnwrap(capture.receipts.values.first(where: {
            $0.target.sequence == 0
        }))
        let sibling = try XCTUnwrap(capture.receipts.values.first(where: {
            $0.target.sequence == 1
        }))
        XCTAssertTrue(owner.ownsKnowledgeItem)
        XCTAssertFalse(sibling.ownsKnowledgeItem)
        XCTAssertEqual(owner.knowledgeItemID, sibling.knowledgeItemID)

        await capture.removeOwned([owner.target])

        XCTAssertEqual(capture.receipts[sibling.target]?.state, .saved)
        XCTAssertEqual(capture.receipts[sibling.target]?.knowledgeItemID, sibling.knowledgeItemID)
        XCTAssertEqual(
            KnowledgeMemorySource.automaticAnswerQuality(
                in: try XCTUnwrap(knowledge.snapshot.memories.first?.source)
            ),
            .smart,
            "A failed rollback must leave all durable receipt truth untouched"
        )
    }

    @MainActor
    func testCommittedTranscriptAutoCapturesWithoutAssistantViewMounted() async throws {
        let runtime = HelixRuntimeDependencies(
            automaticKnowledgeCaptureGraceNanoseconds: 0
        )

        let producedOutcome = await runtime.assistantSession.processLiveTranscript(
            "We decided to ship the runtime-owned note on Friday."
        )
        let outcome = try XCTUnwrap(producedOutcome)
        for _ in 0..<100 where runtime.knowledgeLibrary.snapshot.memories.isEmpty {
            await Task.yield()
        }

        XCTAssertEqual(outcome.sequence, 0)
        XCTAssertEqual(
            runtime.knowledgeLibrary.snapshot.memories.map(\.text),
            ["We decided to ship the runtime-owned note on Friday."]
        )

        _ = await runtime.assistantSession.processLiveTranscript(
            "My launch meeting is at 10 AM."
        )
        _ = await runtime.assistantSession.processLiveTranscript(
            "What is retrieval augmented generation?"
        )
        for _ in 0..<200 where runtime.automaticKnowledgeCapture.receipts.values.contains(
            where: { $0.state == .pending || $0.state == .saving }
        ) {
            await Task.yield()
        }

        XCTAssertTrue(
            runtime.knowledgeLibrary.snapshot.memories.contains {
                $0.text == "My launch meeting is at 10 AM."
            }
        )
        XCTAssertFalse(
            runtime.knowledgeLibrary.snapshot.memories.contains {
                $0.text.hasPrefix("Question: What is retrieval augmented generation?")
            },
            "The keyless deterministic fixture must not become automatic Knowledge"
        )
        XCTAssertEqual(runtime.knowledgeLibrary.snapshot.memories.count, 2)
    }

    @MainActor
    func testAutomaticNoteTargetsAreIsolatedAcrossConversationSequenceReset() async throws {
        let runtime = HelixRuntimeDependencies(
            automaticKnowledgeCaptureGraceNanoseconds: 0
        )
        let producedFirst = await runtime.assistantSession.processLiveTranscript(
            "We decided to preserve the first session note."
        )
        let first = try XCTUnwrap(producedFirst)
        for _ in 0..<100 where runtime.knowledgeLibrary.snapshot.memories.count < 1 {
            await Task.yield()
        }

        await runtime.assistantSession.startNewConversation()
        let producedSecond = await runtime.assistantSession.processLiveTranscript(
            "We decided to preserve the second session note."
        )
        let second = try XCTUnwrap(producedSecond)
        for _ in 0..<100 where runtime.knowledgeLibrary.snapshot.memories.count < 2 {
            await Task.yield()
        }

        XCTAssertEqual(first.sequence, 0)
        XCTAssertEqual(second.sequence, 0)
        XCTAssertNotEqual(first.conversationGeneration, second.conversationGeneration)
        let firstTargets = runtime.automaticKnowledgeCapture.targets(
            conversationGeneration: first.conversationGeneration,
            sequence: first.sequence,
            kind: .transcript
        )
        let secondTargets = runtime.automaticKnowledgeCapture.targets(
            conversationGeneration: second.conversationGeneration,
            sequence: second.sequence,
            kind: .transcript
        )
        XCTAssertFalse(firstTargets.isEmpty)
        XCTAssertFalse(secondTargets.isEmpty)
        XCTAssertTrue(firstTargets.isDisjoint(with: secondTargets))

        await runtime.automaticKnowledgeCapture.removeOwned(secondTargets)
        XCTAssertEqual(
            runtime.knowledgeLibrary.snapshot.memories.map(\.text),
            ["We decided to preserve the first session note."]
        )
    }

    @MainActor
    func testRemovingOwnedAutomaticAnswerResetsEverySharedReceipt() async throws {
        let knowledge = NativeKnowledgeLibraryState()
        let capture = NativeAutomaticKnowledgeCaptureState(
            knowledgeLibrary: knowledge,
            graceNanoseconds: 0
        )
        let questionText = "What is retrieval-augmented generation?"
        let answers = [
            "Retrieval-augmented generation grounds an answer in retrieved context.",
            "RAG improves factual relevance by adding retrieved evidence to generation."
        ]

        for (sequence, answerText) in answers.enumerated() {
            let segment = TranscriptSegment(text: questionText, isFinal: true)
            let question = QuestionCandidate(text: questionText, confidence: 0.99)
            capture.schedule(
                NativeLiveTranscriptOutcome(
                    conversationGeneration: 40,
                    sequence: UInt64(sequence),
                    segment: segment,
                    turn: ConversationTurnResult(
                        segment: segment,
                        question: question,
                        answer: AnswerResponse(
                            text: answerText,
                            provider: .openAI,
                            model: "gpt-4.1-mini"
                        ),
                        passiveReminder: nil
                    )
                )
            )
        }

        for _ in 0..<200 where capture.receipts.values.contains(where: {
            $0.state == .pending || $0.state == .saving
        }) {
            await Task.yield()
        }

        let saved = capture.receipts.values.filter { $0.state == .saved }
        XCTAssertEqual(saved.count, 2)
        XCTAssertEqual(Set(saved.compactMap(\.knowledgeItemID)).count, 1)
        let owner = try XCTUnwrap(saved.first(where: { $0.target.sequence == 0 }))
        let sibling = try XCTUnwrap(saved.first(where: { $0.target.sequence == 1 }))
        XCTAssertTrue(owner.ownsKnowledgeItem)
        XCTAssertTrue(sibling.ownsKnowledgeItem)
        XCTAssertEqual(sibling.previousKnowledgeItem?.text, owner.draft.content)

        await capture.removeOwned(Set([owner.target]))

        XCTAssertTrue(knowledge.snapshot.memories.isEmpty)
        for receipt in capture.receipts.values {
            XCTAssertEqual(receipt.state, .cancelled)
            XCTAssertNil(receipt.knowledgeItemID)
            XCTAssertFalse(receipt.ownsKnowledgeItem)
        }

        await capture.captureImmediately(Set([sibling.target]))

        XCTAssertEqual(knowledge.snapshot.memories.count, 1)
        XCTAssertEqual(capture.receipts[sibling.target]?.state, .saved)
        XCTAssertTrue(capture.receipts[sibling.target]?.ownsKnowledgeItem == true)
        XCTAssertEqual(
            knowledge.snapshot.memories.first?.text,
            "Question: \(questionText)\n\nAnswer: \(answers[1])"
        )
    }

    func testFallbackTranscriptPolicyRejectsUnpunctuatedQuestionLikeFacts() {
        let questionLikeStatements = [
            "My deadline is what day",
            "Our meeting starts when",
            "The launch is which day",
            "My appointment is how soon",
            "My deadline is tomorrow isn't it",
            "The release is Friday, isn’t it",
            "My deadline is tomorrow is it",
            "Our meeting is at noon can we",
            "The release moved to Friday did it",
            "My deadline is tomorrow, right",
            "My meeting is scheduled for which room",
            "My flight is from which airport",
            "My timezone is what offset",
            "My meeting is scheduled for how many people",
            "My reservation is under whose name",
            "My meeting is with who else",
            "My meeting is scheduled for when exactly",
            "My flight is departing from where exactly",
            "My meeting is scheduled for which conference room on the second floor",
            "My meeting is scheduled for when, exactly",
            "My timezone is what—exactly",
            "My timezone is what's the offset",
            "My deadline is tomorrow, yes or no",
            "My deadline is tomorrow, isn’t it though",
            "We decided what day",
            "I will do what",
            "My deadline is what day is available",
            "My meeting is scheduled for which room has the projector",
            "My meeting is scheduled for how many people are coming",
            "My reservation is under whose name is listed",
            "My meeting is Friday, which room should we use",
            "My deadline is Friday, what day should we launch",
            "My appointment is tomorrow, how soon can we meet",
            "My meeting is Friday, what you think",
            "My meeting is Friday what you thinking",
            "My meeting is Friday who you bringing",
            "My deadline is tomorrow why you asking"
        ]

        for statement in questionLikeStatements {
            XCTAssertNil(
                AssistantNoteCapturePolicy.automaticDraft(statement: statement),
                "Fallback capture must not persist a question-like statement: \(statement)"
            )
        }
    }

    func testFallbackTranscriptPolicyPreservesDeclarativeFactsAndDecisions() {
        let expectedDrafts = [
            AssistantNoteDraft(content: "My deadline is tomorrow.", category: .fact),
            AssistantNoteDraft(
                content: "My deadline is what keeps the release plan focused.",
                category: .fact
            ),
            AssistantNoteDraft(
                content: "Our release is what drives our launch plan forward.",
                category: .fact
            ),
            AssistantNoteDraft(
                content: "We decided how the migration will proceed.",
                category: .decision
            ),
            AssistantNoteDraft(
                content: "We agreed when the launch will happen.",
                category: .decision
            ),
            AssistantNoteDraft(
                content: "I will document how the migration works.",
                category: .actionItem
            ),
            AssistantNoteDraft(
                content: "Our meeting is Friday, which gives us three days.",
                category: .fact
            ),
            AssistantNoteDraft(
                content: "Remember that the workshop explains how the model works.",
                category: .fact
            ),
            AssistantNoteDraft(
                content: "Our meeting is scheduled when the client is available.",
                category: .fact
            ),
            AssistantNoteDraft(
                content: "Our project is where the source code lives.",
                category: .fact
            ),
            AssistantNoteDraft(
                content: "I will document how we organize work.",
                category: .actionItem
            ),
            AssistantNoteDraft(
                content: "We decided how Alice will lead the migration.",
                category: .decision
            ),
            AssistantNoteDraft(
                content: "I will document how Helix handles retries.",
                category: .actionItem
            ),
            AssistantNoteDraft(
                content: "Our meeting is scheduled when Alice is available.",
                category: .fact
            ),
            AssistantNoteDraft(
                content: "We decided what Alice will present.",
                category: .decision
            ),
            AssistantNoteDraft(
                content: "I will document what Helix supports.",
                category: .actionItem
            ),
            AssistantNoteDraft(
                content: "Our deadline is what Alice considers urgent.",
                category: .fact
            ),
            AssistantNoteDraft(
                content: "Our deadline is what Alice will confirm.",
                category: .fact
            ),
            AssistantNoteDraft(
                content: "We decided which team will present.",
                category: .decision
            ),
            AssistantNoteDraft(
                content: "We decided who will present.",
                category: .decision
            ),
            AssistantNoteDraft(
                content: "We decided whom Alice will invite.",
                category: .decision
            ),
            AssistantNoteDraft(
                content: "We decided whose team will present.",
                category: .decision
            ),
            AssistantNoteDraft(
                content: "Our meeting is Friday, which is convenient.",
                category: .fact
            ),
            AssistantNoteDraft(
                content: "Our deadline is tomorrow, which works well.",
                category: .fact
            ),
            AssistantNoteDraft(
                content: "We decided to ship Friday, which will leave a week for QA.",
                category: .decision
            ),
            AssistantNoteDraft(content: "My deadline is what matters.", category: .fact),
            AssistantNoteDraft(content: "Our project is what works.", category: .fact),
            AssistantNoteDraft(content: "We decided what works best.", category: .decision),
            AssistantNoteDraft(content: "My preference is swipe right.", category: .fact),
            AssistantNoteDraft(content: "We decided to ship the beta on Friday.", category: .decision)
        ]

        XCTAssertEqual(
            expectedDrafts.map { AssistantNoteCapturePolicy.automaticDraft(statement: $0.content) },
            expectedDrafts.map(Optional.some)
        )
    }

    func testFallbackTranscriptPolicyRejectsFlexibleCredentialSeparators() {
        let sensitiveStatements = [
            "Remember PIN: 1234.",
            "Remember API-key: sk-live-value.",
            "Remember private-key: private-value.",
            "Remember seed-phrase: alpha beta gamma.",
            "Remember social-security: 123-45-6789.",
            "Remember credit-card: 4111111111111111.",
            "Remember card-number: 4111111111111111.",
            "Remember ＰＩＮ: 1234.",
            "Remember API‑key: sk-live-value.",
            "Remember card–number: 4111111111111111.",
            "Remember APIKey: sk-live-value.",
            "Remember privateKey: private-value.",
            "Remember seedPhrase: alpha beta gamma.",
            "Remember cardNumber: 4111111111111111.",
            "Remember accessToken: access_1234567890abcdef.",
            "Remember recoveryCode: ABCD-EFGH-IJKL-MNOP."
        ]

        for statement in sensitiveStatements {
            XCTAssertNil(
                AssistantNoteCapturePolicy.automaticDraft(statement: statement),
                "Credential separators must not bypass automatic Knowledge safety: \(statement)"
            )
        }
    }

    func testAutomaticAnswerPolicyRejectsQuestionShapedModelAnswer() {
        XCTAssertNil(
            AssistantNoteCapturePolicy.automaticDraft(
                question: "What should we do next?",
                answer: "Could you confirm which environment currently owns this deployment?"
            )
        )

        for answer in [
            "What matters is preserving the user's data during migration.",
            "How the cache works is documented in the runtime guide.",
            "When the cache expires, Helix refreshes it from storage."
        ] {
            XCTAssertNotNil(
                AssistantNoteCapturePolicy.automaticDraft(
                    question: "What should Helix preserve during migration?",
                    answer: answer
                ),
                "A declarative answer must not be rejected only because it starts with WH: \(answer)"
            )
        }
    }

    @MainActor
    func testDetectedQuestionNeverBecomesDirectTranscriptFactEvenWhenSuppressed() {
        let knowledge = NativeKnowledgeLibraryState()
        let capture = NativeAutomaticKnowledgeCaptureState(
            knowledgeLibrary: knowledge,
            graceNanoseconds: 60_000_000_000
        )
        let segment = TranscriptSegment(text: "My meeting is when", isFinal: true)
        let question = QuestionCandidate(text: segment.text, confidence: 0.99)

        for suppressionReason in [nil, "Duplicate question suppressed."] as [String?] {
            let turn = ConversationTurnResult(
                segment: segment,
                question: question,
                answer: nil,
                passiveReminder: nil,
                questionResults: [
                    ConversationQuestionResult(
                        question: question,
                        answer: nil,
                        suppressionReason: suppressionReason
                    )
                ]
            )
            capture.schedule(
                NativeLiveTranscriptOutcome(
                    conversationGeneration: suppressionReason == nil ? 10 : 11,
                    sequence: 0,
                    segment: segment,
                    turn: turn
                )
            )
        }

        XCTAssertTrue(capture.receipts.values.filter { $0.target.kind == .transcript }.isEmpty)
    }

    @MainActor
    func testDetectedQuestionExclusionNormalizesCompatibilityAndTerminalPunctuation() {
        let knowledge = NativeKnowledgeLibraryState()
        let capture = NativeAutomaticKnowledgeCaptureState(
            knowledgeLibrary: knowledge,
            graceNanoseconds: 60_000_000_000
        )
        let cases = [
            ("My deadline is tomorrow.", "My deadline is tomorrow?"),
            ("My launch is next week。", "Ｍｙ launch is next week？"),
            (
                "My deadline is tomorrow, isn't it, and we decided to ship Friday.",
                "My deadline is tomorrow, isn't it?"
            )
        ]

        for (index, texts) in cases.enumerated() {
            let segment = TranscriptSegment(text: texts.0, isFinal: true)
            let question = QuestionCandidate(text: texts.1, confidence: 0.99)
            XCTAssertNotNil(
                AssistantNoteCapturePolicy.automaticDraft(statement: segment.text),
                "The regression requires a transcript that is independently fact-shaped"
            )
            capture.schedule(
                NativeLiveTranscriptOutcome(
                    conversationGeneration: UInt64(30 + index),
                    sequence: 0,
                    segment: segment,
                    turn: ConversationTurnResult(
                        segment: segment,
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
                )
            )
        }

        XCTAssertTrue(
            capture.receipts.values.filter { $0.target.kind == .transcript }.isEmpty,
            "Classifier punctuation or compatibility normalization must not leak questions into Knowledge"
        )
    }

    @MainActor
    func testLegacySingleAnswerOutcomeRequiresTrustedModelForAutomaticKnowledge() {
        let knowledge = NativeKnowledgeLibraryState()
        let capture = NativeAutomaticKnowledgeCaptureState(
            knowledgeLibrary: knowledge,
            graceNanoseconds: 60_000_000_000
        )
        let segment = TranscriptSegment(text: "What is RAG?", isFinal: true)
        let question = QuestionCandidate(text: segment.text, confidence: 0.99)

        capture.schedule(
            NativeLiveTranscriptOutcome(
                conversationGeneration: 20,
                sequence: 0,
                segment: segment,
                turn: ConversationTurnResult(
                    segment: segment,
                    question: question,
                    answer: AnswerResponse(
                        text: "Retrieval-augmented generation grounds answers in retrieved context.",
                        provider: .openAI,
                        model: "deterministic-native"
                    ),
                    passiveReminder: nil
                )
            )
        )
        XCTAssertTrue(capture.receipts.isEmpty)

        capture.schedule(
            NativeLiveTranscriptOutcome(
                conversationGeneration: 21,
                sequence: 0,
                segment: segment,
                turn: ConversationTurnResult(
                    segment: segment,
                    question: question,
                    answer: AnswerResponse(
                        text: "Retrieval-augmented generation grounds answers in retrieved context.",
                        provider: .openAI,
                        model: "gpt-4.1-mini"
                    ),
                    passiveReminder: nil
                )
            )
        )
        XCTAssertEqual(capture.receipts.values.filter { $0.target.kind == .answer }.count, 1)
    }
}
