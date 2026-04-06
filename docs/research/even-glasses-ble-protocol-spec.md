# Even Realities G1 BLE Protocol Specification

Extracted from `emingenc/even_glasses` Python SDK v0.1.11.

Source files analyzed:
- `service_identifiers.py` -- BLE UUIDs
- `bluetooth_manager.py` -- BLE connection, write mechanics, heartbeat, reconnect
- `models.py` -- Command enums, packet models, notification structures
- `commands.py` -- Text/image/notification/dashboard sending logic
- `utils.py` -- Packet construction, CRC, image chunking
- `notification_handlers.py` -- Incoming command parsing and dispatch
- `command_logger.py` -- Protocol field documentation via logging

---

## 1. BLE Service and Characteristics

| Role | UUID | Direction |
|------|------|-----------|
| UART Service | `6E400001-B5A3-F393-E0A9-E50E24DCCA9E` | -- |
| TX Characteristic | `6E400002-B5A3-F393-E0A9-E50E24DCCA9E` | Phone -> Glasses (write) |
| RX Characteristic | `6E400003-B5A3-F393-E0A9-E50E24DCCA9E` | Glasses -> Phone (notify) |

This is the Nordic UART Service (NUS). The naming convention follows the BLE peripheral's perspective: TX from the peripheral is what the phone reads/subscribes to (RX char), and TX char is what the phone writes to.

**Write type**: `response=True` (write with response, not write-without-response).

**Notifications**: Started on the RX characteristic (`6E400003`) via `start_notify()`. All incoming data from glasses arrives as notifications on this characteristic.

---

## 2. Dual Glass Connection (Left / Right)

### Discovery
- Glasses advertise with `_L_` or `_R_` in the device name
- Scanner matches on these substrings to identify left vs right
- Both are `Glass` instances managed by `GlassesManager`

### Communication Model
- **Both glasses receive identical data**. Every command is sent to left first, then right, with a short delay between.
- There is no master/slave differentiation for data writes -- both sides get the same packets.
- Typical inter-glass delay: **0.1 seconds** (for general commands) or **0.4 seconds** (for text packets).

### Send Pattern (from `commands.py`)
```
send_command_to_glasses(manager, command):
    left_glass.send(command)    # write with response
    sleep(0.1)
    right_glass.send(command)   # write with response
    sleep(0.1)
```

For text packets the delay is 0.4s between left and right writes.

For image data, left glass receives ALL packets first (full sequence + end + CRC), then right glass receives the same sequence.

### Notification Handling
- Each glass has its own `notification_handler` callback
- Notifications from either side include `glass.side` ("left" / "right") for identification
- The first byte of notification data is always the command byte

---

## 3. Command Byte Map

| Command | Byte | Description |
|---------|------|-------------|
| `BRIGHTNESS` | `0x01` | Set display brightness |
| `SILENT_MODE` | `0x03` | Enable/disable silent mode |
| `DASHBOARD_SHOW` | `0x06` | Show/hide dashboard |
| `HEADUP_ANGLE` | `0x0B` | Set head-up display angle |
| `OPEN_MIC` | `0x0E` | Enable/disable microphone |
| `MIC_RESPONSE` | `0x0E` | Mic response (same cmd byte, different context) |
| `BMP_DATA` | `0x15` | Bitmap image data packet |
| `BMP_CRC` | `0x16` | Bitmap CRC check command |
| `NOTE_ADD` | `0x1E` | Add/update/delete quick note |
| `PACKET_END` | `0x20` | End of image data transmission |
| `QUICK_NOTE` | `0x21` | Quick note event (from glasses) |
| `DASHBOARD` | `0x22` | Dashboard event (from glasses) |
| `HEARTBEAT` | `0x25` | Heartbeat keep-alive |
| `DASHBOARD_POSITION` | `0x26` | Dashboard position/show state |
| `GLASSES_WEAR` | `0x27` | Glasses wear detection on/off |
| `NOTIFICATION` | `0x4B` | NCS notification (push notification) |
| `INIT` | `0x4D` | Initialize / handshake |
| `SEND_RESULT` | `0x4E` | AI result / text display |
| `RECEIVE_MIC_DATA` | `0xF1` | Incoming microphone audio data |
| `START_AI` | `0xF5` | AI control (start/stop/exit/page) |

---

## 4. Heartbeat Protocol

### Packet Format
```
Byte 0: 0x25 (HEARTBEAT command)
Byte 1: length & 0xFF        (low byte of length=6)
Byte 2: (length >> 8) & 0xFF (high byte of length=6)
Byte 3: seq % 0xFF           (sequence counter)
Byte 4: 0x04                 (fixed)
Byte 5: seq % 0xFF           (sequence counter, repeated)
```

