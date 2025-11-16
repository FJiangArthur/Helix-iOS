# Helix AI Features Implementation Plan

**Date**: 2025-11-14
**Purpose**: Implement real AI functionality to replace mock features in the AI Assistant tab

## Current State

### Working Features ✅
- Audio recording and playback (verified on iOS device)
- Real-time waveform visualization
- Recording duration tracking
- File management and storage

### Mock/Fake Features ❌
- AI Personas (hardcoded list)
- Real-time Analysis (static progress bar)
- Fact Checking (hardcoded fake facts)
- Conversation Insights (UI exists but not connected)
- LLM Providers (fake toggle switches)

### Services Already Integrated (Untested) ⏸️
- `LLMServiceImplV2` - Multi-provider LLM service (OpenAI + Anthropic)
- `FactCheckingService` - Real-time fact checking
- `AIInsightsService` - Conversation insights generation
- `TranscriptionCoordinator` - Speech-to-text (Native + Whisper API)
- `ConversationInsights` - Conversation analysis and summary
- `AICoordinator` - AI analysis orchestration

---

## Implementation Options

### Option 1: Phone-Only Implementation (Recommended for MVP)

**Flow**: Phone Recording → Transcription → AI Analysis → Display on Phone Screen

**Advantages**:
- Simpler implementation
- Faster to complete (3-5 days)
- No hardware dependencies
- Easier to test and debug
- Works for all users

**Implementation Steps**:
1. Connect audio recording to transcription service
2. Wire transcription to AI analysis services
3. Connect AI results to UI components
4. Add real-time updates and streaming
5. Implement analytics/tracking

**Timeline**: 3-5 days

---

### Option 2: Phone + Even Realities Glasses (Full Feature)

**Flow**: Phone Recording → Transcription → AI Analysis → Display on Phone + Stream to Glasses HUD

**Advantages**:
- Full product vision realized
- Hands-free AR experience
- Real-time HUD feedback
- Differentiating feature

**Additional Requirements**:
- Even Realities G1 glasses hardware
- Bluetooth connection management
- HUD rendering and text pagination
- Touch gesture handling
- Battery optimization

**Timeline**: 5-7 days (includes Bluetooth integration)

---

## Detailed Implementation Plan (Option 1 - Recommended)

### Phase 1: Transcription Integration (Day 1)

**Goal**: Connect audio recording to speech-to-text transcription

**Tasks**:
1. Initialize `TranscriptionCoordinator` in main app
2. Connect audio recording to transcription service
3. Set up transcription mode (Native vs Whisper API)
4. Display real-time transcription in UI
5. Handle transcription errors gracefully

**Files to Modify**:
- `lib/main.dart` - Initialize transcription service
- `lib/screens/recording_screen.dart` - Connect recording to transcription
- `lib/services/service_locator.dart` - Register transcription services
- `lib/screens/ai_assistant_screen.dart` - Display transcription results

**Success Criteria**:
- ✅ Real-time transcription appears during recording
- ✅ Transcription text is accurate and timely
- ✅ Both Native and Whisper modes work correctly

---

### Phase 2: AI Analysis Integration (Day 2)

**Goal**: Connect transcription to AI analysis services

**Tasks**:
1. Initialize LLM services with API keys
2. Connect transcription stream to AI coordinator
3. Implement real-time fact checking
4. Generate conversation insights
5. Display AI analysis results in UI

**Files to Modify**:
- `lib/services/service_locator.dart` - Initialize AI services
- `lib/services/evenai.dart` - Connect to AI coordinator
- `lib/screens/ai_assistant_screen.dart` - Display real AI results
- `lib/services/conversation_insights.dart` - Wire up insights generation

**Success Criteria**:
- ✅ Fact checking works on real conversation text
- ✅ AI insights generate summary, key points, action items
- ✅ Sentiment analysis displays accurate results
- ✅ Multiple LLM providers work with failover

---

### Phase 3: UI Integration & Real-time Updates (Day 3)

**Goal**: Replace all mock data with real AI results

**Tasks**:
1. Remove hardcoded mock data from AI Assistant screen
2. Connect UI to real-time insight streams
3. Implement loading states and error handling
4. Add refresh functionality
5. Polish UI/UX with real data

**Files to Modify**:
- `lib/screens/ai_assistant_screen.dart` - Remove mocks, add real data
- Update personas to trigger real AI analysis
- Connect fact-checking card to real service
- Wire conversation insights to real data stream

**Success Criteria**:
- ✅ No mock/fake data in UI
- ✅ Real-time updates during conversation
- ✅ Proper loading and error states
- ✅ Smooth user experience

---

### Phase 4: Analytics & Tracking (Day 4)

