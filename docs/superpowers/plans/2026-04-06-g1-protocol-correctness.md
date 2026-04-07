# G1 Protocol Correctness Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close the protocol correctness gaps identified in `docs/research/g1-protocol-conflict-report.md` — add test coverage for items already fixed in checkpoint `10905f7`, implement the unresolved H2/H3 incoming-event handling, and run the H4 BMP inversion hardware probe with a conditional fix.

**Architecture:** Three workstreams — (1) test coverage for already-landed fixes (H1 per-page screen codes, M1–M4), (2) new incoming-event handling for the 0xF5/0x0A battery event and the 0x22 status message (both currently fall through on the Dart side), (3) hardware probe for BMP inversion with a conditional one-line fix.

**Tech Stack:** Flutter 3.35+, Dart, iOS 26 deployment target.

**Scope note:** HIGH and MEDIUM items only. LOW (L1–L9), M5 (heartbeat 8s→5s), and M6 (mic side) are out of scope. Anything covered by Spec A (priority pipeline), Spec B (HUD line streaming), Spec C (Live Activity), or Spec D (cost tracking) is out of scope — see design spec §10.

**Depends on:** Nothing. Can execute in parallel with any other plan.

**Source spec:** `docs/superpowers/specs/2026-04-06-g1-protocol-correctness-design.md` (commit `bb0131e`).
**Authoritative protocol ref:** `docs/research/g1-ble-protocol-consolidated.md`.

---

## File structure

### Created (test-only)
- `test/services/glasses_protocol_test.dart` — H1, M1, M2 matrix for `aiFrameForPage` and `textPageForIndex`.
- `test/services/ble_event_test.dart` — `BleDeviceEvent.fromReceive` fixtures for 0xF5 subcommands and 0x22 variants (H2, H3).
- `test/services/proto_test.dart` — M3 inter-side delay timing, `sendHeartBeat`, `clearBitmapScreen` L→R ordering.
- `test/services/glasses_answer_presenter_pagination_test.dart` — M4 `current_page_num` monotonicity through touchpad pagination.
- `test/services/fixtures/g1_status_0x22_headup.hex` — captured byte fixture (seeded with synthetic bytes until hardware capture available).
- `test/services/fixtures/g1_status_0x22_righttap.hex` — ditto.
- `docs/research/g1-manual-test-protocol.md` — permanent record of the H4 hardware probe result.

### Modified
- `lib/services/ble.dart` — extend `_parseStatusMessage` to populate `BleStatusMessage` fields; wire `BleStatusMessage` onto `BleDeviceEvent` or a sibling stream on `BleManager`.
- `lib/services/ble_manager.dart` — subscribe to `batteryLevel` and `statusMessage` events; publish to a battery/dashboard state controller.
- `lib/services/bitmap_hud/enhanced_data_provider.dart` (or wherever the HUD battery widget reads state) — consume the battery controller.
- `lib/services/bitmap_hud/bmp_encoder.dart` — **conditional** on H4 hardware probe result. May be untouched.

---

## Phase 1 — Test coverage for already-landed fixes

### Task 1.1 — H1 / M1 / M2: glasses_protocol screen-code matrix test
- [ ] Read `lib/services/glasses_protocol.dart` and confirm `HudDisplayState.aiFrameForPage(isStreaming, pageIndex, totalPages)` and `HudDisplayState.textPageForIndex(pageIndex)` signatures.
- [ ] Create `test/services/glasses_protocol_test.dart` with the following cases:
  - `aiFrameForPage(isStreaming: true, pageIndex: 0, totalPages: 3)` → `0x31`
  - `aiFrameForPage(isStreaming: true, pageIndex: 1, totalPages: 3)` → `0x30`
  - `aiFrameForPage(isStreaming: true, pageIndex: 2, totalPages: 3)` → `0x30`
  - `aiFrameForPage(isStreaming: false, pageIndex: 2, totalPages: 3)` → `0x40`
  - Single-page streaming final: `aiFrameForPage(isStreaming: false, pageIndex: 0, totalPages: 1)` → `0x40`
  - `textPageForIndex(0)` → `0x71`
  - `textPageForIndex(1)` → `0x70`
  - `textPageForIndex(4)` → `0x70`
- [ ] Run `flutter test test/services/glasses_protocol_test.dart` — expect all green.
- [ ] Run `flutter analyze` — expect 0 errors.

### Task 1.2 — M3: 400 ms inter-side delay test
- [ ] Read `lib/services/proto.dart` around lines 155–175 and confirm `sendEvenAIData` awaits a `Future.delayed(Duration(milliseconds: 400))` between L and R writes when both sides are connected.
- [ ] Create `test/services/proto_test.dart`. Build a `FakeBleManager` that records `(side, timestampMs, command)` tuples on every `requestList` call and returns a synthetic ACK.
- [ ] Test case "sendEvenAIData inserts ≥400 ms between L and R":
  - Call `Proto.sendEvenAIData` with a single-page payload and both L and R "connected".
  - Assert two entries recorded, sides `L` then `R`, `tR - tL >= 400`.
