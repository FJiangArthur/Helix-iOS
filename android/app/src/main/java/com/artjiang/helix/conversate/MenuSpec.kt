// Loads the shared Conversate contract files (conversate-core/, packaged as
// Java resources by build.gradle.kts). Pure JVM: no Android Context needed.
package com.artjiang.helix.conversate

import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonPrimitive

internal val conversateJson = Json { ignoreUnknownKeys = true }

object ConversateResources {
    fun read(path: String): String {
        val url = ConversateResources::class.java.classLoader?.getResource(path)
            ?: error("conversate-core resource missing: $path")
        return url.readText()
    }
}

@Serializable
data class MenuItemSpec(
    val id: String,
    val label: String? = null,
    val labelOn: String? = null,
    val labelOff: String? = null,
    val toggle: String? = null,
) {
    fun render(flags: Map<String, Boolean>): String =
        if (toggle == null) label ?: id
        else if (flags[toggle] == true) labelOn ?: id
        else labelOff ?: id
}

/** A picker entry (menu v2). [values] are cycled by the display picker; mode items have none. */
@Serializable
data class PickerItemSpec(val id: String, val label: String, val values: List<JsonPrimitive> = emptyList()) {
    val valueStrings: List<String> get() = values.map { it.content }

    fun renderValue(value: String): String = label.replace("{v}", value)
}

@Serializable
data class PickerSpec(val title: String, val items: List<PickerItemSpec>)

@Serializable
data class PanelSpec(val title: String)

@Serializable
data class MenuSpec(
    val version: Int,
    val idle: List<MenuItemSpec>,
    val live: List<MenuItemSpec>,
    val pickers: Map<String, PickerSpec> = emptyMap(),
    val panels: Map<String, PanelSpec> = emptyMap(),
) {
    companion object {
        fun load(): MenuSpec = conversateJson.decodeFromString(serializer(), ConversateResources.read("menu.json"))
    }
}

@Serializable
data class CuePrompt(val version: Int, val maxTokens: Int, val template: String) {
    fun render(transcript: String, prepNote: String, shown: List<String>): String =
        template
            .replace("{{shown}}", if (shown.isEmpty()) "(none)" else shown.joinToString(", "))
            .replace("{{prep_note}}", prepNote.ifBlank { "(none)" })
            .replace("{{transcript}}", transcript)

    companion object {
        fun load(): CuePrompt =
            conversateJson.decodeFromString(serializer(), ConversateResources.read("prompts/cues.v1.json"))
    }
}
