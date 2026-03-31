# App Store Connect Metadata — Even Companion

Reference document with copy-paste content for App Store Connect submission fields.

---

## App Information

**App Name** (30 char max):
```
Even Companion
```

**Subtitle** (30 char max):
```
AI Assistant for Smart Glasses
```

**Primary Category**: Productivity
**Secondary Category**: Utilities

**Copyright**:
```
© 2026 Art Jiang
```

**Age Rating**: 4+ (no objectionable content, no user-generated content shared publicly)

---

## URLs

**Privacy Policy URL**:
```
https://fjiangarthur.github.io/Helix-iOS/privacy
```

**Support URL**:
```
https://fjiangarthur.github.io/Helix-iOS/support
```

**Marketing URL**:
```
https://fjiangarthur.github.io/Helix-iOS/
```

---

## Description (4000 chars max)

```
Even Companion is the AI-powered companion app for Even Realities G1 smart glasses. It transforms your glasses into an intelligent heads-up display with real-time conversation transcription, AI-assisted analysis, and a rich bitmap HUD — all while keeping your data private and under your control.

REAL-TIME CONVERSATION INTELLIGENCE
Transcribe conversations in real time using either Apple's Speech framework or an optional cloud transcription backend that you explicitly select in Settings. Even Companion listens, transcribes, and streams AI-generated insights directly to your G1 glasses display. Whether you're in a meeting, an interview, or a casual conversation, your AI assistant works quietly in the background.

THREE CONVERSATION MODES
- General: Summarize discussions, surface key points, and get instant follow-up suggestions.
- Interview: Get real-time STAR-method coaching — the AI helps you structure your answers around Situation, Task, Action, and Result as you speak.
- Passive: Silent monitoring that captures and transcribes without sending prompts, perfect for recording lectures or talks.

RICH BITMAP HUD
Your G1 glasses become a full heads-up display. See the time, live weather, stock tickers, upcoming calendar events, and phone notifications — all rendered as crisp bitmap graphics on your lens. Choose from layout presets including Classic, Minimal, Dense, and Conversation to match your workflow.

CHOOSE YOUR AI PROVIDER
Even Companion supports six AI providers so you can pick the model that fits your needs and budget:
- OpenAI (GPT-4o, GPT-4o mini, and more)
- Anthropic (Sonnet, Haiku)
- DeepSeek (DeepSeek Chat, DeepSeek Reasoner)
- Qwen (Qwen Turbo, Qwen Plus, Qwen Max)
- Zhipu AI (GLM-4-Flash — free, GLM-4.5-Flash — free, GLM-4.7-Flash — free)
- SiliconFlow (free models available)

FREE AI OPTIONS — No credit card required. Select Zhipu AI and use GLM-4-Flash, GLM-4.5-Flash, or GLM-4.7-Flash for zero-cost AI assistance. SiliconFlow also offers free-tier models.

PRIVACY FIRST
Speech recognition can run on-device through Apple's Speech framework, or through the cloud transcription provider you explicitly choose in Settings. API keys are stored locally in iOS Keychain. No analytics, no tracking, no accounts required.

SEAMLESS BLUETOOTH CONNECTION
Pair your G1 glasses once and Even Companion handles the rest. The app maintains a reliable BLE connection in the background so your HUD stays live and conversation insights keep flowing.

Even Companion is free to download and use. AI features require an API key from your chosen provider, or use one of the free model options listed above.
```

---

## Keywords (100 chars max, comma-separated, no spaces after commas)

```
smart glasses,AI assistant,conversation,transcription,HUD,Even Realities,G1,speech,bluetooth,real-time
```

Character count: 100

---

## What's New — Version 2.2.6

```
MORE RELIABLE CONVERSATION RESTARTS
Starting a new conversation now clears the previous live transcript and response immediately, and transcription continues correctly after restarting from the Home screen.

FASTER MAIN-SCREEN RESET
Finished-session content no longer lingers on the main screen when you begin a fresh recording session.

STABILITY IMPROVEMENTS
Improved live-session reset behavior across transcription, answer streaming, and follow-up chips so each conversation starts cleanly.

APP STORE SUBMISSION POLISH
Updated launch assets and review metadata to better match the current app experience and privacy behavior.
```

