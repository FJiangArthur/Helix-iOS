import Foundation
import Combine

protocol LLMServiceProtocol {
    func analyzeConversation(_ context: ConversationContext) -> AnyPublisher<AnalysisResult, LLMError>
    func factCheck(_ claim: String, context: ConversationContext?) -> AnyPublisher<FactCheckResult, LLMError>
    func summarizeConversation(_ messages: [ConversationMessage]) -> AnyPublisher<String, LLMError>
    func detectClaims(in text: String) -> AnyPublisher<[FactualClaim], LLMError>
    func extractActionItems(from messages: [ConversationMessage]) -> AnyPublisher<[ActionItem], LLMError>
}

struct ConversationContext {
    let messages: [ConversationMessage]
    let speakers: [Speaker]
    let metadata: ConversationMetadata
    let analysisType: AnalysisType
    let timestamp: TimeInterval
    
    init(messages: [ConversationMessage], speakers: [Speaker], analysisType: AnalysisType, metadata: ConversationMetadata = ConversationMetadata()) {
        self.messages = messages
        self.speakers = speakers
        self.analysisType = analysisType
        self.metadata = metadata
        self.timestamp = Date().timeIntervalSince1970
    }
}

struct ConversationMetadata {
    let sessionId: UUID
    let location: String?
    let tags: [String]
    let priority: AnalysisPriority
    
    init(sessionId: UUID = UUID(), location: String? = nil, tags: [String] = [], priority: AnalysisPriority = .medium) {
        self.sessionId = sessionId
        self.location = location
        self.tags = tags
        self.priority = priority
    }
}

enum AnalysisType: String, CaseIterable {
    case factCheck = "fact_check"
    case summarization = "summarization"
    case actionItems = "action_items"
    case sentiment = "sentiment"
    case keyTopics = "key_topics"
    case translation = "translation"
    case clarification = "clarification"
}

enum AnalysisPriority: String {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case critical = "critical"
}

struct AnalysisResult {
    let id: UUID
    let type: AnalysisType
    let content: AnalysisContent
    let confidence: Float
    let sources: [Source]
    let timestamp: TimeInterval
    let processingTime: TimeInterval
    let provider: LLMProvider
    
    init(type: AnalysisType, content: AnalysisContent, confidence: Float = 0.0, sources: [Source] = [], provider: LLMProvider = .openai) {
        self.id = UUID()
        self.type = type
        self.content = content
        self.confidence = confidence
        self.sources = sources
        self.timestamp = Date().timeIntervalSince1970
        self.processingTime = 0.0
        self.provider = provider
    }
}

enum AnalysisContent {
    case factCheck(FactCheckResult)
    case summary(String)
    case actionItems([ActionItem])
    case sentiment(SentimentAnalysis)
    case topics([String])
    case translation(TranslationResult)
    case text(String)
}

struct FactCheckResult {
    let claim: String
    let isAccurate: Bool
    let explanation: String
    let sources: [VerificationSource]
    let confidence: Float
    let alternativeInfo: String?
    let category: ClaimCategory
    let severity: FactCheckSeverity
    
    enum FactCheckSeverity {
        case minor
        case significant
        case critical
    }
}

struct FactualClaim {
    let text: String
    let confidence: Float
    let category: ClaimCategory
    let extractionMethod: ExtractionMethod
    let context: String
    let position: ClaimPosition
}

struct ClaimPosition {
    let startIndex: String.Index
    let endIndex: String.Index
    let characterRange: NSRange
}

enum ClaimCategory: String, CaseIterable {
    case statistical = "statistical"
    case historical = "historical"
    case scientific = "scientific"
    case geographical = "geographical"
    case biographical = "biographical"
    case general = "general"
    case financial = "financial"
    case medical = "medical"
    case legal = "legal"
}

enum ExtractionMethod {
    case patternMatching
    case semanticAnalysis
    case entityRecognition
    case contextualAnalysis
}

struct VerificationSource {
    let title: String
    let url: String?
    let reliability: SourceReliability
    let lastUpdated: Date?
    let summary: String?
}

enum SourceReliability: String {
    case high = "high"
    case medium = "medium"
    case low = "low"
    case unknown = "unknown"
}

struct ActionItem {
    let id: UUID
    let description: String
    let assignee: UUID?
    let dueDate: Date?
    let priority: ActionItemPriority
    let category: ActionItemCategory
    let status: ActionItemStatus
    