Total: 6 bytes. Constructed via `struct.pack("BBBBBB", 0x25, 0x06, 0x00, seq, 0x04, seq)`.

### Timing
- Default frequency: **5 seconds**
- Sent continuously while connected
- Heartbeat starts automatically after connection
- Runs as an async task per glass (each glass gets its own heartbeat)

### Response
- Glasses respond with heartbeat notification (command byte `0x25`)
- No specific response validation -- just logged

---

## 5. Text / AI Result Protocol (Command `0x4E`)

### SendResult Packet Structure

```
Offset  Size  Field              Description
------  ----  -----              -----------
0       1     command            0x4E (SEND_RESULT)
1       1     seq                Sequence number (0-255)
2       1     total_packages     Total number of multi-packet chunks
3       1     current_package    Current chunk index (0-based)
4       1     screen_status      Combined screen action + AI status
5       1     new_char_pos0      New character position byte 0 (2-byte position)
6       1     new_char_pos1      New character position byte 1
7       1     page_number        Current page number (1-based)
8       1     max_pages          Total number of pages
9+      N     data               UTF-8 encoded text payload
```

Header: 9 bytes. Max packet size is bounded by BLE MTU (typically 191-200 bytes).

### Screen Status Byte (Offset 4)

The screen status byte is a combination of two fields:
- **Lower 4 bits (0x0F)**: Screen Action
- **Upper 4 bits (0xF0)**: AI Status

| AI Status | Value | Description |
|-----------|-------|-------------|
| `DISPLAYING` | `0x30` | AI content displaying (automatic mode) |
| `DISPLAY_COMPLETE` | `0x40` | AI display complete (last page, auto mode) |
| `MANUAL_MODE` | `0x50` | Manual page control mode |
| `NETWORK_ERROR` | `0x60` | Network error state |

| Screen Action | Value | Description |
|---------------|-------|-------------|
| `NEW_CONTENT` | `0x01` | New content arriving |

Combined values used in practice:
- `0x31` = `NEW_CONTENT | DISPLAYING` (new content, still more coming)
- `0x30` = `DISPLAYING` (continuation page in auto mode)
- `0x40` = `DISPLAY_COMPLETE` (final page sent, done)

### Multi-Page Text Flow

1. **Format text**: Lines are wrapped at 40 characters per line, 5 lines per page.
2. **Page count**: `total_pages = (len(lines) + 4) // 5`
3. **If multi-page**: Send an initial packet with just the first line, `page_number=1`, `screen_status = NEW_CONTENT | DISPLAYING` (`0x31`).
4. **For each page**: Send the page content (5 lines joined by `\n`), `screen_status = DISPLAYING` (`0x30`).
5. **After last page**: Re-send the last page with `screen_status = DISPLAY_COMPLETE` (`0x40`).
6. **Inter-page delay**: Configurable `duration` parameter (default 5 seconds between pages).

### Text Formatting
- Lines shorter than 5 are vertically centered with empty-string padding
- Line break character: `\n`
- Max characters per line: 40
- Max lines per page: 5

### Send Timing
- 0.4s delay between sending to left glass and right glass
- 0.1s delay between initial packet and page packets
- Configurable duration between pages (default 5s for auto-advance)

---

## 6. Bitmap / Image Protocol

### Overview
Images are sent as raw bitmap data, chunked into 194-byte packets, with a CRC32 verification step.

### Image Data Chunking
- **Chunk size**: 194 bytes per data packet
- Image data is divided into sequential chunks of 194 bytes (last chunk may be smaller)

### BMP Data Packet (Command `0x15`)

**First packet** (seq=0):
```
Offset  Size  Field        Description
------  ----  -----        -----------
0       1     command      0x15
1       1     seq          0x00 (first packet)
2       4     address      0x00, 0x1C, 0x00, 0x00 (storage address: 0x001C0000)
6       194   data         First 194 bytes of image data
```
Total first packet: 200 bytes.

**Subsequent packets** (seq > 0):
```
Offset  Size  Field        Description
------  ----  -----        -----------
0       1     command      0x15
1       1     seq          Sequence number (1, 2, 3, ...)
2       N     data         Next 194 bytes of image data (up to 194)
```
Total subsequent packets: 2 + data_length bytes (max 196).

### Packet End Command (Command `0x20`)
After all data packets are sent:
```
0x20, 0x0D, 0x0E
```
3 bytes, fixed.

### CRC Check Command (Command `0x16`)
After the packet end command:
```
Offset  Size  Field        Description
------  ----  -----        -----------
0       1     command      0x16
1       4     crc32        CRC32 checksum (big-endian, 4 bytes)
```
Total: 5 bytes.

