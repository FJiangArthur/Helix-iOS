# Conversate Plan D — G2 Even Hub App Implementation Plan

> **For agentic workers:** implement task-by-task with TDD (Vitest). Steps use checkbox (`- [ ]`) syntax.

**Goal:** A G2 Even Hub app (`.ehpk`) that runs Helix Conversate on Even G2 glasses (+ R1 ring via G2 sys-events): live captions, AI cues, contextual menu, Prep Notes — sharing `conversate-core/` with the Android G1 app.

**Architecture:** TypeScript + Vite single-page web app in `evenhub/`. A pure TS port of the Conversate state machine (`src/core/`) consumes the same JSON contract (`conversate-core/menu.json`, `prompts/cues.v1.json`) and must pass the same vectors (`conversate-core/vectors/*.json`) in Vitest. A G2 renderer maps `ScreenModel` to Even Hub containers; an input adapter maps Even Hub events to intents; an audio pipeline streams the glasses mic to OpenAI realtime transcription; a cue engine calls OpenAI chat completions. The phone-side page (the Hub WebView UI) holds settings, API key and Prep Notes.

**Tech Stack:** TypeScript 5, Vite 6, Vitest, `@evenrealities/even_hub_sdk@0.0.16` (MIT), `@evenrealities/evenhub-cli` (pack), `@evenrealities/evenhub-simulator` (manual preview).

**Spec:** `docs/superpowers/specs/2026-10-04-conversate-g1-g2-design.md` (§4 core contract, §7 G2 app). Android reference implementation: `android/app/src/main/java/com/artjiang/helix/conversate/*.kt` (ConversateSession.kt, Cue.kt, CueParser.kt, CueEngine.kt, CaptionBuffer.kt, ConversateIntent.kt) — port semantics exactly; vectors are the arbiter.

## Global Constraints

- Everything lives in `evenhub/` (plus read-only use of `conversate-core/`). No changes to `android/`, `ios/`, `NativeHelix/`.
- Manifest `evenhub/app.json`: `package_id` `com.artjiang.helixconversate`, `edition` `"202601"`, `name` `"Helix Conversate"` (≤20 chars), `version` `"0.1.0"`, `min_sdk_version` `"0.0.14"`, `entrypoint` `"index.html"`, `supported_languages` `["en"]`, permissions: `g2-microphone`, `phone-microphone`, `network` with whitelist `["https://api.openai.com", "wss://api.openai.com"]` (check `evenhub pack` accepts the wss entry; if not, keep https only and note it).
- **Never bundle API keys.** The user types their OpenAI key on the phone page; store via `bridge.setLocalStorage` (fallback `window.localStorage` outside the Even app).
- G2 canvas 576×288; ≤8 text/list + ≤4 image containers per page; exactly one container `isEventCapture: 1`; text container ≤1000 chars at create/rebuild, ≤2000 via `textContainerUpgrade`; list ≤20 items × 64 chars; menu ≤10 items, `itemName` ≤32 bytes, `itemID` non-zero uint32, `menuObject` must be re-sent on every rebuild. Validate every page with the SDK's `validateEvenHubPageContainer` in tests.
- Streaming caption updates use `textContainerUpgrade` (no flicker); only structural changes call `rebuildPageContainer`.
- Cue limits identical to Android: title ≤24, body ≤220, detail ≤1000; ≤1 LLM cue / 8 s (ANSWER exempt); queue 3 (ANSWER never evicted); stale 90 s; default dwell 6 s; confirm-end window 3 s with 400 ms echo guard; intent dedupe 250 ms across sources.
- Read the SDK types at `node_modules/@evenrealities/even_hub_sdk/dist/index.d.ts` and its README before writing the bridge layer; use real names (`waitForEvenAppBridge`, `createStartUpPageContainer`, `rebuildPageContainer`, `textContainerUpgrade`, `audioControl`, `onEvenHubEvent`, `OsEventTypeList`, `EventSourceType`, `AudioSpeakerRole`, `MenuItemClickEvent`, `shutDownPageContainer`).
- Commands: `cd evenhub && npm ci && npm test && npm run build && npx evenhub pack app.json dist -o helix-conversate.ehpk --sdk-ver 0.0.16`.

## Review Focus

1. Vector parity — every `conversate-core/vectors/session-*.json` and `cue-parse.json` passes unchanged in Vitest.
2. Page validity — every ScreenModel renders to a page the SDK validator accepts (one event-capture container, sizes within limits, menu labels ≤32 bytes).
3. Key handling — no key in the bundle, `dist/`, or `.ehpk`; missing key shows a phone-page prompt and a lens line, never a crash.
4. Event mapping — CLICK/DOUBLE_CLICK/SCROLL_TOP/SCROLL_BOTTOM/LONG_PRESS from glasses AND ring (`EventSourceType` ring) map to the same intents; menuItemClickEvent ids map to `menu.json` ids.
5. Background/foreground — on FOREGROUND_EXIT stop audio; on FOREGROUND_ENTER re-arm audio and rebuild the page.

---

### Task 1: Scaffold
- [ ] `evenhub/package.json` (scripts: `dev` vite, `build` `tsc --noEmit && vite build`, `test` `vitest run`, `pack` the evenhub pack command), `tsconfig.json` (strict), `vite.config.ts` (`base: './'`, `publicDir` none, `resolve.alias` `@core-contract` → `../conversate-core`), `index.html`, `app.json` per constraints, `.gitignore` (`node_modules`, `dist`, `*.ehpk` except the delivered one is copied to `evenhub/release/`).
- [ ] Install exact deps; commit `package-lock.json`.
- [ ] A trivial Vitest test passes; `npm run build` produces `dist/index.html`. Commit.

