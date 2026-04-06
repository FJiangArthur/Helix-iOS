# Even Realities G1 — Implementation Protocol Reference

> Cross-referenced from JohnRThomas/EvenDemoApp wiki (990 lines, community RE),
> emingenc/even_glasses Python SDK, emingenc/g1_flutter_blue_plus Flutter SDK,
> AugmentOS-Community/AugmentOS iOS native module, even-realities/EvenDemoApp
> official Android app, lohmuller/even-g1-java-sdk, and binarythinktank/eveng1_python_sdk.
>
> **Verified fields** are marked ✅ (confirmed across 2+ independent sources).
> **Wiki-only fields** are marked 📋 (from reverse engineering, single source).
>
> Date: 2026-04-05

---

## 1. BLE Transport Layer

### 1.1 Nordic UART Service (NUS)

| Role | UUID | Direction |
|------|------|-----------|
| Service | `6E400001-B5A3-F393-E0A9-E50E24DCCA9E` ✅ | — |
| TX Char | `6E400002-B5A3-F393-E0A9-E50E24DCCA9E` ✅ | Phone → Glasses (write) |
| RX Char | `6E400003-B5A3-F393-E0A9-E50E24DCCA9E` ✅ | Glasses → Phone (notify) |

TX/RX named from **peripheral** perspective. Phone writes to TX, subscribes to RX.

### 1.2 MTU Configuration

| Command | Byte | Payload | Target |
|---------|------|---------|--------|
| MTU Set | `0x4D` | `0xFB` (251) | **Both** sides ✅ |

Wiki: "Sets the Device BLE MTU value. This should match the setting requested from the host OS ble stack, but never exceed 251."

Response: Generic `[0x4D, 0xC9]` = success. ✅

### 1.3 Dual Glass Communication Model

- Glasses advertise as **two separate BLE peripherals** ✅
- Left: device name contains `_L_` ✅ | Right: contains `_R_` ✅
- Channel number between underscores pairs L/R (e.g., `Even_3A_L_xxxx`) ✅
- L/R lenses communicate internally via **Nordic ESB** (Enhanced ShockBurst) 📋
- ESB channel queryable via command `0x35` 📋

### 1.4 Which Side to Send Commands To

**Critical: not all commands go to both sides.** The wiki documents per-command targeting:

| Target | Commands |
|--------|----------|
| **Both** sides | `0x03` (silent), `0x08` (head-up action), `0x0B`¹ (angle), `0x27` (wear), `0x47` (unpair), `0x17` (upgrade), `0x4D` (MTU), `0x4E` (text), `0x4F` (notif auto), `0x50` (unknown) |
| **Left** only | `0x04` (notif app list), `0x0E` (mic enable)², `0x4B` (notification send), `0x4C` (notif clear), `0x3C` (notif auto get) |
| **Right** only | `0x01` (brightness set), `0x29` (brightness get), `0x3B` (display get), `0x32` (angle get) |
| **Either** side | `0x3A` (wear detection get) |

¹ Wiki says send to Right only for `0x0B`; AugmentOS sends to both.
² Wiki says Left; AugmentOS and Python SDK say Right. **Discrepancy — test both.**

### 1.5 Generic Command Response

Most commands respond with this format: ✅

| Command Echo | Status |
|-------------|--------|
| `XX` | `C9` = Success, `CA` = Failure, `CB` = Continue |

### 1.6 Write Type

| Implementation | Write Type |
|----------------|-----------|
| Python SDK (even_glasses) | `response=True` (write with response) |
| AugmentOS | Hybrid: `.withResponse` for final chunk, `.withoutResponse` for intermediate |
| Helix-iOS | `.withoutResponse` for all |
| Wiki | Not specified |

All approaches work. Hybrid (AugmentOS) is most robust.

---

## 2. Initialization Sequence

Per Java SDK and wiki, the initialization flow is:

```
1. Connect L and R peripherals
2. Discover UART service + characteristics for both
3. Subscribe to RX characteristic notifications on both
4. Send MTU Set [0x4D, 0xFB] to Both → wait for ACK
5. (Optional) Send [0x4D, 0x01] as simple init to Both
6. Send Wear Detection [0x27, 0x01] to Both
7. Send Silent Mode Off [0x03, 0x0A] to Both (or query current)
8. Send Heartbeat to start keepalive cycle
```

AugmentOS: Both sides must ACK init before `fullyBooted = true`. ✅

---

## 3. Heartbeat Protocol (0x25) ✅

### Packet Format (Python SDK / Helix-iOS)

```
Byte 0: 0x25  (HEARTBEAT)
Byte 1: 0x06  (length low)
Byte 2: 0x00  (length high)
Byte 3: seq   (0x00-0xFF, wrapping)
Byte 4: 0x04  (fixed type)
Byte 5: seq   (repeated)
```
Total: 6 bytes. ✅

