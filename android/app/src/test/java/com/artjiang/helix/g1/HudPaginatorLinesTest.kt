package com.artjiang.helix.g1

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Line-awareness tests for [HudPaginator].
 *
 * The regression these pin: the paginator used to wrap with a flat
 * `DEFAULT_MAX_CHARACTERS_PER_PAGE = 120` and had no concept of a line, so a
 * "full" page filled only ~2.6 of the display's 5 lines. The hardware is 488 px
 * wide at 21 pt with 5 lines per page (SLA §7; vendor
 * `lib/services/evenai.dart:489-511`; CLAUDE.md "Text HUD: 488px max width,
 * 21pt font, 5 lines per page").
 */
class HudPaginatorLinesTest {

    // MARK: - The regression: a full page must hold ~230 chars, not 120

    @Test
    fun aFullPageHoldsRoughlyFiveLinesWorthOfCharactersNotOneTwenty() {
        val budget = HudPaginator.DEFAULT_MAX_CHARACTERS_PER_PAGE

        assertTrue(
            "a full page must hold far more than the old flat 120-char budget, " +
                "which filled only ~2.6 of the 5 lines — got $budget",
            budget >= 200,
        )
        assertEquals(
            "page budget must be exactly linesPerPage x charsPerLine",
            HudPaginator.DEFAULT_MAX_CHARACTERS_PER_LINE * HudPaginator.LINES_PER_PAGE,
            budget,
        )
        assertEquals(5, HudPaginator.LINES_PER_PAGE)
    }

    /**
     * End-to-end proof of the fix: a full 5-line page of real prose holds
     * ~215 characters and lands on ONE page. Under the old flat 120-char budget
     * this same text split across two pages and filled about half the lens.
     *
     * Note the gap between the theoretical budget (5 x 46 = 230) and what real
     * prose achieves (~215): greedy word wrapping strands a few characters at
     * the end of each line because the next word does not fit. Roughly 3 chars
     * per line, so ~15 per page. That is inherent to word wrapping, not a bug.
     */
    @Test
    fun aboutTwoHundredCharactersOfProseFitOnASinglePage() {
        // 211 characters of ordinary prose — a realistic full page.
        val text = "The quarterly business review has been moved to Thursday " +
            "afternoon at three because the finance team needs additional time " +
            "to close the books, reconcile the outstanding invoices and brief " +
            "the regional managers."
        assertTrue("fixture should be ~210 chars, was ${text.length}", text.length in 200..220)

        val pages = HudPaginator().pages(text)
        assertEquals(
            "a full 5-line page must hold ~210 chars of prose; the old 120-char " +
                "budget split this across two pages. Pages: $pages",
            1,
            pages.size,
        )
        assertEquals("this fixture should fill all 5 lines", 5, pages[0].lines().size)

        // The regression, stated directly: this text does NOT fit the old budget.
        assertTrue(
            "fixture must be longer than the old 120-char page budget, " +
                "otherwise this test would pass without the fix",
            text.length > 120,
        )
    }

    @Test
    fun aPageHoldsAtMostFiveLines() {
        val text = (1..60).joinToString(" ") { "word$it" }
        val pages = HudPaginator().pages(text)

        pages.forEach { page ->
            assertTrue(
                "page has ${page.lines().size} lines, max is ${HudPaginator.LINES_PER_PAGE}",
                page.lines().size <= HudPaginator.LINES_PER_PAGE,
            )
        }
        // Only the last page may be short.
        pages.dropLast(1).forEach {
            assertEquals(HudPaginator.LINES_PER_PAGE, it.lines().size)
        }
    }

    // MARK: - lines() is the new primitive

    @Test
    fun linesWrapsGreedilyOnWordBoundaries() {
        val lines = HudPaginator(maxCharactersPerLine = 10).lines("one two three four five")
        assertEquals(listOf("one two", "three four", "five"), lines)
        lines.forEach { assertTrue("'$it' exceeds 10", it.length <= 10) }
    }

    @Test
    fun linesRespectTheLineBudgetNotThePageBudget() {
        val lines = HudPaginator().lines(
            "The quarterly business review has been moved to Thursday afternoon " +
                "at three because the finance team needs additional time.",
        )
        assertTrue("expected several lines, got $lines", lines.size > 1)
        lines.forEach {
            assertTrue(
                "'$it' (${it.length}) exceeds the per-line budget of " +
                    HudPaginator.DEFAULT_MAX_CHARACTERS_PER_LINE,
                it.length <= HudPaginator.DEFAULT_MAX_CHARACTERS_PER_LINE,
            )
        }
    }

    @Test
    fun anOverlongWordIsEmittedOnItsOwnLine() {
        val lines = HudPaginator(maxCharactersPerLine = 5).lines("tiny enormouswordhere ok")
        assertEquals(listOf("tiny", "enormouswordhere", "ok"), lines)
    }

    @Test
    fun linesReturnsASingleEmptyLineForEmptyText() {
        assertEquals(listOf(""), HudPaginator().lines(""))
        assertEquals(listOf(""), HudPaginator().lines("   "))
    }

    // MARK: - pages() still honours its contract

    @Test
    fun aPageIsItsLinesJoinedWithNewlines() {
        val paginator = HudPaginator(maxCharactersPerLine = 6)
        val text = (1..12).joinToString(" ") { "w$it" }

        val lines = paginator.lines(text)
        val pages = paginator.pages(text)

        // Every page is exactly the corresponding slice of lines(), joined.
        val expected = lines.chunked(HudPaginator.LINES_PER_PAGE).map { it.joinToString("\n") }
        assertEquals(expected, pages)

        // And re-splitting a page recovers the lines it was built from.
        assertEquals(lines, pages.flatMap { it.lines() })
    }

    @Test
    fun pagesReturnsASingleEmptyPageForEmptyText() {
        assertEquals(listOf(""), HudPaginator().pages(""))
        assertEquals(listOf(""), HudPaginator().pages("   "))
    }

    @Test
    fun aShortAnswerStaysOnOnePage() {
        val pages = HudPaginator().pages("Yes, the meeting moved to Thursday at ten.")
        assertEquals(1, pages.size)
        assertEquals("Yes, the meeting moved to Thursday at ten.", pages[0])
    }

    // MARK: - The legacy whole-page constructor

    @Test
    fun theLegacyPageBudgetConstructorStillBoundsAPage() {
        // Callers that think in whole pages get a page of that size back.
        val paginator = HudPaginator(maxCharactersPerPage = 60)
        assertEquals(60, paginator.maxCharactersPerPage)
        assertEquals(12, paginator.maxCharactersPerLine)

        val pages = paginator.pages((1..40).joinToString(" ") { "word$it" })
        pages.dropLast(1).forEach {
            assertTrue("page of ${it.length} chars exceeds the 60-char budget", it.length <= 60 + 4)
        }
    }

    // MARK: - The chars-per-line estimate is documented as an estimate

    @Test
    fun theCharsPerLineEstimateMatchesTheDocumentedDerivation() {
        // 488 px / ~10.5 px mean glyph advance at 21 pt ~= 46.
        // If this constant is retuned from hardware observation, update the
        // derivation in the HudPaginator KDoc at the same time.
        assertEquals(46, HudPaginator.DEFAULT_MAX_CHARACTERS_PER_LINE)
        assertTrue(
            "the estimate must stay plausible for 488px at 21pt",
            HudPaginator.DEFAULT_MAX_CHARACTERS_PER_LINE in 35..60,
        )
    }
}