- [ ] Test case "sendEvenAIData with only L connected sends once, no delay gate".
- [ ] Test case "sendHeartBeat packet is 6 bytes `[0x25, 0x06, 0x00, seq, 0x04, seq]`" (adjust to match current implementation).
- [ ] Test case "clearBitmapScreen sends L before R" (ordering only).
- [ ] Run `flutter test test/services/proto_test.dart` and `flutter analyze`.

### Task 1.3 — M4: current_page_num monotonicity through touchpad pagination
- [ ] Read `lib/services/glasses_answer_presenter.dart` around line 319–331 (`_defaultSender`) and the pagination event handler. Confirm `currentWindow` is 1-based and propagates to `Proto.sendEvenAIData` as `currentPage`.
- [ ] Read `lib/services/conversation_engine.dart` lines 2363–2411 to confirm streaming path passes `currentPageIndex + 1`.
- [ ] Create `test/services/glasses_answer_presenter_pagination_test.dart`. Inject a `recordingSender` callback in place of `_defaultSender` that captures `(currentPage, maxPage, screenCode)` on every send.
- [ ] Test case "3-window answer emits currentPage 1,2,3 with maxPage=3 and screen codes 0x71,0x70,0x70 as user pages forward".
- [ ] Test case "paging back emits currentPage 2 with screen code 0x70" (no canvas reset on backward nav — confirm this matches current behavior; if not, file as a finding inside the test comment).
- [ ] Assert invariant `currentPage <= maxPage` across every call.
- [ ] Run `flutter test test/services/glasses_answer_presenter_pagination_test.dart` and `flutter analyze`.
- [ ] Since this touches test coverage for `conversation_engine.dart` behavior, run `bash scripts/run_gate.sh` and expect green.

---

## Phase 2 — H2 battery event (0xF5 / 0x0A)

### Task 2.1 — Failing parse-layer test
- [ ] Read `lib/services/ble.dart` around lines 133–220 to confirm the current `BleDeviceEvent.fromReceive` path and the existing `batteryLevel` kind added in checkpoint `10905f7`.
- [ ] Add a test group "0xF5 battery level (H2)" to `test/services/ble_event_test.dart` (create file if missing; import the helpers from `test/helpers/test_helpers.dart`).
- [ ] Test case: `BleDeviceEvent.fromReceive(BleReceive(side: 'L', data: Uint8List.fromList([0xF5, 0x0A, 0x50])))` returns a non-null event with `kind == BleDeviceEventKind.batteryLevel`, `payload == 0x50`, `side == 'L'`.
- [ ] Test edge cases: `0x00`, `0x64`, `0xFF` (out-of-range — still parsed, consumer clamps).
- [ ] Run `flutter test test/services/ble_event_test.dart`. If the current `fromReceive` already handles 0x0A (per checkpoint `10905f7`), test passes green. If not, this is the failing test that drives Task 2.2.

### Task 2.2 — Parse implementation (if not already complete)
- [ ] Only if Task 2.1 is red: add the `0x0A` case in `BleDeviceEvent.fromReceive` setting `kind = batteryLevel`, `payload = data[2]`.
- [ ] Re-run Task 2.1 test. Green.
- [ ] `flutter analyze` + `bash scripts/run_gate.sh` (touches `ble.dart`).

### Task 2.3 — Consumer wiring
- [ ] Grep for `BleDeviceEventKind.batteryLevel` across `lib/` to find any existing consumer. If none, identify the battery HUD widget: grep `battery` in `lib/services/bitmap_hud/` and `lib/widgets/`.
- [ ] Add a `StreamController<({String side, int level})>` in `BleManager` (or extend an existing `bleBatteryStream`). Subscribe to `BleDeviceEvent` stream; when `kind == batteryLevel`, add `(side, payload)` to the controller.
- [ ] Update the identified battery-state consumer (likely `enhanced_data_provider.dart` or a dashboard controller) to subscribe and store per-side level; expose `min(L, R)` as the displayed level.
- [ ] Write `test/services/ble_manager_battery_test.dart`: feed a synthetic `BleDeviceEvent.batteryLevel(side: 'L', payload: 80)` into the manager and assert the controller emits `(L, 80)`.
- [ ] `flutter analyze` + targeted test + `bash scripts/run_gate.sh`.

---

## Phase 3 — H3 status message (0x22)

### Task 3.1 — Failing tests for both variants
- [ ] Read `lib/services/ble.dart` lines 274–315 to confirm the current `_parseStatusMessage` shape and the existing (unpopulated) `BleStatusMessage` class.
- [ ] Consolidated doc §3 specifies the 0x22 layouts. Build synthetic fixtures:
  - 10-byte head-up: `[0x22, 0x0A, eventCode, battery, unread, lowPower, dashMode, paneMode, page, reserved]`
  - 8-byte right-tap: `[0x22, 0x08, eventCode, dashMode, paneMode, page, reserved, reserved]`
  - (Exact field offsets: confirm against `g1-ble-protocol-consolidated.md §3` during implementation; adjust test if offsets differ.)
