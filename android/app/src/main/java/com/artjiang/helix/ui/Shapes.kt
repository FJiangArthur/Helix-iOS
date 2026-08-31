// Warm Linen shape, spacing, and motion tokens (spec §1 radii / spacing / motion).
package com.artjiang.helix.ui

import androidx.compose.animation.core.CubicBezierEasing
import androidx.compose.animation.core.Easing
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Shapes
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp

/**
 * M3 shapes mapped from the spec radii:
 *  radiusSm 8 → extraSmall/small (chips, small buttons)
 *  radiusControl 12 → medium (buttons, inputs)
 *  radiusPanel 16 → large (cards, sheets)
 *  radiusLg 22 → extraLarge (hero panels, modals)
 */
val HelixShapes: Shapes = Shapes(
    extraSmall = RoundedCornerShape(8.dp),
    small = RoundedCornerShape(8.dp),
    medium = RoundedCornerShape(12.dp),
    large = RoundedCornerShape(16.dp),
    extraLarge = RoundedCornerShape(22.dp),
)

/** radiusPill — fully rounded pills and status dots. */
val HelixPillShape: RoundedCornerShape = RoundedCornerShape(50)

/** Spacing scale `s4..s48` → 4 / 8 / 12 / 16 / 20 / 24 / 32 / 48 dp. */
object HelixSpacing {
    val s4: Dp = 4.dp
    val s8: Dp = 8.dp
    val s12: Dp = 12.dp
    val s16: Dp = 16.dp
    val s20: Dp = 20.dp
    val s24: Dp = 24.dp
    val s32: Dp = 32.dp
    val s48: Dp = 48.dp

    /** Unified screen edge padding. */
    val screen: Dp = s16

    /** Gap between cards in lists. */
    val cardGap: Dp = s12

    /** Card content padding. */
    val cardContent: Dp = s16
}

/** Motion durations and easings. */
object HelixMotion {
    /** Micro-interactions, taps. */
    const val fastMillis: Int = 150

    /** Transitions, accent presses (scale-bounce). */
    const val medMillis: Int = 250

    /** Page changes, sheet present. */
    const val slowMillis: Int = 400

    /** Status-dot / halo pulse period. */
    const val pulseMillis: Int = 1500

    /** Enter easing. */
    val easeOutQuint: Easing = CubicBezierEasing(0.22f, 1f, 0.36f, 1f)

    /** Transition easing. */
    val easeInOutCubic: Easing = CubicBezierEasing(0.65f, 0f, 0.35f, 1f)

    /** Press scale for the accent bounce. */
    const val pressScale: Float = 0.94f
}

/** Elevation tokens; shadows are warm-tinted (spec `rgba(60,40,20,…)`). */
object HelixElevation {
    /** Warm shadow colour used as both ambient and spot colour. */
    val shadowColor: Color = Color(0xFF3C2814)

    /** Cards. */
    val e1: Dp = 1.dp

    /** Raised cards, sheets. */
    val e2: Dp = 4.dp

    /** Modals, popovers. */
    val e3: Dp = 12.dp
}
