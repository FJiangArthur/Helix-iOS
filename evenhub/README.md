# Helix Live for Even G2 (Even Hub app)

Helix Live on Even G2 glasses (and the R1 ring through G2): live captions,
AI cues (concepts, people, suggestions, answers to questions), a contextual
menu and Prep Notes. It is the web-app twin of the Android G1 Conversate and
shares its contract in [`../conversate-core/`](../conversate-core/): the same
menu, cue prompt, cue schema and behaviour vectors.

- Spec: `docs/superpowers/specs/2026-10-04-conversate-g1-g2-design.md` (§4, §7)
- Plan: `docs/superpowers/plans/2026-10-05-conversate-plan-d-evenhub.md`
- Decisions that deviate from or refine the plan: [`NOTES.md`](NOTES.md)

## Layout

| Path | What |
|---|---|
| `src/core/` | TypeScript port of the Conversate state machine, cue queue, cue parser, caption buffer, menu and prompt (Android `conversate/*.kt`) |
| `src/g2/` | ScreenModel → Even Hub containers (`render.ts`), native context menu (`contextMenu.ts`), event → intent (`input.ts`), page validation (`validate.ts`) |
| `src/audio/` | Glasses/phone mic PCM → OpenAI Realtime transcription (WebSocket), chunked REST fallback |
| `src/ai/` | Cue engine (gpt-4.1-mini, JSON) and question → ANSWER cues |
| `src/app.ts` | Controller: bridge, session, renderer, transcriber, engines, render coalescing |
| `src/phone/` | Phone page: API key, Start/Pause/End, settings, Prep Notes, lens preview |
| `test/` | Vitest: shared vectors, unit tests, fake-bridge app tests, DOM tests |
| `release/helix-conversate.ehpk` | Packaged app |

## Install and test

```bash
cd evenhub
npm ci
npm test          # vitest: shared conversate-core vectors + unit + app tests
npm run build     # tsc --noEmit && vite build -> dist/
```

## Use

1. Open the app on the phone (Even app → Even Hub) and paste your **OpenAI API key**
   in the phone page. It is stored only in the Even app's local storage on that
   phone; the app never ships with a key.
2. On the glasses: **long-press** for the Conversate menu (or use the native
   context menu) → *Start session* (pick a Prep Note if you have any).
3. Gestures (temple or R1 ring): **scroll down** = next / open cue detail,
   **scroll up** = previous / dismiss cue, **tap** = select, **double-tap** = back;
   double-tap at the live screen asks to confirm, double-tap again ends.

Without a key a session still starts and the lens shows a one-line prompt.

## Develop on a device (sideload)

```bash
npm run dev                                   # vite on 0.0.0.0:5173
npx evenhub qr --ip <your-lan-ip> --port 5173 # scan with the Even app (dev mode)
```

## Simulator

```bash
npm run dev
npx @evenrealities/evenhub-simulator http://localhost:5173
# scripted: add --automation-port 9898, then
#   curl -X POST localhost:9898/api/input -d '{"action":"long_press"}'
#   curl -o g.png localhost:9898/api/screenshot/glasses
```

The simulator injects the bridge and emits 16 kHz audio frames from your Mac's
microphone; device status events are not emitted.

## Package

```bash
npm run build
npm run pack      # evenhub pack app.json dist -o release/helix-conversate.ehpk --sdk-ver 0.0.16
grep -r "sk-" dist release   # must print nothing
```

`--sdk-ver 0.0.16` stamps `min_app_version` 2.2.10 (the SDK's floor).

## Private build upload

An `.ehpk` cannot be opened directly. Log in with `npx evenhub login`, upload
`release/helix-conversate.ehpk` as a private build on the Even Hub developer
site, then open it from the Even app on the phone paired with your G2.

## Permissions

`g2-microphone`, `phone-microphone`, and `network` restricted to
`https://api.openai.com` and `wss://api.openai.com` (`app.json`).
