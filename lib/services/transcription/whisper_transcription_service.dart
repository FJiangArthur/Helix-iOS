import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'transcription_service.dart';
import 'transcription_models.dart';
import 'package:flutter_helix/utils/app_logger.dart';

/// OpenAI Whisper cloud transcription service (US 3.2)
/// Batches audio and sends to Whisper API for transcription
class WhisperTranscriptionService implements TranscriptionService {
  static WhisperTranscriptionService? _instance;
  static WhisperTranscriptionService get instance =>
      _instance ??= WhisperTranscriptionService._();

  WhisperTranscriptionService._();

  @override
  TranscriptionMode get mode => TranscriptionMode.whisper;

  String? _apiKey;
  bool _isInitialized = false;
  bool _isTranscribing = false;
  String? _currentLanguageCode;

  // Audio buffering
  final List<int> _audioBuffer = [];
  Timer? _batchTimer;
  static const int _batchIntervalSeconds = 5; // Batch every 5 seconds
  static const int _sampleRate = 16000; // 16kHz PCM
  static const int _bytesPerSecond = _sampleRate * 2; // 16-bit = 2 bytes
  static const int _minBatchBytes = _bytesPerSecond * 2; // Minimum 2 seconds

  // Statistics
  int _segmentCount = 0;
  int _totalCharacters = 0;
  DateTime? _startTime;
  final List<double> _confidenceScores = [];

  // Streams
  final _transcriptController =
      StreamController<TranscriptSegment>.broadcast();
  final _errorController = StreamController<TranscriptionError>.broadcast();

  @override
  bool get isAvailable => _isInitialized && _apiKey != null;

  @override
  bool get isTranscribing => _isTranscribing;

  @override
  Stream<TranscriptSegment> get transcriptStream =>
      _transcriptController.stream;

  @override
  Stream<TranscriptionError> get errorStream => _errorController.stream;

  /// Initialize with OpenAI API key
  Future<void> initializeWithKey(String apiKey) async {
    _apiKey = apiKey;
    await initialize();
  }

  @override
  Future<void> initialize() async {
    if (_apiKey == null || _apiKey!.isEmpty) {
      _isInitialized = false;
      _errorController.add(const TranscriptionError(
        type: TranscriptionErrorType.notAvailable,
        message: 'Whisper API key not configured',
      ));
      return;
    }

    // Validate API key by making a small test request
    try {
      final isValid = await _validateApiKey();
      _isInitialized = isValid;
      if (!isValid) {
        _errorController.add(const TranscriptionError(
          type: TranscriptionErrorType.apiError,
          message: 'Invalid Whisper API key',
        ));
      }
    } catch (e) {
      _isInitialized = false;
      _errorController.add(TranscriptionError(
        type: TranscriptionErrorType.networkError,
        message: 'Failed to validate Whisper API key',
        originalError: e,
      ));
    }
  }

  @override
  Future<void> startTranscription({String? languageCode}) async {
    if (!isAvailable) {
      _errorController.add(const TranscriptionError(
        type: TranscriptionErrorType.notAvailable,
        message: 'Whisper service not initialized',
      ));
      return;
    }

    if (_isTranscribing) {
      appLogger.i('Whisper transcription already running');
      return;
    }

    _currentLanguageCode = languageCode;
    _isTranscribing = true;
    _startTime = DateTime.now();
    _segmentCount = 0;
    _totalCharacters = 0;
    _confidenceScores.clear();
    _audioBuffer.clear();

    // Start batch processing timer
    _batchTimer = Timer.periodic(
      Duration(seconds: _batchIntervalSeconds),
      (_) => _processBatch(),
    );
  }

  @override
  Future<void> stopTranscription() async {
    if (!_isTranscribing) return;

    _isTranscribing = false;
    _batchTimer?.cancel();
    _batchTimer = null;

    // Process any remaining audio in buffer
    if (_audioBuffer.length >= _minBatchBytes) {
      await _processBatch();
    }

    _audioBuffer.clear();
  }

  @override
  void appendAudioData(Uint8List pcmData) {
    if (!_isTranscribing) return;
    _audioBuffer.addAll(pcmData);
  }

  /// Process accumulated audio batch
  Future<void> _processBatch() async {
    if (_audioBuffer.length < _minBatchBytes) {
      // Not enough audio yet
      return;
    }

    // Take audio from buffer
    final batchData = Uint8List.fromList(_audioBuffer);
    _audioBuffer.clear();

    try {
      // Convert PCM to WAV format required by Whisper
      final wavData = _pcmToWav(batchData);

      // Send to Whisper API
      final result = await _transcribeWithWhisper(wavData);

      if (result != null) {
        _processTranscript(result);
      }
    } catch (e) {
      _errorController.add(TranscriptionError(
        type: TranscriptionErrorType.apiError,
        message: 'Whisper transcription failed',
        originalError: e,
      ));
    }
  }

