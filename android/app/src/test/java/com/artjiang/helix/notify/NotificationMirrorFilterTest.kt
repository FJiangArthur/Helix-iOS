package com.artjiang.helix.notify

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class NotificationMirrorFilterTest {

    private fun notification(
        pkg: String = "com.example.chat",
        title: String = "Ada",
        text: String = "on my way",
        ongoing: Boolean = false,
        summary: Boolean = false,
        atMillis: Long = 1_000L,
    ) = IncomingNotification(
        packageName = pkg,
        title = title,
        text = text,
        isOngoing = ongoing,
        isGroupSummary = summary,
        postedAtMillis = atMillis,
    )

    private val whitelist = setOf("com.example.chat")

    @Test
    fun forwardsWhitelistedNotificationWhenEnabled() {
        val filter = NotificationMirrorFilter()
        assertTrue(filter.shouldForward(notification(), enabled = true, whitelist = whitelist))
    }

    @Test
    fun dropsEverythingWhenMirroringIsOff() {
        val filter = NotificationMirrorFilter()
        assertFalse(filter.shouldForward(notification(), enabled = false, whitelist = whitelist))
    }

    @Test
    fun dropsPackagesOutsideTheWhitelist() {
        val filter = NotificationMirrorFilter()
        assertFalse(
            filter.shouldForward(
                notification(pkg = "com.example.games"),
                enabled = true,
                whitelist = whitelist,
            )
        )
    }

    @Test
    fun dropsOngoingAndGroupSummaryNotifications() {
        val filter = NotificationMirrorFilter()
        assertFalse(filter.shouldForward(notification(ongoing = true), enabled = true, whitelist = whitelist))
        assertFalse(filter.shouldForward(notification(summary = true), enabled = true, whitelist = whitelist))
    }

    @Test
    fun dropsEmptyContent() {
        val filter = NotificationMirrorFilter()
        assertFalse(
            filter.shouldForward(
                notification(title = "", text = "   ".trim()),
                enabled = true,
                whitelist = whitelist,
            )
        )
    }

    @Test
    fun dedupesIdenticalRepostsInsideTheWindow() {
        val filter = NotificationMirrorFilter(dedupeWindowMillis = 10_000)
        assertTrue(filter.shouldForward(notification(atMillis = 1_000), enabled = true, whitelist = whitelist))
        // Same package/title/text 2 s later: a repost, not a new message.
        assertFalse(filter.shouldForward(notification(atMillis = 3_000), enabled = true, whitelist = whitelist))
    }

    @Test
    fun allowsTheSameContentAgainAfterTheWindow() {
        val filter = NotificationMirrorFilter(dedupeWindowMillis = 10_000)
        assertTrue(filter.shouldForward(notification(atMillis = 1_000), enabled = true, whitelist = whitelist))
        assertTrue(filter.shouldForward(notification(atMillis = 12_000), enabled = true, whitelist = whitelist))
    }

    @Test
    fun differentTextFromTheSameAppIsNotDeduped() {
        val filter = NotificationMirrorFilter(dedupeWindowMillis = 10_000)
        assertTrue(filter.shouldForward(notification(atMillis = 1_000), enabled = true, whitelist = whitelist))
        assertTrue(
            filter.shouldForward(
                notification(text = "running late", atMillis = 1_100),
                enabled = true,
                whitelist = whitelist,
            )
        )
    }

    @Test
    fun fingerprintDelimiterKeepsTitleAndBodyBoundariesDistinct() {
        val filter = NotificationMirrorFilter(dedupeWindowMillis = 10_000)
        assertTrue(
            filter.shouldForward(
                notification(title = "ab", text = "c", atMillis = 1_000),
                enabled = true,
                whitelist = whitelist,
            )
        )
        assertTrue(
            filter.shouldForward(
                notification(title = "a", text = "bc", atMillis = 1_100),
                enabled = true,
                whitelist = whitelist,
            )
        )
    }

    @Test
    fun resetForgetsTheDedupeMemory() {
        val filter = NotificationMirrorFilter(dedupeWindowMillis = 10_000)
        assertTrue(filter.shouldForward(notification(atMillis = 1_000), enabled = true, whitelist = whitelist))
        filter.reset()
        assertTrue(filter.shouldForward(notification(atMillis = 1_500), enabled = true, whitelist = whitelist))
    }

    @Test
    fun recentEntriesAreBounded() {
        // 200 distinct notifications inside one window must not grow past the
        // cap: this runs in a long-lived listener process.
        val filter = NotificationMirrorFilter(dedupeWindowMillis = 1_000_000, maxRecentEntries = 4)
        repeat(200) { index ->
            assertTrue(
                filter.shouldForward(
                    notification(text = "message $index", atMillis = 1_000L + index),
                    enabled = true,
                    whitelist = whitelist,
                )
            )
        }
        // The oldest fingerprint was evicted, so it forwards again.
        assertTrue(
            filter.shouldForward(
                notification(text = "message 0", atMillis = 2_000L),
                enabled = true,
                whitelist = whitelist,
            )
        )
    }

    @Test
    fun clockGoingBackwardsDoesNotStrandEntries() {
        val filter = NotificationMirrorFilter(dedupeWindowMillis = 10_000)
        assertTrue(filter.shouldForward(notification(atMillis = 100_000), enabled = true, whitelist = whitelist))
        // Device clock corrected backwards: the stale future entry is pruned
        // rather than blocking this fingerprint forever.
        assertTrue(filter.shouldForward(notification(atMillis = 1_000), enabled = true, whitelist = whitelist))
    }
}
