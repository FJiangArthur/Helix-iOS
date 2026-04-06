# Even Realities G1 Smart Glasses — Consolidated BLE Protocol Specification

> Synthesized from 4 parallel SDE reviews of the open-source G1 ecosystem.
>
> **Sources reviewed:**
> - `emingenc/even_glasses` — Python SDK (v0.1.11)
> - `emingenc/g1_flutter_blue_plus` — Flutter BLE wrapper
> - `emingenc/even_realities_g1` — Dart/Flutter library with BLE_PROTOCOL.md
> - `even-realities/EvenDemoApp` — Official Android reference app
> - `JohnRThomas/EvenDemoApp` wiki — Community reverse-engineered protocol (~990 lines)
> - `binarythinktank/eveng1_python_sdk` — Python SDK (alternative)
> - `lohmuller/even-g1-java-sdk` — Java SDK with protocol tables
> - `rodrigofalvarez/g1-basis-android` — Android shared service architecture
> - `meyskens/fahrplan` — Full-featured Flutter assistant app
> - `AugmentOS-Community/AugmentOS` — Smart glasses OS platform
> - `galfaroth/awesome-even-realities-g1` — Ecosystem catalog
>
> **Date:** 2026-04-05

---

## 1. BLE Service & Characteristics (Nordic UART Service)

| Role | UUID | Direction |
|------|------|-----------|
| UART Service | `6E400001-B5A3-F393-E0A9-E50E24DCCA9E` | — |
| TX Characteristic | `6E400002-B5A3-F393-E0A9-E50E24DCCA9E` | Phone → Glasses (write) |
| RX Characteristic | `6E400003-B5A3-F393-E0A9-E50E24DCCA9E` | Glasses → Phone (notify) |

Standard Nordic UART Service (NUS). TX/RX named from the **peripheral's** perspective.

**Write type:** Python SDK uses write-with-response (`response=True`). Helix-iOS uses `.withoutResponse`. Both work — the glasses accept either.

**MTU:** Should be set to 251 via the `0x4D` init command. Max practical payload ~200 bytes.

---

## 2. Dual Glass Connection (Left / Right)

### Discovery
- Glasses advertise as **two separate BLE peripherals**
- Left glass: device name contains `_L_` (e.g., `Even_3A_L_xxxx`)
- Right glass: device name contains `_R_` (e.g., `Even_3A_R_xxxx`)
- Channel number between underscores (e.g., `3A`) pairs L and R into a logical device
- No service UUID filter needed during scan — match on device name

### Connection
- Both peripherals connected simultaneously
- Each has its own TX (write) and RX (notify) characteristic
- **Both glasses receive identical data** for display commands
- There is **no master/slave differentiation** for data writes
- Glasses relay data internally between L and R via ESB (Enhanced ShockBurst) channel

### Send Pattern (ALL implementations agree)
```
1. Send to Left glass first
2. Wait for ACK / delay
3. Send to Right glass
```

**Inter-glass delays:**
| Operation | Delay |
|-----------|-------|
| General commands | 100ms |
| Text packets | 400ms |
| Notification chunks | 100ms per chunk |
| Image/BMP | Full sequence to L, then full sequence to R |

### Transport Policy
Since glasses relay internally, **a single-side delivery is sufficient**. If only L or R is connected, commands sent to the available side will display on both lenses. Requiring both sides to succeed is overly strict and causes failures when one side's characteristic isn't ready.

### Initialization Sequence
After characteristic discovery, send: `[0x4D, 0x01]` (INIT command) to each side.

Full initialization: Firmware Request → Initialize (`0x4D 0xFB`) → Wear Detection (`0x27`) → Silent Mode (`0x03`)

---

## 3. Complete Command Byte Map

### Phone → Glasses (Outgoing)

