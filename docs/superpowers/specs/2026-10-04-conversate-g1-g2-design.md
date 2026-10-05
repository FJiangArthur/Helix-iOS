# Helix Conversate — G1 (Android) + G2 (Even Hub) + R1 — Design

**Date:** 2026-10-04 · **Status:** Approved 2026-10-05 (D1, D2 accepted) · **Owner:** Art Jiang

## 1. Intent

Bring the Even G2 "Conversate" experience — live captions, auto-popping AI cues, an on-glasses
contextual menu, hands-free control — to the user's **G1** glasses through the Helix Android app,
make **R1 ring** input work with G1, and ship the same experience as a **G2 Even Hub app**.
Extend it with real-time **stocks, news and notes**.

**Success =** wearing G1 + R1 during a conversation feels like Conversate on G2: captions appear
within ~1 s of speech, relevant cues pop and fade without touching the phone, and the user can
open a menu, glance at stocks/news/notes, dictate a quick note and end the session from the ring
or touchpad alone. The G2 app behaves identically (same cues, menu, gestures) on its larger canvas.

**Said by user:** G1 parity with G2 Conversate (contextual menu + conversation); Android G1 app
and G2 Even Hub app; shared logic as "one spec, two implementations"; has G1, G2 and R1; R1 must
work with G1; news + stocks as contextual cues, menu glance panels and head-up dashboard; notes
as voice quick-note, auto meeting notes, read on HUD, Prep Notes.
**Assumed (correct me):** G1 first, then G2; user supplies API keys (OpenAI etc. as today, plus a
Finnhub key for markets/news); US equities watchlist; English UI; G2 uses the phone or glasses mic
via Hub `audioControl`.

## 2. Scope and sub-projects

| # | Sub-project | In this spec | Ships |
|---|---|---|---|
| S | Hardware spikes (R1 link, G1 long-press/head-up, caption throughput) | design of the probes | first |
| 1 | **Conversate Core** — shared contract (intents, state machine, cue schema, prompts, menu, vectors) | full | with 2 |
| 2 | **G1 Android live experience** — HUD composer, menu, G1+R1 input, cue engine, Prep Notes | full | 1st |
| 3 | **Feeds & Notes** — stocks, news, quick note, notes on HUD, head-up dashboard, auto meeting notes | full | 2nd |
| 4 | **G2 Even Hub app** (TypeScript) on the same core | architecture only; own plan | 3rd |
| 5 | Post-session Summary / Cue List / export | out (next spec) | later |
| 6 | Live translation | out (next spec) | later |

## 3. Constraints that shape the design

- **G1 display:** text path only on Android (`0x4E`/`0x71`); **5 lines × ~46 chars** per screen
  (`HudPaginator`). No append primitive — every update re-sends a whole screen; each packet is
  ACK-gated, left lens before right (`docs/G1_PROTOCOL_SLA.md` L1/L2). No layering, no bitmap.
- **G1 input:** firmware events only — `1` tap (L/R side), `0` double-tap, `23` left long-press,
  `24` long-press release, `2/3` head up/down. Multi-taps are counted on the phone.
- **R1:** vendor GATT service `bae80001-4f05-4503-8e65-3af1f7329d1f`, gesture notifies on
  `bae80011`/`bae80013`; frames `FF 04 01` tap, `FF 04 02` double, `FF 03 20` hold,
  `FF 05 xx` swipe, and 11-byte `00 09 61 00 <code> …` (00 long-press, 01 tap, 02 double,
  04 up, 05 down, 08 release). Community-reverse-engineered (faceclaw, hermes-g2, g2-kit);
  bonded/encrypted; the Even app must release it. Officially G2-only → unproven on G1, may change
  with ring firmware.
- **G2 / Even Hub:** web app in Even's phone app WebView; 576×288 canvas, ≤8 text/list + ≤4
  image containers, one fixed font (~10 lines), `textContainerUpgrade` for flicker-free streaming,
  native contextual menu (≤10 items, tap+long-press), events CLICK / DOUBLE_CLICK / SCROLL_* /
  LONG_PRESS (ring sends the same). No user code on the glasses.
- **Repo rules:** product logic stays native (Kotlin in `android/`, Swift in `NativeHelix/`).
  The Even Hub app is a **web app by platform necessity**, not legacy cross-platform UI; it lives
  isolated in `evenhub/` and does not touch the native gate. **This is a deliberate exception to
  CLAUDE.md's "no cross-platform tooling" rule and needs the user's sign-off (§11 D1).**