### Alternative Format (AugmentOS)

```
Byte 0: 0x25
Byte 1: counter
```
Total: 2 bytes. Response: `[0x25, counter-1]`.

### Timing

| Source | Interval |
|--------|----------|
| Python SDK | 5 seconds ✅ |
| AugmentOS | 20 seconds |

### ACK Validation (Python SDK)

Response: `data[0] == 0x25` and `data[4] == 0x04`. ✅
Timeout: 1500ms per side. ✅

---

## 4. Text / AI Result Display (0x4E) ✅

**Target:** Send to **Both** sides. ✅

### 4.1 Packet Layout

Wiki format (most precise):

```
Byte 0:     0x4E        Command
Byte 1:     XX          Packet size
Byte 2:     00-FF       Sequence (global)
Byte 3:     01-FF       Chunk count (total packets for this message)
Byte 4:     00          Pad
Byte 5:     01-FF       Chunk index (1-based per wiki, 0-based per SDK)
Byte 6:     00          Pad
Byte 7:     X           Display Style (upper 4 bits of status byte)
            X           Canvas State (lower 4 bits of status byte)
Byte 8-9:   XX XX       Character position (2 bytes)
Byte 10:    XX          Page number
Byte 11:    XX          Page count
Byte 12+:   UTF-8       Text payload
```

**Note:** The wiki describes bytes 7 as two 4-bit fields sharing one byte. The Python/Flutter SDKs pack this as a single `screenStatus` byte where upper nibble = display style, lower nibble = canvas state. These are equivalent representations.

Helix-iOS / Python SDK simplified format (9-byte header):

```
Byte 0: 0x4E   command
Byte 1: seq     syncSeq (0-255)
Byte 2: maxSeq  total packets
Byte 3: seq     current packet (0-based)
Byte 4: status  display style (upper 4) | canvas state (lower 4)
Byte 5: pos_hi  character position high byte
Byte 6: pos_lo  character position low byte
Byte 7: page    current page number
Byte 8: pages   total page count
Byte 9+: data   UTF-8 text (max 191 bytes)
```

### 4.2 Display Style (Upper 4 Bits) ✅

| Value | Hex (combined w/ canvas=1) | Description | Source |
|-------|---------------------------|-------------|--------|
| 0 | `0x01` | Unknown | Wiki |
| 1 | `0x11` | Unknown | Wiki |
| 2 | `0x21` | Unknown | Wiki |
| 3 | `0x31` | Even AI displaying / Auto Scroll | Wiki ✅ All SDKs |
| 4 | `0x41` | Even AI Complete | Wiki ✅ All SDKs |
| 5 | `0x51` | Even AI Manual Scroll | Wiki ✅ AugmentOS |
| 6 | `0x61` | Even AI Network Error | Wiki ✅ Python SDK |
| 7 | `0x71` | Show Text Only (no AI context) | Wiki ✅ All SDKs |

### 4.3 Canvas State (Lower 4 Bits) ✅

| Value | Description |
|-------|-------------|
| `0` | Draw to existing canvas |
| `1` | Start new canvas |

### 4.4 Text Formatting Constraints ✅

| Parameter | Value | Source |
|-----------|-------|--------|
| Max display width | 576px physical, **488px** usable | AugmentOS display profile ✅ |
| Font size | 21pt | Official EvenDemoApp ✅ |
| Max lines per page | **5** | All sources ✅ |
| Max chars per line | ~40 (depends on char width) | Python SDK ✅ |
| Line separator | `\n` | All sources ✅ |
| Vertical centering | Pages with <5 lines padded with empty strings | Python SDK ✅ |

### 4.5 Multi-Page Send Flow ✅

```
1. Format text into 5-line pages
2. First packet: first line, page=1/N, status=0x31 (AI displaying + new canvas)
3. Wait 100ms
4. Each page: full 5-line content, status=0x30 (AI displaying, existing canvas)
5. Last page: re-send with status=0x40 (AI complete)
6. Inter-page delay: configurable (default 5s for auto-advance)
```

### 4.6 Send Timing

| Operation | Delay | Source |
|-----------|-------|--------|
| Between L and R writes | 400ms | Python SDK |
| Between initial and page packets | 100ms | Python SDK ✅ |
| Between pages (auto-advance) | 5s default | Python SDK ✅ |
| Max payload per BLE packet | 176 bytes (AugmentOS) / 191 bytes (Helix) | Varies by MTU |

---

## 5. Bitmap / Image Protocol ✅

### 5.1 Display Specifications

| Parameter | Value | Source |
|-----------|-------|--------|
| Resolution | 576 × 136 pixels | Python SDK (AugmentOS says 576×135) |
| Color depth | 1-bit monochrome | All sources ✅ |
| Format | BMP | All sources ✅ |
| Pixel inversion | Required (AugmentOS: invert after 62-byte header) | AugmentOS |