| Byte | Command | Description |
|------|---------|-------------|
| `0x01` | BRIGHTNESS | Set display brightness. `[0x01, level(0-41), auto(0/1)]` |
| `0x03` | SILENT_MODE | `[0x03, 0x0A=OFF / 0x0C=ON, 0x00]` |
| `0x04` | WHITELIST | App notification whitelist (JSON) |
| `0x06` | DASHBOARD_SET | Set dashboard content (6 subcommands) |
| `0x0A` | NAVIGATION | Turn-by-turn nav. Subcmds: Init(0), Trip(1), Map(2), Panoramic(3), Sync(4), Exit(5), Arrived(6) |
| `0x0B` | HEADUP_ANGLE | `[0x0B, angle(0-60), 0x01]` |
| `0x0E` | MIC_CONTROL | `[0x0E, 0x01=enable / 0x00=disable]`. **Send to right side only for mic enable.** |
| `0x10` | HEAD_UP_CALIBRATION | Subcmds: Clear(01), Set(02) |
| `0x15` | BMP_DATA | Bitmap image data chunk |
| `0x16` | BMP_CRC | Bitmap CRC32 verification |
| `0x17` | UPGRADE_CONTROL | Firmware upgrade control |
| `0x18` | EXIT / CLEAR_SCREEN | Exit current function to dashboard |
| `0x1E` | NOTE_ADD | Add/update/delete quick note (1-4) |
| `0x20` | BMP_COMPLETE | Bitmap transfer complete signal `[0x20, 0x0D, 0x0E]` |
| `0x25` | HEARTBEAT | Keep-alive heartbeat (6 bytes) |
| `0x26` | HARDWARE_SET | Hardware settings (display height/depth, double-tap action, long-press, head-lift mic) |
| `0x27` | GLASSES_WEAR | Wear detection. `[0x27, 0x01=ON / 0x00=OFF]` |
| `0x2C` | BATTERY_QUERY | `[0x2C, type]` where type: Android=0x01, iOS=0x02 |
| `0x34` | GET_SN | Request serial number. Response bytes 2-17 = SN string |
| `0x35` | ESB_CHANNEL | ESB channel info between L/R lenses |
| `0x37` | TIME_SINCE_BOOT | Request uptime |
| `0x3B` | HARDWARE_DISPLAY_GET | Get screen height/depth values |
| `0x3C` | NOTIFICATION_AUTO_GET | Get notification auto-display settings |
| `0x3D` | LANGUAGE_SET | CN=01, EN=02, JP=03, FR=05, DE=06, ES=07, IT=0E |
| `0x3E` | BURIED_POINT_GET | Usage tracking data (JSON) |
| `0x47` | UNPAIR | Unpair glasses |
| `0x4B` | NOTIFICATION | NCS notification (chunked JSON) |
| `0x4C` | NOTIFICATION_CLEAR | Clear notification by msg_id |
| `0x4D` | INIT | Initialize/handshake `[0x4D, 0x01]` or `[0x4D, 0xFB]` |
| `0x4E` | SEND_RESULT | AI result / text display (multi-pack) |
| `0x4F` | NOTIFICATION_AUTO_SET | Set auto-display timeout (seconds) |
| `0x50` | DASHBOARD_POSITION | Show/hide dashboard overlay |
| `0x58` | CALENDAR_NEXT_UP | Calendar next-up display |
| `0xF4` | PUSH_SCREEN | Push screen by ID. `[0xF4, screenId]`. Response: `[0xF4, 0xC9]` |
| `0xF5` | AI_CONTROL | Clear screen/stop AI: `[0xF5, 0x18, 0x00, 0x00, 0x00]` |

### Glasses → Phone (Incoming Events)

| Byte | Command | Description |
|------|---------|-------------|
| `0x0E` | MIC_RESPONSE | `[0x0E, status(0xC9/0xCA), enable(0/1)]` |
| `0x22` | STATUS | Head-up trigger, unread count, low power, dashboard mode |
| `0xF1` | MIC_DATA | Audio data. `[0xF1, seq, ...LC3_audio_bytes]`. 200 bytes/packet, 30s max |
| `0xF5` | DEVICE_ORDER | Touchpad/gesture events (see §10) |

### Response Status Codes

| Code | Meaning |
|------|---------|
| `0xC9` | Success |
| `0xCA` | Failure |
| `0xCB` | Continue / Acceptable (used in BMP acks) |

---

## 4. Heartbeat Protocol (Command `0x25`)