**Goal**: Add comprehensive tracking for user interactions and AI features

**Tasks**:
1. Add analytics service (Firebase Analytics or custom)
2. Track recording sessions (start, stop, duration)
3. Track transcription events (success, errors, mode)
4. Track AI analysis usage (fact-checks, insights, summaries)
5. Track user interactions (persona selection, feature usage)
6. Add performance monitoring

**Files to Create/Modify**:
- `lib/services/analytics_service.dart` - Create analytics service
- `lib/screens/recording_screen.dart` - Add recording analytics
- `lib/screens/ai_assistant_screen.dart` - Add AI feature analytics
- `lib/services/evenai.dart` - Add transcription analytics

**Events to Track**:
- `recording_started` - When user starts recording
- `recording_stopped` - When user stops recording
- `transcription_completed` - When transcription finishes
- `fact_check_performed` - When fact-checking runs
- `insights_generated` - When AI generates insights
- `persona_selected` - When user selects AI persona
- `error_occurred` - Any errors with context

**Success Criteria**:
- ✅ All key user actions are tracked
- ✅ Analytics data is accurate and complete
- ✅ Performance metrics are monitored
- ✅ Privacy-compliant tracking implementation

---

### Phase 5: Testing & Polish (Day 5)

**Goal**: Comprehensive testing and bug fixes

**Tasks**:
1. End-to-end testing of full workflow
2. Test with different conversation lengths
3. Test error scenarios and edge cases
4. Performance optimization
5. UI/UX polish and refinements
6. Documentation updates

**Test Scenarios**:
- Short conversation (30 seconds)
- Medium conversation (5 minutes)
- Long conversation (15+ minutes)
- Poor audio quality
- Network disconnection during transcription
- API failures and rate limiting
- Multiple consecutive recordings

**Success Criteria**:
- ✅ All features work reliably
- ✅ Good performance under various conditions
- ✅ Clear error messages and recovery paths
- ✅ Professional user experience

---

## API Configuration Required

### OpenAI API
- **Required for**: Whisper transcription, GPT-4 analysis
- **Configuration**: Add to `settings.local.json`
```json
{
  "openAIApiKey": "sk-..."
}
```

### Anthropic API (Optional)
- **Required for**: Backup LLM provider
- **Configuration**: Add to `settings.local.json`
```json
{
  "anthropicApiKey": "sk-ant-..."
}
```

---

## Implementation Approach for Option 2 (Glasses Integration)

If you choose Option 2, add these additional phases:

### Phase 6: Bluetooth & Glasses Connection (Day 6)
- Initialize BLE manager for Even Realities
- Implement device discovery and pairing
- Handle connection state management
- Add reconnection logic

### Phase 7: HUD Display Integration (Day 7)
- Implement text pagination for HUD
- Stream transcription to glasses
- Display AI insights on HUD
- Handle touch gestures from glasses

---

## Recommended Approach

**I recommend starting with Option 1** (Phone-Only Implementation) because:

1. **Faster to implement and test** - 3-5 days vs 5-7 days
2. **No hardware dependencies** - Works for all users
3. **Easier to debug** - Fewer moving parts
4. **Can add glasses later** - Option 2 builds on Option 1

Once Option 1 is working well, we can add glasses integration incrementally.

---

## Analytics Tracking Strategy

### Key Metrics to Track

**Usage Metrics**:
- Daily/weekly/monthly active users
- Recording sessions per user
- Average recording duration
- Feature usage frequency

**AI Feature Metrics**:
- Transcription success rate
- Transcription mode usage (Native vs Whisper)
- Fact-checking requests
- Insights generation requests
- AI persona usage
- LLM provider distribution

**Performance Metrics**:
- Transcription latency
- AI analysis duration
- Error rates by feature
- API failure rates
- Battery consumption

**Engagement Metrics**:
- Time spent in app
- Features used per session
- Conversation review frequency
- User retention rates

### Privacy Considerations

- **No PII tracking** - User IDs should be anonymized
- **Opt-in analytics** - Users should consent
- **Local-first** - Consider local analytics before cloud
- **Data minimization** - Only track essential metrics

---

## Next Steps

Please review both options and let me know which approach you'd like to take:

1. **Option 1**: Phone-only implementation (3-5 days)
2. **Option 2**: Phone + Glasses implementation (5-7 days)

Once you confirm, I'll start implementing:

**Phase 1**: Transcription Integration
**Phase 2**: AI Analysis Integration
**Phase 3**: UI Integration & Real-time Updates
**Phase 4**: Analytics & Tracking
**Phase 5**: Testing & Polish

(Plus Phase 6-7 if Option 2 is selected)
