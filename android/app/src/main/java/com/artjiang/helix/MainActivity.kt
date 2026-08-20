// Single-activity Compose entry point. Port of NativeHelixAppView.swift's host.
package com.artjiang.helix

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import com.artjiang.helix.ui.HelixApp
import com.artjiang.helix.ui.HelixTheme

class MainActivity : ComponentActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // The bridge is application-scoped, so BLE + listening state survive
        // Activity recreation.
        val bridge = (application as HelixApplication).bridge
        setContent {
            HelixTheme {
                HelixApp(bridge)
            }
        }
    }
}
