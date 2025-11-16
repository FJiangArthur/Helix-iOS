// ABOUTME: Enhanced AI service with all features - fact-checking, sentiment, insights
// ABOUTME: Built on simple foundation but adds comprehensive analysis capabilities

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'analytics_service.dart';
import 'package:flutter_helix/utils/app_logger.dart';
import 'package:flutter_helix/core/errors/errors.dart';

/// AI analysis result
class AIAnalysisResult {
  final String? summary;
  final List<String>? keyPoints;
  final List<ActionItem>? actionItems;
  final SentimentResult? sentiment;
  final List<FactCheck>? factChecks;
  final Duration processingTime;
  final bool success;
  final String? error;

  AIAnalysisResult({
    this.summary,
    this.keyPoints,
    this.actionItems,
    this.sentiment,
    this.factChecks,
    required this.processingTime,
    required this.success,
    this.error,
  });

  Map<String, dynamic> toJson() => {
        'summary': summary,
        'key_points': keyPoints,
        'action_items': actionItems?.map((a) => a.toJson()).toList(),
        'sentiment': sentiment?.toJson(),
        'fact_checks': factChecks?.map((f) => f.toJson()).toList(),
        'processing_time_ms': processingTime.inMilliseconds,
        'success': success,
        'error': error,
      };
}

/// Action item extracted from conversation
class ActionItem {
  final String task;
  final String priority; // high, medium, low
  final String? assignee;
  final String? deadline;

  ActionItem({
    required this.task,
    required this.priority,
    this.assignee,
    this.deadline,
  });

  Map<String, dynamic> toJson() => {
        'task': task,
        'priority': priority,
        'assignee': assignee,
        'deadline': deadline,
      };
}

/// Sentiment analysis result
class SentimentResult {
  final String sentiment; // positive, negative, neutral
  final double score; // -1.0 to 1.0
  final List<String>? emotions;

  SentimentResult({
    required this.sentiment,
    required this.score,
    this.emotions,
  });

  Map<String, dynamic> toJson() => {
        'sentiment': sentiment,
        'score': score,
        'emotions': emotions,
      };
}

/// Fact check result
class FactCheck {
  final String claim;
  final String status; // verified, disputed, uncertain
  final double confidence; // 0.0 to 1.0
  final String? explanation;
  final List<String>? sources;

  FactCheck({
    required this.claim,
    required this.status,
    required this.confidence,
    this.explanation,
    this.sources,
  });

  Map<String, dynamic> toJson() => {
        'claim': claim,
        'status': status,
        'confidence': confidence,
        'explanation': explanation,
        'sources': sources,
      };
}

/// Enhanced AI service with all features
class EnhancedAIService {
  final String apiKey;
  final AnalyticsService _analytics = AnalyticsService.instance;

  EnhancedAIService({required this.apiKey});

  /// Transcribe audio using Whisper API
  Future<Result<String, TranscriptionServiceError>> transcribeAudio(String audioFilePath) async {
    final recordingId = DateTime.now().millisecondsSinceEpoch.toString();
    final startTime = DateTime.now();

    _analytics.trackTranscriptionStarted(
      recordingId: recordingId,
      mode: 'whisper',
    );

    appLogger.i('[EnhancedAI] Starting Whisper transcription: $audioFilePath');

    return ErrorRecovery.tryCatchAsync(
      () async {
        var request = http.MultipartRequest(
          'POST',
          Uri.parse('https://api.openai.com/v1/audio/transcriptions'),
        );

        request.headers['Authorization'] = 'Bearer $apiKey';
        request.files.add(
          await http.MultipartFile.fromPath('file', audioFilePath),
        );
        request.fields['model'] = 'whisper-1';
        request.fields['language'] = 'en';

        var response = await request.send();
        var responseBody = await response.stream.bytesToString();

        if (response.statusCode == 200) {
          var jsonResponse = json.decode(responseBody);
          String transcription = jsonResponse['text'] ?? '';

          final processingTime = DateTime.now().difference(startTime);

          _analytics.trackTranscriptionCompleted(
            recordingId: recordingId,
            mode: 'whisper',
            processingTime: processingTime,
            textLength: transcription.length,
            text: transcription,
          );

          appLogger.i('[EnhancedAI] Transcription completed (${processingTime.inSeconds}s): ${transcription.substring(0, transcription.length > 50 ? 50 : transcription.length)}...');

          return transcription;
        } else {
          _analytics.trackAPIError(
            api: 'whisper',
            statusCode: response.statusCode,
            error: responseBody,
          );

          if (response.statusCode == 401) {
            throw AuthError.invalidApiKey(service: 'Whisper');
          } else if (response.statusCode == 429) {
            throw ApiError.rateLimitExceeded();
          } else if (response.statusCode >= 500) {
            throw ApiError.serviceUnavailable(service: 'Whisper');
          } else {
            throw ApiError(
              code: 'WHISPER_API_ERROR',
              message: 'Transcription failed',
              details: responseBody,
              statusCode: response.statusCode,
              responseBody: responseBody,
            );
          }
        }
      },
      operationName: 'EnhancedAI.transcribeAudio',
      context: {'audioFilePath': audioFilePath, 'recordingId': recordingId},
    ).then((result) {
      result.onFailure((error) {
        _analytics.trackTranscriptionError(
          recordingId: recordingId,
          mode: 'whisper',
          error: error.toString(),
        );
      });

      return result.mapError((error) {
        if (error is TranscriptionServiceError) return error;
        return TranscriptionServiceError(
          code: error.code,
          message: error.message,
          details: error.details,
          originalError: error.originalError,
          stackTrace: error.stackTrace,
        );
      });
    });
  }

