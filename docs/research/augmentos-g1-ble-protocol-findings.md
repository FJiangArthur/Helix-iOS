# AugmentOS G1 BLE Protocol & Architecture Findings

Research date: 2026-04-05
Source: https://github.com/AugmentOS-Community/AugmentOS (main branch)
Focus: mobile app iOS native module (`mobile/modules/core/ios/Source/sgcs/G1.swift`)

---

## 1. Architecture Overview

AugmentOS uses a **three-tier architecture**: Cloud <-> Mobile App <-> Glasses.

```
Cloud (Node.js)                Mobile App (React Native / Expo)         G1 Glasses (BLE)
  |                               |                                       |
  |  WebSocket (display_event)    |                                       |
  |------------------------------>|  DisplayProcessor                     |
  |                               |  (pixel-accurate text wrapping)       |
  |                               |                                       |
  |                               |  CoreModule (Expo native module)      |
  |                               |  -> CoreManager.swift (singleton)     |
  |                               |    -> SGCManager protocol             |
  |                               |      -> G1.swift (BLE L/R manager)    |
  |                               |         -> CBCentralManager           |
  |                               |            -> L peripheral (UART)     |
  |                               |            -> R peripheral (UART)     |
```

Key insight: The mobile app is primarily a **relay** between the cloud and the glasses. AI processing happens in the cloud. The mobile app handles:
- BLE connection management (L/R glasses)
- Display event processing (text wrapping to fit display)
- Audio capture and forwarding (phone mic or glasses mic via LC3)
- Touch/button event forwarding to cloud

---

## 2. BLE Connection Layer

### 2.1 UART Service UUIDs

```
UART_SERVICE_UUID = 6E400001-B5A3-F393-E0A9-E50E24DCCA9E
UART_TX_CHAR_UUID = 6E400002-B5A3-F393-E0A9-E50E24DCCA9E  (Phone -> Glasses)
UART_RX_CHAR_UUID = 6E400003-B5A3-F393-E0A9-E50E24DCCA9E  (Glasses -> Phone)
```

Standard Nordic UART Service (NUS). Identical to what Helix uses.

### 2.2 L/R Connection Model

AugmentOS discovers G1 glasses via BLE advertising name pattern: `Even G1_<ID>_L_<MAC>` / `Even G1_<ID>_R_<MAC>`.

- Device search uses `DEVICE_SEARCH_ID` formatted as `_<id>_`
- Both peripherals (`leftPeripheral`, `rightPeripheral`) connect independently
- Readiness tracked via `leftReady` / `rightReady` flags
- `fullyBooted` = `leftReady && rightReady`
- UUID persistence in UserDefaults (`leftGlassUUID`, `rightGlassUUID`) for background reconnection

### 2.3 Reconnection Strategy

- On disconnect of either side: BOTH peripherals cleared, readiness reset to false
- `ReconnectionManager` actor: periodic scan attempts every 30s, unlimited retries
- First reconnection tries `connectByUUID()` (works in background mode)
- Falls back to full BLE scan if UUID reconnection fails
- Reconnection stops automatically when `fullyBooted` becomes true

### 2.4 Command Queue Architecture

Uses Swift actor-based concurrency:

```
CommandQueue (actor)     ->  processCommand()  ->  attemptSend() to L and R in parallel
AckManager (actor)       ->  waitForAck() with timeout per command
HeartbeatManager (actor) ->  20-second heartbeat interval
```

Key parameters:
- `DELAY_BETWEEN_CHUNKS_SEND`: 16ms
- `DELAY_BETWEEN_SENDS_MS`: 8ms  
- `INITIAL_CONNECTION_DELAY_MS`: 350ms
- Chunk inter-packet delay: 8ms (configurable `chunkTimeMs`)
- Last frame delay: 100ms (configurable `lastFrameMs`)

### 2.5 ACK Handling

- Uses `AckManager` actor with per-side or per-sequence-number keys
- ACK timeout: 300ms + 200ms per retry attempt
- Max 5 retry attempts per command
- Two write modes:
  - `.withResponse` for final chunk of each command (waits for ACK)
  - `.withoutResponse` for intermediate chunks (fire-and-forget for speed)

---

## 3. Command Protocol

### 3.1 Command Bytes

From `Enums.swift`:

