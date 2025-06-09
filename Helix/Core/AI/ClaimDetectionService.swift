import Foundation
import Combine
import NaturalLanguage

class ClaimDetectionService {
    private let nlProcessor = NLTagger(tagSchemes: [.nameType, .lexicalClass])
    private let semanticAnalyzer = SemanticAnalyzer()
    private let patternMatcher = PatternMatcher()
    
    func detectClaims(in text: String) -> AnyPublisher<[FactualClaim], LLMError> {
        return Future<[FactualClaim], LLMError> { [weak self] promise in
            guard let self = self else {
                promise(.failure(.serviceUnavailable))
                return
            }
            
            DispatchQueue.global(qos: .userInitiated).async {
                let claims = self.performClaimDetection(in: text)
                promise(.success(claims))
            }
        }
        .eraseToAnyPublisher()
    }
    
    private func performClaimDetection(in text: String) -> [FactualClaim] {
        var detectedClaims: [FactualClaim] = []
        
        // 1. Pattern-based detection
        let patternClaims = patternMatcher.detectClaims(in: text)
        detectedClaims.append(contentsOf: patternClaims)
        
        // 2. Semantic analysis
        let semanticClaims = semanticAnalyzer.detectClaims(in: text)
        detectedClaims.append(contentsOf: semanticClaims)
        
        // 3. Named entity recognition
        let entityClaims = detectEntityBasedClaims(in: text)
        detectedClaims.append(contentsOf: entityClaims)
        
        // 4. Statistical statement detection
        let statisticalClaims = detectStatisticalClaims(in: text)
        detectedClaims.append(contentsOf: statisticalClaims)
        
        // Remove duplicates and filter by confidence
        return deduplicateAndFilter(claims: detectedClaims)
    }
    
    private func detectEntityBasedClaims(in text: String) -> [FactualClaim] {
        nlProcessor.string = text
        var claims: [FactualClaim] = []
        
        let range = text.startIndex..<text.endIndex
        nlProcessor.enumerateTags(in: range, unit: .word, scheme: .nameType) { tag, tokenRange in
            guard let tag = tag else { return true }
            
            let entity = String(text[tokenRange])
            let category = mapEntityToCategory(tag)
            
            // Look for claims involving this entity
            if let claim = findClaimInvolving(entity: entity, in: text, range: tokenRange, category: category) {
                claims.append(claim)
            }
            
            return true
        }
        
        return claims
    }
    
    private func detectStatisticalClaims(in text: String) -> [FactualClaim] {
        var claims: [FactualClaim] = []
        
        // Patterns for statistical claims
        let statisticalPatterns = [
            #"\b\d+(?:\.\d+)?%"#,  // Percentages
            #"\b\d+(?:,\d{3})*(?:\.\d+)?\s+(?:million|billion|trillion|thousand)"#,  // Large numbers
            #"\b\d+(?:\.\d+)?\s+(?:times|fold)"#,  // Multipliers
            #"\b(?:increased|decreased|rose|fell|grew|dropped)\s+by\s+\d+(?:\.\d+)?%?"#,  // Change statistics
            #"\b\d+(?:\.\d+)?\s+(?:degrees|celsius|fahrenheit)"#,  // Temperature
            #"\b\d{4}\s+(?:years?|AD|BC|CE|BCE)"#,  // Years/dates
        ]
        
        for pattern in statisticalPatterns {
            let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
            let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
            
            regex?.enumerateMatches(in: text, options: [], range: nsRange) { match, _, _ in
                guard let match = match else { return }
                
                let matchRange = Range(match.range, in: text)!
                let claimText = String(text[matchRange])
                
                // Extract surrounding context
                let context = extractContext(around: matchRange, in: text)
                
                let claim = FactualClaim(
                    text: claimText,
                    confidence: 0.7,
                    category: .statistical,
                    extractionMethod: .patternMatching,
                    context: context,
                    position: ClaimPosition(
                        startIndex: matchRange.lowerBound,
                        endIndex: matchRange.upperBound,
                        characterRange: match.range
                    )
                )
                
                claims.append(claim)
            }
        }
        
        return claims
    }
    