- [ ] Add a test group "0x22 status message (H3)" to `test/services/ble_event_test.dart`:
  - Head-up variant → event with `kind == headUp` AND a `statusMessage` payload containing `battery, unreadCount, lowPower, dashboardMode, paneMode, page`.
  - Right-tap variant → event with `kind == pageForward` AND a `statusMessage` payload containing `dashboardMode, paneMode, page`.
- [ ] Run — expect red (fields currently discarded).

### Task 3.2 — Extend _parseStatusMessage
- [ ] In `lib/services/ble.dart`, populate `BleStatusMessage` from the packet bytes (both variants). Attach to the returned `BleDeviceEvent` via a new optional `statusMessage` field, or emit on a sibling field.
- [ ] Re-run Task 3.1 tests. Green.
- [ ] Save hex fixtures at `test/services/fixtures/g1_status_0x22_headup.hex` and `..._righttap.hex`; add a TODO comment noting they are synthetic until a real device capture replaces them.
- [ ] `flutter analyze` + `bash scripts/run_gate.sh`.

### Task 3.3 — Consumer wiring
- [ ] In `BleManager`, subscribe to events carrying `statusMessage != null` and route:
  - `battery` field into the same battery controller added in Task 2.3 (latest-wins merge with 0x0A events).
  - `unreadCount` into a new or existing unread-count controller (grep `unread` under `lib/services/` to find an existing sink).
  - `dashboardMode`, `paneMode`, `page` into the dashboard-state controller that currently handles `dashboardOpened` / `dashboardClosed`.
- [ ] Write `test/services/ble_manager_status_test.dart`: feed a synthetic head-up status event through the manager, assert battery controller emits, dashboard controller emits mode/pane/page.
- [ ] `flutter analyze` + `bash scripts/run_gate.sh`.

---

## Phase 4 — H4 BMP pixel inversion hardware probe

### Task 4.1 — Build a probe harness
- [ ] Read `lib/services/bitmap_hud/bmp_encoder.dart` (if it exists; otherwise locate BMP encoding under `lib/services/bitmap_hud/`). Confirm the 62-byte header layout and color table (`index 0 = white, index 1 = black`).
- [ ] Add a dev-only debug route (gated behind a debug flag, not shipped) that sends a **known pattern BMP**: top half (68 rows) solid black, bottom half solid white, 576×136, 1-bit, standard Helix color table. Use the existing `BitmapHudService` send path — do NOT modify the encoder.
- [ ] No unit test here; this is a visual probe.

### Task 4.2 — Manual hardware QA
- [ ] Pair a real G1 pair. Trigger the probe route.
- [ ] Observe the HUD:
  - **PASS (firmware honors color table):** top = black, bottom = white → Helix current behavior is correct. Record outcome in `docs/research/g1-manual-test-protocol.md`. Close H4 as non-issue. Skip Task 4.3 and Task 4.4.
  - **FAIL (firmware ignores color table):** top = white, bottom = black → inversion needed. Record outcome and proceed to Task 4.3.
- [ ] Write the observation (screenshot or phone photo of glasses output) into `docs/research/g1-manual-test-protocol.md`.

### Task 4.3 — Conditional inversion fix (only if Task 4.2 FAIL)
- [ ] Modify `lib/services/bitmap_hud/bmp_encoder.dart` to XOR every pixel byte with `0xFF` after writing the 62-byte header and before chunking.
- [ ] Add `test/services/bmp_encoder_inversion_test.dart` that encodes a known bit pattern and asserts bytes 62..N are the bitwise inverse of the unencoded pixel data.
- [ ] `flutter analyze` + `flutter test test/services/bmp_encoder_inversion_test.dart` + `bash scripts/run_gate.sh`.

### Task 4.4 — Re-verify on hardware (only if Task 4.3 ran)
- [ ] Re-run the probe route with the inversion fix.
- [ ] Confirm: top = black, bottom = white.
- [ ] Append confirmation to `docs/research/g1-manual-test-protocol.md`. Remove or disable the debug probe route before merging.

---

## Phase 5 — Final validation

- [ ] `bash scripts/run_gate.sh` — full validation gate must be green.
- [ ] `flutter build ios --simulator --no-codesign` — must succeed.
- [ ] Diff review: confirm no Spec A/B/C/D scope was touched.
- [ ] Self-review against `docs/research/g1-protocol-conflict-report.md` — every HIGH and MEDIUM severity item (H1–H4, M1–M4) is either tested or implemented or explicitly documented as deferred (M5, M6). LOW items untouched.

---

## Traceability

| Spec section | Conflict report item | Phase.Task | Kind |
|---|---|---|---|
| §1 | H1 | 1.1 | Test only |
| §2 | H2 | 2.1 / 2.2 / 2.3 | Test + impl |
| §3 | H3 | 3.1 / 3.2 / 3.3 | Test + impl |
| §4 | H4 | 4.1 / 4.2 / 4.3 / 4.4 | Hardware probe + conditional fix |
| §5 | M1 | 1.1 | Test only |
| §6 | M2 | 1.1 | Test only |
| §7 | M3 | 1.2 | Test only |
| §8 | M4 | 1.3 | Test only |
| §10 | M5, M6, L1–L9, Spec A/B/C/D overlap | — | Out of scope |