### 5.2 File Upload / BMP Data (0x15) ✅

**First chunk** (includes storage address):
```
Byte 0:    0x15          BMP_DATA command ✅
Byte 1:    0x00          Chunk index = 0 ✅
Byte 2-5:  0x00 0x1C 0x00 0x00  Storage address (0x001C0000) ✅
Byte 6+:   data          Up to 194 bytes of BMP data ✅
```
Total first packet: up to 200 bytes.

**Subsequent chunks:**
```
Byte 0:    0x15          BMP_DATA command
Byte 1:    chunkIndex    (1, 2, 3, ...)
Byte 2+:   data          Up to 194 bytes
```
Total: 2 + data_length (max 196).

**Chunk size:** 194 bytes ✅

### 5.3 File Upload Complete (0x20) ✅

```
0x20, 0x0D, 0x0E
```
3 bytes, fixed. Wiki: "Also used to upgrade a font, it seems." 📋

### 5.4 Bitmap Show / CRC Check (0x16) ✅

```
Byte 0:    0x16          CRC command
Byte 1-4:  CRC32         Big-endian, 4 bytes
```

Wiki: "Shows a previously uploaded file as a bitmap on the screen. The image file must be uploaded before it can be displayed."

Wiki also shows: `[0x16, 0x0D, 0x0E]` as File ID — the `0x0D 0x0E` matches the complete signal.

### 5.5 CRC32 Calculation ✅

- **Input:** `[0x00, 0x1C, 0x00, 0x00] + all_bmp_bytes` (storage address + data)
- **Algorithm:** CRC-32/XZ ✅
  - Polynomial: `0x04C11DB7` (normal form) / `0xEDB88320` (reflected)
  - Init: `0xFFFFFFFF`, Final XOR: `0xFFFFFFFF`
- **Output:** 4 bytes, big-endian

Wiki confirms: "The crc value is calculated using Crc32Xz big endian, combined with the bmp picture storage address and picture data." ✅

### 5.6 Bitmap Hide / Clear Screen (0x18) ✅

```
0x18
```
Single byte. Wiki: "Clears the screen of bitmaps. Also clears text?" 📋

### 5.7 ACK Response Codes ✅

| Response | Meaning |
|----------|---------|
| `data[1] == 0xC9` | Complete ack success |
| `data[1] == 0xCB` | Complete ack acceptable |
| `data[5] == 0xC9` | CRC ack success (6-byte response) |
| `data[5] == 0xCB` | CRC ack acceptable (6-byte response) |

### 5.8 Send Sequence ✅

```
Per side (L first, then R — NOT interleaved):
  1. Stream all BMP data chunks (0x15) with 5-8ms inter-chunk delay
  2. Send complete [0x20, 0x0D, 0x0E], wait for ACK (≥1000ms timeout)
  3. Send CRC [0x16, CRC bytes], wait for ACK (≥1000ms timeout)
```

### 5.9 Inter-Chunk Delays

| Platform | Delay | Source |
|----------|-------|--------|
| iOS | 8ms | Helix ✅ |
| AugmentOS | 16ms between chunks, 8ms between sends | AugmentOS |
| Other | 5ms | Helix default |

---

## 6. Notification Protocol (0x4B) ✅

**Target:** Send to **Left** side only. ✅ (Wiki + Python SDK confirmed)

### 6.1 Packet Layout

Wiki format:

```
Byte 0:    0x4B          NOTIFICATION command
Byte 1:    0x00          Pad
Byte 2:    01-FF         Chunk count (total)
Byte 3:    00-FF         Chunk index (0-based)
Byte 4+:   JSON          Payload (max 180 bytes per chunk)
```

Wiki: "Wait for a C9 (success) response before sending the next chunk." 📋

### 6.2 JSON Payload ✅

```json
{
  "ncs_notification": {
    "msg_id": 16,
    "action": 0,
    "app_identifier": "com.example.app",
    "title": "Title",
    "subtitle": "",
    "message": "Body text",
    "time_s": 1749606217,
    "date": "2025-06-10 18:43:37",
    "display_name": "App Name"
  }
}
```

### 6.3 Notification Clear (0x4C) 📋

**Target:** Send to **Left** side only.

```
Byte 0:    0x4C
Byte 1-4:  msg_id        32-bit, matching the msg_id from 0x4B
```

### 6.4 Notification App List (0x04)

**Target:** Send to **Left** side only. 📋

```
Byte 0:    0x04
Byte 1:    chunk_count
Byte 2:    chunk_index
Byte 3+:   JSON (max 180 bytes)
```

