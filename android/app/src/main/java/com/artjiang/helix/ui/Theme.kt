// Material3 theme mirroring NativeHelixTheme.swift (teal accent, light surface).
package com.artjiang.helix.ui

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

object HelixColors {
    val Teal = Color(0xFF0E7490)
    val Indigo = Color(0xFF4F46E5)
    val Green = Color(0xFF15803D)
    val Amber = Color(0xFFB45309)
    val Ink = Color(0xFF0F172A)
    val SecondaryInk = Color(0xFF64748B)
    val Surface = Color(0xFFFFFFFF)
    val Background = Color(0xFFF1F5F9)
    val Hairline = Color(0xFFE2E8F0)
}

private val HelixLightScheme = lightColorScheme(
    primary = HelixColors.Teal,
    onPrimary = Color.White,
    secondary = HelixColors.Indigo,
    onSecondary = Color.White,
    tertiary = HelixColors.Green,
    background = HelixColors.Background,
    onBackground = HelixColors.Ink,
    surface = HelixColors.Surface,
    onSurface = HelixColors.Ink,
    surfaceVariant = HelixColors.Background,
    onSurfaceVariant = HelixColors.SecondaryInk,
    outline = HelixColors.Hairline,
    error = HelixColors.Amber,
)

/**
 * Light-only, matching the iOS shell — NativeHelixTheme hard-codes its palette
 * rather than adapting, so the two platforms stay visually identical.
 */
@Composable
fun HelixTheme(
    @Suppress("UNUSED_PARAMETER") darkTheme: Boolean = isSystemInDarkTheme(),
    content: @Composable () -> Unit,
) {
    MaterialTheme(colorScheme = HelixLightScheme, content = content)
}
