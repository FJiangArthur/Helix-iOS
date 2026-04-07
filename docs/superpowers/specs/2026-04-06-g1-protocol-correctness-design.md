# G1 Protocol Correctness

**Date:** 2026-04-06
**Status:** Design spec (Spec E)

---

## Relation to other specs

This spec covers the remaining items from `docs/research/g1-protocol-conflict-report.md` (audit 2026-04-05) that are **not** already addressed by Spec A (priority pipeline), Spec B (line-by-line HUD streaming), Spec C (live activity rework), or Spec D (session cost tracking), and that are **not** already resolved by the in-flight checkpoint `10905f7` on the current branch.

Several conflict-report items have already been resolved in checkpoint `10905f7`: **H1** (per-page AI screen status), **M1** (answer-page screen code), **M2** (text-service screen code), **M3** (400 ms inter-side delay in `sendEvenAIData`), and **M4** (`current_page_num` tracks the actual page). This spec documents those for completeness and flags the **test-coverage gap** that remains for every one of them — none of them has a regression test.

Spec B (HUD line streaming) deliberately scopes only the flush trigger. Per-page screen-status correctness is explicitly out of Spec B's scope and was covered by the in-flight work.

The authoritative protocol source cited throughout is `docs/research/g1-ble-protocol-consolidated.md` (synthesized from 10+ open-source G1 SDKs). Section references below (e.g. "consolidated §5") point into that document.

---

## Open questions (resolve during implementation)

1. **H4 / BMP pixel inversion:** the AugmentOS implementation inverts all pixel bits after the 62-byte BMP header before sending. Helix sets the color table to `index 0 = white, index 1 = black`, so if the G1 firmware reads the color table the current code is correct. If the firmware assumes fixed bit polarity and ignores the table, our HUD renders inverted. This **cannot be resolved without hardware observation**. See §4.
2. **M4 verification:** the in-flight fix moved `current_page_num` from `totalPages` to the actual streaming page index + 1. Is the multi-page touchpad pagination path (user pages forward/back through a completed answer) also using the correct index, or only the streaming path? Needs a code read of `glasses_answer_presenter.dart` pagination and a quick hardware confirmation.
3. **H2 / battery event (0x0A) downstream sink:** the BLE layer now constructs a `batteryLevel` event with `payload = data[2]`, but it is not clear that anything on the Dart side consumes it to update the battery HUD widget. Needs a dataflow audit from `BleDeviceEvent` → widget state.
4. **H3 / 0x22 status message fields:** the current `_parseStatusMessage` in `ble.dart` only extracts the event code (head-up vs right-tap) and throws away battery, unread count, low-power, dashboard mode, pane mode, and page fields. Should these be surfaced as a separate `BleStatusMessage` stream, or folded into the existing battery / dashboard state streams?

---

## 1. Section H1 — AI streaming screen status per page (RESOLVED 10905f7)

**Status:** Resolved in checkpoint `10905f7`. Documented here for completeness; a regression test is missing.

**Previous behavior:** `ConversationEngine._sendToGlasses` hard-coded `screenCode = 0x31` for all streaming frames and `0x41` for the completion frame regardless of page index. This forced the glasses canvas to reset on every middle page of a multi-page response (visible flicker) and forced an unnecessary new-canvas bit on the final page.

**Correct behavior per consolidated §5:** First page streaming = `0x31` (`_aiShowing | _displayNewContent`). Subsequent streaming pages = `0x30` (`_aiShowing`, no new-canvas bit). Final completion = `0x40` (`_aiComplete`).

**Current implementation:** `HudDisplayState.aiFrameForPage(isStreaming, pageIndex, totalPages)` in `lib/services/glasses_protocol.dart:16-24` returns exactly that mapping. Called from `lib/services/conversation_engine.dart:2378`.

**Remaining gap — test coverage:** There is no unit test in `test/services/` that asserts `aiFrameForPage` returns `0x31` for page 0 / `0x30` for page 1 / `0x40` for the completion frame. Add `test/services/glasses_protocol_test.dart` covering the full matrix (streaming × page 0 / middle / last, non-streaming final). Pure function, trivial to test.

---

## 2. Section H2 — Battery event (`0xF5` subcmd `0x0A`) handling

