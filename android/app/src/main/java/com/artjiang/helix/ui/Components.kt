// Shared Compose building blocks in the Warm Linen language: LinenCard is the
// layout unit every screen is built from; the rest are the small, recoloured
// pieces (pills, tags, rows, errors, empty states) that sit inside it. Canvas
// pieces (mic button, waveform, battery ring) live in Visuals.kt.
package com.artjiang.helix.ui

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Close
import androidx.compose.material.icons.outlined.WarningAmber
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.SegmentedButton
import androidx.compose.material3.SegmentedButtonDefaults
import androidx.compose.material3.SingleChoiceSegmentedButtonRow
import androidx.compose.material3.Slider
import androidx.compose.material3.SliderDefaults
import androidx.compose.material3.Surface
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.lerp
import androidx.compose.ui.graphics.painter.Painter
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import java.util.concurrent.TimeUnit
import kotlin.math.roundToInt

/** Container fill for [LinenCard]. */
enum class CardTint { Neutral, Accent, Support, Gold, Danger, Sunk }

@Composable
private fun CardTint.containerColor(): Color {
    val t = HelixTheme.tokens
    return when (this) {
        CardTint.Neutral -> t.surface
        CardTint.Accent -> t.accentTint
        CardTint.Support -> t.supportTint
        CardTint.Gold -> t.goldTint
        CardTint.Danger -> t.dangerTint
        CardTint.Sunk -> t.surfaceSunk
    }
}

/**
 * Text colour for a small coloured label (pill text, dot labels) drawn on a
 * light surface. The light palette's tints are pastel, so they are pulled
 * toward ink for legibility; the dark palette's are already bright enough.
 */
@Composable
fun onTintColor(tint: Color): Color {
    val t = HelixTheme.tokens
    return when {
        t.isDark -> tint
        tint == t.accent -> t.accentDeep
        else -> lerp(tint, t.ink, 0.35f)
    }
}

/**
 * The Warm Linen card: shape 16, hairline border, a 1 dp warm shadow, and an
 * optional 4 dp colour rule down the left edge (clipped by the corner radius).
 */
@Composable
fun LinenCard(
    modifier: Modifier = Modifier,
    tint: CardTint = CardTint.Neutral,
    leftRule: Color? = null,
    onClick: (() -> Unit)? = null,
    contentPadding: Dp = HelixSpacing.cardContent,
    content: @Composable ColumnScope.() -> Unit,
) {
    val tokens = HelixTheme.tokens
    val shape = MaterialTheme.shapes.large
    val shadowed = modifier
        .fillMaxWidth()
        .shadow(
            elevation = HelixElevation.e1,
            shape = shape,
            ambientColor = HelixElevation.shadowColor,
            spotColor = HelixElevation.shadowColor,
        )
    val ruleModifier = if (leftRule != null) {
        Modifier.drawBehind {
            drawRect(
                color = leftRule,
                topLeft = Offset.Zero,
                size = Size(4.dp.toPx(), size.height),
            )
        }
    } else {
        Modifier
    }
    val inner: @Composable () -> Unit = {
        Column(
            modifier = ruleModifier
                .fillMaxWidth()
                .padding(
                    start = if (leftRule != null) contentPadding + 4.dp else contentPadding,
                    end = contentPadding,
                    top = contentPadding,
                    bottom = contentPadding,
                ),
            verticalArrangement = Arrangement.spacedBy(HelixSpacing.s12),
            content = content,
        )
    }
    if (onClick != null) {
        Surface(
            onClick = onClick,
            modifier = shadowed,
            shape = shape,
            color = tint.containerColor(),
            contentColor = tokens.ink,
            border = BorderStroke(1.dp, tokens.borderHairline),
            shadowElevation = 0.dp,
            tonalElevation = 0.dp,
        ) { inner() }
    } else {
        Surface(
            modifier = shadowed,
            shape = shape,
            color = tint.containerColor(),
            contentColor = tokens.ink,
            border = BorderStroke(1.dp, tokens.borderHairline),
            shadowElevation = 0.dp,
            tonalElevation = 0.dp,
        ) { inner() }
    }
}

