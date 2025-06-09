import SwiftUI

struct AnalysisView: View {
    @EnvironmentObject var coordinator: AppCoordinator
    @State private var selectedAnalysisType: AnalysisType = .factCheck
    
    var body: some View {
        NavigationView {
            VStack {
                if coordinator.recentAnalysis.isEmpty {
                    EmptyAnalysisView()
                } else {
                    AnalysisContentView(selectedType: $selectedAnalysisType)
                }
            }
            .navigationTitle("Analysis")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        ForEach(AnalysisType.allCases, id: \.self) { type in
                            Button(type.displayName) {
                                selectedAnalysisType = type
                            }
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                }
            }
        }
    }
}

struct EmptyAnalysisView: View {
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                Text("No Analysis Available")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Start a conversation to see AI-powered analysis including fact-checking, summaries, and insights.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            VStack(spacing: 12) {
                AnalysisFeatureRow(
                    icon: "checkmark.circle",
                    title: "Fact Checking",
                    description: "Real-time verification of claims and statements"
                )
                
                AnalysisFeatureRow(
                    icon: "doc.text",
                    title: "Auto Summary",
                    description: "Key points and decisions from conversations"
                )
                
                AnalysisFeatureRow(
                    icon: "list.bullet",
                    title: "Action Items",
                    description: "Extracted tasks and follow-ups"
                )
                
                AnalysisFeatureRow(
                    icon: "heart.text.square",
                    title: "Sentiment Analysis",
                    description: "Emotional tone and mood tracking"
                )
            }
            .padding()
        }
    }
}

struct AnalysisFeatureRow: View {
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

struct AnalysisContentView: View {
    @EnvironmentObject var coordinator: AppCoordinator
    @Binding var selectedType: AnalysisType
    
    private var filteredAnalysis: [AnalysisResult] {
        coordinator.recentAnalysis.filter { $0.type == selectedType }
    }
    
    var body: some View {
        VStack {
            // Analysis type picker
            AnalysisTypePicker(selectedType: $selectedType)
                .padding(.horizontal)
            
            if filteredAnalysis.isEmpty {
                NoAnalysisForTypeView(type: selectedType)
            } else {
                // Analysis results
                List(filteredAnalysis, id: \.id) { result in
                    AnalysisResultCard(result: result)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                }
                .listStyle(.plain)
            }
        }
    }
}

struct AnalysisTypePicker: View {
    @Binding var selectedType: AnalysisType
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(AnalysisType.allCases, id: \.self) { type in
                    Button(action: {
                        selectedType = type
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: type.iconName)
                                .font(.caption)
                            
                            Text(type.displayName)
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(selectedType == type ? Color.blue : Color(.systemGray5))
                        .foregroundColor(selectedType == type ? .white : .primary)
                        .cornerRadius(16)
                    }
                }
            }
            .padding(.horizontal)
        }
    }
}

struct NoAnalysisForTypeView: View {
    let type: AnalysisType
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: type.iconName)
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            
            Text("No \(type.displayName) Available")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text(type.emptyStateDescription)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct AnalysisResultCard: View {
    let result: AnalysisResult
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: result.type.iconName)
                        .foregroundColor(result.type.color)
                    
                    Text(result.type.displayName)
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    ConfidenceIndicator(confidence: result.confidence)
                    
                    Text(formatTimestamp(result.timestamp))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            // Content
            AnalysisContentCard(content: result.content, isExpanded: $isExpanded)
            
            // Sources (if available)
            if !result.sources.isEmpty {
                SourcesView(sources: result.sources)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
    
    private func formatTimestamp(_ timestamp: TimeInterval) -> String {
        let date = Date(timeIntervalSince1970: timestamp)
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

struct AnalysisContentCard: View {
    let content: AnalysisContent
    @Binding var isExpanded: Bool
    
    var body: some View {
        switch content {
        case .factCheck(let result):
            FactCheckContentView(result: result, isExpanded: $isExpanded)
        case .summary(let text):
            SummaryContentView(text: text)
        case .actionItems(let items):
            ActionItemsContentView(items: items)
        case .sentiment(let analysis):
            SentimentContentView(analysis: analysis)
        case .topics(let topics):
            TopicsContentView(topics: topics)
        case .translation(let result):
            TranslationContentView(result: result)
        case .text(let text):
            Text(text)
                .font(.body)
        }
    }
}

struct FactCheckContentView: View {
    let result: FactCheckResult
    @Binding var isExpanded: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Claim
            Text("Claim:")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(result.claim)
                .font(.body)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.systemGray6))
                .cornerRadius(8)
            
            // Result
            HStack {
                Image(systemName: result.isAccurate ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(result.isAccurate ? .green : .red)
                
                Text(result.isAccurate ? "Accurate" : "Inaccurate")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(result.isAccurate ? .green : .red)
                
                Spacer()
                
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isExpanded.toggle()
                    }
                }) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Explanation (expandable)
            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Explanation:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(result.explanation)
                        .font(.body)
                    
                    if let alternativeInfo = result.alternativeInfo {
                        Text("Correct Information:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(alternativeInfo)
                            .font(.body)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(8)
                    }
                }
                .transition(.slide)
            }
        }
    }
}

struct SummaryContentView: View {
    let text: String
    
    var body: some View {
        Text(text)
            .font(.body)
            .padding()
            .background(Color.blue.opacity(0.1))
            .cornerRadius(8)
    }
}

