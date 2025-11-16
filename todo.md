# Helix Development TODO List

**Last Updated**: 2025-11-15
**Branch**: `add-tracking-functionality-01B3bn4MvSDnkpMz4BgKhNZf`

---

## ✅ Completed (Latest Session)

### LLM Integration (llm.art-ai.me)
- [x] Create AppConfig system for runtime configuration
- [x] Update OpenAIProvider with custom base URL support
- [x] Integrate LLMServiceImplV2 with AppConfig
- [x] Add secure config template (`llm_config.local.json.template`)
- [x] Configure 8 model tiers (fast, balanced, advanced, reasoning, etc.)
- [x] Create API validation test (`test_api_integration.dart`)
- [x] Validate API endpoint - **All tests passed**
  - Basic completion: 41 tokens ✅
  - Conversation analysis: 161 tokens ✅
  - Model selection: 8 tiers accessible ✅

### Azure Whisper Integration
- [x] Add Whisper transcription endpoint to config
- [x] Add GPT-Realtime WebSocket endpoint to config
- [x] Create Whisper test script (`test_whisper_integration.dart`)
- [x] Update config with direct Azure OpenAI endpoints

### Audio Service Fixes
- [x] Fix state management bugs in AudioServiceImpl
- [x] Add proper cleanup in `initialize()`
- [x] Add finally blocks to ensure state reset
- [x] Check actual recorder state before operations
- [x] Test on physical device - **Recording works**

### Dependencies & Models
- [x] Add `get_it: ^7.6.4` (dependency injection)
- [x] Add `dio: ^5.4.0` (HTTP client)
- [x] Add `riverpod: ^2.4.9` (state management)
- [x] Create `analysis_result.dart` (AI analysis models)
- [x] Create `conversation_model.dart` (conversation data)
- [x] Create `transcription_segment.dart` (transcription data)
- [x] Create `llm_service.dart` (LLM service interface)

### Documentation
- [x] Create `LITELLM_API_INTEGRATION.md` (complete guide)
- [x] Create `FINAL_INTEGRATION_STATUS.md` (production readiness)
- [x] Create `CUSTOM_LLM_INTEGRATION_PLAN.md` (implementation plan)
- [x] Create `TEST_RESULTS_SUMMARY.md` (test results)
- [x] Create `IMPLEMENTATION_SUMMARY.md` (summary)
- [x] Create `AZURE_OPENAI_INTEGRATION_PLAN.md` (Azure guide)

### Git & Deployment
- [x] Commit all changes with detailed commit message
- [x] Resolve merge conflicts with remote branch
- [x] Push to remote repository

---

## 🚧 In Progress

### Whisper Transcription Service
- [ ] Test Whisper endpoint with actual audio file
- [ ] Integrate Azure Whisper service into Flutter app
- [ ] Create `AzureWhisperService` implementation
- [ ] Connect recording → transcription pipeline
- [ ] Test end-to-end transcription flow

---

## 📋 Next Priority Tasks

### Priority 1: Complete Whisper Integration (Est: 2-3 hours)

**Goal**: Enable audio transcription using Azure Whisper endpoint

1. **Create Azure Whisper Service** (45 min)
   - [ ] Create `lib/services/transcription/azure_whisper_service.dart`
   - [ ] Implement multipart/form-data upload
   - [ ] Add proper error handling
   - [ ] Support both transcription and translation endpoints
   - [ ] Add language detection and confidence scoring

2. **Integrate with TranscriptionCoordinator** (30 min)
   - [ ] Update `TranscriptionCoordinator` to use Azure Whisper
   - [ ] Configure API key from `llm_config.local.json`
   - [ ] Add mode switching (native vs Azure Whisper)
   - [ ] Test mode auto-selection based on network

3. **Connect Recording Pipeline** (45 min)
   - [ ] Wire `AudioServiceImpl` → `AzureWhisperService`
   - [ ] Add audio format conversion if needed
   - [ ] Implement batch processing (5-second intervals)
   - [ ] Add progress indicators in UI