JSON structure:
```json
{
  "calendar_enable": true,
  "Call_enable": true,
  "Msg_enable": true,
  "Ios_mail_enable": true,
  "app": {
    "List": [{"id": "com.app", "name": "App Name"}],
    "enable": true
  }
}
```

### 6.5 Notification Auto Display (0x4F / 0x3C) 📋

**Set (0x4F):** Send to **Both** sides.
```
Byte 0: 0x4F
Byte 1: 0x00/0x01  (disable/enable)
Byte 2: 0x00-0xFF  (timeout in seconds)
```

**Get (0x3C):** Send to **Left** side.
```
Byte 0: 0x3C
```
Response: `[0x3C, 0xC9, enabled, timeout]`

---

## 7. Dashboard Protocol (0x06) 📋

**Target:** Varies per subcommand. The outer frame:

```
Byte 0: 0x06   Command
Byte 1: XX     Length (full packet including header)
Byte 2: 0x00   Pad
Byte 3: XX     Sequence (0x00-0xFF)
Byte 4+:       Subcommand payload
```

### Response format:
```
[0x06, req_length, 0x00, seq, subcmd, chunk_count, 0x00, chunk, 0x00, success(0/1)]
```

### 7.1 Time and Weather (Subcmd 0x01)

```
Length: 0x16 (22 bytes total)

Byte 4:    0x01          Subcommand
Byte 5-8:  XX XX XX XX   Epoch time 32-bit (seconds)
Byte 9-16: XX XX XX XX XX XX XX XX  Epoch time 64-bit (ms)
Byte 17:   01-10         Weather icon ID
Byte 18:   XX            Temperature (°C, signed)
Byte 19:   00/01         C=0 / F=1
Byte 20:   00/01         24H=0 / 12H=1
Byte 21:   00            Unknown
```

### 7.2 Weather Icons

| ID | Icon | | ID | Icon |
|----|------|-|----|------|
| `00` | None | | `09` | Snow |
| `01` | Night | | `0A` | Mist |
| `02` | Clouds | | `0B` | Fog |
| `03` | Drizzle | | `0C` | Sand |
| `04` | Heavy Drizzle | | `0D` | Squalls |
| `05` | Rain | | `0E` | Tornado |
| `06` | Heavy Rain | | `0F` | Freezing |
| `07` | Thunder | | `10` | Sunny |
| `08` | Thunder Storm | | `11+` | Error |

### 7.3 Weather Only (Subcmd 0x02) 📋

```
Length: 0x08
Byte 4: 0x02   Subcommand
Byte 5: 01-10  Weather icon ID
Byte 6: XX     Temperature °C
Byte 7: 00/01  C=0 / F=1
```

### 7.4 Pane Calendar (Subcmd 0x03) 📋

```
Byte 4: 0x03         Subcommand
Byte 5: 01-FF        Chunk count
Byte 6: 0x00         Pad
Byte 7: 01-FF        Chunk index (⚠ 1-based, not 0!)
Byte 8: 0x00         Pad
Byte 9: 0x01 0x03 0x03  Fixed magic
Byte 12: XX          Number of events
Byte 13+:            Event entries
```

Each event = 3 length-prefixed ASCII strings:
```
[0x01, len, title_bytes..., 0x02, len, time_bytes..., 0x03, len, location_bytes...]
```

Layout on display:
```
| Title (01)              |
| Time (02) | Location (03) |
```

### 7.5 Pane Stock/Graph (Subcmd 0x04) 📋

Chunked format, details TODO in wiki.

### 7.6 Pane News (Subcmd 0x05) 📋

Chunked format, details TODO in wiki.

### 7.7 Pane Mode (Subcmd 0x06) ✅

```
Length: 0x07
Byte 4: 0x06   Subcommand
Byte 5: 00-02  Dashboard mode
Byte 6: 00-05  Secondary pane ID
```

**Dashboard Modes:**
| ID | Mode |
|----|------|
| `00` | Full |
| `01` | Dual |
| `02` | Minimal |

**Secondary Pane IDs** (Full/Dual mode only):
| ID | Pane |
|----|------|
| `00` | Notes |
| `01` | Stock (graph) |
| `02` | News |
| `03` | Calendar |
| `04` | Map |
| `05+` | Empty |

### 7.8 Pane Map (Subcmd 0x07) 📋

Chunked format, details TODO in wiki.

---

## 8. Dashboard Layout / Hardware Display (0x26) 📋

### Response format:
```
[0x26, 0x06, 0x00, seq, subcmd, 0xC9/0xCA]
```

### 8.1 Subcommands