    init(description: String, assignee: UUID? = nil, dueDate: Date? = nil, priority: ActionItemPriority = .medium, category: ActionItemCategory = .general) {
        self.id = UUID()
        self.description = description
        self.assignee = assignee
        self.dueDate = dueDate
        self.priority = priority
        self.category = category
        self.status = .pending
    }
}

enum ActionItemPriority: String {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case urgent = "urgent"
}

enum ActionItemCategory: String {
    case general = "general"
    case followUp = "follow_up"
    case decision = "decision"
    case research = "research"
    case communication = "communication"
}

enum ActionItemStatus: String {
    case pending = "pending"
    case inProgress = "in_progress"
    case completed = "completed"
    case cancelled = "cancelled"
}

struct SentimentAnalysis {
    let overallSentiment: Sentiment
    let speakerSentiments: [UUID: Sentiment]
    let emotionalTone: EmotionalTone
    let confidence: Float
}

enum Sentiment: String {
    case positive = "positive"
    case negative = "negative"
    case neutral = "neutral"
    case mixed = "mixed"
}

enum EmotionalTone: String {
    case formal = "formal"
    case casual = "casual"
    case tense = "tense"
    case relaxed = "relaxed"
    case excited = "excited"
    case concerned = "concerned"
}

struct TranslationResult {
    let originalText: String
    let translatedText: String
    let sourceLanguage: String
    let targetLanguage: String
    let confidence: Float
}

struct Source {
    let id: UUID
    let title: String
    let url: String?
    let type: SourceType
    let reliability: SourceReliability
    
    init(title: String, url: String? = nil, type: SourceType = .web, reliability: SourceReliability = .medium) {
        self.id = UUID()
        self.title = title
        self.url = url
        self.type = type
        self.reliability = reliability
    }
}

enum SourceType: String {
    case web = "web"
    case academic = "academic"
    case news = "news"
    case government = "government"
    case encyclopedia = "encyclopedia"
    case database = "database"
}

enum LLMProvider: String, CaseIterable {
    case openai = "openai"
    case anthropic = "anthropic"
    case local = "local"
    
    var displayName: String {
        switch self {
        case .openai: return "OpenAI"
        case .anthropic: return "Anthropic"
        case .local: return "Local Model"
        }
    }
}

enum LLMError: Error {
    case networkError(Error)
    case authenticationFailed
    case rateLimitExceeded
    case modelUnavailable
    case invalidRequest
    case responseParsingFailed
    case contextTooLarge
    case serviceUnavailable
    case quotaExceeded
    
    var localizedDescription: String {
        switch self {
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .authenticationFailed:
            return "Authentication failed"
        case .rateLimitExceeded:
            return "Rate limit exceeded"
        case .modelUnavailable:
            return "Model unavailable"
        case .invalidRequest:
            return "Invalid request"
        case .responseParsingFailed:
            return "Failed to parse response"
        case .contextTooLarge:
            return "Context too large for model"
        case .serviceUnavailable:
            return "Service unavailable"
        case .quotaExceeded:
            return "Usage quota exceeded"
        }
    }
}

// MARK: - LLM Service Implementation

class LLMService: LLMServiceProtocol {
    private let providers: [LLMProvider: LLMProviderProtocol]
    private let rateLimiter: RateLimiter
    private let cacheManager: LLMCacheManager
    private let configManager: LLMConfigManager
    
    private var currentProvider: LLMProvider = .openai
    private let fallbackProviders: [LLMProvider] = [.anthropic, .openai]
    
    init(providers: [LLMProvider: LLMProviderProtocol], rateLimiter: RateLimiter = RateLimiter(), cacheManager: LLMCacheManager = LLMCacheManager()) {
        self.providers = providers
        self.rateLimiter = rateLimiter
        self.cacheManager = cacheManager
        self.configManager = LLMConfigManager()
    }
    
    func analyzeConversation(_ context: ConversationContext) -> AnyPublisher<AnalysisResult, LLMError> {
        // Check cache first
        if let cachedResult = cacheManager.getCachedResult(for: context) {
            return Just(cachedResult)
                .setFailureType(to: LLMError.self)
                .eraseToAnyPublisher()
        }
        
        // Select appropriate provider based on analysis type
        let provider = selectProvider(for: context.analysisType)
        
        return executeWithFallback(context: context, providers: [provider] + fallbackProviders)
            .handleEvents(receiveOutput: { [weak self] result in
                self?.cacheManager.cacheResult(result, for: context)
            })
            .eraseToAnyPublisher()
    }
    
