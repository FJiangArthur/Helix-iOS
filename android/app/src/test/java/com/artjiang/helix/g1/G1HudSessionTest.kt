// Tests for the HUD answer lifecycle: paint, dwell, clear.
//
// Wire behaviour is taken from the WORKING iOS app, not the EvenDemoApp Dart
// reference — see the header of G1HudSession.kt. The load-bearing assertions
// are the emitted `screen_status` (header byte 4) sequence and the fact that
// every answer ends in exactly one screen clear, which is what makes the HUD
// disappear after the dwell.
package com.artjiang.helix.g1

import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.awaitCancellation
import kotlinx.coroutines.test.advanceTimeBy
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

@OptIn(ExperimentalCoroutinesApi::class)
class G1HudSessionTest {

    private companion object {
        /** 0x71 SIMPLE_TEXT | NEW_CONTENT — whole-screen, single-page answers. */
        const val WHOLE_SCREEN = 0x71

        /** 0x71 SIMPLE_TEXT | NEW_CONTENT — every plain-text page. */
        const val PLAIN_TEXT = 0x71

        const val DWELL = 3_000L
        const val ADVANCE = 5_000L
    }

    /** Captures each screen push as (screen_status, currentPage, syncSeq). */
    private class ScreenRecorder {
        val screens = mutableListOf<Triple<Int, Int, Int>>()
        var clears = 0
        var accept: Boolean = true

        suspend fun send(packets: List<ByteArray>): G1ScreenDeliveryOutcome {
            val head = packets.first()
            screens.add(
                Triple(
                    head[4].toInt() and 0xFF,
                    head[7].toInt() and 0xFF,
                    head[1].toInt() and 0xFF,
                )
            )
            return if (accept) {
                G1ScreenDeliveryOutcome.deliveredToBoth(packets.size)
            } else {
                G1ScreenDeliveryOutcome.failed(packets.size)
            }
        }

        fun clear() { clears += 1 }

        fun statuses(): List<Int> = screens.map { it.first }
        fun pages(): List<Int> = screens.map { it.second }
    }

    private fun session(
        recorder: ScreenRecorder,
        scope: kotlinx.coroutines.CoroutineScope,
        requestDisplay: suspend () -> Boolean = { true },
        releaseDisplay: suspend () -> Unit = {},
        onPageChanged: (Int) -> Unit = {},
    ) = G1HudSession(
        scope = scope,
        sendScreen = recorder::send,
        requestDisplay = requestDisplay,
        releaseDisplay = releaseDisplay,
        clearScreen = { recorder.clear() },
        onPageChanged = onPageChanged,
        completeDelayMillis = { DWELL },
        autoAdvanceMillis = { ADVANCE },
    )

    /** [count] single-word pages, so page boundaries are unambiguous. */
    private fun pagesOf(count: Int): List<G1HudPage> =
        G1HudPresenter(HudPaginator(maxCharactersPerLine = 6, linesPerPage = 1))
            .textPages((1..count).joinToString(" ") { "page$it" })

    private fun onePage(): List<G1HudPage> =
        G1HudPresenter().textPages("Yes, the meeting moved to Thursday.")

    // MARK: - Single page: paint at 0x71, dwell, clear

    @Test
    fun singlePagePaintsWholeScreenThenClearsAfterTheDwell() = runTest {
        val recorder = ScreenRecorder()
        val session = session(recorder, this)

        session.present(onePage())
        runCurrent()
        assertEquals(listOf(WHOLE_SCREEN), recorder.statuses())
        assertEquals("nothing is cleared while the answer is readable", 0, recorder.clears)

        advanceTimeBy(DWELL + 1)
        assertEquals("the HUD must blank once the dwell expires", 1, recorder.clears)
        assertEquals(G1HudSession.Phase.COMPLETE, session.phase)
    }

    @Test
    fun singlePageDoesNotClearBeforeTheDwellElapses() = runTest {
        val recorder = ScreenRecorder()
        session(recorder, this).present(onePage())
        advanceTimeBy(DWELL - 100)
        assertEquals(0, recorder.clears)
    }

