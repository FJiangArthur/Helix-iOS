package com.artjiang.helix.data

import com.artjiang.helix.core.ActiveSkill
import com.artjiang.helix.core.BuiltInSkills
import com.artjiang.helix.core.HelixSettings
import kotlinx.serialization.json.Json
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * v1 settings blobs stored one inline skill (`activeSkill {name, prompt}`).
 * [SettingsRepository.decodeSettings] must keep those decodable and migrate
 * them into the v2 `activeSkillID` + `customSkills` shape (mirroring iOS
 * HelixDomain.swift) without losing a user-authored skill.
 */
class SettingsMigrationTest {

    // Same configuration as SettingsRepository's private instance.
    private val json = Json {
        ignoreUnknownKeys = true
        encodeDefaults = true
    }

    private fun decode(raw: String?): HelixSettings = SettingsRepository.decodeSettings(raw, json)

    @Test
    fun `blank and corrupt blobs fall back to defaults`() {
        assertEquals(HelixSettings(), decode(null))
        assertEquals(HelixSettings(), decode("   "))
        assertEquals(HelixSettings(), decode("{not json"))
        assertEquals(BuiltInSkills.DEFAULT_VALUE, decode(null).activeSkillID)
    }

    @Test
    fun `legacy user-authored skill becomes an active custom skill`() {
        val settings = decode(
            """{"mode":"INTERVIEW","activeSkill":{"name":"Sales Coaching","prompt":"Sell the outcome."}}""",
        )
        assertNull(settings.legacyActiveSkill)
        // The v1 blob carried its own explicit skill (Sales Coaching), so mode
        // migration must not steamroll it with "behavioral" — the user's actual
        // choice wins.
        assertEquals("sales-coaching", settings.activeSkillID)
        val custom = settings.customSkills.single()
        assertEquals(ActiveSkill(value = "sales-coaching", label = "Sales Coaching", prompt = "Sell the outcome."), custom)
        // The migrated skill is what answers resolve to.
        assertEquals("Sell the outcome.", settings.resolvedSkill().prompt)
        // Mode collapsed from the retired INTERVIEW value into ACTIVE.
        assertEquals(com.artjiang.helix.core.ConversationMode.ACTIVE, settings.mode)
    }

    @Test
    fun `legacy default skill maps to the General Chat built-in with no custom`() {
        val settings = decode(
            """{"activeSkill":{"name":"Assistant","prompt":"Concise answers for live conversation."}}""",
        )
        assertNull(settings.legacyActiveSkill)
        assertEquals(BuiltInSkills.DEFAULT_VALUE, settings.activeSkillID)
        assertTrue(settings.customSkills.isEmpty())
        assertEquals("General Chat", settings.resolvedSkill().label)
    }

    @Test
    fun `legacy skill colliding with a built-in id is suffixed so it stays visible`() {
        val settings = decode(
            """{"activeSkill":{"name":"Programming","prompt":"My own programming style."}}""",
        )
        assertEquals("programming-custom", settings.activeSkillID)
        assertEquals("My own programming style.", settings.resolvedSkill().prompt)
        assertTrue(settings.selectableSkills().any { it.value == "programming-custom" })
    }

    @Test
    fun `migration is idempotent and the migrated shape round-trips`() {
        val migrated = decode("""{"activeSkill":{"name":"Sales","prompt":"Sell."}}""")
        val roundTripped = decode(json.encodeToString(HelixSettings.serializer(), migrated))
        assertEquals(migrated, roundTripped)
        assertEquals("sales", roundTripped.activeSkillID)
        assertEquals(1, roundTripped.customSkills.size)
    }

    @Test
    fun `v2 blob with skill id and customs decodes without migration`() {
        val settings = decode(
            """
            {"activeSkillID":"sales","customSkills":[{"value":"sales","label":"Sales","prompt":"Sell."}]}
            """.trimIndent(),
        )
        assertEquals("sales", settings.activeSkillID)
        assertEquals("Sales", settings.resolvedSkill().label)
        assertNull(settings.legacyActiveSkill)
    }

    @Test
    fun `legacy blob whose prompt is blank maps to the default built-in`() {
        val settings = decode("""{"activeSkill":{"name":"Whatever","prompt":"  "}}""")
        assertEquals(BuiltInSkills.DEFAULT_VALUE, settings.activeSkillID)
        assertTrue(settings.customSkills.isEmpty())
    }

    // MARK: ConversationMode collapse (GENERAL + INTERVIEW -> ACTIVE)
    //
    // ConversationMode dropped GENERAL/INTERVIEW because mode was never
    // supposed to dictate answer *structure* — that regressed skill selection
    // (e.g. Social Confidence still answering as a STAR interview coach).
    // These blobs are what real installs have on disk today, so decoding a
    // stored "GENERAL" or "INTERVIEW" must not throw and must not blow away
    // the rest of settings (provider config, keys, toggles) the way a raw
    // decode failure falling back to `HelixSettings()` would.

    @Test
    fun `stored GENERAL mode decodes to ACTIVE without resetting other fields`() {
        val settings = decode("""{"mode":"GENERAL","maxResponseSentences":7,"factCheck":false}""")
        assertEquals(com.artjiang.helix.core.ConversationMode.ACTIVE, settings.mode)
        assertEquals(7, settings.maxResponseSentences)
        assertEquals(false, settings.factCheck)
    }

    @Test
    fun `stored INTERVIEW mode decodes to ACTIVE without resetting other fields`() {
        val settings = decode("""{"mode":"INTERVIEW","maxResponseSentences":2}""")
        assertEquals(com.artjiang.helix.core.ConversationMode.ACTIVE, settings.mode)
        assertEquals(2, settings.maxResponseSentences)
    }

    @Test
    fun `INTERVIEW mode with no recorded skill choice adopts the behavioral skill`() {
        // No activeSkillID key at all: this blob predates skill selection, so
        // the user never made an explicit skill choice to preserve. INTERVIEW's
        // old STAR behavior is carried forward onto the skill that now owns it.
        val settings = decode("""{"mode":"INTERVIEW"}""")
        assertEquals("behavioral", settings.activeSkillID)
    }

    @Test
    fun `INTERVIEW mode with an explicit default skill choice is left alone`() {
        // activeSkillID key IS present, even though its value is the ordinary
        // default — this app always writes activeSkillID once it exists, so
        // its presence means the user's settings already went through the v2
        // skill system, not that they typed nothing.
        val settings = decode("""{"mode":"INTERVIEW","activeSkillID":"general-chat"}""")
        assertEquals("general-chat", settings.activeSkillID)
    }

    @Test
    fun `INTERVIEW mode with a different explicit skill choice is left alone`() {
        val settings = decode("""{"mode":"INTERVIEW","activeSkillID":"social-confidence"}""")
        assertEquals("social-confidence", settings.activeSkillID)
    }

    @Test
    fun `GENERAL mode never adopts the behavioral skill`() {
        val settings = decode("""{"mode":"GENERAL"}""")
        assertEquals(BuiltInSkills.DEFAULT_VALUE, settings.activeSkillID)
    }
}
