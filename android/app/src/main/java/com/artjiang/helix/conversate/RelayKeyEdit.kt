// What "Save" / "Remove key" in Settings > Helix relay does to the stored
// bearer key. The key field never shows the saved secret, so an empty field
// means "keep"; removing is explicit, and clearing the URL clears the relay
// (key included) entirely.
package com.artjiang.helix.conversate

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
        fun resolve(url: String, typedKey: String, removeRequested: Boolean): RelayKeyEdit = when {
            removeRequested || url.isBlank() -> Remove
            typedKey.isBlank() -> Keep
            else -> Replace(typedKey.trim())
        }
    }
}
