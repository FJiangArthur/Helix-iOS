package com.artjiang.helix.conversate

import kotlinx.coroutines.test.runTest
import okhttp3.mockwebserver.MockResponse
import okhttp3.mockwebserver.MockWebServer
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Before
import org.junit.Test

class RelayClientTest {
    private lateinit var server: MockWebServer
    private var config: RelayConfig? = null

    private fun client() = RelayClient(config = { config })

    @Before
    fun setUp() {
        server = MockWebServer()
        server.start()
        config = RelayConfig(server.url("/").toString(), "k-test")
    }

    @After
    fun tearDown() = server.shutdown()

    private fun json(body: String, code: Int = 200) =
        server.enqueue(MockResponse().setResponseCode(code).setHeader("Content-Type", "application/json").setBody(body))

    @Test
    fun `dashboard parses the shared fixture with the bearer key`() = runTest {
        json(ConversateResources.read("fixtures/relay-dashboard.json"))
        val d = client().getDashboard()
        val req = server.takeRequest()
        assertEquals("GET", req.method)
        assertEquals("/dashboard", req.path)
        assertEquals("Bearer k-test", req.getHeader("Authorization"))
        assertEquals(3, d.briefing.size)
        assertEquals(listOf("n1", "n2"), d.news.map { it.id })
        assertEquals("@karpathy: new post on LLM evals", d.x.single().title)
        assertEquals(listOf(false, true), d.todos.map { it.completed })
        assertEquals("2026-10-07T21:00:00Z", d.todos[0].dueAt)
        assertNull(d.todos[1].dueAt)
        assertEquals("Prefers morning meetings", d.omi.single().title)
    }

    @Test
    fun `dashboard rows map to panels with to-do done flags`() = runTest {
        json(ConversateResources.read("fixtures/relay-dashboard.json"))
        val d = client().getDashboard()
        assertEquals(
            listOf(
                PanelRow("t1", "Send Q3 churn deck to Sam", "From Omi conversation 'Acme sync'.", false),
                PanelRow("t2", "Book dentist", "", true),
            ),
            d.rows("todos"),
        )
        assertEquals("The chip targets inference workloads and ships in Q1.", d.rows("news")[1].detail)
        assertEquals(emptyList<PanelRow>(), d.rows("weather"))
    }

    @Test
    fun `wrong key is unauthorized`() = runTest {
        json("""{"error":"unauthorized"}""", 401)
        try {
            client().getDashboard(); fail()
        } catch (e: RelayException) {
            assertEquals(RelayException.Kind.UNAUTHORIZED, e.kind)
        }
    }

    @Test
    fun `unconfigured relay never sends a request`() = runTest {
        config = null
        try {
            client().getDashboard(); fail()
        } catch (e: RelayException) {
            assertEquals(RelayException.Kind.NOT_CONFIGURED, e.kind)
        }
        assertEquals(0, server.requestCount)
    }

    @Test
    fun `unreachable relay is a network error`() = runTest {
        val url = server.url("/").toString()
        server.shutdown()
        config = RelayConfig(url, "k")
        try {
            client().getDashboard(); fail()
        } catch (e: RelayException) {
            assertEquals(RelayException.Kind.UNREACHABLE, e.kind)
        }
    }

    @Test
    fun `patch todo sends completed flag`() = runTest {
        json("""{"ok":true,"todo":{"id":"t1","title":"Send Q3 churn deck to Sam","completed":true}}""")
        client().patchTodo("t1", true)
        val req = server.takeRequest()
        assertEquals("PATCH", req.method)
        assertEquals("/todos/t1", req.path)
        assertEquals("""{"completed":true}""", req.body.readUtf8())
        assertEquals("Bearer k-test", req.getHeader("Authorization"))
    }

    @Test
    fun `reminders pass since and parse the shared fixture`() = runTest {
        json(ConversateResources.read("fixtures/relay-reminders.json"))
        val r = client().getReminders(sinceMillis = 1_234L)
        assertEquals("/reminders?since=1234", server.takeRequest().path)
        assertEquals(listOf("r-t1", "r-brief-2026-10-07"), r.map { it.id })
        assertEquals("Due 2pm: Send Q3 churn deck to Sam", r[0].text)
        assertEquals("briefing", r[1].kind)
    }

    @Test
    fun `health needs no key`() = runTest {
        json("""{"ok":true,"version":"0.3.0"}""")
        assertEquals("0.3.0", client().health())
        assertNull(server.takeRequest().getHeader("Authorization"))
    }

    @Test
    fun `ask streams deltas and returns the whole answer`() = runTest {
        server.enqueue(
            MockResponse().setHeader("Content-Type", "text/event-stream").setBody(
                "data: {\"delta\":\"Can\"}\n\ndata: {\"delta\":\"berra.\"}\n\ndata: {\"done\":true}\n\n",
            ),
        )
        val deltas = mutableListOf<String>()
        val answer = client().ask("Capital of Australia?", context = "we talked about travel", deep = false) { deltas += it }
        assertEquals(listOf("Can", "berra."), deltas)
        assertEquals("Canberra.", answer)
        val req = server.takeRequest()
        assertEquals("POST", req.method)
        assertEquals("/ask", req.path)
        val body = req.body.readUtf8()
        assertTrue(body, body.contains("\"question\":\"Capital of Australia?\""))
        assertTrue(body, body.contains("\"context\":\"we talked about travel\""))
        assertTrue(body, body.contains("\"deep\":false"))
    }

    @Test
    fun `ask error event fails the ask`() = runTest {
        server.enqueue(
            MockResponse().setHeader("Content-Type", "text/event-stream")
                .setBody("data: {\"delta\":\"Hm\"}\n\ndata: {\"error\":\"upstream down\"}\n\n"),
        )
        try {
            client().ask("q", null, false) {}; fail()
        } catch (e: RelayException) {
            assertEquals(RelayException.Kind.FAILED, e.kind)
            assertEquals("upstream down", e.message)
        }
    }
}
