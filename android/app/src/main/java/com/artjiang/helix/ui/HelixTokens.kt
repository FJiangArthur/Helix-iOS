// Warm Linen design tokens (spec §1) and the Material 3 mapping used by the
// theme. Theme.kt's HelixTheme() delegates to ProvideHelixTokens below.
package com.artjiang.helix.ui

import androidx.compose.material3.ColorScheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.Immutable
import androidx.compose.runtime.ReadOnlyComposable
import androidx.compose.runtime.remember
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.unit.Density

/**
 * Semantic colour tokens. Names are mode-agnostic; [isDark] tells components
 * which palette is active when they need to branch (e.g. image alpha).
 */
@Immutable
data class HelixTokens(
    /** App background (warm linen). */
    val bg: Color,
    /** Subtly raised surface. */
    val bgRaised: Color,
    /** Cards, sheets, primary panels. */
    val surface: Color,
    /** Sunken surfaces (search, code). */
    val surfaceSunk: Color,
    /** Default 1 px border. */
    val borderHairline: Color,
    /** Emphasis, focused borders. */
    val borderStrong: Color,
    /** Primary text (warm near-black). */
    val ink: Color,
    /** Secondary text. */
    val inkSecondary: Color,
    /** Tertiary text, captions. */
    val inkMuted: Color,
    /** Terracotta — primary actions, brand. */
    val accent: Color,
    /** Pressed / active accent; also link colour on light surfaces. */
    val accentDeep: Color,
    /** Accent backgrounds, duotone fills. */
    val accentTint: Color,
    /** Sage — secondary highlight, links. */
    val support: Color,
    /** Sage container. */
    val supportTint: Color,
    /** Premium / brass — special states. */
    val gold: Color,
    /** Gold container. */
    val goldTint: Color,
    /** Confirmed facts, ready state. */
    val success: Color,
    /** Thinking, attention. */
    val warning: Color,
    /** Errors. */
    val danger: Color,
    /** Error container. */
    val dangerTint: Color,
    /** Text on [dangerTint]. */
    val onDangerTint: Color,
    val isDark: Boolean,
)

val HelixLightTokens: HelixTokens = HelixTokens(
    bg = Color(0xFFF7F4F0),
    bgRaised = Color(0xFFFBF9F5),
    surface = Color(0xFFFFFFFF),
    surfaceSunk = Color(0xFFF1ECE3),
    borderHairline = Color(0xFFEBE3D7),
    borderStrong = Color(0xFFD9CDB9),
    ink = Color(0xFF2C2825),
    inkSecondary = Color(0xFF6F665C),
    inkMuted = Color(0xFFA09687),
    accent = Color(0xFFD89B7B),
    accentDeep = Color(0xFFB97A5A),
    accentTint = Color(0xFFF5E2D5),
    support = Color(0xFF88A89E),
    supportTint = Color(0xFFE3ECE8),
    gold = Color(0xFFC7A35F),
    goldTint = Color(0xFFF3E9D2),
    success = Color(0xFF6E9E78),
    warning = Color(0xFFC9A86A),
    danger = Color(0xFFC45A48),
    dangerTint = Color(0xFFF8E1DC),
    onDangerTint = Color(0xFF7A2E22),
    isDark = false,
)

val HelixDarkTokens: HelixTokens = HelixTokens(
    bg = Color(0xFF1A1612),
    bgRaised = Color(0xFF221C16),
    surface = Color(0xFF2A231C),
    surfaceSunk = Color(0xFF16110D),
    borderHairline = Color(0xFF3A2F25),
    borderStrong = Color(0xFF4F3F31),
    ink = Color(0xFFF2EBDF),
    inkSecondary = Color(0xFFC2B6A3),
    inkMuted = Color(0xFF8A7F6E),
    accent = Color(0xFFE8B393),
    accentDeep = Color(0xFFC18A68),
    accentTint = Color(0xFF3A2A20),
    support = Color(0xFFA8C2B8),
    supportTint = Color(0xFF27352F),
    gold = Color(0xFFD9B976),
    goldTint = Color(0xFF3B3220),
    success = Color(0xFF8DBE96),
    warning = Color(0xFFD9C284),
    danger = Color(0xFFE07A65),
    dangerTint = Color(0xFF4A2420),
    onDangerTint = Color(0xFFF2C4B9),
    isDark = true,
)

