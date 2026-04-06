# G1 Protocol Fix — Manual Hardware Test Protocol

> Test these on physical G1 glasses connected via BLE.
> Each test references the bug ID it validates.

---

## Pre-Test Setup

1. Build and install the updated app on a physical device
2. Connect G1 glasses (both L and R should show as connected)
3. Ensure you have a way to trigger AI responses (either live conversation or manual "Analyze" button)
4. Have the Xcode console open to monitor BLE logs

---

## Test 1: AI Streaming Screen Codes (H1)

**What changed:** AI responses now send different screen codes per page position — first page gets `0x31` (new canvas), middle pages get `0x30` (existing canvas), final page gets `0x40` (AI complete).

**Steps:**
1. Start a live conversation or type a question that produces a **multi-page** AI response (ask something that needs a long answer, e.g., "Explain the history of the internet in detail")
2. Watch the glasses display as the AI streams

**Expected behavior:**
- First page appears cleanly on a fresh canvas (no leftover artifacts from previous content)
- Subsequent pages render smoothly **without flicker** — the canvas should NOT reset between middle pages
- When the AI finishes, the display should settle (no further updates)
- Page indicator on glasses (if shown) should display correctly

**Failure indicators:**
- Visible flicker/blink between pages during streaming
- Canvas resets (momentary blank screen) between middle pages
- Content from previous page bleeds into new page

**Xcode log to watch for:**
```
proto--sendEvenAIData seq=X newScreen=0x31 page=1/N  (first)
proto--sendEvenAIData seq=X newScreen=0x30 page=2/N  (middle)
proto--sendEvenAIData seq=X newScreen=0x40 page=N/N  (last)
```

---

## Test 2: Text Page Screen Codes (M1, M2)

**What changed:** Plain text sends now use `0x71` for the first page and `0x70` for subsequent pages.

**Steps:**
1. Go to the Text page (send text feature)
2. Type or paste a long text that will span **multiple pages** (more than 5 lines of content)
3. Send it to the glasses

**Expected behavior:**
- First page appears on a fresh canvas
- Page transitions are smooth without flicker
- Each subsequent page renders on the existing canvas without a reset

**Failure indicators:**
- Same as Test 1 — flicker between pages

---

## Test 3: Page Number Accuracy (M4)

**What changed:** `current_page_num` now tracks the actual page being sent, not always the total.

**Steps:**
1. Trigger a multi-page AI response
2. If the glasses show a page indicator (e.g., "2/5"), check that it updates correctly

**Expected behavior:**
- Page indicator shows `1/N`, `2/N`, `3/N`, etc. as pages arrive
- Should NOT always show `N/N` for every page

**Failure indicators:**
- Page indicator stuck on last page number (e.g., always "5/5")

---

## Test 4: Inter-Side Display Sync (M3)

**What changed:** 400ms delay added between sending text to left and right glasses.

**Steps:**
1. Trigger any AI response or send text while wearing both glasses
2. Pay attention to whether both lenses update at roughly the same time

**Expected behavior:**
- Both left and right lenses show the same content
- The right lens updates ~400ms after the left (barely perceptible)
- No situation where left shows new content while right still shows old content for an extended period

**Failure indicators:**
- One lens shows content while the other is blank or shows old content for >1 second
- Content appears garbled on one side

---

## Test 5: Battery Event Handling (H2)

**What changed:** The app now handles the 0x0A battery level event from glasses.

**Steps:**
1. Connect glasses
2. Check Xcode console for battery level logs

**Expected behavior:**
- Xcode console shows: `[BLE] Battery level: XX%` (where XX is 0-100)
- If the app has a battery widget/indicator, it should display a value

**Xcode log to watch for:**
```
batteryLevel event: XX
```

---

## Test 6: Status Messages (H3)

**What changed:** The app now parses 0x22 status messages from glasses.

**Steps:**
1. Connect glasses and look up (head-up gesture) to trigger a status message
2. Check Xcode console

**Expected behavior:**
- Xcode console shows status information: unread count, low power flag, dashboard mode
- Example log: `[BLE] Status: unread=0 lowPower=false dashboardMode=0`

**Failure indicators:**
- No status log appears when looking up (may mean 0x22 parsing not reaching log)

---

## Test 7: Dashboard Open/Close Events (M10)

**What changed:** Dashboard open (0x1E) and close (0x1F) events are now handled.

**Steps:**
1. Double-tap the glasses touchpad to open/close the dashboard
2. Check Xcode console

**Expected behavior:**
- `dashboardOpened` event logged when dashboard opens
- `dashboardClosed` event logged when dashboard closes

---

## Test 8: Heartbeat Interval (M5)

