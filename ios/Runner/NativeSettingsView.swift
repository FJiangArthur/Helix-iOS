import HelixCore
import HelixRuntime
import SwiftUI

@MainActor
struct NativeSettingsView: View {
    let runtime: HelixRuntimeDependencies

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                NativeSection("Conversation", subtitle: conversationSummary) {
                    VStack(spacing: 12) {
                        Picker("Default mode", selection: modeBinding) {
                            ForEach(ConversationMode.allCases, id: \.self) { mode in
                                Text(mode.nativeTitle).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)

                        SettingsToggleList(items: settingToggles)

                        SentenceLimitControl(
                            value: runtime.settings.maxResponseSentences,
                            binding: sentenceLimitBinding
                        )
                    }
                    .tint(NativeHelixTheme.teal)
                }

                NativeSection("AI providers") {
                    VStack(spacing: 0) {
                        ForEach(providerRows) { provider in
                            ProviderRow(provider: provider)
                            if provider.id != providerRows.last?.id {
                                Divider().padding(.leading, 34)
                            }
                        }
                    }
                }
            }
            .padding(16)
        }
        .scrollContentBackground(.hidden)
        .task {
            await runtime.refreshSettings()
        }
    }

    private var modeBinding: Binding<ConversationMode> {
        Binding(
            get: { runtime.assistantSession.mode },
            set: { runtime.assistantSession.setMode($0) }
        )
    }

    private var autoDetectBinding: Binding<Bool> {
        Binding(
            get: { runtime.settings.autoDetectQuestions },
            set: { newValue in Task { await runtime.setAutoDetectQuestions(newValue) } }
        )
    }

    private var autoAnswerBinding: Binding<Bool> {
        Binding(
            get: { runtime.settings.autoAnswer },
            set: { newValue in Task { await runtime.setAutoAnswer(newValue) } }
        )
    }

    private var factCheckBinding: Binding<Bool> {
        Binding(
            get: { runtime.settings.liveFactCheckEnabled },
            set: { newValue in Task { await runtime.setLiveFactCheckEnabled(newValue) } }
        )
    }

    private var bitmapHudBinding: Binding<Bool> {
        Binding(
            get: { runtime.settings.hudRenderPath == .bitmap },
            set: { newValue in Task { await runtime.updateHudRenderPath(newValue ? .bitmap : .text) } }
        )
    }

    private var sentenceLimitBinding: Binding<Double> {
        Binding(
            get: { Double(runtime.settings.maxResponseSentences) },
            set: { newValue in Task { await runtime.updateMaxResponseSentences(Int(newValue)) } }
        )
    }

    private var conversationSummary: String {
        "\(runtime.settings.transcriptionBackend.nativeTitle) - \(runtime.settings.webSearchMode.nativeTitle) search - \(runtime.assistantSession.latencySummary)"
    }

    private var settingToggles: [SettingsToggleItem] {
        [
            SettingsToggleItem(
                id: "auto-detect",
                title: "Auto-detect",
                detail: "Identify questions in live transcripts.",
                symbolName: "questionmark.bubble",
                tint: NativeHelixTheme.indigo,
                binding: autoDetectBinding
            ),
            SettingsToggleItem(
                id: "auto-answer",
                title: "Auto-answer",
                detail: "Generate a response when Helix detects intent.",
                symbolName: "arrow.turn.down.left",
                tint: NativeHelixTheme.green,
                binding: autoAnswerBinding
            ),
            SettingsToggleItem(
                id: "fact-check",
                title: "Fact-check",
                detail: "Verify answers in the background.",
                symbolName: "checkmark.seal",
                tint: NativeHelixTheme.teal,
                binding: factCheckBinding
            ),
            SettingsToggleItem(
                id: "bitmap-hud",
                title: "Bitmap HUD",
                detail: "Render G1 pages as bitmap frames.",
                symbolName: "rectangle.on.rectangle",
                tint: NativeHelixTheme.amber,
                binding: bitmapHudBinding
            )
        ]
    }

    private var providerRows: [NativeProviderRow] {
        runtime.settings.providers.map { provider in
            let readiness = runtime.providerReadiness.first { $0.provider == provider.kind }
            return NativeProviderRow(
                id: provider.kind.rawValue,
                name: provider.displayName,
                model: provider.modelSelection.lightModel,
                status: readiness?.hasApiKey == true ? "Key set" : "Needs key",
                tint: readiness?.hasApiKey == true ? NativeHelixTheme.green : NativeHelixTheme.amber
            )
        }
    }
}

private struct SettingsToggleItem: Identifiable {
    let id: String
    let title: String
    let detail: String
    let symbolName: String
    let tint: Color
    let binding: Binding<Bool>
}

private struct SettingsToggleList: View {
    let items: [SettingsToggleItem]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(items) { item in
                SettingsToggleRow(item: item)
                if item.id != items.last?.id {
                    Divider().padding(.leading, 32)
                }
            }
        }
    }
}

private struct SettingsToggleRow: View {
    let item: SettingsToggleItem

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: item.symbolName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(item.tint)
                .frame(width: 20, height: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(NativeHelixTheme.ink)
                Text(item.detail)
                    .font(.caption)
                    .foregroundStyle(NativeHelixTheme.secondaryInk)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            Spacer(minLength: 0)
            Toggle(item.title, isOn: item.binding)
                .labelsHidden()
        }
        .padding(.vertical, 10)
    }
}

private struct SentenceLimitControl: View {
    let value: Int
    let binding: Binding<Double>

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "text.line.first.and.arrowtriangle.forward")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(NativeHelixTheme.teal)
                Text("Max response sentences")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(NativeHelixTheme.secondaryInk)
                Spacer()
                Text("\(value)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(NativeHelixTheme.ink)
            }
            Slider(value: binding, in: 1...10, step: 1)
        }
    }
}

private struct ProviderRow: View {
    let provider: NativeProviderRow

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(provider.tint)
                .frame(width: 10, height: 10)
            VStack(alignment: .leading, spacing: 3) {
                Text(provider.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(NativeHelixTheme.ink)
                Text(provider.model)
                    .font(.caption)
                    .foregroundStyle(NativeHelixTheme.secondaryInk)
            }
            Spacer()
            Text(provider.status)
                .font(.caption.weight(.semibold))
                .foregroundStyle(provider.tint)
        }
        .padding(.vertical, 10)
    }
}
