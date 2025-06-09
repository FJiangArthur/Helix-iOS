import SwiftUI

struct ConversationView: View {
    @EnvironmentObject var coordinator: AppCoordinator
    @State private var showingSpeakerSheet = false
    @State private var isAutoScrollEnabled = true
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Status Bar
                StatusBarView()
                    .padding(.horizontal)
                    .padding(.top, 8)
                
                Divider()
                
                // Conversation Messages
                ConversationScrollView(isAutoScrollEnabled: $isAutoScrollEnabled)
                
                Divider()
                
                // Control Panel
                ControlPanelView(showingSpeakerSheet: $showingSpeakerSheet)
                    .padding()
            }
            .navigationTitle("Live Conversation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("Add Speaker") {
                            showingSpeakerSheet = true
                        }
                        
                        Button("Clear Conversation") {
                            coordinator.clearConversation()
                        }
                        
                        Button("Export Conversation") {
                            exportConversation()
                        }
                        
                        Toggle("Auto-scroll", isOn: $isAutoScrollEnabled)
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .sheet(isPresented: $showingSpeakerSheet) {
            AddSpeakerSheet()
        }
        .alert("Error", isPresented: .constant(coordinator.errorMessage != nil)) {
            Button("OK") {
                coordinator.errorMessage = nil
            }
        } message: {
            Text(coordinator.errorMessage ?? "")
        }
    }
    
    private func exportConversation() {
        let export = coordinator.exportConversation()
        // TODO: Implement export functionality
        print("Exporting conversation: \(export)")
    }
}

struct StatusBarView: View {
    @EnvironmentObject var coordinator: AppCoordinator
    
    var body: some View {
        HStack {
            // Recording Status
            HStack(spacing: 8) {
                Circle()
                    .fill(coordinator.isRecording ? .red : .gray)
                    .frame(width: 8, height: 8)
                    .scaleEffect(coordinator.isRecording ? 1.2 : 1.0)
                    .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: coordinator.isRecording)
                
                Text(coordinator.isRecording ? "Recording" : "Stopped")
                    .font(.caption)
                    .foregroundColor(coordinator.isRecording ? .red : .secondary)
            }
            
            Spacer()
            
            // Glasses Connection
            HStack(spacing: 4) {
                Image(systemName: coordinator.isConnectedToGlasses ? "eyeglasses" : "eyeglasses.slash")
                    .foregroundColor(coordinator.isConnectedToGlasses ? .green : .gray)
                
                if coordinator.isConnectedToGlasses {
                    BatteryIndicator(level: coordinator.batteryLevel)
                }
            }
            .font(.caption)
            
            Spacer()
            
            // Stats
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(coordinator.messageCount) messages")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Text(formatDuration(coordinator.conversationDuration))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

struct BatteryIndicator: View {
    let level: Float
    
    var body: some View {
        HStack(spacing: 2) {
            RoundedRectangle(cornerRadius: 1)
                .stroke(batteryColor, lineWidth: 1)
                .frame(width: 16, height: 8)
                .overlay(
                    RoundedRectangle(cornerRadius: 0.5)
                        .fill(batteryColor)
                        .frame(width: CGFloat(level) * 14, height: 6)
                        .offset(x: (CGFloat(level) - 1) * 7)
                )
            
            RoundedRectangle(cornerRadius: 0.5)
                .fill(batteryColor)
                .frame(width: 2, height: 4)
        }
    }
    
    private var batteryColor: Color {
        switch level {
        case 0.5...1.0: return .green
        case 0.2..<0.5: return .orange
        default: return .red
        }
    }
}

struct ConversationScrollView: View {
    @EnvironmentObject var coordinator: AppCoordinator
    @Binding var isAutoScrollEnabled: Bool
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(coordinator.currentConversation, id: \.id) { message in
                        MessageBubble(message: message)
                            .id(message.id)
                    }
                    
                    if coordinator.isProcessing {
                        ProcessingIndicator()
                    }
                }
                .padding()
            }
            .onChange(of: coordinator.currentConversation.count) { _ in
                if isAutoScrollEnabled, let lastMessage = coordinator.currentConversation.last {
                    withAnimation(.easeOut(duration: 0.3)) {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
        }
    }
}

struct MessageBubble: View {
    @EnvironmentObject var coordinator: AppCoordinator
    let message: ConversationMessage
    
    private var speaker: Speaker? {
        coordinator.speakers.first { $0.id == message.speakerId }
    }
    
    private var isCurrentUser: Bool {
        speaker?.isCurrentUser ?? false
    }
    
