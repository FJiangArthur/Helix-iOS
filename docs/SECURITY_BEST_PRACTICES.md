# Security Best Practices Guide

This guide provides comprehensive security best practices for developing the Helix iOS application. All developers should be familiar with these guidelines.

## Table of Contents

1. [Authentication & Authorization](#authentication--authorization)
2. [Data Protection](#data-protection)
3. [Secure Communication](#secure-communication)
4. [Input Validation](#input-validation)
5. [Secrets Management](#secrets-management)
6. [Mobile-Specific Security](#mobile-specific-security)
7. [Dependency Security](#dependency-security)
8. [Code Quality & Security](#code-quality--security)
9. [Testing Security](#testing-security)
10. [Privacy & Compliance](#privacy--compliance)

---

## Authentication & Authorization

### Session Management

**DO:**
- Implement secure session token generation using cryptographically secure random generators
- Store session tokens securely using platform-specific secure storage (Keychain/KeyStore)
- Implement automatic session timeout and renewal
- Clear sensitive data from memory when session ends

```dart
// ✅ GOOD: Using secure storage
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureSessionManager {
  final _secureStorage = const FlutterSecureStorage();

  Future<void> saveSession(String token) async {
    await _secureStorage.write(
      key: 'session_token',
      value: token,
      iOptions: IOSOptions(
        accessibility: KeychainAccessibility.first_unlock,
      ),
      aOptions: AndroidOptions(
        encryptedSharedPreferences: true,
      ),
    );
  }

  Future<String?> getSession() async {
    return await _secureStorage.read(key: 'session_token');
  }

  Future<void> clearSession() async {
    await _secureStorage.delete(key: 'session_token');
  }
}
```

**DON'T:**
- Store session tokens in SharedPreferences or UserDefaults
- Use predictable session IDs
- Store authentication credentials in plaintext

```dart
// ❌ BAD: Insecure storage
final prefs = await SharedPreferences.getInstance();
await prefs.setString('session_token', token); // NEVER DO THIS
```

### Password Handling

**DO:**
- Use platform-provided biometric authentication when available
- Implement proper password strength requirements
- Use secure password hashing algorithms (bcrypt, argon2, scrypt)
- Never log or display passwords

```dart
// ✅ GOOD: Using biometric authentication
import 'package:local_auth/local_auth.dart';

class BiometricAuth {
  final LocalAuthentication _auth = LocalAuthentication();

  Future<bool> authenticateUser() async {
    try {
      final canCheckBiometrics = await _auth.canCheckBiometrics;
      if (!canCheckBiometrics) return false;

      return await _auth.authenticate(
        localizedReason: 'Authenticate to access Helix',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
    } catch (e) {
      return false;
    }
  }
}
```

**DON'T:**
- Store passwords in any form (even encrypted)
- Implement custom password hashing
- Allow weak passwords

---

## Data Protection

### Encryption at Rest

**DO:**
- Encrypt all sensitive data before storing locally
- Use platform-provided encryption APIs
- Implement data classification (public, internal, confidential, restricted)
- Enable file protection on iOS and Android

```dart
// ✅ GOOD: Encrypting sensitive data
import 'package:encrypt/encrypt.dart';

class DataEncryption {
  late final Key _key;
  late final IV _iv;
  late final Encrypter _encrypter;

  DataEncryption() {
    _key = Key.fromSecureRandom(32);
    _iv = IV.fromSecureRandom(16);
    _encrypter = Encrypter(AES(_key, mode: AESMode.gcm));
  }

  String encryptData(String plaintext) {
    final encrypted = _encrypter.encrypt(plaintext, iv: _iv);
    return encrypted.base64;
  }

  String decryptData(String ciphertext) {
    final encrypted = Encrypted.fromBase64(ciphertext);
    return _encrypter.decrypt(encrypted, iv: _iv);
  }
}
```

**DON'T:**
- Store PII (Personally Identifiable Information) without encryption
- Use ECB mode for AES encryption
- Hardcode encryption keys

### Data Sanitization

**DO:**
- Clear sensitive data from memory after use
- Overwrite sensitive variables before disposal
- Implement secure data deletion

```dart
// ✅ GOOD: Clearing sensitive data
class SecureDataHandler {
  String? _sensitiveData;

  void processData(String data) {
    _sensitiveData = data;
    // Process data...
  }

  void dispose() {
    if (_sensitiveData != null) {
      // Overwrite sensitive data
      _sensitiveData = '\x00' * _sensitiveData!.length;
      _sensitiveData = null;
    }
  }
}
```

---

## Secure Communication

### Network Security

**DO:**
- Use HTTPS for all network communications
- Implement certificate pinning for critical APIs
- Validate SSL/TLS certificates
- Use TLS 1.2 or higher

```dart
// ✅ GOOD: Certificate pinning with Dio
import 'package:dio/dio.dart';
import 'package:dio/io.dart';

class SecureHttpClient {
  late Dio _dio;

  SecureHttpClient() {
    _dio = Dio(BaseOptions(
      baseUrl: 'https://api.helix-app.com',
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ));

    // Configure certificate pinning
    (_dio.httpClientAdapter as IOHttpClientAdapter).onHttpClientCreate =
      (client) {
      client.badCertificateCallback = (cert, host, port) {
        // Implement certificate pinning validation
        return _validateCertificate(cert, host);
      };
      return client;
    };
  }

  bool _validateCertificate(X509Certificate cert, String host) {
    // Validate against pinned certificates
    final expectedFingerprint = 'YOUR_CERTIFICATE_FINGERPRINT';
    final certFingerprint = cert.sha256.toString();
    return certFingerprint == expectedFingerprint;
  }
}
```

**DON'T:**
- Allow HTTP connections in production
- Disable certificate validation
- Trust all certificates

```dart
// ❌ BAD: Disabling certificate validation
client.badCertificateCallback = (cert, host, port) => true; // NEVER DO THIS
```

### API Security

**DO:**
- Implement request signing
- Use API keys securely
- Implement rate limiting on client side
- Validate server responses

```dart
// ✅ GOOD: Secure API request with signature
class SecureApiClient {
  Future<Response> makeSecureRequest(String endpoint, Map<String, dynamic> data) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final signature = _generateSignature(endpoint, data, timestamp);

    return await _dio.post(
      endpoint,
      data: data,
      options: Options(
        headers: {
          'X-Request-Timestamp': timestamp.toString(),
          'X-Request-Signature': signature,
          'Content-Type': 'application/json',
        },
      ),
    );
  }

  String _generateSignature(String endpoint, Map<String, dynamic> data, int timestamp) {
    // Implement HMAC-SHA256 signature
    // ...
  }
}
```

---

## Input Validation

### User Input Sanitization

**DO:**
- Validate all user input on the client side
- Sanitize input before processing
- Use allowlists instead of blocklists
- Implement proper error handling

```dart
// ✅ GOOD: Input validation
class InputValidator {
  static final _emailRegex = RegExp(
    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
  );

  static final _phoneRegex = RegExp(r'^\+?[1-9]\d{1,14}$');

  static bool isValidEmail(String email) {
    if (email.isEmpty || email.length > 254) return false;
    return _emailRegex.hasMatch(email);
  }

  static bool isValidPhone(String phone) {
    final sanitized = phone.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    return _phoneRegex.hasMatch(sanitized);
  }

  static String sanitizeInput(String input) {
    // Remove dangerous characters
    return input
        .replaceAll(RegExp(r'[<>"\']'), '')
        .trim();
  }
}
```

**DON'T:**
- Trust user input without validation
- Use client-side validation as the only security measure
- Allow arbitrary file uploads without validation

---

## Secrets Management

### API Keys and Credentials

**DO:**
- Use environment variables for configuration
- Store secrets in secure storage, never in code
- Use different keys for development and production
- Rotate credentials regularly

```dart
// ✅ GOOD: Loading API keys from environment/secure storage
class ApiConfig {
  static Future<String> getApiKey() async {
    const storage = FlutterSecureStorage();

    // Try to get from secure storage first
    String? apiKey = await storage.read(key: 'api_key');

    if (apiKey == null) {
      // Fallback to environment variable for development
      apiKey = const String.fromEnvironment('API_KEY');

      if (apiKey.isNotEmpty) {
        // Cache in secure storage
        await storage.write(key: 'api_key', value: apiKey);
      }
    }

    return apiKey ?? '';
  }
}
```

**DON'T:**
- Hardcode API keys or secrets in code
- Commit secrets to version control
- Use production credentials in development

```dart
// ❌ BAD: Hardcoded secrets
const String API_KEY = "sk_live_1234567890abcdef"; // NEVER DO THIS
const String DATABASE_PASSWORD = "admin123"; // NEVER DO THIS
```

### Secret Detection Prevention

**DO:**
- Use pre-commit hooks to detect secrets
- Enable secret scanning in CI/CD
- Use `.gitignore` to exclude sensitive files

```bash
# ✅ GOOD: .gitignore for secrets
# Secrets and credentials
.env
.env.local
*.key
*.pem
credentials.json
google-services.json
GoogleService-Info.plist
firebase_options.dart

# Local configuration
settings.local.json
llm_config.local.json
```

---

## Mobile-Specific Security

### iOS Security

**DO:**
- Use Keychain for sensitive data storage
- Enable App Transport Security (ATS)
- Implement jailbreak detection for sensitive features
- Use secure coding practices for Objective-C/Swift code

```dart
// ✅ GOOD: Jailbreak detection
import 'dart:io';

class SecurityChecks {
  static Future<bool> isDeviceJailbroken() async {
    if (!Platform.isIOS) return false;

    // Check for common jailbreak indicators
    final jailbreakPaths = [
      '/Applications/Cydia.app',
      '/Library/MobileSubstrate/MobileSubstrate.dylib',
      '/bin/bash',
      '/usr/sbin/sshd',
      '/etc/apt',
      '/private/var/lib/apt/',
    ];

    for (final path in jailbreakPaths) {
      if (await File(path).exists()) {
        return true;
      }
    }

    return false;
  }
}
```

**iOS Info.plist Security Settings:**

```xml
<!-- ✅ GOOD: Secure Info.plist configuration -->
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <false/>
</dict>

<key>UIFileSharingEnabled</key>
<false/>

<key>UISupportsDocumentBrowser</key>
<false/>
```

### Android Security

**DO:**
- Use Android KeyStore for key management
- Enable ProGuard/R8 code obfuscation
- Implement root detection
- Use network security configuration

```dart
// ✅ GOOD: Root detection for Android
class AndroidSecurityChecks {
  static Future<bool> isDeviceRooted() async {
    if (!Platform.isAndroid) return false;

    // Check for common root indicators
    final rootIndicators = [
      '/system/app/Superuser.apk',
      '/sbin/su',
      '/system/bin/su',
      '/system/xbin/su',
      '/data/local/xbin/su',
      '/data/local/bin/su',
      '/system/sd/xbin/su',
      '/system/bin/failsafe/su',
      '/data/local/su',
    ];

    for (final path in rootIndicators) {
      if (await File(path).exists()) {
        return true;
      }
    }

    return false;
  }
}
```

**Android Network Security Configuration:**

```xml
<!-- ✅ GOOD: res/xml/network_security_config.xml -->
<?xml version="1.0" encoding="utf-8"?>
<network-security-config>
    <base-config cleartextTrafficPermitted="false">
        <trust-anchors>
            <certificates src="system" />
        </trust-anchors>
    </base-config>

    <!-- Certificate pinning for production API -->
    <domain-config cleartextTrafficPermitted="false">
        <domain includeSubdomains="true">api.helix-app.com</domain>
        <pin-set>
            <pin digest="SHA-256">YOUR_CERTIFICATE_HASH</pin>
            <!-- Backup pin -->
            <pin digest="SHA-256">BACKUP_CERTIFICATE_HASH</pin>
        </pin-set>
    </domain-config>
</network-security-config>
```

**Android Manifest Security:**

```xml
<!-- ✅ GOOD: Secure AndroidManifest.xml -->
<manifest>
    <application
        android:allowBackup="false"
        android:usesCleartextTraffic="false"
        android:networkSecurityConfig="@xml/network_security_config">
    </application>
</manifest>
```

---

## Dependency Security

### Dependency Management

**DO:**
- Regularly update dependencies
- Audit dependencies for vulnerabilities
- Use only trusted, well-maintained packages
- Review dependency licenses

```bash
# ✅ GOOD: Regular dependency auditing
dart pub audit
dart pub outdated
flutter pub upgrade
```

**DON'T:**
- Use deprecated or unmaintained packages
- Ignore security advisories
- Use dependencies with incompatible licenses

### Dependency Review Checklist

Before adding a new dependency:

- [ ] Package is actively maintained (recent commits/releases)
- [ ] Package has good security track record
- [ ] Package has acceptable license
- [ ] Package has reasonable number of dependencies
- [ ] Package source code is available for review
- [ ] Package has good test coverage
- [ ] Alternative packages have been evaluated

---

## Code Quality & Security

### Secure Coding Practices

**DO:**
- Follow OWASP Mobile Security guidelines
- Use static analysis tools
- Enable strict mode and linting
- Conduct regular code reviews

```yaml
# ✅ GOOD: analysis_options.yaml with security linters
analyzer:
  strong-mode:
    implicit-casts: false
    implicit-dynamic: false
  errors:
    missing_required_param: error
    missing_return: error
    todo: warning
  exclude:
    - "**/*.g.dart"
    - "**/*.freezed.dart"

linter:
  rules:
    - avoid_print
    - avoid_unnecessary_containers
    - prefer_const_constructors
    - use_key_in_widget_constructors
    - avoid_web_libraries_in_flutter
    - no_logic_in_create_state
    - prefer_relative_imports
```

**DON'T:**
- Disable security warnings
- Use deprecated APIs
- Ignore static analysis results

### Error Handling

**DO:**
- Implement proper error handling
- Avoid exposing sensitive information in errors
- Log errors securely

```dart
// ✅ GOOD: Secure error handling
class SecureErrorHandler {
  static void handleError(dynamic error, StackTrace stackTrace) {
    // Log sanitized error (remove sensitive data)
    final sanitizedError = _sanitizeError(error);

    // Log to secure logging service
    _secureLogger.error(sanitizedError, stackTrace);

    // Show user-friendly message (no technical details)
    _showUserFriendlyError();
  }

  static String _sanitizeError(dynamic error) {
    final errorString = error.toString();

    // Remove sensitive information
    return errorString
        .replaceAll(RegExp(r'token[:\s]+[^\s]+', caseSensitive: false), 'token: [REDACTED]')
        .replaceAll(RegExp(r'password[:\s]+[^\s]+', caseSensitive: false), 'password: [REDACTED]')
        .replaceAll(RegExp(r'api[_-]key[:\s]+[^\s]+', caseSensitive: false), 'api_key: [REDACTED]');
  }

  static void _showUserFriendlyError() {
    // Show generic error message to user
  }
}
```

---

## Testing Security

### Security Testing

**DO:**
- Write security-focused unit tests
- Test authentication and authorization
- Test input validation
- Test encryption/decryption

```dart
// ✅ GOOD: Security testing
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Security Tests', () {
    test('Session tokens should be securely stored', () async {
      final sessionManager = SecureSessionManager();
      const testToken = 'test_session_token_123';

      await sessionManager.saveSession(testToken);
      final retrievedToken = await sessionManager.getSession();

      expect(retrievedToken, equals(testToken));

      // Verify token is not in SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('session_token'), isNull);
    });

    test('Sensitive data should be encrypted', () {
      final encryption = DataEncryption();
      const sensitiveData = 'User credit card: 1234-5678-9012-3456';

      final encrypted = encryption.encryptData(sensitiveData);
      expect(encrypted, isNot(contains('1234')));
      expect(encrypted, isNot(contains('5678')));

      final decrypted = encryption.decryptData(encrypted);
      expect(decrypted, equals(sensitiveData));
    });

    test('Input validation should reject malicious input', () {
      expect(InputValidator.isValidEmail('test@example.com'), isTrue);
      expect(InputValidator.isValidEmail('<script>alert("xss")</script>'), isFalse);
      expect(InputValidator.isValidEmail('test@example'), isFalse);

      final maliciousInput = '<script>alert("xss")</script>';
      final sanitized = InputValidator.sanitizeInput(maliciousInput);
      expect(sanitized, isNot(contains('<')));
      expect(sanitized, isNot(contains('>')));
    });
  });
}
```

---

## Privacy & Compliance

### GDPR Compliance

**DO:**
- Implement data minimization
- Provide data export functionality
- Implement right to deletion
- Obtain proper consent
- See [GDPR Compliance Guide](./GDPR_COMPLIANCE_GUIDE.md) for details

**DON'T:**
- Collect unnecessary personal data
- Share data without consent
- Ignore data deletion requests

### Privacy Best Practices

```dart
// ✅ GOOD: Privacy-conscious data collection
class PrivacyCompliantAnalytics {
  void trackEvent(String eventName, Map<String, dynamic> properties) {
    // Remove PII before tracking
    final sanitizedProperties = _removePII(properties);

    // Track with user consent
    if (_hasUserConsent()) {
      _analytics.logEvent(eventName, sanitizedProperties);
    }
  }

  Map<String, dynamic> _removePII(Map<String, dynamic> properties) {
    final sanitized = Map<String, dynamic>.from(properties);

    // Remove common PII fields
    sanitized.remove('email');
    sanitized.remove('phone');
    sanitized.remove('name');
    sanitized.remove('address');

    return sanitized;
  }

  bool _hasUserConsent() {
    // Check user's privacy preferences
    return true; // Implement actual consent check
  }
}
```

---

## Security Checklist

Use this checklist before releasing new features:

### Authentication & Authorization
- [ ] Session tokens are securely stored
- [ ] Biometric authentication is implemented where appropriate
- [ ] Password requirements meet security standards
- [ ] Session timeout is properly configured

### Data Protection
- [ ] Sensitive data is encrypted at rest
- [ ] Sensitive data is cleared from memory after use
- [ ] File protection is enabled
- [ ] Database is encrypted (if applicable)

### Network Security
- [ ] All communications use HTTPS
- [ ] Certificate pinning is implemented for critical APIs
- [ ] API requests are signed
- [ ] Network timeouts are configured

### Input Validation
- [ ] All user input is validated
- [ ] Input is sanitized before processing
- [ ] File uploads are restricted and validated
- [ ] SQL injection prevention (if applicable)

### Secrets Management
- [ ] No hardcoded secrets in code
- [ ] API keys are stored securely
- [ ] Environment variables are used for configuration
- [ ] Secrets are not committed to Git

### Mobile Security
- [ ] Jailbreak/root detection is implemented (if required)
- [ ] Code obfuscation is enabled for production
- [ ] App Transport Security is configured (iOS)
- [ ] Network security config is set (Android)

### Dependencies
- [ ] All dependencies are up to date
- [ ] Dependency audit has been run
- [ ] No known vulnerabilities in dependencies
- [ ] Licenses have been reviewed

### Testing
- [ ] Security tests are passing
- [ ] Manual security testing completed
- [ ] No sensitive data in logs
- [ ] Error messages don't expose sensitive information

### Privacy
- [ ] GDPR compliance verified
- [ ] Privacy policy is up to date
- [ ] User consent is obtained
- [ ] Data minimization is implemented

---

## Additional Resources

- [OWASP Mobile Security Project](https://owasp.org/www-project-mobile-security/)
- [Flutter Security Best Practices](https://docs.flutter.dev/security)
- [Dart Security Guidelines](https://dart.dev/guides/security)
- [NIST Mobile Security Guidelines](https://www.nist.gov/itl/applied-cybersecurity/mobile-security)
- [CWE Mobile Application Security Weaknesses](https://cwe.mitre.org/data/definitions/919.html)

---

**Document Version**: 1.0
**Last Updated**: 2025-11-16
**Maintained By**: Helix Security Team
