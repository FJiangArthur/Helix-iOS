package com.artjiang.helix.g1

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Tests for the streaming scroll model.
 *
 * These are written to FAIL if the append-only property is removed. The
 * tempting "simple" implementation — re-wrap the whole accumulated string on
 * every update — passes a naive "the text is all there" assertion but breaks
 * [growingTextNeverChangesAnAlreadyEmittedLine], which is the property that
 * actually makes the HUD scroll instead of flash.
 */
class HudLineStreamTest {

    /** Narrow lines keep the fixtures readable and the boundaries unambiguous. */
    private fun stream(charsPerLine: Int = 10, window: Int = 5) =
        HudLineStream(
            paginator = HudPaginator(maxCharactersPerLine = charsPerLine),
            windowSize = window,
        )

    /**
     * Feeds [text] one character at a time, the way a token stream grows.
     * Returns every frame produced along the way.
     */
    private fun feedByCharacter(stream: HudLineStream, text: String): List<HudLineStream.Frame> {
        val frames = mutableListOf<HudLineStream.Frame>()
        for (i in 1..text.length) {
            stream.update(text.substring(0, i))?.let { frames.add(it) }
        }
        return frames
    }

    // MARK: - The anti-reflow invariant

    /**
     * THE load-bearing test: what has been PAINTED must never change.
     *
     * This asserts on the rendered frames — the actual whole-screen writes — not
     * on internal bookkeeping, because the frame is what the wearer sees.
     *
     * The invariant: successive frames are append-only. Frame N+1 must contain
     * frame N's lines as a prefix of its own visible content (allowing for the
     * window sliding off the top). A line that was displayed is never rewritten,
     * re-split, or retracted.
     *
     * A naive implementation that re-wraps the whole accumulated string fails
     * this, because a streamed answer arrives CHARACTER by character: at a
     * 12-char budget "alpha beta g" renders "g" at the end of line 1, and one
     * character later "alpha beta ga" yanks it down to line 2. That partial-word
     * yank is the flash. See the HudLineStream KDoc.
     */
    @Test
    fun paintedLinesAreNeverRewritten() {
        val stream = stream(charsPerLine = 12, window = 5)
        val answer = "The quarterly review moved to Thursday afternoon because " +
            "the finance team needed extra time to close the books properly"

        // Every line ever displayed, in order, keyed by its absolute index.
        val painted = mutableMapOf<Int, String>()

        fun record(frame: HudLineStream.Frame) {
            // The frame is the trailing window, so its first line sits at
            // absolute index totalLines - frame.lines.size.
            val base = frame.totalLines - frame.lines.size
            frame.lines.forEachIndexed { offset, line ->
                val absolute = base + offset
                val previous = painted[absolute]
                if (previous != null) {
                    assertEquals(
                        "line $absolute was displayed as '$previous' and later " +
                            "changed to '$line' — the display reflowed instead " +
                            "of scrolling",
                        previous,
                        line,
                    )
                }
                painted[absolute] = line
            }
        }

        for (i in 1..answer.length) {
            stream.update(answer.substring(0, i))?.let(::record)
        }
        stream.finish()?.let(::record)

        // Sanity: nothing was lost or duplicated by freezing lines early.
        val rendered = (0 until painted.size).map { painted.getValue(it) }
        assertEquals(answer, rendered.joinToString(" "))
        assertTrue("this fixture must span several lines", rendered.size > 5)
    }

    /**
     * The partial-word yank, isolated and pinned directly.
     *
     * Reproduces the exact character sequence that breaks a whole-string
     * re-wrap: at a 12-char budget, "alpha beta g" fits on one line but
     * "alpha beta ga" does not. A word must never be painted on a line it will
     * then be pushed off.
     */
    @Test
    fun aWordIsNeverPaintedOnALineItWillBePushedOffOf() {
        val stream = stream(charsPerLine = 12, window = 5)
        val answer = "alpha beta gammagamma delta"

        val seen = mutableListOf<List<String>>()
        for (i in 1..answer.length) {
            stream.update(answer.substring(0, i))?.let { seen.add(it.lines) }
        }
        stream.finish()?.let { seen.add(it.lines) }

        // No frame may ever have shown "alpha beta g" — a fragment of the word
        // "gammagamma" sitting on line 1, which the next character retracts.
        seen.forEach { frame ->
            frame.forEach { line ->
                assertTrue(
                    "painted '$line' — a partial word was committed to a line " +
                        "and then moved; that is the streaming flash",
                    line == "alpha beta" || !line.startsWith("alpha beta "),
                )
            }
        }
        assertEquals(listOf("alpha beta", "gammagamma", "delta"), seen.last())
    }

