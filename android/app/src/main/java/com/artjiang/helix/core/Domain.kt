// Shared domain contract for the Helix Android port. Mirrors
// NativeHelix/Sources/HelixCore/HelixDomain.swift. All modules code against
// these types; extend within your own package rather than editing here.
package com.artjiang.helix.core

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/**
 * Whether Helix is actively answering (any style, any skill) or silently
 * listening for facts/corrections. Structure (STAR, algorithms-coach shape,
 * etc.) is owned entirely by the active skill's prompt now — mode is no
 * longer allowed to carry an output-shape directive. Previously this had a
 * third value, INTERVIEW, whose STAR directive outranked the active skill's
 * own tone/structure (fixed skill selection had no visible effect while
 * INTERVIEW was selected); GENERAL and INTERVIEW have merged into ACTIVE.
 */
enum class ConversationMode { ACTIVE, PASSIVE }

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
)

/**
 * One assistant skill: a stable slug id ([value]), a display [label], and the
 * system-prompt fragment that shapes answers while the skill is active.
 * Mirrors iOS `ActiveSkill` in HelixDomain.swift (value/label/prompt/isBuiltIn).
 *
 * The v1 Android shape was `{name, prompt}` (a single overwritable skill).
 * [legacyName] keeps that JSON decodable; `SettingsRepository` migrates a
 * stored legacy skill into [HelixSettings.customSkills] on read.
 */
@Serializable
data class ActiveSkill(
    val value: String = "",
    val label: String = "",
    val prompt: String = "",
    val isBuiltIn: Boolean = false,
    @SerialName("name") val legacyName: String = "",
) {
    /**
     * Legacy accessor kept for pre-migration call sites (the deterministic
     * provider's skill check): the stable id, falling back to the v1 name.
     */
    val name: String get() = value.ifEmpty { legacyName }
}

@Serializable
data class HelixSettings(
    val mode: ConversationMode = ConversationMode.ACTIVE,
    val autoDetectQuestions: Boolean = true,
    val autoAnswer: Boolean = true,
    val factCheck: Boolean = true,
    val insightsEnabled: Boolean = false,
    val bitmapHud: Boolean = true,
    val maxResponseSentences: Int = 3,
    val activeProvider: String = "OPENAI",
    // Skill selection mirrors iOS HelixSettings: an id into the built-in +
    // custom skill set, never an inline skill value.
    val activeSkillID: String = BuiltInSkills.DEFAULT_VALUE,
    val customSkills: List<ActiveSkill> = emptyList(),
    /**
     * Deprecated v1 field (`activeSkill {name, prompt}`), retained so old
     * stored blobs decode. `SettingsRepository` migrates it into
     * [customSkills] + [activeSkillID] on read and nulls it; the migrated
     * shape persists on the first settings write. New code must use
     * [resolvedSkill] instead.
     */
    @SerialName("activeSkill") val legacyActiveSkill: ActiveSkill? = null,
    val providers: Map<String, ProviderConfiguration> = defaultProviders(),
) {
    /** The skill answers use right now: built-ins + customs by id, fallback General Chat. */
    fun resolvedSkill(): ActiveSkill = BuiltInSkills.skillFor(activeSkillID, customSkills)

    /** Picker contents: the six built-ins plus valid, deduplicated customs. */
    fun selectableSkills(): List<ActiveSkill> = BuiltInSkills.selectable(customSkills)

    companion object {
        fun defaultProviders(): Map<String, ProviderConfiguration> = mapOf(
            "OPENAI" to ProviderConfiguration("OPENAI", "gpt-4.1", "gpt-4.1-mini"),
            "ANTHROPIC" to ProviderConfiguration("ANTHROPIC", "claude-sonnet-4-5", "claude-haiku-4-5"),
            "DEEPSEEK" to ProviderConfiguration("DEEPSEEK", "deepseek-v4-flash", "deepseek-v4-flash"),
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
    /**
     * Source-provided speaker label, or null when the source cannot diarize.
     * Only Omi supplies this: OpenAI's realtime API returns no speaker labels
     * (diarization exists only in the file-based gpt-4o-transcribe-diarize),
     * and Android's on-device recognizer has never supported it.
     */
    val speaker: String? = null,
    /**
     * True only when the source explicitly identifies the wearer. Undiarized
     * phone/OpenAI speech defaults false and remains "Unknown speaker" in the
     * chat instead of being invented as "You".
     */
    val isUser: Boolean = false,
)

data class QuestionCandidate(val text: String, val confidence: Double)

@Serializable
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
    // Serialized by enum name ("FACTS"), so stored items written by the old
    // String field decode unchanged — and a free-typed bucket string can no
    // longer create items invisible to every bucket filter.
    val bucket: KnowledgeBucket,
    val text: String,
    val source: String = "Manual",
    val createdAtMillis: Long,
)

/**
 * Answer provider contract implemented in the ai package.
 *
 * Streaming is an OPTIONAL capability expressed as one default-valued
 * parameter rather than a second interface: every caller that does not care
 * about tokens keeps calling `answer(request)` unchanged, and a provider that
 * cannot stream (or chooses not to) simply ignores [onDelta] and returns the
 * whole text at once. [AnswerResponse] stays the single terminal value in
 * every case, so `ConversationEngine`/`Turn` semantics are identical whether
 * the answer arrived in one piece or a hundred.
 *
 * Contract for implementations that DO stream:
 *  - [onDelta] receives incremental text chunks, in order, never the running
 *    total — the accumulated concatenation must equal [AnswerResponse.text]
 *    modulo the trailing/leading trim applied to the final value.
 *  - [onDelta] is invoked on the provider's IO context and must be cheap and
 *    non-blocking; callers hop to their own dispatcher.
 *  - It is never invoked after [answer] returns or throws.
 */
interface AnswerProvider {
    val kind: ProviderKind
    val model: String
    suspend fun answer(request: AnswerRequest, onDelta: ((String) -> Unit)? = null): AnswerResponse

    /**
     * Raw classification call: send [prompt] as-is (no [AnswerRequest], no
     * persona/mode/skill system prompt from PromptBuilder) and return the
     * model's raw text response. Used by `LlmQuestionDetector`, which needs a
     * compact "list the questions in this text" completion, not an assistant
     * answer — routing that through [answer] would wrap it in Helix's
     * conversational persona prompt and confuse the model into trying to
     * *answer* the transcript instead of classifying it, while also spending
     * the much larger answer token budget on a call that should be cheap.
     *
     * Default implementation falls back to [answer] with an empty
     * [AnswerRequest] shape for providers that have no cheaper path (keeps
     * every existing [AnswerProvider] implementation source-compatible).
     * Real network providers override this with their own small-budget call.
     */
    suspend fun classify(prompt: String): String =
        answer(
            AnswerRequest(
                question = prompt,
                mode = ConversationMode.ACTIVE,
                skill = ActiveSkill(),
                maxResponseSentences = 1,
            ),
        ).text
}
