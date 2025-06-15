//
//  ContentView.swift
//  Helix
//
//

import SwiftUI

struct ContentView: View {
    @StateObject private var appCoordinator: AppCoordinator
    @State private var hasError = false
    @State private var errorMessage = ""
    @State private var showDebugLauncher = false
    
    // Initialize with debug configuration if in debug mode
    init() {
        let debugConfig = DebugLauncher.getCurrentConfiguration()
        let coordinator = DebugLauncher.createAppCoordinator(with: debugConfig)
        self._appCoordinator = StateObject(wrappedValue: coordinator)
        
        // Show debug launcher in debug builds with specific environment variable
        self._showDebugLauncher = State(initialValue: ProcessInfo.processInfo.environment["SHOW_DEBUG_LAUNCHER"] == "true")
    }
    
    var body: some View {
        if showDebugLauncher {
            DebugConfigurationView()
        } else if hasError {
            VStack(spacing: 20) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 50))
                    .foregroundColor(.orange)
                
                Text("App Initialization Error")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text(errorMessage)
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .padding()
                
                VStack(spacing: 12) {
                    Button("Try Again") {
                        hasError = false
                        // Could trigger a re-initialization here
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Button("Debug Launcher") {
                        showDebugLauncher = true
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding()
        } else {
            NavigationStack {
                MainTabView()
                    .environmentObject(appCoordinator)
            }
            .onAppear {
                // Test if AppCoordinator initialized successfully
                if appCoordinator.connectionState == .error(.serviceUnavailable) {
                    hasError = true
                    errorMessage = "Some services failed to initialize. Check debug logs for details."
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil {
                        Button("Debug") {
                            showDebugLauncher = true
                        }
                    } else {
                        EmptyView()
                    }
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