  /// Comprehensive analysis of conversation text
  Future<AIAnalysisResult> analyzeConversation(String text) async {
    final sessionId = DateTime.now().millisecondsSinceEpoch.toString();
    final startTime = DateTime.now();

    try {
      _analytics.trackAIAnalysisStarted(
        sessionId: sessionId,
        analysisType: 'comprehensive',
      );

      appLogger.i('[EnhancedAI] Starting comprehensive analysis...');

      // Build comprehensive prompt
      final prompt = '''
Analyze this conversation comprehensively. Provide a JSON response with:
1. Summary (2-3 sentences)
2. Key points (array of strings)
3. Action items (array of objects with: task, priority, assignee, deadline)
4. Sentiment (object with: sentiment, score, emotions)
5. Fact checks (array of objects with: claim, status, confidence, explanation, sources)

Conversation:
"""
$text
"""

Return ONLY valid JSON in this exact format:
{
  "summary": "Brief summary here",
  "key_points": ["Point 1", "Point 2", "Point 3"],
  "action_items": [
    {"task": "Task description", "priority": "high/medium/low", "assignee": "Person name or null", "deadline": "Date or null"}
  ],
  "sentiment": {
    "sentiment": "positive/negative/neutral",
    "score": 0.0,
    "emotions": ["emotion1", "emotion2"]
  },
  "fact_checks": [
    {
      "claim": "Factual claim",
      "status": "verified/disputed/uncertain",
      "confidence": 0.85,
      "explanation": "Explanation",
      "sources": ["source1", "source2"]
    }
  ]
}
''';

      var response = await http.post(
        Uri.parse('https://api.openai.com/v1/chat/completions'),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'model': 'gpt-3.5-turbo',
          'messages': [
            {
              'role': 'system',
              'content':
                  'You are a conversation analysis AI. Always respond with valid JSON.'
            },
            {'role': 'user', 'content': prompt}
          ],
          'temperature': 0.3,
          'max_tokens': 1500,
        }),
      );

