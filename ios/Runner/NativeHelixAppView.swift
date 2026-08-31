import HelixRuntime
import SwiftUI

@MainActor
struct NativeHelixAppView: View {
    @State private var selectedTab = NativeHelixTab.assistant
    @State private var draftQuestion = ""
    @State private var runtime: HelixRuntimeDependencies
    @State private var bridge: HelixNativeBridge

    init(runtime: HelixRuntimeDependencies? = nil) {
        // UI tests need durable conversations/Knowledge across relaunches, but
        // must not inherit or leave API keys in the simulator Keychain. The
        // production path continues to use KeychainSecretStore.
        let usesIsolatedTestSecrets = ProcessInfo.processInfo.arguments.contains("--helix-ui-testing")
        let resolvedRuntime = runtime
            ?? (try? HelixRuntimeDependencies.nativePersistent(
                isStoredInMemoryOnly: false,
                useInMemorySecretStore: usesIsolatedTestSecrets
            ))
            ?? HelixRuntimeDependencies()
        _runtime = State(initialValue: resolvedRuntime)
        _bridge = State(initialValue: HelixNativeBridge(runtime: resolvedRuntime))
    }

    var body: some View {
        ZStack {
            NativeHelixTheme.background.ignoresSafeArea()

            TabView(selection: $selectedTab) {
                ForEach(NativeHelixTab.allCases) { tab in
                    NavigationStack {
                        NativeHelixTabContent(
                            tab: tab,
                            runtime: runtime,
                            bridge: bridge,
                            draftQuestion: $draftQuestion
                        )
                        .navigationTitle(tab.title)
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbarBackground(NativeHelixTheme.surface, for: .navigationBar)
                        .toolbarBackground(.visible, for: .navigationBar)
                    }
                    .tabItem {
                        Label(tab.title, systemImage: tab.symbolName)
                    }
                    .tag(tab)
                }
            }
            .tint(NativeHelixTheme.teal)
        }
        .task {
            bridge.activate()
            await runtime.refreshSettings()
        }
    }
}

@MainActor
private struct NativeHelixTabContent: View {
    let tab: NativeHelixTab
    let runtime: HelixRuntimeDependencies
    let bridge: HelixNativeBridge
    @Binding var draftQuestion: String

    var body: some View {
        Group {
            switch tab {
            case .assistant:
                NativeAssistantView(
                    runtime: runtime,
                    bridge: bridge,
                    draftQuestion: $draftQuestion
                )
            case .device:
                NativeDeviceView(runtime: runtime, bridge: bridge)
            case .sessions:
                NativeSessionsView(runtime: runtime)
            case .knowledge:
                NativeKnowledgeView(runtime: runtime)
            case .settings:
                NativeSettingsView(runtime: runtime)
            }
        }
        .background(NativeHelixTheme.background)
    }
}

#Preview {
    NativeHelixAppView()
}