4. **Testing & Validation** (30 min)
   - [ ] Create test audio file (5-10 seconds)
   - [ ] Test transcription accuracy
   - [ ] Test error handling (no network, invalid API key)
   - [ ] Verify on physical device

### Priority 2: AI Analysis Pipeline (Est: 1-2 hours)

**Goal**: Enable real-time conversation analysis with LLM

1. **Connect Transcription → AI Analysis** (45 min)
   - [ ] Listen to `transcriptStream` from TranscriptionCoordinator
   - [ ] Buffer transcript segments for analysis
   - [ ] Trigger LLM analysis after sufficient text
   - [ ] Display analysis results in UI

2. **Implement Analysis Features** (30 min)
   - [ ] Quick summary (1-2 sentences)
   - [ ] Action item extraction
   - [ ] Key topics identification
   - [ ] Add confidence indicators

3. **UI Integration** (30 min)
   - [ ] Show analysis results in ConversationTab
   - [ ] Add loading states during analysis
   - [ ] Display token usage and cost estimates
   - [ ] Add manual "Analyze" button

### Priority 3: Model Selection UI (Est: 30-45 min)

**Goal**: Allow users to choose AI model tier

1. **Create Settings Widget** (20 min)
   - [ ] Create `lib/features/settings/widgets/model_selector.dart`
   - [ ] Display 8 model tiers with descriptions
   - [ ] Show rate limits for each model
   - [ ] Add selection persistence

2. **Integrate Settings** (15 min)
   - [ ] Add to Settings screen
   - [ ] Connect to LLMService
   - [ ] Add "Current Model" indicator in UI
   - [ ] Test model switching

### Priority 4: Rate Limit Handling (Est: 20-30 min)

**Goal**: Graceful handling of API rate limits

1. **Implement Fallback Strategy** (15 min)
   - [ ] Add retry logic with exponential backoff
   - [ ] Automatic model switching on rate limit
   - [ ] Fallback chain: gpt-5 → gpt-4.1 → gpt-4.1-mini
   - [ ] Display rate limit warnings to user

2. **Add Usage Monitoring** (15 min)
   - [ ] Track API calls and token usage
   - [ ] Display usage statistics
   - [ ] Add cost estimates
   - [ ] Warn when approaching limits

---

## 🧪 Testing & Deployment Workflows

### Local Testing Workflow (Est: 2-3 hours)

**Reference**: See [LOCAL_TESTING_PLAN.md](./LOCAL_TESTING_PLAN.md) for detailed test cases

1. **Pre-Test Setup** (15 min)
   - [ ] Clone/pull latest code from `main`
   - [ ] Configure `llm_config.local.json` with valid API keys
   - [ ] Run `flutter doctor -v` to verify environment
   - [ ] Run `flutter analyze` to check code quality
   - [ ] Install on physical device (recommended) or simulator

2. **Phase 1: Smoke Testing** (15 min)
   - [ ] TC-001: Basic audio recording flow
   - [ ] Verify app launches without crash
   - [ ] Navigate through all tabs
   - [ ] Check UI rendering on device

3. **Phase 2: Functional Testing** (1 hour)
   - [ ] TC-002: Multiple recording sessions
   - [ ] TC-003: LLM API basic completion
   - [ ] TC-004: Model selection
   - [ ] TC-005: Whisper transcription (requires audio)
   - [ ] TC-006: AI conversation analysis
   - [ ] TC-007: Network failure handling
   - [ ] TC-008: Invalid API key handling

4. **Phase 3: Performance Testing** (30 min)
   - [ ] TC-009: App launch time (<3s target)
   - [ ] TC-010: Memory usage (<200MB target)
   - [ ] Battery consumption monitoring
   - [ ] UI frame rate (60 FPS target)

5. **Test Report** (15 min)
   - [ ] Document all test results
   - [ ] Calculate pass rate (target: >90%)
   - [ ] Log all bugs found
   - [ ] Create bug reports for critical issues

