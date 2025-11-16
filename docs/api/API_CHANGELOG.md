# Helix API Changelog

All notable changes to Helix APIs will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Nothing yet

### Changed
- Nothing yet

### Deprecated
- Nothing yet

### Removed
- Nothing yet

### Fixed
- Nothing yet

### Security
- Nothing yet

---

## [1.0.0] - 2025-11-16

### Added - Initial Release

#### Method Channel APIs (Flutter ↔ Native iOS)

**Bluetooth Method Channel** (`method.bluetooth` v1.0.0)
- `startScan()` - Start scanning for Even Realities glasses
  - Returns: `String` - Status message
  - Errors: `BluetoothOff` if Bluetooth is not powered on

- `stopScan()` - Stop scanning for devices
  - Returns: `String` - Status message

- `connectToGlasses(deviceName: String)` - Connect to paired glasses
  - Parameters:
    - `deviceName` (String, required) - Name of the device to connect
  - Returns: `String` - Connection status
  - Errors:
    - `DeviceNotFound` if device is not in paired list
    - `PeripheralNotFound` if one or both peripherals are missing

- `disconnectFromGlasses()` - Disconnect from all connected glasses
  - Returns: `String` - Disconnection status

- `send(data: Uint8List, lr: String?)` - Send data to glasses
  - Parameters:
    - `data` (Uint8List, required) - Data to send
    - `lr` (String, optional) - Target side ('L' for left, 'R' for right, null for both)
  - Returns: `void`

- `startEvenAI(identifier: String)` - Start speech recognition
  - Parameters:
    - `identifier` (String, required) - Language identifier (e.g., 'EN', 'CN')
  - Returns: `String` - Status message

- `stopEvenAI()` - Stop speech recognition
  - Returns: `String` - Status message

**Bluetooth Event Channels** (Native iOS → Flutter)

- `eventBleReceive` (v1.0.0) - Receives Bluetooth data from glasses
  - Event Data:
    ```dart
    {
      'type': String,      // Data type
      'lr': String,        // Side ('L' or 'R')
      'data': Uint8List    // Raw data
    }
    ```

- `eventSpeechRecognize` (v1.0.0) - Receives speech recognition results
  - Event Data:
    ```dart
    {
      'script': String     // Recognized text
    }
    ```

#### External HTTP APIs

**OpenAI Integration** (v1.0.0)

- Chat Completions API
  - Endpoint: `POST /v1/chat/completions`
  - Purpose: Generate AI responses and analysis
  - Models supported: GPT-4 Turbo, GPT-4, GPT-3.5 Turbo

- Whisper Transcription API
  - Endpoint: `POST /v1/audio/transcriptions`
  - Purpose: Audio transcription
  - Models supported: Whisper

**Anthropic Integration** (v1.0.0)

- Messages API
  - Endpoint: `POST /v1/messages`
  - API Version: `2023-06-01`
  - Purpose: Generate AI responses and analysis
  - Models supported: Claude 3.5 Sonnet, Claude 3 Opus, Claude 3 Sonnet, Claude 3 Haiku

#### AI Provider Methods (v1.0.0)

All AI providers (OpenAI, Anthropic) support:

- `initialize(apiKey: String)` - Initialize provider with API key
- `sendCompletion()` - Send completion request
- `streamCompletion()` - Stream completion responses
- `verifyFact()` - Verify factual claims
- `generateSummary()` - Generate conversation summaries
- `extractActionItems()` - Extract action items
- `analyzeSentiment()` - Analyze sentiment
- `detectClaims()` - Detect factual claims
- `getUsageStats()` - Get usage statistics
- `validateApiKey()` - Validate API key
- `estimateCost()` - Estimate request cost
- `dispose()` - Clean up resources

---

## Version History

- **v1.0.0** (2025-11-16) - Initial release with Bluetooth, Speech Recognition, and AI Analysis features

---