    /**
     * A word still being emitted token-by-token must not be committed to a line
     * and then grow. "Thu" -> "Thurs" -> "Thursday" is one line entry, not three.
     */
    @Test
    fun aPartiallyEmittedWordIsNeverFrozenIntoALine() {
        val stream = stream(charsPerLine = 10)
        stream.update("alpha ")
        stream.update("alpha Thu")
        stream.update("alpha Thurs")
        stream.update("alpha Thursday")
        stream.finish()

        // "alpha Thursday" is 14 chars > 10, so it wraps to two lines — but
        // "Thursday" appears exactly once, whole.
        assertEquals(listOf("alpha", "Thursday"), stream.emittedLines())
    }

    // MARK: - One frame per completed line

    /**
     * A line is frozen only when the NEXT word will not fit on it — that is
     * what guarantees it can never change afterwards. So "one two | three four |
     * five six" yields two frames from [HudLineStream.update] (the two lines
     * that filled) and the third from [HudLineStream.finish], which flushes the
     * still-open trailing line.
     */
    @Test
    fun aFrameIsProducedOncePerCompletedLineNotPerUpdate() {
        val stream = stream(charsPerLine = 10)
        val text = "one two three four five six "
        val frames = feedByCharacter(stream, text).toMutableList()

        // 28 update() calls, but only one frame per COMPLETED line.
        assertEquals(
            "expected one frame per completed line, got ${frames.map { it.lines }}",
            2,
            frames.size,
        )
        assertEquals(listOf("one two"), frames[0].lines)
        assertEquals(listOf("one two", "three four"), frames[1].lines)

        stream.finish()?.let { frames.add(it) }
        assertEquals(3, frames.size)
        assertEquals(listOf("one two", "three four", "five six"), frames[2].lines)
        assertEquals(3, frames[2].totalLines)
    }

    @Test
    fun updateWithUnchangedTextReturnsNull() {
        val stream = stream()
        stream.update("hello world and then some more text here")
        assertNull("repeat of identical text must not produce a frame", stream.update("hello world and then some more text here"))
    }

    @Test
    fun updateThatCompletesNoLineReturnsNull() {
        val stream = stream(charsPerLine = 40)
        // Well under one line: nothing is completed, so nothing to paint.
        assertNull(stream.update("short"))
        assertNull(stream.update("short answ"))
        assertNull(stream.update("short answer"))
    }

    // MARK: - The trailing window slides

    @Test
    fun theTrailingWindowSlidesOldestLineDropsNewestAppearsAtBottom() {
        val stream = stream(charsPerLine = 6, window = 3)
        // Each word is its own line at a 6-char budget.
        val words = listOf("aaa", "bbb", "ccc", "ddd", "eee")
        val frames = mutableListOf<HudLineStream.Frame>()
        var acc = ""
        for (w in words) {
            acc += "$w "
            stream.update(acc)?.let { frames.add(it) }
        }

        // Each word freezes the PREVIOUS line, so update() yields 4 frames and
        // finish() flushes the 5th and last line.
        stream.finish()?.let { frames.add(it) }

        assertEquals(listOf("aaa"), frames[0].lines)
        assertEquals(listOf("aaa", "bbb"), frames[1].lines)
        assertEquals(listOf("aaa", "bbb", "ccc"), frames[2].lines)
        // Window is full — now it slides.
        assertEquals(listOf("bbb", "ccc", "ddd"), frames[3].lines)
        assertEquals(listOf("ccc", "ddd", "eee"), frames[4].lines)

        // Newest is always last (bottom); oldest fell off the top.
        assertEquals("eee", frames.last().lines.last())
        assertEquals(5, frames.last().totalLines)
    }

    @Test
    fun theWindowNeverExceedsItsSize() {
        val stream = stream(charsPerLine = 6, window = 4)
        var acc = ""
        repeat(20) { i ->
            acc += "w$i "
            stream.update(acc)?.let {
                assertTrue("frame of ${it.lines.size} exceeds window 4", it.lines.size <= 4)
            }
        }
    }

    // MARK: - Short text is not padded

    @Test
    fun textShorterThanTheWindowRendersWithoutPadding() {
        val stream = stream(charsPerLine = 10, window = 5)
        stream.update("one two three four ")
        val frame = stream.finish()

        assertNotNull(frame)
        // Two lines only — no blank padding up to the 5-line window.
        assertEquals(listOf("one two", "three four"), frame!!.lines)
        assertEquals("one two\nthree four", frame.text)
        assertTrue("must not pad to the window size", frame.lines.size < 5)
    }

