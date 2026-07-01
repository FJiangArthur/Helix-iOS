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
                    VStack(spacing: 12) {
                        DeviceLensRow(
                            side: "Left lens",
                            state: runtime.g1DeviceState.leftLensConnected ? "Connected" : "Waiting",
                            tint: runtime.g1DeviceState.leftLensConnected ? NativeHelixTheme.green : NativeHelixTheme.secondaryInk
                        )
                        DeviceLensRow(
                            side: "Right lens",
                            state: runtime.g1DeviceState.rightLensConnected ? "Connected" : "Waiting",
                            tint: runtime.g1DeviceState.rightLensConnected ? NativeHelixTheme.green : NativeHelixTheme.secondaryInk
                        )
                        DeviceLensRow(
                            side: "HUD packets",
                            state: "\(runtime.g1DeviceState.sentPacketCount) queued",
                            tint: NativeHelixTheme.indigo
                        )
                    }
                }

                NativeSection("HUD controls", subtitle: runtime.g1DeviceState.currentPageSummary) {
                    HStack(spacing: 10) {
                        Button("Previous", action: showPreviousPage)
                            .buttonStyle(NativeHelixSecondaryButtonStyle())

                        Button("Push answer", action: pushAnswer)
                            .buttonStyle(NativeHelixPrimaryButtonStyle())
                            .disabled(runtime.assistantSession.currentAnswer.isEmpty)
                            .opacity(runtime.assistantSession.currentAnswer.isEmpty ? 0.45 : 1)

                        Button("Next", action: showNextPage)
                            .buttonStyle(NativeHelixSecondaryButtonStyle())
                    }
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

private struct DeviceLensRow: View {
    let side: String
    let state: String
    let tint: Color

    var body: some View {
        HStack {
            NativeStatusPill(text: side, tint: tint)
            Spacer()
            Text(state)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(NativeHelixTheme.ink)
        }
    }
}
