package com.artjiang.helix.data

import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import okhttp3.mockwebserver.MockResponse
import okhttp3.mockwebserver.MockWebServer
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import java.io.IOException

class OmiLiveServiceTest {

    private lateinit var server: MockWebServer

    @Before
    fun setUp() {
        server = MockWebServer()
        server.start()
    }

    @After
    fun tearDown() = server.shutdown()

    @Test
    fun `parses feed page and drops blank segments`() {
        val page = OmiLiveService.parseFeed(
            """{"seq":7,"segments":[
                {"seq":6,"text":" Hello there ","speaker":"SPEAKER_00","is_user":true,"session_id":"s1"},
                {"seq":7,"text":"   ","speaker":null}
            ]}""",
        )
        assertEquals(7L, page.seq)
        assertEquals(1, page.segments.size)
        assertEquals("Hello there", page.segments[0].text)
        assertEquals("SPEAKER_00", page.segments[0].speaker)
        assertTrue(page.segments[0].isUser)
        assertEquals("s1", page.segments[0].sessionId)
    }

    @Test
    fun `fetch sends after and wait params and maps http errors`() {
        server.enqueue(MockResponse().setResponseCode(200).setBody("""{"seq":3,"segments":[]}"""))
        server.enqueue(MockResponse().setResponseCode(404).setBody("""{"error":"not found"}"""))
        val service = OmiLiveService(CoroutineScope(Dispatchers.Unconfined))
        val url = server.url("/feed/abcdefghijklmnop").toString()

        val page = service.fetch(url, after = 2, wait = 5)
        assertEquals(3L, page.seq)
        assertEquals("/feed/abcdefghijklmnop?after=2&wait=5", server.takeRequest().path)

        val error = runCatching { service.fetch(url, 3, 5) }.exceptionOrNull()
        assertTrue(error is IOException)
        assertTrue(error!!.message!!.contains("404"))
    }
}
