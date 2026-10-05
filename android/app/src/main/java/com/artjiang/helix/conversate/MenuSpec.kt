// Loads the shared Conversate contract files (conversate-core/, packaged as
// Java resources by build.gradle.kts). Pure JVM: no Android Context needed.
package com.artjiang.helix.conversate

import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json

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

@Serializable
data class MenuSpec(val version: Int, val idle: List<MenuItemSpec>, val live: List<MenuItemSpec>) {
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
