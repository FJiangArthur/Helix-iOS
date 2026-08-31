import HelixG1
import HelixRuntime
import SwiftUI

@MainActor
struct NativeDeviceView: View {
    let runtime: HelixRuntimeDependencies
    let bridge: HelixNativeBridge

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                NativeSection("Discovery", subtitle: bridge.connectionPhase) {
                    DeviceDiscoveryPanel(bridge: bridge)
                }

                NativeSection("Glasses display", subtitle: "Applied live when connected") {
                    GlassesDisplayControls(runtime: runtime, bridge: bridge)
                }

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
                title: "Battery",
                value: runtime.g1DeviceState.batterySummary,
                symbolName: runtime.g1DeviceState.isCharging ? "battery.100.bolt" : "battery.75",
                tint: NativeHelixTheme.green
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
        bridge.presentToGlasses(runtime.assistantSession.currentAnswer)
    }

    private func showNextPage() {
        runtime.g1DeviceState.handleTouchpad(notifyIndex: 1, side: .right)
    }
}

@MainActor
private struct GlassesDisplayControls: View {
    let runtime: HelixRuntimeDependencies
    let bridge: HelixNativeBridge

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            GlassesSliderRow(
                title: "Head-up angle",
                symbolName: "angle",
                value: runtime.settings.headUpAngle,
                range: 0...60,
                unit: "°"
            ) { newValue in
                applyChange(headUpAngle: newValue)
            }

            GlassesStepperRow(
                title: "Display height",
                symbolName: "arrow.up.and.down",
                value: runtime.settings.displayHeight,
                range: 0...8
            ) { newValue in
                applyChange(displayHeight: newValue)
            }

            GlassesStepperRow(
                title: "Display depth",
                symbolName: "arrow.forward.to.line",
                value: runtime.settings.displayDepth,
                range: 0...9
            ) { newValue in
                applyChange(displayDepth: newValue)
            }

            GlassesSliderRow(
                title: "Brightness",
                symbolName: "sun.max",
                value: runtime.settings.brightness,
                range: 0...63,
                unit: "",
                isDisabled: runtime.settings.autoBrightness
            ) { newValue in
                applyChange(brightness: newValue)
            }

            GlassesToggleRow(
                title: "Auto brightness",
                symbolName: "circle.lefthalf.filled",
                isOn: runtime.settings.autoBrightness
            ) { newValue in
                applyChange(autoBrightness: newValue)
            }

            GlassesToggleRow(
                title: "Notifications on glasses",
                symbolName: "bell.badge",
                isOn: runtime.settings.glassesNotificationsEnabled
            ) { newValue in
                Task { await runtime.updateGlassesDisplay(glassesNotificationsEnabled: newValue) }
            }

            GlassesToggleRow(
                title: "Head-up dashboard",
                symbolName: "rectangle.topthird.inset.filled",
                isOn: runtime.settings.dashboardEnabled
            ) { newValue in
                Task { await runtime.updateGlassesDisplay(dashboardEnabled: newValue) }
            }
        }
        .tint(NativeHelixTheme.teal)
    }

    private func applyChange(
        headUpAngle: Int? = nil,
        displayHeight: Int? = nil,
        displayDepth: Int? = nil,
        brightness: Int? = nil,
        autoBrightness: Bool? = nil
    ) {
        Task {
            await runtime.updateGlassesDisplay(
                headUpAngle: headUpAngle,
                displayHeight: displayHeight,
                displayDepth: displayDepth,
                brightness: brightness,
                autoBrightness: autoBrightness
            )
            if bridge.isGlassesConnected {
                await bridge.applyGlassesDisplaySettings(runtime.settings)
            }
        }
    }
}

private struct GlassesSliderRow: View {
    let title: String
    let symbolName: String
    let value: Int
    let range: ClosedRange<Int>
    let unit: String
    var isDisabled = false
    let onCommit: (Int) -> Void