```
Byte 0: 0x25  (HEARTBEAT)
Byte 1: 0x06  (length low byte)
Byte 2: 0x00  (length high byte)
Byte 3: seq   (sequence counter, wraps at 0xFF)
Byte 4: 0x04  (fixed heartbeat type)
Byte 5: seq   (sequence counter, repeated)
```

**Total:** 6 bytes fixed.

**Interval:** 5 seconds per glass.

**ACK validation:** Response `data[0] == 0x25` and `data[4] == 0x04`.

**Timeout:** 1500ms per side.

---

## 5. Text / AI Result Protocol (Command `0x4E`)

### Packet Layout

```
Offset  Size  Field           Description
------  ----  -----           -----------
0       1     command         0x4E (SEND_RESULT)
1       1     syncSeq         Sequence number (0-255, shared across packets in one message)
2       1     maxSeq          Total number of multi-packet chunks
3       1     seq             Current chunk index (0-based)
4       1     newScreen       Screen status (4-bit display style + 4-bit canvas state)
5       2     pos             Character position (big-endian int16)
7       1     currentPage     Current page number
8       1     maxPages        Total page count
9+      N     data            UTF-8 encoded text payload (max 191 bytes)
```

**Header:** 9 bytes. **Max payload:** 191 bytes per packet (bounded by BLE MTU ~200).

### Screen Status Byte (newScreen, byte 4)

Lower 4 bits = **Canvas State**, Upper 4 bits = **Display Style/Status**:

| Combined Value | Hex | Usage |
|----------------|-----|-------|
| AI streaming | `0x31` | `0x30 | 0x01` — AI content displaying, new canvas |
| AI complete | `0x40` | AI response complete (last page) |
| AI complete (new) | `0x41` | `0x40 | 0x01` — AI complete, new canvas |
| Manual mode | `0x51` | `0x50 | 0x01` — Manual page control |
| Network error | `0x61` | `0x60 | 0x01` — Network error state |
| Text show | `0x71` | `0x70 | 0x01` — Plain text display |

Canvas state: `0` = draw to existing canvas, `1` = new canvas.

### Text Formatting

| Parameter | Value |
|-----------|-------|
| Max display width | 488 pixels |
| Font size | 21pt |
| Max characters per line | ~40 (word-wrapped) |
| Max lines per page | 5 |
| Line separator | `\n` |
| Vertical centering | Pages with <5 lines are padded with empty strings |

### Multi-Page Send Flow

1. Format text into 5-line pages
2. Send first line with `page=1/N`, status `0x31` (displaying + new content)
3. Wait 100ms
4. For each page: send full 5-line content with status `0x30` (displaying)
5. After last page: re-send with status `0x40` (display complete)
6. Inter-page delay: configurable (default 5 seconds for auto-advance)

### Send Timing
- 400ms delay between L and R glass writes for text
- 100ms delay between initial packet and page packets

---

## 6. Bitmap / Image Protocol

### Display Spec
- **Resolution:** 576 × 136 pixels
- **Color depth:** 1-bit (monochrome)
- **Format:** BMP

### Commands

| Command | Byte | Purpose |
|---------|------|---------|
| BMP Data | `0x15` | Stream bitmap chunk |
| BMP CRC | `0x16` | CRC32 verification |
| BMP Complete | `0x20` | Transfer complete signal |

### BMP Data Packet (0x15)

**First chunk** (includes storage address):
```
Byte 0:    0x15          (BMP_DATA)
Byte 1:    0x00          (chunk index = 0)
Byte 2-5:  0x00 0x1C 0x00 0x00  (storage address: 0x001C0000)
Byte 6+:   data          (up to 194 bytes of BMP data)
```
Total first packet: up to 200 bytes.

**Subsequent chunks** (no storage address):
```
Byte 0:    0x15          (BMP_DATA)
Byte 1:    chunkIndex    (1, 2, 3, ...)
Byte 2+:   data          (up to 194 bytes)
```
Total: 2 + data_length bytes (max 196).

**Chunk size:** 194 bytes of BMP data per packet.

### Transfer Complete (0x20)
```
0x20, 0x0D, 0x0E
```
3 bytes, fixed. Sent after all data chunks.

