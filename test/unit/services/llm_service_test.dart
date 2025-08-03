// ABOUTME: Unit tests for LLMService implementation
// ABOUTME: Tests AI analysis, fact-checking, sentiment analysis, and API integration

import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:dio/dio.dart';

import 'package:flutter_helix/services/implementations/llm_service_impl.dart';
import 'package:flutter_helix/services/llm_service.dart';
import 'package:flutter_helix/models/analysis_result.dart';
import 'package:flutter_helix/core/utils/exceptions.dart';
import '../../test_helpers.dart';

// Mock Dio for API testing
class MockDio extends Mock implements Dio {}
class MockResponse extends Mock implements Response {}

void main() {
  group('LLMService', () {
    late LLMServiceImpl llmService;
    late MockDio mockDio;
    
    setUp(() {
      mockDio = MockDio();
      llmService = LLMServiceImpl(dio: mockDio);
    });
    
    tearDown(() {
      llmService.dispose();
    });
    
    group('Initialization', () {
      test('should initialize with default OpenAI provider', () {
        expect(llmService.currentProvider, equals(LLMProvider.openai));
        expect(llmService.isInitialized, isTrue);
      });
      
      test('should switch between providers', () {
        // Test OpenAI
        llmService.setProvider(LLMProvider.openai);
        expect(llmService.currentProvider, equals(LLMProvider.openai));
        
        // Test Anthropic
        llmService.setProvider(LLMProvider.anthropic);
        expect(llmService.currentProvider, equals(LLMProvider.anthropic));
      });
      
      test('should validate API keys for different providers', () {
        // Valid OpenAI key
        expect(llmService.isValidAPIKey(TestHelpers.testOpenAIKey, LLMProvider.openai), isTrue);
        
        // Valid Anthropic key
        expect(llmService.isValidAPIKey(TestHelpers.testAnthropicKey, LLMProvider.anthropic), isTrue);
        
        // Invalid keys
        expect(llmService.isValidAPIKey('invalid-key', LLMProvider.openai), isFalse);
        expect(llmService.isValidAPIKey('wrong-prefix', LLMProvider.anthropic), isFalse);
      });
    });
    
    group('Conversation Analysis', () {
      test('should analyze conversation with comprehensive analysis', () async {
        // Arrange
        const conversationText = 'We discussed the quarterly budget and decided to increase marketing spend by 20%.';
        
        final mockResponse = MockResponse();
        when(mockResponse.statusCode).thenReturn(200);
        when(mockResponse.data).thenReturn({
          'choices': [{
            'message': {
              'content': '''
              {
                "summary": "Team discussed quarterly budget allocation",
                "keyPoints": ["Budget discussion", "Marketing increase"],
                "factChecks": [],
                "actionItems": [],
                "sentiment": "positive",
                "confidence": 0.89
              }
              '''
            }
          }]
        });
        
        when(mockDio.post(any, data: any, options: any))
            .thenAnswer((_) async => mockResponse);
        
        // Act
        final result = await llmService.analyzeConversation(
          conversationText,
          type: AnalysisType.comprehensive,
        );
        
        // Assert
        expect(result, isA<AnalysisResult>());
        expect(result.summary, contains('budget'));
        expect(result.confidence, greaterThan(0.8));
      });
      
      test('should handle different analysis types', () async {
        const conversationText = 'The product launch went well. Sales exceeded expectations.';
        
        // Mock response for fact-checking only
        final mockResponse = MockResponse();
        when(mockResponse.statusCode).thenReturn(200);
        when(mockResponse.data).thenReturn({
          'choices': [{
            'message': {'content': '{"factChecks": [], "confidence": 0.85}'}
          }]
        });
        
        when(mockDio.post(any, data: any, options: any))
            .thenAnswer((_) async => mockResponse);
        
        // Test fact-checking analysis
        final factCheckResult = await llmService.analyzeConversation(
          conversationText,
          type: AnalysisType.factChecking,
        );
        
        expect(factCheckResult, isA<AnalysisResult>());
      });
      
      test('should cache analysis results for identical inputs', () async {
        // Arrange
        const conversationText = 'Test conversation for caching';
        
        final mockResponse = MockResponse();
        when(mockResponse.statusCode).thenReturn(200);
        when(mockResponse.data).thenReturn({
          'choices': [{
            'message': {'content': '{"summary": "Test", "confidence": 0.9}'}
          }]
        });
        
        when(mockDio.post(any, data: any, options: any))
            .thenAnswer((_) async => mockResponse);
        
        // Act - First call
        final result1 = await llmService.analyzeConversation(conversationText);
        
        // Act - Second call (should use cache)
        final result2 = await llmService.analyzeConversation(conversationText);
        
        // Assert
        expect(result1.summary, equals(result2.summary));
        verify(mockDio.post(any, data: any, options: any)).called(1); // Only one API call
      });
    });
    
    group('Fact Checking', () {
      test('should extract and verify factual claims', () async {
        // Arrange
        const conversationText = 'The iPhone was first released in 2007 and changed the smartphone industry.';
        
        final mockResponse = MockResponse();
        when(mockResponse.statusCode).thenReturn(200);
        when(mockResponse.data).thenReturn({
          'choices': [{
            'message': {
              'content': '''
              {
                "factChecks": [{
                  "claim": "The iPhone was first released in 2007",
                  "status": "verified",
                  "confidence": 0.98,
                  "sources": ["Apple Inc.", "Wikipedia"],
                  "explanation": "Apple announced the iPhone on January 9, 2007"
                }],
                "confidence": 0.95
              }
              '''
            }
          }]
        });
        
        when(mockDio.post(any, data: any, options: any))
            .thenAnswer((_) async => mockResponse);
        
        // Act
        final factChecks = await llmService.checkFacts(conversationText);
        
        // Assert
        expect(factChecks, isNotEmpty);
        expect(factChecks.first.claim, contains('iPhone'));
        expect(factChecks.first.status, equals(FactCheckStatus.verified));
        expect(factChecks.first.confidence, greaterThan(0.9));
      });
      
      test('should handle disputed claims', () async {
        // Arrange
        const conversationText = 'Electric cars produce zero emissions whatsoever.';
        
        final mockResponse = MockResponse();
        when(mockResponse.statusCode).thenReturn(200);
        when(mockResponse.data).thenReturn({
          'choices': [{
            'message': {
              'content': '''
              {
                "factChecks": [{
                  "claim": "Electric cars produce zero emissions whatsoever",
                  "status": "disputed",
                  "confidence": 0.82,
                  "sources": ["EPA", "Scientific studies"],
                  "explanation": "Electric cars produce no direct emissions but electricity generation may create emissions"
                }]
              }
              '''
            }
          }]
        });
        
        when(mockDio.post(any, data: any, options: any))
            .thenAnswer((_) async => mockResponse);
        
        // Act
        final factChecks = await llmService.checkFacts(conversationText);
        
        // Assert
        expect(factChecks.first.status, equals(FactCheckStatus.disputed));
        expect(factChecks.first.explanation, isNotEmpty);
      });
    });
    
    group('Sentiment Analysis', () {
      test('should analyze positive sentiment', () async {
        // Arrange
        const conversationText = 'I am extremely happy with the results! This is fantastic news.';
        
        final mockResponse = MockResponse();
        when(mockResponse.statusCode).thenReturn(200);
        when(mockResponse.data).thenReturn({
          'choices': [{
            'message': {
              'content': '''
              {
                "sentiment": {
                  "overallSentiment": "positive",
                  "confidence": 0.94,
                  "emotions": {
                    "happiness": 0.9,
                    "excitement": 0.8,
                    "satisfaction": 0.85
                  }
                }
              }
              '''
            }
          }]
        });
        
        when(mockDio.post(any, data: any, options: any))
            .thenAnswer((_) async => mockResponse);
        
        // Act
        final sentiment = await llmService.analyzeSentiment(conversationText);
        
        // Assert
        expect(sentiment.overallSentiment, equals(SentimentType.positive));
        expect(sentiment.confidence, greaterThan(0.9));
        expect(sentiment.emotions['happiness'], greaterThan(0.8));
      });
      
      test('should analyze negative sentiment', () async {
        // Arrange
        const conversationText = 'This is disappointing. I am very frustrated with these results.';
        
        final mockResponse = MockResponse();
        when(mockResponse.statusCode).thenReturn(200);
        when(mockResponse.data).thenReturn({
          'choices': [{
            'message': {
              'content': '''
              {
                "sentiment": {
                  "overallSentiment": "negative", 
                  "confidence": 0.88,
                  "emotions": {
                    "frustration": 0.85,
                    "disappointment": 0.9,
                    "anger": 0.4
                  }
                }
              }
              '''
            }
          }]
        });
        
        when(mockDio.post(any, data: any, options: any))
            .thenAnswer((_) async => mockResponse);
        
        // Act
        final sentiment = await llmService.analyzeSentiment(conversationText);
        
        // Assert
        expect(sentiment.overallSentiment, equals(SentimentType.negative));
        expect(sentiment.emotions['frustration'], greaterThan(0.8));
      });
    });
    
    group('Action Item Extraction', () {
      test('should extract action items with priorities and assignments', () async {
        // Arrange
        const conversationText = '''
        We need to review the budget by Friday. John should prepare the presentation for next week's board meeting.
        Someone needs to follow up with the client about their requirements.
        ''';
        
        final mockResponse = MockResponse();
        when(mockResponse.statusCode).thenReturn(200);
        when(mockResponse.data).thenReturn({
          'choices': [{
            'message': {
              'content': '''
              {
                "actionItems": [
                  {
                    "id": "action-1",
                    "description": "Review the budget",
                    "dueDate": "2024-01-26T17:00:00Z",
                    "priority": "high",
                    "confidence": 0.92,
                    "status": "pending"
                  },
                  {
                    "id": "action-2", 
                    "description": "Prepare presentation for board meeting",
                    "assignee": "John",
                    "priority": "medium",
                    "confidence": 0.89,
                    "status": "pending"
                  }
                ]
              }
              '''
            }
          }]
        });
        
        when(mockDio.post(any, data: any, options: any))
            .thenAnswer((_) async => mockResponse);
        
        // Act
        final actionItems = await llmService.extractActionItems(conversationText);
        
        // Assert
        expect(actionItems.length, equals(2));
        expect(actionItems.first.description, contains('budget'));
        expect(actionItems.first.priority, equals(ActionItemPriority.high));
        expect(actionItems[1].assignee, equals('John'));
      });
    });
    
    group('API Error Handling', () {
      test('should handle API rate limiting', () async {
        // Arrange
        when(mockDio.post(any, data: any, options: any))
            .thenThrow(DioException(
              requestOptions: RequestOptions(path: '/api'),
              response: Response(
                statusCode: 429,
                requestOptions: RequestOptions(path: '/api'),
                data: {'error': 'Rate limit exceeded'},
              ),
            ));
        
        // Act & Assert
        expect(
          () async => await llmService.analyzeConversation('test'),
          throwsA(isA<LLMException>()),
        );
      });
      
      test('should handle invalid API key', () async {
        // Arrange
        when(mockDio.post(any, data: any, options: any))
            .thenThrow(DioException(
              requestOptions: RequestOptions(path: '/api'),
              response: Response(
                statusCode: 401,
                requestOptions: RequestOptions(path: '/api'),
                data: {'error': 'Invalid API key'},
              ),
            ));
        
        // Act & Assert
        expect(
          () async => await llmService.analyzeConversation('test'),
          throwsA(isA<LLMException>()),
        );
      });
      
      test('should handle network connectivity issues', () async {
        // Arrange
        when(mockDio.post(any, data: any, options: any))
            .thenThrow(DioException(
              requestOptions: RequestOptions(path: '/api'),
              type: DioExceptionType.connectionTimeout,
              message: 'Connection timeout',
            ));
        
        // Act & Assert
        expect(
          () async => await llmService.analyzeConversation('test'),
          throwsA(isA<LLMException>()),
        );
      });
      
      test('should handle malformed API responses', () async {
        // Arrange
        final mockResponse = MockResponse();
        when(mockResponse.statusCode).thenReturn(200);
        when(mockResponse.data).thenReturn({'invalid': 'response'});
        
        when(mockDio.post(any, data: any, options: any))
            .thenAnswer((_) async => mockResponse);
        
        // Act & Assert
        expect(
          () async => await llmService.analyzeConversation('test'),
          throwsA(isA<LLMException>()),
        );
      });
    });
    
    group('Performance Optimization', () {
      test('should respect rate limiting', () async {
        // Arrange
        final startTime = DateTime.now();
        
        final mockResponse = MockResponse();
        when(mockResponse.statusCode).thenReturn(200);
        when(mockResponse.data).thenReturn({
          'choices': [{'message': {'content': '{"summary": "test"}'}}]
        });
        
        when(mockDio.post(any, data: any, options: any))
            .thenAnswer((_) async => mockResponse);
        
        // Act - Multiple rapid requests
        final futures = List.generate(5, (index) => 
          llmService.analyzeConversation('test conversation $index')
        );
        
        await Future.wait(futures);
        
        final endTime = DateTime.now();
        final duration = endTime.difference(startTime);
        
        // Assert - Should take some time due to rate limiting
        expect(duration.inMilliseconds, greaterThan(100));
      });
      
      test('should handle large conversation texts efficiently', () async {
        // Arrange
        final largeText = List.generate(1000, (index) => 'Word $index').join(' ');
        
        final mockResponse = MockResponse();
        when(mockResponse.statusCode).thenReturn(200);
        when(mockResponse.data).thenReturn({
          'choices': [{'message': {'content': '{"summary": "Large text analysis"}'}}]
        });
        
        when(mockDio.post(any, data: any, options: any))
            .thenAnswer((_) async => mockResponse);
        
        // Act
        final startTime = DateTime.now();
        final result = await llmService.analyzeConversation(largeText);
        final endTime = DateTime.now();
        
        // Assert
        expect(result, isA<AnalysisResult>());
        expect(endTime.difference(startTime).inSeconds, lessThan(30));
      });
    });
    
    group('Configuration', () {
      test('should configure analysis parameters', () {
        // Test confidence threshold
        llmService.setConfidenceThreshold(0.8);
        expect(llmService.confidenceThreshold, equals(0.8));
        
        // Test temperature setting
        llmService.setTemperature(0.7);
        expect(llmService.temperature, equals(0.7));
        
        // Test max tokens
        llmService.setMaxTokens(2000);
        expect(llmService.maxTokens, equals(2000));
      });
      
      test('should validate configuration parameters', () {
        // Invalid confidence threshold
        expect(() => llmService.setConfidenceThreshold(1.5), throwsArgumentError);
        expect(() => llmService.setConfidenceThreshold(-0.1), throwsArgumentError);
        
        // Invalid temperature
        expect(() => llmService.setTemperature(2.5), throwsArgumentError);
        expect(() => llmService.setTemperature(-0.1), throwsArgumentError);
        
        // Invalid max tokens
        expect(() => llmService.setMaxTokens(-100), throwsArgumentError);
      });
    });
    
    group('Resource Management', () {
      test('should dispose resources properly', () {
        // Arrange
        llmService.analyzeConversation('test'); // Start some operation
        
        // Act
        llmService.dispose();
        
        // Assert
        expect(llmService.isDisposed, isTrue);
      });
      
      test('should clear cache on demand', () {
        // Arrange - Assume cache has entries (would be set by previous operations)
        
        // Act
        llmService.clearCache();
        
        // Assert - Cache should be empty (implementation-specific verification)
        expect(llmService.cacheSize, equals(0));
      });
    });
  });
}