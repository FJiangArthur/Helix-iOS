import 'dart:io';
import 'dart:typed_data';

/// Manages audio data buffering and file operations for EvenAI
class AudioBufferManager {
  AudioBufferManager._();

  static AudioBufferManager? _instance;
  static AudioBufferManager get instance => _instance ??= AudioBufferManager._();

  // Audio buffer
  List<int> _audioDataBuffer = [];
  Uint8List? _audioData;

  // Audio files
  File? _lc3File;
  File? _pcmFile;
  int _durationS = 0;

  bool _isReceiving = false;

  /// Get current audio buffer
  List<int> get audioBuffer => List.unmodifiable(_audioDataBuffer);

  /// Get audio data
  Uint8List? get audioData => _audioData;

  /// Get LC3 file
  File? get lc3File => _lc3File;

  /// Get PCM file
  File? get pcmFile => _pcmFile;

  /// Get audio duration in seconds
  int get durationSeconds => _durationS;

  /// Check if currently receiving audio
  bool get isReceiving => _isReceiving;

  /// Start receiving audio data
  void startReceiving() {
    _isReceiving = true;
    _audioDataBuffer.clear();
  }

  /// Stop receiving audio data
  void stopReceiving() {
    _isReceiving = false;
  }

  /// Append audio data to buffer
  void appendData(List<int> data) {
    if (_isReceiving) {
      _audioDataBuffer.addAll(data);
    }
  }

  /// Get buffered audio data size in bytes
  int get bufferSize => _audioDataBuffer.length;

  /// Check if buffer is empty
  bool get isEmpty => _audioDataBuffer.isEmpty;

  /// Finalize audio data and convert to Uint8List
  Uint8List finalizeAudioData() {
    _audioData = Uint8List.fromList(_audioDataBuffer);
    return _audioData!;
  }

  /// Set LC3 audio file
  void setLc3File(File file) {
    _lc3File = file;
  }

  /// Set PCM audio file
  void setPcmFile(File file) {
    _pcmFile = file;
  }

  /// Set audio duration
  void setDuration(int seconds) {
    _durationS = seconds;
  }

  /// Clear all audio data and reset state
  void clear() {
    _audioDataBuffer.clear();
    _audioData = null;
    _lc3File = null;
    _pcmFile = null;
    _durationS = 0;
    _isReceiving = false;
  }

  /// Dispose resources
  void dispose() {
    clear();
  }
}
