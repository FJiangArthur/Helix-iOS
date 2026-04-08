# G1 BLE Protocol Reference

Consolidated reference for the Even Realities G1 BLE protocol. The
authoritative summary lives in **CLAUDE.md → "BLE & HUD Protocol"**;
this file holds the open-source citations, the canonical UUID/command
tables, and any field that's referenced from code comments or by
debugging notes.

## Sources reviewed

- `emingenc/even_glasses` — Python SDK v0.1.11
- `emingenc/g1_flutter_blue_plus` — Flutter BLE wrapper
- `even-realities/EvenDemoApp` — official Android reference
- `JohnRThomas/EvenDemoApp` wiki — community RE (~990 lines)
- `binarythinktank/eveng1_python_sdk`
- `lohmuller/even-g1-java-sdk`
- `rodrigofalvarez/g1-basis-android`
- `meyskens/fahrplan` — full-featured Flutter assistant app
- `AugmentOS-Community/AugmentOS` — smart glasses OS platform
- `galfaroth/awesome-even-realities-g1` — ecosystem catalog

Date: 2026-04-05.

## BLE transport (Nordic UART Service)

| Role | UUID | Direction |
|---|---|---|
| Service | `6E400001-B5A3-F393-E0A9-E50E24DCCA9E` | — |
| TX char | `6E400002-B5A3-F393-E0A9-E50E24DCCA9E` | Phone → Glasses (write) |
| RX char | `6E400003-B5A3-F393-E0A9-E50E24DCCA9E` | Glasses → Phone (notify) |

Standard NUS. Names are from the **peripheral's** perspective. Phone
writes to TX, subscribes to notifications on RX. Write type is
`response=True` (write-with-response).

## Command bytes (the relevant ones)

| Cmd | Name | Direction | Notes |
|---|---|---|---|
| `0x01` | NEW_CONTENT | TX | Initial AI screen content |
| `0x18` | CLEAR_BITMAP_SCREEN | TX | Fire-and-forget. Required to fully empty bitmap overlay (paired with `0x26`). |
| `0x22` | STATUS_EVENT | RX | Battery, triple-tap, charging, dashboard open/close |
| `0x26` | DASHBOARD_VISIBILITY | TX | Show / hide dashboard. Must be followed by `0x18` to clear display buffer. |
| `0x4E` | SEND_RESULT (AI/text) | TX | AI text streaming. The 5th header byte is `screen_status`. |
| `0xF5` | DEVICE_EVENT | RX | head-up, head-down, right-tap |

## `0x4E` AI/text packet header

```
[0x4E, syncSeq, maxSeq, seq, screen_status,
 new_char_pos_hi, new_char_pos_lo,
 currentPage, maxPage, ...data]
```

`screen_status` is `ScreenAction | AIStatus`:

| Value | Meaning | Helix uses? |
|---|---|---|
| `0x01` | NEW_CONTENT | yes — page index 0 |
| `0x30` | DISPLAYING (auto-advance) | yes — pages ≥1 |
| `0x40` | DISPLAY_COMPLETE | yes — final frame |
| `0x50` | MANUAL_MODE (suppress firmware auto-advance) | no |
| `0x60` | NETWORK_ERROR | no |
| `0x70` | text mode | yes — text HUD path |

### Critical findings (verified on hardware)

- **`new_char_pos` is hard-coded `0` in every reference SDK.** It is
  NOT an append offset. It's likely a highlight position, not a write
  position. Pagination is 100% phone-driven by re-pushing whole pages
  with updated `current_page_num`. An attempt to use it as a delta
  offset (commit `10905f7`, reverted in `ddaab66`) caused the L lens
  to get stuck on the EvenAI listening screen.
- **There is no scroll command.** All page-flip behavior is phone-side
  re-rendering of the full canvas.
- **Per-page screen codes:** `0x01` only on page index 0. Pages ≥1 use
  `0x00` (or the appropriate `aiFrameForPage`/`textPageForIndex`
  helper). Sending `0x01` on every page causes the firmware to reset
  the canvas between pages → visible flicker.
- **L/R coordination:** insert `Proto.evenAIInterSideDelay` (400 ms)
  between the L write and the R write to eliminate the
  R-eye-first-then-both visual glitch. Gate the delay on
  `leftConnected && rightConnected` — skip if only one side is
  connected.

## Bitmap dashboard hide/show

The Even Realities SDK requires BOTH commands to fully empty the
bitmap overlay:

1. `0x26` — dashboard visibility command (await ACK)
2. `0x18` — clear-screen command, **fire-and-forget** (no ACK wait)

Earlier attempts:
- `0x26`-only → display buffer never cleared, bitmap stays on screen
- `0x26` + `pushScreen(0xF4)` → `0xF4` times out, blocks state
  recovery with "dashboard screen hide failed"

Cache behavior: only invalidate the bitmap cache when handing off to
text/native routes (`quickAsk`, `notification`, `liveListening`,
`textTransfer`). When returning to idle/dashboard, preserve the cache —
the glasses still hold the last uploaded frame at `0x001C0000` so the
next show can delta-send with zero changed chunks for near-instant
re-display.

## Touchpad notify indices

Arrive on the device-event stream with `notifyIndex`:

| Index | Event |
|---|---|
| `0` | exit |
| `1` | pageBack (L) / pageForward (R) |
| `2` | headUp |
| `3` | headDown |
| `17` | glassesConnectSuccess |
| `23` | evenaiStart |
| `24` | evenaiRecordOver |

**Wiring gotcha:** head-up/head-down are NOT wired to the hide path in
`ble_manager.dart` — both events fall through to a log-only branch.
The hide is triggered via `dashboard_service._deviceEventSub`, which
subscribes to `BleManager.deviceEventStream` and calls
`handleDeviceEvent`. If you grep for `headDown` in `ble_manager.dart`
and see it's log-only, don't assume hide is broken — the wiring is in
`dashboard_service`.

## BLE transport policy

**Changed from "require both sides ACK" to "at-least-one-side
success".** The glasses internally relay between L and R, so single-
side ACK is sufficient for most commands. Tests that check
`expect(result, isFalse)` for single-side failure paths must be
updated.

## Display geometry

- **Physical:** 576x136 px per lens
- **Text HUD:** 488 px max width, 21 pt font, 5 lines per page
- **Bitmap HUD:** widget-based, full-canvas render via
  `BitmapHudService`

## MTU configuration

Standard MTU negotiation. Effective payload after BLE/ATT overhead is
~191 bytes per packet — that's the chunk size used for multi-packet
EvenAI text sending with sequence numbers.
