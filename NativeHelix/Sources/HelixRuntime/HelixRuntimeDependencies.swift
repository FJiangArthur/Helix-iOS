import Foundation
import HelixAI
import HelixConversation
import HelixCore
import HelixPersistence
import Observation

@MainActor
@Observable
public final class HelixRuntimeDependencies {
    public let settingsManager: NativeSettingsManager
    public let assistantSession: NativeAssistantSessionState
    public let g1DeviceState: NativeG1DeviceState
    public let sessionArchive: NativeSessionArchiveState
    public let knowledgeLibrary: NativeKnowledgeLibraryState
    public let insightCoordinator = InsightCoordinator()
    public private(set) var settings: HelixSettings
    public private(set) var providerReadiness: [ProviderReadiness]

    public init(
        settingsManager: NativeSettingsManager = NativeSettingsManager(
            settingsStore: InMemorySettingsStore(),
            secretStore: InMemorySecretStore()
        ),
        assistantSession: NativeAssistantSessionState? = nil,
        g1DeviceState: NativeG1DeviceState? = nil,
        sessionArchive: NativeSessionArchiveState? = nil,
        knowledgeLibrary: NativeKnowledgeLibraryState? = nil,
        settings: HelixSettings = HelixSettings(),
        providerReadiness: [ProviderReadiness] = []
    ) {
        self.settingsManager = settingsManager
        self.assistantSession = assistantSession ?? NativeAssistantSessionState(
            engine: NativeConversationEngine(
                answerProvider: DeterministicAnswerProvider(),
                conversationStore: InMemoryConversationStore(),
                knowledgeStore: InMemoryProjectKnowledgeStore()
            )
        )
        self.g1DeviceState = g1DeviceState ?? NativeG1DeviceState()
        self.sessionArchive = sessionArchive ?? NativeSessionArchiveState()
        self.knowledgeLibrary = knowledgeLibrary ?? NativeKnowledgeLibraryState()
        self.settings = settings
        self.providerReadiness = providerReadiness
    }

    public static func nativePersistent(
        isStoredInMemoryOnly: Bool = false,
        userDefaults: UserDefaults = .standard,
        settingsKey: String = "helix.native.settings",
        keychainService: String = Bundle.main.bundleIdentifier ?? "com.artjiang.helix.native"
    ) throws -> HelixRuntimeDependencies {
        let container = try HelixSwiftDataSchema.makeModelContainer(isStoredInMemoryOnly: isStoredInMemoryOnly)
        let knowledgeStore = SwiftDataKnowledgeLibraryStore(container: container)
        let settingsManager = NativeSettingsManager(
            settingsStore: UserDefaultsSettingsStore(userDefaults: userDefaults, settingsKey: settingsKey),
            secretStore: KeychainSecretStore(service: keychainService)
        )
        return HelixRuntimeDependencies(
            settingsManager: settingsManager,
            assistantSession: NativeAssistantSessionState(
                engine: NativeConversationEngine(
                    answerProvider: DeterministicAnswerProvider(),
                    conversationStore: InMemoryConversationStore(),
                    knowledgeStore: knowledgeStore
                )
            ),
            sessionArchive: NativeSessionArchiveState(
                store: SwiftDataSessionArchiveStore(container: container)
            ),
            knowledgeLibrary: NativeKnowledgeLibraryState(
                store: knowledgeStore
            )
        )
    }

    public func refreshSettings() async {
        settings = await settingsManager.settings()
        providerReadiness = await settingsManager.providerReadiness()
        await sessionArchive.refresh()
        await knowledgeLibrary.refresh()
        await syncEngine()
    }

    public func selectProvider(_ provider: LlmProviderKind) async {
        settings = await settingsManager.selectProvider(provider)
        providerReadiness = await settingsManager.providerReadiness()
        await syncEngine()
    }

    public func updateMaxResponseSentences(_ value: Int) async {
        settings = await settingsManager.updateConversationControls(maxResponseSentences: value)
        await syncEngine()
    }

    public func setAutoDetectQuestions(_ isEnabled: Bool) async {
        settings = await settingsManager.updateConversationControls(autoDetectQuestions: isEnabled)
        await syncEngine()
    }

    public func setAutoAnswer(_ isEnabled: Bool) async {
        settings = await settingsManager.updateConversationControls(autoAnswer: isEnabled)
        await syncEngine()
    }

    public func setLiveFactCheckEnabled(_ isEnabled: Bool) async {
        settings = await settingsManager.updateConversationControls(liveFactCheckEnabled: isEnabled)
        await syncEngine()
    }

    public func updateTranscription(backend: TranscriptionBackend, model: String) async {
        settings = await settingsManager.updateTranscription(backend: backend, model: model)
        await syncEngine()
    }

    public func updateHudRenderPath(_ renderPath: HudRenderPath) async {
        settings = await settingsManager.updateHudRenderPath(renderPath)
        await syncEngine()
    }

    public func updateWebSearchMode(_ mode: WebSearchMode) async {
        settings = await settingsManager.updateWebSearchMode(mode)
        await syncEngine()
    }

    public func setEvalGateEnabled(_ isEnabled: Bool) async {
        settings = await settingsManager.setEvalGateEnabled(isEnabled)
    }

    public func updateActiveSkill(_ value: String) async {
        settings = await settingsManager.updateActiveSkill(value)
        await syncEngine()
    }

    public func upsertCustomSkill(_ skill: ActiveSkill) async {
        settings = await settingsManager.upsertCustomSkill(skill)
        await syncEngine()
    }

