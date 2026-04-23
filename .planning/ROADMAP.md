# Roadmap: Helix iOS — App Store Release

## Overview

This roadmap fixes the core reliability issues preventing Helix from shipping to the App Store. Phase 1 makes transcription stream reliably in real time (the foundation everything depends on). Phase 1.1 (inserted) verifies the per-project document RAG feature — implemented out-of-band but unverified end-to-end on device. Phase 2 fixes Q&A delivery to the glasses HUD and replaces the slow fact-checking path. Phase 3 adds onboarding and compliance for App Store submission.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [ ] **Phase 1: Transcription Reliability** - Fix real-time streaming, eliminate gaps and batching delays across all backends
- [ ] **Phase 1.1: Project RAG — Verification & Polish** (INSERTED) - Validate the per-project document RAG feature end-to-end on a simulator and close any gaps surfaced by the smoke test
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
**Plans:** 2 plans
Plans:
- [ ] 01-01-PLAN.md — Test and validate streaming fixes (no Dart suppression, no VAD gating)
- [ ] 01-02-PLAN.md — Tune segment restart timing and harden multi-backend reliability

### Phase 1.1: Project RAG — Verification & Polish (INSERTED)
**Goal**: Users can rely on the per-project document RAG feature end-to-end — upload documents, select an active project, and have live conversation answers and the Ask-this-project flow pull correct citations from their docs
**Depends on**: None (feature is already implemented in commits cf57bad..b6502e1; this phase verifies and polishes it)
**Requirements**: Implementation plan `docs/superpowers/plans/2026-04-21-project-rag.md` Task 18 (simulator smoke test) plus any gaps surfaced during verification
**Success Criteria** (what must be TRUE):
  1. On a dedicated Helix simulator, creating a project, uploading a TXT and a 2–3 page PDF all transition through pending → processing → ready without user intervention
  2. "Ask this project" correctly cites `[1]` for a known-unique fact from the uploaded TXT
  3. Selecting an active project persists across app restart, and the home-screen chip reflects the current selection (including "No project" when none is active)
  4. During a live conversation with an active project selected, the generated answer references project content and citation chips appear beneath the answer; tapping a chip reveals the source excerpt
  5. Deleting a project moves it to "Recently deleted", and undo restores it; restored projects survive an app restart
**Plans:** 2 plans
Plans:
- [ ] 01.1-01-PLAN.md — Pre-flight fixtures and gate baseline (TXT+PDF fixtures, run validation gate, scaffold evidence/GAPS.md)
- [ ] 01.1-02-PLAN.md — Simulator smoke walkthrough on iPhone 17 Pro (0D7C3AB2): verify SC-1..SC-5 phone-side + b6502e1 regression check

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
Phases execute in numeric order: 1 → 1.1 → 2 → 3

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Transcription Reliability | 0/2 | Planning complete | - |
| 1.1. Project RAG — Verification & Polish (INSERTED) | 0/2 | Planning complete | - |
| 2. Q&A Pipeline and Fact-Checking | 0/0 | Not started | - |
| 3. App Store Submission | 0/0 | Not started | - |
