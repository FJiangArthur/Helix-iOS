# Local Testing Plan - Helix iOS App

**Last Updated**: 2025-11-15  
**Version**: 1.0  
**Target Platforms**: iOS 14.0+, Physical Devices & Simulators

---

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Environment Setup](#environment-setup)
3. [Pre-Test Checklist](#pre-test-checklist)
4. [Testing Phases](#testing-phases)
5. [Test Cases](#test-cases)
6. [Device Testing Matrix](#device-testing-matrix)
7. [Performance Benchmarks](#performance-benchmarks)
8. [Bug Reporting](#bug-reporting)

---

## Prerequisites

### Required Software
- **Xcode**: 15.0+ (latest stable version recommended)
- **Flutter**: 3.24.0+
- **Dart**: 3.5.0+
- **CocoaPods**: 1.11.0+
- **iOS SDK**: 17.0+

### Required Hardware
- **Mac**: macOS 13.0 (Ventura) or later
- **iOS Device**: iPhone running iOS 14.0+ (for physical testing)
- **USB-C Cable**: For device connection
- **Even Realities Smart Glasses**: For full feature testing (optional)

### Required Accounts
- **Apple Developer Account**: For code signing
- **API Access**: LLM endpoint credentials configured in `llm_config.local.json`

---

## Environment Setup

### 1. Clone and Setup Repository

```bash
# Clone repository
git clone https://github.com/FJiangArthur/Helix-iOS.git
cd Helix-iOS

# Ensure you're on main branch
git checkout main
git pull origin main

# Install Flutter dependencies
flutter pub get

# Install iOS dependencies
cd ios
pod install
cd ..
```

### 2. Configure API Keys

```bash
# Copy config template
cp llm_config.local.json.template llm_config.local.json

# Edit with your API keys
# Required fields:
# - llmApiKey: Your LiteLLM API key
# - llmEndpoint: https://llm.art-ai.me/v1/chat/completions
```

**llm_config.local.json** example:
```json
{
  "llmEndpoint": "https://llm.art-ai.me/v1/chat/completions",
  "llmApiKey": "sk-YOUR-API-KEY-HERE",
  "llmModel": "gpt-4.1-mini",
  "llmModels": {
    "fast": "gpt-4.1-mini",
    "balanced": "gpt-4.1",
    "advanced": "gpt-5",
    "reasoning": "o3"
  },
  "transcription": {
    "enabled": true,
    "provider": "azure-whisper",
    "endpoint": "https://isi-oai-gen5-east-us2-sbx.openai.azure.com/openai/deployments/whisper/audio/transcriptions",
    "apiVersion": "2024-06-01"
  }
}
```

### 3. Verify Build Configuration

```bash
# Check Flutter environment
flutter doctor -v

# Expected output: All checks pass (✓)
# If issues found, resolve before proceeding
```

### 4. Code Signing Setup

```bash
# Open Xcode project
open ios/Runner.xcworkspace

# In Xcode:
# 1. Select Runner target
# 2. Go to Signing & Capabilities
# 3. Select your Team
# 4. Enable "Automatically manage signing"
# 5. Verify Bundle Identifier: com.helix.ios (or your custom ID)
```

---

## Pre-Test Checklist

### ☐ Code Quality
- [ ] No compilation errors (`flutter analyze`)
- [ ] All critical warnings resolved
- [ ] Code formatted (`dart format .`)
- [ ] No TODO comments in critical paths

### ☐ Dependencies
- [ ] All packages up to date (`flutter pub outdated`)
- [ ] No dependency conflicts
- [ ] CocoaPods dependencies resolved

### ☐ Configuration
- [ ] `llm_config.local.json` exists and valid
- [ ] API keys active and not expired
- [ ] Network connectivity confirmed

### ☐ Build Verification
- [ ] Debug build succeeds
- [ ] Release build succeeds
- [ ] No code signing issues

---

## Testing Phases

### Phase 1: Smoke Testing (15 minutes)

**Goal**: Verify app launches and basic navigation works

**Test Steps**:
1. Launch app on simulator
2. Verify splash screen appears
3. Navigate through all main tabs
4. Check for crash on startup
5. Verify UI renders correctly

**Success Criteria**:
- ✅ App launches without crash
- ✅ All tabs accessible
- ✅ No visual glitches

### Phase 2: Functional Testing (1-2 hours)

**Goal**: Test all major features end-to-end

**Test Areas**:
1. Audio Recording
2. Transcription
3. AI Analysis
4. Smart Glasses Integration
5. Settings & Configuration

### Phase 3: Integration Testing (30 minutes)

**Goal**: Verify all services work together

**Test Scenarios**:
1. Record → Transcribe → Analyze workflow
2. API error handling
3. Network connectivity changes
4. Background/foreground transitions

### Phase 4: Performance Testing (30 minutes)

**Goal**: Measure app performance metrics

**Metrics to Collect**:
1. App launch time
2. Audio recording latency
3. Transcription speed
4. Memory usage
5. Battery consumption

### Phase 5: Regression Testing (30 minutes)

**Goal**: Ensure previous bugs haven't reappeared

**Test Cases**:
1. Audio service state management
2. Recording button responsiveness
3. Multiple recording sessions
4. Config file loading

---

## Test Cases

### TC-001: Audio Recording - Basic Flow

**Priority**: Critical  
**Estimated Time**: 5 minutes

**Prerequisites**:
- Microphone permission granted
- App freshly launched

**Steps**:
1. Open app and navigate to Recording tab
2. Tap record button
3. Speak for 5 seconds
4. Tap stop button
5. Verify audio file saved

**Expected Results**:
- ✅ Record button changes to stop button
- ✅ Timer displays elapsed time
- ✅ Waveform shows audio levels
- ✅ Recording stops cleanly
- ✅ Audio file exists in storage

**Actual Results**: _________

**Status**: ☐ Pass | ☐ Fail | ☐ Blocked

---

### TC-002: Audio Recording - Multiple Sessions

**Priority**: High  
**Estimated Time**: 10 minutes

**Prerequisites**:
- TC-001 passed

**Steps**:
1. Start first recording (5 seconds)
2. Stop recording
3. Wait 2 seconds
4. Start second recording (5 seconds)
5. Stop recording
6. Repeat 3 more times

**Expected Results**:
- ✅ All recordings complete successfully
- ✅ No crashes or freezes
- ✅ Each recording has unique filename
- ✅ Timer resets between sessions

**Known Issue**: 4-5 second delay on first recording in debug mode

**Actual Results**: _________

**Status**: ☐ Pass | ☐ Fail | ☐ Blocked

---

### TC-003: LLM API - Basic Completion

**Priority**: Critical  
**Estimated Time**: 3 minutes

**Prerequisites**:
- `llm_config.local.json` configured
- Network connectivity

**Steps**:
1. Navigate to AI Test screen
2. Enter test prompt: "Hello, test"
3. Tap "Send" button
4. Wait for response

**Expected Results**:
- ✅ Loading indicator shows
- ✅ Response received within 5 seconds
- ✅ Response text displayed
- ✅ Token count shown

**Actual Results**: _________

**Status**: ☐ Pass | ☐ Fail | ☐ Blocked

---

### TC-004: LLM API - Model Selection

**Priority**: High  
**Estimated Time**: 5 minutes

**Prerequisites**:
- TC-003 passed

**Steps**:
1. Go to Settings → Model Selection
2. Select "Fast" model (gpt-4.1-mini)
3. Run test completion
4. Select "Advanced" model (gpt-5)
5. Run test completion
6. Compare responses

**Expected Results**:
- ✅ Model selection saves
- ✅ Both models respond successfully
- ✅ Response quality differs appropriately

**Actual Results**: _________

**Status**: ☐ Pass | ☐ Fail | ☐ Blocked

---

### TC-005: Transcription - Whisper Integration

**Priority**: High  
**Estimated Time**: 10 minutes

**Prerequisites**:
- Audio recording works (TC-001)
- Whisper endpoint configured

**Steps**:
1. Record 10-second audio clip with clear speech
2. Trigger transcription
3. Wait for result
4. Verify transcription accuracy

**Test Audio Script**:
> "This is a test of the Whisper transcription service. The quick brown fox jumps over the lazy dog. Testing one two three."

**Expected Results**:
- ✅ Transcription completes within 10 seconds
- ✅ Accuracy >80% (allow minor errors)
- ✅ Proper punctuation and capitalization
- ✅ Confidence score displayed

**Actual Results**: _________

**Status**: ☐ Pass | ☐ Fail | ☐ Blocked

---

### TC-006: AI Analysis - Conversation Summary

**Priority**: High  
**Estimated Time**: 10 minutes

**Prerequisites**:
- TC-003 passed
- Sample conversation text prepared

**Steps**:
1. Navigate to Analysis screen
2. Input sample conversation:
   ```
   User: What's the status of the project?
   Assistant: The project is 80% complete. We've finished the API integration and audio recording. Still need to implement transcription and testing.
   User: When will testing be done?
   Assistant: Testing should be complete by end of week.
   ```
3. Trigger analysis
4. Review results

**Expected Results**:
- ✅ Summary generated within 10 seconds
- ✅ Key topics identified (project status, timeline)
- ✅ Action items extracted (complete testing)
- ✅ No hallucinations or incorrect info

**Actual Results**: _________

**Status**: ☐ Pass | ☐ Fail | ☐ Blocked

---

### TC-007: Error Handling - Network Failure

**Priority**: High  
**Estimated Time**: 5 minutes

**Prerequisites**:
- App running

**Steps**:
1. Enable Airplane Mode
2. Attempt LLM API call
3. Verify error message
4. Disable Airplane Mode
5. Retry API call

**Expected Results**:
- ✅ User-friendly error message shown
- ✅ App doesn't crash
- ✅ Retry succeeds after network restored
- ✅ Loading indicator stops on error

**Actual Results**: _________

**Status**: ☐ Pass | ☐ Fail | ☐ Blocked

---

### TC-008: Error Handling - Invalid API Key

**Priority**: High  
**Estimated Time**: 5 minutes

**Prerequisites**:
- Access to config file

**Steps**:
1. Edit `llm_config.local.json`
2. Change API key to invalid value
3. Restart app
4. Attempt API call
5. Restore valid API key

**Expected Results**:
- ✅ Clear authentication error shown
- ✅ Suggestion to check config file
- ✅ App remains functional
- ✅ Works after fixing API key

**Actual Results**: _________

**Status**: ☐ Pass | ☐ Fail | ☐ Blocked

---

### TC-009: Performance - App Launch Time

**Priority**: Medium  
**Estimated Time**: 5 minutes

**Prerequisites**:
- Release build installed

**Steps**:
1. Force quit app
2. Start timer
3. Launch app
4. Stop timer when first screen visible
5. Repeat 5 times, calculate average

**Expected Results**:
- ✅ Average launch time <3 seconds
- ✅ No splash screen freeze
- ✅ Consistent performance across runs

**Measurements**:
- Run 1: _____ seconds
- Run 2: _____ seconds
- Run 3: _____ seconds
- Run 4: _____ seconds
- Run 5: _____ seconds
- **Average**: _____ seconds

**Status**: ☐ Pass | ☐ Fail | ☐ Blocked

---

### TC-010: Performance - Memory Usage

**Priority**: Medium  
**Estimated Time**: 10 minutes

**Prerequisites**:
- Xcode Instruments available

**Steps**:
1. Open Instruments (Xcode → Open Developer Tool → Instruments)
2. Select "Leaks" template
3. Run app on device
4. Perform 10 recording sessions
5. Check for memory leaks

**Expected Results**:
- ✅ No memory leaks detected
- ✅ Memory usage <200MB during idle
- ✅ Memory released after recordings

**Measurements**:
- Idle memory: _____ MB
- Peak memory: _____ MB
- Leaks detected: _____ 

**Status**: ☐ Pass | ☐ Fail | ☐ Blocked

---

## Device Testing Matrix

| Device Model | iOS Version | Screen Size | Test Status | Tester | Issues Found |
|--------------|-------------|-------------|-------------|--------|--------------|
| iPhone 15 Pro | 17.5 | 6.1" | ☐ | - | - |
| iPhone 14 | 17.0 | 6.1" | ☐ | - | - |
| iPhone 13 Mini | 16.5 | 5.4" | ☐ | - | - |
| iPhone 12 | 16.0 | 6.1" | ☐ | - | - |
| iPhone SE (3rd) | 16.0 | 4.7" | ☐ | - | - |
| iPhone 11 | 15.0 | 6.1" | ☐ | - | - |
| iPhone XR | 14.0 | 6.1" | ☐ | - | - |
| Simulator 15 Pro | 17.5 | 6.1" | ☐ | - | - |
| Simulator 13 | 16.0 | 6.1" | ☐ | - | - |

---

## Performance Benchmarks

### Target Metrics

| Metric | Target | Acceptable | Unacceptable |
|--------|--------|------------|--------------|
| App Launch Time | <2s | <3s | >3s |
| Audio Recording Start | <500ms | <1s | >1s |
| Transcription (10s audio) | <5s | <10s | >10s |
| AI Analysis Response | <3s | <5s | >5s |
| Memory Usage (Idle) | <100MB | <150MB | >200MB |
| Memory Usage (Active) | <200MB | <300MB | >400MB |
| Battery Drain (1hr use) | <10% | <15% | >20% |
| UI Frame Rate | 60 FPS | >50 FPS | <50 FPS |

### Measurement Tools

1. **Xcode Instruments**
   - Time Profiler: CPU usage
   - Allocations: Memory usage
   - Leaks: Memory leaks
   - Energy Log: Battery consumption

2. **Flutter DevTools**
   - Performance view: Frame rendering
   - Memory view: Dart memory
   - Network view: API calls

3. **Manual Testing**
   - Stopwatch for timing
   - Visual inspection for UI
   - Audio quality assessment

---

## Bug Reporting

### Bug Report Template

```markdown
## Bug ID: BUG-YYYY-MM-DD-###

**Title**: [Brief description]

**Severity**: Critical | High | Medium | Low

**Priority**: P0 | P1 | P2 | P3

**Reproducibility**: Always | Often | Sometimes | Rare

**Environment**:
- Device: [e.g., iPhone 15 Pro]
- iOS Version: [e.g., 17.5]
- App Version: [e.g., 1.0.0 (build 1)]
- Build Type: Debug | Release

**Steps to Reproduce**:
1. 
2. 
3. 

**Expected Behavior**:


**Actual Behavior**:


**Screenshots/Videos**:
[Attach if applicable]

**Logs**:
```
[Paste relevant console logs]
```

**Additional Context**:


**Related Test Cases**: TC-XXX

**Workaround** (if any):

```

### Severity Definitions

- **Critical**: App crashes, data loss, security issue
- **High**: Major feature broken, significant UX issue
- **Medium**: Minor feature issue, cosmetic problem
- **Low**: Typo, minor visual inconsistency

---

## Quick Test Commands

```bash
# Run app on physical device
flutter run -d 00008150-001514CC3C00401C

# Run app on simulator
flutter run -d iPhone-15-Pro

# Run with verbose logging
flutter run -v

# Build release version
flutter build ios --release

# Run analyzer
flutter analyze

# Run tests
flutter test

# Check device list
flutter devices

# Clear build cache
flutter clean && flutter pub get

# Generate test coverage
flutter test --coverage
```

---

## Test Execution Log

**Test Session**: _________  
**Date**: _________  
**Tester**: _________  
**Build Version**: _________  
**Device**: _________

| Test Case | Status | Duration | Notes |
|-----------|--------|----------|-------|
| TC-001 | ☐ | _____ | _____ |
| TC-002 | ☐ | _____ | _____ |
| TC-003 | ☐ | _____ | _____ |
| TC-004 | ☐ | _____ | _____ |
| TC-005 | ☐ | _____ | _____ |
| TC-006 | ☐ | _____ | _____ |
| TC-007 | ☐ | _____ | _____ |
| TC-008 | ☐ | _____ | _____ |
| TC-009 | ☐ | _____ | _____ |
| TC-010 | ☐ | _____ | _____ |

**Total Tests**: _____  
**Passed**: _____  
**Failed**: _____  
**Blocked**: _____  
**Pass Rate**: _____%

**Summary**:


**Blockers**:


**Next Steps**:

