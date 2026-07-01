import SwiftUI

struct NativeHelixAppView: View {
    @State private var selectedTab = NativeHelixTab.assistant
    @State private var selectedMode = NativeConversationMode.general
    @State private var isListening = false
    @State private var draftQuestion = ""

    var body: some View {
        ZStack {
            NativeHelixTheme.background.ignoresSafeArea()

            TabView(selection: $selectedTab) {
                ForEach(NativeHelixTab.allCases) { tab in
                    NavigationStack {
                        NativeHelixTabContent(
                            tab: tab,
                            selectedMode: $selectedMode,
                            isListening: $isListening,
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
    }
}

private struct NativeHelixTabContent: View {
    let tab: NativeHelixTab
    @Binding var selectedMode: NativeConversationMode
    @Binding var isListening: Bool
    @Binding var draftQuestion: String

    var body: some View {
        Group {
            switch tab {
            case .assistant:
                NativeAssistantView(
                    selectedMode: $selectedMode,
                    isListening: $isListening,
                    draftQuestion: $draftQuestion
                )
            case .device:
                NativeDeviceView()
            case .sessions:
                NativeSessionsView()
            case .knowledge:
                NativeKnowledgeView()
            case .settings:
                NativeSettingsView(selectedMode: $selectedMode)
            }
        }
        .background(NativeHelixTheme.background)
    }
}

#Preview {
    NativeHelixAppView()
}
