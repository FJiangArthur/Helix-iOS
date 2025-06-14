import SwiftUI

struct HistoryView: View {
    @EnvironmentObject var coordinator: AppCoordinator
    @State private var searchText = ""
    @State private var selectedConversation: ConversationExport?
    @State private var showingExportSheet = false
    
    // Mock conversation history for demo
    @State private var conversationHistory: [ConversationExport] = []
    
    var filteredConversations: [ConversationExport] {
        if searchText.isEmpty {
            return conversationHistory
        } else {
            return conversationHistory.filter { conversation in
                conversation.messages.contains { message in
                    message.content.localizedCaseInsensitiveContains(searchText)
                }
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack {
                if conversationHistory.isEmpty {
                    EmptyHistoryView()
                } else {
                    ConversationHistoryList(
                        conversations: filteredConversations,
                        selectedConversation: $selectedConversation,
                        showingExportSheet: $showingExportSheet
                    )
                }
            }
            .navigationTitle("History")
            .searchable(text: $searchText, prompt: "Search conversations")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("Export Current Session") {
                            exportCurrentSession()
                        }
                        .disabled(coordinator.currentConversation.isEmpty)
                        
                        Button("Clear History") {
                            clearHistory()
                        }
                        .disabled(conversationHistory.isEmpty)
                        
                        Button("Import Conversation") {
                            // TODO: Implement import
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .sheet(item: $selectedConversation) { conversation in
            ConversationDetailView(conversation: conversation)
        }
        .sheet(isPresented: $showingExportSheet) {
            ExportSheet()
        }
        .onAppear {
            loadConversationHistory()
        }
    }
    
    private func loadConversationHistory() {
        // Load from persistent storage or generate mock data
        generateMockHistory()
    }
    
    private func generateMockHistory() {
        // Create mock conversation history for demo
        let mockSpeakers = [
            Speaker(name: "You", isCurrentUser: true),
            Speaker(name: "Alice", isCurrentUser: false),
            Speaker(name: "Bob", isCurrentUser: false)
        ]
        
        var tempHistory: [ConversationExport] = []
        
        for index in 1...5 {
            let messageCount = Int.random(in: 3...8)
            var messages: [ConversationMessage] = []
            
            for messageIndex in 1...messageCount {
                let message = ConversationMessage(
                    content: "This is message \(messageIndex) from conversation \(index). Sample content.",
                    speakerId: mockSpeakers.randomElement()?.id,
                    confidence: Float.random(in: 0.7...0.95),
                    timestamp: Date().addingTimeInterval(-TimeInterval(index * 3600 + messageIndex * 60)).timeIntervalSince1970,
                    isFinal: true,
                    wordTimings: [],
                    originalText: "Original text \(messageIndex)"
                )
                messages.append(message)
            }
            
            let avgConfidence = messages.map(\.confidence).reduce(0, +) / Float(messages.count)
            let summary = ConversationSummary(
                messageCount: messages.count,
                speakerCount: mockSpeakers.count,
                duration: TimeInterval(messages.count * 30),
                averageConfidence: avgConfidence,
                startTime: messages.first?.timestamp ?? 0,
                endTime: messages.last?.timestamp ?? 0
            )
            
            let export = ConversationExport(
                messages: messages,
                speakers: mockSpeakers,
                summary: summary,
                exportDate: Date().addingTimeInterval(-TimeInterval(index * 3600))
            )
            tempHistory.append(export)
        }
        
        conversationHistory = tempHistory
    }
    
    private func exportCurrentSession() {
        guard !coordinator.currentConversation.isEmpty else { return }
        
        let export = coordinator.exportConversation()
        conversationHistory.insert(export, at: 0)
        showingExportSheet = true
    }
    
    private func clearHistory() {
        conversationHistory.removeAll()
    }
}

struct EmptyHistoryView: View {
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                Text("No Conversation History")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Your past conversations will appear here. Start a new conversation to begin building your history.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            VStack(spacing: 12) {
                HistoryFeatureRow(
                    icon: "doc.text.magnifyingglass",
                    title: "Search Conversations",
                    description: "Find specific topics or keywords"
                )
                
                HistoryFeatureRow(
                    icon: "square.and.arrow.up",
                    title: "Export & Share",
                    description: "Save conversations for future reference"
                )
                
                HistoryFeatureRow(
                    icon: "chart.bar",
                    title: "Analytics",
                    description: "Track conversation patterns and insights"
                )
            }
            .padding()
        }
    }
}

struct HistoryFeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.blue)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
}

