// Device tab: hero card with scan/connect and the two lens battery rings, then
// display tuning and the HUD controls. Port of ios/Runner/NativeDeviceView.swift.
package com.artjiang.helix.ui

import android.content.Context
import android.content.Intent
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Add
import androidx.compose.material.icons.outlined.Bluetooth
import androidx.compose.material.icons.outlined.ChevronLeft
import androidx.compose.material.icons.outlined.ChevronRight
import androidx.compose.material.icons.outlined.Notifications
import androidx.compose.material.icons.outlined.Remove
import androidx.compose.material.icons.outlined.Tune
import androidx.compose.material.icons.outlined.Visibility
import androidx.compose.material.icons.outlined.TouchApp
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Checkbox
import androidx.compose.material3.CheckboxDefaults
import androidx.compose.material3.FilledTonalIconButton
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.IconButtonDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.unit.dp
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.compose.LocalLifecycleOwner
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.artjiang.helix.HelixBridge
import com.artjiang.helix.data.SettingsRepository
import com.artjiang.helix.R
import com.artjiang.helix.ble.LensConnectionState
import com.artjiang.helix.notify.HelixNotificationListener
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

@Composable
fun DeviceScreen(bridge: HelixBridge, modifier: Modifier = Modifier) {
    val tokens = HelixTheme.tokens
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
    val screenOutcome = bridge.lastScreenOutcome
    val hudScroll by bridge.hudScrollSeconds.collectAsStateWithLifecycle()
    val probeResult by bridge.displayProbeResult.collectAsStateWithLifecycle()
    val display by bridge.displayPrefs.collectAsStateWithLifecycle()
    val glassesNotifications by bridge.glassesNotificationsEnabled.collectAsStateWithLifecycle()
    val glassesDashboard by bridge.glassesDashboardEnabled.collectAsStateWithLifecycle()
    val sessionTapToggle by bridge.sessionTapToggleEnabled.collectAsStateWithLifecycle()
    val hudDwell by bridge.hudDwellSeconds.collectAsStateWithLifecycle()

    val blePermissionLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestMultiplePermissions(),
    ) { grants -> if (grants.values.all { it }) bridge.startScan() }

    val isConnected = left == LensConnectionState.READY || right == LensConnectionState.READY

    Column(
        modifier = modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(horizontal = HelixSpacing.screen)
            .padding(top = HelixSpacing.s4, bottom = HelixSpacing.s24),
        verticalArrangement = Arrangement.spacedBy(HelixSpacing.cardGap),
    ) {
        // Hero: connection state + the two lens rings.
        LinenCard(tint = if (isConnected) CardTint.Support else CardTint.Neutral) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(HelixSpacing.s12),
            ) {
                Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                    Text(
                        text = "Even G1",
                        style = MaterialTheme.typography.headlineMedium,
                        color = tokens.ink,
                    )
                    Text(
                        text = connectionSummary(left, right),
                        style = MaterialTheme.typography.bodySmall,
                        color = tokens.inkSecondary,
                    )
                }
                StatusPill(
                    text = when {
                        isScanning -> "Scanning"
                        isConnected -> "Connected"
                        else -> "Idle"
                    },
                    tint = when {
                        isScanning -> tokens.warning
                        isConnected -> tokens.success
                        else -> tokens.inkMuted
                    },
                    pulsing = isScanning,
                )
            }

            if (!isConnected && !isScanning) {
                // Disconnected: the glasses at rest, not two empty gauges.
                EmptyState(
                    title = "Glasses not connected",
                    detail = "Take both lenses out of the case, then scan.",
                    icon = Icons.Outlined.Visibility,
                    illustration = painterResource(R.drawable.helix_empty_device),
                )
            } else Row(
                modifier = Modifier.fillMaxWidth().padding(vertical = HelixSpacing.s8),
                horizontalArrangement = Arrangement.SpaceEvenly,
            ) {
                // One battery reading from the glasses is shown on both lenses;
                // a lens that is not READY is muted.
                BatteryRing(
                    percent = if (isConnected) battery else null,
                    charging = charging,
                    label = "Left · ${lensLabel(left)}",
                    muted = left != LensConnectionState.READY,
                )
                BatteryRing(
                    percent = if (isConnected) battery else null,
                    charging = charging,
                    label = "Right · ${lensLabel(right)}",
                    muted = right != LensConnectionState.READY,
                )
            }

            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(HelixSpacing.s8),
            ) {
                // The BLE phase string usually repeats the lens summary
                // ("Not connected"); only show it when it adds something.
                Text(
                    text = if (phase.equals(connectionSummary(left, right), ignoreCase = true)) "" else phase,
                    style = MaterialTheme.typography.labelMedium,
                    color = tokens.inkMuted,
                    modifier = Modifier.weight(1f),
                )
                if (isConnected) {
                    OutlinedButton(
                        onClick = bridge::disconnectGlasses,
                        colors = ButtonDefaults.outlinedButtonColors(contentColor = tokens.accentDeep),
                    ) { Text("Disconnect") }
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
                        Icon(Icons.Outlined.Bluetooth, contentDescription = null, modifier = Modifier.size(18.dp))
                        Spacer(Modifier.size(6.dp))
                        Text(if (isScanning) "Stop scan" else "Scan for glasses")
                    }
                }
            }

            if (bleError.isNotBlank()) {
                DismissibleError(text = bleError, onDismiss = bridge::clearBluetoothError)
            }

            if (pairs.isEmpty()) {
                Text(
                    text = if (isScanning) {
                        "Looking for Even G1 glasses nearby..."
                    } else {
                        "Tap Scan to discover Even G1 glasses. Both lenses must be out of the case."
                    },
                    style = MaterialTheme.typography.bodySmall,
                    color = tokens.inkSecondary,
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
                                style = MaterialTheme.typography.titleSmall,
                                color = tokens.ink,
                            )
                            Text(
                                text = pair.signalSummary,
                                style = MaterialTheme.typography.labelSmall,
                                color = tokens.inkSecondary,
                            )
                        }
                        Button(onClick = { bridge.connect(pair) }, enabled = pair.isComplete) {
                            Text("Connect")
                        }
                    }
                }
            }
        }

        HelixSection(
            title = "Glasses display",
            subtitle = "Applied live when connected",
            icon = Icons.Outlined.Tune,
            tint = tokens.support,
        ) {
            SliderRow(
                title = "Head-up angle",
                value = display.headUpAngle,
                range = 0..60,
                suffix = "\u00b0",
            ) { newValue -> bridge.updateDisplayPrefs { it.copy(headUpAngle = newValue) } }

            // 0x26 is a TWO-PHASE command (SLA-L3b): preview, then commit a few
            // seconds later. So these steppers only change the stored value —
            // applying is a deliberate action via the button below. Pushing on
            // every drag would restart the preview on each tick and leave it
            // stuck on the lens, which is the bug this replaced.
            StepperRow("Display height", display.displayHeight, 0..8) { newValue ->
                bridge.updateDisplayPrefs { it.copy(displayHeight = newValue) }
            }

            StepperRow("Display depth", display.displayDepth, 1..9) { newValue ->
                bridge.updateDisplayPrefs { it.copy(displayDepth = newValue) }
            }

            OutlinedButton(onClick = { bridge.applyDisplayPosition() }) {
                Text("Apply position to glasses")
            }
            Text(
                text = "Shows a preview on the lens, then commits it after a few seconds.",
                style = MaterialTheme.typography.bodySmall,
                color = tokens.inkSecondary,
            )

            SliderRow(
                title = "Brightness",
                value = display.brightness,
                range = 0..63,
                enabled = !display.autoBrightness,
            ) { newValue -> bridge.updateDisplayPrefs { it.copy(brightness = newValue) } }

            ToggleRow("Auto brightness", display.autoBrightness) { newValue ->
                bridge.updateDisplayPrefs { it.copy(autoBrightness = newValue) }
            }

            HairlineDivider()

            // iOS NativeDeviceView parity: the head-up dashboard toggle. The
            // notification toggle moved into its own section below.
            ToggleRow(
                title = "Head-up dashboard",
                checked = glassesDashboard,
                detail = "Firmware dashboard when you look up; off also stops its clock resync.",
            ) { newValue -> bridge.setGlassesDashboardEnabled(newValue) }

            HairlineDivider()

            // Triple tap the right pad to start/stop a transcription session.
            // Off by default: enabling it puts a ~400 ms multi-tap window in
            // front of single taps on that pad, which the wearer should opt
            // into rather than discover.
            ToggleRow(
                title = "Triple-tap to record",
                checked = sessionTapToggle,
                detail = "Triple tap the right arm to start or stop transcription. " +
                    "Adds a short delay to single taps on that pad.",
            ) { newValue -> bridge.setSessionTapToggleEnabled(newValue) }

            HairlineDivider()

            // Page/line cadence while an answer is on the lens.
            SliderRow(
                title = "Scroll speed",
                value = hudScroll,
                range = SettingsRepository.MIN_HUD_SCROLL_SECONDS..SettingsRepository.MAX_HUD_SCROLL_SECONDS,
                suffix = "s per line",
            ) { seconds -> bridge.setHudScrollSeconds(seconds) }

            HairlineDivider()

            // How long a finished answer dwells before Helix sends the 0x41
            // that lets the firmware blank the lens.
            SliderRow(
                title = "Answer stays on screen",
                value = hudDwell,
                range = SettingsRepository.MIN_HUD_DWELL_SECONDS..SettingsRepository.MAX_HUD_DWELL_SECONDS,
                suffix = "s",
            ) { seconds -> bridge.setHudDwellSeconds(seconds) }
        }

        NotificationsSection(bridge = bridge, glassesNotifications = glassesNotifications)

        HelixSection(
            title = "HUD",
            subtitle = "Text pages pushed to the glasses",
            icon = Icons.Outlined.Visibility,
            tint = tokens.gold,
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                StatusPill(
                    text = if (hudPages.isEmpty()) "No HUD page" else "Page ${hudIndex + 1} of ${hudPages.size}",
                    tint = tokens.support,
                )
                Spacer(Modifier.weight(1f))
                val tonal = IconButtonDefaults.filledTonalIconButtonColors(
                    containerColor = tokens.accentTint,
                    contentColor = MaterialTheme.colorScheme.onPrimaryContainer,
                    disabledContainerColor = tokens.surfaceSunk,
                    disabledContentColor = tokens.inkMuted,
                )
                // These actually push the page over BLE (bridge.showPage ->
                // transport.sendScreen); the iOS buttons only moved local state.
                FilledTonalIconButton(
                    onClick = bridge::showPreviousPage,
                    enabled = hudPages.isNotEmpty() && hudIndex > 0,
                    colors = tonal,
                ) {
                    Icon(Icons.Outlined.ChevronLeft, contentDescription = "Previous HUD page")
                }
                FilledTonalIconButton(
                    onClick = { bridge.showPage(hudIndex) },
                    enabled = hudPages.isNotEmpty() && isConnected,
                    colors = tonal,
                ) {
                    Icon(Icons.Outlined.Visibility, contentDescription = "Push page to glasses")
                }
                FilledTonalIconButton(
                    onClick = bridge::showNextPage,
                    enabled = hudPages.isNotEmpty() && hudIndex < hudPages.size - 1,
                    colors = tonal,
                ) {
                    Icon(Icons.Outlined.ChevronRight, contentDescription = "Next HUD page")
                }
            }

            hudPages.getOrNull(hudIndex)?.let { page ->
                Text(
                    text = page.text,
                    style = HelixTextStyles.mono,
                    color = tokens.inkSecondary,
                )
            }

            HairlineDivider()

            Row(
                horizontalArrangement = Arrangement.spacedBy(HelixSpacing.s12),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                IconBadge(icon = Icons.Outlined.TouchApp, tint = tokens.accent, size = 32.dp)
                Column {
                    Text(
                        text = "Touchpad",
                        style = MaterialTheme.typography.titleSmall,
                        color = tokens.ink,
                    )
                    Text(
                        text = touchpad,
                        style = MaterialTheme.typography.bodySmall,
                        color = tokens.inkSecondary,
                    )
                    // Per-lens result of the last screen write. A screen that
                    // reaches one lens but not the other still reports success
                    // (single-lens links are supported), so without this a
                    // persistently failing lens is invisible from the app.
                    // 0x26 turned out to be DASHBOARD_VISIBILITY, not HUD
                    // position (SLA-L3b, observed on hardware). Older builds
                    // sent it on every connect, which can leave the dashboard
                    // stuck on the lens; 0x18 is the documented way to clear it.
                    Text(
                        text = probeResult.ifBlank { "Dashboard stuck on the lens? Clear it below." },
                        style = MaterialTheme.typography.bodySmall,
                        color = tokens.inkSecondary,
                    )
                    OutlinedButton(onClick = { bridge.clearGlassesDashboard() }) {
                        Text("Clear dashboard from lenses")
                    }
                    Text(
                        text = "Last screen: $screenOutcome",
                        style = MaterialTheme.typography.bodySmall,
                        color = tokens.inkSecondary,
                    )
                }
            }
        }
    }
}