**Commands**:
```bash
# Run on physical device
flutter run -d 00008150-001514CC3C00401C

# Run on simulator
flutter run -d iPhone-15-Pro

# Build release version for performance testing
flutter build ios --release

# Run analyzer
flutter analyze

# Clear cache if issues
flutter clean && flutter pub get
```

### TestFlight Deployment Workflow (Est: 1-2 hours)

**Reference**: See [TESTFLIGHT_DEPLOYMENT_SOP.md](./TESTFLIGHT_DEPLOYMENT_SOP.md) for complete procedure

#### Pre-Deployment Checklist (30 min)

1. **Code Readiness**
   - [ ] All critical bugs fixed
   - [ ] Code reviewed and approved
   - [ ] Merged to `main` branch
   - [ ] `flutter analyze` passes with 0 critical issues
   - [ ] Local testing complete (>90% pass rate)

2. **Version Management**
   - [ ] Increment version in `pubspec.yaml`
     ```yaml
     version: 1.0.2+3  # VERSION+BUILD
     ```
   - [ ] Update changelog/release notes
   - [ ] Tag release in Git

3. **Configuration**
   - [ ] API endpoints configured correctly
   - [ ] Debug flags disabled
   - [ ] App icon and launch screen finalized
   - [ ] Privacy policy URL updated

#### Deployment Process (30-45 min)

**Method 1: Using Xcode** (Standard)

1. **Build Archive**
   ```bash
   # Prepare build
   cd /path/to/Helix-iOS
   git checkout main
   git pull origin main
   flutter clean
   flutter pub get
   flutter build ios --release

   # Open in Xcode
   open ios/Runner.xcworkspace
   ```

2. **In Xcode**:
   - [ ] Select "Any iOS Device (arm64)" as destination
   - [ ] Product → Archive (wait 5-10 min)
   - [ ] Click "Distribute App" in Organizer
   - [ ] Select "App Store Connect" → Upload
   - [ ] Wait for processing (5-30 min)

**Method 2: Using fastlane** (Automated)

1. **Setup** (one-time):
   ```bash
   cd ios
   sudo gem install fastlane
   fastlane init
   ```

2. **Deploy**:
   ```bash
   cd ios
   fastlane beta
   ```

**Method 3: CI/CD** (GitHub Actions)
   - [ ] Push tag: `git tag v1.0.2 && git push origin v1.0.2`
   - [ ] GitHub Actions automatically builds and deploys
   - [ ] Monitor workflow status

#### Post-Deployment Verification (15-30 min)

1. **Verify Build in App Store Connect**
   - [ ] Login to https://appstoreconnect.apple.com
   - [ ] Go to My Apps → Helix → TestFlight
   - [ ] Verify build appears (may take 30 min)
   - [ ] Check status is "Ready to Submit" or "Testing"

2. **Configure Build**
   - [ ] Add "What to Test" notes for testers
   - [ ] Add build information
   - [ ] Answer export compliance questions

3. **Add Testers**
   - [ ] Internal testing: Add team members (immediate access)
   - [ ] External testing: Add beta testers (requires 24-48hr review)
   - [ ] Verify invitation emails sent

4. **Monitor Feedback**
   - [ ] Check crash reports daily
   - [ ] Review tester feedback
   - [ ] Track analytics
   - [ ] Plan hotfixes if needed

### Continuous Testing Strategy

#### Daily Tasks
- [ ] Monitor TestFlight crash reports
- [ ] Review user feedback from beta testers
- [ ] Check API usage and costs
- [ ] Verify build status

#### Weekly Tasks
- [ ] Run full test suite on latest build
- [ ] Analyze usage metrics
- [ ] Update bug tracker
- [ ] Plan next release features

#### Release Cycle
- [ ] Internal builds: As needed (daily if bugs)
- [ ] External builds: Weekly or bi-weekly
- [ ] Hotfixes: Within 24 hours of critical bug

---

## 🎯 Competitive Feature Roadmap

**Reference**: See [COMPETITIVE_ROADMAP.md](./COMPETITIVE_ROADMAP.md) for complete competitive analysis