### CRC32 Packet (0x16)
```
Byte 0:    0x16          (BMP_CRC)
Byte 1-4:  CRC32         (big-endian, 4 bytes)
```

### CRC32 Calculation
- **Input:** `storageAddress + fullBmpData` = `[0x00, 0x1C, 0x00, 0x00] + all_bmp_bytes`
- **Algorithm:** CRC-32/XZ (standard CRC-32, polynomial `0xEDB88320`)
- **Initial value:** `0xFFFFFFFF`, **final XOR:** `0xFFFFFFFF`
- **Output:** 4 bytes, big-endian

### ACK Response Codes
- Complete ack: `data[1] == 0xC9` (success) or `0xCB` (acceptable)
- CRC ack: `data[5] == 0xC9` or `0xCB` (6-byte response), or `data[1]` for short response

### Send Sequence (per side)
```
1. Stream all BMP data chunks (0x15) with inter-chunk delay
2. Send complete signal [0x20, 0x0D, 0x0E], wait for ACK
3. Send CRC packet [0x16, CRC_bytes], wait for ACK
```

**Order:** Complete full sequence to L, then complete full sequence to R. Not interleaved.

### Inter-Chunk Delays
- iOS: 8ms between chunks
- Other platforms: 5ms between chunks

### Delta/Incremental Updates
Helix supports sending only changed chunks (comparing new BMP against last-sent at 194-byte boundaries). Complete + CRC still use the full BMP data.

---

## 7. Notification Protocol (Command `0x4B`)

### Packet Layout
```
Byte 0:    0x4B          (NOTIFICATION)
Byte 1:    notifyId      (notification ID, typically 0x00)
Byte 2:    totalChunks   (total number of chunks)
Byte 3:    chunkIndex    (current chunk index, 0-based)
Byte 4+:   data          (JSON payload fragment, max 176 bytes)
```

**Max chunk payload:** 176 bytes (180 total - 4 byte header).

### JSON Payload
```json
{
  "ncs_notification": {
    "msg_id": 1,
    "type": 1,
    "app_identifier": "org.telegram.messenger",
    "title": "Title",
    "subtitle": "Subtitle",
    "message": "Body",
    "time_s": 1712345678,
    "date": "2026-04-05 12:34:56",
    "display_name": "App Name"
  },
  "type": "Add"
}
```

**Clear notification:** Command `0x4C` with matching `msg_id`.

**Auto-display settings:** `0x4F` (set) / `0x3C` (get) with timeout in seconds.

### Timing
- 10ms delay between chunks
- Each chunk to L, wait 100ms, then R, wait 100ms

---

## 8. Dashboard Commands

### Dashboard Position/Visibility (Command `0x26` / `0x50`)

```
Byte 0: 0x26
Byte 1: 0x07
Byte 2: 0x00
Byte 3: 0x01
Byte 4: 0x02
Byte 5: state     (0x01=ON, 0x00=OFF)
Byte 6: position  (0x00-0x08, bottom to top)
```

### Dashboard Set (Command `0x06`) — Subcommands

| Subcmd | Value | Content |
|--------|-------|---------|
| Time/Weather | `0x01` | Time display with weather info |
| Weather | `0x02` | Weather details |
| Calendar | `0x03` | Calendar events |
| Stock/Graph | `0x04` | Stock ticker graph |
| News | `0x05` | News headlines |
| Pane Mode | `0x06` | Dashboard pane mode |
| Map | `0x07` | Map display |

### Dashboard Modes
- Full (0) — single full-screen pane
- Dual (1) — two panes side by side
- Minimal (2) — minimal info bar

### Secondary Panes
- Notes (0), Stock (1), News (2), Calendar (3), Map (4)

### Weather Icon IDs
0x00=None, 0x01=Cloudy, 0x02=Drizzle, 0x03=Flurries, 0x04=HeavyRain, 0x05=HeavySnow, 0x06=LightRain, 0x07=LightSnow, 0x08=MostlyCloudy, 0x09=MostlySunny, 0x0A=PartlyCloudy, 0x0B=PartlySunny, 0x0C=Rainy, 0x0D=Sleet, 0x0E=Snowy, 0x0F=Thunderstorm, 0x10=Sunny

