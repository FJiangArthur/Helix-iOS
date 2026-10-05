// Parses the cue-extraction model output (conversate-core/cue-schema.json).
// Tolerates code fences and surrounding prose; anything else is rejected and
// never shown on the lens.
package com.artjiang.helix.conversate

import kotlinx.serialization.Serializable

data class ParsedCue(val type: CueType, val title: String, val body: String, val detail: String?, val entity: String?)

object CueParser {
    const val TITLE_MAX = 24
    const val BODY_MAX = 220
    const val DETAIL_MAX = 1000

    @Serializable
    private data class RawCue(
        val type: String = "",
        val title: String = "",
        val body: String = "",
        val detail: String? = null,
        val entity: String? = null,
    )

    @Serializable
    private data class Envelope(val cues: List<RawCue> = emptyList())

    private val whitespace = Regex("\\s+")

    /** Parsed cues, or null when [raw] holds no decodable cue envelope. */
    fun parse(
        raw: String,
        allowed: Set<CueType> = setOf(CueType.CONCEPT, CueType.BIO, CueType.SUGGESTION),
    ): List<ParsedCue>? {
        val start = raw.indexOf('{')
        val end = raw.lastIndexOf('}')
        if (start < 0 || end <= start) return null
        val envelope = runCatching {
            conversateJson.decodeFromString(Envelope.serializer(), raw.substring(start, end + 1))
        }.getOrNull() ?: return null
        return envelope.cues.mapNotNull { c ->
            val type = runCatching { CueType.valueOf(c.type.trim().uppercase()) }.getOrNull()
            if (type == null || type !in allowed) return@mapNotNull null
            val title = c.title.squash()
            val body = c.body.squash()
            if (title.isEmpty() || body.isEmpty()) return@mapNotNull null
            ParsedCue(
                type = type,
                title = bound(title, TITLE_MAX),
                body = bound(body, BODY_MAX),
                detail = c.detail?.squash()?.takeIf { it.isNotEmpty() }?.let { bound(it, DETAIL_MAX) },
                entity = c.entity?.trim()?.takeIf { it.isNotEmpty() },
            )
        }
    }

    private fun bound(text: String, max: Int) = if (text.length <= max) text else text.take(max - 1) + "~"

    private fun String.squash() = trim().replace(whitespace, " ")
}
