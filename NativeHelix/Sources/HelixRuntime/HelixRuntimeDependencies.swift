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
    }

    public func selectProvider(_ provider: LlmProviderKind) async {
        settings = await settingsManager.selectProvider(provider)
        providerReadiness = await settingsManager.providerReadiness()
    }

    public func updateMaxResponseSentences(_ value: Int) async {
        settings = await settingsManager.updateConversationControls(maxResponseSentences: value)
    }

    public func setAutoDetectQuestions(_ isEnabled: Bool) async {
        settings = await settingsManager.updateConversationControls(autoDetectQuestions: isEnabled)
    }

    public func setAutoAnswer(_ isEnabled: Bool) async {
        settings = await settingsManager.updateConversationControls(autoAnswer: isEnabled)
    }

    public func setLiveFactCheckEnabled(_ isEnabled: Bool) async {
        settings = await settingsManager.updateConversationControls(liveFactCheckEnabled: isEnabled)
    }

    public func updateTranscription(backend: TranscriptionBackend, model: String) async {
        settings = await settingsManager.updateTranscription(backend: backend, model: model)
    }

    public func updateHudRenderPath(_ renderPath: HudRenderPath) async {
        settings = await settingsManager.updateHudRenderPath(renderPath)
    }

    public func updateWebSearchMode(_ mode: WebSearchMode) async {
        settings = await settingsManager.updateWebSearchMode(mode)
    }

    public func setEvalGateEnabled(_ isEnabled: Bool) async {
        settings = await settingsManager.setEvalGateEnabled(isEnabled)
    }

    public func updateActiveSkill(_ value: String) async {
        settings = await settingsManager.updateActiveSkill(value)
    }

    public func upsertCustomSkill(_ skill: ActiveSkill) async {
        settings = await settingsManager.upsertCustomSkill(skill)
    }

    public func setApiKey(_ apiKey: String?, for provider: LlmProviderKind) async {
        await settingsManager.setProviderApiKey(apiKey, for: provider)
        providerReadiness = await settingsManager.providerReadiness()
    }

    public func updateActiveProviderModels(
        smartModel: String,
        lightModel: String,
        realtimeModel: String? = nil,
        transcriptionModel: String? = nil
    ) async {
        settings = await settingsManager.updateProviderModels(
            provider: settings.llmProvider,
            smartModel: smartModel,
            lightModel: lightModel,
            realtimeModel: realtimeModel,
            transcriptionModel: transcriptionModel
        )
        providerReadiness = await settingsManager.providerReadiness()
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
