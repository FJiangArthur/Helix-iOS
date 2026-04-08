# App Store Connect Metadata — Even Companion

Copy-paste content for App Store Connect submission fields.

## App Information

- **Name:** `Even Companion` (30 char max)
- **Subtitle:** `AI Assistant for Smart Glasses` (30 char max)
- **Primary Category:** Productivity
- **Secondary Category:** Utilities
- **Copyright:** `© 2026 Art Jiang`
- **Age Rating:** 4+

## URLs

- Privacy: `https://fjiangarthur.github.io/Helix-iOS/privacy`
- Support: `https://fjiangarthur.github.io/Helix-iOS/support`
- Marketing: `https://fjiangarthur.github.io/Helix-iOS/`

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

## Keywords (100 chars max)

```
smart glasses,AI assistant,conversation,transcription,HUD,Even Realities,G1,speech,bluetooth,real-time
```

## What's New — v2.2.6

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

## Review Notes

```
This app is a companion for Even Realities G1 smart glasses. Full functionality requires paired glasses via Bluetooth. Without glasses, you can still test: (1) Home tab — tap the microphone to record and transcribe speech, then receive AI responses; (2) Settings — configure AI providers and enter API keys; (3) Glasses tab — preview HUD widgets and layout behavior. No login required. Free AI access: set Zhipu AI as provider and select glm-4-flash model (free, no API key charges).
```

## Privacy Label

**Collected (App Functionality, not linked to identity, not tracking):**
- Audio Data (User Content)
- Precise Location (only for HUD weather widget)

**Not collected:** contact info, health, financial, contacts, user
content, browsing/search history, identifiers, purchases, usage data,
diagnostics, sensitive info.

**Notes:**
- Third-party API calls to the user's chosen AI provider (OpenAI /
  Anthropic / DeepSeek / Qwen / Zhipu / SiliconFlow). Functional, not
  tracking.
- Speech recognition defaults to Apple on-device; cloud transcription
  only when user explicitly selects it in Settings.
- API keys stored locally in iOS Keychain (Secure Enclave). Never
  transmitted except to the user's chosen AI provider endpoint.
- No analytics SDKs, no ad IDs, no cross-app tracking, no account
  required.

## Screenshots

Required sizes (portrait): 6.9" (1320x2868) and 6.3" (1206x2622) for
iPhone. 5-6 per size recommended (1-10 allowed).

Suggested sequence: hero shot with glasses connected → live
transcription + streaming AI answer → HUD widgets (clock/weather/
stocks/calendar) → AI provider settings → Interview STAR coaching →
layout presets side-by-side.

Tips: clean status bar (full battery, Wi-Fi, 9:41), dark theme, PNG
or JPEG without alpha, sRGB.
