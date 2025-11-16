# API Documentation

This directory contains complete API references and protocol specifications for all services and integrations.

## What's Here

### Service APIs
- **[AI_SERVICES_API.md](AI_SERVICES_API.md)** - AI services complete API reference
  - **LLM Service API** - Multi-provider language model interface
    - Conversation analysis, fact-checking, summarization
    - OpenAI and Anthropic provider implementations
    - Usage statistics and cost estimation
  - **Fact Checking Service API** - Real-time claim verification
    - Claim detection and validation
    - Source attribution and confidence scoring
    - Queue management and rate limiting
  - **AI Insights Service API** - Conversation intelligence
    - Topic extraction and sentiment analysis
    - Action item identification
    - Contextual suggestions and recommendations
  - **AI Provider Interface** - Pluggable provider system
    - Base provider abstraction
    - Provider-specific implementations
    - Health monitoring and failover
  - Use this when: Integrating with AI services or implementing features

### Hardware Protocols
- **[EVEN_REALITIES_G1_BLE_PROTOCOL.md](EVEN_REALITIES_G1_BLE_PROTOCOL.md)** - Smart glasses BLE protocol
  - Bluetooth Low Energy service specifications
  - Nordic UART Service (NUS) implementation
  - Command structure and message framing
  - HUD rendering protocol
  - Touch gesture event handling
  - Device status and battery monitoring
  - Use this when: Working with Even Realities G1 glasses

## How to Use This Documentation

### For API Consumers (Frontend/Mobile Developers)
1. Start with [AI_SERVICES_API.md](AI_SERVICES_API.md) overview
2. Find the specific service section you need
3. Review method signatures and parameters
4. Check code examples for usage patterns
5. Reference error handling sections

### For API Implementers (Backend Developers)
1. Study the complete API contract in relevant docs
2. Review data models and response formats
3. Understand error handling requirements
4. Check performance and rate limiting specs
5. Implement according to interface definitions

### For Hardware Integration Developers
1. Read [EVEN_REALITIES_G1_BLE_PROTOCOL.md](EVEN_REALITIES_G1_BLE_PROTOCOL.md) thoroughly
2. Understand BLE service UUIDs and characteristics
3. Review command/response message formats
4. Study connection lifecycle management
5. Reference error codes and status handling

### For QA/Testing Engineers
1. Use API docs to understand expected behaviors
2. Review examples for test case development
3. Check error conditions for negative testing
4. Verify response formats match specifications
5. Reference performance requirements for load testing

## API Documentation Structure

Each API document includes:
- **Overview** - Purpose and capabilities
- **Initialization** - Setup and configuration
- **Core Methods** - Primary API functions
- **Data Models** - Request/response structures
- **Error Handling** - Exception types and recovery
- **Code Examples** - Practical usage demonstrations
- **Performance Specs** - Latency and throughput requirements

## Quick Reference

### AI Services API

#### LLM Service
```dart
// Analyze conversation
final result = await llmService.analyzeConversation(
  conversationText,
  type: AnalysisType.comprehensive,
);

// Check facts
final facts = await llmService.checkFacts(claims);

// Generate summary
final summary = await llmService.generateSummary(conversation);
```

#### Fact Checking Service
```dart
// Process text for fact-checking
await factChecker.processText('claim to verify');

// Listen to results
factChecker.results.listen((FactCheckResult result) {
  // Handle fact-check result
});
```

#### AI Insights Service
```dart
// Configure insights
insights.configure(
  enabledTypes: InsightType.actionItems | InsightType.sentiment,
);

// Listen to insights
insights.insights.listen((ConversationInsight insight) {
  // Handle insight
});
```

### Even Realities G1 Protocol

#### Connection
```dart
// Scan and connect
await glassesService.scanForDevices();
await glassesService.connect(deviceId);

// Check connection status
final isConnected = await glassesService.isConnected();
```

#### Display Content
```dart
// Render text on HUD
await glassesService.displayText(
  'Message for HUD',
  position: DisplayPosition.center,
);

// Clear display
await glassesService.clearDisplay();
```

## API Versioning

