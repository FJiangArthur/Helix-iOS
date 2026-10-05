// Renders a ScreenModel to one 5-line G1 text frame (spec §5.2).
package com.artjiang.helix.conversate

import com.artjiang.helix.g1.HudPaginator

data class HudFrame(val text: String, val page: Int = 1, val pageCount: Int = 1)

class G1HudComposer(private val paginator: HudPaginator = HudPaginator()) {
    private val width = paginator.maxCharactersPerLine
    private val rows = paginator.linesPerPage

    fun compose(screen: ScreenModel): HudFrame? = when (screen) {
        ScreenModel.Blank -> null
        is ScreenModel.Live -> live(screen)
        is ScreenModel.Menu -> HudFrame(menu(screen))
        is ScreenModel.CueDetail -> paged(detailText(screen.cue), screen.page)
        is ScreenModel.PrepNoteView -> paged("${screen.title}\n${screen.text}", screen.page)
        ScreenModel.ConfirmEnd -> HudFrame("End session?\n\nDouble-tap again to end\nAny other tap cancels")
    }

    fun detailPageCount(cue: Cue): Int = pages(detailText(cue)).size

    fun textPageCount(text: String): Int = pages(text).size

    /** HudPaginator.lines() splits on spaces only, so honour explicit newlines here. */
    private fun pages(text: String): List<String> =
        text.split("\n").flatMap { para -> if (para.isBlank()) listOf("") else paginator.lines(para) }
            .chunked(rows).map { it.joinToString("\n") }.ifEmpty { listOf("") }

    private fun live(s: ScreenModel.Live): HudFrame? {
        if (s.paused) return HudFrame("${HudGlyphs.PAUSED} Paused\nHold left pad for menu")
        val cue = s.cue
        if (cue != null) {
            val header = fit("${HudGlyphs.CUE} ${cue.type.label}  ${cue.title}")
            val body = paginator.lines(cue.body).toMutableList()
            val more = cue.detail != null || body.size > 2
            val shown = body.take(2).toMutableList()
            while (shown.size < 2) shown += ""
            if (more) {
                val i = shown.indexOfLast { it.isNotEmpty() }.coerceAtLeast(0)
                shown[i] = fit(shown[i], reserve = HudGlyphs.MORE.length + 1) + " " + HudGlyphs.MORE
            }
            val caption = if (s.captionsOn) s.captionLines.lastOrNull().orEmpty() else ""
            return HudFrame(listOf(header, shown[0], shown[1], HudGlyphs.RULE, fit(caption)).joinToString("\n"))
        }
        val captionRows = if (s.captionsOn) s.captionLines.map(::fit) else emptyList()
        if (s.pendingCount > 0) {
            val head = "${HudGlyphs.CUE} ${s.pendingCount} new cue${if (s.pendingCount == 1) "" else "s"}"
            return HudFrame((listOf(head) + captionRows.takeLast(rows - 1)).joinToString("\n"))
        }
        if (captionRows.isEmpty()) return if (s.captionsOn) HudFrame("") else null
        return HudFrame(captionRows.takeLast(rows).joinToString("\n"))
    }

    private fun menu(s: ScreenModel.Menu): String {
        val visible = rows - 1
        val start = (s.cursor / visible) * visible
        val counter = "${s.cursor + 1}/${s.items.size}"
        val title = s.title.take(width - counter.length - 1)
        val header = title + " ".repeat((width - title.length - counter.length).coerceAtLeast(1)) + counter
        val lines = s.items.drop(start).take(visible).mapIndexed { i, item ->
            val prefix = if (start + i == s.cursor) "${HudGlyphs.CURSOR} " else "  "
            fit(prefix + item)
        }
        return (listOf(header) + lines).joinToString("\n")
    }

    private fun detailText(cue: Cue) = "${HudGlyphs.CUE} ${cue.type.label}  ${cue.title}\n${cue.detail ?: cue.body}"

    private fun paged(text: String, page: Int): HudFrame {
        val pages = pages(text)
        val index = page.coerceIn(0, pages.size - 1)
        return HudFrame(pages[index], index + 1, pages.size)
    }

    private fun fit(text: String, reserve: Int = 0): String {
        val max = width - reserve
        return if (text.length <= max) text else text.take(max - 1).trimEnd() + "~"
    }
}
