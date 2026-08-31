// Persistence for HelixSettings (Preferences DataStore, single JSON key) and
// API keys (EncryptedSharedPreferences). Port of the settings half of the iOS
// HelixRuntimeDependencies + keychain storage.
package com.artjiang.helix.data

import android.content.Context
import android.content.SharedPreferences
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.booleanPreferencesKey
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.intPreferencesKey
import androidx.datastore.preferences.core.longPreferencesKey
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.core.stringSetPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey
import com.artjiang.helix.ai.KeyStore
import com.artjiang.helix.ai.QuestionSensitivity
import com.artjiang.helix.core.ActiveSkill
import com.artjiang.helix.core.BuiltInSkills
import com.artjiang.helix.core.HelixSettings
import com.artjiang.helix.speech.QuestionMode
import com.artjiang.helix.speech.RealtimeEvents
import com.artjiang.helix.speech.TranscriptionSource
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
        decodeSettings(prefs[SETTINGS_KEY], json)
    }

    /**
     * Reads, transforms, and persists in one DataStore transaction. The read
     * runs the legacy-skill migration, so the first write after an upgrade
     * persists the migrated shape (`legacyActiveSkill` nulled, its value in
     * `customSkills` + `activeSkillID`).
     */
    suspend fun update(transform: (HelixSettings) -> HelixSettings) {
        appContext.helixDataStore.edit { prefs ->
            prefs[SETTINGS_KEY] =
                json.encodeToString(HelixSettings.serializer(), transform(decodeSettings(prefs[SETTINGS_KEY], json)))
        }
    }

    // MARK: - Omi import bookkeeping

    /**
     * When the last successful Omi import finished, or null if never. Kept as
     * its own DataStore key (not a HelixSettings field) so the shared domain
     * type — mirrored from iOS — stays untouched.
     */
    val omiLastImportMillis: Flow<Long?> =
        appContext.helixDataStore.data.map { prefs -> prefs[OMI_LAST_IMPORT_KEY] }

    suspend fun setOmiLastImport(millis: Long) {
        appContext.helixDataStore.edit { prefs -> prefs[OMI_LAST_IMPORT_KEY] = millis }
    }

    // MARK: - Transcription source / question mode (shell-owned)

    /**
     * Which transcript backend the mic button starts. Own DataStore key, not a
     * HelixSettings field, for the same reason as [omiLastImportMillis].
     * Unknown or missing raw values fall back to [TranscriptionSource.DEVICE].
     */
    val transcriptionSource: Flow<TranscriptionSource> =
        appContext.helixDataStore.data.map { prefs -> parseTranscriptionSource(prefs[TRANSCRIPTION_SOURCE_KEY]) }

    suspend fun setTranscriptionSource(source: TranscriptionSource) {
        appContext.helixDataStore.edit { prefs -> prefs[TRANSCRIPTION_SOURCE_KEY] = source.name }
    }

    /** Unknown or missing raw values fall back to [QuestionMode.AUTO_DETECT]. */
    val questionMode: Flow<QuestionMode> =
        appContext.helixDataStore.data.map { prefs -> parseQuestionMode(prefs[QUESTION_MODE_KEY]) }

    suspend fun setQuestionMode(mode: QuestionMode) {
        appContext.helixDataStore.edit { prefs -> prefs[QUESTION_MODE_KEY] = mode.name }
    }

    /** Recall/precision tradeoff for LLM-backed live question pickup. */
    val questionSensitivity: Flow<QuestionSensitivity> =
        appContext.helixDataStore.data.map { prefs ->
            parseQuestionSensitivity(prefs[QUESTION_SENSITIVITY_KEY])
        }

    suspend fun setQuestionSensitivity(sensitivity: QuestionSensitivity) {
        appContext.helixDataStore.edit { prefs ->
            prefs[QUESTION_SENSITIVITY_KEY] = sensitivity.name
        }
    }

    /** OpenAI realtime transcription model; blank → [RealtimeEvents.DEFAULT_MODEL]. */
    val openAiTranscriptionModel: Flow<String> =
        appContext.helixDataStore.data.map { prefs -> parseTranscriptionModel(prefs[OPENAI_TRANSCRIPTION_MODEL_KEY]) }

    suspend fun setOpenAiTranscriptionModel(model: String) {
        appContext.helixDataStore.edit { prefs ->
            prefs[OPENAI_TRANSCRIPTION_MODEL_KEY] = model.trim().ifEmpty { RealtimeEvents.DEFAULT_MODEL }
        }
    }

    // MARK: - Glasses display toggles (shell-owned)

    /**
     * "Notifications on glasses" (iOS `glassesNotificationsEnabled`). Own
     * DataStore keys — [omiLastImportMillis] pattern — so the shared domain
     * type mirrored from iOS stays untouched. Default true, matching iOS.
     */
    val glassesNotificationsEnabled: Flow<Boolean> =
        appContext.helixDataStore.data.map { prefs -> parseGlassesToggle(prefs[GLASSES_NOTIFICATIONS_KEY]) }

    suspend fun setGlassesNotificationsEnabled(enabled: Boolean) {
        appContext.helixDataStore.edit { prefs -> prefs[GLASSES_NOTIFICATIONS_KEY] = enabled }
    }

    /**
     * "Mirror other apps" — whether posted phone notifications from whitelisted
     * apps are forwarded to the glasses. Independent of
     * [glassesNotificationsEnabled], which gates ALL glasses notifications
     * including Helix's own events. Defaults to **off**: mirroring needs
     * notification-listener access, which the user grants in system settings.
     */
    val notificationMirrorEnabled: Flow<Boolean> =
        appContext.helixDataStore.data.map { prefs -> prefs[NOTIFICATION_MIRROR_KEY] ?: false }

    suspend fun setNotificationMirrorEnabled(enabled: Boolean) {
        appContext.helixDataStore.edit { prefs -> prefs[NOTIFICATION_MIRROR_KEY] = enabled }
    }

    /**
     * Package ids the user ticked in the mirroring whitelist. Stored as a
     * DataStore string set; see [sanitizePackages] for the read-side contract.
     */
    val notificationWhitelist: Flow<Set<String>> =
        appContext.helixDataStore.data.map { prefs -> sanitizePackages(prefs[NOTIFICATION_WHITELIST_KEY]) }

    suspend fun setNotificationWhitelist(packages: Set<String>) {
        appContext.helixDataStore.edit { prefs ->
            prefs[NOTIFICATION_WHITELIST_KEY] = sanitizePackages(packages)
        }
    }

    /** Adds or removes one package, leaving the rest of the set untouched. */
    suspend fun setNotificationWhitelisted(packageName: String, whitelisted: Boolean) {
        appContext.helixDataStore.edit { prefs ->
            val current = sanitizePackages(prefs[NOTIFICATION_WHITELIST_KEY])
            val trimmed = packageName.trim()
            prefs[NOTIFICATION_WHITELIST_KEY] =
                if (whitelisted && trimmed.isNotEmpty()) current + trimmed else current - trimmed
        }
    }

    /** "Head-up dashboard" (iOS `dashboardEnabled`); gates the head-up datetime resync. */
    val glassesDashboardEnabled: Flow<Boolean> =
        appContext.helixDataStore.data.map { prefs -> parseGlassesToggle(prefs[GLASSES_DASHBOARD_KEY]) }

    suspend fun setGlassesDashboardEnabled(enabled: Boolean) {
        appContext.helixDataStore.edit { prefs -> prefs[GLASSES_DASHBOARD_KEY] = enabled }
    }

    // MARK: - HUD dwell

    /**
     * Seconds a finished answer stays on the glasses before Helix sends the
     * 0x41 that lets the firmware blank it. Own DataStore key for the same
     * reason as [omiLastImportMillis].
     */
    val hudDwellSeconds: Flow<Int> =
        appContext.helixDataStore.data.map { prefs -> parseHudDwell(prefs[HUD_DWELL_SECONDS_KEY]) }

    suspend fun setHudDwellSeconds(seconds: Int) {
        appContext.helixDataStore.edit { prefs ->
            prefs[HUD_DWELL_SECONDS_KEY] = seconds.coerceIn(MIN_HUD_DWELL_SECONDS, MAX_HUD_DWELL_SECONDS)
        }
    }

    // MARK: - HUD scroll speed

    /**
     * Seconds each HUD page/line stays before the display advances.
     *
     * Drives BOTH the finished-answer auto-advance and the line-scroll cadence
     * while an answer is streaming. Reading speed is personal — the wearer is
     * reading in their peripheral vision while doing something else — so this
     * is a setting rather than the vendor's hard-coded 5 s.
     */
    val hudScrollSeconds: Flow<Int> =
        appContext.helixDataStore.data.map { prefs -> parseHudScroll(prefs[HUD_SCROLL_SECONDS_KEY]) }

    suspend fun setHudScrollSeconds(seconds: Int) {
        appContext.helixDataStore.edit { prefs ->
            prefs[HUD_SCROLL_SECONDS_KEY] =
                seconds.coerceIn(MIN_HUD_SCROLL_SECONDS, MAX_HUD_SCROLL_SECONDS)
        }
    }

    private fun parseHudScroll(raw: Int?): Int =
        (raw ?: DEFAULT_HUD_SCROLL_SECONDS).coerceIn(MIN_HUD_SCROLL_SECONDS, MAX_HUD_SCROLL_SECONDS)

    // MARK: - Triple-tap session toggle

    /**
     * Whether a triple tap on the RIGHT glasses pad starts/stops a
     * transcription session. Off by default: enabling it puts single taps on
     * that pad behind a ~400 ms multi-tap window, which the wearer should opt
     * into rather than discover.
     */
    val sessionTapToggleEnabled: Flow<Boolean> =
        appContext.helixDataStore.data.map { prefs ->
            prefs[SESSION_TAP_TOGGLE_KEY] ?: DEFAULT_SESSION_TAP_TOGGLE
        }

    suspend fun setSessionTapToggleEnabled(enabled: Boolean) {
        appContext.helixDataStore.edit { prefs -> prefs[SESSION_TAP_TOGGLE_KEY] = enabled }
    }

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
        private val OMI_LAST_IMPORT_KEY = longPreferencesKey("omi_last_import_millis")
        private val HUD_DWELL_SECONDS_KEY = intPreferencesKey("hud_dwell_seconds")
        private val SESSION_TAP_TOGGLE_KEY = booleanPreferencesKey("session_tap_toggle_enabled")
        private val HUD_SCROLL_SECONDS_KEY = intPreferencesKey("hud_scroll_seconds")

        /** Vendor default is 5 s (`EvenAI.updateReplyToOSByTimer`: `int interval = 5`). */
        const val DEFAULT_HUD_SCROLL_SECONDS = 3
        const val MIN_HUD_SCROLL_SECONDS = 1
        const val MAX_HUD_SCROLL_SECONDS = 15
        const val DEFAULT_SESSION_TAP_TOGGLE = false

        const val DEFAULT_HUD_DWELL_SECONDS = 3
        const val MIN_HUD_DWELL_SECONDS = 1
        const val MAX_HUD_DWELL_SECONDS = 30

        internal fun parseHudDwell(raw: Int?): Int =
            (raw ?: DEFAULT_HUD_DWELL_SECONDS).coerceIn(MIN_HUD_DWELL_SECONDS, MAX_HUD_DWELL_SECONDS)
        private val TRANSCRIPTION_SOURCE_KEY = stringPreferencesKey("transcription_source")
        private val QUESTION_MODE_KEY = stringPreferencesKey("question_mode")
        private val QUESTION_SENSITIVITY_KEY = stringPreferencesKey("question_sensitivity")
        private val OPENAI_TRANSCRIPTION_MODEL_KEY = stringPreferencesKey("openai_transcription_model")
        private val GLASSES_NOTIFICATIONS_KEY = booleanPreferencesKey("glasses_notifications_enabled")
        private val GLASSES_DASHBOARD_KEY = booleanPreferencesKey("glasses_dashboard_enabled")
        private val NOTIFICATION_MIRROR_KEY = booleanPreferencesKey("notification_mirror_enabled")
        private val NOTIFICATION_WHITELIST_KEY = stringSetPreferencesKey("notification_whitelist")

        /**
         * Whitelist read/write contract: blank entries dropped, values trimmed,
         * duplicates collapsed. A stale or hand-edited store can hold "" or
         * padded ids, and a blank entry would match nothing while a padded one
         * would silently never match its real package.
         */
        internal fun sanitizePackages(raw: Set<String>?): Set<String> =
            raw.orEmpty().mapNotNull { it.trim().takeIf(String::isNotEmpty) }.toSet()

        /** The v1 default skill, which carried no user intent and is not migrated. */
        private const val LEGACY_DEFAULT_NAME = "Assistant"
        private const val LEGACY_DEFAULT_PROMPT = "Concise answers for live conversation."

        /** Missing key -> enabled, matching the iOS defaults. */
        internal fun parseGlassesToggle(raw: Boolean?): Boolean = raw ?: true

        /** Old three-value `ConversationMode` names that no longer exist on the enum. */
        private val LEGACY_MODE_PATTERN = Regex(""""mode"\s*:\s*"(GENERAL|INTERVIEW)"""")

        /**
         * Whether the raw blob carries an explicit `activeSkillID` key. This app
         * always writes with `encodeDefaults = true`, so any settings blob this
         * app itself has ever persisted since the v2 skill system landed carries
         * this key even when its value is the default — its absence means the
         * blob predates skill selection entirely (a bare mode/pre-skill v1 shape,
         * or hand-written test JSON), not that the user picked the default on
         * purpose. That's the signal [migrateInterviewMode] uses to tell "never
         * touched skill selection" apart from "explicitly left it at default."
         */
        private val ACTIVE_SKILL_ID_KEY_PATTERN = Regex(""""activeSkillID"\s*:""")

        /** Decode + migrate; blank or corrupt JSON falls back to defaults. */
        internal fun decodeSettings(raw: String?, json: Json): HelixSettings {
            if (raw.isNullOrBlank()) return migrateLegacySkill(HelixSettings())

            // ConversationMode dropped GENERAL/INTERVIEW (both merged into ACTIVE)
            // as part of making skills — not mode — own answer structure. Rewrite
            // the retired names before decoding: kotlinx.serialization's enum
            // decoder throws on an unrecognized constant, which would otherwise
            // fall through to the catch-all default below and reset the ENTIRE
            // settings blob (provider keys config, skills, toggles, everything)
            // just because of a stale mode string.
            val hadInterviewMode = LEGACY_MODE_PATTERN.find(raw)?.groupValues?.get(1) == "INTERVIEW"
            val hadExplicitSkillId = ACTIVE_SKILL_ID_KEY_PATTERN.containsMatchIn(raw)
            val normalized = LEGACY_MODE_PATTERN.replace(raw) { """"mode":"ACTIVE"""" }

            val decoded = runCatching { json.decodeFromString(HelixSettings.serializer(), normalized) }
                .getOrElse { HelixSettings() }
            val migrated = migrateLegacySkill(decoded)
            return migrateInterviewMode(migrated, hadInterviewMode, hadExplicitSkillId)
        }

        /**
         * A stored INTERVIEW mode meant "shape every answer as a speakable STAR
         * story" — that job now belongs to the `behavioral` skill, not to mode.
         * Carry the user's intent forward by switching them onto it, but only
         * when they never explicitly chose a skill of their own: if the blob
         * ever recorded an `activeSkillID` (even the default one) or a v1 legacy
         * skill migrated above, that recorded choice wins and is left alone.
         */
        internal fun migrateInterviewMode(
            settings: HelixSettings,
            hadInterviewMode: Boolean,
            hadExplicitSkillId: Boolean,
        ): HelixSettings {
            if (!hadInterviewMode) return settings
            val explicitChoiceRecorded = hadExplicitSkillId || settings.customSkills.isNotEmpty()
            if (explicitChoiceRecorded) return settings
            return settings.copy(activeSkillID = "behavioral")
        }

        /**
         * v1 -> v2 skill migration. The old shape stored one inline skill
         * (`activeSkill {name, prompt}`); the new shape (mirroring iOS) stores
         * `activeSkillID` + `customSkills`. A user-edited legacy skill becomes
         * a custom skill and stays active; the untouched v1 default maps to
         * the General Chat built-in. Idempotent: post-migration blobs have
         * `legacyActiveSkill == null` and pass straight through.
         */
        internal fun migrateLegacySkill(current: HelixSettings): HelixSettings {
            val legacy = current.legacyActiveSkill ?: return current
            val stripped = current.copy(legacyActiveSkill = null)

            val label = legacy.legacyName.ifBlank { legacy.label }.trim().ifEmpty { LEGACY_DEFAULT_NAME }
            val prompt = legacy.prompt.trim()
            val isDefaultSkill = label == LEGACY_DEFAULT_NAME && prompt == LEGACY_DEFAULT_PROMPT
            if (prompt.isEmpty() || isDefaultSkill) return stripped

            // Disambiguated so the migrated prompt can never be dropped in
            // favor of an unrelated skill that happens to share the slug.
            val slug = BuiltInSkills.uniqueSlug(
                BuiltInSkills.slugify(label),
                taken = stripped.customSkills.map { it.value }.toSet(),
            )
            val customs = stripped.customSkills + ActiveSkill(value = slug, label = label, prompt = prompt)
            return stripped.copy(activeSkillID = slug, customSkills = customs)
        }

        internal fun parseTranscriptionSource(raw: String?): TranscriptionSource =
            TranscriptionSource.entries.firstOrNull { it.name == raw } ?: TranscriptionSource.DEVICE

        internal fun parseQuestionMode(raw: String?): QuestionMode =
            QuestionMode.entries.firstOrNull { it.name == raw } ?: QuestionMode.AUTO_DETECT

        internal fun parseQuestionSensitivity(raw: String?): QuestionSensitivity =
            QuestionSensitivity.entries.firstOrNull { it.name == raw } ?: QuestionSensitivity.BALANCED

        internal fun parseTranscriptionModel(raw: String?): String =
            raw?.trim()?.takeIf { it.isNotEmpty() } ?: RealtimeEvents.DEFAULT_MODEL
    }
}