/** Tinted circle with an outlined icon — the duotone approximation from the spec. */
@Composable
fun IconBadge(
    icon: ImageVector,
    tint: Color = HelixTheme.tokens.accent,
    size: Dp = 36.dp,
    modifier: Modifier = Modifier,
) {
    Box(
        modifier = modifier
            .size(size)
            .background(tint.copy(alpha = 0.18f), CircleShape),
        contentAlignment = Alignment.Center,
    ) {
        Icon(
            imageVector = icon,
            contentDescription = null,
            tint = onTintColor(tint),
            modifier = Modifier.size(size / 2),
        )
    }
}

/**
 * Titled card section — the layout unit every screen is built from. Built on
 * [LinenCard]; `icon`/`tint` are defaulted so earlier call-sites compile.
 */
@Composable
fun HelixSection(
    title: String,
    subtitle: String? = null,
    modifier: Modifier = Modifier,
    icon: ImageVector? = null,
    tint: Color = Color.Unspecified,
    cardTint: CardTint = CardTint.Neutral,
    leftRule: Color? = null,
    content: @Composable ColumnScope.() -> Unit,
) {
    val tokens = HelixTheme.tokens
    val badgeTint = if (tint == Color.Unspecified) tokens.accent else tint
    LinenCard(modifier = modifier, tint = cardTint, leftRule = leftRule) {
        SectionHeader(title = title, subtitle = subtitle, icon = icon, tint = badgeTint)
        content()
    }
}

/** Title/subtitle row with an optional [IconBadge]; reused by the screens' custom cards. */
@Composable
fun SectionHeader(
    title: String,
    subtitle: String? = null,
    icon: ImageVector? = null,
    tint: Color = HelixTheme.tokens.accent,
    modifier: Modifier = Modifier,
    trailing: (@Composable () -> Unit)? = null,
) {
    val tokens = HelixTheme.tokens
    Row(
        modifier = modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(HelixSpacing.s12),
    ) {
        if (icon != null) IconBadge(icon = icon, tint = tint)
        Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(
                text = title,
                style = MaterialTheme.typography.titleMedium,
                color = tokens.ink,
            )
            if (!subtitle.isNullOrBlank()) {
                Text(
                    text = subtitle,
                    style = MaterialTheme.typography.bodySmall,
                    color = tokens.inkSecondary,
                )
            }
        }
        if (trailing != null) trailing()
    }
}

