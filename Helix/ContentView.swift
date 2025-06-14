//
//  ContentView.swift
//  Helix
//
//

import SwiftUI

struct ContentView: View {
    @StateObject private var appCoordinator = AppCoordinator()
    @State private var hasError = false
    @State private var errorMessage = ""
    
    var body: some View {
        if hasError {
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
                
                Button("Try Again") {
                    hasError = false
                    // Could trigger a re-initialization here
                }
                .buttonStyle(.borderedProminent)
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
                    errorMessage = "Some services failed to initialize. This is normal in simulator."
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
