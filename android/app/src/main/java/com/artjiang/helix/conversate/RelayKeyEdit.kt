// What "Save" / "Remove key" in Settings > Helix relay does to the stored
// bearer key. The key field never shows the saved secret, so an empty field
// means "keep"; removing is explicit, and clearing the URL clears the relay
// (key included) entirely.
package com.artjiang.helix.conversate

import okhttp3.HttpUrl.Companion.toHttpUrlOrNull

sealed interface RelayKeyEdit {
    /** Value for SettingsRepository.setKey: null deletes the stored key. */
    val storedValue: String?

    data object Keep : RelayKeyEdit {
        override val storedValue: String? get() = error("Keep does not write the key store")
    }

    data object Remove : RelayKeyEdit {
        override val storedValue: String? get() = null
    }

    data class Replace(val key: String) : RelayKeyEdit {
        override val storedValue: String get() = key
    }

    companion object {
        /**
         * Security: the stored key belongs to the relay origin it was entered
         * for. Pointing Helix at a different host without typing a key drops
         * it, so a mistyped or hostile URL never receives the relay key.
         */
        fun resolve(url: String, typedKey: String, removeRequested: Boolean, previousUrl: String? = null): RelayKeyEdit = when {
            removeRequested || url.isBlank() -> Remove
            typedKey.isBlank() && previousUrl != null && origin(url) != origin(previousUrl) -> Remove
            typedKey.isBlank() -> Keep
            else -> Replace(typedKey.trim())
        }

        private fun origin(url: String): String? =
            url.trim().toHttpUrlOrNull()?.let { "${it.scheme}://${it.host}:${it.port}" }
    }
}