### CRC32 Calculation
- Input: `address_bytes + full_image_data`
  - `address_bytes` = `[0x00, 0x1C, 0x00, 0x00]`
  - `full_image_data` = all image bytes concatenated
- Algorithm: Standard CRC32 with polynomial `0xEDB88320` (reflected/LSB-first)
- Initial value: `0xFFFFFFFF`, final XOR: `0xFFFFFFFF`
- Output: 4 bytes, big-endian: `[(crc >> 24) & 0xFF, (crc >> 16) & 0xFF, (crc >> 8) & 0xFF, crc & 0xFF]`

### Image Send Sequence
```
For left glass:
  1. Send all BMP data packets (0x15) sequentially
  2. Send packet end (0x20, 0x0D, 0x0E)
  3. Sleep 0.00001s (negligible)
  4. Send CRC check (0x16 + 4-byte CRC)

Then for right glass:
  1-4. Same sequence
```

Image data is sent to left glass first (complete), then right glass (complete). Not interleaved.

---

## 7. START_AI / Even AI Control (Command `0xF5`)

### Outgoing (Phone -> Glasses)

**Clear screen / stop AI**:
```
0xF5, 0x18, 0x00, 0x00, 0x00
```
5 bytes: `[START_AI, STOP, 0x00, 0x00, 0x00]`

**Generic AI command**:
```
0xF5, <subcmd>, [param bytes...]
```

### Incoming (Glasses -> Phone) SubCommands

| SubCommand | Value | Description |
|------------|-------|-------------|
| `EXIT` | `0x00` | Exit to dashboard (double-tap touchpad) |
| `PAGE_CONTROL` | `0x01` | Page up/down in manual mode |
| `PUT_ON` | `0x06` | Glasses put on (wear detection) |
| `TAKEN_OFF` | `0x07` | Glasses taken off (wear detection) |
| `START` | `0x17` | Start Even AI (user initiated) |
| `STOP` | `0x18` | Stop Even AI recording |

---

## 8. Notification Protocol (Command `0x4B`)

### NCS Notification JSON Structure
```json
{
  "ncs_notification": {
    "msg_id": 1,
    "type": 1,
    "app_identifier": "org.telegram.messenger",
    "title": "Notification Title",
    "subtitle": "Subtitle",
    "message": "Message body",
    "time_s": 1712345678,
    "date": "2026-04-05 12:34:56",
    "display_name": "Display Name"
  },
  "type": "Add"
}
```

### Chunking
- JSON is serialized to UTF-8 bytes
- Max chunk payload: **176 bytes** (180 - 4 byte header)
- Each chunk has a 4-byte header:

```
Offset  Size  Field          Description
------  ----  -----          -----------
0       1     command        0x4B (NOTIFICATION)
1       1     notify_id      Notification ID (0 in current impl)
2       1     total_chunks   Total number of chunks
3       1     current_chunk  Current chunk index (0-based)
4+      N     data           JSON chunk payload (max 176 bytes)
```

### Send Timing
- 0.01s delay between chunks
- Each chunk sent to both glasses (left first, then right, 0.1s between)

---

## 9. Dashboard Commands

### Show/Hide Dashboard (Command `0x26`)

```
Offset  Size  Field     Description
------  ----  -----     -----------
0       1     command   0x26 (DASHBOARD_POSITION)
1       1     fixed     0x07
2       1     fixed     0x00
3       1     fixed     0x01
4       1     fixed     0x02
5       1     state     0x01 = ON, 0x00 = OFF
6       1     position  Dashboard position (0x00-0x08)
```
Total: 7 bytes.

### Dashboard Positions

| Position | Value | Description |
|----------|-------|-------------|
| 0 | `0x00` | Bottom |
| 1-7 | `0x01`-`0x07` | Intermediate |
| 8 | `0x08` | Top |

---

## 10. Settings Commands

### Brightness (Command `0x01`)
```
Byte 0: 0x01 (BRIGHTNESS)
Byte 1: level (0x00 to 0x29, i.e., 0-41)
Byte 2: auto (0x00 = manual, 0x01 = auto)
```

### Silent Mode (Command `0x03`)
```
Byte 0: 0x03 (SILENT_MODE)
Byte 1: status (0x0A = OFF, 0x0C = ON)
Byte 2: 0x00
```

### Head-Up Angle (Command `0x0B`)
```
Byte 0: 0x0B (HEADUP_ANGLE)
Byte 1: angle (0-60 degrees)
Byte 2: 0x01
```

### Glasses Wear Detection (Command `0x27`)
```
Byte 0: 0x27 (GLASSES_WEAR)
Byte 1: status (0x01 = ON, 0x00 = OFF)
```

---

## 11. Quick Note Protocol (Command `0x1E`)

