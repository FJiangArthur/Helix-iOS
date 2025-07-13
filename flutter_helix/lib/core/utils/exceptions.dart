// ABOUTME: Custom exception classes for different service types
// ABOUTME: Provides specific error types for better error handling and debugging

/// Base exception class for all Helix app exceptions
abstract class HelixException implements Exception {
  final String message;
  final Object? originalError;
  final StackTrace? stackTrace;

  const HelixException(
    this.message, {
    this.originalError,
    this.stackTrace,
  });

  @override
  String toString() {
    return '$runtimeType: $message';
  }
}

/// Audio service related exceptions
class AudioException extends HelixException {
  const AudioException(
    super.message, {
    super.originalError,
    super.stackTrace,
  });
}

class AudioPermissionDeniedException extends AudioException {
  const AudioPermissionDeniedException()
      : super('Microphone permission was denied. Please enable microphone access in settings.');
}

class AudioDeviceNotFoundException extends AudioException {
  const AudioDeviceNotFoundException()
      : super('No audio input device found. Please check your microphone connection.');
}

class AudioRecordingException extends AudioException {
  const AudioRecordingException(super.message, {super.originalError});
}

/// Transcription service related exceptions
class TranscriptionException extends HelixException {
  const TranscriptionException(
    super.message, {
    super.originalError,
    super.stackTrace,
  });
}

class SpeechRecognitionUnavailableException extends TranscriptionException {
  const SpeechRecognitionUnavailableException()
      : super('Speech recognition is not available on this device.');
}

class WhisperAPIException extends TranscriptionException {
  final int? statusCode;
  
  const WhisperAPIException(
    super.message, {
    this.statusCode,
    super.originalError,
  });
}

/// AI/LLM service related exceptions
class AIException extends HelixException {
  const AIException(
    super.message, {
    super.originalError,
    super.stackTrace,
  });
}

class APIKeyMissingException extends AIException {
  const APIKeyMissingException(String provider)
      : super('API key for $provider is missing. Please configure it in settings.');
}

class AIProviderException extends AIException {
  final String provider;
  final int? statusCode;
  
  const AIProviderException(
    this.provider,
    super.message, {
    this.statusCode,
    super.originalError,
  });
}

class RateLimitExceededException extends AIException {
  final Duration retryAfter;
  
  const RateLimitExceededException(this.retryAfter)
      : super('API rate limit exceeded. Please try again later.');
}

/// Bluetooth and glasses service related exceptions
class BluetoothException extends HelixException {
  const BluetoothException(
    super.message, {
    super.originalError,
    super.stackTrace,
  });
}

class BluetoothUnavailableException extends BluetoothException {
  const BluetoothUnavailableException()
      : super('Bluetooth is not available on this device.');
}

class BluetoothPermissionDeniedException extends BluetoothException {
  const BluetoothPermissionDeniedException()
      : super('Bluetooth permission was denied. Please enable Bluetooth access in settings.');
}

class GlassesConnectionException extends BluetoothException {
  const GlassesConnectionException(String message)
      : super('Failed to connect to Even Realities glasses: $message');
}

class GlassesNotFoundException extends BluetoothException {
  const GlassesNotFoundException()
      : super('No Even Realities glasses found. Please make sure they are powered on and nearby.');
}

/// Network related exceptions
class NetworkException extends HelixException {
  const NetworkException(
    super.message, {
    super.originalError,
    super.stackTrace,
  });
}

class NoInternetConnectionException extends NetworkException {
  const NoInternetConnectionException()
      : super('No internet connection available. Please check your network settings.');
}

class TimeoutException extends NetworkException {
  const TimeoutException(String operation)
      : super('$operation timed out. Please check your connection and try again.');
}

/// Settings and configuration related exceptions
class SettingsException extends HelixException {
  const SettingsException(
    super.message, {
    super.originalError,
    super.stackTrace,
  });
}

class ConfigurationException extends SettingsException {
  const ConfigurationException(String setting)
      : super('Invalid configuration for $setting. Please check your settings.');
}

/// Data persistence related exceptions
class DataException extends HelixException {
  const DataException(
    super.message, {
    super.originalError,
    super.stackTrace,
  });
}

class DatabaseException extends DataException {
  const DatabaseException(String operation, {Object? originalError})
      : super('Database error during $operation', originalError: originalError);
}

class SerializationException extends DataException {
  const SerializationException(String type, {Object? originalError})
      : super('Failed to serialize/deserialize $type', originalError: originalError);
}