# Roadmap: Helix iOS — App Store Release

## Overview

This roadmap fixes the core reliability issues preventing Helix from shipping to the App Store. Phase 1 makes transcription stream reliably in real time (the foundation everything depends on). Phase 2 fixes Q&A delivery to the glasses HUD and replaces the slow fact-checking path. Phase 3 adds onboarding and compliance for App Store submission.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [ ] **Phase 1: Transcription Reliability** - Fix real-time streaming, eliminate gaps and batching delays across all backends
- [ ] **Phase 2: Q&A Pipeline and Fact-Checking** - Fix answer delivery to glasses HUD, concurrent transcript flow, and faster fact-checking
- [ ] **Phase 3: App Store Submission** - Onboarding flow and privacy manifest for store compliance

## Phase Details

### Phase 1: Transcription Reliability
**Goal**: Users experience continuous, real-time transcription with no perceptible delays or missing words
**Depends on**: Nothing (first phase)
**Requirements**: TRNS-01, TRNS-02, TRNS-03, TRNS-04
**Success Criteria** (what must be TRUE):
  1. Partial transcription text appears on the phone within 1 second of the user speaking
  2. A 60-second continuous speech sample produces a transcript with no missing words or mid-sentence gaps
  3. Switching between OpenAI Realtime and Apple Cloud backends both produce usable real-time transcription
  4. No 30-second batching delays occur during any listening session
**Plans**: TBD

### Phase 2: Q&A Pipeline and Fact-Checking
**Goal**: Users get reliable AI answers on their glasses during live conversations, with fast background fact-checking
**Depends on**: Phase 1
**Requirements**: QA-01, QA-02, QA-03, QA-04, FACT-01
**Success Criteria** (what must be TRUE):
  1. When a question is detected during a live session, the AI answer appears on the glasses HUD within 3 seconds
  2. Multi-page answers can be navigated with touchpad forward/back gestures on the glasses
  3. While an AI answer is displayed on the glasses, the phone continues showing live transcription updates
  4. After an AI answer is generated, a fact-check result arrives within 5 seconds using OpenAI web search
**Plans**: TBD

### Phase 3: App Store Submission
**Goal**: New users can set up the app without external help, and the app meets Apple's submission requirements
**Depends on**: Phase 2
**Requirements**: SHIP-01, SHIP-02
**Success Criteria** (what must be TRUE):
  1. A first-time user is guided through API key entry, glasses pairing, and microphone permission in a single onboarding flow
  2. The app includes a valid PrivacyInfo.xcprivacy manifest declaring all required data usage categories
**Plans**: TBD
**UI hint**: yes

## Progress

**Execution Order:**
Phases execute in numeric order: 1 → 2 → 3

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Transcription Reliability | 0/0 | Not started | - |
| 2. Q&A Pipeline and Fact-Checking | 0/0 | Not started | - |
| 3. App Store Submission | 0/0 | Not started | - |
