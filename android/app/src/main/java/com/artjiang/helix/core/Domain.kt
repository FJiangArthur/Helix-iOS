// Shared domain contract for the Helix Android port. Mirrors
// NativeHelix/Sources/HelixCore/HelixDomain.swift. All modules code against
// these types; extend within your own package rather than editing here.
package com.artjiang.helix.core

import kotlinx.serialization.Serializable

enum class ConversationMode { GENERAL, INTERVIEW, PASSIVE }

enum class ProviderKind(val displayName: String) {
    OPENAI("OpenAI"),
    ANTHROPIC("Anthropic"),
    DEEPSEEK("DeepSeek"),
    QWEN("Qwen"),
    ZHIPU("Zhipu"),
    DETERMINISTIC("Deterministic");
}

@Serializable
data class ProviderConfiguration(
    val kind: String,
    val smartModel: String,
    val lightModel: String,
    val hasKey: Boolean = false,
)

@Serializable
data class ActiveSkill(
    val name: String = "Assistant",
    val prompt: String = "Concise answers for live conversation.",
)

@Serializable
data class HelixSettings(
    val mode: ConversationMode = ConversationMode.GENERAL,
    val autoDetectQuestions: Boolean = true,
    val autoAnswer: Boolean = true,
    val factCheck: Boolean = true,
    val insightsEnabled: Boolean = false,
    val bitmapHud: Boolean = true,
    val maxResponseSentences: Int = 3,
    val activeProvider: String = "OPENAI",
    val activeSkill: ActiveSkill = ActiveSkill(),
    val providers: Map<String, ProviderConfiguration> = defaultProviders(),
) {
    companion object {
        fun defaultProviders(): Map<String, ProviderConfiguration> = mapOf(
            "OPENAI" to ProviderConfiguration("OPENAI", "gpt-4.1", "gpt-4.1-mini"),
            "ANTHROPIC" to ProviderConfiguration("ANTHROPIC", "claude-sonnet-4-5", "claude-haiku-4-5"),
            "DEEPSEEK" to ProviderConfiguration("DEEPSEEK", "deepseek-chat", "deepseek-chat"),
            "QWEN" to ProviderConfiguration("QWEN", "qwen-max", "qwen-turbo"),
            "ZHIPU" to ProviderConfiguration("ZHIPU", "glm-4", "glm-4-flash"),
        )
    }
}

data class AnswerRequest(
    val question: String,
    val mode: ConversationMode,
    val skill: ActiveSkill,
    val maxResponseSentences: Int,
    val conversationContext: String = "",
    val knowledgeContext: List<String> = emptyList(),
)

data class AnswerResponse(
    val text: String,
    val providerKind: ProviderKind,
    val model: String,
)

/** A finalized transcript segment from any transcription backend. */
data class TranscriptSegment(
    val text: String,
    val isFinal: Boolean,
    val timestampMillis: Long,
)

data class QuestionCandidate(val text: String, val confidence: Double)

data class SessionSummary(
    val id: String,
    val title: String,
    val answerPreview: String,
    val transcriptTurns: List<String>,
    val answerCount: Int,
    val createdAtMillis: Long,
)

enum class KnowledgeBucket { PROJECTS, FACTS, MEMORIES, TODOS }

@Serializable
data class KnowledgeItem(
    val id: String,
    val bucket: String,
    val text: String,
    val source: String = "Manual",
    val createdAtMillis: Long,
)

/** Streaming answer provider contract implemented in the ai package. */
interface AnswerProvider {
    val kind: ProviderKind
    val model: String
    suspend fun answer(request: AnswerRequest): AnswerResponse
}
