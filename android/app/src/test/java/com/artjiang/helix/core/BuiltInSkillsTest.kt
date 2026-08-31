package com.artjiang.helix.core

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * The skill table and resolution rules are a verbatim port of the iOS
 * `ActiveSkill` statics (HelixDomain.swift); these tests pin the ids, labels,
 * and the sanitize/selectable semantics so the platforms cannot drift.
 */
class BuiltInSkillsTest {

    @Test
    fun `leads with the six iOS built-ins in their iOS order`() {
        assertEquals(
            listOf("dsa", "programming", "system-design", "behavioral", "discussion-strategy", "general-chat"),
            BuiltInSkills.all.take(6).map { it.value },
        )
        assertEquals(
            listOf(
                "Data Structures & Algorithms",
                "Programming",
                "System Design",
                "Behavioral Interview",
                "Discussion Strategy",
                "General Chat",
            ),
            BuiltInSkills.all.take(6).map { it.label },
        )
    }

    @Test
    fun `ships the android social skills after the iOS six`() {
        assertEquals(
            listOf(
                "friendly-conversation",
                "witty",
                "social-confidence",
                "startup-founder",
                "networking",
                "debate",
                "language-practice",
            ),
            BuiltInSkills.all.drop(6).map { it.value },
        )
    }

    @Test
    fun `every built-in has a unique non-blank id label and prompt`() {
        assertTrue(BuiltInSkills.all.all { it.isBuiltIn })
        assertTrue(BuiltInSkills.all.all { it.value.isNotBlank() })
        assertTrue(BuiltInSkills.all.all { it.label.isNotBlank() })
        assertTrue(BuiltInSkills.all.all { it.prompt.isNotBlank() })
        assertEquals(BuiltInSkills.all.size, BuiltInSkills.all.map { it.value }.toSet().size)
        assertEquals(BuiltInSkills.all.size, BuiltInSkills.all.map { it.label }.toSet().size)
        assertEquals(BuiltInSkills.all.size, BuiltInSkills.all.map { it.prompt }.toSet().size)
    }

    @Test
    fun `ids are url-safe slugs that survive a slugify round trip`() {
        BuiltInSkills.all.forEach { skill ->
            assertTrue(skill.value, skill.value.matches(Regex("[a-z0-9]+(-[a-z0-9]+)*")))
            assertEquals(skill.value, BuiltInSkills.slugify(skill.value))
        }
    }

    /** House rule from CLAUDE.md: prompts must produce directly speakable output. */
    @Test
    fun `no built-in prompt uses banned meta phrasing`() {
        val banned = listOf("you could say", "here's a suggestion", "here is a suggestion")
        BuiltInSkills.all.forEach { skill ->
            val prompt = skill.prompt.lowercase()
            banned.forEach { phrase ->
                assertFalse("${skill.value} contains \"$phrase\"", prompt.contains(phrase))
            }
        }
    }

    @Test
    fun `the default skill still resolves to a built-in`() {
        val default = BuiltInSkills.skillFor(BuiltInSkills.DEFAULT_VALUE)
        assertEquals(BuiltInSkills.DEFAULT_VALUE, default.value)
        assertTrue(default.isBuiltIn)
        assertTrue(BuiltInSkills.all.any { it.value == BuiltInSkills.DEFAULT_VALUE })
    }

    @Test
    fun `every built-in id resolves back to itself`() {
        BuiltInSkills.all.forEach { skill ->
            assertEquals(skill.value, BuiltInSkills.sanitize(skill.value))
            assertEquals(skill, BuiltInSkills.skillFor(skill.value))
        }
    }

    @Test
    fun `selectable is every built-in plus the customs`() {
        val customs = listOf(ActiveSkill(value = "sales", label = "Sales", prompt = "Sell."))
        val selectable = BuiltInSkills.selectable(customs)
        assertEquals(BuiltInSkills.all + customs, selectable)
        assertTrue(BuiltInSkills.all.all { built -> selectable.any { it.value == built.value } })
    }

    @Test
    fun `selectable appends valid customs and drops duplicates and blanks`() {
        val customs = listOf(
            ActiveSkill(value = "sales", label = "Sales", prompt = "Sell."),
            ActiveSkill(value = "dsa", label = "Shadowing built-in", prompt = "x"), // duplicate id
            ActiveSkill(value = "", label = "No id", prompt = "x"),
            ActiveSkill(value = "no-label", label = "", prompt = "x"),
            ActiveSkill(value = "sales", label = "Dup custom", prompt = "x"),
        )
        val selectable = BuiltInSkills.selectable(customs)
        assertEquals(BuiltInSkills.all.size + 1, selectable.size)
        assertEquals("Sales", selectable.last().label)
    }

    @Test
    fun `sanitize maps mock ids and falls back for unknown or blank values`() {
        assertEquals("dsa", BuiltInSkills.sanitize("mock-dsa"))
        assertEquals("behavioral", BuiltInSkills.sanitize("mock-behavioral"))
        assertEquals("programming", BuiltInSkills.sanitize(" programming "))
        assertEquals(BuiltInSkills.DEFAULT_VALUE, BuiltInSkills.sanitize(null))
        assertEquals(BuiltInSkills.DEFAULT_VALUE, BuiltInSkills.sanitize("  "))
        assertEquals(BuiltInSkills.DEFAULT_VALUE, BuiltInSkills.sanitize("nope"))
    }

    @Test
    fun `sanitize accepts a custom id only when the custom exists`() {
        val customs = listOf(ActiveSkill(value = "sales", label = "Sales", prompt = "Sell."))
        assertEquals("sales", BuiltInSkills.sanitize("sales", customs))
        assertEquals(BuiltInSkills.DEFAULT_VALUE, BuiltInSkills.sanitize("sales"))
    }

    @Test
    fun `skillFor resolves built-ins customs and the general fallback`() {
        val customs = listOf(ActiveSkill(value = "sales", label = "Sales", prompt = "Sell."))
        assertEquals("System Design", BuiltInSkills.skillFor("system-design").label)
        assertEquals("Sales", BuiltInSkills.skillFor("sales", customs).label)
        assertEquals("General Chat", BuiltInSkills.skillFor("missing", customs).label)
        assertEquals("General Chat", BuiltInSkills.skillFor(null).label)
    }

    @Test
    fun `settings resolution helpers use the id and custom list`() {
        val custom = ActiveSkill(value = "sales", label = "Sales", prompt = "Sell.")
        val settings = HelixSettings(activeSkillID = "sales", customSkills = listOf(custom))
        assertEquals(custom, settings.resolvedSkill())
        assertEquals("General Chat", HelixSettings().resolvedSkill().label)
        assertEquals(BuiltInSkills.all.size + 1, settings.selectableSkills().size)
    }

    @Test
    fun `slugify matches the iOS custom-skill sheet`() {
        assertEquals("sales-coaching", BuiltInSkills.slugify("Sales Coaching"))
        assertEquals("q-a-live", BuiltInSkills.slugify(" Q&A: Live! "))
        assertEquals("", BuiltInSkills.slugify("!!!"))
    }

    @Test
    fun `legacy name accessor prefers the stable id`() {
        assertEquals("dsa", ActiveSkill(value = "dsa", label = "DSA", prompt = "x").name)
        assertEquals("Old Name", ActiveSkill(legacyName = "Old Name", prompt = "x").name)
        assertFalse(ActiveSkill().name.isNotEmpty())
    }
}
