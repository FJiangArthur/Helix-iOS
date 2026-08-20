// Application-scope owner of the HelixBridge.
//
// The bridge holds the BLE link, the glasses heartbeat, and the recognizer
// session — all of which must survive an Activity recreation (rotation, theme
// change), so it lives here rather than in a ViewModel.
package com.artjiang.helix

import android.app.Application

class HelixApplication : Application() {

    /** Created lazily on first UI access, then reused for the process lifetime. */
    val bridge: HelixBridge by lazy { HelixBridge(this) }
}