struct ActionItemsContentView: View {
    let items: [ActionItem]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(items, id: \.id) { item in
                HStack {
                    Image(systemName: "circle")
                        .foregroundColor(item.priority.color)
                    
                    Text(item.description)
                        .font(.body)
                    
                    Spacer()
                    
                    Text(item.priority.rawValue.uppercased())
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(item.priority.color)
                }
                .padding(.vertical, 4)
            }
        }
    }
}

struct SentimentContentView: View {
    let analysis: SentimentAnalysis
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Overall Sentiment:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                SentimentBadge(sentiment: analysis.overallSentiment)
            }
            
            HStack {
                Text("Emotional Tone:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text(analysis.emotionalTone.rawValue.capitalized)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(.systemGray5))
                    .cornerRadius(8)
            }
        }
    }
}

struct SentimentBadge: View {
    let sentiment: Sentiment
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: sentiment.iconName)
                .font(.caption2)
            
            Text(sentiment.rawValue.capitalized)
                .font(.caption)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(sentiment.color.opacity(0.2))
        .foregroundColor(sentiment.color)
        .cornerRadius(8)
    }
}

struct TopicsContentView: View {
    let topics: [String]
    
    var body: some View {
        LazyVGrid(columns: [
            GridItem(.adaptive(minimum: 100))
        ], spacing: 8) {
            ForEach(topics, id: \.self) { topic in
                Text(topic)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(.systemGray5))
                    .cornerRadius(12)
            }
        }
    }
}

struct TranslationContentView: View {
    let result: TranslationResult
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Original (\(result.sourceLanguage)):")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(result.originalText)
                .font(.body)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
            
            Text("Translation (\(result.targetLanguage)):")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(result.translatedText)
                .font(.body)
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
        }
    }
}

struct SourcesView: View {
    let sources: [Source]
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: {
                withAnimation {
                    isExpanded.toggle()
                }
            }) {
                HStack {
                    Text("Sources (\(sources.count))")
                        .font(.caption)
                        .foregroundColor(.blue)
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption2)
                        .foregroundColor(.blue)
                }
            }
            
            if isExpanded {
                ForEach(sources, id: \.id) { source in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(source.title)
                                .font(.caption)
                                .fontWeight(.medium)
                            
                            if let url = source.url {
                                Text(url)
                                    .font(.caption2)
                                    .foregroundColor(.blue)
                                    .lineLimit(1)
                            }
                        }
                        
                        Spacer()
                        
                        ReliabilityBadge(reliability: source.reliability)
                    }
                    .padding(.vertical, 2)
                }
                .transition(.slide)
            }
        }
    }
}

struct ReliabilityBadge: View {
    let reliability: SourceReliability
    
    var body: some View {
        Text(reliability.rawValue.capitalized)
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(reliability.color.opacity(0.2))
            .foregroundColor(reliability.color)
            .cornerRadius(4)
    }
}

// MARK: - Extensions

extension AnalysisType {
    var displayName: String {
        switch self {
        case .factCheck: return "Fact Check"
        case .summarization: return "Summary"
        case .actionItems: return "Action Items"
        case .sentiment: return "Sentiment"
        case .keyTopics: return "Topics"
        case .translation: return "Translation"
        case .clarification: return "Clarification"
        }
    }
    
    var iconName: String {
        switch self {
        case .factCheck: return "checkmark.circle"
        case .summarization: return "doc.text"
        case .actionItems: return "list.bullet"
        case .sentiment: return "heart.text.square"
        case .keyTopics: return "tag"
        case .translation: return "globe"
        case .clarification: return "questionmark.circle"
        }
    }
    
    var color: Color {
        switch self {
        case .factCheck: return .red
        case .summarization: return .blue
        case .actionItems: return .orange
        case .sentiment: return .purple
        case .keyTopics: return .green
        case .translation: return .cyan
        case .clarification: return .yellow
        }
    }
    
    var emptyStateDescription: String {
        switch self {
        case .factCheck: return "Fact-checking results will appear here when claims are detected in conversations."
        case .summarization: return "Conversation summaries will be generated automatically during discussions."
        case .actionItems: return "Action items and tasks will be extracted from conversations."
        case .sentiment: return "Sentiment analysis will show the emotional tone of conversations."
        case .keyTopics: return "Key topics and themes will be identified from conversation content."
        case .translation: return "Translation results will appear when non-English content is detected."
        case .clarification: return "Clarification suggestions will help improve conversation understanding."
        }
    }
}

extension ActionItemPriority {
    var color: Color {
        switch self {
        case .low: return .green
        case .medium: return .orange
        case .high: return .red
        case .urgent: return .purple
        }
    }
}

extension Sentiment {
    var iconName: String {
        switch self {
        case .positive: return "face.smiling"
        case .negative: return "face.dashed"
        case .neutral: return "face.expressionless"
        case .mixed: return "face.expressionless"
        }
    }
    
    var color: Color {
        switch self {
        case .positive: return .green
        case .negative: return .red
        case .neutral: return .gray
        case .mixed: return .orange
        }
    }
}

extension SourceReliability {
    var color: Color {
        switch self {
        case .high: return .green
        case .medium: return .orange
        case .low: return .red
        case .unknown: return .gray
        }
    }
}

#Preview {
    AnalysisView()
        .environmentObject(AppCoordinator())
}