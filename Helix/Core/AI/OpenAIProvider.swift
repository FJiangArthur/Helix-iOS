import Foundation
import Combine

class OpenAIProvider: LLMProviderProtocol {
    let provider: LLMProvider = .openai
    
    private let apiKey: String
    private let baseURL = "https://api.openai.com/v1"
    private let session = URLSession.shared
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    
    private let model = "gpt-4"
    private let maxRetries = 3
    
    init(apiKey: String) {
        self.apiKey = apiKey
        encoder.keyEncodingStrategy = .convertToSnakeCase
        decoder.keyDecodingStrategy = .convertFromSnakeCase
    }
    
    func analyze(_ context: ConversationContext) -> AnyPublisher<AnalysisResult, LLMError> {
        let prompt = buildPrompt(for: context)
        let request = createChatCompletionRequest(prompt: prompt, analysisType: context.analysisType)
        
        return executeRequest(request)
            .map { [weak self] response in
                self?.parseResponse(response, for: context.analysisType) ?? AnalysisResult(
                    type: context.analysisType,
                    content: .text("Failed to parse response"),
                    provider: .openai
                )
            }
            .mapError { error in
                self.mapError(error)
            }
            .eraseToAnyPublisher()
    }
    
    func isAvailable() -> Bool {
        return !apiKey.isEmpty
    }
    
    func estimateCost(for context: ConversationContext) -> Float {
        let promptTokens = estimateTokens(for: buildPrompt(for: context))
        let completionTokens = 500 // Estimated
        
        // GPT-4 pricing (approximate)
        let inputCostPer1K: Float = 0.03
        let outputCostPer1K: Float = 0.06
        
        let inputCost = Float(promptTokens) / 1000.0 * inputCostPer1K
        let outputCost = Float(completionTokens) / 1000.0 * outputCostPer1K
        
        return inputCost + outputCost
    }
    
    private func buildPrompt(for context: ConversationContext) -> String {
        switch context.analysisType {
        case .factCheck:
            return buildFactCheckPrompt(context)
        case .summarization:
            return buildSummarizationPrompt(context)
        case .actionItems:
            return buildActionItemsPrompt(context)
        case .sentiment:
            return buildSentimentPrompt(context)
        case .keyTopics:
            return buildTopicsPrompt(context)
        case .translation:
            return buildTranslationPrompt(context)
        case .clarification:
            return buildClarificationPrompt(context)
        }
    }
    
    private func buildFactCheckPrompt(_ context: ConversationContext) -> String {
        let conversationText = context.messages.map { message in
            let speakerName = context.speakers.first(where: { $0.id == message.speakerId })?.name ?? "Unknown"
            return "\(speakerName): \(message.content)"
        }.joined(separator: "\n")
        
        return """
        You are a fact-checking expert. Analyze the following conversation and identify any factual claims that can be verified. For each claim, determine if it is accurate or inaccurate, provide an explanation, and cite reliable sources when possible.

        Conversation:
        \(conversationText)

        For each factual claim you identify, respond with:
        1. The exact claim
        2. Whether it is accurate (true/false)
        3. A clear explanation
        4. Confidence level (0-1)
        5. Category of claim (statistical, historical, scientific, etc.)
        6. Alternative correct information if the claim is false

        Focus on verifiable facts rather than opinions or subjective statements. Be precise and cite authoritative sources when available.

        Response format: JSON array of fact-check results.
        """
    }
    
    private func buildSummarizationPrompt(_ context: ConversationContext) -> String {
        let conversationText = context.messages.map { message in
            let speakerName = context.speakers.first(where: { $0.id == message.speakerId })?.name ?? "Unknown"
            return "\(speakerName): \(message.content)"
        }.joined(separator: "\n")
        
        return """
        Provide a concise summary of the following conversation. Include the main topics discussed, key decisions made, and important points raised by each participant.

        Conversation:
        \(conversationText)

        Summary should be:
        - 2-3 sentences maximum
        - Focused on key outcomes and decisions
        - Include speaker attribution for important points
        - Professional and objective tone
        """
    }
    
    private func buildActionItemsPrompt(_ context: ConversationContext) -> String {
        let conversationText = context.messages.map { message in
            let speakerName = context.speakers.first(where: { $0.id == message.speakerId })?.name ?? "Unknown"
            return "\(speakerName): \(message.content)"
        }.joined(separator: "\n")
        
        return """
        Extract action items from the following conversation. Identify tasks, commitments, follow-ups, and decisions that require action.

        Conversation:
        \(conversationText)

        For each action item, provide:
        1. Clear description of the task
        2. Assigned person (if mentioned)
        3. Due date (if mentioned)
        4. Priority level (low/medium/high/urgent)
        5. Category (follow-up, decision, research, communication, etc.)

        Response format: JSON array of action items.
        """
    }
    
