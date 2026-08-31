// Port of NativeHelix/Sources/HelixConversation/PassiveTriggerClassifier.swift
// (heuristic tier only — the optional live LLM classifier tier is out of scope
// for the Android v1 port, matching the transcription backend scope cut) and of
// PassiveCorrectionDetector from ConversationEngine.swift.
package com.artjiang.helix.ai

/** What passive mode should do with a transcript segment. */
enum class PassiveTriggerAction { ANSWER, IGNORE, WAIT }

enum class PassiveTriggerKind {
    DIRECT_QUESTION,
    IMPLICIT_ASK,
    RHETORICAL,
    MONOLOGUE,
    FILLER,
    AMBIGUOUS,
}

data class PassiveTriggerResult(
    val action: PassiveTriggerAction,
    val kind: PassiveTriggerKind,
    val confidence: Double,
    val reason: String,
)

/**
 * Passive Listener gate: decides whether a segment is an actual ask worth
 * answering, or conversation to stay silent about. Without this gate the
 * "silent monitor" mode answered every detected question — the exact behavior
 * the mode exists to prevent.
 */
class PassiveTriggerClassifier {

    fun decision(text: String): PassiveTriggerResult {
        val trimmed = text.trim()
        val normalized = normalize(trimmed)
        if (normalized.isEmpty()) {
            return PassiveTriggerResult(
                PassiveTriggerAction.IGNORE, PassiveTriggerKind.FILLER, 0.98, "Empty passive segment.",
            )
        }

        if (normalized in FILLER_PHRASES) {
            return PassiveTriggerResult(
                PassiveTriggerAction.IGNORE, PassiveTriggerKind.FILLER, 0.96, "Filler or acknowledgement.",
            )
        }

        val words = normalized.split(' ')
        val isQuestionSuffix = trimmed.endsWith("?") || trimmed.endsWith("？")
        if (isQuestionSuffix ||
            QUESTION_PREFIXES.any { normalized == it || normalized.startsWith("$it ") }
        ) {
            return PassiveTriggerResult(
                PassiveTriggerAction.ANSWER, PassiveTriggerKind.DIRECT_QUESTION, 0.95, "Direct question detected.",
            )
        }

        if (RHETORICAL_MARKERS.any { normalized.contains(it) }) {
            return PassiveTriggerResult(
                PassiveTriggerAction.IGNORE, PassiveTriggerKind.RHETORICAL, 0.83, "Rhetorical or self-directed phrasing.",
            )
        }

        if (IMPLICIT_ASK_MARKERS.any { normalized.contains(it) }) {
            return PassiveTriggerResult(
                PassiveTriggerAction.ANSWER, PassiveTriggerKind.IMPLICIT_ASK, 0.78, "Implicit help request detected.",
            )
        }

        if (words.size < 4) {
            return PassiveTriggerResult(
                PassiveTriggerAction.WAIT, PassiveTriggerKind.AMBIGUOUS, 0.64, "Too short for a passive answer.",
            )
        }

        if (normalized.contains(" i wonder ") || normalized.startsWith("i wonder ")) {
            return PassiveTriggerResult(
                PassiveTriggerAction.WAIT, PassiveTriggerKind.AMBIGUOUS, 0.58, "Ambiguous thought, waiting for more context.",
            )
        }

        return PassiveTriggerResult(
            PassiveTriggerAction.IGNORE, PassiveTriggerKind.MONOLOGUE, 0.82, "No help request detected.",
        )
    }

    companion object {
        private val QUESTION_PREFIXES = listOf(
            "what", "why", "how", "when", "where", "who", "which",
            "can", "could", "should", "would", "is", "are", "do", "does",
            "tell me", "explain", "walk me through",
        )

        private val IMPLICIT_ASK_MARKERS = listOf(
            "i am stuck",
            "i'm stuck",
            "i dont know how",
            "i don't know how",
            "need help",
            "can someone explain",
            "not sure how",
            "help me",
            "walk me through",
        )

        private val RHETORICAL_MARKERS = listOf(
            "you know what i mean",
            "isn't it",
            "right?",
            "does that make sense",
        )

        private val FILLER_PHRASES = setOf(
            "ok", "okay", "yeah", "yes", "no", "right",
            "thanks", "thank you", "um", "uh", "mm hmm", "got it",
        )

        // Was `[^a-z0-9 '?]`, which stripped EVERY CJK character — in Passive
        // mode that meant a Chinese utterance could only ever be routed to
        // ANSWER via a literal "？" (isQuestionSuffix, checked on the
        // un-normalized `trimmed` string above); every other passive-trigger
        // path (rhetorical/implicit-ask markers, filler, the word-count
        // check) saw an empty or near-empty string for Chinese speech and
        // fell through to IGNORE/MONOLOGUE. `\\p{L}` (Unicode "any letter")
        // keeps CJK ideographs alongside Latin letters and digits.
        private val NON_WORD = Regex("[^\\p{L}0-9 '?]")
        private val SPACES = Regex(" +")

        fun normalize(value: String): String =
            value.lowercase()
                .replace(NON_WORD, " ")
                .replace(SPACES, " ")
                .trim()
    }
}

/**
 * Passive false-claim corrector: when a monitored claim is heard, emit its
 * correction instead of an LLM answer.
 */
class PassiveCorrectionDetector(
    private val falseClaims: Map<String, String> = mapOf(
        "rag means random answer generation" to "RAG means retrieval augmented generation.",
    ),
) {
    /** The correction for a false claim contained in [text], or null. */
    fun reminder(text: String): String? {
        val lowered = text.lowercase()
        return falseClaims.entries.firstOrNull { lowered.contains(it.key) }?.value
    }
}
