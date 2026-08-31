// The built-in assistant skills and skill-id resolution. The first six and all
// of the resolution rules are a verbatim port of the `ActiveSkill` statics in
// NativeHelix/Sources/HelixCore/HelixDomain.swift (builtIns / selectable /
// sanitize / skill(for:)); keep those ids, labels, and prompts byte-identical
// to iOS. The social/conversational skills after them are Android-only for now
// and have no iOS counterpart — an unknown id sanitizes to general-chat, so a
// profile written here stays loadable on iOS.
package com.artjiang.helix.core

object BuiltInSkills {

    const val DEFAULT_VALUE = "general-chat"

    val all: List<ActiveSkill> = listOf(
        ActiveSkill(
            value = "dsa",
            label = "Data Structures & Algorithms",
            prompt = "Answer as a concise algorithms coach. Prefer complexity, invariants, and edge cases.",
            isBuiltIn = true,
        ),
        ActiveSkill(
            value = "programming",
            label = "Programming",
            prompt = "Answer as a pragmatic programming assistant. Prefer concrete implementation steps and tradeoffs.",
            isBuiltIn = true,
        ),
        ActiveSkill(
            value = "system-design",
            label = "System Design",
            prompt = "Answer as a system design interviewer. Prefer architecture, scale limits, bottlenecks, and failure modes.",
            isBuiltIn = true,
        ),
        ActiveSkill(
            value = "behavioral",
            label = "Behavioral Interview",
            // Structure directive formerly lived on ConversationMode.INTERVIEW in
            // PromptBuilder, where it outranked whatever skill was actually active
            // (structure beats tone). STAR is now owned by this skill alone.
            prompt = "Produce a directly speakable first-person answer structured with the " +
                "STAR framework (situation, task, action, result) and close with one " +
                "measurable impact. Write it exactly as the user should say it out loud — " +
                "no coaching, no framing, no commentary about the answer.",
            isBuiltIn = true,
        ),
        ActiveSkill(
            value = "discussion-strategy",
            label = "Discussion Strategy",
            prompt = "Answer with a calm discussion strategy: acknowledge, clarify, and give one useful next move.",
            isBuiltIn = true,
        ),
        ActiveSkill(
            value = "general-chat",
            label = "General Chat",
            prompt = "Answer naturally and directly. Avoid meta phrasing and keep the response speakable.",
            isBuiltIn = true,
        ),
        // Social and conversational skills — Android-only additions, no iOS
        // counterpart yet. Same house rules as the built-ins above: speakable
        // output, no meta phrasing, bounded by maxResponseSentences.
        ActiveSkill(
            value = "friendly-conversation",
            label = "Friendly Conversation",
            prompt = "Answer as warm, natural small talk. Give one speakable line that keeps the conversation moving, and end on an open question when it fits.",
            isBuiltIn = true,
        ),
        ActiveSkill(
            value = "witty",
            label = "Funny / Witty",
            prompt = "Answer with quick, light banter. Give the joke itself — never explain it — and keep it good-natured, never at anyone's expense.",
            isBuiltIn = true,
        ),
        ActiveSkill(
            value = "social-confidence",
            label = "Social Confidence",
            prompt = "Answer as a confident, charming line the wearer can say as-is. Be genuinely interested in the other person, read their signals, and back off gracefully when they are not interested. Never pressure, negotiate, deceive, or negg.",
            isBuiltIn = true,
        ),
        ActiveSkill(
            value = "startup-founder",
            label = "Startup Founder",
            prompt = "Answer as a founder pitching. Lead with the problem, the wedge, and one concrete number; answer investor questions head-on without hedging.",
            isBuiltIn = true,
        ),
        ActiveSkill(
            value = "networking",
            label = "Networking",
            prompt = "Answer as a professional introduction or follow-up. Name the shared context, stay specific, and close with one question that invites them to keep talking.",
            isBuiltIn = true,
        ),
        ActiveSkill(
            value = "debate",
            label = "Debate / Persuasion",
            prompt = "Answer with a structured argument: state the claim, give the strongest reason, and name the best counterpoint before rebutting it.",
            isBuiltIn = true,
        ),
        ActiveSkill(
            value = "language-practice",
            label = "Language Practice",
            prompt = "Answer in the language being practiced, at the speaker's level. When they make a mistake, give the corrected phrasing once, plainly, then continue the conversation.",
            isBuiltIn = true,
        ),
    )

    /** Legacy eval ids from the iOS mock providers, mapped like iOS `sanitize`. */
    private val mockMap = mapOf(
        "mock-dsa" to "dsa",
        "mock-programming" to "programming",
        "mock-system-design" to "system-design",
        "mock-behavioral" to "behavioral",
    )

    /**
     * Built-ins first, then custom skills with a non-empty value and label,
     * deduplicated by value (a custom may not shadow a built-in id).
     */
    fun selectable(customSkills: List<ActiveSkill>): List<ActiveSkill> {
        val seen = all.mapTo(mutableSetOf()) { it.value }
        return all + customSkills.filter { skill ->
            skill.value.isNotEmpty() && skill.label.isNotEmpty() && seen.add(skill.value)
        }
    }

    /** Normalizes a stored skill id to one that exists, else [fallback]. */
    fun sanitize(
        value: String?,
        customSkills: List<ActiveSkill> = emptyList(),
        fallback: String = DEFAULT_VALUE,
    ): String {
        val normalized = value.orEmpty().trim()
        if (normalized.isEmpty()) return fallback
        val mapped = mockMap[normalized] ?: normalized
        return if (selectable(customSkills).any { it.value == mapped }) mapped else fallback
    }

    /** Resolves an id to its skill, falling back to the General Chat built-in. */
    fun skillFor(value: String?, customSkills: List<ActiveSkill> = emptyList()): ActiveSkill {
        val sanitized = sanitize(value, customSkills)
        return selectable(customSkills).firstOrNull { it.value == sanitized }
            ?: all.first { it.value == DEFAULT_VALUE }
    }

    /** "Sales Coaching" -> "sales-coaching"; same regex as the iOS custom-skill sheet. */
    /**
     * A slug that collides with nothing in [taken] nor with a built-in id:
     * built-in collisions get "-custom", remaining collisions get "-2", "-3"…
     * so two similarly named custom skills can never silently overwrite
     * each other.
     */
    fun uniqueSlug(base: String, taken: Set<String>): String {
        val seed = base.ifEmpty { "custom" }
            .let { if (all.any { skill -> skill.value == it }) "$it-custom" else it }
        if (seed !in taken) return seed
        var n = 2
        while ("$seed-$n" in taken) n += 1
        return "$seed-$n"
    }

    fun slugify(label: String): String =
        label.trim()
            .lowercase()
            .replace(Regex("[^a-z0-9]+"), "-")
            .trim('-')
}