    func factCheck(_ claim: String, context: ConversationContext?) -> AnyPublisher<FactCheckResult, LLMError> {
        let analysisContext = ConversationContext(
            messages: context?.messages ?? [],
            speakers: context?.speakers ?? [],
            analysisType: .factCheck
        )
        
        return analyzeConversation(analysisContext)
            .compactMap { result in
                if case .factCheck(let factCheckResult) = result.content {
                    return factCheckResult
                } else {
                    return nil
                }
            }
            .mapError { $0 as LLMError }
            .eraseToAnyPublisher()
    }
    
    func summarizeConversation(_ messages: [ConversationMessage]) -> AnyPublisher<String, LLMError> {
        let context = ConversationContext(
            messages: messages,
            speakers: [],
            analysisType: .summarization
        )
        
        return analyzeConversation(context)
            .compactMap { result in
                if case .summary(let summary) = result.content {
                    return summary
                } else {
                    return nil
                }
            }
            .eraseToAnyPublisher()
    }
    
    func detectClaims(in text: String) -> AnyPublisher<[FactualClaim], LLMError> {
        let claimDetector = ClaimDetectionService()
        return claimDetector.detectClaims(in: text)
    }
    
    func extractActionItems(from messages: [ConversationMessage]) -> AnyPublisher<[ActionItem], LLMError> {
        let context = ConversationContext(
            messages: messages,
            speakers: [],
            analysisType: .actionItems
        )
        
        return analyzeConversation(context)
            .compactMap { result in
                if case .actionItems(let items) = result.content {
                    return items
                } else {
                    return nil
                }
            }
            .eraseToAnyPublisher()
    }
    
    private func selectProvider(for analysisType: AnalysisType) -> LLMProvider {
        switch analysisType {
        case .factCheck:
            return .anthropic // Claude is good for fact-checking
        case .summarization, .actionItems:
            return .openai // GPT is good for structured tasks
        case .sentiment, .keyTopics:
            return currentProvider
        case .translation:
            return .openai
        case .clarification:
            return .anthropic
        }
    }
    
    private func executeWithFallback(context: ConversationContext, providers: [LLMProvider]) -> AnyPublisher<AnalysisResult, LLMError> {
        guard let firstProvider = providers.first,
              let service = self.providers[firstProvider] else {
            return Fail(error: LLMError.serviceUnavailable)
                .eraseToAnyPublisher()
        }
        
        return rateLimiter.execute {
            service.analyze(context)
        }
        .catch { error -> AnyPublisher<AnalysisResult, LLMError> in
            let remainingProviders = Array(providers.dropFirst())
            if !remainingProviders.isEmpty {
                print("Provider \(firstProvider) failed, trying fallback: \(error)")
                return self.executeWithFallback(context: context, providers: remainingProviders)
            } else {
                return Fail(error: error).eraseToAnyPublisher()
            }
        }
        .eraseToAnyPublisher()
    }
}

// MARK: - LLM Provider Protocol

protocol LLMProviderProtocol {
    var provider: LLMProvider { get }
    func analyze(_ context: ConversationContext) -> AnyPublisher<AnalysisResult, LLMError>
    func isAvailable() -> Bool
    func estimateCost(for context: ConversationContext) -> Float
}

// MARK: - Supporting Services

class RateLimiter {
    private let maxRequestsPerMinute: Int = 60
    private let maxRequestsPerHour: Int = 1000
    private var requestTimestamps: [Date] = []
    private let queue = DispatchQueue(label: "rate.limiter", attributes: .concurrent)
    
