package com.artjiang.helix.ai

import com.artjiang.helix.core.AnswerRequest
import com.artjiang.helix.core.ConversationMode

/**
 * The single source of truth for provider prompts.
 *
 * The Swift port duplicated an identical `systemPrompt`/`userPrompt` pair in both
 * `OpenAIAdapters.swift` and `AnthropicAdapters.swift`, and neither varied by
 * [ConversationMode] — an interview-mode question got exactly the same system
 * prompt as a passive one. Here there is one implementation, and mode is honored.
 */
data class Prompt(val system: String, val user: String)

object PromptBuilder {

    /** Meta phrasing that must never appear in an answer; enforced by prompt and validator. */
    val BANNED_PHRASES: List<String> = listOf(
        "you could say",
        "here's a suggestion",
        "here is a suggestion",
        "you might say",
        "try saying",
    )

    fun build(request: AnswerRequest): Prompt =
        Prompt(system = systemPrompt(request), user = userPrompt(request))

    fun systemPrompt(request: AnswerRequest): String {
        val sentences = request.maxResponseSentences.coerceIn(1, 10)
        val plural = if (sentences == 1) "sentence" else "sentences"

        val lines = mutableListOf(
            "You are Helix, a real-time assistant for smart glasses.",
            "Answer directly with speakable wording. Never use meta phrases like " +
                "\"you could say\", \"here's a suggestion\", or \"try saying\" — " +
                "output only the words the user should speak or read.",
            "Keep the answer within $sentences short $plural unless the user asks otherwise.",
        )

        lines += when (request.mode) {
            ConversationMode.GENERAL ->
                "Mode: general. Answer the question factually and conversationally, " +
                    "leading with the single most useful point."

            ConversationMode.INTERVIEW ->
                "Mode: interview coach. Produce a directly speakable first-person answer " +
                    "structured with the STAR framework (situation, task, action, result) and " +
                    "close with one measurable impact. Write it exactly as the user should say " +
                    "it out loud — no coaching, no framing, no commentary about the answer."

            ConversationMode.PASSIVE ->
                "Mode: passive listener. Stay silent on anything conversational. Surface only a " +
                    "verifiable fact, a correction of something stated incorrectly, or missing " +
                    "context that changes the meaning. No opinions, no advice, no pleasantries."
        }

        val skillName = request.skill.name.trim()
        val skillPrompt = request.skill.prompt.trim()
        if (skillName.isNotEmpty() || skillPrompt.isNotEmpty()) {
            val label = skillName.ifEmpty { "Assistant" }
            lines += if (skillPrompt.isEmpty()) "Active skill: $label." else "Active skill: $label. $skillPrompt"
        }

        return lines.joinToString(" ")
    }

    fun userPrompt(request: AnswerRequest): String {
        val sections = mutableListOf("Question:\n${request.question.trim()}")

        val context = request.conversationContext.trim()
        if (context.isNotEmpty()) {
            sections += "Recent conversation:\n$context"
        }

        val knowledge = request.knowledgeContext.map { it.trim() }.filter { it.isNotEmpty() }
        if (knowledge.isNotEmpty()) {
            sections += "Knowledge context:\n" + knowledge.joinToString("\n") { "- $it" }
        }

        return sections.joinToString("\n\n")
    }
}

/** Guards against meta phrasing leaking into a rendered HUD answer. */
object AnswerStyleValidator {
    fun isDirectSpeakable(answer: String): Boolean {
        val lowered = answer.lowercase()
        return PromptBuilder.BANNED_PHRASES.none { lowered.contains(it) }
    }
}