**Current Feature Parity**: 35% (7/20 features)
**Competitors**: Otter.ai (80%), Gong (85%), Ray-Ban Meta (60%)
**Goal**: Reach 90% feature parity while leveraging unique smart glasses advantages

---

### Phase 1: Foundation (Q1 2026) - 60% Parity

**Goal**: Achieve parity with basic AI assistants
**Duration**: 12 weeks

#### Priority 5: Conversation Memory & History (Week 1-2)
- [ ] Implement SQLite database for conversation storage
  - Create conversation schema (id, timestamp, participants, transcript, analysis)
  - Add indexing for fast queries
- [ ] Build searchable conversation archive
  - Full-text search across all conversations
  - Filter by date, speaker, tags
- [ ] Add conversation tagging system
  - User-defined tags
  - Auto-tagging based on content
- [ ] Implement export functionality
  - Export to PDF with formatting
  - Export to plain text
  - Export to JSON for API integration

**Competitive Benchmark**: Otter.ai has searchable database across all meetings

#### Priority 6: Speaker Diarization (Week 3-4)
- [ ] Integrate Azure Speaker Recognition API
  - Set up Azure Cognitive Services account
  - Implement speaker enrollment
- [ ] Implement automatic speaker labeling
  - "Speaker 1", "Speaker 2" detection
  - Speaker change detection
- [ ] Add manual speaker name assignment
  - UI for renaming speakers
  - Speaker profile management
- [ ] Create speaker-specific insights
  - Per-speaker talk time
  - Per-speaker sentiment
  - Speaker interaction patterns

**Competitive Benchmark**: Otter.ai auto-detects speakers with 90%+ accuracy

#### Priority 7: Voice Commands (Week 5-6)
- [ ] Implement "Hey Helix" wake word detection
  - Integrate Porcupine wake word engine
  - On-device detection for privacy
  - Wake word model training
- [ ] Add voice-activated actions
  - "Start recording", "Stop recording"
  - "Summarize conversation"
  - "Show action items"
  - "What did we discuss about [topic]?"
- [ ] Create natural language command processor
  - Intent classification
  - Entity extraction
  - Command execution engine
- [ ] Optimize for low latency
  - Background wake word detection
  - Fast intent processing

**Competitive Benchmark**: Ray-Ban Meta "Hey Meta" + continuous conversation

#### Priority 8: AI Chat/Query Interface (Week 7-8)
- [ ] Build conversation query service
  - Query single conversation
  - Query across all conversations
  - Context-aware responses
- [ ] Implement natural language queries
  - "What did we discuss about pricing?"
  - "Find all conversations with John"
  - "When did I last talk about the project?"
- [ ] Add conversational follow-ups
  - Multi-turn query support
  - Context retention across queries
- [ ] Create query UI in app
  - Chat interface for queries
  - Quick query suggestions
  - Search results display

**Competitive Benchmark**: Otter.ai AI Chat answers from entire meeting database

#### Priority 9: Sentiment Analysis (Week 9-10)
- [ ] Implement real-time sentiment detection
  - Positive/negative/neutral classification
  - Confidence scoring
- [ ] Add emotion tracking over conversation
  - Sentiment timeline visualization
  - Emotion shift detection
- [ ] Create sentiment alerts
  - Alert on negative sentiment shifts
  - Notify on high-emotion moments
- [ ] Build sentiment trends visualization
  - Graph sentiment over time
  - Compare sentiment across conversations

**Competitive Benchmark**: Gong tracks sentiment and flags risky moments

#### Priority 10: Multi-Language Support (Week 11-12)
- [ ] Add support for top 10 languages
  - English, Spanish, French, German, Italian
  - Portuguese, Chinese, Japanese, Korean, Arabic
- [ ] Implement auto-detect language
  - Use Whisper language detection
  - Fallback to manual selection
- [ ] Add live translation option
  - Translate transcripts in real-time
  - Display on HUD
- [ ] Configure language-specific models
  - Optimized prompts per language
  - Language-specific terminology

