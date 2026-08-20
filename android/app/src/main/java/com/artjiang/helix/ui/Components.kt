// Shared Compose building blocks. Ports of NativeSection / NativeStatusPill /
// NativeEmptyState / CompactTagGrid / workspace rows from
// ios/Runner/NativeHelixSecondaryViews.swift + NativeHelixTheme.swift.
package com.artjiang.helix.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import java.util.concurrent.TimeUnit

/** Titled card section — the layout unit every screen is built from. */
@Composable
fun HelixSection(
    title: String,
    subtitle: String? = null,
    modifier: Modifier = Modifier,
    content: @Composable ColumnScope.() -> Unit,
) {
    Card(
        modifier = modifier.fillMaxWidth(),
        shape = RoundedCornerShape(14.dp),
        colors = CardDefaults.cardColors(containerColor = HelixColors.Surface),
        elevation = CardDefaults.cardElevation(defaultElevation = 0.dp),
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(14.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
                Text(
                    text = title,
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.SemiBold,
                    color = HelixColors.Ink,
                )
                if (!subtitle.isNullOrBlank()) {
                    Text(
                        text = subtitle,
                        style = MaterialTheme.typography.bodySmall,
                        color = HelixColors.SecondaryInk,
                    )
                }
            }
            content()
        }
    }
}

/** Small rounded status chip. */
@Composable
fun StatusPill(text: String, tint: Color = HelixColors.Teal, modifier: Modifier = Modifier) {
    Box(
        modifier = modifier
            .background(tint.copy(alpha = 0.12f), RoundedCornerShape(999.dp))
            .padding(horizontal = 10.dp, vertical = 5.dp),
    ) {
        Text(
            text = text,
            style = MaterialTheme.typography.labelMedium,
            fontWeight = FontWeight.SemiBold,
            color = tint,
        )
    }
}

/** Wrapping row of small informational tags. */
@OptIn(androidx.compose.foundation.layout.ExperimentalLayoutApi::class)
@Composable
fun TagRow(values: List<String>, modifier: Modifier = Modifier) {
    val visible = values.filter { it.isNotBlank() }
    if (visible.isEmpty()) return
    androidx.compose.foundation.layout.FlowRow(
        modifier = modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(6.dp),
        verticalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        visible.forEach { value ->
            Box(
                modifier = Modifier
                    .background(HelixColors.Background, RoundedCornerShape(6.dp))
                    .border(1.dp, HelixColors.Hairline, RoundedCornerShape(6.dp))
                    .padding(horizontal = 8.dp, vertical = 4.dp),
            ) {
                Text(
                    text = value,
                    style = MaterialTheme.typography.labelSmall,
                    color = HelixColors.SecondaryInk,
                )
            }
        }
    }
}

/** Icon + title + value/placeholder row used by the Assistant workspace. */
@Composable
fun WorkspaceRow(
    title: String,
    value: String,
    emptyValue: String,
    icon: ImageVector,
    tint: Color,
    modifier: Modifier = Modifier,
) {
    Row(
        modifier = modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Icon(icon, contentDescription = null, tint = tint, modifier = Modifier.size(20.dp))
        Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Text(
                text = title,
                style = MaterialTheme.typography.labelMedium,
                fontWeight = FontWeight.SemiBold,
                color = HelixColors.SecondaryInk,
            )
            Text(
                text = value.ifBlank { emptyValue },
                style = MaterialTheme.typography.bodyMedium,
                color = if (value.isBlank()) HelixColors.SecondaryInk else HelixColors.Ink,
            )
        }
    }
}

/** Icon + title + trailing value metric row (Device screen). */
@Composable
fun MetricRow(title: String, value: String, icon: ImageVector, tint: Color) {
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
            color = HelixColors.SecondaryInk,
        )
        Spacer(Modifier.weight(1f))
        Text(
            text = value,
            style = MaterialTheme.typography.bodyMedium,
            fontWeight = FontWeight.SemiBold,
            color = HelixColors.Ink,
        )
    }
}

@Composable
fun EmptyState(title: String, detail: String, icon: ImageVector) {
    Column(
        modifier = Modifier.fillMaxWidth().padding(vertical = 20.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        Icon(icon, contentDescription = null, tint = HelixColors.SecondaryInk, modifier = Modifier.size(28.dp))
        Text(
            text = title,
            style = MaterialTheme.typography.bodyMedium,
            fontWeight = FontWeight.SemiBold,
            color = HelixColors.Ink,
        )
        Text(
            text = detail,
            style = MaterialTheme.typography.bodySmall,
            color = HelixColors.SecondaryInk,
        )
    }
}

@Composable
fun HairlineDivider(indent: Int = 0) {
    HorizontalDivider(
        modifier = Modifier.padding(start = indent.dp),
        color = HelixColors.Hairline,
    )
}

/** Section content padding shared by all screens. */
val ScreenPadding = PaddingValues(16.dp)

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
