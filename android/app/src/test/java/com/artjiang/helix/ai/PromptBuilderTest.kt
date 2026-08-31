package com.artjiang.helix.ai

import com.artjiang.helix.core.ActiveSkill
import com.artjiang.helix.core.AnswerRequest
import com.artjiang.helix.core.BuiltInSkills
import com.artjiang.helix.core.ConversationMode
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class PromptBuilderTest {

    private fun request(
        question: String = "What is retrieval augmented generation?",
        mode: ConversationMode = ConversationMode.ACTIVE,
        skill: ActiveSkill = ActiveSkill(),
        sentences: Int = 3,
        context: String = "",
        knowledge: List<String> = emptyList(),
    ) = AnswerRequest(
        question = question,
        mode = mode,
        skill = skill,
        maxResponseSentences = sentences,
        conversationContext = context,
        knowledgeContext = knowledge,
    )

    private fun skill(id: String): ActiveSkill = BuiltInSkills.skillFor(id, emptyList())

    @Test
    fun `every mode bans meta phrasing`() {
        for (mode in ConversationMode.entries) {
            val system = PromptBuilder.systemPrompt(request(mode = mode)).lowercase()
            assertTrue("$mode should ban meta phrasing", system.contains("you could say"))
            assertTrue("$mode should demand direct output", system.contains("answer directly"))
        }
    }

    @Test
    fun `active mode is conversational and carries no structure of its own`() {
        val system = PromptBuilder.systemPrompt(request(mode = ConversationMode.ACTIVE)).lowercase()
        assertTrue(system.contains("mode: active"))
        assertFalse(system.contains("star"))
    }

    @Test
    fun `passive mode restricts output to facts corrections and context`() {
        val system = PromptBuilder.systemPrompt(request(mode = ConversationMode.PASSIVE)).lowercase()
        assertTrue(system.contains("passive listener"))
        assertTrue(system.contains("fact"))
        assertTrue(system.contains("correction"))
        assertTrue(system.contains("context"))
        assertTrue(system.contains("no opinions"))
    }

    // MARK: Skill owns structure, not mode (regression coverage)
    //
    // Root cause of the "Social Confidence still answers like an interview
    // coach" bug: ConversationMode.INTERVIEW used to append a hard STRUCTURAL
    // directive (STAR framework) *after* the skill block, and structure beat
    // tone regardless of which skill was active. STAR now lives only on the
    // `behavioral` skill's own prompt; ConversationMode no longer has an
    // INTERVIEW value at all, so it cannot inject STAR for any skill.

    @Test
    fun `social confidence skill never pulls in STAR interview structure`() {
        val system = PromptBuilder.systemPrompt(
            request(mode = ConversationMode.ACTIVE, skill = skill("social-confidence")),
        )
        assertFalse(system.contains("STAR"))
        assertFalse(system.lowercase().contains("situation, task, action"))
    }

    @Test
    fun `behavioral skill carries STAR interview structure`() {
        val system = PromptBuilder.systemPrompt(
            request(mode = ConversationMode.ACTIVE, skill = skill("behavioral")),
        )
        assertTrue(system.contains("STAR"))
        assertTrue(system.lowercase().contains("situation, task, action"))
    }

    @Test
    fun `skill block precedes mode block in the assembled system prompt`() {
        val system = PromptBuilder.systemPrompt(
            request(mode = ConversationMode.ACTIVE, skill = skill("behavioral")),
        )
        val skillIndex = system.indexOf("Active skill:")
        val modeIndex = system.indexOf("Mode:")
        assertTrue("skill block must come before mode block", skillIndex in 0 until modeIndex)
    }

    @Test
    fun `sentence budget is honored and pluralized`() {
        assertTrue(
            PromptBuilder.systemPrompt(request(sentences = 1)).contains("within 1 short sentence "),
        )
        assertTrue(
            PromptBuilder.systemPrompt(request(sentences = 5)).contains("within 5 short sentences"),
        )
    }

    @Test
    fun `sentence budget is clamped to the supported range`() {
        assertTrue(PromptBuilder.systemPrompt(request(sentences = 0)).contains("within 1 short sentence"))
        assertTrue(PromptBuilder.systemPrompt(request(sentences = 99)).contains("within 10 short sentences"))
    }

    @Test
    fun `active skill prompt is carried into the system prompt`() {
        val system = PromptBuilder.systemPrompt(
            request(skill = ActiveSkill(value = "dsa", label = "DSA", prompt = "Give complexity and edge cases.")),
        )
        assertTrue(system.contains("Active skill: DSA."))
        assertTrue(system.contains("Give complexity and edge cases."))
    }

    @Test
    fun `resolved built-in skill from default settings is carried into the system prompt`() {
        val resolved = com.artjiang.helix.core.HelixSettings().resolvedSkill()
        val system = PromptBuilder.systemPrompt(request(skill = resolved))
        assertTrue(system.contains("Active skill: General Chat."))
        assertTrue(system.contains("Answer naturally and directly."))
    }

    @Test
    fun `legacy v1 skill shape still labels the system prompt via its name`() {
        val system = PromptBuilder.systemPrompt(
            request(skill = ActiveSkill(legacyName = "Sales", prompt = "Sell the outcome.")),
        )
        assertTrue(system.contains("Active skill: Sales."))
        assertTrue(system.contains("Sell the outcome."))
    }

    @Test
    fun `user prompt carries question conversation context and knowledge`() {
        val user = PromptBuilder.userPrompt(
            request(
                question = "How does attention work?",
                context = "Heard: we were discussing transformers",
                knowledge = listOf("Helix ships on G1 glasses", " "),
            ),
        )
        assertTrue(user.startsWith("Question:\nHow does attention work?"))
        assertTrue(user.contains("Recent conversation:\nHeard: we were discussing transformers"))
        assertTrue(user.contains("Knowledge context:\n- Helix ships on G1 glasses"))
        // Blank knowledge entries are dropped rather than emitted as empty bullets.
        assertFalse(user.contains("- \n"))
    }

    @Test
    fun `user prompt omits empty sections`() {
        val user = PromptBuilder.userPrompt(request())
        assertFalse(user.contains("Recent conversation"))
        assertFalse(user.contains("Knowledge context"))
    }

    @Test
    fun `style validator rejects meta phrasing`() {
        assertTrue(AnswerStyleValidator.isDirectSpeakable("I led the migration and cut latency by 40%."))
        assertFalse(AnswerStyleValidator.isDirectSpeakable("You could say that you led the migration."))
        assertFalse(AnswerStyleValidator.isDirectSpeakable("Here's a suggestion: keep it short."))
    }

    // MARK: Recent-context (on-demand) variant

    @Test
    fun `recent context request is recognised by the sentinel only`() {
        assertTrue(PromptBuilder.isRecentContextRequest(request(question = PromptBuilder.RECENT_CONTEXT_QUESTION)))
        assertTrue(PromptBuilder.isRecentContextRequest(request(question = "  ${PromptBuilder.RECENT_CONTEXT_QUESTION}  ")))
        assertFalse(PromptBuilder.isRecentContextRequest(request(question = "What time is it?")))
    }

    @Test
    fun `recent context system prompt swaps the role line and keeps the guardrails`() {
        val req = request(
            question = PromptBuilder.RECENT_CONTEXT_QUESTION,
            mode = ConversationMode.ACTIVE,
            // The skill answers actually run with: the resolved default
            // (General Chat built-in), not a hand-built inline skill.
            skill = com.artjiang.helix.core.HelixSettings().resolvedSkill(),
            sentences = 2,
        )
        val system = PromptBuilder.systemPrompt(req)
        assertTrue(system.contains("last ~60 seconds of a live conversation captured by a wearable"))
        assertTrue(system.contains("Find the most recent question asked of the wearer"))
        assertTrue(system.contains("single most useful fact for the moment"))
        assertTrue(system.lowercase().contains("you could say"))
        assertTrue(system.contains("within 2 short sentences"))
        assertTrue(system.lowercase().contains("mode: active"))
        assertTrue(system.contains("Active skill: General Chat."))
    }

    @Test
    fun `recent context user prompt uses instruction and oldest-first labels`() {
        val req = request(
            question = PromptBuilder.RECENT_CONTEXT_QUESTION,
            context = "Heard: we launch Tuesday\nWhat is our rollback plan?",
            knowledge = listOf("Rollback = feature flag off"),
        )
        val user = PromptBuilder.userPrompt(req)
        assertTrue(user.startsWith("Instruction:\n"))
        assertFalse(user.contains(PromptBuilder.RECENT_CONTEXT_QUESTION))
        assertTrue(user.contains("Recent conversation (oldest first):\nHeard: we launch Tuesday\nWhat is our rollback plan?"))
        assertTrue(user.contains("Knowledge context:\n- Rollback = feature flag off"))
    }

    @Test
    fun `auto-detect prompt is unchanged by the recent-context variant`() {
        val user = PromptBuilder.userPrompt(request(question = "What is RAG?", context = "Heard: hi"))
        assertTrue(user.startsWith("Question:\nWhat is RAG?"))
        assertTrue(user.contains("Recent conversation:\nHeard: hi"))
        assertFalse(user.contains("oldest first"))
        val system = PromptBuilder.systemPrompt(request(question = "What is RAG?"))
        assertFalse(system.contains("wearable"))
    }
}