    public func setApiKey(_ apiKey: String?, for provider: LlmProviderKind) async {
        await settingsManager.setProviderApiKey(apiKey, for: provider)
        providerReadiness = await settingsManager.providerReadiness()
        await syncEngine()
    }

    public func apiKey(for provider: LlmProviderKind) async -> String? {
        await settingsManager.apiKey(for: provider)
    }

    public func updateGlassesDisplay(
        headUpAngle: Int? = nil,
        displayHeight: Int? = nil,
        displayDepth: Int? = nil,
        brightness: Int? = nil,
        autoBrightness: Bool? = nil,
        glassesNotificationsEnabled: Bool? = nil,
        dashboardEnabled: Bool? = nil
    ) async {
        settings = await settingsManager.updateGlassesDisplay(
            headUpAngle: headUpAngle,
            displayHeight: displayHeight,
            displayDepth: displayDepth,
            brightness: brightness,
            autoBrightness: autoBrightness,
            glassesNotificationsEnabled: glassesNotificationsEnabled,
            dashboardEnabled: dashboardEnabled
        )
    }

    public func setInsightsEnabled(_ isEnabled: Bool) async {
        settings = await settingsManager.setInsightsEnabled(isEnabled)
        await syncEngine()
    }

    /// Pushes the persisted settings and a freshly built answer provider into
    /// the conversation engine so UI-visible configuration actually drives
    /// pipeline behavior. Without a stored API key the deterministic provider
    /// is used, keeping the pipeline usable offline and in tests.
    public func syncEngine() async {
        await assistantSession.updateEngineSettings(settings)
        let apiKey = await settingsManager.apiKey(for: settings.llmProvider)
        let factory = HelixAnswerProviderFactory()
        let provider = factory.makeProvider(settings: settings, apiKey: apiKey)
        await assistantSession.setAnswerProvider(provider)

        // Insights get their own lightweight provider instance so proactive
        // analysis never contends with in-flight answer streaming.
        insightCoordinator.setEnabled(settings.insightsEnabled)
        if settings.insightsEnabled {
            var lightSettings = settings
            if let lightModel = settings.activeProviderConfiguration?.modelSelection.lightModel {
                lightSettings.llmModel = lightModel
            }
            insightCoordinator.setProvider(
                factory.makeProvider(settings: lightSettings, apiKey: apiKey),
                maxResponseSentences: 1
            )
        } else {
            insightCoordinator.setProvider(nil)
        }
    }

    public func updateActiveProviderModels(
        smartModel: String,
        lightModel: String,
        realtimeModel: String? = nil,
        transcriptionModel: String? = nil
    ) async {
        await updateProviderModels(
            provider: settings.llmProvider,
            smartModel: smartModel,
            lightModel: lightModel,
            realtimeModel: realtimeModel,
            transcriptionModel: transcriptionModel
        )
    }

    /// Updates the model selection for any provider (not just the active one),
    /// then re-syncs the engine so a change to the live provider takes effect
    /// immediately.
    public func updateProviderModels(
        provider: LlmProviderKind,
        smartModel: String,
        lightModel: String,
        realtimeModel: String? = nil,
        transcriptionModel: String? = nil
    ) async {
        settings = await settingsManager.updateProviderModels(
            provider: provider,
            smartModel: smartModel,
            lightModel: lightModel,
            realtimeModel: realtimeModel,
            transcriptionModel: transcriptionModel
        )
        providerReadiness = await settingsManager.providerReadiness()
        await syncEngine()
    }

    /// Fetches the selectable chat model IDs for `provider`. Uses `overrideKey`
    /// when provided (e.g. a key the user just typed but hasn't saved), else
    /// the stored key; falls back to a curated list when neither works.
    public func availableModels(for provider: LlmProviderKind, overrideKey: String? = nil) async -> [String] {
        let trimmedOverride = overrideKey?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let apiKey = trimmedOverride.isEmpty ? await settingsManager.apiKey(for: provider) : trimmedOverride
        return await ProviderModelCatalog().models(for: provider, apiKey: apiKey)
    }

    public var activeProviderName: String {
        settings.activeProviderConfiguration?.displayName ?? settings.llmProvider.runtimeDisplayName
    }

    public var activeProviderReadiness: ProviderReadiness? {
        providerReadiness.first { $0.provider == settings.llmProvider }
    }

    public var providerStatusRows: [String] {
        providerReadiness.map { readiness in
            let keyStatus = readiness.hasApiKey ? "key set" : "missing key"
            let enabledStatus = readiness.isEnabled ? "enabled" : "disabled"
            return "\(readiness.provider.runtimeDisplayName): \(enabledStatus), \(keyStatus), \(readiness.smartModel)"
        }
    }
}

private extension LlmProviderKind {
    var runtimeDisplayName: String {
        HelixSettings.defaultProviderConfigurations.first { $0.kind == self }?.displayName ?? rawValue
    }
}

public struct HelixNativeEvalGateHarness: Sendable {
    private let runner: NativeConversationEvalRunner
    private let writer: EvalReportWriter

    public init(
        runner: NativeConversationEvalRunner = NativeConversationEvalRunner(),
        writer: EvalReportWriter = EvalReportWriter()
    ) {
        self.runner = runner
        self.writer = writer
    }

    public func runAndWriteReport(
        outputDirectory: URL,
        gitSha: String = "unknown",
        simulatorUdid: String = "local"
    ) async throws -> EvalReportArtifact {
        let report = await runner.run(gitSha: gitSha, simulatorUdid: simulatorUdid)
        return try writer.write(report, to: outputDirectory)
    }
}
