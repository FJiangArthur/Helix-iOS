//
//  ContentView.swift
//  Helix
//
//

import SwiftUI

struct ContentView: View {
    @StateObject private var appCoordinator = AppCoordinator()
    
    var body: some View {
        NavigationStack {
            MainTabView()
                .environmentObject(appCoordinator)
        }
    }
}

#Preview {
    ContentView()
}