| Subcmd | Description | Source |
|--------|-------------|--------|
| `0x01` | Set something to 1 | Wiki 📋 |
| `0x02` | Display height and depth | Wiki 📋 |
| `0x03` | give mic_transm_sem | Wiki 📋 |
| `0x04` | ble set lum gear | Wiki 📋 |
| `0x05` | Double tap action | Wiki 📋 |
| `0x06` | ble set lum coeffic | Wiki 📋 |
| `0x07` | Long press enable/disable | Wiki 📋 |
| `0x08` | Mic on head lift | Wiki 📋 |

### 8.2 Height and Depth (Subcmd 0x02) 📋

**⚠ Requires TWO calls:** first with preview=1, then preview=0 after a few seconds.
Glasses stay on permanently until preview=0 is sent.

```
Byte 0: 0x26
Byte 1: 0x08   Packet size
Byte 2: 0x00   Pad
Byte 3: XX     Sequence
Byte 4: 0x02   Subcommand
Byte 5: 00/01  Preview (1=preview, 0=commit)
Byte 6: 00-08  Height
Byte 7: 01-09  Depth
```

### 8.3 Double Tap Action (Subcmd 0x05, packet byte 0x04) 📋

⚠ Wiki notes discrepancy: subcommand table says 0x05, but packet format uses byte `0x04`.

```
Byte 0: 0x26
Byte 1: 0x06
Byte 2: 0x00
Byte 3: XX     Sequence
Byte 4: 0x04   Subcommand byte in packet
Byte 5: XX     Action ID
```

**Actions:**
| ID | Action |
|----|--------|
| `0x00` | None (close active feature) |
| `0x02` | Open Translate |
| `0x03` | Open Teleprompter |
| `0x04` | Show Dashboard |
| `0x05` | Open Transcribe |

### 8.4 Long Press (Subcmd 0x07) 📋

```
Byte 4: 0x07   Subcommand
Byte 5: 00/01  Disabled/Enabled
```

### 8.5 Mic on Head Lift (Subcmd 0x08) 📋

⚠ **Values are inverted:** `0x01` = enabled, `0x00` = disabled.

```
Byte 4: 0x08   Subcommand
Byte 5: 01/00  Enable/Disable (inverted!)
```

---

## 9. Touchpad / Gesture Events (0xF5) ✅

Received on RX characteristic. Format: `[0xF5, subcmd, ...payload]`

### Complete Event Table (Wiki + AugmentOS cross-referenced)

| Subcmd | Hex | Event | Payload | Source |
|--------|-----|-------|---------|--------|
| 0 | `0x00` | Double-tap touchpad | — | Wiki ✅ |
| 1 | `0x01` | Single-tap (page change) | — | Wiki ✅ |
| 2 | `0x02` | Head up | — | Wiki ✅ |
| 3 | `0x03` | Head down | — | Wiki ✅ |
| 4 | `0x04` | Triple-tap (left?) | — | Wiki |
| 5 | `0x05` | Triple-tap (right?) | — | Wiki |
| 6 | `0x06` | Glasses worn | — | Wiki ✅ |
| 7 | `0x07` | Not worn / not in case | — | Wiki ✅ |
| 8 | `0x08` | In case, lid open | — | Wiki ✅ |
| 9 | `0x09` | Glasses side charging | `00/01` | Wiki ✅ |
| 10 | `0x0A` | Glasses battery level | `00-64` (%) | Wiki ✅ |
| 11 | `0x0B` | In case, lid closed, plugged in | — | Wiki ✅ |
| 12 | `0x0C` | Unknown | — | Wiki |
| 13 | `0x0D` | Unknown | — | Wiki |
| 14 | `0x0E` | Case charging | `00/01` | Wiki ✅ |
| 15 | `0x0F` | Case battery level | `00-64` (%) | Wiki ✅ |
| 16 | `0x10` | Unknown | — | Wiki |
| 17 | `0x11` | BLE paired success? | — | Wiki |
| 18 | `0x12` | Right touchpad press/hold/release | — | Wiki |
| 23 | `0x17` | Left touchpad press+hold (Even AI start) | — | Wiki ✅ |
| 24 | `0x18` | Left touchpad released (recording over) | — | Wiki ✅ |
| 25-29 | `0x19-0x1D` | Unknown | — | Wiki |
| 30 | `0x1E` | Dashboard opened (double tap) | — | Wiki ✅ |
| 31 | `0x1F` | Dashboard closed (double tap) | — | Wiki |
| 32 | `0x20` | Double tap for translate/transcribe | — | Wiki ✅ |

---

## 10. Status Messages (0x22) 📋

Glasses → Phone, sent on head-up events.

### Variant 1: Head-up (10 bytes)

```
Byte 0: 0x22   Command
Byte 1: 0x0A   Size (10)
Byte 2: 0x00   Unknown
Byte 3: 0x00   Unknown
Byte 4: 0x01   Event type
Byte 5: 00-FF  Num unread notifications
Byte 6: 00/01  Low power flag
Byte 7: 00-02  Dashboard mode (Full/Dual/Minimal)
Byte 8: 00-05  Pane mode
Byte 9: 01-04  Pane page number
```

