import com.artjiang.helix.HudArbiter
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class HudArbiterAnswerNotificationTest {
    /**
     * deliver() presents an answer (ANSWER) and immediately forwards the same
     * answer as a 0x4B notification (NOTIFICATION). The notification must NOT
     * be able to take the display out from under the live answer.
     */
    @Test
    fun notificationCannotPreemptALiveAnswer() = runTest {
        var now = 0L
        val arbiter = HudArbiter(clock = { now })
        assertTrue(arbiter.requestDisplay(HudArbiter.Priority.ANSWER))
        assertFalse(
            "a lower-rank notification must be refused while the answer holds the HUD",
            arbiter.requestDisplay(HudArbiter.Priority.NOTIFICATION),
        )
    }

    /**
     * After the answer completes, hudSession releases the lease. A queued
     * notification must then be granted rather than blocked for the rest of
     * the 30 s ANSWER window.
     */
    @Test
    fun notificationIsGrantedOnceTheAnswerReleases() = runTest {
        var now = 0L
        val arbiter = HudArbiter(clock = { now })
        val lease = arbiter.acquire(HudArbiter.Priority.ANSWER)!!
        arbiter.release(lease)
        assertTrue(arbiter.requestDisplay(HudArbiter.Priority.NOTIFICATION))
    }
}