    private func buildSentimentPrompt(_ context: ConversationContext) -> String {
        let conversationText = context.messages.map { message in
            let speakerName = context.speakers.first(where: { $0.id == message.speakerId })?.name ?? "Unknown"
            return "\(speakerName): \(message.content)"
        }.joined(separator: "\n")
        
        return """
        Analyze the sentiment and emotional tone of the following conversation. Provide overall sentiment and per-speaker analysis.

        Conversation:
        \(conversationText)

        Analyze:
        1. Overall conversation sentiment (positive/negative/neutral/mixed)
        2. Individual speaker sentiments
        3. Emotional tone (formal/casual/tense/relaxed/excited/concerned)
        4. Confidence level of analysis

        Response format: JSON with sentiment analysis results.
        """
    }
    
    private func buildTopicsPrompt(_ context: ConversationContext) -> String {
        let conversationText = context.messages.map { message in
            let speakerName = context.speakers.first(where: { $0.id == message.speakerId })?.name ?? "Unknown"
            return "\(speakerName): \(message.content)"
        }.joined(separator: "\n")
        
        return """
        Extract the main topics and themes discussed in the following conversation.

        Conversation:
        \(conversationText)

        Identify:
        1. 3-5 main topics
        2. Key themes or subjects
        3. Important concepts mentioned
        4. Areas of focus or emphasis

        Response format: JSON array of topic strings.
        """
    }
    
    private func buildTranslationPrompt(_ context: ConversationContext) -> String {
        let conversationText = context.messages.map { $0.content }.joined(separator: "\n")
        
        return """
        Translate the following text to English (if not already in English) or identify the language and provide a high-quality translation.

        Text:
        \(conversationText)

        Provide:
        1. Source language identification
        2. High-quality translation
        3. Confidence level
        4. Any cultural context notes if relevant

        Response format: JSON with translation results.
        """
    }
    
    private func buildClarificationPrompt(_ context: ConversationContext) -> String {
        let conversationText = context.messages.map { message in
            let speakerName = context.speakers.first(where: { $0.id == message.speakerId })?.name ?? "Unknown"
            return "\(speakerName): \(message.content)"
        }.joined(separator: "\n")
        
        return """
        Analyze the following conversation for areas that might need clarification or follow-up questions.

        Conversation:
        \(conversationText)

        Identify:
        1. Unclear statements or ambiguous references
        2. Missing context or incomplete information
        3. Potential misunderstandings
        4. Areas that might benefit from follow-up questions

        Suggest clarifying questions or points that could be addressed.

        Response format: JSON with clarification suggestions.
        """
    }
    
    private func createChatCompletionRequest(prompt: String, analysisType: AnalysisType) -> ChatCompletionRequest {
        let config = LLMConfigManager().getConfig(for: analysisType)
        
        return ChatCompletionRequest(
            model: model,
            messages: [
                ChatMessage(role: .user, content: prompt)
            ],
            maxTokens: config.maxTokens,
            temperature: config.temperature,
            topP: config.topP,
            frequencyPenalty: config.frequencyPenalty,
            presencePenalty: config.presencePenalty
        )
    }
    
    private func executeRequest(_ request: ChatCompletionRequest) -> AnyPublisher<ChatCompletionResponse, Error> {
        guard let url = URL(string: "\(baseURL)/chat/completions") else {
            return Fail(error: LLMError.invalidRequest).eraseToAnyPublisher()
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            urlRequest.httpBody = try encoder.encode(request)
        } catch {
            return Fail(error: error).eraseToAnyPublisher()
        }
        
        return session.dataTaskPublisher(for: urlRequest)
            .map(\.data)
            .decode(type: ChatCompletionResponse.self, decoder: decoder)
            .retry(maxRetries)
            .eraseToAnyPublisher()
    }
    
    private func parseResponse(_ response: ChatCompletionResponse, for analysisType: AnalysisType) -> AnalysisResult {
        guard let content = response.choices.first?.message.content else {
            return AnalysisResult(
                type: analysisType,
                content: .text("No response content"),
                provider: .openai
            )
        }
        
        switch analysisType {
        case .factCheck:
            return parseFactCheckResponse(content, analysisType: analysisType)
        case .summarization:
            return AnalysisResult(
                type: analysisType,
                content: .summary(content),
                confidence: 0.8,
                provider: .openai
            )
        case .actionItems:
            return parseActionItemsResponse(content, analysisType: analysisType)
        case .sentiment:
            return parseSentimentResponse(content, analysisType: analysisType)
        case .keyTopics:
            return parseTopicsResponse(content, analysisType: analysisType)
        case .translation:
            return parseTranslationResponse(content, analysisType: analysisType)
        case .clarification:
            return AnalysisResult(
                type: analysisType,
                content: .text(content),
                confidence: 0.7,
                provider: .openai
            )
        }
    }
    
