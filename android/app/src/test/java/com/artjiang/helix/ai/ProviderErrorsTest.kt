package com.artjiang.helix.ai

import com.artjiang.helix.core.ProviderKind
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.IOException
import java.net.ConnectException
import java.net.SocketTimeoutException
import java.net.UnknownHostException

class ProviderErrorsTest {

    @Test
    fun `401 reads as a rejected key for the provider`() {
        assertEquals(
            "OpenAI rejected the API key (401). Check the key in Settings.",
            ProviderErrors.describe(ProviderHttpException(ProviderKind.OPENAI, 401, """{"error":"bad key"}""")),
        )
        assertEquals(
            "Anthropic rejected the API key (401). Check the key in Settings.",
            ProviderErrors.invalidKey(ProviderKind.ANTHROPIC),
        )
    }

    @Test
    fun `other http statuses are friendly and name the provider`() {
        val forbidden = ProviderErrors.describe(ProviderHttpException(ProviderKind.DEEPSEEK, 403, ""))
        assertTrue(forbidden, forbidden.startsWith("DeepSeek") && forbidden.contains("403"))

        val rate = ProviderErrors.describe(ProviderHttpException(ProviderKind.QWEN, 429, ""))
        assertTrue(rate, rate.startsWith("Qwen") && rate.contains("429"))

        val outage = ProviderErrors.describe(ProviderHttpException(ProviderKind.ZHIPU, 503, "<html>"))
        assertTrue(outage, outage.startsWith("Zhipu") && outage.contains("503"))
        assertTrue("body must not leak", !outage.contains("<html>"))

        val other = ProviderErrors.describe(ProviderHttpException(ProviderKind.OPENAI, 418, ""))
        assertEquals("OpenAI request failed (HTTP 418).", other)
    }

    @Test
    fun `missing key and empty response are explained`() {
        assertEquals(
            "No OpenAI API key. Add one in Settings to get answers.",
            ProviderErrors.describe(MissingApiKeyException(ProviderKind.OPENAI)),
        )
        assertEquals(
            "Anthropic returned an empty answer. Try again.",
            ProviderErrors.describe(ProviderEmptyResponseException(ProviderKind.ANTHROPIC)),
        )
    }

    @Test
    fun `transport failures are mapped without raw exception text`() {
        assertEquals(
            "No internet connection. Check the network and try again.",
            ProviderErrors.describe(UnknownHostException("api.openai.com")),
        )
        assertEquals(
            "The AI provider took too long to respond. Try again.",
            ProviderErrors.describe(SocketTimeoutException("timeout")),
        )
        assertTrue(ProviderErrors.describe(ConnectException("refused")).contains("Could not reach"))
        assertEquals("Network error: reset by peer.", ProviderErrors.describe(IOException("reset by peer")))
        assertEquals("Network error: request failed.", ProviderErrors.describe(IOException()))
    }

    @Test
    fun `unknown errors fall back to the message or type`() {
        assertEquals("boom", ProviderErrors.describe(IllegalStateException("boom")))
        assertEquals("Unexpected error: IllegalStateException", ProviderErrors.describe(IllegalStateException()))
    }
}
