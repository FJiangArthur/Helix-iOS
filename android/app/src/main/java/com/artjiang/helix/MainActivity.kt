// Single-activity Compose entry point. Port of NativeHelixAppView.swift's host.
package com.artjiang.helix

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.activity.result.contract.ActivityResultContracts
import androidx.core.content.ContextCompat
import androidx.lifecycle.lifecycleScope
import com.artjiang.helix.service.RecordingService
import com.artjiang.helix.ui.HelixApp
import com.artjiang.helix.ui.HelixTheme
import kotlinx.coroutines.launch

class MainActivity : ComponentActivity() {

    /**
     * POST_NOTIFICATIONS (Android 13+). The result is deliberately ignored:
     * denial hides the recording indicator but must never block recording, so
     * there is nothing to do on either outcome.
     */
    private val notificationPermission =
        registerForActivityResult(ActivityResultContracts.RequestPermission()) { }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Draw behind the system bars; bar icon tint follows the system theme.
        enableEdgeToEdge()
        // The bridge is application-scoped, so BLE + listening state survive
        // Activity recreation.
        val bridge = (application as HelixApplication).bridge
        requestNotificationPermissionIfNeeded()
        bindRecordingIndicator(bridge)
        setContent {
            HelixTheme {
                HelixApp(bridge)
            }
        }
    }

    /**
     * Mirrors the session lifecycle onto [RecordingService].
     *
     * Driven by `isListening` rather than by the start/stop calls themselves so
     * every route into a session is covered — the app's own control, the
     * glasses' triple tap, and a recognizer that stops itself on error — without
     * HelixBridge needing to know a service exists.
     *
     * `lifecycleScope` (not the bridge's scope) keeps the collector tied to the
     * Activity; the service, once started, outlives it on its own.
     */
    private fun bindRecordingIndicator(bridge: HelixBridge) {
        lifecycleScope.launch {
            // StateFlow already conflates equal values, so no distinctUntilChanged.
            bridge.isListening.collect { listening ->
                if (listening) {
                    RecordingService.start(this@MainActivity)
                } else {
                    RecordingService.stop(this@MainActivity)
                }
            }
        }
    }

    private fun requestNotificationPermissionIfNeeded() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return
        val granted = ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.POST_NOTIFICATIONS,
        ) == PackageManager.PERMISSION_GRANTED
        if (!granted) notificationPermission.launch(Manifest.permission.POST_NOTIFICATIONS)
    }
}
