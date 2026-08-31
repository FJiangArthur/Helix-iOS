// Root scaffold: 5-tab bottom navigation mirroring NativeHelixAppView.swift,
// with a collapsing Fraunces title bar and a fade+slide between tabs.
package com.artjiang.helix.ui

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInHorizontally
import androidx.compose.animation.slideOutHorizontally
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.consumeWindowInsets
import androidx.compose.foundation.layout.exclude
import androidx.compose.foundation.layout.ime
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AutoStories
import androidx.compose.material.icons.filled.History
import androidx.compose.material.icons.filled.Mic
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material.icons.filled.Visibility
import androidx.compose.material.icons.outlined.AutoStories
import androidx.compose.material.icons.outlined.History
import androidx.compose.material.icons.outlined.Mic
import androidx.compose.material.icons.outlined.Settings
import androidx.compose.material.icons.outlined.Visibility
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.LargeTopAppBar
import androidx.compose.material3.LocalTextStyle
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarDefaults
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.NavigationBarItemDefaults
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.material3.rememberTopAppBarState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.saveable.rememberSaveableStateHolder
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.input.nestedscroll.nestedScroll
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.artjiang.helix.HelixBridge

private enum class HelixTab(val title: String, val outlined: ImageVector, val filled: ImageVector) {
    ASSISTANT("Assistant", Icons.Outlined.Mic, Icons.Filled.Mic),
    DEVICE("Device", Icons.Outlined.Visibility, Icons.Filled.Visibility),
    SESSIONS("Sessions", Icons.Outlined.History, Icons.Filled.History),
    KNOWLEDGE("Knowledge", Icons.Outlined.AutoStories, Icons.Filled.AutoStories),
    SETTINGS("Settings", Icons.Outlined.Settings, Icons.Filled.Settings),
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun HelixApp(bridge: HelixBridge) {
    val tokens = HelixTheme.tokens
    // Saved as an ordinal: rememberSaveable has no built-in saver for enums.
    var selectedIndex by rememberSaveable { mutableIntStateOf(0) }
    val selected = HelixTab.entries[selectedIndex]
    val saveableStateHolder = rememberSaveableStateHolder()

    val scrollBehavior = TopAppBarDefaults.exitUntilCollapsedScrollBehavior(rememberTopAppBarState())
    // Each tab owns its own scroll position, so a collapsed title from the
    // previous tab must not carry over to a freshly composed short screen.
    LaunchedEffect(selectedIndex) {
        scrollBehavior.state.heightOffset = 0f
        scrollBehavior.state.contentOffset = 0f
    }

    // The Assistant tab draws its own compact header, so it gets an empty
    // topBar slot and no app-bar nested-scroll wiring. The other four tabs
    // keep the collapsing large bar.
    val showLargeBar = selected != HelixTab.ASSISTANT

    Scaffold(
        // The whole scaffold rises above the keyboard so the ask bar (and the
        // tab bar) stay reachable; the navigation bar then drops its own
        // system-bar inset while the IME covers it.
        modifier = Modifier
            .imePadding()
            .then(
                if (showLargeBar) {
                    Modifier.nestedScroll(scrollBehavior.nestedScrollConnection)
                } else {
                    Modifier
                },
            ),
        containerColor = tokens.bg,
        topBar = {
            // When this slot emits nothing, M3 1.3.1 ScaffoldLayout falls back
            // to contentWindowInsets.calculateTopPadding() for innerPadding.top
            // (verified: `topBarPlaceables.isEmpty()` branch in
            // ScaffoldKt$ScaffoldLayout), so Assistant content still starts
            // below the status bar — no manual inset Spacer needed.
            if (showLargeBar) {
                LargeTopAppBar(
                    title = {
                        // LargeTopAppBar styles the title per row (headlineMedium
                        // expanded, titleLarge collapsed); swap both for Fraunces.
                        val base = LocalTextStyle.current
                        val style = if (base.fontSize >= 24.sp) {
                            MaterialTheme.typography.displaySmall
                        } else {
                            MaterialTheme.typography.headlineSmall
                        }
                        Text(text = selected.title, style = style)
                    },
                    colors = TopAppBarDefaults.largeTopAppBarColors(
                        containerColor = tokens.bg,
                        scrolledContainerColor = tokens.bg,
                        titleContentColor = tokens.ink,
                    ),
                    scrollBehavior = scrollBehavior,
                )
            }
        },
        bottomBar = {
            val hairline = tokens.borderHairline
            NavigationBar(
                containerColor = MaterialTheme.colorScheme.surfaceContainerLowest,
                tonalElevation = 0.dp,
                windowInsets = NavigationBarDefaults.windowInsets.exclude(WindowInsets.ime),
                modifier = Modifier.drawBehind {
                    drawLine(
                        color = hairline,
                        start = Offset.Zero,
                        end = Offset(size.width, 0f),
                        strokeWidth = 1.dp.toPx(),
                    )
                },
            ) {
                val itemColors = NavigationBarItemDefaults.colors(
                    selectedIconColor = MaterialTheme.colorScheme.onPrimaryContainer,
                    selectedTextColor = tokens.ink,
                    indicatorColor = tokens.accentTint,
                    unselectedIconColor = tokens.inkSecondary,
                    unselectedTextColor = tokens.inkSecondary,
                )
                HelixTab.entries.forEachIndexed { index, tab ->
                    val isSelected = selectedIndex == index
                    NavigationBarItem(
                        selected = isSelected,
                        onClick = { selectedIndex = index },
                        icon = {
                            Icon(
                                imageVector = if (isSelected) tab.filled else tab.outlined,
                                contentDescription = tab.title,
                            )
                        },
                        label = {
                            // Single line at every font scale: five labels share
                            // the width, so wrapping ("Knowled/ge") is worse than
                            // a slightly smaller label.
                            Text(
                                text = tab.title,
                                style = MaterialTheme.typography.labelSmall.copy(letterSpacing = 0.sp),
                                maxLines = 1,
                                softWrap = false,
                                overflow = TextOverflow.Ellipsis,
                            )
                        },
                        colors = itemColors,
                    )
                }
            }
        },
    ) { innerPadding ->
        val contentModifier = Modifier
            .padding(innerPadding)
            .consumeWindowInsets(innerPadding)
        AnimatedContent(
            targetState = selected,
            transitionSpec = {
                val forward = targetState.ordinal > initialState.ordinal
                val direction = if (forward) 1 else -1
                (
                    fadeIn(tween(HelixMotion.medMillis, easing = HelixMotion.easeOutQuint)) +
                        slideInHorizontally(
                            tween(HelixMotion.medMillis, easing = HelixMotion.easeOutQuint),
                        ) { fullWidth -> direction * fullWidth / 12 }
                    ).togetherWith(
                    fadeOut(tween(HelixMotion.fastMillis)) +
                        slideOutHorizontally(tween(HelixMotion.fastMillis)) { fullWidth ->
                            -direction * fullWidth / 12
                        },
                )
            },
            label = "tab",
        ) { tab ->
            // Keyed per tab so rememberSaveable inside each screen survives
            // both tab switches and activity recreation (fold/unfold, rotate).
            // AnimatedContent composes outgoing and incoming tabs at once
            // during a transition, but their keys (tab names) always differ,
            // so there is no SaveableStateProvider key collision.
            saveableStateHolder.SaveableStateProvider(tab.name) {
                when (tab) {
                    HelixTab.ASSISTANT -> AssistantScreen(bridge, contentModifier)
                    HelixTab.DEVICE -> DeviceScreen(bridge, contentModifier)
                    HelixTab.SESSIONS -> SessionsScreen(bridge, contentModifier)
                    HelixTab.KNOWLEDGE -> KnowledgeScreen(bridge, contentModifier)
                    HelixTab.SETTINGS -> SettingsScreen(bridge, contentModifier)
                }
            }
        }
    }
}
