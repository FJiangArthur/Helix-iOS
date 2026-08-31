package com.artjiang.helix.g1

import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Test

@OptIn(ExperimentalCoroutinesApi::class)
class G1HudDeliveryStateTest {

    private fun onePage(): List<G1HudPage> =
        G1HudPresenter().textPages("The answer is forty-two.")

    @Test
    fun `session reports delivery only after the screen write succeeds`() = runTest {
        val events = mutableListOf<G1HudDeliveryEvent>()
        val outcome = G1ScreenDeliveryOutcome.deliveredToBoth()
        val session = G1HudSession(
            scope = this,
            sendScreen = { outcome },
            completeDelayMillis = { Long.MAX_VALUE },
            onDeliveryChanged = events::add,
        )

        session.present(onePage(), deliveryId = 41)
        runCurrent()

        assertEquals(
            listOf(G1HudDeliveryEvent(41, G1HudDeliveryStatus.DELIVERED, 0, 1, outcome)),
            events,
        )
        session.reset()
        runCurrent()
    }

    @Test
    fun `session reports failed acknowledgement and display refusal`() = runTest {
        val writeEvents = mutableListOf<G1HudDeliveryEvent>()
        G1HudSession(
            scope = this,
            sendScreen = { G1ScreenDeliveryOutcome.failed() },
            onDeliveryChanged = writeEvents::add,
        ).present(onePage(), deliveryId = 42)
        runCurrent()

        assertEquals(G1HudDeliveryStatus.FAILED, writeEvents.single().status)

        val refusedEvents = mutableListOf<G1HudDeliveryEvent>()
        G1HudSession(
            scope = this,
            sendScreen = { G1ScreenDeliveryOutcome.deliveredToBoth() },
            requestDisplay = { false },
            onDeliveryChanged = refusedEvents::add,
        ).present(onePage(), deliveryId = 43)
        runCurrent()

        assertEquals(G1HudDeliveryStatus.REFUSED, refusedEvents.single().status)
    }

    @Test
    fun `session preserves left-only and right-only delivery outcomes`() = runTest {
        val leftEvents = mutableListOf<G1HudDeliveryEvent>()
        val leftOnly = G1ScreenDeliveryOutcome.deliveredToLeft()
        val leftSession = G1HudSession(
            scope = this,
            sendScreen = { leftOnly },
            completeDelayMillis = { Long.MAX_VALUE },
            onDeliveryChanged = leftEvents::add,
        )
        leftSession.present(onePage(), deliveryId = 44)
        runCurrent()

        assertEquals(G1HudDeliveryStatus.PARTIAL, leftEvents.single().status)
        assertEquals(leftOnly, leftEvents.single().screenOutcome)
        leftSession.reset()
        runCurrent()

        val rightEvents = mutableListOf<G1HudDeliveryEvent>()
        val rightOnly = G1ScreenDeliveryOutcome.deliveredToRight()
        val rightSession = G1HudSession(
            scope = this,
            sendScreen = { rightOnly },
            completeDelayMillis = { Long.MAX_VALUE },
            onDeliveryChanged = rightEvents::add,
        )
        rightSession.present(onePage(), deliveryId = 45)
        runCurrent()

        assertEquals(G1HudDeliveryStatus.PARTIAL, rightEvents.single().status)
        assertEquals(rightOnly, rightEvents.single().screenOutcome)
        rightSession.reset()
        runCurrent()
    }

    @Test
    fun `one delivered lens plus one failed lens reports partial then aborts`() = runTest {
        val events = mutableListOf<G1HudDeliveryEvent>()
        var releases = 0
        val leftDeliveredRightFailed = G1ScreenDeliveryOutcome(
            left = G1LensDeliveryStatus.DELIVERED,
            right = G1LensDeliveryStatus.FAILED,
            packetCount = 1,
        )
        val session = G1HudSession(
            scope = this,
            sendScreen = { leftDeliveredRightFailed },
            releaseDisplay = { releases += 1 },
            completeDelayMillis = { Long.MAX_VALUE },
            onDeliveryChanged = events::add,
        )

        session.present(onePage(), deliveryId = 46)
        runCurrent()

        assertEquals(G1HudDeliveryStatus.PARTIAL, events.single().status)
        assertEquals(leftDeliveredRightFailed, events.single().screenOutcome)
        assertEquals(1, releases)
        assertFalse(session.isActive)
    }
}