| Command | Byte | Purpose |
|---------|------|---------|
| `BLE_EXIT_ALL_FUNCTIONS` | `0x18` | Clear display / exit |
| `BLE_REQ_INIT` | `0x4D` | Initialize connection |
| `BLE_REQ_BATTERY` | `0x2C` | Request battery status |
| `BLE_REQ_HEARTBEAT` | `0x25` | Heartbeat keepalive |
| `BLE_REQ_EVENAI` | `0x4E` | Send text/AI response |
| `BLE_REQ_TRANSFER_MIC_DATA` | `0xF1` | Mic audio data (LC3) |
| `BLE_REQ_DEVICE_ORDER` | `0xF5` | Device event notifications |
| `BLE_REQ_MIC_ON` | `0x0E` | Enable/disable glasses mic |
| `QUICK_NOTE_ADD` | `0x1E` | Quick note management |
| `CRC_CHECK` | `0x16` | CRC validation for BMP |
| `BMP_END` | `0x20` | BMP transfer complete |
| `BRIGHTNESS` | `0x01` | Set brightness (0-41) |
| `WHITELIST` | `0x04` | Notification whitelist |
| `SILENT_MODE` | `0x03` | Silent mode toggle |
| `DASHBOARD_LAYOUT_COMMAND` | `0x26` | Dashboard layout/position |
| `DASHBOARD_SHOW` | `0x06` | Show dashboard |
| `HEAD_UP_ANGLE` | `0x0B` | Head-up detection angle |

### 3.2 ACK Response

```
ACK  = 0xC9
CONT = 0xCB  (continue / whitelist)
```

### 3.3 Device Orders (Glasses -> Phone, via `0xF5`)

| Order | Byte | Purpose |
|-------|------|---------|
| `DISPLAY_READY` | `0x00` | Display initialized |
| `TRIGGER_CHANGE_PAGE` | `0x01` | Touchpad page change |
| `TRIGGER_FOR_AI` | `0x17` | AI trigger (touchpad) |
| `TRIGGER_FOR_STOP_RECORDING` | `0x18` | Stop recording |
| `HEAD_UP` | `0x1E` | Head raised |
| `HEAD_UP2` | `0x02` | Head raised (alt) |
| `HEAD_DOWN2` | `0x03` | Head lowered |
| `ACTIVATED` | `0x05` | Glasses activated |
| `SILENCED` | `0x04` | Glasses silenced |
| `CASE_REMOVED` | `0x07` | Removed from case |
| `CASE_REMOVED2` | `0x06` | Removed from case (alt) |
| `CASE_OPEN` | `0x08` | Case opened |
| `CASE_CLOSED` | `0x0B` | Case closed |
| `CASE_CHARGING_STATUS` | `0x0E` | Case charging state (data[2]: 0x01=charging) |
| `CASE_CHARGE_INFO` | `0x0F` | Case battery level (data[2]: percentage) |
| `DOUBLE_TAP` | `0x20` | Double-tap / display off |

### 3.4 Display Status Codes

```
NORMAL_TEXT = 0x30   (streaming text)
FINAL_TEXT  = 0x40   (AI complete)
MANUAL_PAGE = 0x50   (manual page)
ERROR_TEXT  = 0x60   (error display)
SIMPLE_TEXT = 0x70   (static text display)
```

---

## 4. Text Display Protocol

### 4.1 Text Packet Format (command `0x4E`)

```
Byte 0: 0x4E          - SEND_RESULT / Text command
Byte 1: seqNum        - Sequence number (0-255, wraps)
Byte 2: totalPackages - Total chunks for this text
Byte 3: currentPackage - Current chunk index (0-based)
Byte 4: screenStatus  - Display status (e.g., 0x71 = New Content + Simple Text)
Byte 5: charPos0      - Character position high byte
Byte 6: charPos1      - Character position low byte
Byte 7: currentPage   - Page number
Byte 8: maxPages      - Total pages
Byte 9+: UTF-8 text data (up to 176 bytes per chunk)
```

Screen status byte is a combination:
- `0x01` = New Content flag
- `0x30` = Normal/streaming text
- `0x40` = AI complete
- `0x70` = Simple text show

So `0x71` = Simple Text (`0x70`) | New Content (`0x01`)

### 4.2 Text Chunking

- Max chunk size: 176 bytes of payload per BLE packet
- 9-byte header prepended to each chunk
- Text is pre-wrapped by `DisplayProcessor` in React Native before reaching native layer
- `G1Text.swift` only does chunking, NOT wrapping (wrapping done in cloud/RN)

### 4.3 Display Dimensions

From `display-utils` G1 profile:
- Display width: 576px (physical), 488px used for text
- Max lines: 5
- Font: custom glyph-based, rendered width = `(glyphWidth + 1) * 2`
- Space width: 6px rendered
- Hyphen width: 10px rendered
- Max BLE payload: 390 bytes
- BLE chunk size: 176 bytes

