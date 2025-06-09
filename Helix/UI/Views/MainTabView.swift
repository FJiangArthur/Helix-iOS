import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var coordinator: AppCoordinator
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            ConversationView()
                .tabItem {
                    Image(systemName: "waveform.circle")
                    Text("Conversation")
                }
                .tag(0)
            
            AnalysisView()
                .tabItem {
                    Image(systemName: "brain.head.profile")
                    Text("Analysis")
                }
                .tag(1)
            
            GlassesView()
                .tabItem {
                    Image(systemName: "eyeglasses")
                    Text("Glasses")
                }
                .tag(2)
            
            HistoryView()
                .tabItem {
                    Image(systemName: "clock.arrow.circlepath")
                    Text("History")
                }
                .tag(3)
            
            SettingsView()
                .tabItem {
                    Image(systemName: "gearshape")
                    Text("Settings")
                }
                .tag(4)
        }
        .tint(.blue)
    }
}

#Preview {
    MainTabView()
        .environmentObject(AppCoordinator())
}