    @Test
    fun theDwellIsReadPerAnswerSoASettingsChangeApplies() = runTest {
        val recorder = ScreenRecorder()
        var dwell = 1_000L
        val session = G1HudSession(
            scope = this,
            sendScreen = recorder::send,
            clearScreen = { recorder.clear() },
            completeDelayMillis = { dwell },
        )

        session.present(onePage())
        advanceTimeBy(1_100)
        assertEquals(1, recorder.clears)

        dwell = 8_000L
        session.present(onePage())
        advanceTimeBy(1_100)
        assertEquals("the longer dwell must now apply", 1, recorder.clears)
        advanceTimeBy(7_000)
        assertEquals(2, recorder.clears)
    }

    // MARK: - Multi page: 0x71 throughout, auto-advance, then clear

    @Test
    fun multiPagePaintsEveryPagePagedThenClears() = runTest {
        val recorder = ScreenRecorder()
        val session = session(recorder, this)

        session.present(pagesOf(3))
        advanceUntilIdle()

        assertEquals(listOf(PLAIN_TEXT, PLAIN_TEXT, PLAIN_TEXT), recorder.statuses())
        assertEquals(listOf(1, 2, 3), recorder.pages())
        assertEquals(1, recorder.clears)
        assertEquals(G1HudSession.Phase.COMPLETE, session.phase)
    }

    @Test
    fun multiPageAdvancesOnTheAutoAdvanceInterval() = runTest {
        val recorder = ScreenRecorder()
        session(recorder, this).present(pagesOf(3))
        runCurrent()
        assertEquals(1, recorder.screens.size)

        advanceTimeBy(ADVANCE + 1)
        assertEquals(2, recorder.screens.size)

        advanceTimeBy(ADVANCE + 1)
        assertEquals(3, recorder.screens.size)
        assertEquals("the last page must still dwell before blanking", 0, recorder.clears)

        advanceTimeBy(DWELL + 1)
        assertEquals(1, recorder.clears)
    }

    @Test
    fun theLastPageDwellsBeforeTheScreenIsCleared() = runTest {
        val recorder = ScreenRecorder()
        session(recorder, this).present(pagesOf(2))
        advanceTimeBy(ADVANCE + 1)
        assertEquals(2, recorder.screens.size)
        advanceTimeBy(DWELL - 100)
        assertEquals(0, recorder.clears)
        advanceTimeBy(200)
        assertEquals(1, recorder.clears)
    }

    // MARK: - syncSeq

    @Test
    fun syncSeqIncrementsPerScreenNotPerPacket() = runTest {
        val recorder = ScreenRecorder()
        session(recorder, this).present(pagesOf(3))
        advanceUntilIdle()
        assertEquals(listOf(1, 2, 3), recorder.screens.map { it.third })
    }

    @Test
    fun everyPacketOfOneScreenSharesTheSameSyncSeq() = runTest {
        val captured = mutableListOf<List<ByteArray>>()
        G1HudSession(
            scope = this,
            sendScreen = { packets ->
                captured.add(packets)
                G1ScreenDeliveryOutcome.deliveredToBoth(packets.size)
            },
            clearScreen = {},
            completeDelayMillis = { DWELL },
        ).present(
            // One page whose text exceeds a single 182-byte packet, so the
            // screen is chunked but NOT paginated.
            G1HudPresenter(HudPaginator(maxCharactersPerPage = 4_000))
                .textPages("word ".repeat(120).trim()),
        )
        runCurrent()

        val first = captured.first()
        assertTrue("this screen must span several packets", first.size > 1)
        assertEquals(1, first.map { it[1].toInt() and 0xFF }.distinct().size)
    }

    // MARK: - Manual paging

    @Test
    fun touchpadPagingCancelsAutoAdvanceAndLatchesManual() = runTest {
        val recorder = ScreenRecorder()
        val session = session(recorder, this)
        session.present(pagesOf(3))
        runCurrent()

        session.showNextPage()
        advanceUntilIdle()

        assertEquals(G1HudSession.Phase.MANUAL, session.phase)
        assertEquals("manual pages retain the plain-text new-content action", PLAIN_TEXT, recorder.statuses().last())
        assertEquals(
            "hand-paged content must not be blanked out from under the wearer",
            0,
            recorder.clears,
        )
    }

