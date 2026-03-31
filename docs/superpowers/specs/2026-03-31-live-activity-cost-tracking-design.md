# Live Activity Cost Tracking Design

**Date:** 2026-03-31

**Project:** Helix-iOS

**Status:** Approved for planning

## Goal

Add a lock-screen Live Activity for active conversation sessions that:

- shows the active detected question while the answer is being generated and streamed
- shows cumulative session cost across transcription, question detection, and answer generation
- supports OpenAI plus Chinese providers with provider-specific pricing and parsing
- supports an interrupting `Ask Now` button that runs from the Live Activity without opening the app UI
- supports a separate `Open App` button that explicitly foregrounds Helix

## Non-Goals

- Rebuilding the assistant stack in Swift
- Approximating cost when usage or pricing metadata is unavailable
- Opening the app automatically for `Ask Now`
- Supporting multiple simultaneous response generations

## Current State

- Native Live Activity scaffolding already exists in the iOS app and widget extension.
- Flutter does not currently call the native `startLiveActivity`, `updateLiveActivity`, or `stopLiveActivity` methods.
- The conversation pipeline already exists in Dart and is authoritative for question detection, answer generation, provider selection, and manual ask behavior.
- The LLM abstraction currently streams text only. It does not expose usage metadata or cost.
- The OpenAI realtime transcription path handles transcript events but does not currently parse usage metadata.
- Chinese providers are routed through the existing provider stack, but pricing and usage normalization do not exist yet.

## Product Decisions

- Session cost includes all supported AI work in the active session:
  - transcription
  - question detection
  - answer generation
- Cost display must be provider-specific.
- If usage or pricing is incomplete for a provider or model, Helix shows usage-only or incomplete-cost state instead of invented numbers.
- `Ask Now` must run from the Live Activity without opening the app UI.
- `Ask Now` is interrupting:
  - if an old response is still streaming, Helix cancels it and starts a new analysis immediately
  - the newest ask wins
- A separate `Open App` control must be available.

## Recommended Architecture

### 1. Keep One Assistant System

Helix should keep a single authoritative conversation system in Dart.

- `ConversationEngine` remains the source of truth for session state, question detection, and answer generation.
- Provider routing remains in the existing provider stack.
- The new feature adds orchestration and accounting layers around the existing pipeline rather than duplicating assistant behavior in Swift.

### 2. Add a Dart Live Activity Service

Create a Dart `LiveActivityService` responsible for:

- subscribing to engine lifecycle, status, question detection, answer streaming, and provider/model state
- maintaining a `LiveActivitySessionSnapshot`
- bridging that snapshot to the native iOS methods that start, update, and stop the Live Activity
- pinning the active question while the answer area updates independently

This service should own the display state contract. The widget extension should render a prepared state object, not derive product logic itself.

### 3. Add a Background Ask Path

Add a native iOS `AppIntent` for `Ask Now` that runs from the Live Activity surface.

- The intent must not open the UI.
- The intent updates the Live Activity into `Analyzing`.
- The intent hands off work to a headless Helix worker path that reuses the existing Dart pipeline.
- The result flows back into the same Live Activity state update path.

Add a separate `Open App` path using explicit deep linking.

### 4. Keep Native Live Activity Code Thin

The native iOS side should only:

- start, update, and stop the activity
- render SwiftUI lock-screen and Dynamic Island views
- host the interaction intents
- bridge background intent execution into the headless Helix worker

It should not own provider pricing logic or independent question-answer logic.

## Cost Accounting Model

### Ledger Model

Session cost should be tracked as a ledger, not a single number guessed from the last answer.

Each ledger item stores:

- `operationType`
- `providerId`
- `modelId`
- `usage`
- `pricingVersion`
- `calculatedCost`
- `currency`
- `startedAt`
- `completedAt`
- `status`

`operationType` has three values:

- `transcription`
- `questionDetection`
- `answerGeneration`

### Usage Rules

- Usage must come from provider-native metadata when available.
- Chat-style providers must emit final usage information after the request finishes.
- Realtime transcription and realtime answer flows must parse usage from their completion events.
- If a request is canceled, the ledger should keep the partial attempt with its actual known usage and cost status.

### Pricing Rules

- Pricing is provider-specific and model-specific.
- Pricing should live in an app-level registry, not in UI code.
- The registry must support different rate dimensions when relevant:
  - input
  - output
  - cached input
  - transcription
- If usage exists but pricing is unknown, Helix shows incomplete cost state.
- If pricing exists but usage is missing, Helix does not estimate from text length.

### Provider Scope

The design must support:

- OpenAI
- DeepSeek
- Qwen
- Zhipu

## Live Activity UX

### Lock-Screen Content

While a session is active, the Live Activity shows:

- session mode
- provider and active model
- elapsed session duration
- cumulative session cost
- active question
- answer state and answer text

### Question and Answer Behavior

- Once a question is detected, it becomes the pinned active question.
- The pinned question stays visible while the answer is generated and streamed.
- The answer section updates independently underneath the question.
- A newer detected question replaces the previous pinned question.

### Ask Now Behavior

- `Ask Now` immediately interrupts any in-flight response.
- The current response generation is canceled.
- The Live Activity switches to `Analyzing`.
- Helix reuses the latest available transcript context and starts a fresh analysis cycle.
- The previous answer stops streaming and is replaced by the new active turn when ready.
- Cost ledger entries for interrupted attempts remain recorded, but the UI only presents the newest active turn.

### Open App Behavior

- `Open App` always foregrounds Helix explicitly.
- `Open App` does not imply a new ask.
- It is a navigation control, not an analysis control.

### Error and Edge States

- If there is not enough context for `Ask Now`, show a short `Need more context` state and return to listening.
- If provider usage is unavailable, show a clear incomplete-cost state.
- If background execution fails, show a compact error state and keep the session alive.
- Only one response generation may be active at a time.

## State Machine

The Live Activity state machine should be semantic and minimal:

- `Listening`
- `Analyzing`
- `Answering`
- `ShowingResult`
- `Error`
- `Ended`

State transitions:

- session start -> `Listening`
- detected question -> `Analyzing`
- answer stream begins -> `Answering`
- answer completes -> `ShowingResult`
- `Ask Now` during `Answering` -> cancel old response, then `Analyzing`
- session stop -> `Ended`

## Testing Requirements

- verify question pinning while answer text changes
- verify ledger accumulation across transcription, question detection, and answer generation
- verify provider-specific usage parsing and pricing lookup
- verify interrupted `Ask Now` behavior cancels the old response and starts a new one
- verify incomplete-cost display rules
- verify `Open App` does not trigger analysis
- verify session end behavior cleans up the activity correctly

## Risks

- Background intent handoff into a headless Flutter worker is the most complex integration point.
- Provider usage shapes may differ enough that normalization needs careful tests.
- Realtime flows may expose usage only at completion, which means cost display must tolerate short pending windows.

## Success Criteria

- A user in an active session can read the current question and streamed answer on the lock screen.
- The displayed cost reflects provider-specific accumulated session cost across approved operation types.
- `Ask Now` works without opening the app UI and interrupts old responses correctly.
- `Open App` is available as a distinct control.
- The feature works with OpenAI and the approved Chinese providers through a shared accounting abstraction.
