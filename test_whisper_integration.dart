#!/usr/bin/env dart

/// Test Whisper transcription endpoint
/// Run with: dart run test_whisper_integration.dart

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

void main() async {
  print('🎤 Testing Azure Whisper Transcription API');
  print('=' * 60);

  // Load config
  final configFile = File('llm_config.local.json');
  if (!await configFile.exists()) {
    print('❌ Error: llm_config.local.json not found!');
    exit(1);
  }

  final configJson = jsonDecode(await configFile.readAsString());
  final transcription = configJson['transcription'];
  final apiKey = configJson['llmApiKey'] as String;

  // Build endpoint URL
  final baseEndpoint = transcription['endpoint'] as String;
  final apiVersion = transcription['apiVersion'] as String;
  final endpoint = '$baseEndpoint?api-version=$apiVersion';

  print('📍 Endpoint: $endpoint');
  print('🔑 API Key: ${apiKey.substring(0, 10)}...');
  print('');

  // Test 1: Check if we have a sample audio file
  print('Test 1: Audio File Check');
  print('-' * 60);

  // Check for test audio file
  final testAudioFiles = [
    'test_audio.mp3',
    'test_audio.wav',
    'test_audio.m4a',
    '/tmp/test_audio.wav',
  ];

  File? audioFile;
  for (final path in testAudioFiles) {
    final file = File(path);
    if (await file.exists()) {
      audioFile = file;
      print('✅ Found test audio: $path');
      break;
    }
  }

  if (audioFile == null) {
    print('⚠️  No test audio file found');
    print('   Create a test audio file to test transcription');
    print('   Supported formats: mp3, wav, m4a, webm, mp4');
    print('');
    print('   You can record audio using:');
    print('   - macOS: QuickTime Player → File → New Audio Recording');
    print('   - iOS: Voice Memos app');
    print('   - Save as: test_audio.wav');
    print('');
    print('Skipping actual transcription test...');
    print('');
    testEndpointAvailability(endpoint, apiKey);
    return;
  }

  // Test 2: Transcribe audio
  print('');
  print('Test 2: Audio Transcription');
  print('-' * 60);
  try {
    final request = http.MultipartRequest('POST', Uri.parse(endpoint));

    // Add headers
    request.headers['api-key'] = apiKey;

    // Add audio file
    request.files.add(await http.MultipartFile.fromPath(
      'file',
      audioFile.path,
    ));

    // Add optional parameters
    request.fields['language'] = 'en'; // Optional: specify language
    request.fields['response_format'] = 'json'; // or 'text', 'srt', 'vtt'

    print('Uploading audio file...');
    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    print('Status: ${response.statusCode}');

    if (response.statusCode == 200) {
      print('✅ SUCCESS');
      final result = jsonDecode(response.body);
      print('');
      print('Transcription:');
      print(result['text']);
      print('');
      if (result.containsKey('duration')) {
        print('Duration: ${result['duration']}s');
      }
    } else {
      print('❌ FAILED');
      print('Response: ${response.body}');
    }
  } catch (e) {
    print('❌ EXCEPTION: $e');
  }

  print('');
  testEndpointAvailability(endpoint, apiKey);
}

void testEndpointAvailability(String endpoint, String apiKey) {
  print('Test 3: Endpoint Information');
  print('-' * 60);
  print('Endpoint URL: $endpoint');
  print('');
  print('To test transcription:');
  print('1. Record a short audio clip (5-10 seconds)');
  print('2. Save as test_audio.wav in project root');
  print('3. Run: dart run test_whisper_integration.dart');
  print('');
  print('Supported formats:');
  print('- WAV (recommended)');
  print('- MP3');
  print('- M4A');
  print('- WebM');
  print('- MP4');
  print('');
  print('Example cURL command:');
  print('''
curl -X POST "$endpoint" \\
  -H "api-key: $apiKey" \\
  -F "file=@test_audio.wav" \\
  -F "language=en" \\
  -F "response_format=json"
''');
}