    @Test
    fun touchpadOnASinglePageAnswerCancelsThePendingClear() = runTest {
        val recorder = ScreenRecorder()
        val session = session(recorder, this)
        session.present(onePage())
        runCurrent()

        session.showPage(0)
        advanceUntilIdle()

        assertEquals(G1HudSession.Phase.MANUAL, session.phase)
        assertEquals(0, recorder.clears)
    }

    @Test
    fun manualPageIndexIsClampedToTheAnswerRange() = runTest {
        val recorder = ScreenRecorder()
        val session = session(recorder, this)
        session.present(pagesOf(3))
        runCurrent()

        session.showPage(99)
        advanceUntilIdle()
        assertEquals(2, session.pageIndex)

        session.showPage(-5)
        advanceUntilIdle()
        assertEquals(0, session.pageIndex)
    }

    // MARK: - Supersession

    @Test
    fun newAnswerCancelsThePreviousPendingClear() = runTest {
        val recorder = ScreenRecorder()
        val session = session(recorder, this)

        session.present(onePage())
        advanceTimeBy(DWELL - 500)
        session.present(onePage())
        advanceTimeBy(600)

        assertEquals("the superseded answer's clear must not fire", 0, recorder.clears)
        advanceUntilIdle()
        assertEquals("only the surviving answer clears", 1, recorder.clears)
    }

    @Test
    fun supersededClearCannotCompleteOrReleaseTheNewLifecycle() = runTest {
        val recorder = ScreenRecorder()
        var dwell = 0L
        var clearCalls = 0
        var releases = 0
        val session = G1HudSession(
            scope = this,
            sendScreen = recorder::send,
            releaseDisplay = { releases += 1 },
            clearScreen = {
                clearCalls += 1
                if (clearCalls == 1) awaitCancellation()
            },
            completeDelayMillis = { dwell },
        )

        session.present(onePage(), deliveryId = 1)
        runCurrent()
        assertEquals("the first lifecycle must be suspended in its clear", 1, clearCalls)

        dwell = 10_000L
        session.present(onePage(), deliveryId = 2)
        runCurrent()

        assertEquals(G1HudSession.Phase.DISPLAYING, session.phase)
        assertEquals("the cancelled lifecycle does not own the new lease", 0, releases)

        advanceTimeBy(dwell + 1)
        assertEquals(G1HudSession.Phase.COMPLETE, session.phase)
        assertEquals(2, clearCalls)
        assertEquals("only the surviving lifecycle releases its lease", 1, releases)
    }

    @Test
    fun rapidSuccessivePresentsStillClearExactlyOnce() = runTest {
        val recorder = ScreenRecorder()
        val session = session(recorder, this)

        repeat(4) { session.present(onePage()) }
        advanceUntilIdle()

        assertEquals(1, recorder.clears)
        assertEquals(G1HudSession.Phase.COMPLETE, session.phase)
    }

    /**
     * HARDWARE TIMING. A screen push is not instant on glasses: every packet
     * goes to the left lens, then the load-bearing 400 ms inter-side settle,
     * then the right lens — ~410 ms per screen. Streaming repaints arriving
     * mid-write must still leave exactly one clear.
     */
    @Test
    fun streamingRepaintsDuringInFlightWritesStillClearOnce() = runTest {
        val recorder = ScreenRecorder()
        val session = G1HudSession(
            scope = this,
            sendScreen = { packets ->
                kotlinx.coroutines.delay(410)
                recorder.send(packets)
            },
            clearScreen = { recorder.clear() },
            completeDelayMillis = { DWELL },
        )

        session.present(onePage())
        advanceTimeBy(1_200)
        session.present(onePage())
        advanceTimeBy(1_200)
        session.present(onePage())
        advanceUntilIdle()

        assertEquals(1, recorder.clears)
        assertEquals(G1HudSession.Phase.COMPLETE, session.phase)
    }

    // MARK: - Arbiter interaction