**Competitive Benchmark**: Ray-Ban Meta live translation, Otter supports 30+ languages

#### Phase 1 Success Metrics
- ✅ 60% feature parity achieved
- ✅ Conversation history with search working
- ✅ Speaker identification >85% accuracy
- ✅ Voice command activation <500ms latency
- ✅ Query any past conversation
- ✅ Multi-language transcription for top 10 languages

---

### Phase 2: Differentiation (Q2 2026) - 75% Parity + Unique Features

**Goal**: Leverage smart glasses advantages
**Duration**: 12 weeks

#### Advanced Features

**Real-Time Coaching System** (Week 1-3)
- [ ] Build live conversation analysis engine
  - Real-time transcript processing
  - Pattern detection (objections, opportunities)
- [ ] Create HUD coaching display
  - Non-intrusive coaching tips
  - Context-sensitive suggestions
- [ ] Implement objection detection and handling
  - Common objection patterns
  - Suggested responses on HUD
- [ ] Add talk ratio monitoring
  - Listening vs speaking percentage
  - Optimal ratio alerts

**Competitive Benchmark**: Gong real-time coaching for sales calls
**Unique Helix Angle**: Display coaching on HUD without disrupting flow

**Context-Aware Notifications** (Week 4-5)
- [ ] Smart HUD alerts
  - Action items display
  - Follow-up reminders
  - Time-based notifications
- [ ] Implement context detection
  - Meeting vs casual conversation
  - Sales call vs medical consultation
- [ ] Add proactive suggestions
  - Next best action recommendations
  - Conversation-type specific tips
- [ ] Create Do Not Disturb modes
  - Manual DND toggle
  - Auto-DND based on context

**Offline Mode** (Week 6-7)
- [ ] Implement on-device transcription
  - Core ML Whisper model integration
  - Model optimization for iOS
- [ ] Add local LLM for basic analysis
  - Llama 3 8B on-device
  - Lightweight analysis capabilities
- [ ] Build offline-first database with sync
  - Local storage
  - Cloud sync when online
  - Conflict resolution

**Unique Helix Feature**: Privacy-first, works in secure environments
**Competitive Advantage**: None of the major competitors offer true offline mode

**Smart Summaries** (Week 8-9)
- [ ] Build adaptive summary engine
  - 1-sentence, paragraph, detailed levels
  - User preference learning
- [ ] Create role-specific summaries
  - Sales: focus on objections, next steps
  - Medical: focus on symptoms, treatment
  - Legal: focus on facts, agreements
- [ ] Implement key points extraction
  - Automatic highlight detection
  - Important moment identification
- [ ] Add automatic follow-up suggestions
  - Action items from conversation
  - Recommended next steps

**Talk Pattern Analytics** (Week 10-11)
- [ ] Implement speaking time ratio analysis
  - Per-speaker time tracking
  - Ratio visualizations
- [ ] Add question frequency analysis
  - Question count per speaker
  - Question types classification
- [ ] Create filler word detection
  - "um", "uh", "like" counting
  - Filler word reduction coaching
- [ ] Build pace and clarity metrics
  - Words per minute
  - Clarity score

**Competitive Benchmark**: Gong's talk pattern intelligence

**Privacy Controls** (Week 12)
- [ ] Build granular privacy settings
  - Per-conversation privacy levels
  - Default privacy mode
- [ ] Implement PII detection and redaction
  - NER models for PII
  - Automatic masking
- [ ] Add compliance modes
  - HIPAA mode
  - GDPR mode
  - Custom compliance rules
- [ ] Create audit logging
  - Track all data access
  - Compliance reports

#### Phase 2 Success Metrics
- ✅ Real-time coaching on HUD working
- ✅ Fully functional offline mode
- ✅ Privacy-first architecture implemented
- ✅ Professional-grade analytics
- ✅ 75%+ feature parity achieved

---

### Phase 3: Enterprise (Q3-Q4 2026) - 90% Parity + Market Leadership

**Goal**: Enterprise-ready with integrations
**Duration**: 24 weeks