### Variant 2: Right-tap while looking up (8 bytes)

```
Byte 0: 0x22   Command
Byte 1: 0x08   Size (8)
Byte 2: 0x00   Unknown
Byte 3: 0x00   Unknown
Byte 4: 0x02   Event type
Byte 5: 00-02  Dashboard mode
Byte 6: 00-05  Pane mode
Byte 7: 01-04  Pane page number
```

---

## 11. Microphone / Audio Protocol

### 11.1 Mic Enable (0x0E) ✅

**Target:** ⚠ **Disputed.** Wiki says **Left** only. AugmentOS says **Right** only. Test both.

```
[0x0E, 0x01]  Enable
[0x0E, 0x00]  Disable
```

Response: Generic `[0x0E, 0xC9/0xCA]`

### 11.2 Audio Data (0xF1) ✅

```
Byte 0: 0xF1   MIC_DATA command
Byte 1: seq    Audio sequence (separate from global, resets on mic toggle)
Byte 2+:       LC3 audio data
```

- Packet size: ~200 bytes ✅
- Codec: LC3 ✅
- Max recording: 30 seconds (official app limit) ✅
- Audio sequence is **independent** from global sequence 📋

### 11.3 Head-Up Action (0x08) 📋

**Target:** Send to **Both** sides.

```
Byte 0: 0x08
Byte 1: 0x06   Packet size
Byte 2: 0x00   Pad
Byte 3: XX     Sequence
Byte 4: 03/04  Local(03) / Global(04)
Byte 5: XX     Action
```

| Action | Description |
|--------|-------------|
| `0x00` | Show Dashboard |
| `0x02` | Do Nothing |

Wiki: "If Local/Global is set to 03, the command can be sent to just the left and left will forward to the right. If set to 04, the command sends to both." 📋

---

## 12. Settings Commands

### 12.1 Brightness Set (0x01) ✅

**Target:** Send to **Right** side only. 📋

```
Byte 0: 0x01
Byte 1: 0x00-0x2A  Brightness level (0-42)
Byte 2: 0x00/0x01  Manual/Auto
```

### 12.2 Brightness Get (0x29) 📋

**Target:** Send to **Right** side only.

```
Send: [0x29]
Response: [0x29, 0x65, brightness, auto_enabled]
```

### 12.3 Silent Mode Set (0x03) ✅

**Target:** Send to **Both** sides.

```
[0x03, 0x0C]  Silent ON  (not 0x01!)
[0x03, 0x0A]  Silent OFF (not 0x00!)
```

### 12.4 Silent Mode Get (0x2B) 📋

**Target:** Send to **Both** sides.

```
Send: [0x2B]
Response: [0x2B, 0x69, silent_enabled(0x0C/0x0A), state_code]
```

State codes match F5 event codes:
| Code | State |
|------|-------|
| `0x06` | Glasses worn |
| `0x07` | Not worn |
| `0x08` | In case, lid open |
| `0x0A` | In case, lid closed |
| `0x0B` | In case, lid closed, charging |

### 12.5 Head-Up Angle Set (0x0B) ✅

**Target:** Wiki says **Right** only.

```
Byte 0: 0x0B
Byte 1: 0x00-0x3C  Angle (0-60 degrees)
Byte 2: 0x01       Level/fixed
```

### 12.6 Head-Up Angle Get (0x32) 📋

**Target:** Send to **Right** side.

```
Send: [0x32]
Response: [0x32, 0xC9, angle(0x00-0x42)]
```

Note: Get returns range 0-66 (0x42) while Set accepts 0-60 (0x3C). 📋

### 12.7 Head-Up Calibration (0x10) 📋

```
[0x10, 0x01]  Clear calibration
[0x10, 0x02]  Set calibration
```

### 12.8 Wear Detection Set (0x27) ✅

```
[0x27, 0x01]  Enable
[0x27, 0x00]  Disable
```

### 12.9 Wear Detection Get (0x3A) 📋

**Target:** Send to **Either** side.

```
Send: [0x3A]
Response: [0x3A, 0xC9, enabled(00/01)]
```

### 12.10 Language Set (0x3D) 📋

```
Byte 0: 0x3D
Byte 1: 0x06   Size
Byte 2: 0x00   Pad
Byte 3: XX     Sequence
Byte 4: 0x01   Magic
Byte 5: XX     Language ID
```

| ID | Language |
|----|----------|
| `0x01` | Chinese |
| `0x02` | English |
| `0x03` | Japanese |
| `0x05` | French (?) |
| `0x06` | German |
| `0x07` | Spanish (?) |
| `0x0E` | Italian |

---

## 13. Info / Query Commands

### 13.1 Battery and Firmware (0x2C) ✅

