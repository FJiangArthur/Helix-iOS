package com.artjiang.helix

import com.artjiang.helix.g1.G1HudDeliveryEvent
import com.artjiang.helix.g1.G1HudDeliveryStatus
import com.artjiang.helix.g1.G1LensDeliveryStatus
import com.artjiang.helix.g1.G1ScreenDeliveryOutcome
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Test

class HudDeliveryReceiptTest {

    @Test
    fun `offline preview never claims the answer reached glasses`() {
        val receipt = HudDeliveryReceipt(
            ownerFeedEntryId = 7,
            phase = HudDeliveryPhase.PHONE_ONLY,
            pageIndex = 0,
            pageCount = 1,
        )

        val label = receipt.labelForAnswer(7)

        assertEquals("Phone only", label)
        assertFalse(label!!.contains("On glasses", ignoreCase = true))
        assertFalse(label.contains("Delivered", ignoreCase = true))
    }

    @Test
    fun `only an acknowledged matching delivery is labelled delivered`() {
        val sending = HudDeliveryReceipt(
            ownerFeedEntryId = 9,
            phase = HudDeliveryPhase.SENDING,
            pageIndex = 0,
            pageCount = 2,
        )
        val failed = sending.copy(phase = HudDeliveryPhase.FAILED)
        val delivered = sending.copy(phase = HudDeliveryPhase.DELIVERED, pageIndex = 1)

        assertEquals("Sending to glasses…", sending.labelForAnswer(9))
        assertEquals("Glasses delivery failed", failed.labelForAnswer(9))
        assertEquals("Delivered to glasses · page 2 of 2", delivered.labelForAnswer(9))
        assertNull("a global HUD event must not relabel another answer", delivered.labelForAnswer(10))
    }

    @Test
    fun `single-lens acknowledgements never claim both glasses received the answer`() {
        val sending = HudDeliveryReceipt(
            ownerFeedEntryId = 21,
            phase = HudDeliveryPhase.SENDING,
            pageIndex = 0,
            pageCount = 2,
        )
        val leftOutcome = G1ScreenDeliveryOutcome.deliveredToLeft()
        val leftOnly = sending.applying(
            G1HudDeliveryEvent(
                deliveryId = 1,
                status = G1HudDeliveryStatus.PARTIAL,
                pageIndex = 0,
                pageCount = 2,
                screenOutcome = leftOutcome,
            ),
        )
        val rightOutcome = G1ScreenDeliveryOutcome.deliveredToRight()
        val rightOnly = sending.applying(
            G1HudDeliveryEvent(
                deliveryId = 1,
                status = G1HudDeliveryStatus.PARTIAL,
                pageIndex = 1,
                pageCount = 2,
                screenOutcome = rightOutcome,
            ),
        )

        assertEquals(leftOutcome, leftOnly.screenOutcome)
        assertEquals(rightOutcome, rightOnly.screenOutcome)
        assertEquals("Delivered to left lens only · page 1 of 2", leftOnly.labelForAnswer(21))
        assertEquals("Delivered to right lens only · page 2 of 2", rightOnly.labelForAnswer(21))
    }

    @Test
    fun `one acknowledged lens remains visible when its peer failed`() {
        val outcome = G1ScreenDeliveryOutcome(
            left = G1LensDeliveryStatus.DELIVERED,
            right = G1LensDeliveryStatus.FAILED,
            packetCount = 2,
        )
        val receipt = HudDeliveryReceipt(
            ownerFeedEntryId = 22,
            phase = HudDeliveryPhase.SENDING,
            pageCount = 1,
        ).applying(
            G1HudDeliveryEvent(
                deliveryId = 2,
                status = G1HudDeliveryStatus.PARTIAL,
                pageIndex = 0,
                pageCount = 1,
                screenOutcome = outcome,
            ),
        )

        assertEquals("Delivered to left lens only · page 1 of 1", receipt.labelForAnswer(22))
    }

    @Test
    fun `arbiter refusal stays distinct from transport failure`() {
        val refused = HudDeliveryReceipt(
            ownerFeedEntryId = 31,
            phase = HudDeliveryPhase.REFUSED,
        )

        assertEquals("Glasses display busy", refused.labelForAnswer(31))
    }

    @Test
    fun `combined multi-question receipt labels every included answer and no other card`() {
        val batch = HudDeliveryReceipt(
            ownerFeedEntryId = null,
            answerFeedEntryIds = setOf(41L, 42L),
            phase = HudDeliveryPhase.PHONE_ONLY,
            pageCount = 2,
        )

        assertEquals("Phone only", batch.labelForAnswer(41L))
        assertEquals("Phone only", batch.labelForAnswer(42L))
        assertNull(batch.labelForAnswer(40L))
        assertNull(batch.labelForAnswer(43L))
    }
}