    var body: some View {
        HStack {
            if isCurrentUser {
                Spacer()
            }
            
            VStack(alignment: isCurrentUser ? .trailing : .leading, spacing: 4) {
                // Speaker name and timestamp
                HStack {
                    Text(speaker?.name ?? "Unknown Speaker")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text(formatTimestamp(message.timestamp))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                // Message content
                Text(message.content)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(isCurrentUser ? Color.blue : Color(.systemGray5))
                    .foregroundColor(isCurrentUser ? .white : .primary)
                    .cornerRadius(16)
                
                // Confidence indicator
                if message.confidence > 0 {
                    ConfidenceIndicator(confidence: message.confidence)
                }
            }
            .frame(maxWidth: 280, alignment: isCurrentUser ? .trailing : .leading)
            
            if !isCurrentUser {
                Spacer()
            }
        }
    }
    
    private func formatTimestamp(_ timestamp: TimeInterval) -> String {
        let date = Date(timeIntervalSince1970: timestamp)
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct ConfidenceIndicator: View {
    let confidence: Float
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<5, id: \.self) { index in
                Circle()
                    .fill(index < Int(confidence * 5) ? confidenceColor : Color.gray.opacity(0.3))
                    .frame(width: 4, height: 4)
            }
        }
    }
    
    private var confidenceColor: Color {
        switch confidence {
        case 0.8...1.0: return .green
        case 0.6..<0.8: return .orange
        default: return .red
        }
    }
}

struct ProcessingIndicator: View {
    @State private var isAnimating = false
    
    var body: some View {
        HStack {
            Spacer()
            
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 8, height: 8)
                        .scaleEffect(isAnimating ? 1.2 : 0.8)
                        .animation(
                            Animation.easeInOut(duration: 0.6)
                                .repeatForever()
                                .delay(Double(index) * 0.2),
                            value: isAnimating
                        )
                }
                
                Text("Processing...")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.systemGray6))
            .cornerRadius(16)
            
            Spacer()
        }
        .onAppear {
            isAnimating = true
        }
    }
}

struct ControlPanelView: View {
    @EnvironmentObject var coordinator: AppCoordinator
    @Binding var showingSpeakerSheet: Bool
    
    var body: some View {
        VStack(spacing: 16) {
            // Main record button
            Button(action: toggleRecording) {
                ZStack {
                    Circle()
                        .fill(coordinator.isRecording ? Color.red : Color.blue)
                        .frame(width: 80, height: 80)
                        .scaleEffect(coordinator.isRecording ? 1.1 : 1.0)
                        .animation(.easeInOut(duration: 0.3), value: coordinator.isRecording)
                    
                    Image(systemName: coordinator.isRecording ? "stop.fill" : "mic.fill")
                        .font(.title)
                        .foregroundColor(.white)
                }
            }
            .disabled(coordinator.isProcessing)
            
            // Secondary controls
            HStack(spacing: 20) {
                Button("Speakers") {
                    showingSpeakerSheet = true
                }
                .buttonStyle(.bordered)
                
                Button("Clear") {
                    coordinator.clearConversation()
                }
                .buttonStyle(.bordered)
                .disabled(coordinator.currentConversation.isEmpty)
                
                Button("Connect") {
                    if coordinator.isConnectedToGlasses {
                        coordinator.disconnectFromGlasses()
                    } else {
                        coordinator.connectToGlasses()
                    }
                }
                .buttonStyle(.bordered)
            }
        }
    }
    
    private func toggleRecording() {
        if coordinator.isRecording {
            coordinator.stopConversation()
        } else {
            coordinator.startConversation()
        }
    }
}

struct AddSpeakerSheet: View {
    @EnvironmentObject var coordinator: AppCoordinator
    @Environment(\.dismiss) private var dismiss
    @State private var speakerName = ""
    @State private var isCurrentUser = false
    
    var body: some View {
        NavigationView {
            Form {
                Section("Speaker Information") {
                    TextField("Name", text: $speakerName)
                    
                    Toggle("This is me", isOn: $isCurrentUser)
                }
                
                Section("Current Speakers") {
                    ForEach(coordinator.speakers, id: \.id) { speaker in
                        HStack {
                            Text(speaker.name ?? "Unknown")
                            
                            Spacer()
                            
                            if speaker.isCurrentUser {
                                Text("You")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Manage Speakers")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        coordinator.addSpeaker(name: speakerName, isCurrentUser: isCurrentUser)
                        dismiss()
                    }
                    .disabled(speakerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

#Preview {
    ConversationView()
        .environmentObject(AppCoordinator())
}