- `HelixBridge.kt` is already 2,213 LOC — new behaviour goes in a new `conversate` package with a
  thin seam, not into the bridge.

## 4. Conversate Core (shared contract)

A language-neutral contract in `conversate-core/` at the repo root. Both apps implement it; both
test suites run the **same JSON vectors**.

```
conversate-core/
  intents.md            # intent model + per-device mapping tables (this §4.1)
  state-machine.md      # screens, transitions (this §4.2)
  menu.json             # menu tree, item ids, labels (≤32 bytes), visibility rules
  cue-schema.json       # JSON Schema for LLM cue output
  prompts/
    cues.v1.json        # system + user templates for cue extraction
    quicknote.v1.json   # note cleanup/titling
    meeting-notes.v1.json
  vectors/
    input-*.json        # device events -> intents
    session-*.json      # intent/event script -> expected screen models
    cue-parse-*.json    # raw LLM output -> parsed cues / rejections
    r1-frames.json      # raw ring bytes -> gesture (Android only)
```

Rendering is **not** shared: core emits a device-neutral **ScreenModel**; each app has its own
composer (G1 5-line text, G2 containers).

### 4.1 Intent model

Devices emit raw gestures; a per-device **InputMapper** turns them into five intents the state
machine understands: `NEXT`, `PREV`, `SELECT`, `BACK`, `MENU` (+ `HEAD_UP`, `HEAD_DOWN`).

| Intent | R1 ring | G1 touchpad | G2 touchpad/ring (Hub) |
|---|---|---|---|
| NEXT | swipe down / forward | right tap (`1`,R) | SCROLL_BOTTOM |
| PREV | swipe up / back | left tap (`1`,L) | SCROLL_TOP |
| SELECT | tap | long-press (`23`) **while a list is open** | CLICK |
| BACK | double-tap | double-tap (`0`) | DOUBLE_CLICK |
| MENU | hold | long-press (`23`) when no list is open | native menu (tap+long-press) |
| HEAD_UP | — | `2` | — (Hub has no head-up; see §6.5) |

Notes: G1 has no separate select gesture, so long-press is context-sensitive (opens the menu,
selects inside lists).

**Routing (must not collide with legacy behaviour).** Today `G1TouchpadRouter`/`TouchpadDecider`
map `23` → manual question, `24` → `StopListening`, `0` → `ClearHud` (0x18), `1` → page/toggle.
While Conversate is active, `HelixBridge.handleInbound` hands **every** touchpad event to
`ConversateController` *before* `TouchpadDecider`, and the legacy decider never sees it:
- `23` + `24` are one physical gesture: `23` emits the intent, the matching `24` is swallowed.
- `0` becomes BACK; it never triggers the legacy `ClearHud` (Conversate owns clearing, §5.3).
- `G1TapCounter` multi-tap is disabled; when Conversate is off everything behaves as today.

**Intent bus.** All sources (G1 touchpad, R1, phone UI) post to one serialized intent channel.
The same intent from different sources within **250 ms** is deduplicated (one physical gesture
can arrive on both R1 characteristics, or ring + touchpad together). Destructive intents
(BACK at Live root → end) always require the §4.2 confirm step, so a duplicate can never end a
session.

### 4.2 State machine

Screens (each produces a ScreenModel):

- `Idle` — nothing on the lens (or the dashboard on head-up).
- `Live` — session running: **cue slot** + **caption slot**.
  - sub-state `CueShown(cue, expiresAt)` / `CueCollapsed(pendingCount)` / `CaptionsOnly`.
- `CueDetail(cue, page)` — full-screen paged cue.
- `Menu(path, cursor)` — list from `menu.json`.
- `Panel(kind, cursor, page)` — Stocks / News / Notes / Prep Note list or detail.
- `QuickNote(phase)` — `Listening` → `Confirm(text)` → `Saved`.
- `ConfirmEnd` — "Double-tap again to end".
- `Dashboard` — head-up glance (G1).

Key transitions (full table in `state-machine.md`, vectors in `vectors/session-*.json`):

