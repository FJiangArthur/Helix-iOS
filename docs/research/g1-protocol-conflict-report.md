# G1 Protocol Conflict Report — Helix-iOS vs Spec

> Audited by 4 parallel agents against JohnRThomas wiki, Python SDK, Flutter SDK,
> AugmentOS, and official EvenDemoApp.
>
> Date: 2026-04-05

---

## HIGH Severity

### H1. AI streaming sends same screen code for ALL pages
- **File:** `lib/services/conversation_engine.dart:2348`
- **Current:** All pages get `0x31` (streaming) or `0x41` (complete). No differentiation.
- **Spec:** First=`0x31` (new canvas), Middle=`0x30` (existing canvas), Last=`0x40` (complete, no new canvas)
- **Impact:** Glasses may clear canvas on each middle page causing visible flicker. Final page forces unnecessary canvas reset.

### H2. Battery event (0x0A) not handled
- **File:** `lib/services/ble.dart:133` — missing from event switch
- **Current:** Falls through to `unknownDeviceOrder`, silently dropped.
- **Spec:** `[0xF5, 0x0A, level(0-100)]` carries glasses battery percentage.
- **Impact:** Battery HUD widget has no data source from glasses. Battery display is non-functional or shows stale data.

### H3. Status messages (0x22) completely ignored
- **File:** Not referenced anywhere in codebase.
- **Current:** 0x22 packets arrive via native → Dart but are silently dropped (not 0xF5, so `BleDeviceEvent.fromReceive` returns null).
- **Spec:** Two variants: 10-byte on head-up (battery, unread count, low power, dashboard mode, pane mode, page) and 8-byte on right-tap (dashboard mode, pane, page).
- **Impact:** Free battery level, unread notification count, and dashboard state data completely wasted.

### H4. BMP pixel inversion possibly missing
- **File:** `lib/services/bitmap_hud/bmp_encoder.dart` (entire file)
- **Current:** Raw BMP bytes sent directly. No inversion after 62-byte header.
- **Spec:** AugmentOS inverts all pixel bits after BMP header before sending.
- **Impact:** **Conditional** — if G1 firmware reads the BMP color table (which Helix sets correctly: index 0=white, 1=black), this works fine. If firmware assumes fixed bit polarity, display shows inverted colors. **Test on hardware to confirm.**

---

## MEDIUM Severity

### M1. Answer pages always force new canvas (0x71)
- **File:** `lib/services/glasses_answer_presenter.dart:326`
- **Current:** Every answer window/page uses `HudDisplayState.textPage()` → `0x71` (text show + new canvas).
- **Spec:** First page `0x71`, subsequent pages `0x70` (existing canvas).
- **Impact:** Each page unnecessarily resets canvas, potential flicker.

### M2. TextService sends all pages with same screen code
- **File:** `lib/services/text_service.dart:24`
- **Current:** `_screenCodeForPage()` always returns `0x71`.
- **Spec:** Same as M1 — first `0x71`, subsequent `0x70`.
- **Impact:** Same flicker risk as M1.

### M3. No inter-side delay for EvenAI data sends
- **File:** `lib/services/proto.dart:155-175`
- **Current:** `sendEvenAIData` sends to L, awaits response, immediately sends to R. No explicit delay.
- **Spec:** 400ms delay between L and R writes for text.
- **Impact:** Display sync issues between left and right lenses possible on fast connections.

### M4. `current_page_num` always equals total pages
- **File:** `lib/services/conversation_engine.dart:2349`
- **Current:** `currentPage = paginator.pageCount > 0 ? paginator.pageCount : 1`
- **Spec:** Should be actual current page index (1-based).
- **Impact:** Glasses always thinks it's on the last page. Page indicator display incorrect for multi-page responses.

### M5. Heartbeat interval too slow
- **File:** `lib/ble_manager.dart:233-234`
- **Current:** 8s default, 30s idle, suppressed during conversation.
- **Spec:** 5s constant.
- **Impact:** Glasses may consider connection stale. In practice this seems to work, but could cause intermittent disconnects.

### M6. Mic enable defaults to wrong side
- **File:** `lib/services/proto.dart:106-115`
- **Current:** Defaults to R via `Proto.lR()`.
- **Spec:** Wiki says Left only (disputed — AugmentOS says Right).
- **Impact:** Low practical impact — this Dart code path is dead (mic control happens on native Swift side).

### M7. Triple-tap events (0x04/0x05) not handled
- **File:** `lib/services/ble.dart:133`
- **Current:** Falls to `unknownDeviceOrder`.
- **Spec:** Silent mode toggle events.
- **Impact:** Glasses may enter/exit silent mode without app knowledge.