  /// Convert PCM audio to WAV format for Whisper API
  Uint8List _pcmToWav(Uint8List pcmData) {
    // WAV header structure
    const int numChannels = 1; // Mono
    const int bitsPerSample = 16;
    const int byteRate = _sampleRate * numChannels * bitsPerSample ~/ 8;
    const int blockAlign = numChannels * bitsPerSample ~/ 8;

    final int dataSize = pcmData.length;
    final int fileSize = 36 + dataSize;

    final buffer = ByteData(44 + dataSize);

    // RIFF header
    buffer.setUint8(0, 0x52); // 'R'
    buffer.setUint8(1, 0x49); // 'I'
    buffer.setUint8(2, 0x46); // 'F'
    buffer.setUint8(3, 0x46); // 'F'
    buffer.setUint32(4, fileSize, Endian.little);
    buffer.setUint8(8, 0x57); // 'W'
    buffer.setUint8(9, 0x41); // 'A'
    buffer.setUint8(10, 0x56); // 'V'
    buffer.setUint8(11, 0x45); // 'E'

    // fmt subchunk
    buffer.setUint8(12, 0x66); // 'f'
    buffer.setUint8(13, 0x6D); // 'm'
    buffer.setUint8(14, 0x74); // 't'
    buffer.setUint8(15, 0x20); // ' '
    buffer.setUint32(16, 16, Endian.little); // Subchunk1Size (16 for PCM)
    buffer.setUint16(20, 1, Endian.little); // AudioFormat (1 = PCM)
    buffer.setUint16(22, numChannels, Endian.little);
    buffer.setUint32(24, _sampleRate, Endian.little);
    buffer.setUint32(28, byteRate, Endian.little);
    buffer.setUint16(32, blockAlign, Endian.little);
    buffer.setUint16(34, bitsPerSample, Endian.little);

    // data subchunk
    buffer.setUint8(36, 0x64); // 'd'
    buffer.setUint8(37, 0x61); // 'a'
    buffer.setUint8(38, 0x74); // 't'
    buffer.setUint8(39, 0x61); // 'a'
    buffer.setUint32(40, dataSize, Endian.little);

    // Copy PCM data
    for (int i = 0; i < dataSize; i++) {
      buffer.setUint8(44 + i, pcmData[i]);
    }

    return buffer.buffer.asUint8List();
  }

  /// Send audio to Whisper API for transcription
  Future<Map<String, dynamic>?> _transcribeWithWhisper(
      Uint8List wavData) async {
    final url = Uri.parse('https://api.openai.com/v1/audio/transcriptions');

    final request = http.MultipartRequest('POST', url);
    request.headers['Authorization'] = 'Bearer $_apiKey';

    // Add audio file
    request.files.add(http.MultipartFile.fromBytes(
      'file',
      wavData,
      filename: 'audio.wav',
    ));

    // Add parameters
    request.fields['model'] = 'whisper-1';
    request.fields['response_format'] = 'verbose_json'; // Get confidence scores
    if (_currentLanguageCode != null) {
      // Extract language code (e.g., "en-US" -> "en")
      final langCode = _currentLanguageCode!.split('-').first;
      request.fields['language'] = langCode;
    }

    final response = await request.send();
    final responseBody = await response.stream.bytesToString();

    if (response.statusCode == 200) {
      return jsonDecode(responseBody) as Map<String, dynamic>;
    } else {
      throw Exception(
          'Whisper API error: ${response.statusCode} - $responseBody');
    }
  }

  void _processTranscript(Map<String, dynamic> result) {
    final text = result['text'] as String? ?? '';
    if (text.isEmpty) return;

    _segmentCount++;
    _totalCharacters += text.length;

    // Whisper doesn't always provide confidence, use a reasonable default
    const double defaultConfidence = 0.85;
    _confidenceScores.add(defaultConfidence);

    final segment = TranscriptSegment(
      text: text,
      confidence: defaultConfidence,
      timestamp: DateTime.now(),
      isFinal: true,
      source: TranscriptionMode.whisper,
    );

    _transcriptController.add(segment);
  }

  Future<bool> _validateApiKey() async {
    // We can't easily validate Whisper API key without audio
    // For now, assume it's valid if not empty
    return _apiKey != null && _apiKey!.isNotEmpty;
  }

  @override
  TranscriptionStats getStats() {
    final duration = _startTime != null
        ? DateTime.now().difference(_startTime!)
        : Duration.zero;

    final avgConfidence = _confidenceScores.isEmpty
        ? 0.0
        : _confidenceScores.reduce((a, b) => a + b) / _confidenceScores.length;

    return TranscriptionStats(
      segmentCount: _segmentCount,
      totalCharacters: _totalCharacters,
      totalDuration: duration,
      averageConfidence: avgConfidence,
      activeMode: mode,
    );
  }

  @override
  void dispose() {
    _batchTimer?.cancel();
    _transcriptController.close();
    _errorController.close();
    _isTranscribing = false;
    _audioBuffer.clear();
  }
}
