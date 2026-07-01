import HelixCore
import HelixRuntime
import SwiftUI

@MainActor
struct NativeSettingsView: View {
    let runtime: HelixRuntimeDependencies

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                NativeSection("Conversation") {
                    VStack(spacing: 12) {
                        Picker("Default mode", selection: modeBinding) {
                            ForEach(ConversationMode.allCases, id: \.self) { mode in
                                Text(mode.nativeTitle).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)

                        Toggle("Auto-detect questions", isOn: autoDetectBinding)
                        Toggle("Auto-answer", isOn: autoAnswerBinding)
                        Toggle("Live fact-check", isOn: factCheckBinding)
                        Toggle("Bitmap HUD", isOn: bitmapHudBinding)

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Max response sentences: \(runtime.settings.maxResponseSentences)")
                                .font(.subheadline.weight(.semibold))
                            Slider(value: sentenceLimitBinding, in: 1...10, step: 1)
                        }
                    }
                    .tint(NativeHelixTheme.teal)
                }

                NativeSection("Runtime") {
                    CompactTagGrid(
                        values: [
                            runtime.settings.transcriptionBackend.nativeTitle,
                            runtime.settings.webSearchMode.nativeTitle,
                            runtime.assistantSession.memorySummary,
                            runtime.assistantSession.latencySummary
                        ]
                    )
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
