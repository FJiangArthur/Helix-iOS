package com.artjiang.helix.ai

import com.artjiang.helix.core.AnswerProvider
import com.artjiang.helix.core.HelixSettings
import com.artjiang.helix.core.ProviderKind
import okhttp3.OkHttpClient

/**
 * Supplies API keys. The app layer implements this over encrypted storage; tests
 * and keyless operation supply [EmptyKeyStore].
 */
interface KeyStore {
    /** @param kind the [ProviderKind] name, e.g. "OPENAI". Returns null/blank when unset. */
    fun keyFor(kind: String): String?
}

object EmptyKeyStore : KeyStore {
    override fun keyFor(kind: String): String? = null
}

/** In-memory keystore for tests and previews. */
class MapKeyStore(private val keys: Map<String, String>) : KeyStore {
    override fun keyFor(kind: String): String? = keys[kind]
}

/**
 * Builds the concrete provider for the active settings. Falls back to
 * [DeterministicProvider] whenever no API key is stored, so the whole pipeline
 * stays functional and testable without credentials.
 */
class ProviderFactory(
    private val keyStore: KeyStore = EmptyKeyStore,
    private val client: OkHttpClient = OpenAiCompatibleProvider.defaultClient,
    private val endpointOverride: String? = null,
) {

    fun make(settings: HelixSettings): AnswerProvider {
        val kind = parseKind(settings.activeProvider)
        if (kind == ProviderKind.DETERMINISTIC) return DeterministicProvider()

        val key = keyStore.keyFor(kind.name)?.trim().orEmpty()
        if (key.isEmpty()) return DeterministicProvider(kind = kind)

        val model = smartModel(settings, kind)
        val baseUrl = endpointOverride ?: ProviderEndpoints.forKind(kind)

        return when (kind) {
            ProviderKind.ANTHROPIC -> AnthropicProvider(
                apiKey = key,
                model = model,
                baseUrl = baseUrl,
                client = client,
            )

            else -> OpenAiCompatibleProvider(
                apiKey = key,
                model = model,
                kind = kind,
                baseUrl = baseUrl,
                client = client,
            )
        }
    }

    private fun smartModel(settings: HelixSettings, kind: ProviderKind): String {
        val configured = settings.providers[kind.name]?.smartModel?.trim().orEmpty()
        return configured.ifEmpty { OpenAiCompatibleProvider.defaultModelFor(kind) }
    }

    companion object {
        fun parseKind(raw: String): ProviderKind =
            ProviderKind.entries.firstOrNull { it.name.equals(raw.trim(), ignoreCase = true) }
                ?: ProviderKind.DETERMINISTIC
    }
}