struct ConversationHistoryList: View {
    let conversations: [ConversationExport]
    @Binding var selectedConversation: ConversationExport?
    @Binding var showingExportSheet: Bool
    
    var body: some View {
        List(conversations, id: \.exportDate) { conversation in
            ConversationHistoryRow(conversation: conversation)
                .onTapGesture {
                    selectedConversation = conversation
                }
                .swipeActions(edge: .trailing) {
                    Button("Export") {
                        selectedConversation = conversation
                        showingExportSheet = true
                    }
                    .tint(.blue)
                    
                    Button("Delete") {
                        deleteConversation(conversation)
                    }
                    .tint(.red)
                }
        }
        .listStyle(.insetGrouped)
    }
    
    private func deleteConversation(_ conversation: ConversationExport) {
        // TODO: Implement deletion
        print("Deleting conversation from \(conversation.exportDate)")
    }
}

struct ConversationHistoryRow: View {
    let conversation: ConversationExport
    
    private var firstMessage: String {
        conversation.messages.first?.content.prefix(80).appending("...") ?? "No content"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(formatDate(conversation.exportDate))
                    .font(.headline)
                    .fontWeight(.medium)
                
                Spacer()
                
                Text(formatDuration(conversation.summary.duration))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(.systemGray5))
                    .cornerRadius(8)
            }
            
            Text(String(firstMessage))
                .font(.body)
                .foregroundColor(.secondary)
                .lineLimit(2)
            
            HStack(spacing: 16) {
                ConversationStat(
                    icon: "message",
                    value: "\(conversation.summary.messageCount)",
                    label: "messages"
                )
                
                ConversationStat(
                    icon: "person.2",
                    value: "\(conversation.summary.speakerCount)",
                    label: "speakers"
                )
                
                ConversationStat(
                    icon: "checkmark.circle",
                    value: "\(Int(conversation.summary.averageConfidence * 100))%",
                    label: "confidence"
                )
                
                Spacer()
            }
        }
        .padding(.vertical, 4)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        if Calendar.current.isDateInToday(date) {
            formatter.timeStyle = .short
            return "Today at \(formatter.string(from: date))"
        } else if Calendar.current.isDateInYesterday(date) {
            formatter.timeStyle = .short
            return "Yesterday at \(formatter.string(from: date))"
        } else {
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            return formatter.string(from: date)
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        
        if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        } else {
            return "\(seconds)s"
        }
    }
}

struct ConversationStat: View {
    let icon: String
    let value: String
    let label: String
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
            
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}

struct ConversationDetailView: View {
    let conversation: ConversationExport
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab = 0
    
    var body: some View {
        NavigationView {
            TabView(selection: $selectedTab) {
                ConversationMessagesView(conversation: conversation)
                    .tabItem {
                        Image(systemName: "message")
                        Text("Messages")
                    }
                    .tag(0)
                
                ConversationStatsView(conversation: conversation)
                    .tabItem {
                        Image(systemName: "chart.bar")
                        Text("Stats")
                    }
                    .tag(1)
                
                ConversationSpeakersView(conversation: conversation)
                    .tabItem {
                        Image(systemName: "person.2")
                        Text("Speakers")
                    }
                    .tag(2)
            }
            .navigationTitle("Conversation Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Export") {
                        exportConversation()
                    }
                }
            }
        }
    }
    
    private func exportConversation() {
        // TODO: Implement export functionality
        print("Exporting conversation details")
    }
}

struct ConversationMessagesView: View {
    let conversation: ConversationExport
    
    var body: some View {
        List(conversation.messages, id: \.id) { message in
            MessageDetailRow(
                message: message,
                speaker: conversation.speakers.first { $0.id == message.speakerId }
            )
        }
        .listStyle(.plain)
    }
}

struct MessageDetailRow: View {
    let message: ConversationMessage
    let speaker: Speaker?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(speaker?.name ?? "Unknown")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text(formatTimestamp(message.timestamp))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Text(message.content)
                .font(.body)
            