### API Versioning Documentation (New!) ⭐

Complete API versioning framework for Helix:

- **[API Versioning Strategy](API_VERSIONING_STRATEGY.md)** - Comprehensive versioning framework
  - Semantic versioning (SemVer) implementation
  - Backward compatibility rules
  - Deprecation policy and timelines
  - Version routing and middleware
  - Best practices for API consumers and developers

- **[API Changelog](API_CHANGELOG.md)** - Detailed version history
  - All API changes across versions
  - Breaking changes documentation
  - New features and enhancements
  - Deprecation notices and sunset dates
  - Support timeline matrix

- **[Migration Guides](MIGRATION_GUIDES.md)** - Step-by-step migration instructions
  - Version-specific migration paths
  - Code examples (before/after)
  - Common issues and solutions
  - Migration tools and scripts
  - Testing checklists

- **[API Reference](API_REFERENCE.md)** - Complete API documentation
  - Method Channel APIs (Flutter ↔ Native iOS)
  - Event Channel APIs (Native → Flutter)
  - External Provider APIs (OpenAI, Anthropic)
  - Version Management APIs
  - Data models and error codes

### Current Versions
- **Method Channel API**: v1.0.0 (Flutter ↔ Native iOS)
- **Event Channel API**: v1.0.0 (Native iOS → Flutter)
- **OpenAI Provider API**: v1.0.0 (External integration)
- **Anthropic Provider API**: v1.0.0 (External integration)
- **AI Services API**: v2.0 (Epic 2.2)
- **G1 BLE Protocol**: v1.0 (Even Realities firmware compatible)

### Version Support Matrix

| API Component | Current | Min Supported | Max Supported | Status |
|---------------|---------|---------------|---------------|--------|
| Method Channels | 1.0.0 | 1.0.0 | 2.0.0 | Active |
| Event Channels | 1.0.0 | 1.0.0 | 2.0.0 | Active |
| OpenAI Provider | 1.0.0 | 1.0.0 | 2.0.0 | Active |
| Anthropic Provider | 1.0.0 | 1.0.0 | 2.0.0 | Active |

### Version History
- **v1.0.0** (2025-11-16) - Initial API versioning framework implemented
  - Method Channel versioning with automatic routing
  - Event Channel version metadata
  - External API version tracking
  - Deprecation policy and sunset timeline (90+180 days)
  - Comprehensive documentation and migration guides
- **v2.0** (2025-11) - Multi-provider LLM support, enhanced fact-checking
- **v1.0** (2025-10) - Initial API implementation

## Rate Limits & Performance

### AI Services
- **LLM Analysis**: <2 seconds for comprehensive analysis
- **Fact Checking**: <3 seconds per claim
- **Insights Generation**: <1 second for basic insights
- **Rate Limits**: Configured per provider (OpenAI/Anthropic quotas)

### BLE Protocol
- **Connection Latency**: <2 seconds typical
- **HUD Update**: <50ms display refresh
- **Command Response**: <100ms typical
- **Battery Impact**: <5% per hour of continuous display

## Error Handling

### Common Error Types
- **LLMException** - AI service errors
  - ServiceNotReady, InvalidApiKey, QuotaExceeded, NetworkError
- **FactCheckException** - Fact-checking errors
  - ClaimDetectionFailed, VerificationTimeout
- **BluetoothException** - BLE communication errors
  - DeviceNotFound, ConnectionFailed, CommandTimeout

### Error Recovery Patterns
- Automatic retry with exponential backoff
- Provider failover for AI services
- Graceful degradation when services unavailable
- Clear error messages for user feedback

## Related Documentation
- [Architecture](../architecture/) - System design and integration patterns
- [Developer Guides](../dev/) - Implementation examples and patterns
- [Product Requirements](../product/) - Feature specifications
- [Testing](../evaluation/) - API testing strategies

## Contributing to API Documentation
- Keep API docs synchronized with code
- Include runnable code examples
- Document all parameters and return values
- Specify error conditions and handling
- Update version history with changes

---

**[← Back to Documentation Hub](../00-READ-FIRST.md)**
