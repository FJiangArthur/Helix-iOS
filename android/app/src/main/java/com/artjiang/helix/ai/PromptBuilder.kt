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

    /**
     * Sentinel [AnswerRequest.question] for the on-demand path: the request
     * carries the last ~60 s of conversation in `conversationContext` and the
     * model is asked to find and answer the most recent question itself.
     */
    const val RECENT_CONTEXT_QUESTION = "__helix_recent_context__"

    /** The instruction line the model sees in place of a literal question. */
    const val RECENT_CONTEXT_INSTRUCTION =
        "Answer the most recent question asked of the wearer in the conversation below, " +
            "or address the point that most needs an answer."

    fun isRecentContextRequest(request: AnswerRequest): Boolean =
        request.question.trim() == RECENT_CONTEXT_QUESTION

    fun build(request: AnswerRequest): Prompt =
        Prompt(system = systemPrompt(request), user = userPrompt(request))

    fun systemPrompt(request: AnswerRequest): String {
        val sentences = request.maxResponseSentences.coerceIn(1, 10)
        val plural = if (sentences == 1) "sentence" else "sentences"

        val role = if (isRecentContextRequest(request)) {
            "You are Helix, a real-time assistant for smart glasses. The user will give you " +
                "the last ~60 seconds of a live conversation captured by a wearable. Find the " +
                "most recent question asked of the wearer, or the point that needs an answer, " +
                "and answer it directly so the wearer can say or read it. If nothing needs an " +
                "answer, reply with the single most useful fact for the moment."
        } else {
            "You are Helix, a real-time assistant for smart glasses."
        }

        val lines = mutableListOf(
            role,
            "Answer directly with speakable wording. Never use meta phrases like " +
                "\"you could say\", \"here's a suggestion\", or \"try saying\" — " +
                "output only the words the user should speak or read.",
            "Keep the answer within $sentences short $plural unless the user asks otherwise.",
        )

        // Skill owns structure and comes first: it is the more specific,
        // user-chosen directive. Mode is emitted after and must stay
        // non-structural (tone/verbosity only) so it can never outrank the
        // skill's output shape the way ConversationMode.INTERVIEW's STAR
        // directive used to outrank e.g. Social Confidence.
        //
        // Display label first (built-ins/customs), then the legacy accessor
        // for pre-migration skills that only carried a v1 name.
        val skillName = request.skill.label.trim().ifEmpty { request.skill.name.trim() }
        val skillPrompt = request.skill.prompt.trim()
        if (skillName.isNotEmpty() || skillPrompt.isNotEmpty()) {
            val label = skillName.ifEmpty { "Assistant" }
            lines += if (skillPrompt.isEmpty()) "Active skill: $label." else "Active skill: $label. $skillPrompt"
        }

        lines += when (request.mode) {
            ConversationMode.ACTIVE ->
                "Mode: active. Answer the question directly and conversationally, " +
                    "leading with the single most useful point. Follow the active skill above " +
                    "for tone and structure."

            ConversationMode.PASSIVE ->
                "Mode: passive listener. Stay silent on anything conversational. Surface only a " +
                    "verifiable fact, a correction of something stated incorrectly, or missing " +
                    "context that changes the meaning. No opinions, no advice, no pleasantries."
        }

        return lines.joinToString(" ")
    }

    fun userPrompt(request: AnswerRequest): String {
        val recentContext = isRecentContextRequest(request)
        val sections = mutableListOf(
            if (recentContext) "Instruction:\n$RECENT_CONTEXT_INSTRUCTION" else "Question:\n${request.question.trim()}",
        )

        val context = request.conversationContext.trim()
        if (context.isNotEmpty()) {
            sections += if (recentContext) {
                "Recent conversation (oldest first):\n$context"
            } else {
                "Recent conversation:\n$context"
            }
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