            if message.confidence > 0 {
                HStack {
                    Text("Confidence:")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    ConfidenceIndicator(confidence: message.confidence)
                    
                    Spacer()
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    private func formatTimestamp(_ timestamp: TimeInterval) -> String {
        let date = Date(timeIntervalSince1970: timestamp)
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }
}

struct ConversationStatsView: View {
    let conversation: ConversationExport
    
    var body: some View {
        List {
            Section("Overview") {
                StatRow(title: "Duration", value: formatDuration(conversation.summary.duration))
                StatRow(title: "Messages", value: "\(conversation.summary.messageCount)")
                StatRow(title: "Speakers", value: "\(conversation.summary.speakerCount)")
                StatRow(title: "Average Confidence", value: "\(Int(conversation.summary.averageConfidence * 100))%")
            }
            
            Section("Timeline") {
                StatRow(title: "Start Time", value: formatDate(Date(timeIntervalSince1970: conversation.summary.startTime)))
                StatRow(title: "End Time", value: formatDate(Date(timeIntervalSince1970: conversation.summary.endTime)))
                StatRow(title: "Export Date", value: formatDate(conversation.exportDate))
            }
            
            Section("Message Distribution") {
                ForEach(messagesPerSpeaker, id: \.speakerId) { stat in
                    HStack {
                        Text(stat.speakerName)
                        
                        Spacer()
                        
                        Text("\(stat.messageCount) messages")
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
    
    private var messagesPerSpeaker: [SpeakerMessageStat] {
        let speakerMessageCounts = Dictionary(grouping: conversation.messages) { $0.speakerId }
            .mapValues { $0.count }
        
        return conversation.speakers.map { speaker in
            SpeakerMessageStat(
                speakerId: speaker.id,
                speakerName: speaker.name ?? "Unknown",
                messageCount: speakerMessageCounts[speaker.id] ?? 0
            )
        }
        .sorted { $0.messageCount > $1.messageCount }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        let seconds = Int(duration) % 60
        
        if hours > 0 {
            return String(format: "%dh %dm %ds", hours, minutes, seconds)
        } else if minutes > 0 {
            return String(format: "%dm %ds", minutes, seconds)
        } else {
            return String(format: "%ds", seconds)
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }
}

struct SpeakerMessageStat {
    let speakerId: UUID
    let speakerName: String
    let messageCount: Int
}

struct StatRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundColor(.secondary)
        }
    }
}

struct ConversationSpeakersView: View {
    let conversation: ConversationExport
    
    var body: some View {
        List(conversation.speakers, id: \.id) { speaker in
            SpeakerDetailRow(speaker: speaker, conversation: conversation)
        }
    }
}

struct SpeakerDetailRow: View {
    let speaker: Speaker
    let conversation: ConversationExport
    
    private var speakerMessages: [ConversationMessage] {
        conversation.messages.filter { $0.speakerId == speaker.id }
    }
    
    private var averageConfidence: Float {
        let confidences = speakerMessages.map { $0.confidence }
        return confidences.isEmpty ? 0 : confidences.reduce(0, +) / Float(confidences.count)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(speaker.name ?? "Unknown Speaker")
                    .font(.headline)
                
                Spacer()
                
                if speaker.isCurrentUser {
                    Text("You")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.2))
                        .foregroundColor(.blue)
                        .cornerRadius(8)
                }
            }
            
            HStack(spacing: 16) {
                SpeakerStat(
                    title: "Messages",
                    value: "\(speakerMessages.count)"
                )
                
                SpeakerStat(
                    title: "Confidence",
                    value: "\(Int(averageConfidence * 100))%"
                )
                
                SpeakerStat(
                    title: "Words",
                    value: "\(totalWords)"
                )
            }
        }
        .padding(.vertical, 4)
    }
    
    private var totalWords: Int {
        speakerMessages.reduce(0) { total, message in
            total + message.content.components(separatedBy: .whitespacesAndNewlines).count
        }
    }
}

struct SpeakerStat: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
        }
    }
}

struct ExportSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedFormat = ExportFormat.json
    @State private var includeAnalysis = true
    @State private var includeTimestamps = true
    
    enum ExportFormat: String, CaseIterable {
        case json = "JSON"
        case csv = "CSV"
        case txt = "Text"
        case pdf = "PDF"
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Export Format") {
                    Picker("Format", selection: $selectedFormat) {
                        ForEach(ExportFormat.allCases, id: \.self) { format in
                            Text(format.rawValue).tag(format)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                Section("Options") {
                    Toggle("Include Analysis Results", isOn: $includeAnalysis)
                    Toggle("Include Timestamps", isOn: $includeTimestamps)
                }
                
                Section("Preview") {
                    Text("The exported file will contain conversation messages, speaker information, and metadata in \(selectedFormat.rawValue) format.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Export Conversation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Export") {
                        performExport()
                    }
                }
            }
        }
    }
    
    private func performExport() {
        // TODO: Implement actual export functionality
        print("Exporting in \(selectedFormat.rawValue) format")
        print("Include analysis: \(includeAnalysis)")
        print("Include timestamps: \(includeTimestamps)")
        
        dismiss()
    }
}

#Preview {
    HistoryView()
        .environmentObject(AppCoordinator())
}