    private func findClaimInvolving(entity: String, in text: String, range: Range<String.Index>, category: ClaimCategory) -> FactualClaim? {
        // Extract sentence containing the entity
        let sentenceRange = expandToSentence(from: range, in: text)
        let sentence = String(text[sentenceRange])
        
        // Check if sentence contains factual indicators
        let factualIndicators = [
            "is", "was", "are", "were", "has", "have", "had",
            "contains", "includes", "measures", "weighs",
            "born", "died", "founded", "established",
            "located", "situated", "discovered", "invented"
        ]
        
        let lowercaseSentence = sentence.lowercased()
        let containsFactualIndicator = factualIndicators.contains { lowercaseSentence.contains($0) }
        
        if containsFactualIndicator {
            return FactualClaim(
                text: sentence.trimmingCharacters(in: .whitespacesAndNewlines),
                confidence: 0.6,
                category: category,
                extractionMethod: .entityRecognition,
                context: sentence,
                position: ClaimPosition(
                    startIndex: sentenceRange.lowerBound,
                    endIndex: sentenceRange.upperBound,
                    characterRange: NSRange(sentenceRange, in: text)
                )
            )
        }
        
        return nil
    }
    
    private func mapEntityToCategory(_ tag: NLTag) -> ClaimCategory {
        switch tag {
        case .personalName:
            return .biographical
        case .placeName:
            return .geographical
        case .organizationName:
            return .general
        default:
            return .general
        }
    }
    
    private func expandToSentence(from range: Range<String.Index>, in text: String) -> Range<String.Index> {
        let sentenceEnders: Set<Character> = [".", "!", "?"]
        
        // Find sentence start
        var start = range.lowerBound
        while start > text.startIndex {
            let prevIndex = text.index(before: start)
            if sentenceEnders.contains(text[prevIndex]) {
                break
            }
            start = prevIndex
        }
        
        // Find sentence end
        var end = range.upperBound
        while end < text.endIndex {
            if sentenceEnders.contains(text[end]) {
                end = text.index(after: end)
                break
            }
            end = text.index(after: end)
        }
        
        return start..<end
    }
    
    private func extractContext(around range: Range<String.Index>, in text: String, contextWords: Int = 10) -> String {
        let words = text.components(separatedBy: .whitespacesAndNewlines)
        let claimText = String(text[range])
        
        // Find the claim in the words array
        guard let claimWordIndex = words.firstIndex(where: { claimText.contains($0) }) else {
            return claimText
        }
        
        let startIndex = max(0, claimWordIndex - contextWords)
        let endIndex = min(words.count, claimWordIndex + contextWords)
        
        return words[startIndex..<endIndex].joined(separator: " ")
    }
    
    private func deduplicateAndFilter(claims: [FactualClaim]) -> [FactualClaim] {
        var uniqueClaims: [FactualClaim] = []
        let minConfidence: Float = 0.5
        
        for claim in claims {
            // Filter by confidence
            guard claim.confidence >= minConfidence else { continue }
            
            // Check for duplicates
            let isDuplicate = uniqueClaims.contains { existingClaim in
                let similarity = calculateSimilarity(claim.text, existingClaim.text)
                return similarity > 0.8
            }
            
            if !isDuplicate {
                uniqueClaims.append(claim)
            }
        }
        
        // Sort by confidence
        return uniqueClaims.sorted { $0.confidence > $1.confidence }
    }
    
    private func calculateSimilarity(_ text1: String, _ text2: String) -> Float {
        let words1 = Set(text1.lowercased().components(separatedBy: .whitespacesAndNewlines))
        let words2 = Set(text2.lowercased().components(separatedBy: .whitespacesAndNewlines))
        
        let intersection = words1.intersection(words2)
        let union = words1.union(words2)
        
        return union.isEmpty ? 0.0 : Float(intersection.count) / Float(union.count)
    }
}

// MARK: - Pattern Matcher

class PatternMatcher {
    private let factualPatterns: [FactualPattern] = [
        // Geographical claims
        FactualPattern(
            pattern: #"\b\w+\s+is\s+(?:located|situated)\s+in\s+\w+"#,
            category: .geographical,
            confidence: 0.8
        ),
        FactualPattern(
            pattern: #"\b\w+\s+has\s+a\s+population\s+of\s+[\d,]+"#,
            category: .statistical,
            confidence: 0.9
        ),
        
        // Historical claims
        FactualPattern(
            pattern: #"\b\w+\s+(?:was\s+born|died)\s+in\s+\d{4}"#,
            category: .biographical,
            confidence: 0.8
        ),
        FactualPattern(
            pattern: #"\b\w+\s+(?:founded|established)\s+in\s+\d{4}"#,
            category: .historical,
            confidence: 0.8
        ),
        
        // Scientific claims
        FactualPattern(
            pattern: #"\b\w+\s+(?:boils|melts|freezes)\s+at\s+\d+(?:\.\d+)?\s+degrees"#,
            category: .scientific,
            confidence: 0.9
        ),
        FactualPattern(
            pattern: #"\b\w+\s+(?:weighs|measures)\s+\d+(?:\.\d+)?\s+\w+"#,
            category: .scientific,
            confidence: 0.7
        ),
        
        // General factual statements
        FactualPattern(
            pattern: #"\b(?:there\s+are|there\s+were)\s+\d+\s+\w+"#,
            category: .statistical,
            confidence: 0.7
        ),
        FactualPattern(
            pattern: #"\b\w+\s+is\s+the\s+(?:capital|largest|smallest)\s+\w+\s+in\s+\w+"#,
            category: .geographical,
            confidence: 0.8
        )
    ]
    