```
Send: [0x2C, 0x01] (Android) or [0x2C, 0x02] (iOS)
```

Response:
```
Byte 0:    0x2C
Byte 1:    ASCII model ('A' or 'B')
Byte 2:    Left battery (0-100%)
Byte 3:    Right battery (0-100%)
Byte 4-6:  0x00 0x00 0x00  Unknown
Byte 7:    L major version
Byte 8:    L minor version
Byte 9:    L sub version
Byte 10:   R major version
Byte 11:   R minor version
Byte 12:   R sub version
```

### 13.2 Serial Number — Glasses (0x34) 📋

```
Send: [0x34]
Response: [0x34, 0x34, frame_type, frame_color, ID...]  (ASCII)
```

Format: `S{XXX}L{XX}L{XXXXXX}` e.g., `S110LAAL103842`

**Frame shapes:** S100 = Round (A), S110 = Square (B)
**Colors:** LAA = Grey, LBB = Brown, LCC = Green

### 13.3 Serial Number — Lens (0x33) 📋

```
Send: [0x33]
Response: [0x33, 0x33, ASCII_payload...]
```

### 13.4 ESB Channel (0x35) 📋

```
Send: [0x35]
Response: [0x35, 0xC9/0xCA, channel_id]
```

### 13.5 ESB Notification Count (0x36) 📋

```
Send: [0x36]
Response: [0x36, 0xC9/0xCA, count]
```

### 13.6 Time Since Boot (0x37) 📋

```
Send: [0x37]
Response: [0x37, time_bytes(4), unknown(00/01)]
```

### 13.7 Buried Point / Usage Data (0x3E) 📋

```
Send: [0x3E]
Response: [0x3E, 0xC9, JSON_payload...]
```

---

## 14. System Commands

### 14.1 Debug Logging (0x23 0x6C) 📋

⚠ **Inverted values:**
```
[0x23, 0x6C, 0x00]  Enable debug logging
[0x23, 0x6C, 0xC1]  Disable debug logging
```

Debug messages arrive as `0xF4` packets: null-terminated ASCII strings.

### 14.2 Reboot (0x23 0x72) 📋

```
[0x23, 0x72]
```
No response. Glasses reboot immediately.

### 14.3 Firmware Build Info (0x23 0x74) 📋

```
Send: [0x23, 0x74]
Response: Raw ASCII (no header!), starts with "net"
Example: "net build time: 2024-12-28 20:21:57, app build time 2024-12-28 20:20:45, ver 1.4.5, JBD DeviceID 4010"
```

### 14.4 Unpair (0x47) 📋

**Target:** Send to **Both** sides. **⚠ DANGEROUS.**

```
[0x47]
```

### 14.5 Upgrade Control (0x17) 📋

**Target:** Send to **Both** sides. **⚠ DANGEROUS — erases DFU image.**

```
[0x17]
```

---

## 15. Additional Protocols

### 15.1 Navigation (0x0A) 📋

| Subcmd | Description |
|--------|-------------|
| `0x00` | Init |
| `0x01` | Update trip status |
| `0x02` | Update map overview |
| `0x03` | Set panoramic map |
| `0x04` | App sync packet |
| `0x05` | Exit |
| `0x06` | Arrived |

### 15.2 Teleprompter (0x09) 📋

| Subcmd | Description |
|--------|-------------|
| `0x01` | Init / set text |
| `0x02` | Set position |
| `0x03` | Update text |
| `0x04` | None |
| `0x05` | Exit |

Related: `0x24` (teleprompter suspend), `0x25` (teleprompter position set — conflicts with heartbeat?)

### 15.3 Timer Control (0x07) 📋

Details TODO in wiki.

### 15.4 Transcribe Control (0x0D) 📋

Details TODO in wiki.

### 15.5 Translate Control (0x0F) 📋

Details TODO in wiki.

### 15.6 Tutorial Control (0x1F) 📋

"Has subcommands that need to be sent in sequence." Details TODO.

### 15.7 Dashboard Calendar Next Up (0x58) 📋

Sets calendar event below clock in Full mode. Details TODO.

### 15.8 Unknown Command (0x50) 📋

**Target:** Send to **Both** sides.

```
Send: [0x50, 0x06, 0x00, 0x00, 0x01, 0x01]
Response: Full command echoed back identically.
```

---

## 16. Quick Reference: All Command Bytes

