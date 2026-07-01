import HelixG1
import HelixRuntime
import SwiftUI

@MainActor
struct NativeDeviceView: View {
    let runtime: HelixRuntimeDependencies

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                NativeSection("G1 connection", subtitle: runtime.g1DeviceState.connectionSummary) {
                    DeviceStatusGrid(metrics: connectionMetrics)
                }

                NativeSection("HUD controls", subtitle: runtime.g1DeviceState.currentPageSummary) {
                    HStack(spacing: 10) {
                        NativeIconButton(
                            symbolName: "chevron.left",
                            accessibilityLabel: "Previous HUD page",
                            action: showPreviousPage
                        )

                        NativeIconButton(
                            symbolName: "eyeglasses",
                            isPrimary: true,
                            isDisabled: runtime.assistantSession.currentAnswer.isEmpty,
                            accessibilityLabel: "Push answer to glasses",
                            action: pushAnswer
                        )

                        NativeIconButton(
                            symbolName: "chevron.right",
                            accessibilityLabel: "Next HUD page",
                            action: showNextPage
                        )
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                NativeSection("Touchpad") {
                    VStack(alignment: .leading, spacing: 10) {
                        NativeStatusPill(
                            text: runtime.g1DeviceState.lastTouchpadSummary,
                            tint: NativeHelixTheme.teal
                        )
                        if let firstPage = runtime.g1DeviceState.hudPages.first {
                            Text(firstPage.text)
                                .font(.footnote)
                                .foregroundStyle(NativeHelixTheme.secondaryInk)
                                .lineLimit(3)
                        } else {
                            NativeEmptyState(
                                title: "No HUD page loaded",
                                detail: "Send an answer from Assistant to preview G1 pagination here.",
                                symbolName: "eyeglasses"
                            )
                        }
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

private struct DeviceMetric: Identifiable {
    let title: String
    let value: String
    let symbolName: String
    let tint: Color

    var id: String { title }
}

private struct DeviceStatusGrid: View {
    let metrics: [DeviceMetric]

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: 8)], spacing: 8) {
            ForEach(metrics) { metric in
                DeviceMetricTile(metric: metric)
            }
        }
    }
}

private struct DeviceMetricTile: View {
    let metric: DeviceMetric

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: metric.symbolName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(metric.tint)
                .frame(width: 18, height: 18)
            VStack(alignment: .leading, spacing: 2) {
                Text(metric.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(NativeHelixTheme.secondaryInk)
                Text(metric.value)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(NativeHelixTheme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: 78, alignment: .leading)
        .background(NativeHelixTheme.background)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(NativeHelixTheme.hairline)
        }
    }
}