#### Enterprise Features

**CRM Integration Suite** (Month 1-2)
- [ ] Build Salesforce connector
  - OAuth 2.0 authentication
  - Bi-directional sync
  - Activity logging
- [ ] Create HubSpot integration
  - Contact sync
  - Deal tracking
  - Email integration
- [ ] Add Microsoft Dynamics support
  - Enterprise authentication
  - Field mapping
- [ ] Build custom CRM API
  - Generic REST connector
  - Custom field mapping UI

**Public API & Webhooks** (Month 2-3)
- [ ] Design and implement RESTful API
  - /api/v1/conversations
  - /api/v1/analyze
  - /api/v1/insights
- [ ] Create webhook system
  - conversation.completed
  - insight.generated
  - action_item.created
- [ ] Write developer documentation
  - API reference
  - Integration guides
  - Code examples
- [ ] Build SDK for iOS/Android
  - Native SDKs
  - Example apps

**Team Collaboration** (Month 3-4)
- [ ] Implement shared workspace
  - Multi-user database
  - Real-time collaboration
- [ ] Create team insights dashboard
  - Aggregate analytics
  - Team performance metrics
- [ ] Add commenting and annotations
  - Conversation commenting
  - Timestamp annotations
- [ ] Build permission management
  - Role-based access control
  - Team member management

**Advanced Analytics Dashboard** (Month 4-5)
- [ ] Build conversation trends analysis
  - Time-series visualization
  - Topic trending
- [ ] Create team performance metrics
  - Benchmarking
  - Performance scoring
- [ ] Implement topic clustering
  - Automatic topic detection
  - Topic trend analysis
- [ ] Add custom report builder
  - Drag-and-drop report builder
  - Export to PDF/CSV

**AI Call Scoring** (Month 5)
- [ ] Implement automatic call quality scoring
  - Customizable scorecards
  - MEDDIC, SPICED, BANT frameworks
- [ ] Add performance benchmarking
  - Compare to team average
  - Industry benchmarks
- [ ] Create coaching recommendations
  - AI-powered improvement suggestions
  - Personalized coaching plans

**Enterprise Admin Console** (Month 6)
- [ ] Build user management
  - User provisioning
  - License management
- [ ] Add usage analytics
  - Usage dashboards
  - Cost tracking
- [ ] Implement billing and subscriptions
  - Stripe integration
  - Invoice generation
- [ ] Create security and compliance dashboard
  - Security audit logs
  - Compliance reports

#### Phase 3 Success Metrics
- ✅ CRM integrations live (Salesforce, HubSpot, Dynamics)
- ✅ Public API documented and stable
- ✅ Team features launched
- ✅ Enterprise customers onboarded (target: 5+ companies)
- ✅ 90%+ feature parity achieved

---

## 🔮 Future Enhancements (Beyond Roadmap)

### GPT-Realtime Integration
- [ ] Research WebSocket requirements for GPT-Realtime
- [ ] Create WebSocket client for real-time streaming
- [ ] Implement streaming transcription + analysis
- [ ] Test latency and performance
- [ ] Compare with batch processing approach

### Performance Optimization
- [ ] Profile audio recording performance
- [ ] Optimize buffer sizes for transcription
- [ ] Implement caching for repeated analyses
- [ ] Add background processing for long conversations
- [ ] Reduce memory usage during long sessions

### Smart Glasses Integration Enhancements
- [ ] Advanced HUD layouts
- [ ] Gesture-controlled browsing
- [ ] Auto-hide intelligence
- [ ] Battery optimization
- [ ] Multiple glasses support

### Additional AI Features
- [ ] Fact-checking with source citations
- [ ] Conversation context memory (long-term)
- [ ] Proactive meeting preparation
- [ ] Smart meeting scheduling

### Testing & Quality
- [ ] Add unit tests for new services (>80% coverage)
- [ ] Add integration tests for full pipeline
- [ ] Add UI tests for critical flows
- [ ] Performance benchmarking
- [ ] Load testing for API endpoints

