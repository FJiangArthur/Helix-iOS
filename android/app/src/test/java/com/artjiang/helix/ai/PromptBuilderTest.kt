package com.artjiang.helix.ai

import com.artjiang.helix.core.ActiveSkill
import com.artjiang.helix.core.AnswerRequest
import com.artjiang.helix.core.ConversationMode
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class PromptBuilderTest {

    private fun request(
        question: String = "What is retrieval augmented generation?",
        mode: ConversationMode = ConversationMode.GENERAL,
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

    @Test
    fun `every mode bans meta phrasing`() {
        for (mode in ConversationMode.entries) {
            val system = PromptBuilder.systemPrompt(request(mode = mode)).lowercase()
            assertTrue("$mode should ban meta phrasing", system.contains("you could say"))
            assertTrue("$mode should demand direct output", system.contains("answer directly"))
        }
    }

    @Test
    fun `general mode is conversational and not STAR`() {
        val system = PromptBuilder.systemPrompt(request(mode = ConversationMode.GENERAL)).lowercase()
        assertTrue(system.contains("mode: general"))
        assertFalse(system.contains("star"))
    }

    @Test
    fun `interview mode asks for speakable STAR with measurable impact`() {
        val system = PromptBuilder.systemPrompt(request(mode = ConversationMode.INTERVIEW)).lowercase()
        assertTrue(system.contains("star"))
        assertTrue(system.contains("situation"))
        assertTrue(system.contains("result"))
        assertTrue(system.contains("measurable impact"))
        assertTrue(system.contains("speakable"))
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
            request(skill = ActiveSkill(name = "DSA", prompt = "Give complexity and edge cases.")),
        )
        assertTrue(system.contains("Active skill: DSA."))
        assertTrue(system.contains("Give complexity and edge cases."))
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
}
