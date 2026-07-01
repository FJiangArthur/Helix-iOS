import HelixG1
import HelixRuntime
import SwiftUI

@MainActor
struct NativeDeviceView: View {
    let runtime: HelixRuntimeDependencies

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                NativeSection("G1 device", subtitle: runtime.g1DeviceState.connectionSummary) {
                    VStack(alignment: .leading, spacing: 12) {
                        DeviceStatusList(metrics: connectionMetrics)
                        Divider()
                        HudControlsRow(
                            pageSummary: runtime.g1DeviceState.currentPageSummary,
                            canPushAnswer: !runtime.assistantSession.currentAnswer.isEmpty,
                            previousAction: showPreviousPage,
                            pushAction: pushAnswer,
                            nextAction: showNextPage
                        )
                        Divider()
                        TouchpadPreviewRow(
                            statusSummary: runtime.g1DeviceState.lastTouchpadSummary,
                            previewText: runtime.g1DeviceState.hudPages.first?.text
                        )
                    }
                }
            }
            .padding(16)
        }
        .scrollContentBackground(.hidden)
    }

    private var connectionMetrics: [DeviceMetric] {
        [
            DeviceMetric(
                title: "Left",
                value: runtime.g1DeviceState.leftLensConnected ? "Connected" : "Waiting",
                symbolName: "l.circle",
                tint: runtime.g1DeviceState.leftLensConnected ? NativeHelixTheme.green : NativeHelixTheme.secondaryInk
            ),
            DeviceMetric(
                title: "Right",
                value: runtime.g1DeviceState.rightLensConnected ? "Connected" : "Waiting",
                symbolName: "r.circle",
                tint: runtime.g1DeviceState.rightLensConnected ? NativeHelixTheme.green : NativeHelixTheme.secondaryInk
            ),
            DeviceMetric(
                title: "HUD",
                value: "\(runtime.g1DeviceState.sentPacketCount) queued",
                symbolName: "rectangle.3.group",
                tint: NativeHelixTheme.indigo
            )
        ]
    }

    private func showPreviousPage() {
        runtime.g1DeviceState.handleTouchpad(notifyIndex: 1, side: .left)
    }

    private func pushAnswer() {
        runtime.g1DeviceState.presentText(runtime.assistantSession.currentAnswer)
    }

    private func showNextPage() {
        runtime.g1DeviceState.handleTouchpad(notifyIndex: 1, side: .right)
    }
}

private struct TouchpadPreviewRow: View {
    let statusSummary: String
    let previewText: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Image(systemName: "hand.tap")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(NativeHelixTheme.teal)
                    .frame(width: 22, height: 22)
                Text("Touchpad")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(NativeHelixTheme.ink)
                Spacer(minLength: 0)
                Text(statusSummary)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(NativeHelixTheme.secondaryInk)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }

            if let previewText, !previewText.isEmpty {
                Text(previewText)
                    .font(.footnote)
                    .foregroundStyle(NativeHelixTheme.secondaryInk)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("Send an answer from Assistant to preview G1 pagination here.")
                    .font(.footnote)
                    .foregroundStyle(NativeHelixTheme.secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

private struct DeviceMetric: Identifiable {
    let title: String
    let value: String
    let symbolName: String
    let tint: Color

    var id: String { title }
}

private struct DeviceStatusList: View {
    let metrics: [DeviceMetric]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(metrics.indices, id: \.self) { index in
                DeviceMetricRow(metric: metrics[index])
                if index < metrics.index(before: metrics.endIndex) {
                    Divider()
                        .padding(.leading, 32)
                }
            }
        }
    }
}

private struct DeviceMetricRow: View {
    let metric: DeviceMetric

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: metric.symbolName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(metric.tint)
                .frame(width: 22, height: 22)
            Text(metric.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(NativeHelixTheme.secondaryInk)
            Spacer(minLength: 10)
            Text(metric.value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(NativeHelixTheme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, minHeight: 38, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

private struct HudControlsRow: View {
    let pageSummary: String
    let canPushAnswer: Bool
    let previousAction: () -> Void
    let pushAction: () -> Void
    let nextAction: () -> Void

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) {
                NativeStatusPill(text: pageSummary, tint: NativeHelixTheme.indigo)
                Spacer(minLength: 0)
                HudControlButtons(
                    canPushAnswer: canPushAnswer,
                    previousAction: previousAction,
                    pushAction: pushAction,
                    nextAction: nextAction
                )
            }

            VStack(alignment: .leading, spacing: 10) {
                NativeStatusPill(text: pageSummary, tint: NativeHelixTheme.indigo)
                HudControlButtons(
                    canPushAnswer: canPushAnswer,
                    previousAction: previousAction,
                    pushAction: pushAction,
                    nextAction: nextAction
                )
            }
        }
    }
}

private struct HudControlButtons: View {
    let canPushAnswer: Bool
    let previousAction: () -> Void
    let pushAction: () -> Void
    let nextAction: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            NativeIconButton(
                symbolName: "chevron.left",
                accessibilityLabel: "Previous HUD page",
                action: previousAction
            )

            NativeIconButton(
                symbolName: "eyeglasses",
                isPrimary: true,
                isDisabled: !canPushAnswer,
                accessibilityLabel: "Push answer to glasses",
                action: pushAction
            )

            NativeIconButton(
                symbolName: "chevron.right",
                accessibilityLabel: "Next HUD page",
                action: nextAction
            )
        }
    }
}