| From | Intent/Event | To |
|---|---|---|
| Live | cue arrives, auto-popup on | Live/CueShown (dwell = cue duration, default 6 s) |
| Live | cue arrives, auto-popup off | Live/CueCollapsed (`◆ 2 cues` indicator line) |
| Live/CueShown | NEXT | CueDetail(page 1) |
| Live/CueCollapsed | SELECT or NEXT | Live/CueShown(oldest pending) |
| CueShown | dwell expires | Live/CaptionsOnly |
| CueDetail | NEXT/PREV | page ±1; BACK → Live |
| any non-Menu | MENU | Menu(root) |
| Menu | NEXT/PREV/SELECT/BACK | move cursor / open item / up a level, root BACK → previous screen |
| Live (root) | BACK | ConfirmEnd (3 s) → BACK again ends session, timeout returns |
| Idle/Live | HEAD_UP | Dashboard; HEAD_DOWN or 5 s → previous |
| any | new cue while not Live | queued; never interrupts Menu/Panel/QuickNote |

**Quick note controls** (phase-specific, every phase has a timeout):

| Phase | SELECT | NEXT/PREV | BACK | Timeout |
|---|---|---|---|---|
| Listening | finish | ignored | cancel → previous | 2.5 s silence finishes; 60 s hard cap |
| Confirm(text) | save | page the text | discard | 10 s → **save** (hands-free default) |
| Saved | — | — | — | 1.5 s → previous |

On G1 without R1, SELECT inside QuickNote is long-press (QuickNote counts as a "list open"
context, so long-press never opens the menu there).

**Cue queue rules.** Max 3 pending. Dequeue = highest priority first (ANSWER > QUOTE >
HEADLINE > BIO/CONCEPT > SUGGESTION), FIFO within a priority. Overflow evicts the oldest
lowest-priority cue; an ANSWER is never evicted and may push the queue to 4. Cues older than
90 s are dropped as stale. `CueCollapsed` + SELECT opens the next cue by this same order.

Answers to detected questions keep today's priority: an `ANSWER` cue may pre-empt `CaptionsOnly`
and other cue types but never a menu, panel or quick note the user opened.

### 4.3 Menu (`menu.json`)

Root (G1 shows 4 items + header per screen, `>` cursor; scrolls):
`Pause/Resume` · `Captions on/off` · `Cues on/off` · `Prep Note` · `Stocks` · `News` · `Notes` ·
`Quick note` · `Display off` · `End session`.
Outside a session the root is `Start Conversate` · `Stocks` · `News` · `Notes` · `Quick note`.
`Start Conversate` opens the Prep Note picker with `Skip & start` first (mirrors G2).
On G2 the same ids map onto the native contextual menu (≤10 items; the system adds Display off /
Brightness / Close itself, so those ids are hidden there).

### 4.4 Cues

Types: `ANSWER`, `CONCEPT`, `BIO`, `SUGGESTION` (Conversate) + `QUOTE` (stock), `HEADLINE`
(news), `NOTE_SAVED` (system). Schema per cue: `{type, title ≤24 chars, body ≤220 chars,
detail? ≤1000, entity?, ticker?, sourceSegmentIds[]}`.

## 5. G1 Android live experience

### 5.1 Components (new package `com.artjiang.helix.conversate`)

| Unit | Responsibility | Depends on |
|---|---|---|
| `ConversateSession` | pure-Kotlin state machine (§4.2); input = intents + events, output = `StateFlow<ScreenModel>` | nothing Android |
| `G1HudComposer` | ScreenModel → list of 5-line text pages | `HudPaginator` |
| `ConversateHudDriver` | own **persistent** display lifecycle on the shared `G1CommandTransport` (does *not* use `G1HudSession`, whose dwell/auto-advance would blank an open menu); clears with 0x18 only on an explicit state transition; holds the HUD via an owner token (§5.3) | g1 package |
| `InputMapper` (`G1InputMapper`, `R1InputMapper`) | raw events → intents | — |
| `R1Transport` (`ring/`) | scan `EVEN R1_*`, connect to bonded ring, subscribe `bae80011/13`, decode frames, reconnect | Android BLE |
| `CueEngine` | transcript window → cues (LLM JSON), rate-limit, dedupe; reuses the existing question path for `ANSWER` | `ai/` providers |
| `PrepNoteRepository` | Prep Notes (text ≤5,000 chars, TXT/PDF import via knowledge importer) | `data/` JsonFileStore |
| `ConversateController` | wires the above, the only thing `HelixBridge` talks to | all |

