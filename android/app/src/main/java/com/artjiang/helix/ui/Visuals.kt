// Canvas-drawn and animated pieces of the Warm Linen UI: the listening mic
// button with its sage halo, the transcript waveform, the battery rings, and
// the press-bounce modifier. Every infinite transition is created only while
// its owner is active so an idle screen schedules no animation frames.
package com.artjiang.helix.ui

import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.StartOffset
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Bolt
import androidx.compose.material.icons.outlined.Mic
import androidx.compose.material.icons.outlined.Stop
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import kotlin.math.sin

/**
 * Alpha for a pulsing status dot: 1 → 0.35 → 1 over [HelixMotion.pulseMillis].
 * Returns a constant 1f (and runs no animation) while [active] is false.
 */
@Composable
fun pulseAlpha(active: Boolean): Float {
    if (!active) return 1f
    val transition = rememberInfiniteTransition(label = "pulse")
    val alpha by transition.animateFloat(
        initialValue = 1f,
        targetValue = 0.35f,
        animationSpec = infiniteRepeatable(
            animation = tween(HelixMotion.pulseMillis / 2, easing = HelixMotion.easeInOutCubic),
            repeatMode = RepeatMode.Reverse,
        ),
        label = "pulseAlpha",
    )
    return alpha
}

/**
 * Scale-bounce on press (0.94× over 250 ms). Pass the same [interactionSource]
 * to the clickable so the bounce tracks its press state.
 */
@Composable
fun Modifier.pressBounce(interactionSource: MutableInteractionSource): Modifier {
    val pressed by interactionSource.collectIsPressedAsState()
    val scale by animateFloatAsState(
        targetValue = if (pressed) HelixMotion.pressScale else 1f,
        animationSpec = tween(HelixMotion.medMillis, easing = HelixMotion.easeOutQuint),
        label = "pressBounce",
    )
    return this.graphicsLayer {
        scaleX = scale
        scaleY = scale
    }
}

/**
 * Terracotta mic button. While listening, two sage halo rings expand from the
 * button edge (1.0 → 1.45×, alpha .35 → 0, 1500 ms, staggered by half a
 * period); while answering, a gold ring marks the thinking state.
 */
@Composable
fun WarmMicButton(
    isListening: Boolean,
    isAnswering: Boolean,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    size: Dp = 72.dp,
) {
    val tokens = HelixTheme.tokens
    val interactionSource = remember { MutableInteractionSource() }
    val haloScale = 1.45f
    val outer = size * haloScale

    Box(modifier = modifier.size(outer), contentAlignment = Alignment.Center) {
        if (isListening) {
            val transition = rememberInfiniteTransition(label = "halo")
            val ringA by transition.animateFloat(
                initialValue = 0f,
                targetValue = 1f,
                animationSpec = infiniteRepeatable(
                    animation = tween(HelixMotion.pulseMillis, easing = LinearEasing),
                    repeatMode = RepeatMode.Restart,
                ),
                label = "ringA",
            )
            val ringB by transition.animateFloat(
                initialValue = 0f,
                targetValue = 1f,
                animationSpec = infiniteRepeatable(
                    animation = tween(HelixMotion.pulseMillis, easing = LinearEasing),
                    repeatMode = RepeatMode.Restart,
                    initialStartOffset = StartOffset(HelixMotion.pulseMillis / 2),
                ),
                label = "ringB",
            )
            val halo = tokens.support
            Canvas(modifier = Modifier.fillMaxSize()) {
                val base = size.toPx() / 2f
                listOf(ringA, ringB).forEach { t ->
                    val radius = base * (1f + (haloScale - 1f) * t)
                    drawCircle(
                        color = halo.copy(alpha = 0.35f * (1f - t)),
                        radius = radius,
                        center = center,
                        style = Stroke(width = 2.dp.toPx()),
                    )
                    drawCircle(
                        color = halo.copy(alpha = 0.12f * (1f - t)),
                        radius = radius,
                        center = center,
                    )
                }
            }
        } else if (isAnswering) {
            val gold = tokens.gold
            val alpha = pulseAlpha(active = true)
            Canvas(modifier = Modifier.fillMaxSize()) {
                drawCircle(
                    color = gold.copy(alpha = alpha * 0.8f),
                    radius = size.toPx() / 2f + 6.dp.toPx(),
                    center = center,
                    style = Stroke(width = 3.dp.toPx()),
                )
            }
        }

        val fill = when {
            isListening -> tokens.accentDeep
            isAnswering -> tokens.gold
            else -> tokens.accent
        }
        Surface(
            onClick = onClick,
            modifier = Modifier
                .size(size)
                .pressBounce(interactionSource),
            shape = CircleShape,
            color = fill,
            contentColor = if (tokens.isDark) tokens.bg else Color.White,
            interactionSource = interactionSource,
            shadowElevation = HelixElevation.e2,
        ) {
            Box(contentAlignment = Alignment.Center) {
                Icon(
                    imageVector = when {
                        isListening -> Icons.Outlined.Stop
                        isAnswering -> Icons.Outlined.Bolt
                        else -> Icons.Outlined.Mic
                    },
                    contentDescription = if (isListening) "Stop listening" else "Start listening",
                    modifier = Modifier.size(size * 0.42f),
                )
            }
        }
    }
}

/**
 * Bar waveform. [energy] (0..1) sets the amplitude; bars ripple while
 * [active], and settle to a quiet resting line otherwise (no animation).
 */