    private func parseFactCheckResponse(_ content: String, analysisType: AnalysisType) -> AnalysisResult {
        // Simple parsing - in production, use proper JSON parsing
        let factCheckResult = FactCheckResult(
            claim: "Extracted claim",
            isAccurate: content.lowercased().contains("true"),
            explanation: content,
            sources: [],
            confidence: 0.8,
            alternativeInfo: nil,
            category: .general,
            severity: .minor
        )
        
        return AnalysisResult(
            type: analysisType,
            content: .factCheck(factCheckResult),
            confidence: 0.8,
            provider: .openai
        )
    }
    
    private func parseActionItemsResponse(_ content: String, analysisType: AnalysisType) -> AnalysisResult {
        // Simple parsing - extract action items from text
        let actionItems = content.components(separatedBy: "\n")
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .map { ActionItem(description: $0.trimmingCharacters(in: .whitespacesAndNewlines)) }
        
        return AnalysisResult(
            type: analysisType,
            content: .actionItems(actionItems),
            confidence: 0.7,
            provider: .openai
        )
    }
    
    private func parseSentimentResponse(_ content: String, analysisType: AnalysisType) -> AnalysisResult {
        let sentiment: Sentiment
        let lowercased = content.lowercased()
        
        if lowercased.contains("positive") {
            sentiment = .positive
        } else if lowercased.contains("negative") {
            sentiment = .negative
        } else if lowercased.contains("mixed") {
            sentiment = .mixed
        } else {
            sentiment = .neutral
        }
        
        let sentimentAnalysis = SentimentAnalysis(
            overallSentiment: sentiment,
            speakerSentiments: [:],
            emotionalTone: .casual,
            confidence: 0.7
        )
        
        return AnalysisResult(
            type: analysisType,
            content: .sentiment(sentimentAnalysis),
            confidence: 0.7,
            provider: .openai
        )
    }
    
    private func parseTopicsResponse(_ content: String, analysisType: AnalysisType) -> AnalysisResult {
        let topics = content.components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        return AnalysisResult(
            type: analysisType,
            content: .topics(topics),
            confidence: 0.8,
            provider: .openai
        )
    }
    
    private func parseTranslationResponse(_ content: String, analysisType: AnalysisType) -> AnalysisResult {
        let translationResult = TranslationResult(
            originalText: "",
            translatedText: content,
            sourceLanguage: "auto",
            targetLanguage: "en",
            confidence: 0.8
        )
        
        return AnalysisResult(
            type: analysisType,
            content: .translation(translationResult),
            confidence: 0.8,
            provider: .openai
        )
    }
    
    private func estimateTokens(for text: String) -> Int {
        // Rough estimate: 1 token ≈ 4 characters for English
        return text.count / 4
    }
    
    private func mapError(_ error: Error) -> LLMError {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost:
                return .networkError(urlError)
            case .timedOut:
                return .serviceUnavailable
            default:
                return .networkError(urlError)
            }
        }
        
        if error is DecodingError {
            return .responseParsingFailed
        }
        
        return .networkError(error)
    }
}

// MARK: - OpenAI API Models

struct ChatCompletionRequest: Codable {
    let model: String
    let messages: [ChatMessage]
    let maxTokens: Int?
    let temperature: Float?
    let topP: Float?
    let frequencyPenalty: Float?
    let presencePenalty: Float?
    let stream: Bool?
    
    init(model: String, messages: [ChatMessage], maxTokens: Int? = nil, temperature: Float? = nil, topP: Float? = nil, frequencyPenalty: Float? = nil, presencePenalty: Float? = nil, stream: Bool = false) {
        self.model = model
        self.messages = messages
        self.maxTokens = maxTokens
        self.temperature = temperature
        self.topP = topP
        self.frequencyPenalty = frequencyPenalty
        self.presencePenalty = presencePenalty
        self.stream = stream
    }
}

struct ChatMessage: Codable {
    let role: ChatRole
    let content: String
}

enum ChatRole: String, Codable {
    case system = "system"
    case user = "user"
    case assistant = "assistant"
}

struct ChatCompletionResponse: Codable {
    let id: String
    let object: String
    let created: Int
    let model: String
    let choices: [ChatChoice]
    let usage: Usage?
}

struct ChatChoice: Codable {
    let index: Int
    let message: ChatMessage
    let finishReason: String?
}

struct Usage: Codable {
    let promptTokens: Int
    let completionTokens: Int
    let totalTokens: Int
}