// Device-neutral input for Conversate (spec §4.1). Every device maps its raw
// gestures to these intents; the state machine never sees raw events.
package com.artjiang.helix.conversate

import com.artjiang.helix.g1.G1StatusEvent
import com.artjiang.helix.g1.G1TouchpadFrame
import com.artjiang.helix.g1.G1TouchpadSide

enum class ConversateIntent { NEXT, PREV, SELECT, BACK, MENU, HEAD_UP, HEAD_DOWN }

enum class IntentSource { G1_TOUCHPAD, R1, PHONE }

/**
 * G1 touchpad -> intent. Indices per SLA: 0 double-tap, 1 tap (side),
 * 23 left long-press, 24 its release. Long-press doubles as SELECT while a
 * list is open because the G1 has no other select gesture; its release (24)
 * is part of the same physical gesture and is swallowed.
 */
object G1InputMapper {
    fun map(frame: G1TouchpadFrame, selectContext: Boolean): ConversateIntent? = when (frame.notifyIndex) {
        0 -> ConversateIntent.BACK
        1 -> if (frame.side == G1TouchpadSide.RIGHT) ConversateIntent.NEXT else ConversateIntent.PREV
        23 -> if (selectContext) ConversateIntent.SELECT else ConversateIntent.MENU
        else -> null
    }

    fun map(event: G1StatusEvent?): ConversateIntent? = when (event) {
        G1StatusEvent.HeadUp -> ConversateIntent.HEAD_UP
        G1StatusEvent.HeadDown -> ConversateIntent.HEAD_DOWN
        else -> null
    }
}

/** Drops the same intent arriving from a different source within [windowMillis]. */
class IntentDeduper(private val clock: () -> Long, private val windowMillis: Long = 250) {
    private var lastIntent: ConversateIntent? = null
    private var lastSource: IntentSource? = null
    private var lastAt: Long = Long.MIN_VALUE / 2

    fun accept(intent: ConversateIntent, source: IntentSource): Boolean {
        val now = clock()
        val duplicate = intent == lastIntent && source != lastSource && now - lastAt < windowMillis
        if (duplicate) return false
        lastIntent = intent
        lastSource = source
        lastAt = now
        return true
    }
}