| Byte | Name | Target | Status |
|------|------|--------|--------|
| `0x01` | Brightness Set | Right | ✅ |
| `0x03` | Silent Mode Set | Both | ✅ |
| `0x04` | Notification App List | Left | ✅ |
| `0x06` | Dashboard Set | Both | ✅ |
| `0x07` | Timer Control | ? | 📋 |
| `0x08` | Head-Up Action Set | Both | 📋 |
| `0x09` | Teleprompter Control | ? | 📋 |
| `0x0A` | Navigation Control | ? | 📋 |
| `0x0B` | Head-Up Angle Set | Right¹ | ✅ |
| `0x0D` | Transcribe Control | ? | 📋 |
| `0x0E` | Mic Set | Left²/Right² | ✅ |
| `0x0F` | Translate Control | ? | 📋 |
| `0x10` | Head-Up Calibration | ? | 📋 |
| `0x15` | BMP Data (File Upload) | Both | ✅ |
| `0x16` | BMP CRC (Bitmap Show) | Both | ✅ |
| `0x17` | Upgrade Control | Both | 📋 ⚠ |
| `0x18` | Clear Screen / Exit | Both | ✅ |
| `0x1E` | Quick Note Add | Both | 📋 |
| `0x1F` | Tutorial Control | ? | 📋 |
| `0x20` | File Upload Complete | Both | ✅ |
| `0x22` | Status (incoming) | — | 📋 |
| `0x23` | System Control | Both | 📋 |
| `0x25` | Heartbeat | Both | ✅ |
| `0x26` | Hardware Set | Both | 📋 |
| `0x27` | Wear Detection Set | Both | ✅ |
| `0x29` | Brightness Get | Right | 📋 |
| `0x2A` | Anti-Shake Get | ? | 📋 |
| `0x2B` | Silent Mode Get | Both | 📋 |
| `0x2C` | Battery/Firmware Get | ? | ✅ |
| `0x2D` | MAC Address Get | ? | 📋 |
| `0x2E` | Notif App List Get | ? | 📋 |
| `0x29` | Brightness Get | Right | 📋 |
| `0x32` | Head-Up Angle Get | Right | 📋 |
| `0x33` | Serial Number Lens | ? | 📋 |
| `0x34` | Serial Number Glasses | ? | 📋 |
| `0x35` | ESB Channel Get | ? | 📋 |
| `0x36` | ESB Notif Count Get | ? | 📋 |
| `0x37` | Time Since Boot Get | ? | 📋 |
| `0x38` | ANCS Settings Get | ? | 📋 |
| `0x39` | Running App Get | ? | 📋 |
| `0x3A` | Wear Detection Get | Either | 📋 |
| `0x3B` | Display Get | Right | 📋 |
| `0x3C` | Notif Auto Get | Left | 📋 |
| `0x3D` | Language Set | Both | 📋 |
| `0x3E` | Buried Point Get | ? | 📋 |
| `0x3F` | Hardware Get | ? | 📋 |
| `0x47` | Unpair | Both | 📋 ⚠ |
| `0x4B` | Notification Send | Left | ✅ |
| `0x4C` | Notification Clear | Left | 📋 |
| `0x4D` | MTU Set / Init | Both | ✅ |
| `0x4E` | Text/AI Result | Both | ✅ |
| `0x4F` | Notif Auto Set | Both | 📋 |
| `0x50` | Unknown | Both | 📋 |
| `0x58` | Calendar Next Up | ? | 📋 |
| `0xF1` | Mic Data (incoming) | — | ✅ |
| `0xF4` | Debug (incoming) | — | 📋 |
| `0xF5` | Event (incoming) | — | ✅ |

¹ Wiki says Right; AugmentOS sends to Both.
² **Mic target disputed:** Wiki says Left, AugmentOS says Right. Test both.

---

## 17. Helix-iOS Action Items

Based on cross-referencing all sources, these are discrepancies or gaps in Helix:

### High Priority
1. **BMP pixel inversion** — AugmentOS inverts pixel bits after 62-byte BMP header. Verify Helix does this.
2. **Mic enable target** — Wiki says Left, AugmentOS says Right. Test which side actually works.
3. **Brightness/angle commands** — Should go to Right only, not Both. Verify Helix routing.
4. **Notification send** — Should go to Left only. Verify Helix routing.

### Medium Priority
5. **Init sequence** — Consider sending `[0x4D, 0xFB]` (MTU=251) instead of `[0x4D, 0x01]`.
6. **Display height/depth** — Two-call preview protocol (preview=1, then preview=0).
7. **Notification clear** — `0x4C` with msg_id not implemented in Helix.
8. **Silent mode values** — Uses `0x0C`/`0x0A`, not `0x01`/`0x00`.

### Low Priority (Feature Gaps)
9. **Dashboard set** — Full `0x06` protocol with time/weather/calendar/stock/news/map.
10. **Navigation** — `0x0A` protocol not implemented.
11. **Language set** — `0x3D` not implemented.
12. **Battery query** — `0x2C` with iOS type `0x02`.
13. **Debug logging** — `0x23 0x6C` for on-device debugging.
14. **Teleprompter** — `0x09` protocol not implemented.