---

## 🐛 Known Issues

### Critical
- None currently blocking

### Non-Critical
- [ ] FactCheckingService has 16 compilation errors (currently disabled)
- [ ] AIInsightsService has 16 compilation errors (currently disabled)
- [ ] Audio recording has 4-5 second delay on first start (debug mode only)
- [ ] iOS build artifacts not properly ignored (build/ folder)

### Technical Debt
- [ ] Remove hardcoded language selection ("en-US")
- [ ] Add proper logging throughout app
- [ ] Implement analytics for feature usage
- [ ] Add telemetry for error tracking
- [ ] Improve error messages for users

---

## 📊 Test Status

### API Tests
- ✅ LLM Endpoint: **PASSED** (3/3 tests)
  - Basic completion
  - Conversation analysis
  - Model selection

- ⏳ Whisper Endpoint: **NEEDS AUDIO FILE**
  - Endpoint configured
  - Test script created
  - Waiting for test audio

### Flutter Tests
- ✅ App compilation: **PASSED** (0 critical errors)
- ✅ Audio recording: **PASSED** (tested on device)
- ⏳ Transcription: **NOT TESTED YET**
- ⏳ AI analysis: **NOT TESTED YET**

### Device Tests
- ✅ iPhone (00008150-001514CC3C00401C): **PASSED**
  - App launches
  - Services initialize
  - Config loads
  - Recording works

---

## 🎯 Success Metrics

### Short-term (This Week)
- [ ] Whisper transcription working end-to-end
- [ ] AI analysis producing useful insights
- [ ] <3 second latency from speech to transcription
- [ ] >80% transcription accuracy on test audio

### Medium-term (This Month)
- [ ] Model selection UI completed
- [ ] Rate limit handling robust
- [ ] Smart glasses integration working
- [ ] Battery life >2 hours continuous use

### Long-term (This Quarter)
- [ ] 95%+ uptime for API services
- [ ] <500ms latency for real-time features
- [ ] User satisfaction >4.5/5
- [ ] Launch beta to 10 users

---

## 📚 Resources

### Documentation
- [LiteLLM API Integration Guide](./LITELLM_API_INTEGRATION.md)
- [Final Integration Status](./FINAL_INTEGRATION_STATUS.md)
- [Custom LLM Plan](./CUSTOM_LLM_INTEGRATION_PLAN.md)
- [Azure OpenAI Guide](./AZURE_OPENAI_INTEGRATION_PLAN.md)

### Testing & Deployment
- [Local Testing Plan](./LOCAL_TESTING_PLAN.md) - Comprehensive test cases and procedures
- [TestFlight Deployment SOP](./TESTFLIGHT_DEPLOYMENT_SOP.md) - Step-by-step deployment guide
- [Architecture Diagram](./ARCHITECTURE.md) - High-level system architecture

### API Endpoints
- **LLM Endpoint**: https://llm.art-ai.me/v1/chat/completions
- **Whisper Transcription**: https://isi-oai-gen5-east-us2-sbx.openai.azure.com/openai/deployments/whisper/audio/transcriptions
- **Whisper Translation**: https://isi-oai-gen5-east-us2-sbx.openai.azure.com/openai/deployments/whisper/audio/translations
- **GPT-Realtime**: wss://isi-oai-gen5-east-us2-sbx.openai.azure.com/openai/realtime

### Test Scripts
- `test_api_integration.dart` - LLM API tests
- `test_whisper_integration.dart` - Whisper transcription tests
- `test_llm_connection.py` - Python API tests

### Configuration
- `llm_config.local.json` - Local config (gitignored, contains API keys)
- `llm_config.local.json.template` - Config template (committed)

---

**Notes**:
- All API keys stored in `llm_config.local.json` (gitignored)
- Use exact Azure deployment names (e.g., `gpt-4.1`, not `gpt-4`)
- Rate limits: 12 req/min (o3-mini) to 2500 req/min (gpt-5)
- Whisper uses direct Azure endpoint, not LiteLLM proxy