---

## 9. Hardware Settings (Command `0x26`)

### Subcommands

| Subcmd | Value | Description |
|--------|-------|-------------|
| Display Height/Depth | `0x02` | Adjust display position (with preview mode) |
| Double-Tap Action | `0x05` | Configure double-tap behavior |
| Long-Press | `0x07` | Configure long-press behavior |
| Head-Lift Mic | `0x08` | Enable/disable head-lift to activate mic |

---

## 10. Touchpad / Gesture Events (Command `0xF5`)

Received from glasses via RX characteristic notifications.

### Event Table (data[1] = subcmd)

| Subcmd | Hex | Event |
|--------|-----|-------|
| 0 | `0x00` | Double-tap / Exit to dashboard |
| 1 | `0x01` | Single-tap / Page control (L=back, R=forward) |
| 2 | `0x02` | Head-up gesture |
| 3 | `0x03` | Head-down gesture |
| 4 | `0x04` | Triple-tap left (silent mode toggle) |
| 5 | `0x05` | Triple-tap right |
| 6 | `0x06` | Glasses put on (wear detection) |
| 7 | `0x07` | Glasses taken off |
| 8 | `0x08` | In case, lid open |
| 9 | `0x09` | Charging |
| 10 | `0x0A` | Battery level (0-100 in data[2]) |
| 11 | `0x0B` | In case, lid closed, plugged in |
| 14 | `0x0E` | Case charging |
| 15 | `0x0F` | Case battery level |
| 17 | `0x11` | BLE paired |
| 18 | `0x12` | Right touchpad press/hold/release |
| 23 | `0x17` | Left touchpad press/hold (Even AI start) |
| 24 | `0x18` | Left touchpad release (Even AI recording over) |
| 30 | `0x1E` | Dashboard opened |
| 31 | `0x1F` | Dashboard closed |
| 32 | `0x20` | Double-tap for translate/transcribe |

---

## 11. Microphone / Audio Protocol

### Enable Mic (Command `0x0E`)
```
[0x0E, 0x01]  — Enable
[0x0E, 0x00]  — Disable
```
**Important:** Send mic enable to **right side only**.

### Mic Response
```
[0x0E, 0xC9, 0x01]  — Success, enabled
[0x0E, 0xCA, 0x00]  — Failure
```

### Audio Data (Command `0xF1`)
```
Byte 0:    0xF1          (MIC_DATA)
Byte 1:    seq           (sequence number for ordering)
Byte 2+:   audioData     (LC3-encoded audio)
```
- **Codec:** LC3
- **Packet size:** 200 bytes
- **Max recording:** 30 seconds
- Separate sequence counter (not global)

---

## 12. Quick Notes (Command `0x1E`)

### Add/Update Note
```
Byte 0:    0x1E
Byte 1:    payload_len & 0xFF
Byte 2:    0x00
Byte 3:    time() % 256    (versioning)
Byte 4:    0x03
Byte 5:    0x01
Byte 6:    0x00
Byte 7:    0x01
Byte 8:    0x00
Byte 9:    note_number     (1-4)
Byte 10:   0x01
Byte 11:   title_len
Byte 12+:  title (UTF-8)
...        text_len
...        0x00
...        text (UTF-8)
```

### Delete Note
Fixed 16-byte packet:
```
0x1E, 0x10, 0x00, 0xE0, 0x03, 0x01, 0x00, 0x01,
0x00, <note_number>, 0x00, 0x01, 0x00, 0x01, 0x00, 0x00
```

---

## 13. Serial Number Decoding

Request: `[0x34]`. Response bytes 2-17 = SN string.

### Frame Shape Codes
- S100 = Round
- S110 = Square

### Color Codes
- LAA = Grey
- LBB = Brown
- LCC = Green

---

## 14. Charging Case Serial Protocol

Via CH34x USB-serial chip at **115200 baud**.

Monitors:
- Case battery: voltage (mV) + percentage
- L/R glass battery levels
- VRECT charging voltage
- Charging current
- USB/lid/charge state
- NFC IC temperatures
- Battery temperature

