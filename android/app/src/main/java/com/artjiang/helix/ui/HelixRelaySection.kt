package com.artjiang.helix.ui

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.material3.Button
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.artjiang.helix.HelixBridge
import com.artjiang.helix.conversate.RelayKeyEdit

/**
 * Settings > Helix relay (contract 0.3 §7): the Mac-side relay that serves
 * dashboards, reminders and Ask. URL and key go to the encrypted key store.
 */
@Composable
fun HelixRelaySection(bridge: HelixBridge) {
    val keyRevision by bridge.settingsRepository.keyRevision.collectAsStateWithLifecycle()
    val status by bridge.relayStatus.collectAsStateWithLifecycle()
    val storedUrl = remember(keyRevision) { bridge.relayUrl() }
    val hasKey = remember(keyRevision) { bridge.hasRelayKey() }
    var url by remember(storedUrl) { mutableStateOf(storedUrl) }
    var key by remember { mutableStateOf("") }
    val trimmed = url.trim()
    val looksValid = trimmed.isEmpty() || trimmed.startsWith("https://") || trimmed.startsWith("http://")

    HelixSection(title = "Helix relay", subtitle = "Dashboards, reminders and Ask ChatGPT from your Mac") {
        OutlinedTextField(
            value = url,
            onValueChange = { url = it },
            label = { Text("Relay URL") },
            placeholder = { Text("https://<mac>.<tailnet>.ts.net") },
            singleLine = true,
            isError = !looksValid,
            modifier = Modifier.fillMaxWidth(),
        )
        OutlinedTextField(
            value = key,
            onValueChange = { key = it },
            label = { Text(if (hasKey) "Replace relay key (saved)" else "Relay key") },
            singleLine = true,
            visualTransformation = PasswordVisualTransformation(),
            modifier = Modifier.fillMaxWidth(),
        )
        Row(horizontalArrangement = Arrangement.spacedBy(HelixSpacing.s8)) {
            Button(
                onClick = {
                    bridge.setRelay(trimmed, RelayKeyEdit.resolve(trimmed, key, removeRequested = false))
                    key = ""
                },
                enabled = looksValid,
            ) { Text("Save") }
            if (hasKey) {
                OutlinedButton(onClick = {
                    bridge.setRelay(storedUrl, RelayKeyEdit.Remove)
                    key = ""
                }) { Text("Remove key") }
            }
            OutlinedButton(onClick = bridge::testRelay, enabled = storedUrl.isNotBlank()) { Text("Test connection") }
        }
        if (status.isNotEmpty()) Text(status, style = MaterialTheme.typography.bodySmall)
        Text(
            "Needs Tailscale on this phone and the relay running on your Mac (relay/helix-relay).",
            style = MaterialTheme.typography.bodySmall,
        )
    }
}
