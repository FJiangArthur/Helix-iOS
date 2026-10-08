package com.artjiang.helix.conversate

import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.boolean
import kotlinx.serialization.json.int
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.json.long
import org.junit.Assert.assertEquals
import org.junit.Test

class SessionVectorTest {
    @Test fun menu() = run("vectors/session-menu.json")
    @Test fun cues() = run("vectors/session-cues.json")
    @Test fun end() = run("vectors/session-end.json")
    @Test fun pickers() = run("vectors/session-pickers.json")
    @Test fun panels() = run("vectors/session-panels.json")

    private fun run(path: String) {
        val root = conversateJson.parseToJsonElement(ConversateResources.read(path)).jsonObject
        val name = root["name"]!!.jsonPrimitive.content
        var now = 0L
        val p = root["prefs"]?.jsonObject
        val prefs = ConversatePrefs(
            captionsOn = p?.get("captionsOn")?.jsonPrimitive?.boolean ?: true,
            cuesOn = p?.get("cuesOn")?.jsonPrimitive?.boolean ?: true,
            autoPopup = p?.get("autoPopup")?.jsonPrimitive?.boolean ?: true,
            cueDurationMillis = p?.get("cueDurationMillis")?.jsonPrimitive?.long ?: 6_000,
        )
        val s = ConversateSession(MenuSpec.load(), { now }, prefs)
        root["prepNotes"]?.jsonArray?.map {
            val o = it.jsonObject
            PrepNoteRef(o["id"]!!.jsonPrimitive.content, o["title"]!!.jsonPrimitive.content, o["text"]!!.jsonPrimitive.content)
        }?.let(s::setPrepNotes)
        root["steps"]!!.jsonArray.forEachIndexed { i, el ->
            val step = el.jsonObject
            val where = "$name step $i"
            step["advance"]?.let { now += it.jsonPrimitive.long }
            var effects = emptyList<SessionEffect>()
            step["start"]?.let { effects = s.startLive(if (it is JsonNull) null else it.jsonPrimitive.content) }
            step["captions"]?.let { s.onCaptionLines(it.jsonArray.map { l -> l.jsonPrimitive.content }) }
            step["cue"]?.jsonObject?.let { c ->
                s.onCue(Cue(c["id"]!!.jsonPrimitive.long, CueType.valueOf(c["type"]!!.jsonPrimitive.content),
                    c["title"]!!.jsonPrimitive.content, c["body"]!!.jsonPrimitive.content, createdAtMillis = now))
            }
            if (step["tick"]?.jsonPrimitive?.boolean == true) s.tick()
            step["panelRows"]?.jsonObject?.let { pr ->
                s.setPanelRows(pr["kind"]!!.jsonPrimitive.content, pr["rows"]!!.jsonArray.map { r ->
                    val o = r.jsonObject
                    PanelRow(
                        o["id"]!!.jsonPrimitive.content,
                        o["title"]!!.jsonPrimitive.content,
                        o["detail"]?.jsonPrimitive?.content.orEmpty(),
                        o["done"]?.jsonPrimitive?.boolean ?: false,
                    )
                })
            }
            step["askText"]?.let { effects = s.onAskText(it.jsonPrimitive.content) }
            step["intent"]?.let { effects = s.onIntent(ConversateIntent.valueOf(it.jsonPrimitive.content)) }
            step["effects"]?.let { assertEquals(where, it.jsonArray.map { e -> e.jsonPrimitive.content }, effects.map(::label)) }
            step["expect"]?.jsonObject?.let { check(where, it, s) }
        }
    }

    private fun label(e: SessionEffect) = when (e) {
        is SessionEffect.Start -> "Start:${e.prepNoteId}"
        SessionEffect.End -> "End"
        is SessionEffect.SetPaused -> "SetPaused:${e.paused}"
        is SessionEffect.SetCaptions -> "SetCaptions:${e.on}"
        is SessionEffect.SetCues -> "SetCues:${e.on}"
        is SessionEffect.SetMode -> "SetMode:${e.mode.name}"
        is SessionEffect.SetPref -> "SetPref:${e.id}=${e.value}"
        is SessionEffect.RequestPanel -> "RequestPanel:${e.kind}"
        is SessionEffect.ToggleTodo -> "ToggleTodo:${e.id}=${e.done}"
        SessionEffect.AskListen -> "AskListen"
        is SessionEffect.AskQuestion -> "AskQuestion:${e.text}"
        SessionEffect.AskCancel -> "AskCancel"
    }

    private fun check(where: String, e: JsonObject, s: ConversateSession) {
        val screen = s.screen()
        e["kind"]?.let { assertEquals(where, it.jsonPrimitive.content, screen::class.simpleName) }
        e["live"]?.let { assertEquals(where, it.jsonPrimitive.boolean, s.isLive) }
        e["cueId"]?.let {
            val id = when (screen) { is ScreenModel.Live -> screen.cue?.id; is ScreenModel.CueDetail -> screen.cue.id; else -> null }
            assertEquals(where, it.jsonPrimitive.long, id)
        }
        e["pendingCount"]?.let { assertEquals(where, it.jsonPrimitive.int, (screen as ScreenModel.Live).pendingCount) }
        e["cursor"]?.let {
            val cursor = when (screen) { is ScreenModel.Menu -> screen.cursor; is ScreenModel.Panel -> screen.cursor; else -> -1 }
            assertEquals(where, it.jsonPrimitive.int, cursor)
        }
        e["items"]?.let {
            val items = when (screen) { is ScreenModel.Menu -> screen.items; is ScreenModel.Panel -> screen.items; else -> null }
            assertEquals(where, (it as JsonArray).map { x -> x.jsonPrimitive.content }, items)
        }
        e["title"]?.let {
            val title = when (screen) { is ScreenModel.Menu -> screen.title; is ScreenModel.Panel -> screen.title; else -> null }
            assertEquals(where, it.jsonPrimitive.content, title)
        }
        e["page"]?.let {
            val page = when (screen) {
                is ScreenModel.CueDetail -> screen.page
                is ScreenModel.PrepNoteView -> screen.page
                is ScreenModel.PanelDetail -> screen.page
                else -> -1
            }
            assertEquals(where, it.jsonPrimitive.int, page)
        }
    }
}
