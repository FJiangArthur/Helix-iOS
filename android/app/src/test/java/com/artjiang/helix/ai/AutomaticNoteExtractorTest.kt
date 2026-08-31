package com.artjiang.helix.ai

import com.artjiang.helix.core.KnowledgeBucket
import com.artjiang.helix.core.AnswerResponse
import com.artjiang.helix.core.ProviderKind
import com.artjiang.helix.core.QuestionCandidate
import com.artjiang.helix.core.TranscriptSegment
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class AutomaticNoteExtractorTest {

    private fun segment(text: String, isFinal: Boolean = true) = TranscriptSegment(
        text = text,
        isFinal = isFinal,
        timestampMillis = 123,
    )

    @Test
    fun `partial transcript never creates a note`() {
        assertTrue(
            AutomaticNoteExtractor.extract(segment("We decided to ship Friday.", isFinal = false)).isEmpty(),
        )
    }

    @Test
    fun `explicit decisions actions and useful facts map to internal knowledge buckets`() {
        val candidates = AutomaticNoteExtractor.extract(
            segment(
                "We decided to ship the beta on Friday. " +
                    "Action item: Art needs to send the release notes. " +
                    "The launch meeting is at 10 AM.",
            ),
        )

        assertEquals(
            listOf(
                AutomaticNoteKind.DECISION to KnowledgeBucket.MEMORIES,
                AutomaticNoteKind.ACTION_ITEM to KnowledgeBucket.TODOS,
                AutomaticNoteKind.FACT to KnowledgeBucket.FACTS,
            ),
            candidates.map { it.kind to it.bucket },
        )
        assertEquals("We decided to ship the beta on Friday.", candidates[0].text)
    }

    @Test
    fun `ordinary chatter questions and credentials are not auto saved`() {
        val candidates = AutomaticNoteExtractor.extract(
            segment(
                "The weather is nice. What time is lunch? " +
                    "My password is hunter2. My API key is sk-secret.",
            ),
        )

        assertTrue(candidates.isEmpty())
    }

    @Test
    fun `Arabic question mark delimits questions that are never auto saved`() {
        assertTrue(
            AutomaticNoteExtractor.extract(segment("My deadline is tomorrow؟")).isEmpty(),
        )

        val followingDecision = AutomaticNoteExtractor.extract(
            segment("My deadline is tomorrow؟ We decided to ship Friday."),
        )
        assertEquals(listOf(AutomaticNoteKind.DECISION), followingDecision.map { it.kind })
        assertEquals("We decided to ship Friday.", followingDecision.single().text)
    }

    @Test
    fun `on demand statement form question is conservatively excluded from automatic facts`() {
        val questions = listOf(
            "My deadline is what day",
            "Our meeting starts when",
            "My meeting is scheduled for when",
            "My appointment is scheduled for what day",
            "My deadline is tomorrow, isn't it",
            "My deadline is tomorrow isn’t it",
            "My meeting is at noon, right",
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
            "My deadline is tomorrow why you asking",
        )

        questions.forEach { question ->
            assertTrue(question, AutomaticNoteExtractor.extract(segment(question)).isEmpty())
        }

        assertEquals(
            listOf(AutomaticNoteKind.FACT),
            AutomaticNoteExtractor.extract(
                segment("My deadline is what keeps the release plan focused."),
            ).map { it.kind },
        )
        assertEquals(
            listOf(AutomaticNoteKind.FACT),
            AutomaticNoteExtractor.extract(
                segment("Our release is what drives our launch plan forward."),
            ).map { it.kind },
        )
    }

    @Test
    fun `classifier outcome can exclude a fact shaped spoken span`() {
        val unclassified = AutomaticNoteExtractor.extract(
            segment("My deadline is tomorrow"),
        )
        val classified = AutomaticNoteExtractor.extract(
            segment("My deadline is tomorrow"),
            excludedQuestionTexts = listOf("My deadline is tomorrow?"),
        )

        assertEquals(listOf(AutomaticNoteKind.FACT), unclassified.map { it.kind })
        assertTrue(classified.isEmpty())
    }

    @Test
    fun `question exclusion preserves a separate decision from the same final`() {
        val candidates = AutomaticNoteExtractor.extract(
            segment("My deadline is what day. We decided to ship Friday."),
            excludedQuestionTexts = listOf("My deadline is what day"),
        )

        assertEquals(listOf(AutomaticNoteKind.DECISION), candidates.map { it.kind })
        assertEquals("We decided to ship Friday.", candidates.single().text)
    }

    @Test
    fun `short question exclusion does not match inside a separate fact word`() {
        val candidates = AutomaticNoteExtractor.extract(
            segment("Art? Our meeting starts tomorrow."),
            excludedQuestionTexts = listOf("Art?"),
        )

        assertEquals(listOf(AutomaticNoteKind.FACT), candidates.map { it.kind })
        assertEquals("Our meeting starts tomorrow.", candidates.single().text)
    }

    @Test
    fun `embedded wh clauses remain eligible decisions actions and declarative facts`() {
        val statements = listOf(
            "We decided how the migration will proceed.",
            "We agreed when the launch will happen.",
            "I will document how the migration works.",
            "Our meeting is Friday, which gives us three days.",
            "Remember that the workshop explains how the model works.",
            "Our meeting is scheduled when the client is available.",
            "Our project is where the source code lives.",
            "I will document how we organize work.",
            "We decided how Alice will lead the migration.",
            "I will document how Helix handles retries.",
            "Our meeting is scheduled when Alice is available.",
            "We decided what Alice will present.",
            "I will document what Helix supports.",
            "Our deadline is what Alice considers urgent.",
            "Our deadline is what Alice will confirm.",
            "We decided which team will present.",
            "We decided who will present.",
            "We decided whom Alice will invite.",
            "We decided whose team will present.",
            "Our meeting is Friday, which is convenient.",
            "Our deadline is tomorrow, which works well.",
            "We decided to ship Friday, which will leave a week for QA.",
            "My deadline is what matters.",
            "Our project is what works.",
            "We decided what works best.",
        )

        assertEquals(
            listOf(
                AutomaticNoteKind.DECISION,
                AutomaticNoteKind.DECISION,
                AutomaticNoteKind.ACTION_ITEM,
                AutomaticNoteKind.FACT,
                AutomaticNoteKind.FACT,
                AutomaticNoteKind.FACT,
                AutomaticNoteKind.FACT,
                AutomaticNoteKind.ACTION_ITEM,
                AutomaticNoteKind.DECISION,
                AutomaticNoteKind.ACTION_ITEM,
                AutomaticNoteKind.FACT,
                AutomaticNoteKind.DECISION,
                AutomaticNoteKind.ACTION_ITEM,
                AutomaticNoteKind.FACT,
                AutomaticNoteKind.FACT,
                AutomaticNoteKind.DECISION,
                AutomaticNoteKind.DECISION,
                AutomaticNoteKind.DECISION,
                AutomaticNoteKind.DECISION,
                AutomaticNoteKind.FACT,
                AutomaticNoteKind.FACT,
                AutomaticNoteKind.DECISION,
                AutomaticNoteKind.FACT,
                AutomaticNoteKind.FACT,
                AutomaticNoteKind.DECISION,
            ),
            statements.map { statement ->
                AutomaticNoteExtractor.extract(segment(statement)).single().kind
            },
        )
    }

    @Test
    fun `completed high-confidence answer becomes an internal knowledge candidate`() {
        val candidate = AutomaticNoteExtractor.extractAnswer(
            Turn(
                transcript = "What is the capital of France?",
                question = QuestionCandidate("What is the capital of France?", 0.95),
                answer = AnswerResponse(
                    "The capital of France is Paris.",
                    ProviderKind.OPENAI,
                    "gpt-test",
                ),
            ),
        )

        assertEquals(AutomaticNoteKind.ANSWER, candidate!!.kind)
        assertEquals(KnowledgeBucket.FACTS, candidate.bucket)
        assertEquals(
            "Q: What is the capital of France?\nA: The capital of France is Paris.",
            candidate.text,
        )
    }

    @Test
    fun `low-confidence uncertain failed and sensitive answers are not captured`() {
        fun turn(
            confidence: Double = 0.95,
            answer: String = "A concrete answer with enough detail.",
            error: Throwable? = null,
            provider: ProviderKind = ProviderKind.OPENAI,
        ) = Turn(
            transcript = "Please help",
            question = QuestionCandidate("Please help", confidence),
            answer = AnswerResponse(answer, provider, "test-model"),
            error = error,
        )

        assertTrue(AutomaticNoteExtractor.extractAnswer(turn(confidence = 0.72)) == null)
        assertTrue(AutomaticNoteExtractor.extractAnswer(turn(answer = "I'm not sure what the answer is.")) == null)
        assertTrue(AutomaticNoteExtractor.extractAnswer(turn(error = IllegalStateException("failed"))) == null)
        assertTrue(AutomaticNoteExtractor.extractAnswer(turn(answer = "The API key is sk-secret-value.")) == null)
        assertTrue(
            AutomaticNoteExtractor.extractAnswer(
                turn(answer = "It looks like your question got cut off. Could you please repeat it?"),
            ) == null,
        )
        assertTrue(
            AutomaticNoteExtractor.extractAnswer(
                turn().copy(question = QuestionCandidate("Wh", 0.95)),
            ) == null,
        )
    }

    @Test
    fun `qualified credential tokens recovery codes and jwt-like secrets are never captured`() {
        fun answer(text: String) = Turn(
            transcript = "What credential should I use?",
            question = QuestionCandidate("What credential should I use?", 0.95),
            answer = AnswerResponse(text, ProviderKind.OPENAI, "gpt-test"),
        )

        val sensitiveAnswers = listOf(
            "Your access token is access_1234567890abcdef.",
            "Your auth token is auth_1234567890abcdef.",
            "Use Authorization: Bearer abcdefghijklmnopqrstuvwxyz123456.",
            "Your OAuth token is oauth_1234567890abcdef.",
            "Your refresh token is refresh_1234567890abcdef.",
            "Your session token is session_1234567890abcdef.",
            "Your recovery code is ABCD-EFGH-IJKL-MNOP.",
            "Use this credential: eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjM0NTY3ODkwIn0.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c.",
        )

        sensitiveAnswers.forEach { text ->
            assertTrue(text, AutomaticNoteExtractor.extractAnswer(answer(text)) == null)
        }
        assertTrue(
            AutomaticNoteExtractor.extract(
                segment("Remember that my refresh token is refresh_1234567890abcdef."),
            ).isEmpty(),
        )
        assertTrue(
            AutomaticNoteExtractor.extract(
                segment(
                    "Remember that my credential is " +
                        "eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjM0NTY3ODkwIn0." +
                        "SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c.",
                ),
            ).isEmpty(),
        )
        listOf(
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
            "Remember recoveryCode: ABCD-EFGH-IJKL-MNOP.",
        ).forEach { statement ->
            assertTrue(statement, AutomaticNoteExtractor.extract(segment(statement)).isEmpty())
        }
    }

    @Test
    fun `question shaped model answer is never captured`() {
        val candidate = AutomaticNoteExtractor.extractAnswer(
            Turn(
                transcript = "What should we do next?",
                question = QuestionCandidate("What should we do next?", 0.95),
                answer = AnswerResponse(
                    "Could you confirm which environment currently owns this deployment?",
                    ProviderKind.OPENAI,
                    "gpt-test",
                ),
            ),
        )

        assertTrue(candidate == null)

        listOf(
            "What matters is preserving the user's data during migration.",
            "How the cache works is documented in the runtime guide.",
            "When the cache expires, Helix refreshes it from storage.",
        ).forEach { declarativeAnswer ->
            val declarativeTurn = turnWithAnswer(declarativeAnswer)
            assertEquals(
                declarativeAnswer,
                AutomaticNoteExtractor.extractAnswer(declarativeTurn)?.text?.substringAfter("A: "),
            )
        }
    }

    private fun turnWithAnswer(answer: String) = Turn(
        transcript = "What should Helix preserve during migration?",
        question = QuestionCandidate("What should Helix preserve during migration?", 0.95),
        answer = AnswerResponse(answer, ProviderKind.OPENAI, "gpt-test"),
    )

    @Test
    fun `deterministic placeholder answers are never captured`() {
        val candidate = AutomaticNoteExtractor.extractAnswer(
            Turn(
                transcript = "What did we discuss?",
                question = QuestionCandidate("What did we discuss?", 0.95),
                answer = AnswerResponse(
                    "Connect an AI provider key to answer from the conversation.",
                    ProviderKind.DETERMINISTIC,
                    "deterministic-native",
                ),
            ),
        )

        assertTrue(candidate == null)
    }

    @Test
    fun `benign model token concepts remain eligible`() {
        val answerCandidate = AutomaticNoteExtractor.extractAnswer(
            Turn(
                transcript = "How do language models generate text?",
                question = QuestionCandidate("How do language models generate text?", 0.95),
                answer = AnswerResponse(
                    "A language model predicts the next token from context and repeats the process.",
                    ProviderKind.OPENAI,
                    "gpt-test",
                ),
            ),
        )
        val transcriptCandidates = AutomaticNoteExtractor.extract(
            segment("Remember that our model token budget is 128,000 tokens."),
        )

        assertEquals(AutomaticNoteKind.ANSWER, answerCandidate!!.kind)
        assertEquals(listOf(AutomaticNoteKind.FACT), transcriptCandidates.map { it.kind })
    }
}
