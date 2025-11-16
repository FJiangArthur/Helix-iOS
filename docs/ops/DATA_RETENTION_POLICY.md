# Data Retention and Privacy Policy

## Overview

This document defines the data retention, deletion, and privacy policies for the Helix-iOS application. It outlines how user data is collected, stored, managed, and deleted in compliance with GDPR, CCPA, and other privacy regulations.

**Last Updated**: 2025-11-16
**Version**: 1.0.0

---

## 1. Data Types and Classification

### 1.1 Personal Identifiable Information (PII)

| Data Type | Description | Sensitivity | Storage Location |
|-----------|-------------|-------------|------------------|
| User ID | Unique user identifier | Medium | Analytics Service (in-memory) |
| Session ID | Temporary session identifier | Low | Analytics Service (in-memory) |
| Speaker ID | Optional speaker identification in conversations | Medium | Conversation Model |

### 1.2 Audio Data

| Data Type | Description | Sensitivity | Storage Location |
|-----------|-------------|-------------|------------------|
| Audio Recordings | Raw audio files (.wav) | High | Temporary directory |
| Audio Chunks | Binary audio data segments | High | In-memory (AudioChunk model) |
| Audio Metadata | Sample rate, channels, duration, timestamps | Low | AudioChunk model |

### 1.3 Transcription Data

| Data Type | Description | Sensitivity | Storage Location |
|-----------|-------------|-------------|------------------|
| Transcription Text | Speech-to-text results | High | TranscriptionSegment model |
| Transcription Metadata | Timestamps, confidence scores, language | Low | TranscriptionResult model |
| Speaker Information | Optional speaker identification | Medium | TranscriptionSegment model |

### 1.4 Conversation Data

| Data Type | Description | Sensitivity | Storage Location |
|-----------|-------------|-------------|------------------|
| Conversation Messages | User messages and content | High | ConversationMessage model |
| Conversation Context | Recent messages for AI analysis | High | ConversationContext model |
| Conversation Metadata | Start/end times, duration, custom metadata | Medium | Conversation model |

### 1.5 AI Analysis Data

| Data Type | Description | Sensitivity | Storage Location |
|-----------|-------------|-------------|------------------|
| Fact Check Results | Claims, sources, explanations | Medium | FactCheckResult model |
| Summaries | Conversation summaries and key points | Medium | ConversationSummary model |
| Action Items | Extracted tasks, assignees, due dates | Medium | ActionItemResult model |
| Sentiment Analysis | Emotional analysis and tone detection | Medium | SentimentAnalysisResult model |
| Cached Results | Temporary analysis cache | Medium | CachedResult model |

### 1.6 Analytics and Telemetry

| Data Type | Description | Sensitivity | Storage Location |
|-----------|-------------|-------------|------------------|
| Usage Events | User interactions, feature usage | Low | AnalyticsService (in-memory) |
| Error Events | Application errors and exceptions | Low | AnalyticsService (in-memory) |
| Performance Metrics | Latency, processing times | Low | AnalyticsService (in-memory) |
| BLE Health Metrics | Bluetooth connection statistics | Low | BleHealthMetrics model |

### 1.7 Technical Data

| Data Type | Description | Sensitivity | Storage Location |
|-----------|-------------|-------------|------------------|
| Application Logs | Debug, info, warning, error logs | Low | Console output |
| BLE Transaction Data | Bluetooth communication logs | Low | BleTransaction model |
| API Keys | Third-party service credentials | Critical | Local config file (excluded from git) |

---

## 2. Data Retention Timelines

### 2.1 Immediate Deletion (On-Demand)
- **Audio Recordings**: Deleted immediately when user explicitly deletes from file management screen
- **Temporary Files**: Can be manually deleted at any time

### 2.2 Short-Term Retention (24 hours)
- **Audio Chunks**: Cleared from memory immediately after processing
- **Temporary Audio Files**: Auto-deleted after 24 hours if not manually removed
- **Analytics Events**: Cleared after session ends or 24 hours
- **Application Logs**: Cleared on app restart or after 24 hours
- **BLE Transaction Data**: Retained for current session only

### 2.3 Medium-Term Retention (7 days)
- **Transcription Results**: Retained for 7 days for review and correction
- **Conversation Data**: Retained for 7 days for context and history
- **Cached AI Results**: Expired after 10 minutes (configurable)

### 2.4 Long-Term Retention (30 days)
- **AI Analysis Results**: Retained for 30 days for insights and reporting
- **Fact Check History**: Retained for 30 days for reference
- **Action Items**: Retained for 30 days or until marked complete