---

## App Review Notes

```
This app is a companion for Even Realities G1 smart glasses. Full functionality requires paired glasses via Bluetooth. Without glasses, you can still test: (1) Home tab — tap the microphone to record and transcribe speech, then receive AI responses; (2) Settings — configure AI providers and enter API keys; (3) Glasses tab — preview HUD widgets and layout behavior. No login required. Free AI access: set Zhipu AI as provider and select glm-4-flash model (free, no API key charges).
```

---

## Privacy Nutrition Label Guidance

Select the following in App Store Connect under **App Privacy**:

### Data Collected

| Data Type | Category | Purpose | Linked to Identity | Tracking |
|---|---|---|---|---|
| Audio Data | User Content | App Functionality | No | No |
| Precise Location | Location | App Functionality | No | No |

### Data NOT Collected

Check "No" or leave unselected for all of the following:
- Contact Info (name, email, phone)
- Health & Fitness
- Financial Info
- Contacts
- User Content (photos, videos, gameplay)
- Browsing History
- Search History
- Identifiers (user ID, device ID)
- Purchases
- Usage Data (product interaction, advertising data)
- Diagnostics (crash data, performance data)
- Sensitive Info

### Key Declarations

- **Third-party API calls**: The app sends user-composed text to third-party AI APIs (OpenAI, Anthropic, DeepSeek, Qwen, Zhipu, SiliconFlow) based on the user's explicit provider selection. These are functional requests, not tracking.
- **Speech recognition**: By default this can run through Apple Speech on-device. If the user explicitly selects a cloud transcription backend, audio is sent only to that chosen provider for transcription.
- **Location**: Precise location is used only to show local weather conditions on the HUD. It is not linked to identity and not used for tracking.
- **API keys**: Stored locally in iOS Keychain (Secure Enclave). Never transmitted except to the user's chosen AI provider endpoint.
- **No tracking**: The app does not use any analytics SDKs, advertising identifiers, or cross-app tracking.
- **No account required**: The app does not require login or collect identity information.

In App Store Connect, you can likely select:
1. **"Yes, we collect data"** (because audio is processed locally and text is sent to AI APIs)
2. Under **User Content**: declare the app's audio usage for "App Functionality", not linked to identity, not used for tracking
3. Under **Location**: declare precise location for "App Functionality", not linked to identity, not used for tracking
4. Mark everything else as not collected

---

## Screenshot Requirements

### Required Device Sizes

| Display Size | Resolution (portrait) | Required |
|---|---|---|
| 6.9" (iPhone 16 Pro Max) | 1320 x 2868 | Yes — covers 6.7" and 6.9" |
| 6.3" (iPhone 16 Pro) | 1206 x 2622 | Yes — covers 6.1" and 6.3" |
| 5.5" (iPhone 8 Plus) | 1242 x 2208 | Only if supporting iPhone 8 Plus |
| 12.9" iPad Pro (6th gen) | 2048 x 2732 | Only if supporting iPad |

### Screenshot Count
- Minimum: 1 per device size
- Maximum: 10 per device size
- Recommended: 5-6 per device size

### Suggested Screenshot Sequence

1. **Hero shot** — G1 glasses connected, HUD preview visible on the home screen
2. **Conversation mode** — Live transcription with AI response streaming
3. **HUD widgets** — Bitmap display showing clock, weather, stocks, calendar
4. **AI provider selection** — Settings screen showing multiple provider options
5. **Interview mode** — STAR coaching in action with structured feedback
6. **Layout presets** — Side-by-side of Classic, Minimal, Dense, Conversation layouts

### Screenshot Tips
- Use clean status bars (full battery, full signal, Wi-Fi, appropriate time like 9:41)
- Dark theme screenshots match the app's glassmorphism design
- Add marketing text above or below the device frame if using framed screenshots
- File format: PNG or JPEG, no alpha channel, sRGB color space
