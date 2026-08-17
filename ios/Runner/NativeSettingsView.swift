import HelixCore
import HelixRuntime
import SwiftUI

@MainActor
struct NativeSettingsView: View {
    let runtime: HelixRuntimeDependencies
    @State private var keyEntryProvider: ProviderConfiguration?
    @State private var isEditingCustomSkill = false

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

                NativeSection("Assistant skill", subtitle: runtime.settings.activeSkill.label) {
                    SkillConfigurationPanel(
                        runtime: runtime,
                        isEditingCustomSkill: $isEditingCustomSkill
                    )
                }

                NativeSection("AI providers", subtitle: "Tap a provider to set its API key") {
                    VStack(spacing: 0) {
                        ForEach(runtime.settings.providers) { provider in
                            Button {
                                keyEntryProvider = provider
                            } label: {
                                ProviderRow(
                                    provider: providerRow(for: provider),
                                    isActive: provider.kind == runtime.settings.llmProvider
                                )
                            }
                            .buttonStyle(.plain)
                            if provider.kind != runtime.settings.providers.last?.kind {
                                Divider().padding(.leading, 34)
                            }
                        }
                    }
                }
            }
            .padding(16)
        }
        .scrollContentBackground(.hidden)
        .sheet(item: $keyEntryProvider) { provider in
            ProviderKeySheet(runtime: runtime, provider: provider)
        }
        .sheet(isPresented: $isEditingCustomSkill) {
            CustomSkillSheet(runtime: runtime)
        }
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

    private var insightsBinding: Binding<Bool> {
        Binding(
            get: { runtime.settings.insightsEnabled },
            set: { newValue in Task { await runtime.setInsightsEnabled(newValue) } }
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
                id: "insights",
                title: "Real-time insights",
                detail: "Proactive context while you talk (experimental).",
                symbolName: "lightbulb.max",
                tint: NativeHelixTheme.indigo,
                binding: insightsBinding
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

    private func providerRow(for provider: ProviderConfiguration) -> NativeProviderRow {
        let readiness = runtime.providerReadiness.first { $0.provider == provider.kind }
        return NativeProviderRow(
            id: provider.kind.rawValue,
            name: provider.displayName,
            model: provider.modelSelection.smartModel,
            status: readiness?.hasApiKey == true ? "Key set" : "Needs key",
            tint: readiness?.hasApiKey == true ? NativeHelixTheme.green : NativeHelixTheme.amber
        )
    }
}

@MainActor
private struct SkillConfigurationPanel: View {
    let runtime: HelixRuntimeDependencies
    @Binding var isEditingCustomSkill: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "wand.and.stars")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(NativeHelixTheme.indigo)
                    .frame(width: 22, height: 22)

                Picker("Active skill", selection: activeSkillBinding) {
                    ForEach(runtime.settings.selectableActiveSkills) { skill in
                        Text(skill.label).tag(skill.value)
                    }
                }
                .pickerStyle(.menu)
                .tint(NativeHelixTheme.ink)

                Spacer(minLength: 0)

                Button {
                    isEditingCustomSkill = true
                } label: {
                    Label("Custom", systemImage: "plus")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.bordered)
                .tint(NativeHelixTheme.teal)
            }

            Text(runtime.settings.activeSkill.prompt)
                .font(.footnote)
                .foregroundStyle(NativeHelixTheme.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var activeSkillBinding: Binding<String> {
        Binding(
            get: { runtime.settings.activeSkillID },
            set: { newValue in Task { await runtime.updateActiveSkill(newValue) } }
        )
    }
}