`HelixBridge` changes: intercept touchpad events before `TouchpadDecider` while Conversate is
active (§4.1), give `ConversateController` a partials+finals transcript subscription (§5.3), route
the existing answer pipeline's output in as `ANSWER` cues, and adopt `HudArbiter` owner tokens
for its own producers (§5.3). When Conversate is disabled the app behaves exactly as today.

### 5.2 G1 screen layouts (5 lines × ~46 chars)

```
Live / CueShown                 Live / CaptionsOnly          Menu
◆ ANSWER  Fed rate              …and the Fed said rates      CONVERSATE        3/10
Rates held at 4.25-4.50%;       would stay where they are    > Cues: on
next decision Dec 10.           until they see inflation       Prep Note
──────────────────────          come down, which I think       Stocks
…see inflation come down,       is the right call for now      News
which I think is the right
```

- Cue card: line 1 type + title, lines 2–3 body (truncated, `→` marker when detail exists),
  line 4 thin rule, line 5 most recent caption text. Captions-only: last 5 wrapped lines.
- Captions off: cue cards only; lens blanks (`0x18`) when no cue is shown.
- Cue collapsed: line 1 becomes `◆ 2 new cues` above 4 caption lines.

### 5.3 Throughput, captions and HUD ownership

A 5-line screen is ~1–2 packets per lens (191-byte payload chunks), each ACK-gated, left then
right, plus the transport's 400 ms inter-side settle. The driver therefore renders **state, not
events**:
- **Single-slot render queue:** at most one screen in flight and one pending; a newer
  ScreenModel replaces the pending one. Every intent is applied to the state machine; only the
  latest resulting screen is drawn (rapid cursor moves collapse to the final position).
- Never sends a screen identical to the last one sent.
- User-initiated screens (menu/panel/cue/quick note) jump ahead of a pending caption screen.
- Caption cadence starts at **≥700 ms** and is set from spike S3's measured speech-to-lens latency.

**Captions use partials.** `HelixBridge.handleSegment` drops non-final segments today; Conversate
receives partials *and* finals from the transcript stream (a separate subscription, the existing
finals-only path is untouched). Caption slot shows committed finals + the current partial.
Cues still run on finals only. The "~1 s captions" target is validated in S3, not assumed.

**HUD ownership.** `HudArbiter` gains owner tokens: `requestDisplay` returns a token (generation
counter) and `releaseDisplay(token)` / clears are ignored unless the token is current, so a
superseded producer can no longer release or blank a newer screen. New priority
`CONVERSATE_INTERACTIVE` (menu/panel/quick note/cue detail) ranks above ANSWER; Live captions and
cue cards hold at `CONVERSATE_LIVE` (= ANSWER rank, so the existing answer pipeline's output is
routed in as ANSWER cues rather than competing for the lens). Phone notifications are queued, not
drawn, while `CONVERSATE_INTERACTIVE` holds the HUD.

### 5.4 Cue engine

- Trigger: on each final transcript segment, debounce 1.5 s, run one LLM call over the last
  ~60 s of transcript + Prep Note + already-shown cue titles, returning JSON per
  `cue-schema.json` (fast tier model, `response_format: json`).
- Gating: ≤1 cue / 8 s (ANSWER exempt), dedupe by `entity`/normalized title per session, max
  3 queued; queue order ANSWER > QUOTE > HEADLINE > BIO/CONCEPT > SUGGESTION.
- `QUOTE`/`HEADLINE`: the LLM only extracts `ticker`/`entity`; prices and headlines come from the
  market/news provider (§6), never from the model.
- Malformed JSON → dropped and counted; never shown.
- Existing `QuestionDetector`/answer pipeline continues to produce `ANSWER` cues unchanged.

### 5.5 Phone UI (Compose, Assistant tab)

- "Conversate" toggle + Prep Note picker + Start/Pause/End.
- Live view: captions + cue list (tap to resend a cue to the glasses).
- Settings: captions on/off, cues on/off, per-cue-type toggles, auto-popup, cue duration (3–15 s),
  ring pairing status + "Connect R1".

### 5.6 R1 on G1

- Connect only to an **already bonded** ring (user sets it up once in the Even app, then
  force-stops it — same pattern as the documented `com.even.g1` conflict).
