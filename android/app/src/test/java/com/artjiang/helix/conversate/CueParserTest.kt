package com.artjiang.helix.conversate

import kotlinx.serialization.json.boolean
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class CueParserTest {
    @Test
    fun `shared parse vectors`() {
        val cases = conversateJson.parseToJsonElement(ConversateResources.read("vectors/cue-parse.json")).jsonArray
        cases.forEach { el ->
            val c = el.jsonObject
            val name = c["name"]!!.jsonPrimitive.content
            val result = CueParser.parse(c["raw"]!!.jsonPrimitive.content)
            if (c["rejected"]?.jsonPrimitive?.boolean == true) {
                assertNull(name, result)
            } else {
                assertEquals(name, c["titles"]!!.jsonArray.map { it.jsonPrimitive.content }, result!!.map { it.title })
            }
        }
    }

    @Test
    fun `newlines in fields are collapsed`() {
        val cue = CueParser.parse("""{"cues":[{"type":"BIO","title":"Ada\nLovelace","body":"First\n\nprogrammer."}]}""")!!.single()
        assertEquals("Ada Lovelace", cue.title)
        assertEquals("First programmer.", cue.body)
    }

    @Test
    fun `fields are bounded`() {
        val raw = """{"cues":[{"type":"CONCEPT","title":"t","body":"${"b".repeat(400)}","detail":"${"d".repeat(2000)}"}]}"""
        val cue = CueParser.parse(raw)!!.single()
        assertTrue(cue.body.length <= 220)
        assertTrue(cue.detail!!.length <= 1000)
    }
}
