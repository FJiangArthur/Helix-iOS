// Live caption text for the lens: committed finals plus the current partial,
// word-wrapped to HUD lines (spec §5.3 "Captions use partials").
package com.artjiang.helix.conversate

import com.artjiang.helix.core.TranscriptSegment
import com.artjiang.helix.g1.HudPaginator

class CaptionBuffer(
    private val paginator: HudPaginator = HudPaginator(),
    private val maxLines: Int = 5,
    private val keepFinals: Int = 12,
) {
    private val finals = ArrayDeque<String>()
    private var partial = ""

    fun onSegment(segment: TranscriptSegment) {
        val text = segment.text.trim()
        if (segment.isFinal) {
            if (text.isNotEmpty()) finals.addLast(text)
            while (finals.size > keepFinals) finals.removeFirst()
            partial = ""
        } else {
            partial = text
        }
    }

    fun lines(): List<String> {
        val joined = (finals + partial).filter { it.isNotBlank() }.joinToString(" ")
        if (joined.isBlank()) return emptyList()
        return paginator.lines(joined).takeLast(maxLines)
    }

    fun clear() { finals.clear(); partial = "" }
}
