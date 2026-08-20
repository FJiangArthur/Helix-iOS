// Root scaffold: 5-tab bottom navigation mirroring NativeHelixAppView.swift.
package com.artjiang.helix.ui

import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.GraphicEq
import androidx.compose.material.icons.filled.History
import androidx.compose.material.icons.filled.MenuBook
import androidx.compose.material.icons.filled.RemoveRedEye
import androidx.compose.material.icons.filled.Tune
import androidx.compose.material3.CenterAlignedTopAppBar
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import com.artjiang.helix.HelixBridge

private enum class HelixTab(val title: String, val icon: ImageVector) {
    ASSISTANT("Assistant", Icons.Filled.GraphicEq),
    DEVICE("Device", Icons.Filled.RemoveRedEye),
    SESSIONS("Sessions", Icons.Filled.History),
    KNOWLEDGE("Knowledge", Icons.Filled.MenuBook),
    SETTINGS("Settings", Icons.Filled.Tune),
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun HelixApp(bridge: HelixBridge) {
    // Saved as an ordinal: rememberSaveable has no built-in saver for enums.
    var selectedIndex by rememberSaveable { mutableIntStateOf(0) }
    val selected = HelixTab.entries[selectedIndex]

    Scaffold(
        containerColor = HelixColors.Background,
        topBar = {
            CenterAlignedTopAppBar(
                title = { Text(selected.title) },
                colors = TopAppBarDefaults.centerAlignedTopAppBarColors(
                    containerColor = HelixColors.Surface,
                    titleContentColor = HelixColors.Ink,
                ),
            )
        },
        bottomBar = {
            NavigationBar(containerColor = HelixColors.Surface) {
                HelixTab.entries.forEachIndexed { index, tab ->
                    NavigationBarItem(
                        selected = selectedIndex == index,
                        onClick = { selectedIndex = index },
                        icon = { Icon(tab.icon, contentDescription = tab.title) },
                        label = { Text(tab.title) },
                    )
                }
            }
        },
    ) { innerPadding ->
        val contentModifier = Modifier.padding(innerPadding)
        when (selected) {
            HelixTab.ASSISTANT -> AssistantScreen(bridge, contentModifier)
            HelixTab.DEVICE -> DeviceScreen(bridge, contentModifier)
            HelixTab.SESSIONS -> SessionsScreen(bridge, contentModifier)
            HelixTab.KNOWLEDGE -> KnowledgeScreen(bridge, contentModifier)
            HelixTab.SETTINGS -> SettingsScreen(bridge, contentModifier)
        }
    }
}