### Add/Update Note

```
Offset  Size  Field          Description
------  ----  -----          -----------
0       1     command        0x1E
1       1     payload_len    Total payload length & 0xFF
2       1     fixed          0x00
3       1     versioning     int(time()) % 256
4       1     fixed          0x03
5       1     fixed          0x01
6       1     fixed          0x00
7       1     fixed          0x01
8       1     fixed          0x00
9       1     note_number    Note number (1-4)
10      1     fixed          0x01
11      1     title_len      Length of title bytes
12      N     title          Title string (UTF-8)
12+N    1     text_len       Length of text bytes
13+N    1     fixed          0x00
14+N    M     text           Text string (UTF-8)
```

Note numbers are 1-4. Includes a versioning byte derived from `time() % 256`.

### Delete Note

Fixed 16-byte packet:
```
0x1E, 0x10, 0x00, 0xE0, 0x03, 0x01, 0x00, 0x01,
0x00, <note_number>, 0x00, 0x01, 0x00, 0x01, 0x00, 0x00
```

---

## 12. Microphone Protocol

### Open Mic (Command `0x0E`)
```
Byte 0: 0x0E (OPEN_MIC)
Byte 1: 0x01 (ENABLE) or 0x00 (DISABLE)
```

### Mic Response (Command `0x0E`, from glasses)
```
Byte 0: 0x0E
Byte 1: response status (0xC9 = SUCCESS, 0xCA = FAILURE)
Byte 2: mic enable status (0x01 = ENABLE, 0x00 = DISABLE)
```

### Receive Mic Data (Command `0xF1`, from glasses)
```
Byte 0: 0xF1 (RECEIVE_MIC_DATA)
Byte 1: seq (sequence number)
Byte 2+: audio data bytes
```

---

## 13. Error Handling and Reconnection

### Reconnection Strategy
- **Trigger**: Automatic on unexpected disconnection (if `desired_connection_state == CONNECTED`)
- **Retries**: 3 attempts
- **Backoff**: 5 seconds between attempts (fixed, not exponential)
- **On failure**: Logs error, gives up after 3 attempts

### Write Protection
- Each glass has an `asyncio.Lock` (`_write_lock`) for serialized writes
- Write failures are caught and logged, return `False`
- Connection check before every write attempt

### Disconnection Handling
- Notifications are stopped before disconnecting
- Heartbeat task is cancelled on disconnect
- `disconnected_callback` on `BleakClient` triggers reconnection logic

---

## 14. Protocol Comparison with Helix-iOS

The Helix-iOS codebase (`/Users/artjiang/develop/Helix-iOS/ios/Runner/ServiceIdentifiers.swift`) uses identical UUIDs:
- Service: `6E400001-B5A3-F393-E0A9-E50E24DCCA9E`
- TX (write): `6E400002-B5A3-F393-E0A9-E50E24DCCA9E`
- RX (notify): `6E400003-B5A3-F393-E0A9-E50E24DCCA9E`

### Key Differences to Investigate

| Area | even_glasses (Python) | Helix-iOS |
|------|----------------------|-----------|
| Write type | With response (`response=True`) | Check `BluetoothManager.swift` |
| Inter-glass delay | 0.1s general, 0.4s text | Check current implementation |
| Image storage addr | `0x001C0000` | Check bitmap HUD service |
| Image chunk size | 194 bytes | Check bitmap HUD service |
| Heartbeat freq | 5 seconds | Check heartbeat implementation |
| Reconnect retries | 3, 5s backoff | Check reconnection logic |
| Max text line width | 40 chars | Check text paginator |
| Lines per page | 5 | Check text paginator |
| Notification chunk | 176 bytes (180-4 header) | Check NCS implementation |

---

## 15. Packet Size Summary

| Packet Type | Max Size (bytes) | Notes |
|-------------|-----------------|-------|
| Heartbeat | 6 | Fixed |
| Text/AI Result | 9 + text_bytes | Header 9, text limited by MTU |
| BMP Data (first) | 200 | 2 cmd + 4 addr + 194 data |
| BMP Data (subsequent) | 196 | 2 cmd + 194 data |
| BMP Packet End | 3 | Fixed: 0x20, 0x0D, 0x0E |
| BMP CRC Check | 5 | 1 cmd + 4 CRC bytes |
| Notification chunk | 180 | 4 header + 176 payload |
| Dashboard show/hide | 7 | Fixed |
| Brightness | 3 | Fixed |
| Silent mode | 3 | Fixed |
| Head-up angle | 3 | Fixed |
| Glasses wear | 2 | Fixed |
| Clear screen | 5 | Fixed |
| Note delete | 16 | Fixed |
| Note add | Variable | Header + title + text |