    @Test
    fun refusedInterruptionLeavesThePendingClearIntact() = runTest {
        val recorder = ScreenRecorder()
        var grants = 0
        val session = session(
            recorder,
            this,
            requestDisplay = { grants++ == 0 },
        )

        session.present(onePage())
        runCurrent()
        // A live caption arrives mid-dwell and is refused by the arbiter.
        session.present(onePage())
        advanceUntilIdle()

        assertEquals("the refused newcomer must not draw", 1, recorder.screens.size)
        assertEquals("the original answer must still blank the lens", 1, recorder.clears)
    }

    @Test
    fun refusedArbiterGrantDrawsNothingAndLeavesNoSession() = runTest {
        val recorder = ScreenRecorder()
        val session = session(recorder, this, requestDisplay = { false })

        session.present(onePage())
        advanceUntilIdle()

        assertTrue(recorder.screens.isEmpty())
        assertEquals(0, recorder.clears)
        assertFalse(session.isActive)
    }

    @Test
    fun theLeaseIsReleasedOnceTheScreenIsBlank() = runTest {
        val recorder = ScreenRecorder()
        var released = 0
        session(recorder, this, releaseDisplay = { released += 1 }).present(onePage())
        advanceUntilIdle()
        assertEquals(1, released)
    }

    @Test
    fun aFailedFirstWriteReleasesTheLeaseInsteadOfHoldingIt() = runTest {
        val recorder = ScreenRecorder().apply { accept = false }
        var released = 0
        val session = session(recorder, this, releaseDisplay = { released += 1 })

        session.present(onePage())
        advanceUntilIdle()

        assertEquals("a screen that never drew must not clear", 0, recorder.clears)
        assertEquals("the lease must not be held over a blank lens", 1, released)
        assertFalse(session.isActive)
    }

    // MARK: - Reset

    @Test
    fun resetCancelsEverythingAndClearsState() = runTest {
        val recorder = ScreenRecorder()
        val session = session(recorder, this)
        session.present(pagesOf(3))
        runCurrent()

        session.reset()
        advanceUntilIdle()

        assertEquals(G1HudSession.Phase.IDLE, session.phase)
        assertTrue(session.pages.isEmpty())
        assertEquals("a reset lifecycle must not fire its clear", 0, recorder.clears)
    }

    @Test
    fun resetMakesManualPagingANoOp() = runTest {
        val recorder = ScreenRecorder()
        val session = session(recorder, this)
        session.present(pagesOf(3))
        runCurrent()
        val drawn = recorder.screens.size

        session.reset()
        session.showNextPage()
        advanceUntilIdle()

        assertEquals(drawn, recorder.screens.size)
    }

    @Test
    fun presentWithNoPagesResetsRatherThanDrawing() = runTest {
        val recorder = ScreenRecorder()
        val session = session(recorder, this)
        session.present(emptyList())
        advanceUntilIdle()

        assertTrue(recorder.screens.isEmpty())
        assertEquals(G1HudSession.Phase.IDLE, session.phase)
    }

    @Test
    fun onPageChangedMirrorsEveryPageTransition() = runTest {
        val recorder = ScreenRecorder()
        val seen = mutableListOf<Int>()
        session(recorder, this, onPageChanged = { seen.add(it) }).present(pagesOf(3))
        advanceUntilIdle()
        assertEquals(listOf(0, 1, 2), seen)
    }

    /**
     * A clear that fails mid-teardown (a lens dropping) must still release the
     * lease. Gating release on the clear would move the stuck-lease bug one
     * step later instead of fixing it.
     */
    @Test
    fun aFailedClearStillReleasesTheLease() = runTest {
        val recorder = ScreenRecorder()
        var released = 0
        G1HudSession(
            scope = this,
            sendScreen = recorder::send,
            releaseDisplay = { released += 1 },
            clearScreen = { error("lens dropped during teardown") },
            completeDelayMillis = { DWELL },
        ).present(onePage())
        advanceUntilIdle()

        assertEquals("the lease must not survive a failed clear", 1, released)
    }

    @Test
    fun officialTimingConstantsMatchTheReferenceApp() {
        assertEquals(3_000L, G1HudSession.SINGLE_PAGE_COMPLETE_DELAY_MILLIS)
        assertEquals(5_000L, G1HudSession.AUTO_ADVANCE_INTERVAL_MILLIS)
    }
}
