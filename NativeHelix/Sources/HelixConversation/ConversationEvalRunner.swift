import Foundation
import HelixAI
import HelixCore
import HelixPersistence
import HelixSpeech

public struct NativeConversationEvalRunner: Sendable {
    public init() {}

    public func run(gitSha: String = "unknown", simulatorUdid: String = "local") async -> EvalReport {
        var checks: [EvalCheck] = []
        checks.append(await transcriptionCheck())
        checks.append(questionDetectionCheck())
        checks.append(statementSuppressionCheck())
        checks.append(duplicateQuestionCheck())
        checks.append(passiveCorrectionCheck())
        checks.append(await activeAnswerCheck())
        checks.append(await ragCheck())
        checks.append(await webSearchCheck())
        return EvalReport(gitSha: gitSha, simulatorUdid: simulatorUdid, checks: checks)
    }

    private func transcriptionCheck() async -> EvalCheck {
        let start = ContinuousClock.now
        let transcriber = DeterministicAudioFileTranscriber()
        do {
            let segment = try await transcriber.transcribeAudioFile(
                at: URL(fileURLWithPath: "/tmp/llm-question.wav"),
                backend: .openAITranscription,
                model: "gpt-4o-mini-transcribe"
            )
            let passed = !segment.text.isEmpty && segment.text.lowercased().contains("llm")
            return check(
                id: "T01",
                area: "transcription",
                passed: passed,
                start: start,
                expected: "non-empty transcript containing LLM marker",
                actual: segment.text
            )
        } catch {
            return check(
                id: "T01",
                area: "transcription",
                passed: false,
                start: start,
                expected: "transcript",
                actual: error.localizedDescription
            )
        }
    }

    private func questionDetectionCheck() -> EvalCheck {
        let start = ContinuousClock.now
        let questions = QuestionDetector().detectQuestions(in: "What is RAG for an LLM?")
        return check(
            id: "Q01",
            area: "question-detection",
            passed: questions.count == 1,
            start: start,
            expected: "exactly one question",
            actual: "\(questions.count)"
        )
    }

    private func statementSuppressionCheck() -> EvalCheck {
        let start = ContinuousClock.now
        let questions = QuestionDetector().detectQuestions(in: "RAG combines retrieval with generation.")
        return check(
            id: "Q02",
            area: "question-detection",
            passed: questions.isEmpty,
            start: start,
            expected: "no question",
            actual: "\(questions.count)"
        )
    }

    private func duplicateQuestionCheck() -> EvalCheck {
        let start = ContinuousClock.now
        let detector = QuestionDetector()
        let suppressor = DuplicateQuestionSuppressor()
        let unique = suppressor.uniqueQuestions(
            detector.detectQuestions(in: "What is RAG? What is RAG?")
        )
        return check(
            id: "Q03",
            area: "question-detection",
            passed: unique.count == 1,
            start: start,
            expected: "one unique question",
            actual: "\(unique.count)"
        )
    }

    private func passiveCorrectionCheck() -> EvalCheck {
        let detector = PassiveCorrectionDetector()
        let finalizedAt = Date()
        let segment = TranscriptSegment(
            text: "RAG means random answer generation.",
            isFinal: true,
            finalizedAt: finalizedAt
        )
        let reminder = detector.reminder(for: segment, finalizedAt: finalizedAt.addingTimeInterval(0.12))
        return EvalCheck(
            id: "P01",
            area: "passive-correction",
            status: (reminder?.latencyMs ?? 9999) < 1000 ? .pass : .fail,
            latencyMs: reminder?.latencyMs ?? 9999,
            expected: "reminder under 1000ms",
            actual: reminder?.reminder ?? "none"
        )
    }

    private func activeAnswerCheck() async -> EvalCheck {
        let start = ContinuousClock.now
        let engine = NativeConversationEngine(
            answerProvider: DeterministicAnswerProvider(),
            conversationStore: InMemoryConversationStore()
        )
        do {
            let answer = try await engine.answerActiveQuestion("What is an LLM?")
            let validator = AnswerStyleValidator()
            let passed = answer.text.lowercased().contains("transformer") && validator.isDirectSpeakable(answer.text)
            return check(
                id: "A01",
                area: "active-answer",
                passed: passed,
                start: start,
                expected: "precise direct answer",
                actual: answer.text,
                latencyReportOnly: true
            )
        } catch {
            return check(id: "A01", area: "active-answer", passed: false, start: start, expected: "answer", actual: error.localizedDescription)
        }
    }

    private func ragCheck() async -> EvalCheck {
        let start = ContinuousClock.now
        let engine = NativeConversationEngine(
            answerProvider: DeterministicAnswerProvider(),
            conversationStore: InMemoryConversationStore()
        )
        do {
            let answer = try await engine.answerActiveQuestion(
                "What does the project say?",
                projectFacts: ["Helix displays answers on Even G1 glasses"]
            )
            let passed = answer.text.contains("Even G1 glasses") && answer.citations.contains("project-context")
            return check(
                id: "R01",
                area: "rag",
                passed: passed,
                start: start,
                expected: "answer uses project facts",
                actual: answer.text,
                latencyReportOnly: true
            )
        } catch {
            return check(id: "R01", area: "rag", passed: false, start: start, expected: "RAG answer", actual: error.localizedDescription)
        }
    }

    private func webSearchCheck() async -> EvalCheck {
        let start = ContinuousClock.now
        let engine = NativeConversationEngine(
            settings: HelixSettings(webSearchMode: .fakeDeterministic),
            answerProvider: DeterministicAnswerProvider(),
            webSearchService: DeterministicWebSearchService(),
            conversationStore: InMemoryConversationStore()
        )
        let answer: AnswerResponse
        do {
            answer = try await engine.answerActiveQuestion("What is RAG?")
        } catch {
            return check(
                id: "W01",
                area: "web-search",
                passed: false,
                start: start,
                expected: "web-routed answer",
                actual: error.localizedDescription
            )
        }
        return check(
            id: "W01",
            area: "web-search",
            passed: answer.text.contains("retrieved context") && answer.citations.contains("web-search"),
            start: start,
            expected: "engine-routed synthesized answer from web result",
            actual: answer.text
        )
    }

    private func check(
        id: String,
        area: String,
        passed: Bool,
        start: ContinuousClock.Instant,
        expected: String,
        actual: String,
        latencyReportOnly: Bool = false
    ) -> EvalCheck {
        let elapsed = start.duration(to: ContinuousClock.now)
        let latencyMs = Int(elapsed.components.seconds) * 1000 + Int(Double(elapsed.components.attoseconds) / 1_000_000_000_000_000)
        return EvalCheck(
            id: id,
            area: area,
            status: passed ? .pass : .fail,
            latencyMs: latencyMs,
            expected: expected,
            actual: actual,
            latencyReportOnly: latencyReportOnly
        )
    }
}