---

## 5. Bitmap Display Protocol

### 5.1 BMP Transfer Flow

```
1. Decode base64 -> raw BMP data
2. Invert pixels (BMP header is 62 bytes; invert everything after)
3. Chunk into 194-byte packs
4. First pack: [0x15, packIndex, address(4B), data...]
   Subsequent: [0x15, packIndex, data...]
5. After all data: send end command [0x20, 0x0D, 0x0E]
6. Calculate CRC32-XZ over [address + bmpData]
7. Send CRC: [0x16, crc3, crc2, crc1, crc0]
```

### 5.2 BMP Constants

- Pack length: 194 bytes per chunk
- Address bytes: `[0x00, 0x1C, 0x00, 0x00]` (fixed glasses address)
- BMP format: 576x135 1-bit monochrome
- BMP header size: 62 bytes (14 file header + 40 DIB header + 8 color table)
- CRC polynomial: CRC32-XZ (0x04C11DB7, NOT standard CRC32)
- Pixel inversion required (bits are flipped before sending)

### 5.3 BMP Command Bytes

```
0x15 = BMP data chunk
0x20 = BMP end (with payload [0x0D, 0x0E])
0x16 = CRC check
```

---

## 6. Dashboard Protocol

### 6.1 Dashboard Layout Command (`0x26`)

```
Byte 0: 0x26 (DASHBOARD_LAYOUT_COMMAND)
Byte 1: 0x08 (length)
Byte 2: 0x00 (sequence)
Byte 3: globalCounter (incrementing)
Byte 4: 0x02 (fixed)
Byte 5: 0x01 (state ON)
Byte 6: height (0-8)
Byte 7: depth (1-9)
```

### 6.2 Dashboard Modes

```
full    = 0x00
dual    = 0x01
minimal = 0x02
```

---

## 7. Other Commands

### 7.1 Init (`0x4D`)

```
Send: [0x4D, 0x01]
Response: [0x4D, 0xC9] = ACK success
```

Both sides must ACK init before `fullyBooted` = true.

### 7.2 Heartbeat (`0x25`)

```
Send: [0x25, counter]
Response: [0x25, counter-1]
```

Sent every 20 seconds. Battery check piggybacked every 10th heartbeat.

### 7.3 Battery (`0x2C`)

```
Send: [0x2C, 0x01]
Response: [0x2C, 0x66, battery%, flags, volLow, volHigh, ...]
```

Battery level = min(leftBattery, rightBattery).

### 7.4 Mic Enable (`0x0E`)

```
Enable:  [0x0E, 0x01]  (sent to RIGHT only)
Disable: [0x0E, 0x00]  (sent to RIGHT only)
```

Mic data arrives as `0xF1` packets; first 2 bytes skipped, rest is LC3 audio.

### 7.5 Brightness (`0x01`)

```
[0x01, level, autoMode]
level: 0x00-0x29 (0-41, mapped from 0-100%)
autoMode: 0x01 (auto) or 0x00 (manual)
```

### 7.6 Head-Up Angle (`0x0B`)

```
[0x0B, angle, 0x01]
angle: 0-60 degrees
```

### 7.7 Silent Mode (`0x03`)

```
Enable:  [0x03, 0x0C, 0x00]
Disable: [0x03, 0x0A, 0x00]
```

### 7.8 Whitelist (`0x04`)

JSON notification whitelist, chunked:
```
[0x04, totalChunks, chunkIndex, ...jsonPayload]
Max payload per chunk: 176 bytes (180 - 4 header bytes)
```

### 7.9 Notification (`0x4B`)

```
[0x4B, notifyId, totalChunks, chunkIndex, ...jsonPayload]
Payload: NCS notification JSON (msg_id, app_identifier, title, message, etc.)
```

### 7.10 Exit All Functions (`0x18`)

```
[0x18]
```

Single byte, clears display.

---

## 8. Serial Number Decoding

From manufacturer advertising data:
- Format: `S1<style><xx><color><rest>` (e.g., `S110LABD020021`)
- Style (index 2): `0` = Round, `1` = Rectangular
- Color (index 5): `A` = Grey, `B` = Brown, `C` = Green

---

## 9. Comparison with Helix-iOS

### Similarities