/**
 * "Notifications on glasses" — the master toggle (A: Helix's own events), the
 * optional mirroring of other apps (B), and the per-app whitelist.
 *
 * Mirroring needs Android's notification-listener access, which only the user
 * can grant in system settings; until then the switch deep-links there instead
 * of pretending to turn something on. The granted state is re-read every time
 * the screen resumes, so returning from that settings screen updates the row.
 */
@Composable
private fun NotificationsSection(bridge: HelixBridge, glassesNotifications: Boolean) {
    val tokens = HelixTheme.tokens
    val context = LocalContext.current
    val mirrorEnabled by bridge.notificationMirrorEnabled.collectAsStateWithLifecycle()
    val whitelist by bridge.notificationWhitelist.collectAsStateWithLifecycle()

    var accessGranted by remember { mutableStateOf(HelixNotificationListener.isAccessGranted(context)) }
    var pickerExpanded by remember { mutableStateOf(false) }
    var apps by remember { mutableStateOf<List<LaunchableApp>>(emptyList()) }

    // Re-check on every resume: the user grants access in a system screen, and
    // there is no callback back into the app when they do.
    val lifecycleOwner = LocalLifecycleOwner.current
    DisposableEffect(lifecycleOwner) {
        val observer = LifecycleEventObserver { _, event ->
            if (event == Lifecycle.Event.ON_RESUME) {
                accessGranted = HelixNotificationListener.isAccessGranted(context)
            }
        }
        lifecycleOwner.lifecycle.addObserver(observer)
        onDispose { lifecycleOwner.lifecycle.removeObserver(observer) }
    }

    // Querying the package manager touches disk; keep it off the frame thread
    // and only do it when the list is actually shown.
    LaunchedEffect(pickerExpanded) {
        if (pickerExpanded && apps.isEmpty()) {
            val loaded = withContext(Dispatchers.IO) { loadLaunchableApps(context) }
            apps = loaded
            bridge.recordNotificationAppLabels(loaded.associate { it.packageName to it.label })
        }
    }

    HelixSection(
        title = "Notifications on glasses",
        subtitle = "What Helix puts on the HUD",
        icon = Icons.Outlined.Notifications,
        tint = tokens.accent,
    ) {
        ToggleRow(
            title = "Notifications on glasses",
            checked = glassesNotifications,
            detail = "Helix answers and fact checks appear on the HUD.",
        ) { newValue -> bridge.setGlassesNotificationsEnabled(newValue) }

        HairlineDivider()

        ToggleRow(
            title = "Mirror other apps",
            checked = mirrorEnabled && accessGranted,
            detail = if (accessGranted) {
                "Notifications from the apps you pick below."
            } else {
                "Needs notification access — tap to open system settings."
            },
        ) { newValue ->
            if (!accessGranted) {
                context.startActivity(HelixNotificationListener.accessSettingsIntent())
            } else {
                bridge.setNotificationMirrorEnabled(newValue)
            }
        }

        Row(
            modifier = Modifier.fillMaxWidth().padding(vertical = 4.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(HelixSpacing.s8),
        ) {
            StatusPill(
                text = if (accessGranted) "Access granted" else "Access not granted",
                tint = if (accessGranted) tokens.success else tokens.inkMuted,
            )
            Spacer(Modifier.weight(1f))
            if (!accessGranted) {
                OutlinedButton(
                    onClick = { context.startActivity(HelixNotificationListener.accessSettingsIntent()) },
                ) { Text("Grant access") }
            }
        }

        if (accessGranted && mirrorEnabled) {
            HairlineDivider()
            Row(
                modifier = Modifier.fillMaxWidth().padding(vertical = 4.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                    Text(
                        text = "Mirrored apps",
                        style = MaterialTheme.typography.titleSmall,
                        color = tokens.ink,
                    )
                    Text(
                        text = if (whitelist.isEmpty()) {
                            "No apps picked yet"
                        } else {
                            "${whitelist.size} app${if (whitelist.size == 1) "" else "s"} mirrored"
                        },
                        style = MaterialTheme.typography.bodySmall,
                        color = tokens.inkSecondary,
                    )
                }
                OutlinedButton(onClick = { pickerExpanded = !pickerExpanded }) {
                    Text(if (pickerExpanded) "Done" else "Choose apps")
                }
            }

            if (pickerExpanded) {
                if (apps.isEmpty()) {
                    Text(
                        text = "Loading installed apps…",
                        style = MaterialTheme.typography.bodySmall,
                        color = tokens.inkSecondary,
                    )
                } else {
                    // Bounded height: the list can run to hundreds of apps and
                    // must not stretch the enclosing scrolling column.
                    Column(
                        modifier = Modifier
                            .fillMaxWidth()
                            .heightIn(max = 320.dp)
                            .verticalScroll(rememberScrollState()),
                    ) {
                        apps.forEach { app ->
                            AppWhitelistRow(
                                label = app.label,
                                packageName = app.packageName,
                                checked = app.packageName in whitelist,
                                onCheckedChange = { checked ->
                                    bridge.setNotificationWhitelisted(app.packageName, checked)
                                },
                            )
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun AppWhitelistRow(
    label: String,
    packageName: String,
    checked: Boolean,
    onCheckedChange: (Boolean) -> Unit,
) {
    val tokens = HelixTheme.tokens
    Row(
        modifier = Modifier.fillMaxWidth().padding(vertical = 4.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(text = label, style = MaterialTheme.typography.bodyMedium, color = tokens.ink)
            Text(
                text = packageName,
                style = MaterialTheme.typography.bodySmall,
                color = tokens.inkMuted,
            )
        }
        Checkbox(
            checked = checked,
            onCheckedChange = onCheckedChange,
            colors = CheckboxDefaults.colors(
                checkedColor = tokens.success,
                uncheckedColor = tokens.borderStrong,
            ),
        )
    }
}

/** One installed app that has a launcher entry. */
private data class LaunchableApp(val packageName: String, val label: String)

/**
 * Installed apps with a LAUNCHER activity, alphabetical by label, excluding
 * Helix itself (which never mirrors its own notifications).
 */
private fun loadLaunchableApps(context: Context): List<LaunchableApp> {
    val pm = context.packageManager
    val intent = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
    return runCatching {
        pm.queryIntentActivities(intent, 0)
            .mapNotNull { resolved ->
                val pkg = resolved.activityInfo?.packageName ?: return@mapNotNull null
                if (pkg == context.packageName) return@mapNotNull null
                LaunchableApp(packageName = pkg, label = resolved.loadLabel(pm).toString())
            }
            .distinctBy { it.packageName }
            .sortedBy { it.label.lowercase() }
    }.getOrDefault(emptyList())
}

@Composable
private fun StepperRow(title: String, value: Int, range: IntRange, onCommit: (Int) -> Unit) {
    val tokens = HelixTheme.tokens
    Row(
        modifier = Modifier.fillMaxWidth().padding(vertical = 4.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            text = title,
            style = MaterialTheme.typography.titleSmall,
            color = tokens.ink,
        )
        Spacer(Modifier.weight(1f))
        IconButton(
            onClick = { onCommit((value - 1).coerceIn(range.first, range.last)) },
            enabled = value > range.first,
            colors = IconButtonDefaults.iconButtonColors(contentColor = tokens.accentDeep),
        ) {
            Icon(Icons.Outlined.Remove, contentDescription = "Decrease $title")
        }
        Text(
            text = "$value",
            style = MaterialTheme.typography.titleSmall,
            color = tokens.ink,
        )
        IconButton(
            onClick = { onCommit((value + 1).coerceIn(range.first, range.last)) },
            enabled = value < range.last,
            colors = IconButtonDefaults.iconButtonColors(contentColor = tokens.accentDeep),
        ) {
            Icon(Icons.Outlined.Add, contentDescription = "Increase $title")
        }
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