### 2.5 No Retention (In-Memory Only)
- **Active Audio Streams**: Cleared immediately after processing
- **BLE Health Metrics**: Reset on app restart
- **Current Session Data**: Cleared on app termination

---

## 3. Deletion Policies

### 3.1 Automatic Deletion

#### 3.1.1 Time-Based Deletion
```
- Audio files older than 24 hours → Auto-delete
- Transcription data older than 7 days → Auto-delete
- Conversation data older than 7 days → Auto-delete
- AI analysis results older than 30 days → Auto-delete
- Cached results older than 10 minutes → Auto-expire
```

#### 3.1.2 Event-Based Deletion
```
- Audio chunks → Delete after transcription complete
- Analytics events → Delete on app termination
- Session data → Delete on session end
- Temporary files → Delete on app uninstall
```

### 3.2 Manual Deletion

Users can manually delete:
- Individual audio recordings via File Management screen
- All analytics data via Settings screen
- Cached data via Settings screen
- All application data via device Settings > App Storage

### 3.3 Secure Deletion

For sensitive data (PII, audio recordings, transcriptions):
1. **Overwrite** file contents with zeros before deletion
2. **Immediate removal** from all in-memory caches
3. **Permanent deletion** with no recovery possibility
4. **Verification** that all references are cleared

---

## 4. Anonymization Rules

### 4.1 Data Subject to Anonymization

When anonymization is enabled:

#### 4.1.1 Audio Data
- Remove all speaker identification
- Strip metadata containing user information
- Retain only technical attributes (sample rate, format)

#### 4.1.2 Transcription Data
- Remove speaker IDs
- Replace names with generic placeholders (e.g., "Speaker A", "Speaker B")
- Remove any personally identifiable context

#### 4.1.3 Conversation Data
- Remove user IDs and speaker IDs
- Replace timestamps with relative times
- Strip all custom metadata that may contain PII

#### 4.1.4 Analytics Data
- Remove user IDs
- Remove session IDs linking to users
- Aggregate data to prevent individual identification
- Remove file paths containing user-specific information

### 4.2 Anonymization Techniques

1. **Pseudonymization**: Replace identifiers with random IDs
2. **Generalization**: Replace specific values with ranges or categories
3. **Data Masking**: Partially obscure sensitive data
4. **Aggregation**: Combine individual data into statistical summaries

### 4.3 Anonymization Scope

```
REQUIRED for analytics export
OPTIONAL for local storage
NOT APPLIED to active user data during session
```

---

## 5. PII Handling Guidelines

### 5.1 PII Identification

The following are considered PII in this application:
- User identifiers (if implemented)
- Speaker identifiers with real names
- Voice recordings (biometric data)
- Transcribed speech containing personal information
- Any metadata linking to specific individuals

### 5.2 PII Collection Principles

1. **Minimization**: Collect only what is necessary
2. **Purpose Limitation**: Use only for stated purposes
3. **Consent**: Obtain explicit user consent for PII processing
4. **Transparency**: Clearly inform users what data is collected

### 5.3 PII Storage Requirements

- **Encryption**: Encrypt PII at rest (if stored persistently)
- **Access Control**: Limit access to authorized components only
- **Isolation**: Store PII separately from non-sensitive data
- **No Cloud Storage**: All PII remains on-device only

### 5.4 PII Transmission Rules

- **TLS Only**: Use HTTPS/TLS for all API communications
- **No External Logging**: Never log PII to external services
- **Minimize Payload**: Send only essential data to APIs
- **API Key Protection**: Never include API keys in logs or analytics

### 5.5 PII Deletion Requirements

- **User Request**: Honor deletion requests within 30 days
- **Complete Removal**: Delete from all storage locations
- **Third-Party Notification**: Notify any third-party processors
- **Deletion Confirmation**: Provide confirmation to user

---

## 6. GDPR Compliance Measures

### 6.1 Right to Access (Article 15)
- Users can view all stored data via Settings screen
- Export analytics data in JSON format
- View all recorded files and transcriptions

### 6.2 Right to Rectification (Article 16)
- Users can edit transcriptions (if feature implemented)
- Users can update preferences and settings
- Users can correct speaker identifications

### 6.3 Right to Erasure (Article 17 - "Right to be Forgotten")
- Users can delete individual recordings
- Users can clear all analytics data
- Users can reset app to factory state
- App provides "Delete All Data" function

### 6.4 Right to Data Portability (Article 20)
- Export analytics in JSON format
- Export transcriptions in text format
- Export conversation history in structured format

### 6.5 Right to Restrict Processing (Article 18)
- Users can disable analytics collection
- Users can disable AI analysis features
- Users can disable specific data collection points