/** Small rounded status chip with a leading dot; the dot pulses when [pulsing]. */
@Composable
fun StatusPill(
    text: String,
    tint: Color = HelixTheme.tokens.accent,
    modifier: Modifier = Modifier,
    pulsing: Boolean = false,
) {
    val dotAlpha = pulseAlpha(active = pulsing)
    Row(
        modifier = modifier
            .background(tint.copy(alpha = 0.14f), HelixPillShape)
            .padding(horizontal = 10.dp, vertical = 5.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        Box(
            modifier = Modifier
                .size(6.dp)
                .background(tint.copy(alpha = dotAlpha), CircleShape),
        )
        Text(
            text = text,
            style = MaterialTheme.typography.labelMedium,
            color = onTintColor(tint),
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
        )
    }
}

/** Wrapping row of small informational tags. */
@OptIn(ExperimentalLayoutApi::class)
@Composable
fun TagRow(values: List<String>, modifier: Modifier = Modifier) {
    val tokens = HelixTheme.tokens
    val visible = values.filter { it.isNotBlank() }
    if (visible.isEmpty()) return
    FlowRow(
        modifier = modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(6.dp),
        verticalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        visible.forEach { value ->
            Box(
                modifier = Modifier
                    .background(tokens.surfaceSunk, MaterialTheme.shapes.small)
                    .border(1.dp, tokens.borderHairline, MaterialTheme.shapes.small)
                    .padding(horizontal = 8.dp, vertical = 4.dp),
            ) {
                Text(
                    text = value,
                    style = MaterialTheme.typography.labelSmall,
                    color = tokens.inkSecondary,
                )
            }
        }
    }
}

/** Icon + title + trailing value metric row (Device screen). */
@Composable
fun MetricRow(title: String, value: String, icon: ImageVector, tint: Color) {
    val tokens = HelixTheme.tokens
    Row(
        modifier = Modifier.fillMaxWidth().padding(vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        Icon(icon, contentDescription = null, tint = tint, modifier = Modifier.size(20.dp))
        Text(
            text = title,
            style = MaterialTheme.typography.bodyMedium,
            fontWeight = FontWeight.SemiBold,
            color = tokens.inkSecondary,
        )
        Spacer(Modifier.weight(1f))
        Text(
            text = value,
            style = MaterialTheme.typography.bodyMedium,
            fontWeight = FontWeight.SemiBold,
            color = tokens.ink,
        )
    }
}

/**
 * Centered empty state. [illustration] is the slot for the generated
 * watercolour art (sized by [illustrationSize], 160 dp by default); until
 * those assets exist the icon badge is shown instead.
 */
@Composable
fun EmptyState(
    title: String,
    detail: String,
    icon: ImageVector,
    illustration: Painter? = null,
    modifier: Modifier = Modifier,
    illustrationSize: Dp = 160.dp,
) {
    val tokens = HelixTheme.tokens
    Column(
        modifier = modifier.fillMaxWidth().padding(vertical = HelixSpacing.s20),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(HelixSpacing.s8),
    ) {
        if (illustration != null) {
            androidx.compose.foundation.Image(
                painter = illustration,
                contentDescription = null,
                contentScale = ContentScale.Fit,
                modifier = Modifier.size(illustrationSize),
            )
        } else {
            IconBadge(icon = icon, tint = tokens.support, size = 56.dp)
        }
        Text(
            text = title,
            style = MaterialTheme.typography.headlineSmall,
            color = tokens.ink,
        )
        Text(
            text = detail,
            style = MaterialTheme.typography.bodySmall,
            color = tokens.inkSecondary,
            textAlign = androidx.compose.ui.text.style.TextAlign.Center,
        )
    }
}

@Composable
fun HairlineDivider(indent: Int = 0) {
    HorizontalDivider(
        modifier = Modifier.padding(start = indent.dp),
        color = HelixTheme.tokens.borderHairline,
    )
}

/** Single-choice segmented selector shared by the mode and bucket pickers. */
@Composable
fun <T> HelixSegmentedRow(
    entries: List<T>,
    selected: T,
    label: (T) -> String,
    modifier: Modifier = Modifier,
    onSelect: (T) -> Unit,
) {
    val tokens = HelixTheme.tokens
    val scheme = MaterialTheme.colorScheme
    val colors = SegmentedButtonDefaults.colors(
        activeContainerColor = tokens.accentTint,
        activeContentColor = scheme.onPrimaryContainer,
        activeBorderColor = tokens.borderStrong,
        inactiveContainerColor = tokens.surface,
        inactiveContentColor = tokens.inkSecondary,
        inactiveBorderColor = tokens.borderStrong,
    )
    SingleChoiceSegmentedButtonRow(modifier = modifier.fillMaxWidth()) {
        entries.forEachIndexed { index, entry ->
            SegmentedButton(
                selected = selected == entry,
                onClick = { onSelect(entry) },
                shape = SegmentedButtonDefaults.itemShape(index, entries.size),
                colors = colors,
                icon = {},
            ) {
                Text(
                    text = label(entry),
                    style = MaterialTheme.typography.labelMedium,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
            }
        }
    }
}

/** Error banner on the error container with a dismiss button, shared by every error surface. */
@Composable
fun DismissibleError(text: String, modifier: Modifier = Modifier, onDismiss: () -> Unit) {
    val scheme = MaterialTheme.colorScheme
    Surface(
        modifier = modifier.fillMaxWidth(),
        shape = MaterialTheme.shapes.medium,
        color = scheme.errorContainer,
        contentColor = scheme.onErrorContainer,
    ) {
        Row(
            modifier = Modifier.padding(start = 12.dp, top = 4.dp, bottom = 4.dp, end = 4.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            Icon(
                Icons.Outlined.WarningAmber,
                contentDescription = null,
                modifier = Modifier.size(18.dp),
            )
            Text(
                text = text,
                style = MaterialTheme.typography.bodySmall,
                modifier = Modifier.weight(1f).padding(vertical = 6.dp),
            )
            IconButton(onClick = onDismiss) {
                Icon(Icons.Outlined.Close, contentDescription = "Dismiss error")
            }
        }
    }
}

/**
 * Titled value slider. The value is local while dragging and committed once on
 * release — Device-screen sliders push BLE bursts per commit, so per-frame
 * commits are never acceptable, and Settings sliders gain nothing from them.
 */
@Composable
fun SliderRow(
    title: String,
    value: Int,
    range: IntRange,
    suffix: String = "",
    enabled: Boolean = true,
    onCommit: (Int) -> Unit,
) {
    val tokens = HelixTheme.tokens
    var dragValue by remember(value) { mutableFloatStateOf(value.toFloat()) }
    Column(modifier = Modifier.fillMaxWidth()) {
        Row(modifier = Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
            Text(
                text = title,
                style = MaterialTheme.typography.labelMedium,
                color = tokens.inkSecondary,
            )
            Spacer(Modifier.weight(1f))
            Text(
                text = "${dragValue.roundToInt()}$suffix",
                style = MaterialTheme.typography.labelMedium,
                fontWeight = FontWeight.Bold,
                color = tokens.ink,
            )
        }
        Slider(
            value = dragValue,
            onValueChange = { dragValue = it },
            onValueChangeFinished = {
                onCommit(dragValue.roundToInt().coerceIn(range.first, range.last))
            },
            valueRange = range.first.toFloat()..range.last.toFloat(),
            steps = (range.last - range.first - 1).coerceAtLeast(0),
            enabled = enabled,
            colors = SliderDefaults.colors(
                thumbColor = tokens.accent,
                activeTrackColor = tokens.accent,
                activeTickColor = tokens.accentTint,
                inactiveTrackColor = tokens.surfaceSunk,
                inactiveTickColor = tokens.borderStrong,
                disabledThumbColor = tokens.borderStrong,
                disabledActiveTrackColor = tokens.borderStrong,
                disabledInactiveTrackColor = tokens.surfaceSunk,
            ),
        )
    }
}

/** Titled switch row with an optional detail line. */
@Composable
fun ToggleRow(
    title: String,
    checked: Boolean,
    detail: String? = null,
    onCheckedChange: (Boolean) -> Unit,
) {
    val tokens = HelixTheme.tokens
    Row(
        modifier = Modifier.fillMaxWidth().padding(vertical = 6.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(
                text = title,
                style = MaterialTheme.typography.bodyMedium,
                fontWeight = FontWeight.SemiBold,
                color = tokens.ink,
            )
            if (detail != null) {
                Text(text = detail, style = MaterialTheme.typography.bodySmall, color = tokens.inkSecondary)
            }
        }
        Switch(
            checked = checked,
            onCheckedChange = onCheckedChange,
            colors = SwitchDefaults.colors(
                checkedTrackColor = tokens.success,
                checkedThumbColor = Color.White,
                checkedBorderColor = Color.Transparent,
                uncheckedTrackColor = tokens.surfaceSunk,
                uncheckedThumbColor = tokens.inkMuted,
                uncheckedBorderColor = tokens.borderStrong,
            ),
        )
    }
}

/** "3m ago"-style label, matching `Date.nativeRelativeLabel` on iOS. */
fun relativeLabel(timestampMillis: Long, nowMillis: Long = System.currentTimeMillis()): String {
    val delta = (nowMillis - timestampMillis).coerceAtLeast(0)
    val seconds = TimeUnit.MILLISECONDS.toSeconds(delta)
    if (seconds < 60) return "now"
    val minutes = TimeUnit.MILLISECONDS.toMinutes(delta)
    if (minutes < 60) return "${minutes}m ago"
    val hours = TimeUnit.MILLISECONDS.toHours(delta)
    if (hours < 24) return "${hours}h ago"
    return "${TimeUnit.MILLISECONDS.toDays(delta)}d ago"
}
