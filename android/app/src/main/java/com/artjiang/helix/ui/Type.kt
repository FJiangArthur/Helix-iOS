// Warm Linen typography: Fraunces (serif display/headings) + Inter (UI/body),
// both shipped as variable TTFs in res/font (see scripts/fetch_fonts.sh) so the
// app never depends on a runtime font fetch. Scale per the Warm Linen spec §2;
// M3 slot mapping per the Workstream C plan.
@file:OptIn(ExperimentalTextApi::class) // FontVariation.Settings(vararg) is still experimental in Compose 1.7

package com.artjiang.helix.ui

import androidx.compose.material3.Typography
import androidx.compose.ui.text.ExperimentalTextApi
import androidx.compose.ui.text.PlatformTextStyle
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontVariation
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.sp
import com.artjiang.helix.R

/** Inter's "book" weight used for reading text in the spec (450). */
val FontWeightBook: FontWeight = FontWeight(450)

private fun interFont(weight: FontWeight): Font = Font(
    resId = R.font.inter_variable,
    weight = weight,
    style = FontStyle.Normal,
    variationSettings = FontVariation.Settings(
        FontVariation.weight(weight.weight),
        // Inter's optical-size axis spans 14..32; UI text sits at the text end.
        FontVariation.Setting("opsz", 14f),
    ),
)

private fun frauncesFont(weight: FontWeight): Font = Font(
    resId = R.font.fraunces_variable,
    weight = weight,
    style = FontStyle.Normal,
    variationSettings = FontVariation.Settings(
        FontVariation.weight(weight.weight),
        // Display optical size, softened terminals, no "wonky" alternates.
        FontVariation.Setting("opsz", 32f),
        FontVariation.Setting("SOFT", 30f),
        FontVariation.Setting("WONK", 0f),
    ),
)

/** Inter variable font at the four weights the type scale uses. */
val InterFontFamily: FontFamily = FontFamily(
    interFont(FontWeightBook),
    interFont(FontWeight.Medium),
    interFont(FontWeight.SemiBold),
    interFont(FontWeight.Bold),
)

/** Fraunces variable font at the two display weights the type scale uses. */
val FrauncesFontFamily: FontFamily = FontFamily(
    frauncesFont(FontWeight.Medium),
    frauncesFont(FontWeight.SemiBold),
)

private val NoFontPadding = PlatformTextStyle(includeFontPadding = false)

private fun fraunces(size: Int, weight: FontWeight, lineHeight: Float) = TextStyle(
    fontFamily = FrauncesFontFamily,
    fontWeight = weight,
    fontSize = size.sp,
    lineHeight = lineHeight.sp,
    platformStyle = NoFontPadding,
)

private fun inter(size: Int, weight: FontWeight, lineHeight: Float, letterSpacing: Float = 0f) = TextStyle(
    fontFamily = InterFontFamily,
    fontWeight = weight,
    fontSize = size.sp,
    lineHeight = lineHeight.sp,
    letterSpacing = letterSpacing.sp,
    platformStyle = NoFontPadding,
)

/**
 * Material 3 typography populated from the Warm Linen type scale.
 *
 * Spec → M3 slot:
 *  display  → displayMedium (Fraunces 32/600)
 *  title1   → headlineMedium (Fraunces 24/600); headlineSmall (Fraunces 20/600) is the AI answer style
 *  title2   → titleLarge (Inter 18/600)
 *  title3   → titleMedium (Inter 15/600)
 *  bodyLg   → bodyLarge (Inter 16/450, lh 24)
 *  body     → bodyMedium (Inter 14/450)
 *  bodySm   → bodySmall (Inter 13/450)
 *  caption  → labelMedium (Inter 12/500)
 *  label    → labelSmall (Inter 11/600, tracking 0.6)
 */
val HelixTypography: Typography = Typography(
    displayLarge = fraunces(40, FontWeight.SemiBold, 46f),
    displayMedium = fraunces(32, FontWeight.SemiBold, 37f),
    displaySmall = fraunces(28, FontWeight.SemiBold, 33f),
    headlineLarge = fraunces(28, FontWeight.SemiBold, 34f),
    headlineMedium = fraunces(24, FontWeight.SemiBold, 29f),
    headlineSmall = fraunces(20, FontWeight.SemiBold, 24f),
    titleLarge = inter(18, FontWeight.SemiBold, 23f),
    titleMedium = inter(15, FontWeight.SemiBold, 20f),
    titleSmall = inter(13, FontWeight.SemiBold, 18f),
    bodyLarge = inter(16, FontWeightBook, 24f),
    bodyMedium = inter(14, FontWeightBook, 21f),
    bodySmall = inter(13, FontWeightBook, 19f),
    labelLarge = inter(14, FontWeight.SemiBold, 20f),
    labelMedium = inter(12, FontWeight.Medium, 17f),
    labelSmall = inter(11, FontWeight.SemiBold, 14f, letterSpacing = 0.6f),
)

/** Extra styles from the spec that have no M3 slot of their own. */
object HelixTextStyles {
    /** Onboarding hero / empty-state titles. Same as [Typography.displayMedium]. */
    val display: TextStyle = HelixTypography.displayMedium

    /** Uppercase status labels; callers apply `.uppercase()` to the text. */
    val label: TextStyle = HelixTypography.labelSmall

    /** Transcripts in dev, code, log output. JetBrains Mono is skipped; platform mono is used. */
    val mono: TextStyle = TextStyle(
        fontFamily = FontFamily.Monospace,
        fontWeight = FontWeight.Normal,
        fontSize = 13.sp,
        lineHeight = 19.5.sp,
        platformStyle = NoFontPadding,
    )
}
