# Error Handling Guide

## Overview

This guide describes the standardized error handling patterns and best practices for the Helix iOS application. The error handling system provides consistent error types, structured logging, recovery strategies, and UI error boundaries.

## Table of Contents

1. [Error Handling Architecture](#error-handling-architecture)
2. [Error Types and Codes](#error-types-and-codes)
3. [Using the Result Type](#using-the-result-type)
4. [Error Recovery Strategies](#error-recovery-strategies)
5. [Error Logging](#error-logging)
6. [UI Error Handling](#ui-error-handling)
7. [Best Practices](#best-practices)
8. [Migration Guide](#migration-guide)

## Error Handling Architecture

The error handling system consists of several key components:

```
lib/core/errors/
├── app_error.dart          # Core error types and base classes
├── error_formatter.dart    # Error formatting utilities
├── error_logger.dart       # Centralized error logging
├── error_recovery.dart     # Recovery strategies and Result type
├── error_boundary.dart     # UI error boundaries
└── errors.dart            # Main export file
```

### Key Components

- **AppError**: Base error class with severity, category, and recovery information
- **Result\<T, E\>**: Type-safe result wrapper (inspired by Rust/Swift)
- **ErrorRecovery**: Utilities for retry, timeout, and fallback strategies
- **ErrorLogger**: Centralized logging with structured context
- **ErrorBoundary**: Flutter widgets for graceful UI error handling

## Error Types and Codes

### Error Categories

```dart
enum ErrorCategory {
  network,         // Network-related errors
  auth,           // Authentication/authorization
  api,            // API service errors
  bluetooth,      // BLE errors
  audio,          // Audio processing
  transcription,  // Transcription errors
  ai,             // AI/LLM errors
  storage,        // Storage/persistence
  validation,     // Input validation
  configuration,  // Configuration errors
  unknown,        // Unexpected errors
}
```

### Error Severity Levels

```dart
enum ErrorSeverity {
  debug,      // Development only
  info,       // Informational
  warning,    // Degraded functionality
  error,      // Feature failure
  critical,   // App-level failure
  fatal,      // Requires restart
}
```

### Standard Error Types

#### NetworkError
```dart
// No internet connection
throw NetworkError.noConnection();

// Request timeout
throw NetworkError.timeout(details: 'API took too long');

// Server error
throw NetworkError.serverError(
  statusCode: 500,
  details: 'Internal server error',
);
```

#### AuthError
```dart
// Invalid API key
throw AuthError.invalidApiKey(service: 'OpenAI');

// Unauthorized
throw AuthError.unauthorized();

// Permission denied
throw AuthError.permissionDenied(permission: 'microphone');
```

#### ApiError
```dart
// Rate limit exceeded
throw ApiError.rateLimitExceeded(retryAfter: '60s');

// Invalid request
throw ApiError.invalidRequest(details: 'Missing required field');

// Service unavailable
throw ApiError.serviceUnavailable(service: 'Whisper API');
```

#### BluetoothError
```dart
// Not connected
throw BluetoothError.notConnected();

// Connection timeout
throw BluetoothError.connectionTimeout();

// Device disconnected
throw BluetoothError.disconnected();
```

#### AIError
```dart
// Service not ready
throw AIError.notReady(service: 'OpenAI');

// Invalid response
throw AIError.invalidResponse(details: 'Failed to parse JSON');

// Model error
throw AIError.modelError(model: 'gpt-3.5', details: 'Token limit exceeded');
```

## Using the Result Type

The `Result<T, E>` type provides type-safe error handling without exceptions.

### Basic Usage

```dart
// Return a Result instead of throwing
Future<Result<String, NetworkError>> fetchData() async {
  return ErrorRecovery.tryCatchAsync(
    () async {
      final response = await http.get(url);
      return response.body;
    },
    operationName: 'fetchData',
  );
}

// Handle the result
final result = await fetchData();
result.fold(
  (data) => print('Success: $data'),
  (error) => print('Error: $error'),
);

// Or use pattern matching
if (result.isSuccess) {
  print('Data: ${result.value}');
} else {
  print('Error: ${result.error}');
}
```

### Chaining Operations

```dart
// Map transforms successful values
final result = await fetchData()
  .map((data) => data.toUpperCase());

// FlatMap chains multiple async operations
final result = await fetchUser()
  .flatMap((user) => fetchUserPosts(user.id));

// Execute side effects
result
  .onSuccess((data) => print('Got data'))
  .onFailure((error) => logError(error));
```

### Default Values

```dart
// Get value or default
final data = result.getOrDefault('fallback');

// Get value or compute default
final data = result.getOrElse(() => computeDefault());

// Get value or throw error
final data = result.getOrThrow();
```

## Error Recovery Strategies

### Retry with Exponential Backoff

```dart
final result = await ErrorRecovery.retryWithBackoff(
  operation: () => apiService.fetchData(),
  maxAttempts: 3,
  initialDelay: Duration(milliseconds: 500),
  backoffMultiplier: 2.0,
  shouldRetry: (error) => error is NetworkError,
);
```

### Timeout

```dart
final result = await ErrorRecovery.withTimeout(
  operation: () => apiService.fetchData(),
  timeout: Duration(seconds: 30),
  timeoutMessage: 'API request timed out',
);
```

### Fallback Strategy

```dart
final result = await ErrorRecovery.withFallback(
  primary: () => cloudService.transcribe(audio),
  fallback: () => localService.transcribe(audio),
  fallbackReason: 'Cloud service unavailable',
);
```

### First Success

```dart
final result = await ErrorRecovery.firstSuccess(
  operations: [
    () => provider1.analyze(text),
    () => provider2.analyze(text),
    () => provider3.analyze(text),
  ],
  operationName: 'AI Analysis',
);
```

### Circuit Breaker

```dart
final breaker = CircuitBreaker(
  name: 'APIService',
  failureThreshold: 5,
  timeout: Duration(seconds: 30),
  resetTimeout: Duration(minutes: 1),
);

final result = await breaker.execute(
  () => apiService.fetchData(),
);
```

## Error Logging

### Basic Logging

```dart
// Log any error
logError(
  error,
  stackTrace: stackTrace,
  context: {'userId': userId},
  source: 'UserService',
);
```

### Structured Logging

```dart
// Log specific error types with context
ErrorLogger.instance.logNetworkError(
  NetworkError.timeout(),
  url: 'https://api.example.com',
  method: 'POST',
  headers: {'Authorization': 'Bearer ...'},
);

ErrorLogger.instance.logApiError(
  ApiError.rateLimitExceeded(),
  endpoint: '/api/transcribe',
  method: 'POST',
  requestBody: jsonEncode(request),
  responseBody: response.body,
);

ErrorLogger.instance.logBluetoothError(
  BluetoothError.connectionTimeout(),
  deviceName: 'Helix Glasses',
  deviceId: deviceId,
  operation: 'connect',
);
```

### Error Handlers

```dart
// Register custom error handlers
ErrorLogger.instance.registerHandler(
  AnalyticsErrorHandler((errorData) {
    analytics.trackError(errorData);
  }),
);

ErrorLogger.instance.registerHandler(
  CrashReportingErrorHandler((error, stackTrace) {
    crashlytics.recordError(error, stackTrace);
  }),
);
```

### Full Error Report

```dart
// Create and log a comprehensive error report
ErrorLogger.instance.logErrorReport(
  error,
  stackTrace: stackTrace,
  context: {
    'userId': userId,
    'sessionId': sessionId,
    'appVersion': appVersion,
  },
);
```

## UI Error Handling

### Error Boundary Widget

```dart
// Wrap your widget tree with error boundary
class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ErrorBoundary(
      onError: (error, stackTrace) {
        // Custom error handling
        print('Error caught: $error');
      },
      showErrorDetails: kDebugMode,
      child: MaterialApp(
        home: HomeScreen(),
      ),
    );
  }
}
```

### Custom Error Widget

```dart
ErrorBoundary.withCustomError(
  errorBuilder: (context, error) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error, size: 64, color: Colors.red),
            SizedBox(height: 16),
            Text(error.message),
            if (error.isRecoverable)
              ElevatedButton(
                onPressed: () => retry(),
                child: Text('Retry'),
              ),
          ],
        ),
      ),
    );
  },
  child: MyWidget(),
);
```

### Error Snackbar

```dart
// Show error as snackbar
context.showErrorSnackbar(error);

// Or with custom duration
ErrorSnackbar.show(
  context,
  error,
  duration: Duration(seconds: 5),
);
```

### Error Dialog

```dart
// Show error dialog
await context.showErrorDialog(
  error,
  onRetry: () => retryOperation(),
  showDetails: true,
);

// Or directly
await ErrorDialog.show(
  context,
  NetworkError.noConnection(),
  onRetry: () => retryConnection(),
);
```

## Best Practices

### 1. Use Result Type for Expected Errors

```dart
// Good: Use Result for operations that can fail
Future<Result<User, AppError>> fetchUser(String id) async {
  return ErrorRecovery.tryCatchAsync(
    () async => await api.getUser(id),
    operationName: 'fetchUser',
    context: {'userId': id},
  );
}

// Avoid: Throwing exceptions for expected failures
Future<User> fetchUser(String id) async {
  throw Exception('User not found'); // ❌
}
```

### 2. Throw Specific Error Types

```dart
// Good: Throw specific, descriptive errors
if (apiKey.isEmpty) {
  throw AuthError.invalidApiKey(service: 'OpenAI');
}

// Avoid: Generic exceptions
if (apiKey.isEmpty) {
  throw Exception('Invalid API key'); // ❌
}
```

### 3. Include Context and Recovery Actions

```dart
// Good: Provide context and recovery guidance
throw NetworkError(
  code: 'NETWORK_TIMEOUT',
  message: 'Request timed out',
  details: 'The server took too long to respond',
  context: {
    'url': url,
    'timeout': timeout.inSeconds,
  },
  isRecoverable: true,
  recoveryAction: 'Check your internet connection and try again',
);
```

### 4. Log Errors with Structured Context

```dart
// Good: Include relevant context
logError(
  error,
  stackTrace: stackTrace,
  source: 'TranscriptionService',
  context: {
    'audioFilePath': path,
    'duration': duration.inSeconds,
    'mode': 'whisper',
  },
);

// Avoid: Minimal logging
print('Error: $error'); // ❌
```

### 5. Use Recovery Strategies

```dart
// Good: Implement retry logic
final result = await ErrorRecovery.retryWithBackoff(
  operation: () => api.sendData(),
  maxAttempts: 3,
  shouldRetry: (error) => error is NetworkError,
);

// Avoid: Manual retry without backoff
for (var i = 0; i < 3; i++) { // ❌
  try {
    await api.sendData();
    break;
  } catch (e) {
    // No delay, no backoff
  }
}
```

### 6. Handle Errors at Appropriate Levels

```dart
// Service layer: Return Results
Future<Result<Data, AppError>> fetchData() async {
  return ErrorRecovery.tryCatchAsync(() async {
    return await api.getData();
  });
}

// UI layer: Display errors to users
final result = await service.fetchData();
result.onFailure((error) {
  context.showErrorSnackbar(error);
});
```

### 7. Use Error Boundaries in UI

```dart
// Good: Wrap feature widgets
class FeatureScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ErrorBoundary.withDefaultError(
      child: FeatureContent(),
    );
  }
}
```

## Migration Guide

### Migrating from Map-based Errors

**Before:**
```dart
Future<Map<String, dynamic>> analyze(String text) async {
  try {
    final result = await api.analyze(text);
    return result;
  } catch (e) {
    return {'error': e.toString()};
  }
}

// Usage
final result = await service.analyze(text);
if (result.containsKey('error')) {
  print('Error: ${result['error']}');
}
```

**After:**
```dart
Future<Result<Map<String, dynamic>, AIError>> analyze(String text) async {
  return ErrorRecovery.tryCatchAsync(
    () async => await api.analyze(text),
    operationName: 'analyze',
    context: {'textLength': text.length},
  ).then((result) => result.mapError((error) => _toAIError(error)));
}

// Usage
final result = await service.analyze(text);
result.fold(
  (data) => print('Success: $data'),
  (error) => context.showErrorSnackbar(error),
);
```

### Migrating from Generic Exceptions

**Before:**
```dart
if (!isConnected) {
  throw Exception('Not connected to device');
}
```

**After:**
```dart
if (!isConnected) {
  throw BluetoothError.notConnected();
}
```

### Migrating Error Handling in UI

**Before:**
```dart
try {
  final data = await service.fetchData();
  setState(() => _data = data);
} catch (e) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Error: $e')),
  );
}
```

**After:**
```dart
final result = await service.fetchData();
result.fold(
  (data) => setState(() => _data = data),
  (error) => context.showErrorSnackbar(error),
);
```

## Error Code Reference

### Network Errors
- `NETWORK_NO_CONNECTION`: No internet connection
- `NETWORK_TIMEOUT`: Request timeout
- `NETWORK_SERVER_ERROR_XXX`: Server error with status code

### Authentication Errors
- `AUTH_INVALID_API_KEY`: Invalid API key
- `AUTH_UNAUTHORIZED`: Unauthorized access
- `AUTH_PERMISSION_DENIED`: Permission denied

### API Errors
- `API_RATE_LIMIT_EXCEEDED`: Rate limit exceeded
- `API_INVALID_REQUEST`: Invalid API request
- `API_SERVICE_UNAVAILABLE`: Service unavailable

### Bluetooth Errors
- `BLE_NOT_CONNECTED`: Device not connected
- `BLE_CONNECTION_TIMEOUT`: Connection timeout
- `BLE_DISCONNECTED`: Device disconnected
- `BLE_NOT_AVAILABLE`: Bluetooth not available

### Audio Errors
- `AUDIO_RECORDING_FAILED`: Recording failed
- `AUDIO_PLAYBACK_FAILED`: Playback failed
- `AUDIO_PERMISSION_DENIED`: Microphone permission denied

### Transcription Errors
- `TRANSCRIPTION_NOT_AVAILABLE`: Service not available
- `TRANSCRIPTION_FAILED`: Transcription failed

### AI Errors
- `AI_NOT_READY`: Service not initialized
- `AI_INVALID_RESPONSE`: Invalid response from AI
- `AI_MODEL_ERROR`: AI model error
- `AI_RATE_LIMIT_EXCEEDED`: Rate limit exceeded

### Storage Errors
- `STORAGE_READ_FAILED`: Failed to read data
- `STORAGE_WRITE_FAILED`: Failed to write data
- `STORAGE_FULL`: Storage is full

### Validation Errors
- `VALIDATION_INVALID_INPUT`: Invalid input
- `VALIDATION_REQUIRED_FIELD`: Required field missing

## Examples

### Complete Service Example

```dart
import 'package:flutter_helix/core/errors/errors.dart';

class UserService {
  final ApiClient _api;

  Future<Result<User, AppError>> getUser(String id) async {
    return ErrorRecovery.retryWithBackoff(
      operation: () async {
        final response = await _api.get('/users/$id');

        if (response.statusCode == 200) {
          return User.fromJson(response.data);
        } else if (response.statusCode == 404) {
          throw AppError(
            code: 'USER_NOT_FOUND',
            message: 'User not found',
            details: 'No user with ID: $id',
            category: ErrorCategory.api,
          );
        } else {
          throw ApiError.serverError(
            statusCode: response.statusCode,
            details: response.body,
          );
        }
      },
      maxAttempts: 3,
      shouldRetry: (error) => error is NetworkError,
    );
  }

  Future<Result<List<User>, AppError>> searchUsers(String query) async {
    return ErrorRecovery.tryCatchAsync(
      () async {
        final response = await _api.get('/users/search',
          queryParams: {'q': query},
        );
        return (response.data as List)
          .map((json) => User.fromJson(json))
          .toList();
      },
      operationName: 'UserService.searchUsers',
      context: {'query': query},
    );
  }
}
```

### Complete UI Example

```dart
class UserProfileScreen extends StatefulWidget {
  final String userId;

  const UserProfileScreen({required this.userId});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final _userService = UserService();
  User? _user;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    setState(() => _isLoading = true);

    final result = await _userService.getUser(widget.userId);

    if (!mounted) return;

    setState(() => _isLoading = false);

    result.fold(
      (user) => setState(() => _user = user),
      (error) {
        context.showErrorDialog(
          error,
          onRetry: _loadUser,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ErrorBoundary.withDefaultError(
      child: Scaffold(
        appBar: AppBar(title: Text('User Profile')),
        body: _isLoading
            ? Center(child: CircularProgressIndicator())
            : _user != null
                ? UserProfileContent(user: _user!)
                : Center(child: Text('No user data')),
      ),
    );
  }
}
```

## Summary

This error handling system provides:

✅ **Type-safe error handling** with Result types
✅ **Standardized error types** with codes and categories
✅ **Structured logging** with context
✅ **Recovery strategies** (retry, fallback, circuit breaker)
✅ **UI error boundaries** for graceful error display
✅ **Developer-friendly** error messages and formatting
✅ **User-friendly** error messages and recovery actions

For questions or issues, please refer to the inline documentation in the error handling modules.