### M8. Right touchpad held (0x12) not handled
- **File:** `lib/services/ble.dart:133`
- **Current:** Falls to `unknownDeviceOrder`.
- **Spec:** Right touchpad press/hold/release.
- **Impact:** Limits gesture vocabulary to left-side-only interactions.

### M9. Charging status (0x09) not handled
- **File:** `lib/services/ble.dart:133`
- **Current:** Falls to `unknownDeviceOrder`.
- **Spec:** `[0xF5, 0x09, 0/1]` charging status.
- **Impact:** No way to show charging state in app.

### M10. Dashboard open/close events (0x1E/0x1F) not handled
- **File:** `lib/services/ble.dart:133`
- **Current:** Falls to `unknownDeviceOrder`.
- **Spec:** Glasses native dashboard opened/closed.
- **Impact:** State mismatch between glasses UI state and Helix's internal dashboard state.

---

## LOW Severity

### L1. 0xF5 clear command not implemented as outgoing
- Uses `0x18` only (also valid per spec). Non-issue.

### L2. BMP resolution 576×136 vs AugmentOS 576×135
- Matches Python SDK. Likely AugmentOS bug.

### L3. 2-byte BMP trailer from Even samples
- Non-standard but derived from official assets.

### L4. Delta BMP CRC scope
- CRC over full data regardless of delta. Firmware-dependent.

### L5. Glasses worn/not-worn (0x06/0x07) not handled
- Could auto-pause/resume transcription. Nice-to-have.

### L6. Case events (0x08/0x0B/0x0E/0x0F) not handled
- Case lid, charging, battery. Nice-to-have.

### L7. Heartbeat response seq not validated
- `lib/services/proto.dart:297-302` — checks cmd and 0x04 marker but not seq match. Minor.

### L8. 0x11 label imprecise
- `lib/services/ble.dart:168` — mapped as `glassesConnectSuccess`, spec says "BLE paired." Semantic only.

### L9. Double-tap translate (0x20) not handled
- Falls to `unknownDeviceOrder`.

---

## NO CONFLICT (Correct)

These were audited and confirmed correct:

| Area | Status |
|------|--------|
| BLE UUIDs (NUS) | ✅ Identical |
| BMP CRC (Crc32Xz, addr+data, big-endian) | ✅ Correct |
| BMP complete before CRC order | ✅ Correct |
| BMP storage address `[0x00, 0x1C, 0x00, 0x00]` | ✅ Correct |
| BMP chunk size 194 bytes | ✅ Correct |
| BMP L-then-R send order (not interleaved) | ✅ Correct |
| BMP inter-chunk delay (8ms iOS, 5ms default) | ✅ Correct |
| BMP complete ACK check (0xC9/0xCB) | ✅ Correct |
| BMP CRC ACK check (data[5] or data[1]) | ✅ Correct |
| Screen status code constants (0x30/0x40/0x70) | ✅ Correct |
| 9-byte EvenAI header format | ✅ Correct |
| Multi-packet chunking (191 bytes) | ✅ Correct |
| Text wrapping (488px, 21pt, 5 lines) | ✅ Correct |
| pushScreen `[0xF4, screenId]` | ✅ Correct |
| Clear screen `[0x18]` single byte | ✅ Correct |
| Notification send (0x4B) to Left only | ✅ Correct |
| Whitelist send (0x04) to Left only | ✅ Correct |
| All "Both sides" commands routed correctly | ✅ Correct |
| Heartbeat packet format (6 bytes) | ✅ Correct |
| Heartbeat timeout (1500ms) | ✅ Correct |
| Init command `[0x4D, 0x01]` to both sides | ✅ Correct |
| Event mapping (0/1/2/3/23/24) | ✅ Correct |
| First BMP chunk includes 4-byte address | ✅ Correct |
| First BMP chunk index = 0x00 | ✅ Correct |

---

## Recommended Fix Priority

### Phase 1 — Fix screen code logic (affects current display quality)
1. **H1:** Differentiate screen codes per page position (first/middle/last)
2. **M1+M2:** Use `0x70` for subsequent pages in text/answer presenters
3. **M4:** Fix `current_page_num` to track actual page index

### Phase 2 — Add missing event handling (unlocks features)
4. **H2:** Handle 0x0A battery level event → feed battery widget
5. **H3:** Parse 0x22 status messages → battery + dashboard state
6. **M10:** Handle dashboard open/close for state sync

### Phase 3 — Timing and transport (polish)
7. **M3:** Add 400ms inter-side delay for text sends
8. **M5:** Reduce heartbeat interval to 5s (or at least from 8s)

### Phase 4 — Extended events (completeness)
9. **M7-M9:** Handle triple-tap, right touchpad, charging events
10. **H4:** Test BMP pixel inversion on hardware — fix only if needed
