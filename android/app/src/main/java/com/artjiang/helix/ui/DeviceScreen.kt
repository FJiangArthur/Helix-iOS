// Port of ios/Runner/NativeDeviceView.swift.
package com.artjiang.helix.ui

import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.BatteryFull
import androidx.compose.material.icons.filled.Bluetooth
import androidx.compose.material.icons.filled.ChevronLeft
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Remove
import androidx.compose.material.icons.filled.RemoveRedEye
import androidx.compose.material.icons.filled.TouchApp
import androidx.compose.material3.Button
import androidx.compose.material3.FilledTonalIconButton
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Slider
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.artjiang.helix.HelixBridge
import com.artjiang.helix.ble.LensConnectionState

@Composable
fun DeviceScreen(bridge: HelixBridge, modifier: Modifier = Modifier) {
    val isScanning by bridge.isScanning.collectAsStateWithLifecycle()
    val pairs by bridge.discoveredPairs.collectAsStateWithLifecycle()
    val phase by bridge.connectionPhase.collectAsStateWithLifecycle()
    val bleError by bridge.bluetoothError.collectAsStateWithLifecycle()
    val left by bridge.leftLens.collectAsStateWithLifecycle()
    val right by bridge.rightLens.collectAsStateWithLifecycle()
    val battery by bridge.batteryPercent.collectAsStateWithLifecycle()
    val charging by bridge.isCharging.collectAsStateWithLifecycle()
    val hudPages by bridge.hudPages.collectAsStateWithLifecycle()
    val hudIndex by bridge.hudPageIndex.collectAsStateWithLifecycle()
    val touchpad by bridge.lastTouchpadSummary.collectAsStateWithLifecycle()
    val display by bridge.displayPrefs.collectAsStateWithLifecycle()

    val blePermissionLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestMultiplePermissions(),
    ) { grants -> if (grants.values.all { it }) bridge.startScan() }

    val isConnected = left == LensConnectionState.READY || right == LensConnectionState.READY

    Column(
        modifier = modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        HelixSection(title = "Discovery", subtitle = phase) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                StatusPill(
                    text = if (isScanning) "Scanning" else "Idle",
                    tint = if (isScanning) HelixColors.Green else HelixColors.SecondaryInk,
                )
                Spacer(Modifier.weight(1f))
                if (isConnected) {
                    OutlinedButton(onClick = bridge::disconnectGlasses) { Text("Disconnect") }
                } else {
                    Button(
                        onClick = {
                            if (isScanning) {
                                bridge.stopScan()
                            } else if (bridge.bluetooth.hasPermissions()) {
                                bridge.startScan()
                            } else {
                                blePermissionLauncher.launch(bridge.bluetooth.requiredPermissions())
                            }
                        },
                    ) {
                        Icon(Icons.Filled.Bluetooth, contentDescription = null, modifier = Modifier.size(18.dp))
                        Spacer(Modifier.size(6.dp))
                        Text(if (isScanning) "Stop scan" else "Scan for glasses")
                    }
                }
            }

            if (bleError.isNotBlank()) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text(
                        text = bleError,
                        style = MaterialTheme.typography.bodySmall,
                        color = HelixColors.Amber,
                        modifier = Modifier.weight(1f),
                    )
                    IconButton(onClick = bridge::clearBluetoothError) {
                        Icon(Icons.Filled.Close, contentDescription = "Dismiss", tint = HelixColors.Amber)
                    }
                }
            }

            if (pairs.isEmpty()) {
                Text(
                    text = if (isScanning) {
                        "Looking for Even G1 glasses nearby..."
                    } else {
                        "Tap Scan to discover Even G1 glasses. Both lenses must be out of the case."
                    },
                    style = MaterialTheme.typography.bodySmall,
                    color = HelixColors.SecondaryInk,
                )
            } else {
                pairs.forEach { pair ->
                    Row(
                        modifier = Modifier.fillMaxWidth().padding(vertical = 6.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Column(modifier = Modifier.weight(1f)) {
                            Text(
                                text = pair.displayName,
                                style = MaterialTheme.typography.bodyMedium,
                                fontWeight = FontWeight.SemiBold,
                                color = HelixColors.Ink,
                            )
                            Text(
                                text = pair.signalSummary,
                                style = MaterialTheme.typography.labelSmall,
                                color = HelixColors.SecondaryInk,
                            )
                        }
                        Button(onClick = { bridge.connect(pair) }, enabled = pair.isComplete) {
                            Text("Connect")
                        }
                    }
                }
            }
        }

        HelixSection(title = "Glasses display", subtitle = "Applied live when connected") {
            SliderRow(
                title = "Head-up angle",
                value = display.headUpAngle,
                range = 0..60,
                suffix = "deg",
            ) { newValue -> bridge.updateDisplayPrefs { it.copy(headUpAngle = newValue) } }

            StepperRow("Display height", display.displayHeight, 0..8) { newValue ->
                bridge.updateDisplayPrefs { it.copy(displayHeight = newValue) }
            }

            StepperRow("Display depth", display.displayDepth, 0..9) { newValue ->
                bridge.updateDisplayPrefs { it.copy(displayDepth = newValue) }
            }

            SliderRow(
                title = "Brightness",
                value = display.brightness,
                range = 0..63,
                enabled = !display.autoBrightness,
            ) { newValue -> bridge.updateDisplayPrefs { it.copy(brightness = newValue) } }

            ToggleRow("Auto brightness", display.autoBrightness) { newValue ->
                bridge.updateDisplayPrefs { it.copy(autoBrightness = newValue) }
            }
        }

        HelixSection(title = "G1 device", subtitle = connectionSummary(left, right)) {
            MetricRow(
                title = "Left",
                value = lensLabel(left),
                icon = Icons.Filled.RemoveRedEye,
                tint = if (left == LensConnectionState.READY) HelixColors.Green else HelixColors.SecondaryInk,
            )
            HairlineDivider(indent = 30)
            MetricRow(
                title = "Right",
                value = lensLabel(right),
                icon = Icons.Filled.RemoveRedEye,
                tint = if (right == LensConnectionState.READY) HelixColors.Green else HelixColors.SecondaryInk,
            )
            HairlineDivider(indent = 30)
            MetricRow(
                title = "Battery",
                value = battery?.let { "$it%${if (charging) " charging" else ""}" } ?: "Unknown",
                icon = Icons.Filled.BatteryFull,
                tint = HelixColors.Green,
            )

            HairlineDivider()

            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                StatusPill(
                    text = if (hudPages.isEmpty()) "No HUD page" else "Page ${hudIndex + 1} of ${hudPages.size}",
                    tint = HelixColors.Indigo,
                )
                Spacer(Modifier.weight(1f))
                // These actually push the page over BLE (bridge.showPage ->
                // transport.sendScreen); the iOS buttons only moved local state.
                FilledTonalIconButton(
                    onClick = bridge::showPreviousPage,
                    enabled = hudPages.isNotEmpty() && hudIndex > 0,
                ) {
                    Icon(Icons.Filled.ChevronLeft, contentDescription = "Previous HUD page")
                }
                FilledTonalIconButton(
                    onClick = { bridge.showPage(hudIndex) },
                    enabled = hudPages.isNotEmpty() && isConnected,
                ) {
                    Icon(Icons.Filled.RemoveRedEye, contentDescription = "Push page to glasses")
                }
                FilledTonalIconButton(
                    onClick = bridge::showNextPage,
                    enabled = hudPages.isNotEmpty() && hudIndex < hudPages.size - 1,
                ) {
                    Icon(Icons.Filled.ChevronRight, contentDescription = "Next HUD page")
                }
            }

            HairlineDivider()

            Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                Icon(
                    Icons.Filled.TouchApp,
                    contentDescription = null,
                    tint = HelixColors.Teal,
                    modifier = Modifier.size(20.dp),
                )
                Column {
                    Text(
                        text = "Touchpad",
                        style = MaterialTheme.typography.bodyMedium,
                        fontWeight = FontWeight.SemiBold,
                        color = HelixColors.Ink,
                    )
                    Text(
                        text = touchpad,
                        style = MaterialTheme.typography.bodySmall,
                        color = HelixColors.SecondaryInk,
                    )
                }
            }

            hudPages.getOrNull(hudIndex)?.let { page ->
                Text(
                    text = page.text,
                    style = MaterialTheme.typography.bodySmall,
                    color = HelixColors.SecondaryInk,
                )
            }
        }
    }
}