- Subscribe both notify characteristics; no writes in v1 (gestures need no handshake).
- Unknown frames are logged and ignored, never guessed.
- On disconnect: exponential reconnect (1 → 30 s); touchpad keeps working; phone shows status.

## 6. Feeds & Notes

### 6.1 Market data provider

`MarketDataProvider` interface; v1 implementation **Finnhub** (REST `quote`, WebSocket trades for
watchlist while a Stocks panel or dashboard is visible; company news). User-entered API key;
features hidden without a key. Watchlist (≤10 tickers) edited on the phone. Quotes cached 15 s.

### 6.2 News provider

`NewsProvider` interface; v1: Finnhub market/company news when a key exists, plus **RSS** feeds
the user adds (no key needed). Headlines refreshed every 5 min while the app is in a session or a
News panel is open; one-line LLM summary generated on demand when a headline is selected.

### 6.3 Glance panels (menu → Stocks / News / Notes)

```
STOCKS            14:32     NEWS                 2/12   NOTES                 1/7
> NVDA  132.40  +1.2%       > Fed holds rates as…       > Call dentist Fri
  AAPL  228.10  -0.4%         Nvidia unveils new…         Q3 deck: add churn
  TSLA  251.77  +3.1%         Oil slips after OPEC…     ☐ Buy filters
  SPY   571.20  +0.2%         Apple supplier warns…     ☑ Book flights
```
NEXT/PREV move, SELECT opens detail (quote detail; headline summary; full note, or toggles a
to-do), BACK returns. Stocks panel updates in place at most every 2 s.

### 6.4 Notes

- **Voice quick-note:** menu `Quick note` → `Listening… (tap to finish)`; reuses the active
  transcription source (starts it if idle); finishes on SELECT or 2.5 s silence; LLM cleans and
  titles (`quicknote.v1`); `Confirm` screen (SELECT save, BACK discard); saved to existing notes
  store; `NOTE_SAVED` toast. During a Live session, the quick-note utterance is excluded from cues.
- **Auto meeting notes:** extend `AutomaticNoteExtractor` with action items / decisions from the
  session (`meeting-notes.v1`), stored per session (consumed by the Summary spec later).
- **Read on HUD:** Notes panel above; to-dos toggle with SELECT.
- **Prep Notes:** §5.1; selectable on the phone or from `Start Conversate` / menu `Prep Note`
  (shows the note paged on the lens).

### 6.5 Head-up dashboard

G1 only (Hub apps cannot replace the G2 system dashboard; on G2 the app's idle home screen shows
the same content). On `HEAD_UP` while Idle or Live: 5 lines — time + glasses battery, top 2
watchlist quotes, top headline, top open to-do / last note. HEAD_DOWN or 5 s → previous screen.
**Depends on spike S2:** if the G1 firmware draws its own dashboard on head-up and ours conflicts,
fall back to the firmware dashboard (no Helix screen on head-up) and expose the dashboard via the
menu instead.

## 7. G2 Even Hub app (architecture; separate plan)

- `evenhub/`: TypeScript + Vite, Even Hub SDK, Vitest. Implements the core state machine in TS and
  runs `conversate-core/vectors` in Vitest.
- Rendering: cue container (top, ~4 lines, border on new cue), caption container (bottom, ~5
  lines, `textContainerUpgrade`), list containers for panels (≤20 items × 64 chars).
- Audio: `audioControl(true, Glasses|Phone)` → OpenAI realtime transcription over WebSocket.
- Keys/settings in Hub `localStorage`; menu via native `menuObject` (re-sent on every rebuild).
- Android WebView may suspend in the background → re-arm audio on foreground (Hub docs).
- Validated on the Even Hub simulator, then on the user's G2 + R1.

## 8. Error handling

| Failure | Behaviour |
|---|---|
| LLM error/timeout for cues | skip that window; captions unaffected; phone shows a degraded badge after 3 consecutive |
| Malformed cue JSON | drop, count |
| Market/news provider error or no key | panel shows `Unavailable` line; contextual QUOTE/HEADLINE cues disabled |
| BLE screen send fails one lens | existing ABSENT vs FAILED handling in `G1CommandTransport` |
| R1 disconnect / unknown frame | reconnect with backoff; ignore unknown frames |
| Transcription source drops | existing reconnect; Live shows `… reconnecting` on the caption line |
| Quick note empty transcript | `Nothing heard` then back |