| Feature | AugmentOS | Helix-iOS |
|---------|-----------|-----------|
| UART UUIDs | Same Nordic NUS | Same Nordic NUS |
| L/R discovery | `_L_` / `_R_` in name | Same |
| Text command | `0x4E` | `0x4E` |
| Screen codes | `0x30/0x40/0x70` | Same |
| BMP commands | `0x15/0x16/0x20` | Same |
| Heartbeat | `0x25` | `0x25` |
| Battery | `0x2C` | `0x2C` |
| Device orders | `0xF5` | `0xF5` |
| Max chunk | 176 bytes | 176 bytes (Helix uses 191 for EvenAI) |

### Differences

| Feature | AugmentOS | Helix-iOS |
|---------|-----------|-----------|
| Architecture | Cloud-first (cloud sends display_event) | On-device (ConversationEngine runs locally) |
| Text wrapping | Cloud + DisplayProcessor in RN | On-device bitmap rendering (BitmapHudService) |
| Display path | Cloud -> WS -> DisplayProcessor -> Native -> BLE | ConversationEngine -> HudController -> BLE |
| AI processing | Cloud-side | On-device LLM calls |
| Command queue | Swift actor-based (CommandQueue) | Flutter MethodChannel -> Swift |
| ACK handling | AckManager actor with per-key tracking | Simpler semaphore-based |
| BMP address | `[0x00, 0x1C, 0x00, 0x00]` | Same |
| BMP CRC | CRC32-XZ (polynomial 0x04C11DB7) | Standard CRC32 (may differ) |
| Mic routing | Right glass only (`sendLeft: false, sendRight: true`) | Same convention |
| Dashboard cmd | `0x26` with height/depth | `0x26` (may use different layout) |
| Touchpad mapping | `0x17` = AI trigger, `0x01` = page change | `notifyIndex` 23/24 = evenaiStart/recordOver |

### Key Architectural Insight

AugmentOS delegates ALL intelligence to the cloud. The mobile app is essentially a BLE-to-WebSocket bridge with display processing. Helix-iOS runs the full AI pipeline on-device, using the phone as the brain rather than a relay.

This means AugmentOS requires constant internet connectivity for any AI features, while Helix can operate offline (with local models). However, AugmentOS gains access to more powerful cloud models and can update AI behavior without app updates.

---

## 10. Useful Patterns to Adopt

### 10.1 Actor-Based Command Queue

AugmentOS's `CommandQueue`, `AckManager`, and `HeartbeatManager` actors provide excellent concurrency safety. Consider adopting similar patterns in Helix's BLE layer to replace the current DispatchQueue approach.

### 10.2 L/R Parallel Transmission

Commands are sent to L and R in parallel using `withTaskGroup`, with independent retry per side. This is more resilient than sequential sends.

### 10.3 UUID-Based Reconnection

Storing peripheral UUIDs in UserDefaults and using `retrievePeripherals(withIdentifiers:)` for background reconnection is a proven pattern worth ensuring Helix follows.

### 10.4 Display Profile System

The `display-utils` package with per-device font metrics, glyph widths, and rendering formulas is a robust approach for pixel-accurate text wrapping across different glasses models.

### 10.5 CRC32-XZ for BMP Verification

AugmentOS uses CRC32-XZ (polynomial `0x04C11DB7`) rather than standard CRC32. If Helix has BMP display issues, verify which CRC variant is being used.

---

## Key Source Files Referenced

| File | Path |
|------|------|
| G1 BLE Manager | `mobile/modules/core/ios/Source/sgcs/G1.swift` |
| Commands/Enums | `mobile/modules/core/ios/Source/utils/Enums.swift` |
| Text Chunking | `mobile/modules/core/ios/Source/utils/G1Text.swift` |
| SGC Protocol | `mobile/modules/core/ios/Source/sgcs/SGCManager.swift` |
| Core Manager | `mobile/modules/core/ios/Source/CoreManager.swift` |
| Constants | `mobile/modules/core/ios/Source/utils/Constants.swift` |
| Models | `mobile/modules/core/ios/Source/utils/Models.swift` |
| Display Processor | `mobile/src/services/DisplayProcessor.ts` |
| G1 Display Profile | `cloud/packages/display-utils/src/profiles/g1.ts` |
| Socket Comms | `mobile/src/services/SocketComms.ts` |
| WebSocket Manager | `mobile/src/services/WebSocketManager.ts` |
| Core Module Bridge | `mobile/modules/core/src/CoreModule.ts` |
| Core Types | `mobile/modules/core/src/Core.types.ts` |
| Glasses Store | `mobile/src/stores/glasses.ts` |
| Display Store | `mobile/src/stores/display.ts` |
