package com.artjiang.helix.conversate

import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.fail
import org.junit.Test

class DashboardRepositoryTest {
    private var now = 0L
    private var fetches = 0
    private var failNext = false
    private val fixture = conversateJson.decodeFromString(
        RelayDashboard.serializer(),
        ConversateResources.read("fixtures/relay-dashboard.json"),
    )
    private val repo = DashboardRepository(
        fetch = {
            fetches++
            if (failNext) throw RelayException(RelayException.Kind.UNREACHABLE, "down")
            fixture
        },
        clock = { now },
    )

    @Test
    fun `serves from cache for 60 seconds`() = runTest {
        repo.rows("news")
        now += 59_999
        repo.rows("todos")
        assertEquals(1, fetches)
        now += 1
        repo.rows("news")
        assertEquals(2, fetches)
    }

    @Test
    fun `local toggle survives until the next fetch`() = runTest {
        repo.rows("todos")
        repo.applyToggle("t1", true)
        assertEquals(listOf(true, true), repo.rows("todos").map { it.done })
        now += 60_000
        assertEquals(listOf(false, true), repo.rows("todos").map { it.done })
    }

    @Test
    fun `failure after a good fetch keeps stale rows, cold failure throws`() = runTest {
        repo.rows("news")
        now += 61_000
        failNext = true
        assertEquals(2, repo.rows("news").size)
        val cold = DashboardRepository(fetch = { throw RelayException(RelayException.Kind.UNREACHABLE, "down") }, clock = { now })
        try {
            cold.rows("news"); fail()
        } catch (_: RelayException) {
        }
    }

    @Test
    fun `invalidate forces a refetch`() = runTest {
        repo.rows("omi")
        repo.invalidate()
        repo.rows("omi")
        assertEquals(2, fetches)
    }
}
