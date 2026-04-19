# Requirements: Helix iOS — App Store Release

**Defined:** 2026-04-18
**Core Value:** Real-time transcription must stream reliably with zero perceptible delay

## v1 Requirements

### Transcription

- [ ] **TRNS-01**: Transcription streams to UI in real time — no batching delay, partials appear as words are recognized
- [ ] **TRNS-02**: No mid-sentence gaps — transcription does not cut out or lose words during continuous speech
- [ ] **TRNS-03**: Segment restart interval tuned for optimal quality vs latency tradeoff
- [ ] **TRNS-04**: OpenAI Realtime and Whisper batch backends both produce reliable end-to-end transcription

### Q&A and HUD

- [ ] **QA-01**: AI answers consistently appear on glasses HUD during live listening sessions
- [ ] **QA-02**: Long answers paginate correctly with touchpad forward/back navigation
- [ ] **QA-03**: Transcript keeps updating on the phone while AI answer is displayed on glasses
- [ ] **QA-04**: Time from question detected to first answer token on HUD under 3 seconds

### Fact-Checking

- [ ] **FACT-01**: Fact-checking uses OpenAI web search (Responses API with web_search tool) instead of slow Tavily path

### App Store Polish

- [ ] **SHIP-01**: First-launch onboarding flow — API key setup, glasses pairing, permission requests
- [ ] **SHIP-02**: PrivacyInfo.xcprivacy manifest for App Store compliance

## v2 Requirements

### Enhanced Intelligence

- **INTL-01**: Proactive insights — surface relevant context in passive mode without being asked
- **INTL-02**: Sentiment analysis — real-time mood/tone detection of conversation participants
- **INTL-03**: Conversation summaries — auto-generated meeting notes and key takeaways

### Reliability

- **REL-01**: Graceful error recovery — BLE disconnects, API failures, network loss handled smoothly
- **REL-02**: Session stability — no crashes during 30+ minute continuous sessions
- **REL-03**: Fact-check citations — show source URLs with fact-check results
- **REL-04**: Inline corrections — push corrections to glasses HUD when answer is wrong

## Out of Scope

| Feature | Reason |
|---------|--------|
| Android support | iOS-only for initial release |
| Custom LLM fine-tuning | Use off-the-shelf models |
| Voice response output | Text-only for v1; voice assistant exists but not ship-critical |
| Multi-language simultaneous detection | Single language per session is sufficient |
| Cloud sync / user accounts | Local-only for v1 |
| BLE reconnect reliability | Hardware-dependent; defer to post-launch |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| TRNS-01 | — | Pending |
| TRNS-02 | — | Pending |
| TRNS-03 | — | Pending |
| TRNS-04 | — | Pending |
| QA-01 | — | Pending |
| QA-02 | — | Pending |
| QA-03 | — | Pending |
| QA-04 | — | Pending |
| FACT-01 | — | Pending |
| SHIP-01 | — | Pending |
| SHIP-02 | — | Pending |

**Coverage:**
- v1 requirements: 11 total
- Mapped to phases: 0
- Unmapped: 11 (roadmap pending)

---
*Requirements defined: 2026-04-18*
*Last updated: 2026-04-18 after initial definition*
