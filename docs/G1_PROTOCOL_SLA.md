# Even Realities G1 — Communication Protocol & API SLA

**Source of truth**: [`even-realities/EvenDemoApp`](https://github.com/even-realities/EvenDemoApp)
pinned at commit `3899aac2b39ce969582cf6eb96ecb36be3e0e9e6` (2026-06-09).
Every clause cites `file:line` **in that repo**, not in Helix.

**Status**: Normative. Where Helix disagrees with this document, Helix is wrong
unless a dated on-hardware note says otherwise. Prose in the vendor README is
NOT normative — it has been observed to disagree with the vendor's own code
(see §9). Code wins.

**Conformance keywords**: MUST / MUST NOT / SHOULD / MAY per RFC 2119.

---

## 1. Transport

| Role | UUID |
|------|------|
| Service (Nordic UART) | `6E400001-B5A3-F393-E0A9-E50E24DCCA9E` |
| TX — phone writes | `6E400002-B5A3-F393-E0A9-E50E24DCCA9E` |
| RX — phone notifies | `6E400003-B5A3-F393-E0A9-E50E24DCCA9E` |
| CCCD | `00002902-0000-1000-8000-00805F9B34FB` |

`docs/G1_BLE_CONNECTION.en.md:47-56`

- G1 is **two independent BLE peripherals** (left, right) paired by channel number.
- Advertised names: `G1_<channel>_L_<suffix>` / `G1_<channel>_R_<suffix>`.
  Scan matches `G`+digits and **four** `_`-separated segments. A pair is
  surfaced only once **both** sides are seen. (`docs/G1_BLE_CONNECTION.en.md:33-43`)
- MTU: `requestMtu(251)`. Bonding via `createBond()`. (`docs/G1_BLE_CONNECTION.en.md:58`)
- Connected state is reported only when **both** sides report connected.

### SLA-T1 — Advertising exclusivity (operational)
A connected G1 lens **stops advertising**. Any second app holding a GATT link
(e.g. the official `com.even.g1`) makes the lenses **undiscoverable** to this
app. Clients MUST surface this as a distinct, actionable state and MUST NOT
present it as a generic "scanning" spinner.
*Observed on hardware 2026-08-28; cost three debugging cycles.*

---

## 2. Packet framing — `0x4E` (text / AI result)

9-byte header, then payload:

```
[0]  0x4E        command
[1]  syncSeq     per-SCREEN counter, & 0xFF, incremented once per screen
[2]  maxSeq      TOTAL packet COUNT for this screen   <-- see SLA-P1
[3]  seq         0-based index of this packet
[4]  newScreen   screen_status = AIStatus | ScreenAction
[5]  pos hi      big-endian int16, always 0
[6]  pos lo
[7]  current_page_num
[8]  max_page_num
[9+] payload     UTF-8, <= 191 bytes PER PACKET (payload only)
```

`lib/services/evenai_proto.dart:5-42`

### SLA-P1 — `maxSeq` is a COUNT, not count−1 (MUST)
```dart
int maxSeq = data.length ~/ len;
if (data.length % len > 0) { maxSeq++; }
```
`lib/services/evenai_proto.dart:18-21` — ceiling division. A 1-chunk screen
sends `maxSeq = 1`. Emitting `count - 1` is a protocol violation.

### SLA-P2 — Chunk length (MUST)
`len = 191` is the **payload** slice length, not the whole-frame budget:
`evenai_proto.dart:8` declares `int len = 191`, and `:21-27` slices
`data.sublist(seq * len, ...)` before the 9-byte header is *prefixed* via
`Utils.addPrefixToUint8List`. So a full frame is **9 + 191 = 200 bytes**, which
fits the negotiated MTU of 251 (`docs/G1_BLE_CONNECTION.en.md:58`).

Deriving the chunk size as `191 - 9 = 182` misreads `len` as a frame budget.

### SLA-P3 — `pos` is always 0 (MUST)
Written as big-endian int16 and passed `0` at every call site. It is **not** an
append offset. Pagination is 100% phone-driven by re-pushing whole pages with an
updated `current_page_num`.

### SLA-P5 — `current_page_num` is 1-BASED, never 0 (MUST)
The vendor derives both page fields from helpers that are 1-based and never
return 0 for real content (`lib/services/text_service.dart:133-162`):

```dart
int getCurrentPage() {
  if (_currentLine == 0) { return 1; }      // <-- single page => 1, NOT 0
  ...
}
int getTotalPages() {
  if (list.isEmpty) { return 0; }
  if (list.length < 6) { return 1; }
  ...
}
```

Every `0x4E` write — the `0x71` text path included — passes
`current_page_num: getCurrentPage(), max_page_num: getTotalPages()`
(`text_service.dart:68-71`). A single-page screen therefore carries
`current_page_num = 1, max_page_num = 1`.

Hard-coding `current_page_num = 0` against `max_page_num = 1` (a 0-based current
against a 1-based max) is a protocol violation. It originates in the Swift
`encodeWholeScreenText` and was inherited by the Kotlin port.

### SLA-P4 — `syncSeq` is per-screen (MUST)
`_evenaiSeq` increments once per `sendEvenAIData` call — every packet of one
screen carries the **same** value. (`lib/services/proto.dart:41,50`)

---

## 3. `screen_status` values

`newScreen = status | type`, where `type` is the ScreenAction.
(`lib/services/evenai.dart:485-486`)

| AIStatus | Meaning |
|---|---|
| `0x30` | Even AI displaying (automatic mode) |
| `0x40` | Even AI display complete — last page of automatic mode |
| `0x50` | Even AI manual mode |
| `0x60` | Even AI network error |
| `0x70` | Text Show (plain text, non-AI) |

| ScreenAction | Meaning |
|---|---|
| `0x01` | Display new content |

**Every** call site passes `type = 0x01`, so on-wire bytes are
`0x31`, `0x41`, `0x51`, `0x61`, `0x71`.

---

## 4. AI answer lifecycle (`0x31` → `0x41`) — NORMATIVE

`lib/services/evenai.dart:210-268`

### SLA-A1 — `0x30` MUST precede `0x40` (MUST)
Verbatim vendor comment, repeated three times in the source:
> `// The glasses need to have 0x30 before they can process 0x40`

`lib/services/evenai.dart:220,238,251`

### SLA-A2 — Short answers (≤5 measured lines)
1. Send the page at `0x31`.
2. Wait **exactly 3 seconds** (`await Future.delayed(Duration(seconds: 3))`).
3. If manual mode was latched meanwhile, **return without sending `0x40`**.
4. Otherwise re-send *the same text* at `0x41`.

`lib/services/evenai.dart:220-230`

### SLA-A3 — Long answers (>5 lines)
Send page 1 at `0x31`, then `updateReplyToOSByTimer()`: a **5-second**
`Timer.periodic` advancing 5 lines per tick. Each tick sends `0x31`, except the
final page which sends `0x41` and cancels the timer. Manual mode cancels it.
(`lib/services/evenai.dart:272-320`)

### SLA-A4 — Manual paging latches
`_isManual = true` cancels the timer and suppresses all further `0x40`.
(`lib/services/evenai.dart:325-330`)

### SLA-A5 — Plain text uses `0x71`, with no `0x40` phase
`text_service.dart` sends `doSendText(..., 0x01, 0x70, 0)` → wire `0x71` — for
first page, subsequent pages, and last page alike. There is **no** completion
byte on this path. (`lib/services/text_service.dart:30,39,46,51,109-126`)

> **Consequence.** `0x71` (Text Show) and `0x31`/`0x41` (AI session) are two
> DIFFERENT display paths. A client MUST NOT mix one path's header conventions
> into the other.

---

## 5. Left/right ordering and ACKs — NORMATIVE

### SLA-L1 — Left fully succeeds before right begins (MUST)
```dart
isSuccess = await BleManager.requestList(dataList, lr: "L", timeoutMs: 2000);
if (!isSuccess) { return false; }          // abort — right is never sent
isSuccess = await BleManager.requestList(dataList, lr: "R", timeoutMs: 2000);
```
`lib/services/proto.dart:55-71`

Ordering is **acknowledgment-gated, not delay-gated**. There is no fixed
inter-side sleep on this path.

### SLA-L2 — Every text packet is individually ACKed (MUST)
```dart
var resp = await request(pack, lr: lr, timeoutMs: timeoutMs ?? 350);
if (resp.isTimeout) return false;
else if (resp.data[1].toInt() != 0xc9 && resp.data[1].toInt() != 0xcB) return false;
```
`lib/ble_manager.dart:391-399`

- Per-packet ACK timeout: **350 ms** default; `sendEvenAIData` passes **2000 ms**.
- Accepted ACK codes: `0xC9` (success) and `0xCB`. `0xCA` is failure.
- ACK frame: byte 0 echoes the command, byte 1 carries the status.
- Text packets MUST NOT be fire-and-forget.

### SLA-L3 — Per-command lens routing (MUST)
| Command | Lens |
|---|---|
| `0x4B` notification | Left only, up to 6 retries (`proto.dart:185+`) |
| `0x04` app whitelist | Left only, 3 attempts, 300 ms (`proto.dart:166-180`) |
| `0x4E` text/AI | Left, then right (SLA-L1) |
| `0x18` exit | Left, then right, gated on `0xC9` (`proto.dart:122-135`) |
| Brightness `0x01`, head-up angle `0x0B`, display position `0x26` | **UNVERIFIED — see below** |
| Init, heartbeat, silent mode | Both |

---

## 6. Display teardown

### SLA-L3a — RETRACTED: display commands are NOT known to be right-lens-only
An earlier revision of this document asserted that brightness (`0x01`),
head-up angle (`0x0B`), and display position (`0x26`) are right-lens-only "in
the vendor app". **That claim has no basis in the cited source.** `grep -ri
brightness` over the entire EvenDemoApp tree returns **zero** matches: the
vendor demo implements none of these three commands, so it cannot be the
authority for any routing rule about them.

Helix sends all three to **both** lenses, which is the behaviour that shipped
and the only one observed working on hardware (2026-08-28: the wearer confirmed
brightness changes are visible). Routing them right-only additionally regresses
a supported state — `isGlassesConnected` is `left READY || right READY`, so on a
left-lens-only link every display setting silently becomes a no-op.

If a real source for a right-only rule exists (Even Realities firmware docs, the
community Python SDK, or a dated hardware observation), cite it here before
changing the routing again.

One genuine sub-finding survives the retraction: `0x26` **is** ACK-gated, so any
lens that accepts the write but never ACKs costs the transport its full retry
budget. That is a transport concern, not a reason to drop a lens.

### SLA-D1 — `0x18` returns the lens to the dashboard
```dart
// tell the glasses to exit function to dashboard
static Future<bool> exit() async { var data = Uint8List.fromList([0x18]); ... }
```
`lib/services/proto.dart:121-135`. Left first with a **1500 ms** timeout,
requiring `0xC9`, then right on the same terms.

### SLA-D2 — There is NO timed auto-blank in the vendor app
`Proto.exit()` is called only from an explicit user action
(`features_services.dart:38`); the one call inside the AI flow is **commented
out** (`evenai.dart:113`). After `0x41` the content **stays on the lens** until
something overwrites it.

> Any "answer disappears after N seconds" behaviour is a **product decision**,
> not vendor-specified. Helix implements it as `0x18` after a configurable
> dwell. That is a deliberate extension and MUST be documented as such.

---

## 7. Text layout

- Max width **488 px**, font size **21**, **5 lines per page**.
  (`lib/services/evenai.dart:489-511`)
- Paragraphs split on `\n`, trimmed, empties dropped, then wrapped to width.
- Short answers are padded with leading newlines to bottom-align:
  `\n\n` for ≤3 lines, `\n` for 4 lines. (`evenai.dart:217,235`)

---

## 8. Other commands

| Cmd | Purpose | Notes |
|---|---|---|
| `0x25` | Heartbeat | length 6; periodic (`proto.dart:76+`) |
| `0x4D 0x01` | Init (iOS) | per side |
| `0xF4 0x01` | Init (Android) | both ears |
| `0x4B` | Notification | `[0x4B, msgId, maxSeq, seq]` + ≤176 B JSON, left only |
| `0x04` | App whitelist | `[0x04, maxSeq, seq]` + ≤180 B JSON, left only |
| `0x18` | Exit to dashboard | see SLA-D1 |
| `0xF5` | Inbound touchpad/state | `02` head-up, `03` head-down, `1E`/`1F` dashboard |

Touchpad `notifyIndex`: 0 exit · 1 page back/forward (L/R) · 2 head-up ·
3 head-down · 23 evenaiStart · 24 evenaiRecordOver.

---

## 9. Where the vendor README misleads

The README states the exit command is `[0xF5, 0x00]`. **The vendor's own code
uses `[0x18]`** (`proto.dart:123`); `0xF5` appears only as an *inbound* state
family. Trust the code.

---

## 10. Helix conformance — audit 2026-08-28

| Clause | Helix (Android) | Status |
|---|---|---|
| SLA-P1 `maxSeq` = COUNT | now `chunks.size` on both paths (fixed) | ✅ *untested on HW* |
| SLA-P1 (whole-screen) | `encodeWholeScreenText` uses count | ✅ |
| SLA-P2 191-byte chunks | now 191 on both paths (fixed) | ✅ *untested on HW* |
| SLA-P3 `pos` = 0 | 0 | ✅ |
| SLA-P5 1-based currentPage | now 1 (fixed) | ✅ *untested on HW* |
| SLA-P4 per-screen syncSeq | per screen | ✅ |
| SLA-A1 `0x30` before `0x40` | sends neither | ⚠️ Uses `0x71` path |
| SLA-A5 `0x71` for plain text | now routed correctly (fixed) | ✅ *fix untested on HW* |
| SLA-L1 left-ACK before right | ACK-gated; absent lens ≠ failed lens (fixed) | ✅ *untested on HW* |
| SLA-L2 per-packet ACK | `withAck` + 2000 ms; `0x4E` added to decoder (fixed) | ✅ *untested on HW* |
| SLA-L3a display routing | both lenses (right-only claim RETRACTED — uncited) | ✅ |
| SLA-D1 `0x18` exit | `0x18`, both lenses, no ACK gate | ⚠️ Partial |
| SLA-D2 no vendor auto-blank | documented product extension | ✅ |
| SLA-T1 advertising exclusivity | 15 s scan-timeout hint when `com.even.g1` installed (fixed) | ✅ |

### Decoder gap (found during remediation, 2026-08-28)
`G1StatusDecoder.decode` omitted `0x4E` from its ACK command list. Harmless
while text was fire-and-forget; the moment SLA-L2 made screens ACK-gated it
became fatal — real `0x4E` ACK frames decoded to `null`, no waiter ever
resolved, and every screen would have timed out on hardware (packets x 3
attempts x 2 s) while unit tests injecting decoded events still passed.
`0x4E` is now in the list, and the transport tests drive raw bytes through
`handleInbound` so the decoder can never be bypassed again.

### Fix priority
1. **SLA-L2 / SLA-L1** — text ACK gating. Silently dropped packets are
   currently indistinguishable from success, which is why every failure looked
   identical.
2. **SLA-P1** — `maxSeq` off-by-one on the paged path.
3. **SLA-L3** — lens routing.
4. **SLA-T1** — conflict detection.
5. **SLA-P2** — chunk size 191.

---

## 11. Reproducing this document

```bash
git clone --depth 1 https://github.com/even-realities/EvenDemoApp.git
cd EvenDemoApp && git rev-parse HEAD   # expect 3899aac2b39ce...
```
Key files: `lib/services/evenai_proto.dart`, `lib/services/proto.dart`,
`lib/services/evenai.dart`, `lib/services/text_service.dart`,
`lib/ble_manager.dart`, `docs/G1_BLE_CONNECTION.en.md`.