      if (response.statusCode == 200) {
        var jsonResponse = json.decode(response.body);
        String analysisText = jsonResponse['choices'][0]['message']['content'] ?? '';

        // Extract JSON from response (may have markdown code blocks)
        String jsonText = analysisText;
        if (analysisText.contains('```json')) {
          jsonText = analysisText.split('```json')[1].split('```')[0].trim();
        } else if (analysisText.contains('```')) {
          jsonText = analysisText.split('```')[1].split('```')[0].trim();
        }

        try {
          var analysisData = json.decode(jsonText);

          // Parse action items
          List<ActionItem>? actionItems;
          if (analysisData['action_items'] != null) {
            actionItems = (analysisData['action_items'] as List)
                .map((item) => ActionItem(
                      task: item['task'] ?? '',
                      priority: item['priority'] ?? 'medium',
                      assignee: item['assignee'],
                      deadline: item['deadline'],
                    ))
                .toList();
          }

          // Parse sentiment
          SentimentResult? sentiment;
          if (analysisData['sentiment'] != null) {
            final sentData = analysisData['sentiment'];
            sentiment = SentimentResult(
              sentiment: sentData['sentiment'] ?? 'neutral',
              score: (sentData['score'] ?? 0.0).toDouble(),
              emotions: sentData['emotions'] != null
                  ? List<String>.from(sentData['emotions'])
                  : null,
            );
          }

          // Parse fact checks
          List<FactCheck>? factChecks;
          if (analysisData['fact_checks'] != null) {
            factChecks = (analysisData['fact_checks'] as List)
                .map((fact) => FactCheck(
                      claim: fact['claim'] ?? '',
                      status: fact['status'] ?? 'uncertain',
                      confidence: (fact['confidence'] ?? 0.5).toDouble(),
                      explanation: fact['explanation'],
                      sources: fact['sources'] != null
                          ? List<String>.from(fact['sources'])
                          : null,
                    ))
                .toList();
          }

          final processingTime = DateTime.now().difference(startTime);

          // Track analytics
          _analytics.trackAIAnalysisCompleted(
            sessionId: sessionId,
            analysisType: 'comprehensive',
            processingTime: processingTime,
            results: {
              'has_summary': analysisData['summary'] != null,
              'key_points_count': (analysisData['key_points'] as List?)?.length ?? 0,
              'action_items_count': actionItems?.length ?? 0,
              'has_sentiment': sentiment != null,
              'fact_checks_count': factChecks?.length ?? 0,
            },
          );

          if (factChecks != null && factChecks.isNotEmpty) {
            _analytics.trackFactCheckPerformed(
              claimsChecked: factChecks.length,
              verified: factChecks.where((f) => f.status == 'verified').length,
              disputed: factChecks.where((f) => f.status == 'disputed').length,
              uncertain: factChecks.where((f) => f.status == 'uncertain').length,
            );
          }

          if (sentiment != null || (analysisData['key_points'] as List?)?.isNotEmpty == true) {
            _analytics.trackInsightsGenerated(
              hasSummary: analysisData['summary'] != null,
              keyPoints: (analysisData['key_points'] as List?)?.length ?? 0,
              actionItems: actionItems?.length ?? 0,
              hasSentiment: sentiment != null,
            );
          }

          appLogger.i('[EnhancedAI] Analysis completed (${processingTime.inSeconds}s)');

          return AIAnalysisResult(
            summary: analysisData['summary'],
            keyPoints: analysisData['key_points'] != null
                ? List<String>.from(analysisData['key_points'])
                : null,
            actionItems: actionItems,
            sentiment: sentiment,
            factChecks: factChecks,
            processingTime: processingTime,
            success: true,
          );
        } catch (e) {
          appLogger.i('[EnhancedAI] JSON parsing error: $e');
          appLogger.i('[EnhancedAI] Response text: $analysisText');

          // Return partial result with raw text
          final processingTime = DateTime.now().difference(startTime);
          return AIAnalysisResult(
            summary: analysisText,
            processingTime: processingTime,
            success: false,
            error: 'Failed to parse JSON response: $e',
          );
        }
      } else {
        _analytics.trackAPIError(
          api: 'chatgpt',
          statusCode: response.statusCode,
          error: response.body,
        );
        throw Exception('Analysis failed: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      _analytics.trackAIAnalysisError(
        sessionId: sessionId,
        analysisType: 'comprehensive',
        error: e.toString(),
      );

      return AIAnalysisResult(
        processingTime: DateTime.now().difference(startTime),
        success: false,
        error: e.toString(),
      );
    }
  }

  /// Quick sentiment analysis only
  Future<SentimentResult> analyzeSentiment(String text) async {
    try {
      final prompt = '''
Analyze the sentiment of this text and respond with ONLY valid JSON:
{
  "sentiment": "positive/negative/neutral",
  "score": 0.5,
  "emotions": ["happy", "excited"]
}

Text: "$text"
''';

      var response = await http.post(
        Uri.parse('https://api.openai.com/v1/chat/completions'),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'model': 'gpt-3.5-turbo',
          'messages': [
            {
              'role': 'system',
              'content': 'You analyze sentiment. Respond only with valid JSON.'
            },
            {'role': 'user', 'content': prompt}
          ],
          'temperature': 0.3,
          'max_tokens': 200,
        }),
      );

      if (response.statusCode == 200) {
        var jsonResponse = json.decode(response.body);
        String resultText =
            jsonResponse['choices'][0]['message']['content'] ?? '';

        // Clean JSON
        if (resultText.contains('```')) {
          resultText = resultText.split('```')[1].replaceAll('json', '').trim();
        }

        var sentData = json.decode(resultText);

        return SentimentResult(
          sentiment: sentData['sentiment'] ?? 'neutral',
          score: (sentData['score'] ?? 0.0).toDouble(),
          emotions: sentData['emotions'] != null
              ? List<String>.from(sentData['emotions'])
              : null,
        );
      } else {
        throw Exception('Sentiment analysis failed: ${response.statusCode}');
      }
    } catch (e) {
      appLogger.i('[EnhancedAI] Sentiment analysis error: $e');
      return SentimentResult(sentiment: 'neutral', score: 0.0);
    }
  }

  /// Validate API key
  Future<bool> validateApiKey() async {
    try {
      var response = await http.get(
        Uri.parse('https://api.openai.com/v1/models'),
        headers: {'Authorization': 'Bearer $apiKey'},
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}