    func execute<T>(_ operation: @escaping () -> AnyPublisher<T, LLMError>) -> AnyPublisher<T, LLMError> {
        return Future<T, LLMError> { [weak self] promise in
            self?.queue.async(flags: .barrier) {
                guard let self = self else {
                    promise(.failure(.serviceUnavailable))
                    return
                }
                
                let now = Date()
                
                // Clean old timestamps
                self.requestTimestamps = self.requestTimestamps.filter { timestamp in
                    now.timeIntervalSince(timestamp) < 3600 // 1 hour
                }
                
                // Check rate limits
                let recentRequests = self.requestTimestamps.filter { timestamp in
                    now.timeIntervalSince(timestamp) < 60 // 1 minute
                }
                
                if recentRequests.count >= self.maxRequestsPerMinute {
                    promise(.failure(.rateLimitExceeded))
                    return
                }
                
                if self.requestTimestamps.count >= self.maxRequestsPerHour {
                    promise(.failure(.rateLimitExceeded))
                    return
                }
                
                // Add current request
                self.requestTimestamps.append(now)
                
                // Execute operation
                operation()
                    .sink(
                        receiveCompletion: { completion in
                            if case .failure(let error) = completion {
                                promise(.failure(error))
                            }
                        },
                        receiveValue: { value in
                            promise(.success(value))
                        }
                    )
                    .store(in: &Set<AnyCancellable>())
            }
        }
        .eraseToAnyPublisher()
    }
}

class LLMCacheManager {
    private var cache: [String: CachedResult] = [:]
    private let cacheQueue = DispatchQueue(label: "llm.cache", attributes: .concurrent)
    private let maxCacheSize = 100
    private let cacheExpirationTime: TimeInterval = 3600 // 1 hour
    
    struct CachedResult {
        let result: AnalysisResult
        let timestamp: Date
        let accessCount: Int
        
        var isExpired: Bool {
            Date().timeIntervalSince(timestamp) > 3600
        }
    }
    
    func getCachedResult(for context: ConversationContext) -> AnalysisResult? {
        let key = generateCacheKey(for: context)
        
        return cacheQueue.sync {
            guard let cached = cache[key], !cached.isExpired else {
                cache.removeValue(forKey: key)
                return nil
            }
            
            // Update access count
            cache[key] = CachedResult(
                result: cached.result,
                timestamp: cached.timestamp,
                accessCount: cached.accessCount + 1
            )
            
            return cached.result
        }
    }
    
    func cacheResult(_ result: AnalysisResult, for context: ConversationContext) {
        let key = generateCacheKey(for: context)
        
        cacheQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            
            // Clean expired entries
            self.cleanExpiredEntries()
            
            // Add new entry
            self.cache[key] = CachedResult(
                result: result,
                timestamp: Date(),
                accessCount: 1
            )
            
            // Maintain cache size
            if self.cache.count > self.maxCacheSize {
                self.evictLeastUsed()
            }
        }
    }
    
    private func generateCacheKey(for context: ConversationContext) -> String {
        let messagesHash = context.messages.map { $0.content }.joined().hash
        return "\(context.analysisType.rawValue)_\(messagesHash)"
    }
    
    private func cleanExpiredEntries() {
        cache = cache.filter { !$0.value.isExpired }
    }
    
    private func evictLeastUsed() {
        guard let leastUsedKey = cache.min(by: { $0.value.accessCount < $1.value.accessCount })?.key else {
            return
        }
        cache.removeValue(forKey: leastUsedKey)
    }
}

class LLMConfigManager {
    struct LLMConfig {
        let maxTokens: Int
        let temperature: Float
        let topP: Float
        let frequencyPenalty: Float
        let presencePenalty: Float
    }
    
    private let configs: [AnalysisType: LLMConfig] = [
        .factCheck: LLMConfig(maxTokens: 500, temperature: 0.1, topP: 0.9, frequencyPenalty: 0.0, presencePenalty: 0.0),
        .summarization: LLMConfig(maxTokens: 300, temperature: 0.3, topP: 0.9, frequencyPenalty: 0.0, presencePenalty: 0.0),
        .actionItems: LLMConfig(maxTokens: 400, temperature: 0.2, topP: 0.9, frequencyPenalty: 0.0, presencePenalty: 0.0),
        .sentiment: LLMConfig(maxTokens: 200, temperature: 0.1, topP: 0.9, frequencyPenalty: 0.0, presencePenalty: 0.0),
        .keyTopics: LLMConfig(maxTokens: 300, temperature: 0.2, topP: 0.9, frequencyPenalty: 0.0, presencePenalty: 0.0)
    ]
    
    func getConfig(for analysisType: AnalysisType) -> LLMConfig {
        return configs[analysisType] ?? LLMConfig(maxTokens: 400, temperature: 0.3, topP: 0.9, frequencyPenalty: 0.0, presencePenalty: 0.0)
    }
}