@Composable
fun AnimatedWaveform(
    active: Boolean,
    energy: Float,
    color: Color = HelixTheme.tokens.accent,
    modifier: Modifier = Modifier,
    bars: Int = 28,
) {
    val phase: Float = if (active) {
        val transition = rememberInfiniteTransition(label = "waveform")
        val value by transition.animateFloat(
            initialValue = 0f,
            targetValue = (2 * Math.PI).toFloat(),
            animationSpec = infiniteRepeatable(
                animation = tween(1100, easing = LinearEasing),
                repeatMode = RepeatMode.Restart,
            ),
            label = "phase",
        )
        value
    } else {
        0f
    }
    val amplitude by animateFloatAsState(
        targetValue = if (active) 0.25f + 0.75f * energy.coerceIn(0f, 1f) else 0f,
        animationSpec = tween(HelixMotion.slowMillis, easing = HelixMotion.easeOutQuint),
        label = "amplitude",
    )
    Canvas(modifier = modifier.height(32.dp)) {
        val gap = 3.dp.toPx()
        val barWidth = ((size.width - gap * (bars - 1)) / bars).coerceAtLeast(1f)
        val minHeight = 3.dp.toPx()
        val midY = size.height / 2f
        for (i in 0 until bars) {
            val wave = (sin(phase + i * 0.55f) + 1f) / 2f
            val envelope = 0.55f + 0.45f * sin((i.toFloat() / bars) * Math.PI.toFloat())
            val h = minHeight + (size.height - minHeight) * amplitude * wave * envelope
            val x = i * (barWidth + gap)
            drawRoundRect(
                color = color.copy(alpha = if (active) 0.9f else 0.45f),
                topLeft = Offset(x, midY - h / 2f),
                size = Size(barWidth, h),
                cornerRadius = androidx.compose.ui.geometry.CornerRadius(barWidth / 2f),
            )
        }
    }
}

/**
 * Battery arc for one lens: track on the hairline, sweep coloured by level
 * (success ≥ 50, warning ≥ 20, danger below), animated to the new value.
 * [muted] greys the ring for a lens that is not READY.
 */
@Composable
fun BatteryRing(
    percent: Int?,
    charging: Boolean,
    label: String,
    modifier: Modifier = Modifier,
    size: Dp = 72.dp,
    muted: Boolean = false,
) {
    val tokens = HelixTheme.tokens
    val level = (percent ?: 0).coerceIn(0, 100) / 100f
    val sweep by animateFloatAsState(
        targetValue = if (percent == null) 0f else level,
        animationSpec = tween(HelixMotion.slowMillis * 2, easing = HelixMotion.easeOutQuint),
        label = "batterySweep",
    )
    val levelColor = when {
        muted -> tokens.inkMuted
        percent == null -> tokens.inkMuted
        percent >= 50 -> tokens.success
        percent >= 20 -> tokens.warning
        else -> tokens.danger
    }
    val track = tokens.borderHairline
    Column(
        modifier = modifier,
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = androidx.compose.foundation.layout.Arrangement.spacedBy(HelixSpacing.s8),
    ) {
        Box(modifier = Modifier.size(size), contentAlignment = Alignment.Center) {
            Canvas(modifier = Modifier.fillMaxSize()) {
                val stroke = 6.dp.toPx()
                val inset = stroke / 2f
                val arcSize = Size(this.size.width - stroke, this.size.height - stroke)
                drawArc(
                    color = track,
                    startAngle = -90f,
                    sweepAngle = 360f,
                    useCenter = false,
                    topLeft = Offset(inset, inset),
                    size = arcSize,
                    style = Stroke(width = stroke, cap = StrokeCap.Round),
                )
                if (sweep > 0f) {
                    drawArc(
                        color = levelColor,
                        startAngle = -90f,
                        sweepAngle = 360f * sweep,
                        useCenter = false,
                        topLeft = Offset(inset, inset),
                        size = arcSize,
                        style = Stroke(width = stroke, cap = StrokeCap.Round),
                    )
                }
            }
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                Text(
                    text = percent?.let { "$it%" } ?: "—",
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.SemiBold,
                    color = if (muted) tokens.inkMuted else tokens.ink,
                )
                if (charging && percent != null) {
                    Icon(
                        Icons.Outlined.Bolt,
                        contentDescription = "Charging",
                        tint = if (muted) tokens.inkMuted else tokens.gold,
                        modifier = Modifier.size(12.dp),
                    )
                }
            }
        }
        Text(
            text = label,
            style = MaterialTheme.typography.labelMedium,
            color = if (muted) tokens.inkMuted else tokens.inkSecondary,
        )
    }
}

/**
 * Warm gradient stand-in for the generated hero art (`helix_assistant_hero`):
 * accent tint top-left, sage tint mid, fading to the page background at the
 * bottom edge so the panel sits on the linen rather than floating.
 */
@Composable
fun heroBackdropBrush(): Brush {
    val tokens = HelixTheme.tokens
    return Brush.linearGradient(
        colors = listOf(tokens.accentTint, tokens.supportTint, tokens.bgRaised),
        start = Offset.Zero,
        end = Offset(1200f, 900f),
    )
}

/** Vertical fade used over hero imagery so text at the bottom stays readable. */
@Composable
fun heroFadeBrush(): Brush {
    val tokens = HelixTheme.tokens
    return Brush.verticalGradient(
        0f to Color.Transparent,
        0.55f to tokens.bg.copy(alpha = 0.6f),
        1f to tokens.bg,
    )
}