    @State private var draft: Double?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: symbolName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(NativeHelixTheme.teal)
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(NativeHelixTheme.secondaryInk)
                Spacer()
                Text("\(Int(draft ?? Double(value)))\(unit)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(NativeHelixTheme.ink)
            }
            Slider(
                value: Binding(
                    get: { draft ?? Double(value) },
                    set: { draft = $0 }
                ),
                in: Double(range.lowerBound)...Double(range.upperBound),
                step: 1
            ) { isEditing in
                if !isEditing, let draft {
                    onCommit(Int(draft))
                    self.draft = nil
                }
            }
            .disabled(isDisabled)
            .opacity(isDisabled ? 0.4 : 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
    }
}

private struct GlassesStepperRow: View {
    let title: String
    let symbolName: String
    let value: Int
    let range: ClosedRange<Int>
    let onCommit: (Int) -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: symbolName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(NativeHelixTheme.indigo)
                .frame(width: 22, height: 22)
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(NativeHelixTheme.ink)
            Spacer(minLength: 10)
            Stepper(
                value: Binding(get: { value }, set: { onCommit($0) }),
                in: range
            ) {
                Text("\(value)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(NativeHelixTheme.ink)
                    .frame(minWidth: 24, alignment: .trailing)
            }
            .fixedSize()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
    }
}

private struct GlassesToggleRow: View {
    let title: String
    let symbolName: String
    let isOn: Bool
    let onChange: (Bool) -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: symbolName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(NativeHelixTheme.amber)
                .frame(width: 22, height: 22)
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(NativeHelixTheme.ink)
            Spacer(minLength: 10)
            Toggle(title, isOn: Binding(get: { isOn }, set: { onChange($0) }))
                .labelsHidden()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
    }
}

@MainActor
private struct DeviceDiscoveryPanel: View {
    let bridge: HelixNativeBridge

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                NativeStatusPill(
                    text: bridge.isScanning ? "Scanning" : "Idle",
                    tint: bridge.isScanning ? NativeHelixTheme.green : NativeHelixTheme.secondaryInk
                )
                Spacer(minLength: 0)

                if bridge.isGlassesConnected {
                    Button(action: bridge.disconnect) {
                        Label("Disconnect", systemImage: "xmark.circle")
                            .font(.subheadline.weight(.semibold))
                    }
                    .buttonStyle(.bordered)
                    .tint(NativeHelixTheme.amber)
                } else {
                    Button(action: toggleScan) {
                        Label(
                            bridge.isScanning ? "Stop scan" : "Scan for glasses",
                            systemImage: bridge.isScanning ? "stop.circle" : "dot.radiowaves.left.and.right"
                        )
                        .font(.subheadline.weight(.semibold))
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(NativeHelixTheme.teal)
                }
            }

            if !bridge.bluetoothError.isEmpty {
                Text(bridge.bluetoothError)
                    .font(.footnote)
                    .foregroundStyle(NativeHelixTheme.amber)
            }

            if bridge.discoveredPairs.isEmpty {
                Text(bridge.isScanning
                    ? "Looking for Even G1 glasses nearby…"
                    : "Tap Scan to discover Even G1 glasses. Both lenses must be out of the case.")
                    .font(.footnote)
                    .foregroundStyle(NativeHelixTheme.secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                VStack(spacing: 0) {
                    ForEach(bridge.discoveredPairs) { pair in
                        DiscoveredPairRow(pair: pair) {
                            bridge.connect(to: pair)
                        }
                        if pair.id != bridge.discoveredPairs.last?.id {
                            Divider().padding(.leading, 32)
                        }
                    }
                }
            }
        }
    }

    private func toggleScan() {
        if bridge.isScanning {
            bridge.stopScan()
        } else {
            bridge.startScan()
        }
    }
}

private struct DiscoveredPairRow: View {
    let pair: DiscoveredGlassesPair
    let connectAction: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "eyeglasses")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(NativeHelixTheme.indigo)
                .frame(width: 22, height: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(pair.displayName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(NativeHelixTheme.ink)
                Text(pair.signalSummary)
                    .font(.caption)
                    .foregroundStyle(NativeHelixTheme.secondaryInk)
            }
            Spacer(minLength: 10)
            Button("Connect", action: connectAction)
                .buttonStyle(.borderedProminent)
                .tint(NativeHelixTheme.teal)
                .font(.caption.weight(.semibold))
        }
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
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