Data format examples:
```
box bat: 4250 mV, 90%
NFC1:[3254900] Get data:01 02 30 63, Rx VRECT: 560mV, Battery Level: 99%
usb:01, lid:01, charge:02
NFC IC0:30, NFC IC1:32, Bat:27
RX BatLevel--L:99%, R:2%, bat:2
WLC State: WLC_STATE_STATIC (4)
```

---

## 15. Error Handling & Reconnection

### Timeouts

| Operation | Timeout |
|-----------|---------|
| BLE connection | 15s |
| Scan per attempt | 30s |
| Heartbeat response | 1500ms/side |
| AI data send | 2000ms |
| Push screen | 300ms |
| Notification send | 1000ms (up to 6 retries) |
| BMP complete/CRC ack | ≥1000ms |
| BMP dashboard transfers | 500ms/chunk |

### Reconnection
- Python SDK: 3 retries, 5s fixed backoff
- Helix-iOS: Up to 10 automatic reconnect attempts
- User-initiated disconnects skip reconnection

### Write Protection
- Serialize writes per glass (lock/mutex)
- Check connection before every write
- Catch and log write failures

---

## 16. Ecosystem Project Catalog

### Tier 1: Protocol Documentation
| Project | Key Contribution |
|---------|-----------------|
| `JohnRThomas/EvenDemoApp` wiki | **Most comprehensive BLE protocol reference** (~990 lines, community RE) |
| `even-realities/EvenDemoApp` | Official Android reference implementation |

### Tier 2: Libraries & SDKs
| Project | Language | Stars | Notes |
|---------|----------|-------|-------|
| `emingenc/even_glasses` | Python | 77 | Most widely-used community library |
| `emingenc/even_realities_g1` | Dart/Flutter | 3 | Most complete Flutter lib with BLE_PROTOCOL.md |
| `emingenc/g1_flutter_blue_plus` | Flutter | 18 | Basic Flutter BLE wrapper |
| `binarythinktank/eveng1_python_sdk` | Python | 39 | Clean SDK with state management |
| `lohmuller/even-g1-java-sdk` | Java | 3 | Clean command/response tables |
| `rodrigofalvarez/g1-basis-android` | Kotlin | 18 | Shared Android service (AIDL) for multi-app |

### Tier 3: Complete Applications
| Project | Language | Stars | Features |
|---------|----------|-------|----------|
| `meyskens/fahrplan` | Flutter | 46 | Life assistant: notifications, calendar, weather, voice, timers |
| `AugmentOS-Community/AugmentOS` | TypeScript/RN | — | Smart glasses OS with app store |
| `Hendrik-mc/g1-whisper` | Kotlin/Compose | 1 | Android companion with 5 AI widgets |
| `emingenc/G1_voice_ai_assistant` | Python | 25 | Real-time emotional AI conversation |

### Tier 4: MentraOS Cloud Apps
| Project | Key Feature |
|---------|-------------|
| `ThatChocolateGuy/nametag` | Voice biometric recognition |
| `GeauxAi-Labs/GeauxAiPrompt` | Always-on voice AI with web search |
| `fractal-nyc/context-clairvoyant` | Proactive Q&A from conversation |
| `drewomix/jarvi` | BAML-powered intelligent routing |
| `owensantoso/AR-spotify-lyrics` | Synced lyrics with CJK romanization |

### Tier 5: Utilities
| Project | Key Contribution |
|---------|-----------------|
| `razem-io/SerialLens` | Charging case serial protocol documentation |
| `hqrrr/EvenComfort` | Environmental quality display |
| `NyasakiAT/G1-Navigate` | BMP composing code for Flutter |
| `callbacked/Aludra` | Ollama AI integration (EvenDemoApp fork) |

---

## 17. AugmentOS Architecture Insights

AugmentOS (`AugmentOS-Community/AugmentOS`) uses a **cloud-first relay** model vs Helix's on-device approach:

```
AugmentOS: Cloud AI → WebSocket → Mobile (relay) → BLE → Glasses
Helix:     Phone AI → ConversationEngine → HudController → BLE → Glasses
```

### Key AugmentOS Patterns Worth Noting