### 6.6 Privacy by Design and Default (Article 25)
- Minimal data collection by default
- Analytics can be disabled
- No data sharing with third parties by default
- All sensitive processing is on-device

### 6.7 Data Protection Impact Assessment (Article 35)
- Regular assessment of data processing risks
- Documentation of privacy safeguards
- Review of third-party API usage
- Monitoring of data access patterns

---

## 7. CCPA Compliance Measures

### 7.1 Right to Know
- Transparent disclosure of data collection
- Clear documentation of data usage
- Accessible privacy policy

### 7.2 Right to Delete
- User-initiated deletion of all personal data
- Deletion within 30 days of request
- Confirmation of deletion

### 7.3 Right to Opt-Out
- Disable data collection via Settings
- Opt-out of analytics tracking
- Disable AI analysis features

### 7.4 Non-Discrimination
- Full app functionality available without data sharing
- No service degradation for opting out
- No penalties for exercising privacy rights

---

## 8. Additional Privacy Regulations

### 8.1 HIPAA (If Processing Health Data)
- Audio/transcription may contain health information
- No PHI storage without proper safeguards
- Encryption required for all health-related data
- Access logging for audit trails

### 8.2 COPPA (Children's Privacy)
- No data collection from users under 13
- Age verification required if applicable
- Parental consent for minors
- Enhanced data protection for children

---

## 9. Third-Party Data Processing

### 9.1 AI Service Providers
- **OpenAI / Custom LLM APIs**: Transcriptions and analysis sent to external APIs
- **Data Sharing**: Only necessary text data sent
- **Retention**: Per third-party provider policies
- **User Control**: Can disable AI features

### 9.2 Data Processing Agreements
- Review third-party privacy policies
- Ensure GDPR/CCPA compliance
- Document data sharing practices
- Obtain user consent for external processing

### 9.3 API Key Security
- Store API keys locally only (not in version control)
- Use secure configuration loading
- Rotate keys periodically
- Monitor API usage for anomalies

---

## 10. Data Breach Response

### 10.1 Detection
- Monitor for unauthorized access
- Log all data access attempts
- Alert on anomalous patterns

### 10.2 Response Plan
1. **Immediate**: Contain the breach
2. **24 hours**: Assess scope and impact
3. **72 hours**: Notify authorities (if GDPR applies)
4. **7 days**: Notify affected users
5. **30 days**: Implement corrective measures

### 10.3 User Notification
- Clear description of breach
- Data types affected
- Recommended user actions
- Contact information for support

---

## 11. Audit and Compliance

### 11.1 Regular Reviews
- **Quarterly**: Review data retention policies
- **Bi-Annually**: Audit data deletion processes
- **Annually**: Full privacy compliance audit

### 11.2 Documentation
- Maintain records of data processing activities
- Document all privacy-related decisions
- Keep audit logs for compliance verification

### 11.3 Training
- Ensure development team understands privacy policies
- Regular updates on privacy regulations
- Code review for privacy compliance

---

## 12. User Rights and Controls

### 12.1 Settings Screen Controls
Users can control:
- Analytics tracking (enable/disable)
- AI analysis features (enable/disable)
- Data collection preferences
- Auto-deletion timelines

### 12.2 Data Access
Users can access:
- All recorded audio files
- All transcriptions
- All analytics events
- All conversation history

### 12.3 Data Export
Users can export:
- Analytics data (JSON)
- Transcriptions (TXT)
- Conversation history (JSON)
- Settings and preferences (JSON)

### 12.4 Data Deletion
Users can delete:
- Individual audio files
- All recordings at once
- Analytics history
- Conversation history
- All app data (via Settings)

---

## 13. Implementation Checklist

- [x] Identify all data collection points
- [ ] Implement retention period configuration
- [ ] Create data cleanup utilities
- [ ] Add anonymization functions
- [ ] Implement secure deletion
- [ ] Add user data export
- [ ] Create Settings UI for privacy controls
- [ ] Add data access logging
- [ ] Implement consent management
- [ ] Create privacy policy UI
- [ ] Add data retention background tasks
- [ ] Implement breach detection
- [ ] Create audit logging system
- [ ] Add compliance reporting

---

## 14. Contact Information

For privacy-related inquiries:
- Email: privacy@helix-app.example.com
- Website: https://helix-app.example.com/privacy
- Support: https://helix-app.example.com/support

---

## 15. Policy Updates

This policy will be reviewed and updated:
- When new features are added
- When regulations change
- At least annually
- After any data breach

**Version History**:
- v1.0.0 (2025-11-16): Initial policy creation