## 9. Testing

- **Shared vectors** (`conversate-core/vectors`) run by Android JUnit (via test resources srcDir)
  and later Vitest.
- Android unit: `ConversateSessionTest` (vectors), `G1HudComposerTest` (exact 5-line golden text),
  `G1InputMapperTest`, `R1FrameDecoderTest` (golden frames), `CueParserTest`, `CueEngineGatingTest`
  (virtual time), `ConversateHudDriverTest` (coalescing/latest-wins with fake transport),
  `FinnhubProviderTest`/`RssNewsProviderTest` (mockwebserver), `QuickNoteFlowTest`.
- Gate: `cd android && ./gradlew :app:testDebugUnitTest :app:assembleDebug`; repo gate
  `bash scripts/run_gate.sh` stays green (no native package change required).
- Hardware checklist on G1 (+R1): caption latency, menu navigation by touchpad and ring, cue
  pop/fade, end-session confirm, panels, quick note, head-up.

## 10. Hardware spikes — entry gates

The spikes are **gates**, run before the code that depends on them: S2 + S3 before Plan A's
input mapping and caption cadence are finalized; S1 before Plan B. Plan A ships touchpad-only
navigation first, so nothing in Plan A depends on R1.

| Spike | Question | Probe | Fallback |
|---|---|---|---|
| S1 R1 link | Do R1 gestures reach Helix directly while bonded to Android? | nRF Connect: subscribe `bae80011/13`, record frames; then debug `R1Transport` build | touchpad-only; revisit with HCI snoop capture |
| S2 G1 gestures | Does long-press (`23`) trigger firmware UI/mic side effects? Does head-up (`2`) firmware dashboard fight a Helix screen? | debug build logging + screen send on `23`/`2` | D3 gesture fallback; head-up dashboard disabled |
| S3 Throughput | Fastest stable full-screen rate on G1 | send N screens back-to-back, measure ACK latency | raise caption coalesce interval |

### Hardware results — PENDING

Plan A software shipped on `feature/conversate` (2026-10-05). Run the Device-tab
"Conversate probe" (debug build) and record here before merge:

| Check | Result |
|---|---|
| Left long-press → `23` then `24`? Firmware UI / mic indicator? | |
| Right long-press indices | |
| Single tap L/R → `1` per side? | |
| Fast double-tap → one `0` or two `1`s? | |
| Head up/down while a Helix screen is shown | |
| Throughput probe ×3 (median / p90) → caption interval = max(700, p90+100) | |

Plan A acceptance checklist: see Task 15 in
`docs/superpowers/plans/2026-10-05-conversate-plan-a-g1-mvp.md`.

## 11. Implementation plans

This spec is delivered as four plans, each built, tested and shipped in order:

| Plan | Contents | Gate |
|---|---|---|
| **A** | Spikes S2/S3 → G1 Conversate MVP: `ConversateSession`, `G1HudComposer`, `ConversateHudDriver`, arbiter tokens, touchpad routing, partial captions, cue engine, Prep Notes, phone UI; `conversate-core/` vectors for these | S2, S3 |
| **B** | Spike S1 → `R1Transport` + `R1InputMapper` + intent dedupe | S1 |
| **C** | Feeds & Notes: market/news providers, panels, quick note, Notes panel, auto meeting notes, head-up dashboard (only if S2 passed) | A |
| **D** | G2 Even Hub app (`evenhub/`), extracting/consuming `conversate-core/` | A, D1 |

## 12. Decisions needing sign-off

- **D1** Even Hub app as a TypeScript web app in `evenhub/` (exception to the no-cross-platform rule).
- **D2** Finnhub (user key) for quotes + market news, RSS for general news.
- **D3** If S2 shows long-press is unusable, MENU on G1 without R1 becomes "left double-tap
  counted on the phone" (two `1`,L within 400 ms) and SELECT becomes right double-tap — **only if**
S2 confirms the firmware emits two `1` events for a fast double-tap rather than a single `0`.
- **D4** Double-tap at Live root asks to confirm before ending (G2 ends immediately) — avoids
  accidental ends on G1's less precise touchpad.
- **D5** Using community R1 protocol knowledge (faceclaw/hermes-g2); license checked before
  reusing any code — v1 writes its own decoder from the documented frame formats.
