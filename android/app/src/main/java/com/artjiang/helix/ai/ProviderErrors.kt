package com.artjiang.helix.ai

import com.artjiang.helix.core.ProviderKind
import java.io.IOException
import java.io.InterruptedIOException
import java.net.ConnectException
import java.net.SocketTimeoutException
import java.net.UnknownHostException
import javax.net.ssl.SSLException

/**
 * Maps provider/transport failures to one-line, user-facing messages. The
 * raw exception text (HTTP body snippets, stack-ish detail) belongs in the
 * event log, not in a banner; a 401 in particular must read as "your key is
 * wrong", because on the Assistant screen it used to look like transcription
 * was broken.
 */
object ProviderErrors {

    fun invalidKey(kind: ProviderKind): String =
        "${kind.displayName} rejected the API key (401). Check the key in Settings."

    fun describe(error: Throwable): String = when (error) {
        is ProviderHttpException -> describeHttp(error)
        is MissingApiKeyException ->
            "No ${error.providerKind.displayName} API key. Add one in Settings to get answers."
        is ProviderEmptyResponseException ->
            "${error.providerKind.displayName} returned an empty answer. Try again."
        is UnknownHostException -> "No internet connection. Check the network and try again."
        is SocketTimeoutException, is InterruptedIOException ->
            "The AI provider took too long to respond. Try again."
        is ConnectException -> "Could not reach the AI provider. Check the network and try again."
        is SSLException -> "Secure connection to the AI provider failed. Check the network and try again."
        is IOException -> "Network error: ${error.message?.takeIf { it.isNotBlank() } ?: "request failed"}."
        else -> error.message?.takeIf { it.isNotBlank() } ?: "Unexpected error: ${error::class.simpleName}"
    }

    private fun describeHttp(error: ProviderHttpException): String {
        val name = error.providerKind.displayName
        return when (val code = error.statusCode) {
            401 -> invalidKey(error.providerKind)
            403 -> "$name refused the request (403). The key may lack access to this model."
            404 -> "$name could not find the model (404). Check the model name in Settings."
            429 -> "$name rate limit or quota exceeded (429). Wait a moment and try again."
            in 500..599 -> "$name is having trouble (HTTP $code). Try again in a moment."
            else -> "$name request failed (HTTP $code)."
        }
    }
}
