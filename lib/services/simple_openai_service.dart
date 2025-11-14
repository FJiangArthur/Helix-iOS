// ABOUTME: Minimal OpenAI service for transcription and AI analysis
// ABOUTME: No complex architecture - just direct API calls that WORK

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class SimpleOpenAIService {
  final String apiKey;

  SimpleOpenAIService({required this.apiKey});

  /// Transcribe audio file using Whisper API
  /// Returns transcribed text or throws exception on error
  Future<String> transcribeAudio(String audioFilePath) async {
    try {
      print('[SimpleOpenAI] Starting transcription for: $audioFilePath');

      // Prepare multipart request
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('https://api.openai.com/v1/audio/transcriptions'),
      );

      request.headers['Authorization'] = 'Bearer $apiKey';

      // Add audio file
      request.files.add(
        await http.MultipartFile.fromPath('file', audioFilePath),
      );

      // Add model parameter
      request.fields['model'] = 'whisper-1';
      request.fields['language'] = 'en'; // Can be changed to auto-detect

      // Send request
      print('[SimpleOpenAI] Sending request to Whisper API...');
      var response = await request.send();
      var responseBody = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        var jsonResponse = json.decode(responseBody);
        String transcription = jsonResponse['text'] ?? '';
        print('[SimpleOpenAI] Transcription success: ${transcription.substring(0, transcription.length > 100 ? 100 : transcription.length)}...');
        return transcription;
      } else {
        print('[SimpleOpenAI] Transcription failed: ${response.statusCode} - $responseBody');
        throw Exception('Transcription failed: ${response.statusCode} - $responseBody');
      }
    } catch (e) {
      print('[SimpleOpenAI] Transcription error: $e');
      rethrow;
    }
  }

  /// Analyze text with ChatGPT
  /// Returns AI analysis or throws exception on error
  Future<String> analyzeText(String text, {String? prompt}) async {
    try {
      print('[SimpleOpenAI] Starting analysis for text (${text.length} chars)');

      final analysisPrompt = prompt ?? '''
Analyze this conversation and provide:
1. Brief summary (2-3 sentences)
2. Key points (bullet list)
3. Action items (if any)
4. Overall sentiment

Conversation:
$text
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
              'content': 'You are a helpful AI assistant analyzing conversations.'
            },
            {
              'role': 'user',
              'content': analysisPrompt,
            }
          ],
          'temperature': 0.7,
          'max_tokens': 500,
        }),
      );

      if (response.statusCode == 200) {
        var jsonResponse = json.decode(response.body);
        String analysis = jsonResponse['choices'][0]['message']['content'] ?? '';
        print('[SimpleOpenAI] Analysis success');
        return analysis;
      } else {
        print('[SimpleOpenAI] Analysis failed: ${response.statusCode} - ${response.body}');
        throw Exception('Analysis failed: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('[SimpleOpenAI] Analysis error: $e');
      rethrow;
    }
  }

  /// Check if API key is valid by making a simple request
  Future<bool> validateApiKey() async {
    try {
      var response = await http.get(
        Uri.parse('https://api.openai.com/v1/models'),
        headers: {
          'Authorization': 'Bearer $apiKey',
        },
      );
      return response.statusCode == 200;
    } catch (e) {
      print('[SimpleOpenAI] API key validation error: $e');
      return false;
    }
  }
}