    @Test
    fun frameTextJoinsVisibleLinesWithNewlines() {
        val stream = stream(charsPerLine = 6, window = 3)
        stream.update("aaa bbb ccc ")
        val frame = stream.finish()
        assertNotNull(frame)
        assertEquals(listOf("aaa", "bbb", "ccc"), frame!!.lines)
        assertEquals("aaa\nbbb\nccc", frame.text)
    }

    // MARK: - finish()

    @Test
    fun finishFlushesTheTrailingPartialLine() {
        val stream = stream(charsPerLine = 20)
        // No trailing space: "tail" is still an in-progress word.
        stream.update("a short tail")
        val frame = stream.finish()

        assertNotNull("finish must paint the leftover words", frame)
        assertEquals(listOf("a short tail"), frame!!.lines)
    }

    @Test
    fun finishIsIdempotent() {
        val stream = stream()
        stream.update("something to say")
        assertNotNull(stream.finish())
        assertNull("a second finish has nothing new to paint", stream.finish())
    }

    @Test
    fun finishWithNoContentProducesNoFrame() {
        assertNull(stream().finish())
    }

    /**
     * The skip-redundant-write path: once [HudLineStream.finish] has flushed the
     * trailing line, a window that has not changed must not be repainted. Each
     * screen is an ACK-gated left-then-right write (SLA-L1/L2), so a redundant
     * frame costs real airtime.
     */
    @Test
    fun anUnchangedWindowIsNotRepainted() {
        val stream = stream(charsPerLine = 6, window = 3)
        stream.update("aaa bbb ccc ")
        assertNotNull("finish flushes the still-open trailing line", stream.finish())
        assertNull("a second finish has nothing new to paint", stream.finish())
        assertNull("and unchanged text still yields no frame", stream.update("aaa bbb ccc "))
    }

    // MARK: - Reset / rewrite

    @Test
    fun aRewrittenAnswerResetsRatherThanCorruptingFrozenLines() {
        val stream = stream(charsPerLine = 6, window = 3)
        stream.update("aaa bbb ccc ")
        assertEquals(listOf("aaa", "bbb"), stream.emittedLines().take(2))

        // Not an append — a different answer entirely.
        stream.update("zzz yyy ")
        assertTrue(
            "frozen lines from the old answer must not survive",
            stream.emittedLines().none { it == "aaa" },
        )
    }

    @Test
    fun resetClearsEverything() {
        val stream = stream()
        stream.update("some text that spans a couple of lines at least here")
        stream.reset()
        assertEquals(emptyList<String>(), stream.emittedLines())
        assertEquals(0, stream.totalLines)
    }

    // MARK: - Window sizing

    @Test
    fun defaultWindowMatchesThePhysicalPageHeight() {
        assertEquals(HudPaginator.LINES_PER_PAGE, HudLineStream().windowSize)
    }

    @Test(expected = IllegalArgumentException::class)
    fun windowSizeMustBeAtLeastOne() {
        HudLineStream(windowSize = 0)
    }

    @Test
    fun windowSizeIsConfigurableForASettingsSlider() {
        val stream = stream(charsPerLine = 6, window = 1)
        var acc = ""
        val frames = mutableListOf<HudLineStream.Frame>()
        listOf("aaa", "bbb", "ccc").forEach {
            acc += "$it "
            stream.update(acc)?.let { f -> frames.add(f) }
        }
        stream.finish()?.let { frames.add(it) }
        // A 1-line window shows only the newest line.
        assertEquals(listOf(listOf("aaa"), listOf("bbb"), listOf("ccc")), frames.map { it.lines })
    }

    // MARK: - Realistic wrapping at the real line budget

    @Test
    fun atTheRealLineBudgetLinesStayWithinTheEstimate() {
        val stream = HudLineStream()
        val answer = "The quarterly business review has been moved to Thursday " +
            "afternoon at three o'clock because the finance team needed extra " +
            "time to close the books and reconcile the outstanding invoices."
        feedByCharacter(stream, answer)
        stream.finish()

        stream.emittedLines().forEach { line ->
            assertTrue(
                "line '$line' (${line.length}) exceeds the " +
                    "${HudPaginator.DEFAULT_MAX_CHARACTERS_PER_LINE}-char estimate",
                line.length <= HudPaginator.DEFAULT_MAX_CHARACTERS_PER_LINE,
            )
        }
        assertEquals(answer, stream.emittedLines().joinToString(" "))
    }
}
