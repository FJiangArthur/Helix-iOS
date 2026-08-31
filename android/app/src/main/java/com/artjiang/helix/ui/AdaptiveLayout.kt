// Width-class buckets and content clamping for adaptive layout. Pure Dp math
// (no WindowSizeClass dependency) so screens can bucket from BoxWithConstraints
// and the logic stays unit-testable on the JVM.
package com.artjiang.helix.ui

import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.widthIn
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp

/**
 * Coarse width buckets for Helix screens:
 * - [Narrow]: < 380 dp (Fold cover screen, small phones) — drop secondary
 *   chips, let pill rows wrap.
 * - [Standard]: 380..599 dp (typical phones) — the default layout.
 * - [Wide]: >= 600 dp (Fold inner display, tablets) — clamp content width
 *   with [helixMaxContentWidth] and center it.
 */
enum class HelixWidthClass { Narrow, Standard, Wide }

/** Buckets [maxWidth] (usually `BoxWithConstraints.maxWidth`) into a [HelixWidthClass]. */
fun helixWidthClass(maxWidth: Dp): HelixWidthClass = when {
    maxWidth < 380.dp -> HelixWidthClass.Narrow
    maxWidth < 600.dp -> HelixWidthClass.Standard
    else -> HelixWidthClass.Wide
}

/**
 * Clamps content to at most [max] while filling whatever width is available
 * below that, so cards stop stretching absurdly wide on the Fold inner
 * display and tablets.
 *
 * The clamp only shrinks this node — it does NOT position it. The parent must
 * center the clamped child or it will sit flush left on wide screens: use
 * `contentAlignment = Alignment.TopCenter` on a wrapping Box, or
 * `horizontalAlignment = Alignment.CenterHorizontally` on a Column/LazyColumn.
 */
fun Modifier.helixMaxContentWidth(max: Dp = 640.dp): Modifier =
    widthIn(max = max).fillMaxWidth()