@Composable
private fun SliderRow(
    title: String,
    value: Int,
    range: IntRange,
    suffix: String = "",
    enabled: Boolean = true,
    onCommit: (Int) -> Unit,
) {
    Column(modifier = Modifier.fillMaxWidth()) {
        Row(modifier = Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
            Text(
                text = title,
                style = MaterialTheme.typography.labelMedium,
                fontWeight = FontWeight.SemiBold,
                color = HelixColors.SecondaryInk,
            )
            Spacer(Modifier.weight(1f))
            Text(
                text = "$value$suffix",
                style = MaterialTheme.typography.labelMedium,
                fontWeight = FontWeight.Bold,
                color = HelixColors.Ink,
            )
        }
        Slider(
            value = value.toFloat(),
            onValueChange = { onCommit(it.toInt()) },
            valueRange = range.first.toFloat()..range.last.toFloat(),
            steps = (range.last - range.first - 1).coerceAtLeast(0),
            enabled = enabled,
        )
    }
}

@Composable
private fun StepperRow(title: String, value: Int, range: IntRange, onCommit: (Int) -> Unit) {
    Row(
        modifier = Modifier.fillMaxWidth().padding(vertical = 4.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            text = title,
            style = MaterialTheme.typography.bodyMedium,
            fontWeight = FontWeight.SemiBold,
            color = HelixColors.Ink,
        )
        Spacer(Modifier.weight(1f))
        IconButton(onClick = { onCommit((value - 1).coerceIn(range.first, range.last)) }, enabled = value > range.first) {
            Icon(Icons.Filled.Remove, contentDescription = "Decrease $title")
        }
        Text(text = "$value", style = MaterialTheme.typography.bodyMedium, color = HelixColors.Ink)
        IconButton(onClick = { onCommit((value + 1).coerceIn(range.first, range.last)) }, enabled = value < range.last) {
            Icon(Icons.Filled.Add, contentDescription = "Increase $title")
        }
    }
}

@Composable
private fun ToggleRow(title: String, isOn: Boolean, onChange: (Boolean) -> Unit) {
    Row(
        modifier = Modifier.fillMaxWidth().padding(vertical = 4.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            text = title,
            style = MaterialTheme.typography.bodyMedium,
            fontWeight = FontWeight.SemiBold,
            color = HelixColors.Ink,
        )
        Spacer(Modifier.weight(1f))
        Switch(checked = isOn, onCheckedChange = onChange)
    }
}

private fun lensLabel(state: LensConnectionState): String = when (state) {
    LensConnectionState.READY -> "Connected"
    LensConnectionState.CONNECTED -> "Discovering"
    LensConnectionState.CONNECTING -> "Connecting"
    LensConnectionState.DISCONNECTED -> "Waiting"
}

private fun connectionSummary(left: LensConnectionState, right: LensConnectionState): String = when {
    left == LensConnectionState.READY && right == LensConnectionState.READY -> "Both lenses connected"
    left == LensConnectionState.READY -> "Left lens only"
    right == LensConnectionState.READY -> "Right lens only"
    else -> "Not connected"
}
