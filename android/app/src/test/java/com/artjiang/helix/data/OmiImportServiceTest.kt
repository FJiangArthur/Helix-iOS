package com.artjiang.helix.data

import com.artjiang.helix.ai.KeyStore
import com.artjiang.helix.core.KnowledgeBucket
import com.artjiang.helix.core.KnowledgeItem
import com.artjiang.helix.core.SessionSummary
import kotlinx.coroutines.test.runTest
import okhttp3.mockwebserver.MockResponse
import okhttp3.mockwebserver.MockWebServer
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

class OmiImportServiceTest {

    private lateinit var server: MockWebServer

    private val keyStore = object : KeyStore {
        var key: String? = "omi_dev_test"
        override fun keyFor(kind: String): String? = if (kind == "OMI") key else null
    }

    private val storedSessions = mutableListOf<SessionSummary>()
    private val storedKnowledge = mutableListOf<KnowledgeItem>()

    private fun service() = OmiImportService(
        keyStore = keyStore,
        upsertSessions = { incoming ->
            val existing = storedSessions.mapTo(HashSet()) { it.id }
            val fresh = incoming.filter { existing.add(it.id) }
            storedSessions += fresh
            fresh.size
        },
        upsertKnowledge = { incoming ->
            val existing = storedKnowledge.mapTo(HashSet()) { it.id }
            val fresh = incoming.filter { existing.add(it.id) }
            storedKnowledge += fresh
            fresh.size
        },
        baseUrl = server.url("/").toString().trimEnd('/'),
    )

    @Before
    fun setUp() {
        server = MockWebServer()
        server.start()
    }

    @After
    fun tearDown() {
        server.shutdown()
    }

    private fun enqueueJson(body: String) {
        server.enqueue(MockResponse().setResponseCode(200).setBody(body))
    }

    @Test
    fun `imports conversations and memories with stable omi ids`() = runTest {
        enqueueJson(
            """{"conversations":[{"id":"c1","started_at":"2026-08-20 23:45:13+00:00",
              "structured":{"title":"Team sync","overview":"Discussed the release."},
              "transcript_segments":[{"text":"hello","speaker":"SPEAKER_1"},{"text":"hi"}]}]}""",
        )
        enqueueJson("""{"memories":[{"id":"m1","content":"Prefers Apple Cloud transcription","created_at":"2026-08-20T10:00:00Z"}]}""")

        val result = service().importAll()

        assertEquals(1, result.conversationsImported)
        assertEquals(1, result.memoriesImported)
        assertEquals(0, result.duplicatesSkipped)
        assertEquals("omi:c1", storedSessions.single().id)
        assertEquals("Team sync", storedSessions.single().title)
        assertEquals(listOf("SPEAKER_1: hello", "hi"), storedSessions.single().transcriptTurns)
        assertEquals("omi:m1", storedKnowledge.single().id)
        assertEquals(KnowledgeBucket.MEMORIES, storedKnowledge.single().bucket)
        assertEquals("Omi", storedKnowledge.single().source)

        val request = server.takeRequest()
        assertEquals("Bearer omi_dev_test", request.getHeader("Authorization"))
        assertTrue(request.path.orEmpty().contains("/v1/dev/user/conversations"))
    }

    @Test
    fun `second import skips already-imported records`() = runTest {
        repeat(2) {
            enqueueJson("""{"conversations":[{"id":"c1","structured":{"title":"T"}}]}""")
            enqueueJson("""{"memories":[{"id":"m1","content":"fact"}]}""")
        }
        service().importAll()
        val second = service().importAll()

        assertEquals(0, second.conversationsImported)
        assertEquals(0, second.memoriesImported)
        assertEquals(2, second.duplicatesSkipped)
        assertEquals(1, storedSessions.size)
        assertEquals(1, storedKnowledge.size)
    }

    @Test
    fun `accepts bare array responses`() = runTest {
        enqueueJson("""[{"id":"c9","structured":{"title":"Bare"}}]""")
        enqueueJson("""[{"id":"m9","text":"bare memory"}]""")

        val result = service().importAll()
        assertEquals(1, result.conversationsImported)
        assertEquals(1, result.memoriesImported)
    }

    @Test
    fun `missing key fails without any request`() = runTest {
        keyStore.key = null
        val error = runCatching { service().importAll() }.exceptionOrNull()
        assertTrue(error is OmiMissingKeyException)
        assertEquals(0, server.requestCount)
    }

    @Test
    fun `http error surfaces status code`() = runTest {
        server.enqueue(MockResponse().setResponseCode(401).setBody("""{"error":"bad key"}"""))
        val error = runCatching { service().importAll() }.exceptionOrNull()
        assertTrue(error is OmiHttpException)
        assertEquals(401, (error as OmiHttpException).statusCode)
    }

    @Test
    fun `blank ids are dropped instead of colliding on the omi prefix`() = runTest {
        enqueueJson("""{"conversations":[{"id":"","structured":{"title":"A"}},{"id":"  ","structured":{"title":"B"}},{"id":"c1","structured":{"title":"C"}}]}""")
        enqueueJson("""{"memories":[]}""")

        val result = service().importAll()
        assertEquals(1, result.conversationsImported)
        assertEquals("omi:c1", storedSessions.single().id)
    }

    @Test
    fun `unrecognized response envelope fails instead of importing nothing`() = runTest {
        enqueueJson("""{"data":{"nested":"shape"}}""")
        val error = runCatching { service().importAll() }.exceptionOrNull()
        assertTrue(error is OmiUnexpectedResponseException)
    }

    @Test
    fun `timestamp parsing handles omi formats`() = runTest {
        val svc = service()
        assertEquals(1787269513000L, svc.timestampMillis("2026-08-20 23:45:13+00:00"))
        assertEquals(1787219400000L, svc.timestampMillis("2026-08-20T09:50:00Z"))
        // Unparseable input falls back to "now" rather than crashing.
        assertTrue(svc.timestampMillis("not-a-date") > 0)
    }
}