| Pattern | AugmentOS | Potential for Helix |
|---------|-----------|---------------------|
| Command queue | Swift actors (`CommandQueue`, `AckManager`) | Could replace DispatchQueue approach |
| L/R parallel send | `withTaskGroup` for independent L/R retry | More resilient than sequential |
| ACK tracking | Per-command key with 300ms + 200ms/retry timeout | More granular than current approach |
| Write mode | `.withResponse` for final chunk, `.withoutResponse` for intermediate | Hybrid approach for speed + reliability |
| Heartbeat | 20 seconds (not 5) | Less BLE traffic |
| Inter-chunk delay | 16ms between chunks, 8ms between sends | Compare with our 5-8ms |
| Pixel inversion | BMP pixels inverted before sending | Verify Helix does this |
| Reconnection | Both sides cleared on single-side disconnect | More aggressive reset |
| Battery check | Piggybacked on every 10th heartbeat | Efficient polling |

### Display Profile (from `display-utils`)
- Display width: 576px physical, **488px usable** for text
- **5 lines** max
- Custom glyph-based font with pixel-accurate width tables
- Formula: rendered width = `(glyphWidth + 1) * 2`
- Space: 6px, Hyphen: 10px rendered

### Touchpad Mapping Differences
| Event | AugmentOS `0xF5` data[1] | Helix `notifyIndex` |
|-------|--------------------------|---------------------|
| AI trigger | `0x17` | 23 (same) |
| Stop recording | `0x18` | 24 (same) |
| Page change | `0x01` | 1 (same) |
| Head up | `0x02` / `0x1E` | 2 (same) |
| Head down | `0x03` | 3 (same) |
| Double tap | `0x20` | 0 (different mapping) |
| Dashboard open | N/A | 30 / `0x1E` |
| Dashboard close | N/A | 31 / `0x1F` |

---

## 18. Comparison with Helix-iOS

### Matches (Confirmed Across ALL Implementations)
- BLE UUIDs: ✅ Identical (Nordic UART Service)
- Storage address `0x001C0000`: ✅ Identical
- BMP chunk size 194 bytes: ✅ Identical
- Complete signal `[0x20, 0x0D, 0x0E]`: ✅ Identical
- CRC-32/XZ over address+data: ✅ Identical
- Text `0x4E` 9-byte header format: ✅ Identical
- Screen status codes `0x30/0x40/0x70`: ✅ Identical
- Mic enable to right side only: ✅ Confirmed by AugmentOS
- Both glasses receive identical data: ✅ Confirmed by ALL implementations
- Single-side delivery sufficient: ✅ Confirmed (internal ESB relay)

### Differences to Investigate

| Area | Reference Implementations | Helix-iOS | Priority |
|------|--------------------------|-----------|----------|
| Write type | Python: with-response; AugmentOS: hybrid | Without response | Medium |
| Inter-glass delay (text) | 400ms (Python), parallel (AugmentOS) | Varies | Low |
| Heartbeat frequency | 5s (Python) / 20s (AugmentOS) | Check timer | Low |
| Heartbeat format | Python: 6 bytes; AugmentOS: 2 bytes `[0x25, counter]` | 6 bytes | Check |
| Init command | `[0x4D, 0x01]` (basic) vs `[0x4D, 0xFB]` (full) | `[0x4D, 0x01]` | Low |
| BMP pixel inversion | AugmentOS inverts pixels after 62-byte header | Check if Helix does this | **High** |
| BMP resolution | 576×135 (AugmentOS) vs 576×136 (Python) | Check actual | Medium |
| Text chunk max | 176 bytes (AugmentOS) vs 191 bytes (Helix) | Check MTU | Medium |
| Mic enable target | Right side only (confirmed) | Check current impl | **High** |
| Reconnect on partial disconnect | AugmentOS: clear BOTH sides | Check behavior | Medium |
| Notification auto-display | `0x4F`/`0x3C` commands | Not implemented? | Low |
| Navigation protocol | `0x0A` with 7 subcmds | Not implemented | Low |
| Quick notes | `0x1E` add/delete | Not implemented | Low |
| Battery query | `0x2C` with iOS type `0x02` | Check impl | Low |
| Dashboard set | `0x06` with 7 subcmds | Check impl | Low |
