// Persistence for HelixSettings (Preferences DataStore, single JSON key) and
// API keys (EncryptedSharedPreferences). Port of the settings half of the iOS
// HelixRuntimeDependencies + keychain storage.
package com.artjiang.helix.data

import android.content.Context
import android.content.SharedPreferences
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey
import com.artjiang.helix.ai.KeyStore
import com.artjiang.helix.core.HelixSettings
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.map
import kotlinx.serialization.json.Json

private val Context.helixDataStore: DataStore<Preferences> by preferencesDataStore(name = "helix_settings")

/**
 * Settings + API-key storage.
 *
 * Settings live as one JSON blob under a single Preferences key so the whole
 * [HelixSettings] value type round-trips atomically; adding a field to the
 * domain type needs no migration here.
 *
 * API keys never touch DataStore — they go to EncryptedSharedPreferences and
 * are surfaced to the AI layer through the [KeyStore] contract, so a key value
 * is never persisted in plaintext nor serialized into settings JSON.
 */
class SettingsRepository(context: Context) : KeyStore {

    private val appContext = context.applicationContext
    private val json = Json {
        ignoreUnknownKeys = true
        encodeDefaults = true
    }

    private val encryptedPrefs: SharedPreferences by lazy {
        val masterKey = MasterKey.Builder(appContext)
            .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
            .build()
        EncryptedSharedPreferences.create(
            appContext,
            SECURE_PREFS_NAME,
            masterKey,
            EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
            EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM,
        )
    }

    /**
     * Bumped whenever a key is written or removed so [KeyStore] consumers (the
     * provider factory) can be rebuilt: encrypted prefs are not a Flow source.
     */
    private val keyRevisionState = MutableStateFlow(0)
    val keyRevision: StateFlow<Int> = keyRevisionState

    val settings: Flow<HelixSettings> = appContext.helixDataStore.data.map { prefs ->
        val raw = prefs[SETTINGS_KEY]
        if (raw.isNullOrBlank()) {
            HelixSettings()
        } else {
            runCatching { json.decodeFromString(HelixSettings.serializer(), raw) }
                .getOrElse { HelixSettings() }
        }
    }

    /** Reads, transforms, and persists in one DataStore transaction. */
    suspend fun update(transform: (HelixSettings) -> HelixSettings) {
        appContext.helixDataStore.edit { prefs ->
            val current = prefs[SETTINGS_KEY]
                ?.let { raw -> runCatching { json.decodeFromString(HelixSettings.serializer(), raw) }.getOrNull() }
                ?: HelixSettings()
            prefs[SETTINGS_KEY] = json.encodeToString(HelixSettings.serializer(), transform(current))
        }
    }

    suspend fun save(settings: HelixSettings) = update { settings }

    // MARK: - KeyStore

    override fun keyFor(kind: String): String? =
        encryptedPrefs.getString(keyName(kind), null)?.takeIf { it.isNotBlank() }

    fun hasKey(kind: String): Boolean = !keyFor(kind).isNullOrBlank()

    /** Passing null (or blank) removes the stored key. */
    fun setKey(kind: String, value: String?) {
        val trimmed = value?.trim()
        encryptedPrefs.edit().apply {
            if (trimmed.isNullOrEmpty()) remove(keyName(kind)) else putString(keyName(kind), trimmed)
        }.apply()
        keyRevisionState.value = keyRevisionState.value + 1
    }

    private fun keyName(kind: String): String = "api_key_${kind.uppercase()}"

    companion object {
        private const val SECURE_PREFS_NAME = "helix_secure_keys"
        private val SETTINGS_KEY = stringPreferencesKey("settings_json")
    }
}