@MainActor
private struct CustomSkillSheet: View {
    let runtime: HelixRuntimeDependencies
    @Environment(\.dismiss) private var dismiss
    @State private var label = ""
    @State private var prompt = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("e.g. Sales Coaching", text: $label)
                }
                Section("System prompt") {
                    TextField(
                        "How should Helix answer while this skill is active?",
                        text: $prompt,
                        axis: .vertical
                    )
                    .lineLimit(4...10)
                }
                Section {
                    Text("The skill is added to the picker and activated immediately.")
                        .font(.footnote)
                        .foregroundStyle(NativeHelixTheme.secondaryInk)
                }
            }
            .navigationTitle("Custom skill")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(trimmedLabel.isEmpty || trimmedPrompt.isEmpty)
                }
            }
        }
    }

    private var trimmedLabel: String {
        label.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedPrompt: String {
        prompt.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func save() {
        let slug = trimmedLabel
            .lowercased()
            .replacingOccurrences(of: "[^a-z0-9]+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        guard !slug.isEmpty else { return }

        let skill = ActiveSkill(value: slug, label: trimmedLabel, prompt: trimmedPrompt)
        Task {
            await runtime.upsertCustomSkill(skill)
            await runtime.updateActiveSkill(slug)
            dismiss()
        }
    }
}

@MainActor
private struct ProviderKeySheet: View {
    let runtime: HelixRuntimeDependencies
    let provider: ProviderConfiguration
    @Environment(\.dismiss) private var dismiss
    @State private var apiKey = ""
    @State private var smartModel: String
    @State private var lightModel: String
    @State private var availableModels: [String] = []
    @State private var isLoadingModels = false

    init(runtime: HelixRuntimeDependencies, provider: ProviderConfiguration) {
        self.runtime = runtime
        self.provider = provider
        _smartModel = State(initialValue: provider.modelSelection.smartModel)
        _lightModel = State(initialValue: provider.modelSelection.lightModel)
    }

    private var hasStoredKey: Bool {
        runtime.providerReadiness.first { $0.provider == provider.kind }?.hasApiKey == true
    }

    private var isActiveProvider: Bool {
        runtime.settings.llmProvider == provider.kind
    }

    /// Model list to show: the discovered/fallback set, guaranteeing the
    /// current selections are always present even if discovery omits them.
    private var modelOptions: [String] {
        var options = availableModels
        for model in [smartModel, lightModel] where !model.isEmpty && !options.contains(model) {
            options.insert(model, at: 0)
        }
        return options
    }

    private var modelsChanged: Bool {
        smartModel != provider.modelSelection.smartModel || lightModel != provider.modelSelection.lightModel
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("API key") {
                    SecureField(
                        hasStoredKey ? "Key stored — enter a new key to replace" : "Paste your \(provider.displayName) API key",
                        text: $apiKey
                    )
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                    if hasStoredKey {
                        Button("Remove stored key", role: .destructive) {
                            Task {
                                await runtime.setApiKey(nil, for: provider.kind)
                                dismiss()
                            }
                        }
                    }
                }

                Section {
                    ModelPickerRow(title: "Smart", selection: $smartModel, options: modelOptions)
                    ModelPickerRow(title: "Light", selection: $lightModel, options: modelOptions)
                } header: {
                    HStack {
                        Text("Models")
                        Spacer()
                        if isLoadingModels {
                            ProgressView().controlSize(.mini)
                        } else {
                            Button {
                                Task { await loadModels() }
                            } label: {
                                Label("Refresh", systemImage: "arrow.clockwise")
                                    .labelStyle(.iconOnly)
                            }
                        }
                    }
                } footer: {
                    Text(hasStoredKey
                        ? "Discovered from \(provider.displayName). Tap refresh to re-fetch."
                        : "Add a key to discover live models; showing common defaults.")
                }

                Section {
                    if isActiveProvider {
                        Label("Active provider", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(NativeHelixTheme.green)
                    } else {
                        Button("Use \(provider.displayName) for answers") {
                            Task {
                                await persistKeyIfEntered()
                                await saveModelsIfChanged()
                                await runtime.selectProvider(provider.kind)
                                dismiss()
                            }
                        }
                    }
                }
            }
            .navigationTitle(provider.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(!canSave)
                }
            }
            .task { await loadModels() }
        }
    }

    private var canSave: Bool {
        !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || modelsChanged
    }

    private func loadModels() async {
        isLoadingModels = true
        // Use the just-typed key (if any) so Refresh discovers live models
        // before the key is saved.
        availableModels = await runtime.availableModels(for: provider.kind, overrideKey: apiKey)
        isLoadingModels = false
    }

    private func persistKeyIfEntered() async {
        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return }
        await runtime.setApiKey(key, for: provider.kind)
        apiKey = ""
    }

    private func saveModelsIfChanged() async {
        guard modelsChanged else { return }
        await runtime.updateProviderModels(
            provider: provider.kind,
            smartModel: smartModel,
            lightModel: lightModel
        )
    }

    private func save() {
        Task {
            await persistKeyIfEntered()
            await saveModelsIfChanged()
            dismiss()
        }
    }
}

private struct ModelPickerRow: View {
    let title: String
    @Binding var selection: String
    let options: [String]

    var body: some View {
        Picker(title, selection: $selection) {
            ForEach(options, id: \.self) { model in
                Text(model).tag(model)
            }
        }
        .pickerStyle(.menu)
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
    let isActive: Bool

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(provider.tint)
                .frame(width: 10, height: 10)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(provider.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(NativeHelixTheme.ink)
                    if isActive {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(NativeHelixTheme.green)
                    }
                }
                Text(provider.model)
                    .font(.caption)
                    .foregroundStyle(NativeHelixTheme.secondaryInk)
            }
            Spacer()
            Text(provider.status)
                .font(.caption.weight(.semibold))
                .foregroundStyle(provider.tint)
            Image(systemName: "chevron.right")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(NativeHelixTheme.secondaryInk)
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }
}