**What changed:** Heartbeat interval reduced from 8s to 5s.

**Steps:**
1. Connect glasses and let the app idle for 30+ seconds
2. Watch Xcode console for heartbeat logs

**Expected behavior:**
- Heartbeat logs appear every ~5 seconds (not 8)
- Format: `sendHeartBeat--------data---[37, 6, 0, X, 4, X]--`
- Glasses remain connected (no disconnection due to timeout)

**Failure indicators:**
- Heartbeat at wrong interval
- Glasses disconnect after a period of idle

---

## Test 9: Debug Logging Toggle (New Feature)

**What changed:** New debug logging option in Settings, sends 0x23 command to glasses.

**Steps:**
1. Open Settings page
2. Scroll to the very bottom
3. Find "Debug Logging" toggle
4. Turn it ON

**Expected behavior:**
- Toggle sends `[0x23, 0x6C, 0x00]` to glasses (visible in Xcode BLE logs)
- A text area appears below the toggle showing incoming debug messages
- Debug messages from glasses appear in real-time in both:
  - The settings text area
  - Xcode console (prefixed with `[G1 Debug]` or similar)

**Steps to verify disable:**
1. Turn the toggle OFF
2. Sends `[0x23, 0x6C, 0xC1]` to glasses
3. Debug messages stop arriving
4. Text area hides or clears

**Failure indicators:**
- No debug messages appear after enabling
- Toggle doesn't send the BLE command
- App crashes when toggling

---

## Test 10: Triple-Tap Silent Toggle (M7)

**What changed:** Triple-tap events (0x04/0x05) now handled instead of being dropped.

**Steps:**
1. Triple-tap the left or right touchpad on the glasses
2. Check Xcode console

**Expected behavior:**
- `tripleTapLeft` or `tripleTapRight` event logged
- Silent mode toggles on the glasses (visual/haptic feedback from glasses)

---

## Test 11: Right Touchpad Hold (M8)

**What changed:** Right touchpad held event (0x12) now handled.

**Steps:**
1. Press and hold the right touchpad on the glasses
2. Check Xcode console

**Expected behavior:**
- `rightTouchpadHeld` event logged

---

## Test 12: Charging Status (M9)

**What changed:** Charging event (0x09) now handled.

**Steps:**
1. Place glasses in charging case
2. Check Xcode console

**Expected behavior:**
- `chargingStatus` event logged with payload 0 or 1

---

## Test 13: BLE Transport Resilience (Earlier fix)

**What changed:** `glassesConnected` notification deferred until characteristics are discovered; transport policy uses OR logic (succeed if either side works).

**Steps:**
1. Turn glasses off and on (or put in case and take out)
2. Wait for reconnection
3. Immediately try to send text or trigger AI response

**Expected behavior:**
- Text/AI response displays on glasses even if one side's characteristic discovery is slower
- No more "rightWChar is nil" failures blocking all sends
- Xcode shows `didDiscoverCharacteristics side=L/R` BEFORE `glassesConnected`

**Failure indicators:**
- "writeData rightWChar is nil" still appears AND no content displays
- Sends fail completely despite left side being connected

---

## Regression Tests

### R1: Basic AI Response
1. Ask a short question → AI response should display on glasses
2. Both lenses should show same content

### R2: Manual Text Send
1. Send a short text from the Text page → should display on glasses

### R3: Bitmap HUD (if enabled)
1. If bitmap HUD is active, verify it still renders and updates correctly
2. Dashboard should still show/hide properly

### R4: Touchpad Navigation
1. During multi-page content, tap right touchpad → next page
2. Tap left touchpad → previous page
3. Double-tap → exit to dashboard

### R5: Transcription
1. Start conversation → transcription should work normally
2. AI should detect questions and answer them

---

## Pass/Fail Criteria

| Test | Must Pass | Nice to Have |
|------|-----------|-------------|
| 1 (AI screen codes) | No flicker between pages | Correct page indicators |
| 2 (Text screen codes) | No flicker between pages | — |
| 3 (Page numbers) | — | Correct page indicator |
| 4 (Inter-side sync) | Both lenses show content | Synchronized timing |
| 5 (Battery) | Log appears in Xcode | Widget shows value |
| 6 (Status) | Log appears in Xcode | — |
| 7 (Dashboard events) | Log appears in Xcode | — |
| 8 (Heartbeat) | Glasses stay connected | 5s interval in logs |
| 9 (Debug logging) | Toggle works, logs appear | Real-time text area |
| 10-12 (Events) | Logs appear in Xcode | — |
| 13 (Transport) | Sends work after reconnect | No rightWChar errors |
| R1-R5 (Regression) | All must pass | — |