## Migration Guides

### Migrating to v1.0.0
This is the initial release. No migration needed.

---

## Deprecation Notices

### Current Deprecations
No deprecated APIs at this time.

### Upcoming Deprecations
No planned deprecations at this time.

---

## API Version Support Matrix

| API Component | Current Version | Min Supported | Max Supported | Status |
|---------------|----------------|---------------|---------------|--------|
| Method Channels | 1.0.0 | 1.0.0 | 2.0.0 | Active |
| Event Channels | 1.0.0 | 1.0.0 | 2.0.0 | Active |
| OpenAI Provider | 1.0.0 | 1.0.0 | 2.0.0 | Active |
| Anthropic Provider | 1.0.0 | 1.0.0 | 2.0.0 | Active |

---

## How to Use This Changelog

### For Developers

1. **Before Updating**: Check the version you're currently using
2. **Review Changes**: Look for your version in the changelog
3. **Check Deprecations**: Review deprecated features you might be using
4. **Read Migration Guides**: Follow migration guides for breaking changes
5. **Test Thoroughly**: Test your integration after updating

### For API Consumers

When consuming Helix APIs, always:
- Specify the API version in your requests using the `X-API-Version` header
- Monitor for deprecation warnings in responses (`X-API-Deprecated` header)
- Check sunset dates to plan migrations (`X-API-Sunset` header)
- Subscribe to API change notifications

### Version Number Format

We use [Semantic Versioning](https://semver.org/): `MAJOR.MINOR.PATCH`

- **MAJOR**: Incompatible API changes (breaking changes)
- **MINOR**: Backwards-compatible new features
- **PATCH**: Backwards-compatible bug fixes

### Change Categories

- **Added**: New features or endpoints
- **Changed**: Changes to existing functionality
- **Deprecated**: Features marked for removal in future versions
- **Removed**: Features removed from the API
- **Fixed**: Bug fixes
- **Security**: Security-related changes

---

## API Stability Guarantees

### Stable APIs
- Method Channel endpoints marked as "stable" will maintain backward compatibility within the same major version
- New optional parameters may be added
- Existing parameters will not be removed or made required

### Beta APIs
- APIs marked as "beta" may change without notice
- Use with caution in production
- Provide feedback to help stabilize the API

### Experimental APIs
- Experimental features may be removed or significantly changed
- Not recommended for production use
- Used for gathering feedback and testing new features

---

## Support Timeline

Each major API version is supported for at least 6 months after the next major version is released.

| Version | Release Date | Deprecation Date | Sunset Date | Status |
|---------|-------------|------------------|-------------|---------|
| 1.0.0 | 2025-11-16 | TBD | TBD | Active |

---

## Getting Help

### Documentation
- [API Versioning Strategy](/docs/api/API_VERSIONING_STRATEGY.md)
- [Migration Guides](/docs/api/MIGRATION_GUIDES.md)
- [API Reference](/docs/api/API_REFERENCE.md)

### Support Channels
- GitHub Issues: Report bugs or request features
- Documentation: Full API documentation available
- Community: Join our developer community

### Reporting Issues
If you encounter issues with API versioning:
1. Check this changelog for known issues
2. Review the migration guide for your version
3. Search existing GitHub issues
4. Create a new issue with:
   - Current API version
   - Expected behavior
   - Actual behavior
   - Minimal reproduction steps

---

## Change Request Process

### Proposing API Changes

1. **Create RFC**: Submit a Request for Comments (RFC) for significant changes
2. **Community Review**: Allow time for community feedback
3. **Implementation**: Implement approved changes
4. **Beta Release**: Release as beta for testing
5. **Stable Release**: Promote to stable after validation
6. **Documentation**: Update all relevant documentation

### Breaking Change Policy

Breaking changes require:
- 90-day deprecation notice
- Migration guide
- Updated code examples
- 180-day sunset period
- Support for previous version during transition