**Status:** Partially resolved — the BLE layer now constructs a `BleDeviceEventKind.batteryLevel` event (`lib/services/ble.dart:206-214`, checkpoint `10905f7`). Downstream wiring to the HUD battery widget is **unconfirmed** and likely still missing.

**Current behavior (top of pipeline):** `BleDeviceEvent.fromReceive` now returns a `batteryLevel` event with `payload = data[2]` (0–100) when notifyIndex is `0x0A`. Previously it fell through to `unknownDeviceOrder` and was silently dropped.

**Correct behavior per consolidated §3 / §10:** `[0xF5, 0x0A, level]` carries the glasses battery percentage. It should feed the battery HUD widget and any battery-related dashboard / Live Activity state.

**Remaining fix:**

- `lib/services/ble_manager.dart` or wherever `BleDeviceEvent` is consumed: add a listener branch for `BleDeviceEventKind.batteryLevel` that updates a battery-state controller (new or existing).
- `lib/services/bitmap_hud/enhanced_data_provider.dart` (or wherever the battery widget reads from): subscribe to that controller.
- Per-side tracking: the event carries `side = L|R`. The HUD should show the lower of the two, or both if the UI supports it.

**Testing:**

- Unit test: feed a fake `BleReceive` with `[0xF5, 0x0A, 0x50]` into `BleDeviceEvent.fromReceive` and assert `kind == batteryLevel`, `payload == 0x50` (done as part of H1's test file or a new `ble_event_test.dart`).
- Integration test: feed the same event through the consumer and assert the battery state controller emits `(side: 'L', level: 80)`.

---

## 3. Section H3 — Status message (`0x22`) parsing

**Status:** Partially resolved — `_parseStatusMessage` in `lib/services/ble.dart:274-312` now catches `0x22` packets and distinguishes the two variants (size `0x0A` → head-up, size `0x08` → right-tap), but the additional payload fields (battery, unread count, low power, dashboard mode, pane mode, page) are **not extracted**. The `BleStatusMessage` class at `ble.dart:315` defines the schema but is not populated from the main event path.

**Current behavior:** The size-10 head-up variant returns a `headUp` event with no extra payload. The size-8 right-tap variant returns a `pageForward` event. All the other fields in the packet are discarded.

**Correct behavior per consolidated §3 / conflict report H3:**

- 10-byte (`size == 0x0A`) head-up variant carries: event code, battery %, unread notification count, low-power flag, dashboard mode, pane mode, page index.
- 8-byte (`size == 0x08`) right-tap variant carries: dashboard mode, pane mode, page index.

These fields are a free source of battery, unread count, and dashboard state without needing a separate query.

**Remaining fix:**

- Extend `_parseStatusMessage` to build a `BleStatusMessage` and either attach it to the `BleDeviceEvent` (add a `statusMessage` field) or publish it on a separate `Stream<BleStatusMessage>` on `BleManager`.
- Hook the battery field into the same consumer chain added for H2 (§2), using it as a complementary source — whichever arrives more recently wins.
- Hook the dashboard mode / pane mode / page fields into the dashboard-state controller (see M10 in conflict report, which is already partially resolved via the `dashboardOpened` / `dashboardClosed` events but does not know the mode/pane).

**Testing:**

- Unit tests in `test/services/ble_event_test.dart` (new): one per packet variant with hand-crafted byte arrays, asserting every field is extracted.
- Drift guard: a fixture byte array captured from a real device during hardware testing (see §8).

---

## 4. Section H4 — BMP pixel inversion (HARDWARE TEST REQUIRED)

**Status:** Unresolved; requires a hardware probe before any code change.

**Current behavior:** `lib/services/bitmap_hud/bmp_encoder.dart` emits raw BMP bytes. No inversion pass after the 62-byte header. The color table is set to `index 0 = white, index 1 = black`.

**Conflicting reference implementations:**

- **AugmentOS** inverts all pixel bits after the 62-byte BMP header before sending. This would be wrong on the G1 if the firmware honors the color table.
- **Python SDK `emingenc/even_glasses`** and **official EvenDemoApp** send raw 1-bit BMP with a standard color table. This matches Helix's current behavior.
- Consolidated doc §18 flags this as a "High priority, verify on hardware" open item.

**Proposed fix at the code level:** none yet. **Do not change `bmp_encoder.dart` without a hardware observation.** The fix is a one-line XOR after the header write if needed.

**Hardware test protocol:**

1. On a real G1 pair, push a bitmap with a known recognizable pattern (e.g. a solid black horizontal band across the top half, solid white bottom half, rendered with index 0 = white and index 1 = black in the color table — current Helix behavior).
2. Observe the display. If top is **black** and bottom is **white** as intended → firmware honors the color table → **no fix needed**, current code is correct, close H4.
3. If top is **white** and bottom is **black** (inverted) → firmware ignores the color table and assumes fixed bit polarity → apply the inversion: after writing the 62-byte BMP header in `bmp_encoder.dart`, XOR every pixel byte with `0xFF` before chunking. Add a unit test that verifies the pixel bytes are inverted post-header.
4. Either way, write the result into `docs/research/g1-manual-test-protocol.md` as a permanent record so the next engineer does not re-debate this.

**No unit test possible** without hardware confirmation — the test would encode our current (wrong?) assumption.

---

## 5. Section M1 — Answer-page screen code (RESOLVED 10905f7)

**Status:** Resolved in checkpoint `10905f7`. Test coverage missing.

**Previous behavior:** `lib/services/glasses_answer_presenter.dart` called `HudDisplayState.textPage()` for every page, yielding `0x71` (text show + new canvas) on every window, forcing a canvas reset on every page turn.

**Correct behavior per consolidated §5:** First page `0x71`, subsequent pages `0x70` (text show, no new canvas).

**Current implementation:** `_defaultSender` in `lib/services/glasses_answer_presenter.dart:319-331` calls `HudDisplayState.textPageForIndex(currentWindow - 1)`, which returns `0x71` when `pageIndex == 0` and `0x70` otherwise (`lib/services/glasses_protocol.dart:28-31`).

**Remaining gap — test coverage:** Same test file proposed in §1 should cover `textPageForIndex(0)` → `0x71`, `textPageForIndex(1..)` → `0x70`.

---

## 6. Section M2 — TextService screen code (RESOLVED 10905f7)

**Status:** Resolved in checkpoint `10905f7`. Test coverage missing.

**Previous behavior:** `lib/services/text_service.dart` `_screenCodeForPage` returned a constant `HudDisplayState.textPage()` (`0x71`) for every page.

**Current implementation:** `lib/services/text_service.dart:24` now delegates to `HudDisplayState.textPageForIndex(pageIndex)`, matching M1.

**Remaining gap — test coverage:** A unit test of `TextService` with a multi-page payload asserting the per-page screen-status value through a `HudPacketSink`-style fake would be ideal, but `TextService` currently calls `Proto.sendEvenAIData` directly without a seam. Minimum acceptable: the `glasses_protocol_test.dart` test from §1 covers `textPageForIndex`, which is the only logic that differs per page here.

---

## 7. Section M3 — Inter-side delay for EvenAI data (RESOLVED 10905f7)

**Status:** Resolved in checkpoint `10905f7`. Test coverage missing.

**Previous behavior:** `Proto.sendEvenAIData` sent to L, awaited the response, then immediately sent to R with no delay.

**Correct behavior per consolidated §5:** 400 ms delay between L and R writes for text packets.

**Current implementation:** `lib/services/proto.dart:166-168` now awaits `Future.delayed(Duration(milliseconds: 400))` between the L write and the R write when both sides are connected.

**Remaining gap — test coverage:** No test asserts the delay. Add a test in `test/services/proto_test.dart` (new) that injects a fake `BleManager` and asserts the timestamp delta between the L `requestList` call and the R `requestList` call is ≥ 400 ms (or, with a `FakeClock`, exact). This also pins the behavior against regressions when someone tries to optimize the delay away.

---

## 8. Section M4 — `current_page_num` tracking (RESOLVED 10905f7, verify pagination path)

**Status:** Streaming path resolved in checkpoint `10905f7`. The touchpad pagination path (user pages forward/back through a completed multi-page answer) needs verification — see Open Question 2.

**Previous behavior:** `ConversationEngine._sendToGlasses` hard-coded `current_page_num = paginator.pageCount` so the firmware always thought it was on the last page of the response.

**Current implementation:** `lib/services/conversation_engine.dart:2405` now passes `currentPageIndex + 1` (where `currentPageIndex = totalPages - 1` for the streaming path — i.e. during streaming it is still the last page, but now correctly reported as the last page of the in-progress total, which is mathematically the same when the streaming text always fills the last page). This is correct for streaming but relies on `currentPageIndex = totalPages - 1`.

For the **completed-answer touchpad pagination path**, `glasses_answer_presenter.dart` passes `currentWindow` (1-based) through `_defaultSender` to `Proto.sendEvenAIData`. A quick read confirms the pagination call site uses the actual window index, not `totalWindows`, so this path appears correct. Add a regression test that feeds a 3-window answer into the presenter, simulates page-forward events, and asserts the `current_page_num` argument to the sender mock is `1, 2, 3` in sequence.

**Remaining gap — test coverage:** test as described above, plus documentation of the expected invariant (`current_page_num ≤ max_page_num`, both 1-based, `current_page_num` monotonic within a single render pass).

---

## 9. Testing strategy

### Hardware probes (cannot be automated)

- **H4:** BMP pixel inversion — see §4 step-by-step.
- **H2 cross-check:** observe a real battery level notification from a physical G1 and compare the `data[2]` byte against the glasses' displayed level.
- **H3 cross-check:** capture a size-10 head-up status packet and a size-8 right-tap status packet as hex fixtures; stash in `test/services/fixtures/`.

### Pure-Dart unit tests (add as part of this spec's implementation)

1. `test/services/glasses_protocol_test.dart` (**new**): full matrix for `HudDisplayState.aiFrameForPage` and `HudDisplayState.textPageForIndex`. Covers H1, M1, M2 regression guards.
2. `test/services/ble_event_test.dart` (**new**): fixtures for every `0xF5` subcmd Helix handles (0, 1, 2, 3, 4, 5, 0x09, 0x0A, 0x12, 17, 0x1E, 0x1F, 23, 24) and for both `0x22` variants, asserting `BleDeviceEvent.fromReceive` produces the expected kind and payload. Covers H2 and H3 at the parse layer.
3. `test/services/proto_test.dart` (**new**): `sendEvenAIData` inter-side delay test (M3), `sendHeartBeat` packet-format test, `clearBitmapScreen` L→R sequencing test.
4. `test/services/glasses_answer_presenter_test.dart` (extend existing if present, or new): multi-page navigation asserts `current_page_num` sequence (M4 pagination path).

### Integration test (optional, behind hardware harness)

- End-to-end: push a known bitmap and read back the observed display via an external camera rig. Only feasible if hardware CI is set up — not blocking.

---

## 10. Out of scope

- **Anything covered by Spec A** (priority pipeline, `QAButtonController`, `AnswerArbiter`, transcription isolation, Phase 0 diagnostic toolkit including `G1DebugService` wiring).
- **Anything covered by Spec B** (HUD line-streaming flush trigger, `HudStreamSession`, `HudPacketSink`).
- **Anything covered by Spec C** (Live Activity rework).
- **Anything covered by Spec D** (session cost tracking).
- **Low-severity items from the conflict report (L1–L9)**: single-byte clear command, BMP resolution nitpick, BMP trailer bytes, delta BMP CRC scope, wear detection events, case events, heartbeat seq validation, `0x11` label precision, double-tap translate event. These are nice-to-haves; none block any current user-facing feature.
- **M5 (heartbeat interval 8 s vs 5 s)** and **M6 (mic enable side)**: M5 empirically works and tuning it carries connection-stability risk; M6 is on a dead Dart path (mic control is native-side Swift). Flagged in the conflict report but deferred.
- **M7, M8, M9, M10 extended event handling** (triple-tap, right touchpad held, charging, dashboard open/close): already resolved in checkpoint `10905f7` at the `BleDeviceEvent` parse layer. Downstream consumers (what the app actually does with a triple-tap) are a product decision, not a protocol correctness item.
- **Navigation (`0x0A`), Quick Notes (`0x1E`), Notification auto-display (`0x4F`/`0x3C`)**: entire features Helix does not ship. Out of scope.
