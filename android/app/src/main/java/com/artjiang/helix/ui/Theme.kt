// App theme entry point. Colours, type, and shapes all come from the Warm Linen
// tokens in HelixTokens.kt / Type.kt / Shapes.kt; this file only decides which
// palette is active. Components read colours via `HelixTheme.tokens`.
package com.artjiang.helix.ui

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.runtime.Composable

/**
 * Provides the Warm Linen tokens, the derived Material 3 colour scheme, the
 * Fraunces/Inter typography, and the shape scale to the whole app. Unlike the
 * iOS shell, the Android theme follows the system dark-mode setting.
 */
@Composable
fun HelixTheme(
    darkTheme: Boolean = isSystemInDarkTheme(),
    content: @Composable () -> Unit,
) {
    ProvideHelixTokens(dark = darkTheme, content = content)
}