val LocalHelixTokens = staticCompositionLocalOf { HelixLightTokens }

/** Accessor mirroring [MaterialTheme]: `HelixTheme.tokens.accent`. */
object HelixTheme {
    val tokens: HelixTokens
        @Composable
        @ReadOnlyComposable
        get() = LocalHelixTokens.current
}

/** Largest font scale the layouts are designed for (spec §2 Dynamic Type cap). */
const val HELIX_MAX_FONT_SCALE: Float = 1.4f

/**
 * M3 [ColorScheme] derived from tokens.
 *
 * primary=accent, primaryContainer=accentTint, secondary=support, tertiary=gold,
 * background=surface=bg, surfaceContainerLowest=card surface (#FFFFFF in light),
 * outline=borderStrong, outlineVariant=borderHairline, error=danger,
 * errorContainer=dangerTint.
 */
fun helixColorScheme(tokens: HelixTokens): ColorScheme {
    // White on terracotta is ~2.3:1, so dark mode puts ink-dark bg on the
    // lighter accent; light keeps white for filled primary buttons per spec.
    val onAccent = if (tokens.isDark) tokens.bg else Color.White
    val onContainerAccent = if (tokens.isDark) tokens.accent else tokens.accentDeep
    val base = if (tokens.isDark) darkColorScheme() else lightColorScheme()
    return base.copy(
        primary = tokens.accent,
        onPrimary = onAccent,
        primaryContainer = tokens.accentTint,
        onPrimaryContainer = onContainerAccent,
        inversePrimary = if (tokens.isDark) HelixLightTokens.accent else HelixDarkTokens.accent,
        secondary = tokens.support,
        onSecondary = onAccent,
        secondaryContainer = tokens.supportTint,
        onSecondaryContainer = tokens.ink,
        tertiary = tokens.gold,
        onTertiary = onAccent,
        tertiaryContainer = tokens.goldTint,
        onTertiaryContainer = tokens.ink,
        background = tokens.bg,
        onBackground = tokens.ink,
        surface = tokens.bg,
        onSurface = tokens.ink,
        surfaceVariant = tokens.surfaceSunk,
        onSurfaceVariant = tokens.inkSecondary,
        surfaceTint = tokens.accent,
        inverseSurface = tokens.ink,
        inverseOnSurface = tokens.bg,
        error = tokens.danger,
        onError = Color.White,
        errorContainer = tokens.dangerTint,
        onErrorContainer = tokens.onDangerTint,
        outline = tokens.borderStrong,
        outlineVariant = tokens.borderHairline,
        scrim = Color.Black,
        surfaceBright = tokens.bgRaised,
        surfaceDim = tokens.surfaceSunk,
        surfaceContainer = tokens.bgRaised,
        surfaceContainerHigh = tokens.surfaceSunk,
        surfaceContainerHighest = tokens.surfaceSunk,
        surfaceContainerLow = tokens.bgRaised,
        surfaceContainerLowest = tokens.surface,
    )
}

fun helixLightColorScheme(): ColorScheme = helixColorScheme(HelixLightTokens)

fun helixDarkColorScheme(): ColorScheme = helixColorScheme(HelixDarkTokens)

/**
 * Provides [LocalHelixTokens] plus a [MaterialTheme] built from the tokens,
 * [HelixTypography], and [HelixShapes], with the system font scale capped at
 * [HELIX_MAX_FONT_SCALE] so accessibility sizes enlarge text without breaking
 * layouts.
 */
@Composable
fun ProvideHelixTokens(
    dark: Boolean,
    content: @Composable () -> Unit,
) {
    val tokens = if (dark) HelixDarkTokens else HelixLightTokens
    val colorScheme = remember(tokens) { helixColorScheme(tokens) }
    val systemDensity = LocalDensity.current
    val cappedDensity = remember(systemDensity) {
        if (systemDensity.fontScale <= HELIX_MAX_FONT_SCALE) {
            systemDensity
        } else {
            Density(density = systemDensity.density, fontScale = HELIX_MAX_FONT_SCALE)
        }
    }
    CompositionLocalProvider(
        LocalHelixTokens provides tokens,
        LocalDensity provides cappedDensity,
    ) {
        MaterialTheme(
            colorScheme = colorScheme,
            typography = HelixTypography,
            shapes = HelixShapes,
            content = content,
        )
    }
}
