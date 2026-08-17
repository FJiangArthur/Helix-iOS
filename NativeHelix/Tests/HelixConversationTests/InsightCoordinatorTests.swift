import XCTest
import HelixAI
import HelixCore
import HelixRuntime

/// Returns a canned response regardless of the request — used to script the
/// insight JSON the coordinator must parse and orchestrate.
private struct StaticAnswerProvider: HelixAnswerProvider {
    let kind: LlmProviderKind = .openAI
    let model = "static-test"
    let responseText: String

    func streamAnswer(for request: AnswerRequest) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            continuation.yield(responseText)
            continuation.finish()
        }
    }
}

@MainActor
final class InsightCoordinatorTests: XCTestCase {
    private func makeCoordinator(
        response: String? = nil,
        now: Date = Date(timeIntervalSince1970: 1_000_000)
    ) -> (InsightCoordinator, () -> Void) {
        var currentTime = now
        let clock = { currentTime }
        let coordinator = InsightCoordinator(now: { clock() })
        coordinator.setEnabled(true)
        if let response {
            coordinator.setProvider(StaticAnswerProvider(responseText: response))
        }
        let advance = { currentTime = currentTime.addingTimeInterval(15) }
        return (coordinator, advance)
    }

    private func insightJSON(
        text: String,
        action: String = "show",
        urgency: String = "low"
    ) -> String {
        #"{"type":"insight","text":"\#(text)","displayAction":"\#(action)","urgency":"\#(urgency)","confidence":0.9}"#
    }

    // MARK: - Triggers

    func testFinalTranscriptBelowThresholdIsIgnored() async {
        let (coordinator, _) = makeCoordinator(response: insightJSON(text: "x"))

        await coordinator.handleTranscript("short", isFinal: true)

        XCTAssertNil(coordinator.activeInsight)
        XCTAssertTrue(coordinator.decisions.isEmpty)
    }

    func testFinalTranscriptTriggersAnalysisAndDisplay() async {
        let (coordinator, _) = makeCoordinator(response: insightJSON(text: "The meeting moved to 3pm."))

        await coordinator.handleTranscript("We rescheduled the sync for later today", isFinal: true)

        XCTAssertEqual(coordinator.activeInsight?.text, "The meeting moved to 3pm.")
        XCTAssertEqual(coordinator.decisions.last?.outcome, .displayed)
    }

    func testCompletedSentenceInterimTriggers() async {
        let (coordinator, _) = makeCoordinator(response: insightJSON(text: "Rome hosted the 1960 games."))

        await coordinator.handleTranscript("The olympics were in rome that year.", isFinal: false)

        XCTAssertEqual(coordinator.activeInsight?.text, "Rome hosted the 1960 games.")
    }

    func testIncompleteShortInterimDoesNotTrigger() async {
        let (coordinator, _) = makeCoordinator(response: insightJSON(text: "nope"))

        await coordinator.handleTranscript("so anyway we were", isFinal: false)

        XCTAssertNil(coordinator.activeInsight)
    }

    // MARK: - Dedup & mutual exclusion

    func testDuplicateInsightIsDeduplicated() async {
        let (coordinator, advance) = makeCoordinator(response: insightJSON(text: "Same insight text."))

        await coordinator.handleTranscript("First chunk of conversation here.", isFinal: true)
        advance()
        await coordinator.handleTranscript("Second different chunk arrives now.", isFinal: true)

        XCTAssertEqual(coordinator.decisions.filter { $0.outcome == .displayed }.count, 1)
        XCTAssertEqual(coordinator.decisions.last?.outcome, .deduplicated)
    }

    func testEngineAnsweredUtteranceIsSkipped() async {
        let (coordinator, _) = makeCoordinator(response: insightJSON(text: "Should never appear"))

        await coordinator.handleTranscript("What is the capital of France?", isFinal: true, engineAnswered: true)

        XCTAssertNil(coordinator.activeInsight)
        XCTAssertEqual(coordinator.decisions.last?.outcome, .engineOwned)
    }

    // MARK: - Orchestration

    func testSilentResponseProducesNoDisplay() async {
        let (coordinator, _) = makeCoordinator(response: #"{"type":"silent","confidence":0.9}"#)

        await coordinator.handleTranscript("Just some small talk happening here.", isFinal: true)

        XCTAssertNil(coordinator.activeInsight)
        XCTAssertEqual(coordinator.decisions.last?.outcome, .silent)
    }

    func testDropActionIsDropped() {
        let (coordinator, _) = makeCoordinator()
        let insight = Insight(text: "droppable", displayAction: .drop)

        coordinator.process(insight, trigger: "final", chunk: "chunk")

        XCTAssertNil(coordinator.activeInsight)
        XCTAssertEqual(coordinator.decisions.last?.outcome, .dropped)
    }

    func testHighUrgencyReplacesActiveDisplay() {
        let (coordinator, _) = makeCoordinator()

        coordinator.process(Insight(text: "first insight"), trigger: "final", chunk: "a")
        coordinator.process(
            Insight(text: "urgent correction", urgency: .high),
            trigger: "final",
            chunk: "b"
        )

        XCTAssertEqual(coordinator.activeInsight?.text, "urgent correction")
        XCTAssertEqual(coordinator.decisions.last?.outcome, .replaced)
    }

    func testLowUrgencyQueuesBehindActiveDisplayUpToLimit() {
        let (coordinator, _) = makeCoordinator()

        coordinator.process(Insight(text: "active"), trigger: "final", chunk: "a")
        for index in 0..<3 {
            coordinator.process(Insight(text: "queued \(index)"), trigger: "final", chunk: "q\(index)")
        }
        coordinator.process(Insight(text: "overflow"), trigger: "final", chunk: "z")

        XCTAssertEqual(coordinator.activeInsight?.text, "active")
        XCTAssertEqual(coordinator.decisions.filter { $0.outcome == .queued }.count, 3)
        XCTAssertEqual(coordinator.decisions.last?.outcome, .dropped)
    }

    // MARK: - Parsing

    func testParsesJSONWrappedInCodeFence() {
        let wrapped = """
        ```json
        {"type":"insight","text":"Wrapped insight","displayAction":"queue","urgency":"medium","confidence":0.7}
        ```
        """
        let insight = InsightCoordinator.parseInsightResponse(wrapped)

        XCTAssertEqual(insight?.text, "Wrapped insight")
        XCTAssertEqual(insight?.displayAction, .queue)
        XCTAssertEqual(insight?.urgency, .medium)
    }

    func testNonJSONResponseParsesAsNil() {
        XCTAssertNil(InsightCoordinator.parseInsightResponse("I think the meeting moved."))
        XCTAssertNil(InsightCoordinator.parseInsightResponse(#"{"type":"defer"}"#))
        XCTAssertNil(InsightCoordinator.parseInsightResponse(#"{"type":"insight","text":"  "}"#))
    }

    func testDisabledCoordinatorIgnoresTranscripts() async {
        let (coordinator, _) = makeCoordinator(response: insightJSON(text: "hidden"))
        coordinator.setEnabled(false)

        await coordinator.handleTranscript("A long enough final transcript arrives.", isFinal: true)

        XCTAssertNil(coordinator.activeInsight)
    }
}