### Task 2: Core port (`src/core/`) — TDD against shared vectors
- [ ] `intents.ts` (ConversateIntent, IntentSource, IntentDeduper), `cue.ts` (CueType with Android priorities/labels, Cue, CueQueue), `menu.ts` (load `menu.json` via JSON import, `renderLabel`), `session.ts` (ConversateSession: same API + semantics as Android `ConversateSession.kt`, including HEAD_* ignored, confirm guard, promote-after-intent), `screen.ts` (ScreenModel union), `cueParser.ts`, `captionBuffer.ts` (word wrap width injected).
- [ ] `test/vectors.test.ts` loads every `conversate-core/vectors/session-*.json` and `cue-parse.json` (same runner semantics as Android `SessionVectorTest.kt` / `CueParserTest.kt`) — write first, watch fail, implement, pass.
- [ ] Unit tests mirroring Android `ConversateSessionTest.kt` and `CueQueueTest.kt` cases. Commit.

### Task 3: G2 renderer (`src/g2/render.ts`)
- [ ] Pure function `renderPage(model: ScreenModel, opts): { kind: 'rebuild'|'upgrade', page: CreateStartUpPageContainer|RebuildPageContainer, upgrades?: TextContainerUpgrade[] }`.
- [ ] Layout: Live = cue text container (top, ~4 lines, border when a cue is shown, `TYPE  title` + body) + caption text container (bottom, ~5 lines, event capture); CueDetail/PrepNote = one full-screen text container (scrolls natively, event capture); Menu = list container (≤20 items, `>` not needed — native list selection) or text with `>` cursor if list selection events don't fit the session's cursor model (decide from SDK `List_ItemEvent` semantics; ledger the choice); ConfirmEnd = centered text; Blank = empty text container.
- [ ] Contextual menu: `menuObject` built from `menu.json` live items (ids 1..n stable), labels ≤32 bytes; re-sent on every rebuild.
- [ ] Tests: every ScreenModel kind → `validateEvenHubPageContainer` ok; caption-only change → `upgrade` (not rebuild). Commit.

### Task 4: Input adapter (`src/g2/input.ts`)
- [ ] Map `EvenHubEvent` → intent: CLICK→SELECT, DOUBLE_CLICK→BACK, SCROLL_BOTTOM→NEXT, SCROLL_TOP→PREV, LONG_PRESS→MENU (LONG_PRESS_RELEASE ignored); source ring vs glasses → IntentSource R1 / G2_TOUCHPAD (add G2_TOUCHPAD to the TS enum); `menuItemClickEvent` → activate that menu id directly (session method `activateMenuItem(id)` — add with a unit test); FOREGROUND_ENTER/EXIT → lifecycle callbacks.
- [ ] Tests with fabricated events via `evenHubEventFromJson`. Commit.

### Task 5: Audio + transcription (`src/audio/`)
- [ ] `audioControl(true, AudioInputSource.Glasses)`; audio frames arrive as `audioEvent` (PCM 16 kHz s16le mono; `AudioSpeakerRole` self/other) — read the SDK type for the payload field.
- [ ] `RealtimeTranscriber`: WebSocket `wss://api.openai.com/v1/realtime?intent=transcription` with browser subprotocol auth (`['realtime', 'openai-insecure-api-key.' + key, 'openai-beta.realtime-v1']`), session update for `gpt-4o-mini-transcribe` + server VAD, append base64 PCM (resample 16 kHz→24 kHz linear), emit partial (`...delta`) and final (`...completed`) segments with speaker role. Verify event names against current OpenAI realtime docs.
- [ ] Fallback `ChunkedTranscriber` (REST `/v1/audio/transcriptions`, 3 s WAV chunks) used if the socket fails twice.
- [ ] Tests: resampler, WAV encoder, segment assembly from recorded event JSON fixtures (no network). Commit.

### Task 6: Cue engine + app wiring (`src/app.ts`, `src/ai/`)
- [ ] `openaiClassify(prompt, maxTokens)` via fetch chat completions (`gpt-4.1-mini`, temperature 0); `CueEngine` port (debounce 1.5 s, gap 8 s, window 60 s, in-flight not cancelled); answers: a lightweight question detector (`?`-terminated or wh-word final + LLM answer in ≤3 sentences) producing ANSWER cues.
- [ ] `App` controller: bridge init (`waitForEvenAppBridge`), create start-up page, subscribe events, session ↔ renderer ↔ transcriber ↔ engine, 250 ms ticker, render coalescing (latest state wins; upgrades ≥300 ms apart for captions).
- [ ] Tests with a fake bridge (records calls). Commit.

### Task 7: Phone page (`src/phone/`)
- [ ] Minimal accessible HTML UI: API key field (masked, saved via setLocalStorage), Start/End/Pause, captions/cues/auto-popup toggles, cue duration, Prep Notes (list/add/edit/delete, ≤5000 chars), live preview of the lens text.
- [ ] Works in a normal browser (fallback storage, no bridge) for the simulator. Commit.

### Task 8: Package + docs
- [ ] `npm test`, `npm run build`, `npx evenhub pack app.json dist -o release/helix-conversate.ehpk --sdk-ver 0.0.16` succeeds; commit `release/helix-conversate.ehpk`.
- [ ] Verify no secret: `grep -r "sk-" dist release` finds nothing.
- [ ] `evenhub/README.md`: install, `npm run dev` + `npx evenhub qr --ip <lan-ip> --port 5173` sideload, simulator `npx evenhub-simulator http://localhost:5173`, pack, private build upload.
- [ ] Optional manual check in `evenhub-simulator` (report result honestly if it cannot run headless). Commit.
