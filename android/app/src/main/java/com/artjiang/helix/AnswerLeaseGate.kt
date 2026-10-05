// The legacy answer lifecycle's hold on the HUD (G1HudSession). Kept apart
// from HelixBridge so the ownership rules are testable.
package com.artjiang.helix

/**
 * Answer pages may renew their own lease; anything else drawn through the
 * same session (session notices at NOTIFICATION) must win on rank alone, so a
 * reminder can never ride an answer's lease and blank it. [owns] is true while
 * nobody else has taken the HUD since our grant — even after the grant's
 * window expired — so the dwell clear still runs for long answers but never
 * blanks a screen another producer (e.g. a Conversate menu) drew since.
 */
class AnswerLeaseGate(private val arbiter: HudArbiter) {
    @Volatile
    private var lease: HudArbiter.Lease? = null

    suspend fun request(priority: HudArbiter.Priority): Boolean {
        val replacing = lease.takeIf { priority == HudArbiter.Priority.ANSWER }
        val granted = arbiter.acquire(priority, replacing = replacing) ?: return false
        lease = granted
        return true
    }

    suspend fun owns(): Boolean = lease?.let { arbiter.isLatest(it) } ?: false

    suspend fun release() {
        lease?.let { arbiter.release(it) }
        lease = null
    }
}