    func detectClaims(in text: String) -> [FactualClaim] {
        var claims: [FactualClaim] = []
        
        for pattern in factualPatterns {
            let regex = try? NSRegularExpression(pattern: pattern.pattern, options: [.caseInsensitive])
            let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
            
            regex?.enumerateMatches(in: text, options: [], range: nsRange) { match, _, _ in
                guard let match = match else { return }
                
                let matchRange = Range(match.range, in: text)!
                let claimText = String(text[matchRange])
                
                let claim = FactualClaim(
                    text: claimText,
                    confidence: pattern.confidence,
                    category: pattern.category,
                    extractionMethod: .patternMatching,
                    context: claimText,
                    position: ClaimPosition(
                        startIndex: matchRange.lowerBound,
                        endIndex: matchRange.upperBound,
                        characterRange: match.range
                    )
                )
                
                claims.append(claim)
            }
        }
        
        return claims
    }
}

struct FactualPattern {
    let pattern: String
    let category: ClaimCategory
    let confidence: Float
}

// MARK: - Semantic Analyzer

class SemanticAnalyzer {
    private let embedding = NLEmbedding.wordEmbedding(for: .english)
    
    func detectClaims(in text: String) -> [FactualClaim] {
        guard let embedding = embedding else { return [] }
        
        var claims: [FactualClaim] = []
        
        // Split into sentences
        let sentences = text.components(separatedBy: CharacterSet(charactersIn: ".!?"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        for sentence in sentences {
            if let claim = analyzeSemanticContent(sentence, embedding: embedding) {
                claims.append(claim)
            }
        }
        
        return claims
    }
    
    private func analyzeSemanticContent(_ sentence: String, embedding: NLEmbedding) -> FactualClaim? {
        // Keywords that often indicate factual claims
        let factualKeywords = [
            "is", "was", "are", "were", "has", "have", "contains",
            "measures", "weighs", "located", "founded", "born", "died",
            "discovered", "invented", "established", "population", "temperature"
        ]
        
        let words = sentence.lowercased().components(separatedBy: .whitespacesAndNewlines)
        let factualWordCount = words.filter { factualKeywords.contains($0) }.count
        
        // Calculate semantic confidence based on factual keyword density
        let confidence = min(Float(factualWordCount) / Float(words.count) * 2.0, 1.0)
        
        guard confidence > 0.3 else { return nil }
        
        // Determine category based on semantic content
        let category = determineSemanticCategory(sentence, embedding: embedding)
        
        return FactualClaim(
            text: sentence,
            confidence: confidence,
            category: category,
            extractionMethod: .semanticAnalysis,
            context: sentence,
            position: ClaimPosition(
                startIndex: sentence.startIndex,
                endIndex: sentence.endIndex,
                characterRange: NSRange(location: 0, length: sentence.count)
            )
        )
    }
    
    private func determineSemanticCategory(_ sentence: String, embedding: NLEmbedding) -> ClaimCategory {
        let categoryKeywords: [ClaimCategory: [String]] = [
            .statistical: ["number", "percent", "population", "million", "billion", "thousand"],
            .geographical: ["located", "country", "city", "river", "mountain", "continent"],
            .historical: ["year", "century", "founded", "established", "war", "battle"],
            .scientific: ["temperature", "weight", "mass", "discovery", "element", "formula"],
            .biographical: ["born", "died", "age", "person", "author", "president", "leader"],
            .financial: ["cost", "price", "money", "dollar", "economy", "market"],
            .medical: ["disease", "treatment", "medicine", "health", "symptom", "therapy"]
        ]
        
        let words = sentence.lowercased().components(separatedBy: .whitespacesAndNewlines)
        
        var bestCategory: ClaimCategory = .general
        var maxScore = 0
        
        for (category, keywords) in categoryKeywords {
            let score = keywords.filter { keyword in
                words.contains { $0.contains(keyword) }
            }.count
            
            if score > maxScore {
                maxScore = score
                bestCategory = category
            }
        }
        
        return bestCategory
    }
}