# Product Overview

Helix is a companion app for Even Realities G1 smart glasses that
provides real-time conversation intelligence. Listens to conversations,
detects questions, generates AI answers, streams them to the glasses
HUD — hands-free.

See `CLAUDE.md` for the authoritative configuration table, provider
list, and hardware requirements.

## User Flows

1. **Live Conversation** — Listen → transcribe → detect question →
   AI answer → stream to glasses HUD → background fact-check.
   Scroll pages with L/R touchpad.
2. **Text Query** — Type in Ask field → AI answer → phone + optional
   glasses → follow-up chips.
3. **Interview Coach** — STAR framework, directly speakable output,
   no "you could say" phrasing.
4. **Passive Listener** — Silent monitor, only facts / corrections /
   key context, minimal interventions.

## Supported Hardware

- **Glasses:** Even Realities G1 (dual BLE L/R)
- **Phone:** iOS 15+, BLE 5.0
- **Mic:** phone mic (default), glasses mic, auto-detect
