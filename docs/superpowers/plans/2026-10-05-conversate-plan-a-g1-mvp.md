# Conversate Plan A — G1 Conversate MVP (touchpad) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A G2-Conversate-style live session on G1 glasses driven by the Helix Android app: live captions, auto-popping AI cues (Concept / Bio / Suggestion + existing Answers), a phone-rendered contextual menu, Prep Notes, all controlled from the G1 touchpad.

**Architecture:** A new pure-Kotlin package `com.artjiang.helix.conversate` holds a state machine (`ConversateSession`) that consumes device-neutral intents and emits a `ScreenModel`; `G1HudComposer` renders that to 5-line text; `ConversateHudDriver` sends it over the existing `G1CommandTransport` with its own persistent lifecycle and a lease from a token-based `HudArbiter`. `ConversateController` wires session + cue engine + captions and is the only thing `HelixBridge` talks to. Shared, language-neutral contract files (menu, prompts, cue schema, test vectors) live in `conversate-core/` at the repo root and are packaged as Java resources.

**Tech Stack:** Kotlin 2 / Android (minSdk 26, target 35), coroutines 1.9, kotlinx.serialization 1.7, Jetpack Compose Material3, JUnit4 + kotlinx-coroutines-test. Gradle 8.11.1 wrapper, AGP 8.7.3, `JAVA_HOME=/opt/homebrew/opt/openjdk@17`.

**Spec:** `docs/superpowers/specs/2026-10-04-conversate-g1-g2-design.md` (Plan A row of §11).

## Global Constraints

- G1 text HUD: **5 lines per screen, ~46 chars per line** (`HudPaginator.LINES_PER_PAGE`, `DEFAULT_MAX_CHARACTERS_PER_LINE`). Never hard-code other line metrics.
- Screens are `0x4E` plain text at screen_status `0x71`, 1-based `currentPage`, per-screen `syncSeq` (use `G1PacketEncoder.encodeTextPage`); clear is `0x18` (`G1CommandEncoder.exitAllFunctions()`). Read `docs/G1_PROTOCOL_SLA.md` before touching bytes.
- HUD glyphs are **ASCII only** until hardware confirms the font (`*`, `>`, `-`, `||`), kept in one `HudGlyphs` object.
- When Conversate is disabled, app behaviour must be byte-for-byte what it is today (legacy touchpad, answer HUD, notifications).
- Cue limits: title ≤ 24 chars, body ≤ 220, detail ≤ 1000; ≤ 1 LLM cue per 8 s (ANSWER exempt); queue max 3 (ANSWER never evicted, may make it 4); cues stale after 90 s; default cue dwell 6 s (range 3–15 s).
- Caption render cadence ≥ 700 ms by default (value replaced by S3 result); intent dedupe window 250 ms; end-session confirm window 3 s.
- Prep Note text ≤ 5,000 chars.
- Build/test: `cd android && JAVA_HOME=/opt/homebrew/opt/openjdk@17 ./gradlew :app:testDebugUnitTest :app:assembleDebug`. Never trust a filtered `--tests` run that reports success in < 2 s — add `--rerun-tasks` when filtering.
- Repo gate before the final commit: `bash scripts/run_gate.sh` (from repo root).
- No `@Composable` or Android imports inside `conversate/` except `ConversateController` (coroutines only) — everything else is plain JVM-testable Kotlin.

## Review Focus

1. **Touchpad leakage** — with Conversate enabled, a long-press must never also fire the legacy manual question, its release must never stop listening, and a double-tap must never send the legacy `ClearHud`. Pinned in Task 13 (`ConversateTouchpadRoutingTest`).
2. **Stale screen after end** — ending a session (glasses BACK-BACK or phone End) must clear the lens and release the lease even if a caption render is mid-flight. Pinned in Task 9 (`driver clears after in-flight send`).
3. **Superseded producer blanking the lens** — an old answer/notification lease releasing after Conversate took the HUD must not clear Conversate's ownership. Pinned in Task 1 (`stale lease release is ignored`).
4. **Model returns prose / fenced JSON / oversized fields** — must be parsed or dropped, never shown raw or overflowing 5 lines. Pinned in Task 10 vectors (`cue-parse-*.json`) and Task 7 (`long title truncated`).
5. **Rapid taps** — five quick NEXTs in a menu must draw the final cursor position only, without a queue of stale renders. Pinned in Task 9 (`latest state wins`).

---

## File Structure

```
conversate-core/                              (repo root, new — shared with Plan D)
  README.md                                   contract overview
  menu.json                                   menu tree for idle/live
  cue-schema.json                             JSON Schema of LLM cue output
  prompts/cues.v1.json                        cue extraction prompt + maxTokens
  vectors/session-*.json                      state-machine vectors
  vectors/cue-parse.json                      parser vectors

android/app/build.gradle.kts                  + resources srcDir ../../conversate-core
android/app/src/main/java/com/artjiang/helix/
  HudArbiter.kt                               MODIFY: leases + Conversate priorities
  core/Domain.kt                              MODIFY: classify(prompt, maxTokens)
  ai/Providers.kt                             MODIFY: classify overrides honour maxTokens
  data/SettingsRepository.kt                  MODIFY: conversate prefs
  HelixBridge.kt                              MODIFY: leases, routing seam, controller wiring
  g1/HudProbe.kt                              NEW: spike tooling (touchpad log, throughput stats)
  conversate/
    ConversateIntent.kt                       intents, sources, G1InputMapper, IntentDeduper
    Cue.kt                                    Cue, CueType, CueQueue
    ScreenModel.kt                            ScreenModel, HudGlyphs
    MenuSpec.kt                               menu.json model + loader
    ConversateSession.kt                      state machine
    G1HudComposer.kt                          ScreenModel -> 5-line text frame
    CaptionBuffer.kt                          partial+final captions -> lines
    ConversateHudDriver.kt                    latest-wins render loop, lease, clear
    CueParser.kt                              LLM JSON -> cues
    CueEngine.kt                              debounce/gating/dedupe, calls classify
    PrepNoteRepository.kt                     PrepNote + JSON store
    ConversateController.kt                   wiring, ticker, effects
  ui/ConversateCard.kt                        NEW: Assistant tab card + HUD preview
  ui/PrepNotesSheet.kt                        NEW: Prep Note list/editor/.txt import
  ui/AssistantScreen.kt                       MODIFY: show ConversateCard
  ui/SettingsScreen.kt                        MODIFY: Conversate section
  ui/DeviceScreen.kt                          MODIFY: probe card (debug)
android/app/src/test/java/com/artjiang/helix/
  HudArbiterTest.kt, HudArbiterAnswerNotificationTest.kt   MODIFY
  g1/HudProbeTest.kt
  conversate/*Test.kt                         one per unit above + SessionVectorTest
```

---

### Task 0: Hardware spike tooling (S2 + S3) and the spike gate

**Files:**
- Create: `android/app/src/main/java/com/artjiang/helix/g1/HudProbe.kt`
- Modify: `android/app/src/main/java/com/artjiang/helix/HelixBridge.kt` (handleInbound ~line 744; new public probe functions)
- Modify: `android/app/src/main/java/com/artjiang/helix/ui/DeviceScreen.kt` (add probe card)
- Test: `android/app/src/test/java/com/artjiang/helix/g1/HudProbeTest.kt`

**Interfaces:**
- Produces: `TouchpadProbeLog(capacity: Int = 60, clock: () -> Long)` with `record(label: String)`, `entries: StateFlow<List<String>>`; `ProbeStats.of(durationsMillis: List<Long>): ProbeStats(count, min, median, p90, max)`; bridge `val probeLog: StateFlow<List<String>>`, `fun runThroughputProbe(screens: Int = 20)`, `val probeResult: StateFlow<String>`.

- [ ] **Step 1: Write the failing test**

```kotlin
package com.artjiang.helix.g1

import org.junit.Assert.assertEquals
import org.junit.Test

class HudProbeTest {
    @Test
    fun `stats compute min median p90 max`() {
        val s = ProbeStats.of(listOf(100L, 300L, 200L, 400L, 500L, 600L, 700L, 800L, 900L, 1000L))
        assertEquals(10, s.count)
        assertEquals(100L, s.min)
        assertEquals(550L, s.median)
        assertEquals(900L, s.p90)
        assertEquals(1000L, s.max)
    }

    @Test
    fun `empty stats are zero`() {
        assertEquals(ProbeStats(0, 0, 0, 0, 0), ProbeStats.of(emptyList()))
    }

    @Test
    fun `log keeps newest entries with relative timestamps`() {
        var now = 1_000L
        val log = TouchpadProbeLog(capacity = 2, clock = { now })
        log.record("a"); now += 150; log.record("b"); now += 50; log.record("c")
        assertEquals(listOf("+150ms b", "+200ms c"), log.entries.value)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd android && JAVA_HOME=/opt/homebrew/opt/openjdk@17 ./gradlew :app:testDebugUnitTest --tests 'com.artjiang.helix.g1.HudProbeTest' --rerun-tasks`
Expected: compilation FAIL (`Unresolved reference: ProbeStats`).

- [ ] **Step 3: Implement**

```kotlin
// Hardware spike tooling for Conversate (spec §10, S2/S3). Debug aid only:
// it records raw touchpad/status frames and measures full-screen send latency
// so the input mapping and caption cadence are set from real G1 behaviour.
package com.artjiang.helix.g1

import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

data class ProbeStats(val count: Int, val min: Long, val median: Long, val p90: Long, val max: Long) {
    fun summary(): String = "n=$count min=${min}ms median=${median}ms p90=${p90}ms max=${max}ms"

    companion object {
        fun of(durationsMillis: List<Long>): ProbeStats {
            if (durationsMillis.isEmpty()) return ProbeStats(0, 0, 0, 0, 0)
            val sorted = durationsMillis.sorted()
            val mid = sorted.size / 2
            val median = if (sorted.size % 2 == 0) (sorted[mid - 1] + sorted[mid]) / 2 else sorted[mid]
            val p90Index = (Math.ceil(sorted.size * 0.9).toInt() - 1).coerceIn(0, sorted.size - 1)
            return ProbeStats(sorted.size, sorted.first(), median, sorted[p90Index], sorted.last())
        }
    }
}

/** Ring buffer of raw inbound events, each stamped relative to the previous one. */
class TouchpadProbeLog(private val capacity: Int = 60, private val clock: () -> Long) {
    private val state = MutableStateFlow<List<String>>(emptyList())
    val entries: StateFlow<List<String>> = state.asStateFlow()
    private var last: Long? = null

    fun record(label: String) {
        val now = clock()
        val delta = last?.let { now - it } ?: 0L
        last = now
        state.value = (state.value + "+${delta}ms $label").takeLast(capacity)
    }
}
```

In `HelixBridge.kt`, add near the other HUD state (after `val hudArbiter = HudArbiter()`):

```kotlin
    private val touchpadProbe = TouchpadProbeLog(clock = System::currentTimeMillis)
    val probeLog: StateFlow<List<String>> = touchpadProbe.entries
    private val probeResultState = MutableStateFlow("")
    val probeResult: StateFlow<String> = probeResultState.asStateFlow()

    /**
     * Spike S3: alternate two full 5-line screens [screens] times and report
     * per-screen send latency (both lenses ACKed). Blanks the lens afterwards.
     */
    fun runThroughputProbe(screens: Int = 20) {
        if (!isGlassesConnected) { probeResultState.value = "Glasses not connected"; return }
        scope.launch {
            val a = (1..5).joinToString("\n") { "Probe line $it ".padEnd(40, 'a') }
            val b = (1..5).joinToString("\n") { "Probe line $it ".padEnd(40, 'b') }
            val durations = mutableListOf<Long>()
            var failures = 0
            repeat(screens) { i ->
                val packets = G1PacketEncoder.encodeTextPage(if (i % 2 == 0) a else b, syncSeq = i.toByte())
                val start = System.currentTimeMillis()
                val outcome = transport.sendScreenDetailed(packets)
                durations += System.currentTimeMillis() - start
                if (outcome.coverage != G1ScreenDeliveryCoverage.BOTH) failures++
            }
            transport.send(G1Command(bytes = G1CommandEncoder.exitAllFunctions()))
            probeResultState.value = ProbeStats.of(durations).summary() + " failures=$failures"
        }
    }
```

(Check the `G1ScreenDeliveryOutcome` property name with `grep -n "val coverage" g1/G1CommandTransport.kt`; use whatever field holds `G1ScreenDeliveryCoverage`.)

In `handleInbound`, immediately after `transport.handleDecoded(status, side)` add:

```kotlin
            if (data.isNotEmpty() && data[0] == 0xF5.toByte() && data.size >= 2) {
                touchpadProbe.record("${side.name} F5 idx=${data[1].toInt() and 0xFF}")
            }
```

In `DeviceScreen.kt`, add at the end of the main column a debug card (inside `if (BuildConfig.DEBUG)`):

```kotlin
        if (BuildConfig.DEBUG) {
            val probeLog by bridge.probeLog.collectAsStateWithLifecycle()
            val probeResult by bridge.probeResult.collectAsStateWithLifecycle()
            HelixSection(title = "Conversate probe", subtitle = "Spikes S2/S3 - debug only") {
                Button(onClick = { bridge.runThroughputProbe() }) { Text("Run throughput probe (20 screens)") }
                if (probeResult.isNotEmpty()) Text(probeResult, style = MaterialTheme.typography.bodySmall)
                Text(
                    probeLog.takeLast(15).joinToString("\n"),
                    style = MaterialTheme.typography.bodySmall,
                    fontFamily = FontFamily.Monospace,
                )
            }
        }
```

(Add imports `com.artjiang.helix.BuildConfig`, `androidx.compose.ui.text.font.FontFamily`, `androidx.compose.material3.Button` as needed; if `buildConfig` is disabled in `build.gradle.kts`, add `buildFeatures { buildConfig = true }`.)

- [ ] **Step 4: Run tests, build**

Run: `cd android && JAVA_HOME=/opt/homebrew/opt/openjdk@17 ./gradlew :app:testDebugUnitTest --tests 'com.artjiang.helix.g1.HudProbeTest' --rerun-tasks :app:assembleDebug`
Expected: PASS, BUILD SUCCESSFUL.

- [ ] **Step 5: Commit**

```bash
git add android/app/src/main/java/com/artjiang/helix/g1/HudProbe.kt android/app/src/test/java/com/artjiang/helix/g1/HudProbeTest.kt android/app/src/main/java/com/artjiang/helix/HelixBridge.kt android/app/src/main/java/com/artjiang/helix/ui/DeviceScreen.kt android/app/build.gradle.kts
git commit -m "feat(conversate): add G1 hardware probe for touchpad and throughput spikes"
```

- [ ] **Step 6: HARDWARE GATE (human + agent)** — install the debug APK, `adb shell am force-stop com.even.g1`, connect G1, open Device tab. Record in the spec §10 a "Results 2026-10-xx" table:
  1. Left long-press, hold 2 s, release → which indices (expect `23` then `24`)? Any firmware UI or mic indicator on the lens?
  2. Right long-press → indices?
  3. Single tap L, single tap R → `1` per side?
  4. Fast double-tap L and R → one `0`, or two `1`s?
  5. Head up / head down while a Helix screen is shown (run probe first) → status frames? Does the firmware dashboard replace the screen?
  6. Throughput probe ×3 → median/p90.

  **Decisions:** if (1) shows firmware UI or no `23`, implement D3 in Task 3 (mapper variant documented there). Set `CAPTION_INTERVAL_DEFAULT_MILLIS` in Task 9 to `max(700, p90 + 100)`. Commit the spec update: `git commit -m "docs: record Conversate S2/S3 hardware results"`.

---

### Task 1: HudArbiter leases and Conversate priorities

**Files:**
- Modify: `android/app/src/main/java/com/artjiang/helix/HudArbiter.kt`
- Modify: `android/app/src/main/java/com/artjiang/helix/HelixBridge.kt:445-446, 799-806, 1989-2005`
- Test: `android/app/src/test/java/com/artjiang/helix/HudArbiterTest.kt`, `HudArbiterAnswerNotificationTest.kt`

**Interfaces:**
- Produces: `HudArbiter.Priority.CONVERSATE_LIVE` (rank 3), `CONVERSATE_INTERACTIVE` (rank 4); `@JvmInline value class HudArbiter.Lease(val generation: Long)`; `suspend fun acquire(priority: Priority, durationMillis: Long = defaultDurationFor(priority)): Lease?`; `suspend fun release(lease: Lease)`; `suspend fun isCurrent(lease: Lease): Boolean`. `requestDisplay(...)` stays (returns `acquire(...) != null`). **`releaseDisplay()` is removed.**

- [ ] **Step 1: Write the failing tests** (append to `HudArbiterTest`)

```kotlin
    @Test
    fun `stale lease release is ignored`() = runTest {
        val arbiter = HudArbiter(FakeClock())
        val old = arbiter.acquire(HudArbiter.Priority.ANSWER)!!
        val conversate = arbiter.acquire(HudArbiter.Priority.CONVERSATE_INTERACTIVE)!!
        arbiter.release(old)
        assertEquals(HudArbiter.Priority.CONVERSATE_INTERACTIVE, arbiter.currentHolder())
        assertTrue(arbiter.isCurrent(conversate))
        arbiter.release(conversate)
        assertNull(arbiter.currentHolder())
    }

    @Test
    fun `interactive conversate refuses notifications and answers`() = runTest {
        val arbiter = HudArbiter(FakeClock())
        arbiter.acquire(HudArbiter.Priority.CONVERSATE_INTERACTIVE)!!
        assertNull(arbiter.acquire(HudArbiter.Priority.NOTIFICATION))
        assertNull(arbiter.acquire(HudArbiter.Priority.ANSWER))
    }

    @Test
    fun `refused acquire returns null and keeps holder`() = runTest {
        val arbiter = HudArbiter(FakeClock())
        arbiter.acquire(HudArbiter.Priority.CONVERSATE_LIVE)!!
        assertNull(arbiter.acquire(HudArbiter.Priority.INSIGHT))
        assertEquals(HudArbiter.Priority.CONVERSATE_LIVE, arbiter.currentHolder())
    }
```

In `HudArbiterTest` line ~73-74 and `HudArbiterAnswerNotificationTest` line ~33-34, replace the `requestDisplay(...)` + `releaseDisplay()` pairs with:

```kotlin
        val lease = arbiter.acquire(HudArbiter.Priority.ANSWER)!!
        arbiter.release(lease)
```

- [ ] **Step 2: Run to verify failure**

Run: `cd android && JAVA_HOME=/opt/homebrew/opt/openjdk@17 ./gradlew :app:testDebugUnitTest --tests 'com.artjiang.helix.HudArbiter*' --rerun-tasks`
Expected: compilation FAIL (`Unresolved reference: acquire`).

- [ ] **Step 3: Implement** — in `HudArbiter.kt`:

```kotlin
    enum class Priority(val rank: Int) {
        INSIGHT(0),
        DASHBOARD(1),
        NOTIFICATION(2),
        ANSWER(3),
        /** Conversate captions/cue cards: same rank as an answer (answers become cues). */
        CONVERSATE_LIVE(3),
        /** Conversate menu/panel/detail the wearer opened: nothing may draw over it. */
        CONVERSATE_INTERACTIVE(4),
    }

    /** Proof of ownership. Only the current lease can release the HUD. */
    @JvmInline
    value class Lease(val generation: Long)

    private var generation: Long = 0

    suspend fun acquire(
        priority: Priority,
        durationMillis: Long = defaultDurationFor(priority),
    ): Lease? = mutex.withLock {
        val now = clock()
        val current = activePriority
        val expired = current == null || activeUntilMillis <= now
        if (current != null && !expired && priority.rank < current.rank) return@withLock null
        activePriority = priority
        activeUntilMillis = now + durationMillis
        generation += 1
        Lease(generation)
    }

    suspend fun requestDisplay(
        priority: Priority,
        durationMillis: Long = defaultDurationFor(priority),
    ): Boolean = acquire(priority, durationMillis) != null

    /** Releases only if [lease] is still the holder; a superseded lease is a no-op. */
    suspend fun release(lease: Lease) = mutex.withLock {
        if (lease.generation != generation) return@withLock
        activePriority = null
        activeUntilMillis = 0
    }

    suspend fun isCurrent(lease: Lease): Boolean = mutex.withLock {
        lease.generation == generation && activePriority != null && activeUntilMillis > clock()
    }
```

Delete the old `requestDisplay` body and `releaseDisplay()`. In `defaultDurationFor`, make `CONVERSATE_LIVE`/`CONVERSATE_INTERACTIVE` return `60_000` (the driver renews on every screen). Keep the existing KDoc about equal-priority replacement on `acquire`.

In `HelixBridge.kt`:

```kotlin
    /** Lease held by [hudSession]'s current answer, if any. */
    @Volatile private var answerLease: HudArbiter.Lease? = null
```

and change the `hudSession` lambdas (line ~445):

```kotlin
        requestDisplay = { hudArbiter.acquire(hudPriority).also { answerLease = it } != null },
        releaseDisplay = { answerLease?.let { hudArbiter.release(it) }; answerLease = null },
```

`ClearHud` branch (~805): replace `hudArbiter.releaseDisplay()` with `answerLease?.let { hudArbiter.release(it) }; answerLease = null`.

`forwardNotificationToGlasses` (~1989-2005):

```kotlin
            val lease = hudArbiter.acquire(HudArbiter.Priority.NOTIFICATION) ?: return@launch
            try {
                notificationSender.sendNotification(/* unchanged args */)
            } finally {
                hudArbiter.release(lease)
            }
```

- [ ] **Step 4: Run all tests**

Run: `cd android && JAVA_HOME=/opt/homebrew/opt/openjdk@17 ./gradlew :app:testDebugUnitTest`
Expected: all PASS (baseline count + 3).

- [ ] **Step 5: Commit**

```bash
git add android/app/src/main/java/com/artjiang/helix/HudArbiter.kt android/app/src/main/java/com/artjiang/helix/HelixBridge.kt android/app/src/test/java/com/artjiang/helix/HudArbiter*.kt
git commit -m "feat(hud): token leases in HudArbiter so stale producers cannot release the HUD"
```

---

### Task 2: `conversate-core/` contract files and resource wiring

**Files:**
- Create: `conversate-core/README.md`, `conversate-core/menu.json`, `conversate-core/cue-schema.json`, `conversate-core/prompts/cues.v1.json`
- Modify: `android/app/build.gradle.kts` (inside `android { }`)
- Create: `android/app/src/main/java/com/artjiang/helix/conversate/MenuSpec.kt`
- Test: `android/app/src/test/java/com/artjiang/helix/conversate/MenuSpecTest.kt`

**Interfaces:**
- Produces: `MenuItemSpec(id, label?, labelOn?, labelOff?, toggle?)`, `MenuItemSpec.render(flags: Map<String, Boolean>): String`; `MenuSpec(version, idle, live)`; `MenuSpec.load(): MenuSpec`; `CuePrompt(version, maxTokens, template)`, `CuePrompt.load(): CuePrompt`, `CuePrompt.render(transcript: String, prepNote: String, shown: List<String>): String`; `ConversateResources.read(path: String): String`.

- [ ] **Step 1: Create contract files**

`conversate-core/README.md`:

```markdown
# Conversate Core

Language-neutral contract shared by the Helix Android G1 app (`android/`) and the
G2 Even Hub app (`evenhub/`, Plan D). Spec:
`docs/superpowers/specs/2026-10-04-conversate-g1-g2-design.md`.

- `menu.json` — menu items by context. Toggle items render `labelOn`/`labelOff`
  from the named flag; others render `label`.
- `prompts/*.json` — LLM prompt templates. `{{name}}` placeholders.
- `cue-schema.json` — JSON Schema the cue prompt must return.
- `vectors/` — behaviour vectors every implementation must pass.

Android packages this directory as Java resources (`build.gradle.kts`), so files
are read with `ClassLoader.getResource("<path>")`. Changing a file here changes
both apps: run both test suites.
```

`conversate-core/menu.json`:

```json
{
  "version": 1,
  "idle": [
    { "id": "start", "label": "Start Conversate" }
  ],
  "live": [
    { "id": "pause", "toggle": "paused", "labelOn": "Resume", "labelOff": "Pause" },
    { "id": "captions", "toggle": "captions", "labelOn": "Captions: on", "labelOff": "Captions: off" },
    { "id": "cues", "toggle": "cues", "labelOn": "Cues: on", "labelOff": "Cues: off" },
    { "id": "prep_note", "label": "Prep Note" },
    { "id": "display_off", "label": "Display off" },
    { "id": "end", "label": "End session" }
  ]
}
```

`conversate-core/cue-schema.json`:

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "title": "Conversate cue extraction output",
  "type": "object",
  "required": ["cues"],
  "properties": {
    "cues": {
      "type": "array",
      "maxItems": 2,
      "items": {
        "type": "object",
        "required": ["type", "title", "body"],
        "properties": {
          "type": { "enum": ["CONCEPT", "BIO", "SUGGESTION"] },
          "title": { "type": "string", "maxLength": 24 },
          "body": { "type": "string", "maxLength": 220 },
          "detail": { "type": "string", "maxLength": 1000 },
          "entity": { "type": "string" }
        }
      }
    }
  }
}
```

`conversate-core/prompts/cues.v1.json`:

```json
{
  "version": 1,
  "maxTokens": 600,
  "template": "You are Conversate, a silent assistant showing short cues on smart glasses during a live conversation.\nPick at most 2 cues that would genuinely help the wearer right now:\n- CONCEPT: explain a term, acronym or idea just mentioned.\n- BIO: who a person or organisation just mentioned is.\n- SUGGESTION: a useful follow-up question, point or next step for the wearer.\nRules: only use things actually said in the transcript; title <= 24 characters; body <= 220 characters, one or two plain sentences, no markdown; optional detail <= 1000 characters; entity = the canonical name the cue is about.\nNever repeat these already-shown cues: {{shown}}\nIf nothing is worth interrupting for, return {\"cues\":[]}.\nReturn ONLY JSON: {\"cues\":[{\"type\":\"CONCEPT|BIO|SUGGESTION\",\"title\":\"...\",\"body\":\"...\",\"detail\":\"...\",\"entity\":\"...\"}]}\n\nPrep note (context from the wearer, may be empty):\n{{prep_note}}\n\nTranscript (most recent last):\n{{transcript}}"
}
```

- [ ] **Step 2: Wire resources** — in `android/app/build.gradle.kts`, inside `android { ... }`:

```kotlin
    sourceSets {
        getByName("main").resources.srcDir("../../conversate-core")
    }
```

- [ ] **Step 3: Write the failing test**

```kotlin
package com.artjiang.helix.conversate

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class MenuSpecTest {
    @Test
    fun `menu loads from conversate-core`() {
        val spec = MenuSpec.load()
        assertEquals(listOf("start"), spec.idle.map { it.id })
        assertEquals(listOf("pause", "captions", "cues", "prep_note", "display_off", "end"), spec.live.map { it.id })
    }

    @Test
    fun `toggle items render from flags`() {
        val pause = MenuSpec.load().live.first { it.id == "pause" }
        assertEquals("Pause", pause.render(mapOf("paused" to false)))
        assertEquals("Resume", pause.render(mapOf("paused" to true)))
    }

    @Test
    fun `cue prompt fills placeholders`() {
        val prompt = CuePrompt.load()
        assertEquals(600, prompt.maxTokens)
        val text = prompt.render(transcript = "We use RAG.", prepNote = "", shown = listOf("RAG"))
        assertTrue(text.contains("We use RAG."))
        assertTrue(text.contains("cues: RAG"))
        assertTrue(!text.contains("{{"))
    }

    @Test
    fun `every menu label fits 32 bytes for the G2 native menu`() {
        val spec = MenuSpec.load()
        (spec.idle + spec.live).flatMap { listOfNotNull(it.label, it.labelOn, it.labelOff) }
            .forEach { assertTrue(it, it.toByteArray().size <= 32) }
    }
}
```

- [ ] **Step 4: Run to verify failure** — `./gradlew :app:testDebugUnitTest --tests 'com.artjiang.helix.conversate.MenuSpecTest' --rerun-tasks` → FAIL (unresolved `MenuSpec`).

- [ ] **Step 5: Implement `MenuSpec.kt`**

```kotlin
// Loads the shared Conversate contract files (conversate-core/, packaged as
// Java resources by build.gradle.kts). Pure JVM: no Android Context needed.
package com.artjiang.helix.conversate

import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json

internal val conversateJson = Json { ignoreUnknownKeys = true }

object ConversateResources {
    fun read(path: String): String {
        val url = ConversateResources::class.java.classLoader?.getResource(path)
            ?: error("conversate-core resource missing: $path")
        return url.readText()
    }
}

@Serializable
data class MenuItemSpec(
    val id: String,
    val label: String? = null,
    val labelOn: String? = null,
    val labelOff: String? = null,
    val toggle: String? = null,
) {
    fun render(flags: Map<String, Boolean>): String =
        if (toggle == null) label ?: id
        else if (flags[toggle] == true) labelOn ?: id
        else labelOff ?: id
}

@Serializable
data class MenuSpec(val version: Int, val idle: List<MenuItemSpec>, val live: List<MenuItemSpec>) {
    companion object {
        fun load(): MenuSpec = conversateJson.decodeFromString(serializer(), ConversateResources.read("menu.json"))
    }
}

@Serializable
data class CuePrompt(val version: Int, val maxTokens: Int, val template: String) {
    fun render(transcript: String, prepNote: String, shown: List<String>): String =
        template
            .replace("{{shown}}", if (shown.isEmpty()) "(none)" else shown.joinToString(", "))
            .replace("{{prep_note}}", prepNote.ifBlank { "(none)" })
            .replace("{{transcript}}", transcript)

    companion object {
        fun load(): CuePrompt = conversateJson.decodeFromString(serializer(), ConversateResources.read("prompts/cues.v1.json"))
    }
}
```

- [ ] **Step 6: Run tests** → PASS. Also `:app:assembleDebug` → BUILD SUCCESSFUL.

- [ ] **Step 7: Commit**

```bash
git add conversate-core android/app/build.gradle.kts android/app/src/main/java/com/artjiang/helix/conversate/MenuSpec.kt android/app/src/test/java/com/artjiang/helix/conversate/MenuSpecTest.kt
git commit -m "feat(conversate): shared conversate-core contract (menu, cue prompt, schema)"
```

---

### Task 3: Intents, G1 input mapping, dedupe

**Files:**
- Create: `android/app/src/main/java/com/artjiang/helix/conversate/ConversateIntent.kt`
- Test: `android/app/src/test/java/com/artjiang/helix/conversate/ConversateIntentTest.kt`

**Interfaces:**
- Consumes: `G1TouchpadFrame(notifyIndex: Int, side: G1TouchpadSide)`, `G1StatusEvent.HeadUp/HeadDown` (package `com.artjiang.helix.g1`).
- Produces: `enum class ConversateIntent { NEXT, PREV, SELECT, BACK, MENU, HEAD_UP, HEAD_DOWN }`, `enum class IntentSource { G1_TOUCHPAD, R1, PHONE }`, `object G1InputMapper { fun map(frame: G1TouchpadFrame, selectContext: Boolean): ConversateIntent?; fun map(event: G1StatusEvent?): ConversateIntent? }`, `class IntentDeduper(clock: () -> Long, windowMillis: Long = 250) { fun accept(intent: ConversateIntent, source: IntentSource): Boolean }`.

- [ ] **Step 1: Write the failing test**

```kotlin
package com.artjiang.helix.conversate

import com.artjiang.helix.g1.G1StatusEvent
import com.artjiang.helix.g1.G1TouchpadFrame
import com.artjiang.helix.g1.G1TouchpadSide
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class ConversateIntentTest {
    private fun f(i: Int, side: G1TouchpadSide = G1TouchpadSide.LEFT) = G1TouchpadFrame(i, side)

    @Test
    fun `taps page, double-tap is back`() {
        assertEquals(ConversateIntent.NEXT, G1InputMapper.map(f(1, G1TouchpadSide.RIGHT), false))
        assertEquals(ConversateIntent.PREV, G1InputMapper.map(f(1, G1TouchpadSide.LEFT), false))
        assertEquals(ConversateIntent.BACK, G1InputMapper.map(f(0), false))
    }

    @Test
    fun `long press is menu outside lists and select inside`() {
        assertEquals(ConversateIntent.MENU, G1InputMapper.map(f(23), selectContext = false))
        assertEquals(ConversateIntent.SELECT, G1InputMapper.map(f(23), selectContext = true))
    }

    @Test
    fun `long press release is swallowed`() {
        assertNull(G1InputMapper.map(f(24), false))
        assertNull(G1InputMapper.map(f(24), true))
    }

    @Test
    fun `head events map`() {
        assertEquals(ConversateIntent.HEAD_UP, G1InputMapper.map(G1StatusEvent.HeadUp))
        assertEquals(ConversateIntent.HEAD_DOWN, G1InputMapper.map(G1StatusEvent.HeadDown))
        assertNull(G1InputMapper.map(null))
    }

    @Test
    fun `same intent from two sources inside window counts once`() {
        var now = 0L
        val d = IntentDeduper(clock = { now })
        assertTrue(d.accept(ConversateIntent.SELECT, IntentSource.R1))
        now = 100
        assertFalse(d.accept(ConversateIntent.SELECT, IntentSource.G1_TOUCHPAD))
        now = 400
        assertTrue(d.accept(ConversateIntent.SELECT, IntentSource.G1_TOUCHPAD))
    }

    @Test
    fun `same source repeats are kept`() {
        var now = 0L
        val d = IntentDeduper(clock = { now })
        assertTrue(d.accept(ConversateIntent.NEXT, IntentSource.G1_TOUCHPAD))
        now = 50
        assertTrue(d.accept(ConversateIntent.NEXT, IntentSource.G1_TOUCHPAD))
    }
}
```

- [ ] **Step 2: Run → FAIL** (unresolved references).

- [ ] **Step 3: Implement**

```kotlin
// Device-neutral input for Conversate (spec §4.1). Every device maps its raw
// gestures to these intents; the state machine never sees raw events.
package com.artjiang.helix.conversate

import com.artjiang.helix.g1.G1StatusEvent
import com.artjiang.helix.g1.G1TouchpadFrame
import com.artjiang.helix.g1.G1TouchpadSide

enum class ConversateIntent { NEXT, PREV, SELECT, BACK, MENU, HEAD_UP, HEAD_DOWN }

enum class IntentSource { G1_TOUCHPAD, R1, PHONE }

/**
 * G1 touchpad -> intent. Indices per SLA: 0 double-tap, 1 tap (side),
 * 23 left long-press, 24 its release. Long-press doubles as SELECT while a
 * list is open because the G1 has no other select gesture; its release (24)
 * is part of the same physical gesture and is swallowed.
 */
object G1InputMapper {
    fun map(frame: G1TouchpadFrame, selectContext: Boolean): ConversateIntent? = when (frame.notifyIndex) {
        0 -> ConversateIntent.BACK
        1 -> if (frame.side == G1TouchpadSide.RIGHT) ConversateIntent.NEXT else ConversateIntent.PREV
        23 -> if (selectContext) ConversateIntent.SELECT else ConversateIntent.MENU
        else -> null
    }

    fun map(event: G1StatusEvent?): ConversateIntent? = when (event) {
        G1StatusEvent.HeadUp -> ConversateIntent.HEAD_UP
        G1StatusEvent.HeadDown -> ConversateIntent.HEAD_DOWN
        else -> null
    }
}

/** Drops the same intent arriving from a different source within [windowMillis]. */
class IntentDeduper(private val clock: () -> Long, private val windowMillis: Long = 250) {
    private var lastIntent: ConversateIntent? = null
    private var lastSource: IntentSource? = null
    private var lastAt: Long = Long.MIN_VALUE / 2

    fun accept(intent: ConversateIntent, source: IntentSource): Boolean {
        val now = clock()
        val duplicate = intent == lastIntent && source != lastSource && now - lastAt < windowMillis
        if (duplicate) return false
        lastIntent = intent
        lastSource = source
        lastAt = now
        return true
    }
}
```

**D3 variant (only if the Task 0 gate says long-press is unusable):** replace the `23` branch with `else -> null` and add a phone-side `G1DoubleTapCounter` (reuse `G1TapCounter` with a 400 ms window) in `ConversateController.handleTouchpad`: two left `1`s → MENU (or SELECT in selectContext), two right `1`s → SELECT; single taps emit NEXT/PREV after the window. Update the first two tests accordingly.

- [ ] **Step 4: Run → PASS.**

- [ ] **Step 5: Commit**

```bash
git add android/app/src/main/java/com/artjiang/helix/conversate/ConversateIntent.kt android/app/src/test/java/com/artjiang/helix/conversate/ConversateIntentTest.kt
git commit -m "feat(conversate): intent model, G1 input mapper and cross-source dedupe"
```

---

### Task 4: Cue model and CueQueue

**Files:**
- Create: `android/app/src/main/java/com/artjiang/helix/conversate/Cue.kt`
- Test: `android/app/src/test/java/com/artjiang/helix/conversate/CueQueueTest.kt`

**Interfaces:**
- Produces: `enum class CueType(val priority: Int, val label: String) { ANSWER(5,"ANSWER"), QUOTE(4,"QUOTE"), HEADLINE(3,"NEWS"), BIO(2,"BIO"), CONCEPT(2,"CONCEPT"), SUGGESTION(1,"IDEA"), NOTICE(0,"NOTE") }`; `data class Cue(id: Long, type: CueType, title: String, body: String, detail: String? = null, entity: String? = null, ticker: String? = null, createdAtMillis: Long)`; `class CueQueue(capacity: Int = 3, staleMillis: Long = 90_000) { val size: Int; fun offer(cue: Cue, now: Long); fun poll(now: Long): Cue?; fun count(now: Long): Int; fun clear() }`.

- [ ] **Step 1: Write the failing test**

```kotlin
package com.artjiang.helix.conversate

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class CueQueueTest {
    private fun cue(id: Long, type: CueType, at: Long = 0) = Cue(id, type, "t$id", "b$id", createdAtMillis = at)

    @Test
    fun `poll returns highest priority, fifo within priority`() {
        val q = CueQueue()
        q.offer(cue(1, CueType.SUGGESTION, 0), 0)
        q.offer(cue(2, CueType.CONCEPT, 1), 1)
        q.offer(cue(3, CueType.BIO, 2), 2)
        assertEquals(2L, q.poll(3)?.id)
        assertEquals(3L, q.poll(3)?.id)
        assertEquals(1L, q.poll(3)?.id)
        assertNull(q.poll(3))
    }

    @Test
    fun `overflow evicts oldest lowest priority`() {
        val q = CueQueue(capacity = 3)
        q.offer(cue(1, CueType.SUGGESTION, 0), 0)
        q.offer(cue(2, CueType.SUGGESTION, 1), 1)
        q.offer(cue(3, CueType.CONCEPT, 2), 2)
        q.offer(cue(4, CueType.CONCEPT, 3), 3)
        assertEquals(3, q.size)
        assertEquals(listOf(3L, 4L, 2L), generateSequence { q.poll(4) }.map { it.id }.toList())
    }

    @Test
    fun `answer is never evicted and may exceed capacity`() {
        val q = CueQueue(capacity = 3)
        repeat(3) { q.offer(cue(it.toLong(), CueType.ANSWER, it.toLong()), it.toLong()) }
        q.offer(cue(9, CueType.ANSWER, 9), 9)
        assertEquals(4, q.size)
        q.offer(cue(10, CueType.CONCEPT, 10), 10)
        assertEquals(4, q.size)
    }

    @Test
    fun `stale cues are dropped`() {
        val q = CueQueue(staleMillis = 90_000)
        q.offer(cue(1, CueType.CONCEPT, 0), 0)
        assertEquals(0, q.count(90_001))
        assertNull(q.poll(90_001))
    }
}
```

- [ ] **Step 2: Run → FAIL.**

- [ ] **Step 3: Implement**

```kotlin
// Conversate cues and the pending-cue queue (spec §4.4 + "Cue queue rules").
package com.artjiang.helix.conversate

enum class CueType(val priority: Int, val label: String) {
    ANSWER(5, "ANSWER"),
    QUOTE(4, "QUOTE"),
    HEADLINE(3, "NEWS"),
    BIO(2, "BIO"),
    CONCEPT(2, "CONCEPT"),
    SUGGESTION(1, "IDEA"),
    NOTICE(0, "NOTE"),
}

data class Cue(
    val id: Long,
    val type: CueType,
    val title: String,
    val body: String,
    val detail: String? = null,
    val entity: String? = null,
    val ticker: String? = null,
    val createdAtMillis: Long,
)

/**
 * Pending cues. Highest priority first, FIFO within a priority. Over
 * [capacity] the oldest lowest-priority non-ANSWER cue is evicted; ANSWERs are
 * never evicted (so the queue may exceed capacity). Cues older than
 * [staleMillis] are dropped on every access.
 */
class CueQueue(private val capacity: Int = 3, private val staleMillis: Long = 90_000) {
    private val items = mutableListOf<Cue>()
    private val order = compareByDescending<Cue> { it.type.priority }.thenBy { it.createdAtMillis }

    val size: Int get() = items.size

    fun offer(cue: Cue, now: Long) {
        prune(now)
        items += cue
        while (items.size > capacity) {
            val victim = items.filter { it.type != CueType.ANSWER }
                .minWithOrNull(compareBy<Cue> { it.type.priority }.thenBy { it.createdAtMillis })
                ?: break
            items.remove(victim)
        }
    }

    fun poll(now: Long): Cue? {
        prune(now)
        val next = items.sortedWith(order).firstOrNull() ?: return null
        items.remove(next)
        return next
    }

    fun count(now: Long): Int { prune(now); return items.size }

    fun clear() = items.clear()

    private fun prune(now: Long) { items.removeAll { now - it.createdAtMillis > staleMillis } }
}
```

- [ ] **Step 4: Run → PASS.**
- [ ] **Step 5: Commit** — `git add` both files; `git commit -m "feat(conversate): cue model and priority queue"`.

---

### Task 5: ScreenModel and the ConversateSession state machine

**Files:**
- Create: `android/app/src/main/java/com/artjiang/helix/conversate/ScreenModel.kt`
- Create: `android/app/src/main/java/com/artjiang/helix/conversate/ConversateSession.kt`
- Test: `android/app/src/test/java/com/artjiang/helix/conversate/ConversateSessionTest.kt`

**Interfaces:**
- Consumes: `MenuSpec`, `CueQueue`, `Cue`, `ConversateIntent`.
- Produces:
  - `sealed interface ScreenModel { data object Blank; data class Live(cue: Cue?, pendingCount: Int, captionLines: List<String>, captionsOn: Boolean, paused: Boolean); data class CueDetail(cue: Cue, page: Int); data class Menu(title: String, items: List<String>, cursor: Int); data class PrepNoteView(title: String, text: String, page: Int); data object ConfirmEnd }` + `val ScreenModel.isInteractive: Boolean` (true for CueDetail, Menu, PrepNoteView, ConfirmEnd).
  - `data class PrepNoteRef(id: String, title: String, text: String)`
  - `data class ConversatePrefs(captionsOn: Boolean = true, cuesOn: Boolean = true, autoPopup: Boolean = true, cueDurationMillis: Long = 6_000)`
  - `sealed interface SessionEffect { data class Start(prepNoteId: String?); data object End; data class SetPaused(paused: Boolean); data class SetCaptions(on: Boolean); data class SetCues(on: Boolean) }`
  - `class ConversateSession(menu: MenuSpec, clock: () -> Long, prefs: ConversatePrefs = ConversatePrefs(), detailPageCount: (Cue) -> Int = { 1 }, textPageCount: (String) -> Int = { 1 })` with `val isLive: Boolean`, `val selectContext: Boolean`, `fun setPrepNotes(notes: List<PrepNoteRef>)`, `fun updatePrefs(prefs: ConversatePrefs)`, `fun startLive(prepNoteId: String?): List<SessionEffect>`, `fun endLive(): List<SessionEffect>`, `fun setPaused(paused: Boolean)`, `fun onIntent(intent: ConversateIntent): List<SessionEffect>`, `fun onCue(cue: Cue)`, `fun onCaptionLines(lines: List<String>)`, `fun tick()`, `fun screen(): ScreenModel`.

- [ ] **Step 1: Write the failing test**

```kotlin
package com.artjiang.helix.conversate

import com.artjiang.helix.conversate.ConversateIntent.BACK
import com.artjiang.helix.conversate.ConversateIntent.MENU
import com.artjiang.helix.conversate.ConversateIntent.NEXT
import com.artjiang.helix.conversate.ConversateIntent.PREV
import com.artjiang.helix.conversate.ConversateIntent.SELECT
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class ConversateSessionTest {
    private var now = 0L
    private fun session(prefs: ConversatePrefs = ConversatePrefs(), pages: Int = 1) =
        ConversateSession(MenuSpec.load(), { now }, prefs, detailPageCount = { pages })
    private fun cue(id: Long, type: CueType = CueType.CONCEPT) = Cue(id, type, "T$id", "B$id", createdAtMillis = now)

    @Test
    fun `idle menu starts a session without prep notes`() {
        val s = session()
        s.onIntent(MENU)
        assertEquals(ScreenModel.Menu("CONVERSATE", listOf("Start Conversate"), 0), s.screen())
        assertTrue(s.selectContext)
        assertEquals(listOf(SessionEffect.Start(null)), s.onIntent(SELECT))
        assertTrue(s.isLive)
        assertTrue(s.screen() is ScreenModel.Live)
    }

    @Test
    fun `start with prep notes shows picker`() {
        val s = session()
        s.setPrepNotes(listOf(PrepNoteRef("n1", "Acme call", "context")))
        s.onIntent(MENU); s.onIntent(SELECT)
        assertEquals(ScreenModel.Menu("PREP NOTE", listOf("Skip & start", "Acme call"), 0), s.screen())
        s.onIntent(NEXT)
        assertEquals(listOf(SessionEffect.Start("n1")), s.onIntent(SELECT))
    }

    @Test
    fun `cue pops, dwells, then collapses to captions`() {
        val s = session(); s.startLive(null)
        s.onCaptionLines(listOf("hello"))
        s.onCue(cue(1))
        assertEquals(cue(1), (s.screen() as ScreenModel.Live).cue)
        now += 6_001; s.tick()
        val live = s.screen() as ScreenModel.Live
        assertEquals(null, live.cue)
        assertEquals(listOf("hello"), live.captionLines)
    }

    @Test
    fun `auto popup off collapses cues to a count`() {
        val s = session(ConversatePrefs(autoPopup = false)); s.startLive(null)
        s.onCue(cue(1)); s.onCue(cue(2))
        assertEquals(2, (s.screen() as ScreenModel.Live).pendingCount)
        s.onIntent(SELECT)
        assertEquals(1L, (s.screen() as ScreenModel.Live).cue?.id)
    }

    @Test
    fun `next on a cue opens paged detail and back returns`() {
        val s = session(pages = 2); s.startLive(null)
        s.onCue(cue(1))
        s.onIntent(NEXT)
        assertEquals(ScreenModel.CueDetail(cue(1), 0), s.screen())
        s.onIntent(NEXT); assertEquals(1, (s.screen() as ScreenModel.CueDetail).page)
        s.onIntent(NEXT); assertEquals(1, (s.screen() as ScreenModel.CueDetail).page)
        s.onIntent(BACK)
        assertEquals(null, (s.screen() as ScreenModel.Live).cue)
    }

    @Test
    fun `cues never interrupt an open menu`() {
        val s = session(); s.startLive(null)
        s.onIntent(MENU)
        s.onCue(cue(1, CueType.ANSWER))
        assertTrue(s.screen() is ScreenModel.Menu)
        s.onIntent(BACK)
        assertEquals(1L, (s.screen() as ScreenModel.Live).cue?.id)
    }

    @Test
    fun `answer preempts a shown concept`() {
        val s = session(); s.startLive(null)
        s.onCue(cue(1)); s.onCue(cue(2, CueType.ANSWER))
        assertEquals(2L, (s.screen() as ScreenModel.Live).cue?.id)
        now += 6_001; s.tick()
        assertEquals(1L, (s.screen() as ScreenModel.Live).cue?.id)
    }

    @Test
    fun `double back ends, timeout cancels`() {
        val s = session(); s.startLive(null)
        s.onIntent(BACK)
        assertEquals(ScreenModel.ConfirmEnd, s.screen())
        now += 3_001; s.tick()
        assertTrue(s.screen() is ScreenModel.Live)
        s.onIntent(BACK)
        assertEquals(listOf(SessionEffect.End), s.onIntent(BACK))
        assertFalse(s.isLive)
        assertEquals(ScreenModel.Blank, s.screen())
    }

    @Test
    fun `live menu toggles emit effects and relabel`() {
        val s = session(); s.startLive(null)
        s.onIntent(MENU)
        assertEquals(listOf(SessionEffect.SetPaused(true)), s.onIntent(SELECT))
        assertEquals("Resume", (s.screen() as ScreenModel.Menu).items[0])
        s.onIntent(NEXT)
        assertEquals(listOf(SessionEffect.SetCaptions(false)), s.onIntent(SELECT))
        repeat(10) { s.onIntent(NEXT) }
        assertEquals(5, (s.screen() as ScreenModel.Menu).cursor)
        assertEquals(listOf(SessionEffect.End), s.onIntent(SELECT))
    }

    @Test
    fun `cues off drops incoming cues`() {
        val s = session(ConversatePrefs(cuesOn = false)); s.startLive(null)
        s.onCue(cue(1))
        assertEquals(null, (s.screen() as ScreenModel.Live).cue)
    }

    @Test
    fun `captions off and nothing to show blanks the lens`() {
        val s = session(ConversatePrefs(captionsOn = false)); s.startLive(null)
        s.onCaptionLines(listOf("x"))
        assertEquals(ScreenModel.Blank, s.screen())
    }

    @Test
    fun `display off blanks until any intent`() {
        val s = session(); s.startLive(null)
        s.onIntent(MENU)
        repeat(4) { s.onIntent(NEXT) }
        s.onIntent(SELECT)
        assertEquals(ScreenModel.Blank, s.screen())
        s.onIntent(PREV)
        assertTrue(s.screen() is ScreenModel.Live)
    }

    @Test
    fun `prep note opens paged view`() {
        val s = session(); s.setPrepNotes(listOf(PrepNoteRef("n1", "Acme", "Ctx")))
        s.startLive("n1")
        s.onIntent(MENU); repeat(3) { s.onIntent(NEXT) }; s.onIntent(SELECT)
        assertEquals(ScreenModel.PrepNoteView("Acme", "Ctx", 0), s.screen())
        s.onIntent(BACK)
        assertTrue(s.screen() is ScreenModel.Live)
    }
}
```

- [ ] **Step 2: Run → FAIL.**

- [ ] **Step 3: Implement `ScreenModel.kt`**

```kotlin
// What Conversate wants on the lens, independent of device (spec §4.2).
package com.artjiang.helix.conversate

sealed interface ScreenModel {
    data object Blank : ScreenModel
    data class Live(
        val cue: Cue?,
        val pendingCount: Int,
        val captionLines: List<String>,
        val captionsOn: Boolean,
        val paused: Boolean,
    ) : ScreenModel
    data class CueDetail(val cue: Cue, val page: Int) : ScreenModel
    data class Menu(val title: String, val items: List<String>, val cursor: Int) : ScreenModel
    data class PrepNoteView(val title: String, val text: String, val page: Int) : ScreenModel
    data object ConfirmEnd : ScreenModel
}

/** Screens the wearer opened; drawn at CONVERSATE_INTERACTIVE and never coalesced away. */
val ScreenModel.isInteractive: Boolean
    get() = this is ScreenModel.CueDetail || this is ScreenModel.Menu ||
        this is ScreenModel.PrepNoteView || this is ScreenModel.ConfirmEnd

data class PrepNoteRef(val id: String, val title: String, val text: String)

data class ConversatePrefs(
    val captionsOn: Boolean = true,
    val cuesOn: Boolean = true,
    val autoPopup: Boolean = true,
    val cueDurationMillis: Long = 6_000,
)

sealed interface SessionEffect {
    data class Start(val prepNoteId: String?) : SessionEffect
    data object End : SessionEffect
    data class SetPaused(val paused: Boolean) : SessionEffect
    data class SetCaptions(val on: Boolean) : SessionEffect
    data class SetCues(val on: Boolean) : SessionEffect
}
```

- [ ] **Step 4: Implement `ConversateSession.kt`**

```kotlin
// Conversate state machine (spec §4.2). Pure and single-threaded: the
// controller calls it from one coroutine context and asks for screen() after
// every input. Timers are driven by tick() against the injected clock.
package com.artjiang.helix.conversate

class ConversateSession(
    private val menu: MenuSpec,
    private val clock: () -> Long,
    prefs: ConversatePrefs = ConversatePrefs(),
    private val detailPageCount: (Cue) -> Int = { 1 },
    private val textPageCount: (String) -> Int = { 1 },
) {
    companion object {
        const val CONFIRM_END_MILLIS = 3_000L
        const val LIVE_TITLE = "CONVERSATE"
        const val PICKER_TITLE = "PREP NOTE"
        const val SKIP_AND_START = "Skip & start"
        const val NO_PREP_NOTE = "No prep note for this session."
    }

    private enum class MenuKind { IDLE, LIVE, PICKER }

    private sealed interface Overlay {
        data class Menu(val kind: MenuKind, val cursor: Int) : Overlay
        data class Detail(val cue: Cue, val page: Int) : Overlay
        data class Prep(val page: Int) : Overlay
        data class Confirm(val until: Long) : Overlay
        data object Off : Overlay
    }

    private var prefs = prefs
    private var overlay: Overlay? = null
    private val queue = CueQueue()
    private var shown: Cue? = null
    private var shownUntil = 0L
    private var captions: List<String> = emptyList()
    private var prepNotes: List<PrepNoteRef> = emptyList()
    private var activePrep: PrepNoteRef? = null
    private var paused = false

    var isLive: Boolean = false
        private set

    /** True while a list is open: G1 long-press means SELECT, not MENU. */
    val selectContext: Boolean get() = overlay is Overlay.Menu

    fun setPrepNotes(notes: List<PrepNoteRef>) { prepNotes = notes }

    fun updatePrefs(prefs: ConversatePrefs) {
        this.prefs = prefs
        if (!prefs.cuesOn) { queue.clear(); shown = null }
    }

    fun setPaused(paused: Boolean) { this.paused = paused }

    fun startLive(prepNoteId: String?): List<SessionEffect> {
        isLive = true
        paused = false
        activePrep = prepNotes.firstOrNull { it.id == prepNoteId }
        queue.clear(); shown = null; captions = emptyList(); overlay = null
        return listOf(SessionEffect.Start(prepNoteId))
    }

    fun endLive(): List<SessionEffect> {
        isLive = false
        queue.clear(); shown = null; captions = emptyList(); overlay = null; activePrep = null
        return listOf(SessionEffect.End)
    }

    fun onCaptionLines(lines: List<String>) { captions = lines }

    fun onCue(cue: Cue) {
        if (!isLive || !prefs.cuesOn) return
        val now = clock()
        val current = currentShown(now)
        if (cue.type == CueType.ANSWER && current != null && current.type != CueType.ANSWER) {
            queue.offer(current, now)
            show(cue, now)
            return
        }
        queue.offer(cue, now)
        promote(now)
    }

    fun tick() {
        val now = clock()
        val o = overlay
        if (o is Overlay.Confirm && now > o.until) overlay = null
        if (shown != null && now >= shownUntil) shown = null
        promote(now)
    }

    /** Applies [intent]; afterwards a waiting cue may surface (e.g. once a menu closes). */
    fun onIntent(intent: ConversateIntent): List<SessionEffect> =
        handle(intent).also { promote(clock()) }

    private fun handle(intent: ConversateIntent): List<SessionEffect> {
        val now = clock()
        when (val o = overlay) {
            Overlay.Off -> { overlay = null; return emptyList() }
            is Overlay.Menu -> return onMenuIntent(o, intent)
            is Overlay.Detail -> {
                when (intent) {
                    ConversateIntent.NEXT -> overlay = o.copy(page = (o.page + 1).coerceAtMost(detailPageCount(o.cue) - 1))
                    ConversateIntent.PREV -> overlay = o.copy(page = (o.page - 1).coerceAtLeast(0))
                    ConversateIntent.BACK -> { overlay = null; shown = null; promote(now) }
                    ConversateIntent.MENU -> overlay = Overlay.Menu(MenuKind.LIVE, 0)
                    else -> Unit
                }
                return emptyList()
            }
            is Overlay.Prep -> {
                val text = activePrep?.text ?: NO_PREP_NOTE
                when (intent) {
                    ConversateIntent.NEXT -> overlay = o.copy(page = (o.page + 1).coerceAtMost(textPageCount(text) - 1))
                    ConversateIntent.PREV -> overlay = o.copy(page = (o.page - 1).coerceAtLeast(0))
                    ConversateIntent.BACK -> overlay = null
                    ConversateIntent.MENU -> overlay = Overlay.Menu(MenuKind.LIVE, 0)
                    else -> Unit
                }
                return emptyList()
            }
            is Overlay.Confirm -> {
                if (intent == ConversateIntent.BACK) return endLive()
                overlay = null
                return emptyList()
            }
            null -> Unit
        }
        if (intent == ConversateIntent.MENU) {
            overlay = Overlay.Menu(if (isLive) MenuKind.LIVE else MenuKind.IDLE, 0)
            return emptyList()
        }
        if (!isLive) return emptyList()
        val current = currentShown(now)
        when (intent) {
            ConversateIntent.NEXT, ConversateIntent.SELECT ->
                if (current != null) overlay = Overlay.Detail(current, 0)
                else queue.poll(now)?.let { show(it, now) }
            ConversateIntent.PREV -> if (current != null) { shown = null; promote(now) }
            ConversateIntent.BACK ->
                if (current != null) { shown = null; promote(now) }
                else overlay = Overlay.Confirm(now + CONFIRM_END_MILLIS)
            else -> Unit
        }
        return emptyList()
    }

    fun screen(): ScreenModel {
        val now = clock()
        return when (val o = overlay) {
            Overlay.Off -> ScreenModel.Blank
            is Overlay.Menu -> ScreenModel.Menu(menuTitle(o.kind), menuLabels(o.kind), o.cursor)
            is Overlay.Detail -> ScreenModel.CueDetail(o.cue, o.page)
            is Overlay.Prep -> ScreenModel.PrepNoteView(activePrep?.title ?: PICKER_TITLE, activePrep?.text ?: NO_PREP_NOTE, o.page)
            is Overlay.Confirm -> ScreenModel.ConfirmEnd
            null -> liveScreen(now)
        }
    }

    private fun liveScreen(now: Long): ScreenModel {
        if (!isLive) return ScreenModel.Blank
        val cue = currentShown(now)
        val pending = if (cue == null && !prefs.autoPopup) queue.count(now) else 0
        if (!paused && cue == null && pending == 0 && !prefs.captionsOn) return ScreenModel.Blank
        return ScreenModel.Live(cue, pending, captions, prefs.captionsOn, paused)
    }

    private fun onMenuIntent(o: Overlay.Menu, intent: ConversateIntent): List<SessionEffect> {
        val labels = menuLabels(o.kind)
        when (intent) {
            ConversateIntent.NEXT -> overlay = o.copy(cursor = (o.cursor + 1).coerceAtMost(labels.size - 1))
            ConversateIntent.PREV -> overlay = o.copy(cursor = (o.cursor - 1).coerceAtLeast(0))
            ConversateIntent.BACK, ConversateIntent.MENU ->
                overlay = if (o.kind == MenuKind.PICKER) Overlay.Menu(MenuKind.IDLE, 0) else null
            ConversateIntent.SELECT -> return activate(o)
            else -> Unit
        }
        return emptyList()
    }

    private fun activate(o: Overlay.Menu): List<SessionEffect> {
        if (o.kind == MenuKind.PICKER) {
            val note = if (o.cursor == 0) null else prepNotes.getOrNull(o.cursor - 1)
            return startLive(note?.id)
        }
        val items = if (o.kind == MenuKind.IDLE) menu.idle else menu.live
        return when (items.getOrNull(o.cursor)?.id) {
            "start" -> if (prepNotes.isEmpty()) startLive(null) else { overlay = Overlay.Menu(MenuKind.PICKER, 0); emptyList() }
            "pause" -> { paused = !paused; listOf(SessionEffect.SetPaused(paused)) }
            "captions" -> { prefs = prefs.copy(captionsOn = !prefs.captionsOn); listOf(SessionEffect.SetCaptions(prefs.captionsOn)) }
            "cues" -> { updatePrefs(prefs.copy(cuesOn = !prefs.cuesOn)); listOf(SessionEffect.SetCues(prefs.cuesOn)) }
            "prep_note" -> { overlay = Overlay.Prep(0); emptyList() }
            "display_off" -> { overlay = Overlay.Off; emptyList() }
            "end" -> endLive()
            else -> emptyList()
        }
    }

    private fun menuTitle(kind: MenuKind) = if (kind == MenuKind.PICKER) PICKER_TITLE else LIVE_TITLE

    private fun menuLabels(kind: MenuKind): List<String> {
        val flags = mapOf("paused" to paused, "captions" to prefs.captionsOn, "cues" to prefs.cuesOn)
        return when (kind) {
            MenuKind.IDLE -> menu.idle.map { it.render(flags) }
            MenuKind.LIVE -> menu.live.map { it.render(flags) }
            MenuKind.PICKER -> listOf(SKIP_AND_START) + prepNotes.map { it.title }
        }
    }

    private fun currentShown(now: Long): Cue? = shown?.takeIf { now < shownUntil }

    private fun show(cue: Cue, now: Long) {
        shown = cue
        shownUntil = now + prefs.cueDurationMillis
    }

    private fun promote(now: Long) {
        if (overlay != null || !prefs.autoPopup || currentShown(now) != null) return
        queue.poll(now)?.let { show(it, now) }
    }
}
```

- [ ] **Step 5: Run → PASS.** If a test fails, fix the implementation, not the test, unless the test contradicts spec §4.2 (then cite the spec line in the commit message).
- [ ] **Step 6: Commit** — `git commit -m "feat(conversate): screen model and session state machine"`.

---

### Task 6: Shared session vectors

**Files:**
- Create: `conversate-core/vectors/session-menu.json`, `conversate-core/vectors/session-cues.json`, `conversate-core/vectors/session-end.json`
- Test: `android/app/src/test/java/com/artjiang/helix/conversate/SessionVectorTest.kt`

**Interfaces:**
- Consumes: `ConversateSession`, `ScreenModel`, `ConversateIntent`, `CueType`.
- Produces: the vector format Plan D re-implements in TypeScript:
  `{ "name", "prefs"?: {captionsOn, cuesOn, autoPopup, cueDurationMillis}, "prepNotes"?: [{id,title,text}], "steps": [ { "advance"?: ms, "intent"?: "NEXT", "cue"?: {id,type,title,body}, "captions"?: [..], "start"?: prepNoteId|null, "tick"?: true, "expect"?: { "kind": "Blank|Live|CueDetail|Menu|PrepNoteView|ConfirmEnd", "cueId"?, "pendingCount"?, "cursor"?, "items"?, "page"?, "live"? }, "effects"?: ["Start:null","End","SetPaused:true"] } ] }`

- [ ] **Step 1: Create vectors**

`conversate-core/vectors/session-menu.json`:

```json
{
  "name": "menu navigation and toggles",
  "steps": [
    { "intent": "MENU", "expect": { "kind": "Menu", "items": ["Start Conversate"], "cursor": 0 } },
    { "intent": "SELECT", "effects": ["Start:null"], "expect": { "kind": "Live", "live": true } },
    { "intent": "MENU", "expect": { "kind": "Menu", "cursor": 0 } },
    { "intent": "NEXT" }, { "intent": "NEXT" }, { "intent": "NEXT" }, { "intent": "NEXT" }, { "intent": "NEXT" }, { "intent": "NEXT" },
    { "expect": { "kind": "Menu", "cursor": 5 } },
    { "intent": "PREV", "expect": { "kind": "Menu", "cursor": 4 } },
    { "intent": "BACK", "expect": { "kind": "Live" } }
  ]
}
```

`conversate-core/vectors/session-cues.json`:

```json
{
  "name": "cue popup, dwell, priority",
  "prefs": { "cueDurationMillis": 6000 },
  "steps": [
    { "start": null },
    { "cue": { "id": 1, "type": "SUGGESTION", "title": "Ask budget", "body": "Ask about budget." }, "expect": { "kind": "Live", "cueId": 1 } },
    { "cue": { "id": 2, "type": "CONCEPT", "title": "RAG", "body": "Retrieval augmented generation." } },
    { "cue": { "id": 3, "type": "ANSWER", "title": "Answer", "body": "Q3 revenue was $4M." }, "expect": { "kind": "Live", "cueId": 3 } },
    { "advance": 6001, "tick": true, "expect": { "kind": "Live", "cueId": 2 } },
    { "intent": "NEXT", "expect": { "kind": "CueDetail", "cueId": 2, "page": 0 } },
    { "intent": "BACK", "expect": { "kind": "Live", "cueId": 1 } }
  ]
}
```

`conversate-core/vectors/session-end.json`:

```json
{
  "name": "end confirm and timeout",
  "steps": [
    { "start": null },
    { "intent": "BACK", "expect": { "kind": "ConfirmEnd" } },
    { "advance": 3001, "tick": true, "expect": { "kind": "Live" } },
    { "intent": "BACK", "expect": { "kind": "ConfirmEnd" } },
    { "intent": "BACK", "effects": ["End"], "expect": { "kind": "Blank", "live": false } }
  ]
}
```

- [ ] **Step 2: Write the runner test**

```kotlin
package com.artjiang.helix.conversate

import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.boolean
import kotlinx.serialization.json.int
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.json.long
import org.junit.Assert.assertEquals
import org.junit.Test

class SessionVectorTest {
    @Test fun menu() = run("vectors/session-menu.json")
    @Test fun cues() = run("vectors/session-cues.json")
    @Test fun end() = run("vectors/session-end.json")

    private fun run(path: String) {
        val root = conversateJson.parseToJsonElement(ConversateResources.read(path)).jsonObject
        val name = root["name"]!!.jsonPrimitive.content
        var now = 0L
        val p = root["prefs"]?.jsonObject
        val prefs = ConversatePrefs(
            captionsOn = p?.get("captionsOn")?.jsonPrimitive?.boolean ?: true,
            cuesOn = p?.get("cuesOn")?.jsonPrimitive?.boolean ?: true,
            autoPopup = p?.get("autoPopup")?.jsonPrimitive?.boolean ?: true,
            cueDurationMillis = p?.get("cueDurationMillis")?.jsonPrimitive?.long ?: 6_000,
        )
        val s = ConversateSession(MenuSpec.load(), { now }, prefs)
        root["prepNotes"]?.jsonArray?.map {
            val o = it.jsonObject
            PrepNoteRef(o["id"]!!.jsonPrimitive.content, o["title"]!!.jsonPrimitive.content, o["text"]!!.jsonPrimitive.content)
        }?.let(s::setPrepNotes)
        root["steps"]!!.jsonArray.forEachIndexed { i, el ->
            val step = el.jsonObject
            val where = "$name step $i"
            step["advance"]?.let { now += it.jsonPrimitive.long }
            var effects = emptyList<SessionEffect>()
            step["start"]?.let { effects = s.startLive(if (it is JsonNull) null else it.jsonPrimitive.content) }
            step["captions"]?.let { s.onCaptionLines(it.jsonArray.map { l -> l.jsonPrimitive.content }) }
            step["cue"]?.jsonObject?.let { c ->
                s.onCue(Cue(c["id"]!!.jsonPrimitive.long, CueType.valueOf(c["type"]!!.jsonPrimitive.content),
                    c["title"]!!.jsonPrimitive.content, c["body"]!!.jsonPrimitive.content, createdAtMillis = now))
            }
            if (step["tick"]?.jsonPrimitive?.boolean == true) s.tick()
            step["intent"]?.let { effects = s.onIntent(ConversateIntent.valueOf(it.jsonPrimitive.content)) }
            step["effects"]?.let { assertEquals(where, it.jsonArray.map { e -> e.jsonPrimitive.content }, effects.map(::label)) }
            step["expect"]?.jsonObject?.let { check(where, it, s) }
        }
    }

    private fun label(e: SessionEffect) = when (e) {
        is SessionEffect.Start -> "Start:${e.prepNoteId}"
        SessionEffect.End -> "End"
        is SessionEffect.SetPaused -> "SetPaused:${e.paused}"
        is SessionEffect.SetCaptions -> "SetCaptions:${e.on}"
        is SessionEffect.SetCues -> "SetCues:${e.on}"
    }

    private fun check(where: String, e: JsonObject, s: ConversateSession) {
        val screen = s.screen()
        e["kind"]?.let { assertEquals(where, it.jsonPrimitive.content, screen::class.simpleName) }
        e["live"]?.let { assertEquals(where, it.jsonPrimitive.boolean, s.isLive) }
        e["cueId"]?.let {
            val id = when (screen) { is ScreenModel.Live -> screen.cue?.id; is ScreenModel.CueDetail -> screen.cue.id; else -> null }
            assertEquals(where, it.jsonPrimitive.long, id)
        }
        e["pendingCount"]?.let { assertEquals(where, it.jsonPrimitive.int, (screen as ScreenModel.Live).pendingCount) }
        e["cursor"]?.let { assertEquals(where, it.jsonPrimitive.int, (screen as ScreenModel.Menu).cursor) }
        e["items"]?.let { assertEquals(where, (it as JsonArray).map { x -> x.jsonPrimitive.content }, (screen as ScreenModel.Menu).items) }
        e["page"]?.let {
            val page = when (screen) { is ScreenModel.CueDetail -> screen.page; is ScreenModel.PrepNoteView -> screen.page; else -> -1 }
            assertEquals(where, it.jsonPrimitive.int, page)
        }
    }
}
```

- [ ] **Step 3: Run** `--tests 'com.artjiang.helix.conversate.SessionVectorTest' --rerun-tasks` → PASS (the state machine already exists; if a vector fails, the vector or session disagrees with spec §4.2 — fix whichever is wrong and note it in the commit).
- [ ] **Step 4: Commit** — `git add conversate-core/vectors android/.../SessionVectorTest.kt`; `git commit -m "test(conversate): shared state-machine vectors"`.

---

### Task 7: G1HudComposer

**Files:**
- Modify: `android/app/src/main/java/com/artjiang/helix/conversate/ScreenModel.kt` (append `HudGlyphs`)
- Create: `android/app/src/main/java/com/artjiang/helix/conversate/G1HudComposer.kt`
- Test: `android/app/src/test/java/com/artjiang/helix/conversate/G1HudComposerTest.kt`

**Interfaces:**
- Consumes: `HudPaginator` (`lines(text): List<String>`, `pages(text): List<String>`, `maxCharactersPerLine`), `ScreenModel`.
- Produces: `object HudGlyphs { CUE = "*"; CURSOR = ">"; MORE = ">>"; RULE = "- - - - - - - - - -"; PAUSED = "||" }`; `data class HudFrame(val text: String, val page: Int = 1, val pageCount: Int = 1)`; `class G1HudComposer(paginator: HudPaginator = HudPaginator()) { fun compose(screen: ScreenModel): HudFrame?; fun detailPageCount(cue: Cue): Int; fun textPageCount(text: String): Int }`. `null` = clear the lens.

- [ ] **Step 1: Write the failing test**

```kotlin
package com.artjiang.helix.conversate

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class G1HudComposerTest {
    private val composer = G1HudComposer()
    private fun cue(title: String = "Fed rate", body: String = "Rates held at 4.25-4.50%.", detail: String? = null) =
        Cue(1, CueType.ANSWER, title, body, detail, createdAtMillis = 0)

    @Test
    fun `live cue card layout`() {
        val f = composer.compose(ScreenModel.Live(cue(), 0, listOf("one", "two"), captionsOn = true, paused = false))!!
        assertEquals("* ANSWER  Fed rate\nRates held at 4.25-4.50%.\n\n- - - - - - - - - -\ntwo", f.text)
    }

    @Test
    fun `cue with detail shows more marker`() {
        val f = composer.compose(ScreenModel.Live(cue(detail = "long"), 0, emptyList(), true, false))!!
        assertTrue(f.text.lines()[1].endsWith(">>"))
    }

    @Test
    fun `long title truncated to the line`() {
        val f = composer.compose(ScreenModel.Live(cue(title = "X".repeat(80)), 0, emptyList(), true, false))!!
        assertTrue(f.text.lines()[0].length <= 46)
        assertTrue(f.text.lines().size <= 5)
    }

    @Test
    fun `captions only shows last five lines`() {
        val lines = (1..7).map { "line $it" }
        val f = composer.compose(ScreenModel.Live(null, 0, lines, true, false))!!
        assertEquals((3..7).joinToString("\n") { "line $it" }, f.text)
    }

    @Test
    fun `pending cues line above four captions`() {
        val f = composer.compose(ScreenModel.Live(null, 2, (1..6).map { "c$it" }, true, false))!!
        assertEquals("* 2 new cues\nc3\nc4\nc5\nc6", f.text)
    }

    @Test
    fun `paused`() {
        val f = composer.compose(ScreenModel.Live(null, 0, emptyList(), true, true))!!
        assertEquals("|| Paused\nHold left pad for menu", f.text)
    }

    @Test
    fun `menu windows four items with cursor and counter`() {
        val items = listOf("A", "B", "C", "D", "E", "F")
        val f = composer.compose(ScreenModel.Menu("CONVERSATE", items, 4))!!
        val lines = f.text.lines()
        assertEquals(3, lines.size)
        assertTrue(lines[0].startsWith("CONVERSATE") && lines[0].endsWith("5/6"))
        assertEquals(listOf("> E", "  F"), lines.drop(1))
    }

    @Test
    fun `detail paginates and reports pages`() {
        val c = cue(detail = (1..60).joinToString(" ") { "word$it" })
        val count = composer.detailPageCount(c)
        assertTrue(count >= 2)
        val f = composer.compose(ScreenModel.CueDetail(c, 1))!!
        assertEquals(2, f.page)
        assertEquals(count, f.pageCount)
    }

    @Test
    fun `blank clears`() { assertNull(composer.compose(ScreenModel.Blank)) }

    @Test
    fun `confirm end`() {
        assertEquals("End session?\n\nDouble-tap again to end\nAny other tap cancels", composer.compose(ScreenModel.ConfirmEnd)!!.text)
    }
}
```

- [ ] **Step 2: Run → FAIL.**

- [ ] **Step 3: Implement** — append to `ScreenModel.kt`:

```kotlin
/** ASCII-only HUD glyphs until the G1 font's coverage is confirmed on hardware. */
object HudGlyphs {
    const val CUE = "*"
    const val CURSOR = ">"
    const val MORE = ">>"
    const val RULE = "- - - - - - - - - -"
    const val PAUSED = "||"
}
```

`G1HudComposer.kt`:

```kotlin
// Renders a ScreenModel to one 5-line G1 text frame (spec §5.2).
package com.artjiang.helix.conversate

import com.artjiang.helix.g1.HudPaginator

data class HudFrame(val text: String, val page: Int = 1, val pageCount: Int = 1)

class G1HudComposer(private val paginator: HudPaginator = HudPaginator()) {
    private val width = paginator.maxCharactersPerLine
    private val rows = paginator.linesPerPage

    fun compose(screen: ScreenModel): HudFrame? = when (screen) {
        ScreenModel.Blank -> null
        is ScreenModel.Live -> live(screen)
        is ScreenModel.Menu -> HudFrame(menu(screen))
        is ScreenModel.CueDetail -> paged(detailText(screen.cue), screen.page)
        is ScreenModel.PrepNoteView -> paged("${screen.title}\n${screen.text}", screen.page)
        ScreenModel.ConfirmEnd -> HudFrame("End session?\n\nDouble-tap again to end\nAny other tap cancels")
    }

    fun detailPageCount(cue: Cue): Int = paginator.pages(detailText(cue)).size.coerceAtLeast(1)

    fun textPageCount(text: String): Int = paginator.pages(text).size.coerceAtLeast(1)

    private fun live(s: ScreenModel.Live): HudFrame? {
        if (s.paused) return HudFrame("${HudGlyphs.PAUSED} Paused\nHold left pad for menu")
        val cue = s.cue
        if (cue != null) {
            val header = fit("${HudGlyphs.CUE} ${cue.type.label}  ${cue.title}")
            val body = paginator.lines(cue.body).toMutableList()
            val more = cue.detail != null || body.size > 2
            val shown = body.take(2).toMutableList()
            while (shown.size < 2) shown += ""
            if (more) {
                val i = shown.indexOfLast { it.isNotEmpty() }.coerceAtLeast(0)
                shown[i] = fit(shown[i], reserve = HudGlyphs.MORE.length + 1) + " " + HudGlyphs.MORE
            }
            val caption = if (s.captionsOn) s.captionLines.lastOrNull().orEmpty() else ""
            return HudFrame(listOf(header, shown[0], shown[1], HudGlyphs.RULE, fit(caption)).joinToString("\n"))
        }
        val captionRows = if (s.captionsOn) s.captionLines.map(::fit) else emptyList()
        if (s.pendingCount > 0) {
            val head = "${HudGlyphs.CUE} ${s.pendingCount} new cue${if (s.pendingCount == 1) "" else "s"}"
            return HudFrame((listOf(head) + captionRows.takeLast(rows - 1)).joinToString("\n"))
        }
        if (captionRows.isEmpty()) return if (s.captionsOn) HudFrame("") else null
        return HudFrame(captionRows.takeLast(rows).joinToString("\n"))
    }

    private fun menu(s: ScreenModel.Menu): String {
        val visible = rows - 1
        val start = (s.cursor / visible) * visible
        val counter = "${s.cursor + 1}/${s.items.size}"
        val title = s.title.take(width - counter.length - 1)
        val header = title + " ".repeat((width - title.length - counter.length).coerceAtLeast(1)) + counter
        val lines = s.items.drop(start).take(visible).mapIndexed { i, item ->
            val prefix = if (start + i == s.cursor) "${HudGlyphs.CURSOR} " else "  "
            fit(prefix + item)
        }
        return (listOf(header) + lines).joinToString("\n")
    }

    private fun detailText(cue: Cue) = "${HudGlyphs.CUE} ${cue.type.label}  ${cue.title}\n${cue.detail ?: cue.body}"

    private fun paged(text: String, page: Int): HudFrame {
        val pages = paginator.pages(text).ifEmpty { listOf("") }
        val index = page.coerceIn(0, pages.size - 1)
        return HudFrame(pages[index], index + 1, pages.size)
    }

    private fun fit(text: String, reserve: Int = 0): String {
        val max = width - reserve
        return if (text.length <= max) text else text.take(max - 1).trimEnd() + "~"
    }
}
```

Note: `paginator.pages(text)` must honour explicit `\n` breaks; verify with `grep -n "fun pages" -A20 android/app/src/main/java/com/artjiang/helix/g1/G1Protocol.kt`. If it collapses newlines, build detail pages as `listOf(header) + paginator.lines(body)` chunked by 5 instead (keep the test).

- [ ] **Step 4: Run → PASS.** Adjust only `fit`/layout code if a golden string differs by whitespace; never weaken the 5-line / 46-char assertions.
- [ ] **Step 5: Commit** — `git commit -m "feat(conversate): G1 5-line HUD composer"`.

---

### Task 8: CaptionBuffer

**Files:**
- Create: `android/app/src/main/java/com/artjiang/helix/conversate/CaptionBuffer.kt`
- Test: `android/app/src/test/java/com/artjiang/helix/conversate/CaptionBufferTest.kt`

**Interfaces:**
- Consumes: `TranscriptSegment(text, isFinal, timestampMillis, ...)` from `com.artjiang.helix.core`, `HudPaginator.lines`.
- Produces: `class CaptionBuffer(paginator: HudPaginator = HudPaginator(), maxLines: Int = 5, keepFinals: Int = 12) { fun onSegment(segment: TranscriptSegment); fun lines(): List<String>; fun clear() }`.

- [ ] **Step 1: Write the failing test**

```kotlin
package com.artjiang.helix.conversate

import com.artjiang.helix.core.TranscriptSegment
import com.artjiang.helix.g1.HudPaginator
import org.junit.Assert.assertEquals
import org.junit.Test

class CaptionBufferTest {
    private fun seg(t: String, final: Boolean) = TranscriptSegment(t, final, 0)

    @Test
    fun `partial replaces partial, final commits`() {
        val b = CaptionBuffer(HudPaginator(maxCharactersPerLine = 20, linesPerPage = 5))
        b.onSegment(seg("hello", false))
        b.onSegment(seg("hello there", false))
        assertEquals(listOf("hello there"), b.lines())
        b.onSegment(seg("Hello there.", true))
        b.onSegment(seg("How", false))
        assertEquals(listOf("Hello there. How"), b.lines())
    }

    @Test
    fun `keeps only the newest lines`() {
        val b = CaptionBuffer(HudPaginator(maxCharactersPerLine = 10, linesPerPage = 5), maxLines = 2)
        listOf("aaaa bbbb", "cccc dddd", "eeee ffff").forEach { b.onSegment(seg(it, true)) }
        assertEquals(listOf("cccc dddd", "eeee ffff"), b.lines())
    }

    @Test
    fun `blank partial ignored and clear empties`() {
        val b = CaptionBuffer()
        b.onSegment(seg("  ", false))
        assertEquals(emptyList<String>(), b.lines())
        b.onSegment(seg("x", true)); b.clear()
        assertEquals(emptyList<String>(), b.lines())
    }
}
```

- [ ] **Step 2: Run → FAIL.**

- [ ] **Step 3: Implement**

```kotlin
// Live caption text for the lens: committed finals plus the current partial,
// word-wrapped to HUD lines (spec §5.3 "Captions use partials").
package com.artjiang.helix.conversate

import com.artjiang.helix.core.TranscriptSegment
import com.artjiang.helix.g1.HudPaginator

class CaptionBuffer(
    private val paginator: HudPaginator = HudPaginator(),
    private val maxLines: Int = 5,
    private val keepFinals: Int = 12,
) {
    private val finals = ArrayDeque<String>()
    private var partial = ""

    fun onSegment(segment: TranscriptSegment) {
        val text = segment.text.trim()
        if (segment.isFinal) {
            if (text.isNotEmpty()) finals.addLast(text)
            while (finals.size > keepFinals) finals.removeFirst()
            partial = ""
        } else {
            partial = text
        }
    }

    fun lines(): List<String> {
        val joined = (finals + partial).filter { it.isNotBlank() }.joinToString(" ")
        if (joined.isBlank()) return emptyList()
        return paginator.lines(joined).takeLast(maxLines)
    }

    fun clear() { finals.clear(); partial = "" }
}
```

- [ ] **Step 4: Run → PASS.** (If the HudPaginator constructor parameter names differ, use the names from `G1Protocol.kt:329`.)
- [ ] **Step 5: Commit** — `git commit -m "feat(conversate): caption buffer with partials"`.

---

### Task 9: ConversateHudDriver

**Files:**
- Create: `android/app/src/main/java/com/artjiang/helix/conversate/ConversateHudDriver.kt`
- Test: `android/app/src/test/java/com/artjiang/helix/conversate/ConversateHudDriverTest.kt`

**Interfaces:**
- Consumes: `HudArbiter.acquire/release/Lease`, `G1PacketEncoder.encodeTextPage(text, currentPage, maxPage, screenStatus, syncSeq)`, `G1ScreenDeliveryOutcome`, `HudFrame`.
- Produces: `class ConversateHudDriver(scope: CoroutineScope, sendScreen: suspend (List<ByteArray>) -> G1ScreenDeliveryOutcome, clearScreen: suspend () -> Unit, arbiter: HudArbiter, clock: () -> Long, captionIntervalMillis: () -> Long = { CAPTION_INTERVAL_DEFAULT_MILLIS })` with `fun submit(frame: HudFrame?, interactive: Boolean)`, `suspend fun shutdown()`, `val lastSentText: StateFlow<String?>`; `companion const val CAPTION_INTERVAL_DEFAULT_MILLIS = 700L`.

- [ ] **Step 1: Write the failing test**

```kotlin
package com.artjiang.helix.conversate

import com.artjiang.helix.HudArbiter
import com.artjiang.helix.g1.G1ScreenDeliveryOutcome
import kotlinx.coroutines.delay
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.advanceTimeBy
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class ConversateHudDriverTest {
    private class Rig(scope: TestScope, sendMillis: Long = 300) {
        val sent = mutableListOf<String>()
        var clears = 0
        val arbiter = HudArbiter { scope.testScheduler.currentTime }
        val driver = ConversateHudDriver(
            scope = scope.backgroundScope,
            sendScreen = { packets ->
                delay(sendMillis)
                sent += String(packets.first().copyOfRange(9, packets.first().size))
                G1ScreenDeliveryOutcome.deliveredToBoth(packets.size)
            },
            clearScreen = { clears++ },
            arbiter = arbiter,
            clock = { scope.testScheduler.currentTime },
        )
    }

    @Test
    fun `latest state wins over a burst`() = runTest {
        val rig = Rig(this)
        rig.driver.submit(HudFrame("m0"), interactive = true)
        runCurrent()
        (1..5).forEach { rig.driver.submit(HudFrame("m$it"), interactive = true) }
        advanceTimeBy(2_000)
        assertEquals(listOf("m0", "m5"), rig.sent)
    }

    @Test
    fun `identical frames are not resent`() = runTest {
        val rig = Rig(this)
        rig.driver.submit(HudFrame("a"), true); advanceTimeBy(1_000)
        rig.driver.submit(HudFrame("a"), true); advanceTimeBy(1_000)
        assertEquals(listOf("a"), rig.sent)
    }

    @Test
    fun `captions are spaced by the interval, interactive is immediate`() = runTest {
        val rig = Rig(this, sendMillis = 100)
        rig.driver.submit(HudFrame("c1"), false); advanceTimeBy(150)
        rig.driver.submit(HudFrame("c2"), false); advanceTimeBy(300)
        assertEquals(listOf("c1"), rig.sent)
        advanceTimeBy(500)
        assertEquals(listOf("c1", "c2"), rig.sent)
        rig.driver.submit(HudFrame("c3"), false); advanceTimeBy(50)
        rig.driver.submit(HudFrame("menu"), true); advanceTimeBy(150)
        assertEquals(listOf("c1", "c2", "menu"), rig.sent)
    }

    @Test
    fun `driver clears after in-flight send and releases the lease`() = runTest {
        val rig = Rig(this)
        rig.driver.submit(HudFrame("x"), false); runCurrent()
        rig.driver.submit(null, true)
        advanceTimeBy(1_000)
        assertEquals(listOf("x"), rig.sent)
        assertEquals(1, rig.clears)
        assertNull(rig.arbiter.currentHolder())
    }

    @Test
    fun `refused lease skips the draw`() = runTest {
        val rig = Rig(this)
        rig.arbiter.acquire(HudArbiter.Priority.CONVERSATE_INTERACTIVE)
        rig.driver.submit(HudFrame("caption"), false); advanceTimeBy(1_000)
        assertEquals(emptyList<String>(), rig.sent)
    }

    @Test
    fun `shutdown clears and releases`() = runTest {
        val rig = Rig(this)
        rig.driver.submit(HudFrame("x"), true); advanceTimeBy(1_000)
        rig.driver.shutdown()
        assertEquals(1, rig.clears)
        assertNull(rig.arbiter.currentHolder())
    }
}
```

- [ ] **Step 2: Run → FAIL.**

- [ ] **Step 3: Implement**

```kotlin
// Sends Conversate screens to the G1 (spec §5.3). Renders STATE, not events:
// a conflated slot means a burst of updates draws only the newest frame.
// Persistent: nothing here blanks the lens on a timer — clearing happens only
// when the session submits a null frame (or shutdown()).
package com.artjiang.helix.conversate

import com.artjiang.helix.HudArbiter
import com.artjiang.helix.g1.G1PacketEncoder
import com.artjiang.helix.g1.G1ScreenDeliveryOutcome
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withTimeoutOrNull

class ConversateHudDriver(
    scope: CoroutineScope,
    private val sendScreen: suspend (List<ByteArray>) -> G1ScreenDeliveryOutcome,
    private val clearScreen: suspend () -> Unit,
    private val arbiter: HudArbiter,
    private val clock: () -> Long,
    private val captionIntervalMillis: () -> Long = { CAPTION_INTERVAL_DEFAULT_MILLIS },
) {
    companion object {
        /** Replace with max(700, S3 p90 + 100) once spike S3 is recorded. */
        const val CAPTION_INTERVAL_DEFAULT_MILLIS = 700L
    }

    private data class Submission(val frame: HudFrame?, val interactive: Boolean)
    private object Unset

    private val slot = Channel<Submission>(Channel.CONFLATED)
    private val lock = Mutex()
    private var lease: HudArbiter.Lease? = null
    private var last: Any? = Unset
    private var lastSentAt = Long.MIN_VALUE / 2
    private var syncSeq = 0
    private val lastSentState = MutableStateFlow<String?>(null)
    val lastSentText: StateFlow<String?> = lastSentState.asStateFlow()

    init {
        scope.launch {
            for (first in slot) {
                var next = first
                // A caption waits out the cadence; anything newer replaces it,
                // and an interactive screen (or a clear) ends the wait at once.
                while (!next.interactive && next.frame != null) {
                    val wait = lastSentAt + captionIntervalMillis() - clock()
                    if (wait <= 0) break
                    next = withTimeoutOrNull(wait) { slot.receive() } ?: break
                }
                lock.withLock { draw(next) }
            }
        }
    }

    fun submit(frame: HudFrame?, interactive: Boolean) {
        slot.trySend(Submission(frame, interactive))
    }

    /** Clears the lens and gives the HUD back. Safe to call repeatedly. */
    suspend fun shutdown() = lock.withLock {
        if (last != null && last !== Unset) clearScreen()
        lease?.let { arbiter.release(it) }
        lease = null
        last = Unset
        lastSentState.value = null
    }

    private suspend fun draw(s: Submission) {
        if (s.frame == last) return
        if (s.frame == null) {
            clearScreen()
            lease?.let { arbiter.release(it) }
            lease = null
            last = null
            lastSentState.value = null
            return
        }
        val priority = if (s.interactive) HudArbiter.Priority.CONVERSATE_INTERACTIVE else HudArbiter.Priority.CONVERSATE_LIVE
        val granted = arbiter.acquire(priority) ?: return
        lease = granted
        syncSeq = (syncSeq + 1) and 0xFF
        val packets = G1PacketEncoder.encodeTextPage(
            text = s.frame.text,
            currentPage = s.frame.page,
            maxPage = s.frame.pageCount,
            syncSeq = syncSeq.toByte(),
        )
        sendScreen(packets)
        last = s.frame
        lastSentAt = clock()
        lastSentState.value = s.frame.text
    }
}
```

- [ ] **Step 4: Run → PASS.** If the "in-flight then clear" case races, confirm the conflated channel delivers the `null` submission after the in-flight `draw` returns (the lock guarantees ordering).
- [ ] **Step 5: Commit** — `git commit -m "feat(conversate): latest-wins HUD driver with lease ownership"`.

---

### Task 10: classify token budget, CueParser and parser vectors

**Files:**
- Modify: `android/app/src/main/java/com/artjiang/helix/core/Domain.kt:201` (classify signature)
- Modify: `android/app/src/main/java/com/artjiang/helix/ai/Providers.kt:490, 632` (both overrides)
- Create: `android/app/src/main/java/com/artjiang/helix/conversate/CueParser.kt`
- Create: `conversate-core/vectors/cue-parse.json`
- Test: `android/app/src/test/java/com/artjiang/helix/conversate/CueParserTest.kt`

**Interfaces:**
- Produces: `AnswerProvider.classify(prompt: String, maxTokens: Int = 120): String`; `data class ParsedCue(type: CueType, title: String, body: String, detail: String?, entity: String?)`; `object CueParser { fun parse(raw: String, allowed: Set<CueType> = setOf(CueType.CONCEPT, CueType.BIO, CueType.SUGGESTION)): List<ParsedCue>? }` — `null` means rejected (malformed).

- [ ] **Step 1: classify signature** — in `Domain.kt` change the interface method to

```kotlin
    suspend fun classify(prompt: String, maxTokens: Int = 120): String =
```

(keep the existing default body). In both `Providers.kt` overrides change the signature to `override suspend fun classify(prompt: String, maxTokens: Int): String` and replace `CLASSIFY_MAX_TOKENS` inside them with `maxTokens`. Run `grep -rn "classify(" android/app/src` and fix any compile error (callers passing one argument keep working through the default). Run the full suite: PASS, unchanged count.

- [ ] **Step 2: Create `conversate-core/vectors/cue-parse.json`**

```json
[
  { "name": "plain", "raw": "{\"cues\":[{\"type\":\"CONCEPT\",\"title\":\"RAG\",\"body\":\"Retrieval augmented generation.\",\"entity\":\"RAG\"}]}", "titles": ["RAG"] },
  { "name": "fenced", "raw": "```json\n{\"cues\":[{\"type\":\"BIO\",\"title\":\"Jensen Huang\",\"body\":\"Nvidia CEO.\"}]}\n```", "titles": ["Jensen Huang"] },
  { "name": "prose around json", "raw": "Sure! {\"cues\":[{\"type\":\"SUGGESTION\",\"title\":\"Ask timeline\",\"body\":\"Ask when it ships.\"}]} Hope that helps", "titles": ["Ask timeline"] },
  { "name": "empty", "raw": "{\"cues\":[]}", "titles": [] },
  { "name": "unknown type skipped", "raw": "{\"cues\":[{\"type\":\"ANSWER\",\"title\":\"x\",\"body\":\"y\"},{\"type\":\"concept\",\"title\":\"API\",\"body\":\"Interface.\"}]}", "titles": ["API"] },
  { "name": "blank body skipped", "raw": "{\"cues\":[{\"type\":\"CONCEPT\",\"title\":\"x\",\"body\":\"  \"}]}", "titles": [] },
  { "name": "oversize truncated", "raw": "{\"cues\":[{\"type\":\"CONCEPT\",\"title\":\"ABCDEFGHIJKLMNOPQRSTUVWXYZ123\",\"body\":\"b\"}]}", "titles": ["ABCDEFGHIJKLMNOPQRSTUVW~"] },
  { "name": "prose only", "raw": "I could not find anything.", "rejected": true },
  { "name": "broken json", "raw": "{\"cues\":[{\"type\":", "rejected": true }
]
```

- [ ] **Step 3: Write the failing test**

```kotlin
package com.artjiang.helix.conversate

import kotlinx.serialization.json.boolean
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class CueParserTest {
    @Test
    fun `shared parse vectors`() {
        val cases = conversateJson.parseToJsonElement(ConversateResources.read("vectors/cue-parse.json")).jsonArray
        cases.forEach { el ->
            val c = el.jsonObject
            val name = c["name"]!!.jsonPrimitive.content
            val result = CueParser.parse(c["raw"]!!.jsonPrimitive.content)
            if (c["rejected"]?.jsonPrimitive?.boolean == true) {
                assertNull(name, result)
            } else {
                assertEquals(name, c["titles"]!!.jsonArray.map { it.jsonPrimitive.content }, result!!.map { it.title })
            }
        }
    }

    @Test
    fun `fields are bounded`() {
        val raw = """{"cues":[{"type":"CONCEPT","title":"t","body":"${"b".repeat(400)}","detail":"${"d".repeat(2000)}"}]}"""
        val cue = CueParser.parse(raw)!!.single()
        assertTrue(cue.body.length <= 220)
        assertTrue(cue.detail!!.length <= 1000)
    }
}
```

- [ ] **Step 4: Run → FAIL.**

- [ ] **Step 5: Implement `CueParser.kt`**

```kotlin
// Parses the cue-extraction model output (conversate-core/cue-schema.json).
// Tolerates code fences and surrounding prose; anything else is rejected and
// never shown on the lens.
package com.artjiang.helix.conversate

import kotlinx.serialization.Serializable

data class ParsedCue(val type: CueType, val title: String, val body: String, val detail: String?, val entity: String?)

object CueParser {
    const val TITLE_MAX = 24
    const val BODY_MAX = 220
    const val DETAIL_MAX = 1000

    @Serializable private data class RawCue(
        val type: String = "",
        val title: String = "",
        val body: String = "",
        val detail: String? = null,
        val entity: String? = null,
    )

    @Serializable private data class Envelope(val cues: List<RawCue> = emptyList())

    fun parse(
        raw: String,
        allowed: Set<CueType> = setOf(CueType.CONCEPT, CueType.BIO, CueType.SUGGESTION),
    ): List<ParsedCue>? {
        val start = raw.indexOf('{')
        val end = raw.lastIndexOf('}')
        if (start < 0 || end <= start) return null
        val envelope = runCatching {
            conversateJson.decodeFromString(Envelope.serializer(), raw.substring(start, end + 1))
        }.getOrNull() ?: return null
        return envelope.cues.mapNotNull { c ->
            val type = runCatching { CueType.valueOf(c.type.trim().uppercase()) }.getOrNull()
            if (type == null || type !in allowed) return@mapNotNull null
            val title = c.title.trim()
            val body = c.body.trim()
            if (title.isEmpty() || body.isEmpty()) return@mapNotNull null
            ParsedCue(
                type = type,
                title = bound(title, TITLE_MAX),
                body = bound(body, BODY_MAX),
                detail = c.detail?.trim()?.takeIf { it.isNotEmpty() }?.let { bound(it, DETAIL_MAX) },
                entity = c.entity?.trim()?.takeIf { it.isNotEmpty() },
            )
        }
    }

    private fun bound(text: String, max: Int) = if (text.length <= max) text else text.take(max - 1) + "~"
}
```

- [ ] **Step 6: Run → PASS** (full suite).
- [ ] **Step 7: Commit** — `git commit -m "feat(conversate): cue parser with shared vectors; classify token budget"`.

---

### Task 11: CueEngine

**Files:**
- Create: `android/app/src/main/java/com/artjiang/helix/conversate/CueEngine.kt`
- Test: `android/app/src/test/java/com/artjiang/helix/conversate/CueEngineTest.kt`

**Interfaces:**
- Consumes: `CuePrompt`, `CueParser.parse`, `Cue`.
- Produces: `class CueEngine(scope: CoroutineScope, classify: suspend (String, Int) -> String, prompt: CuePrompt, clock: () -> Long, emit: (Cue) -> Unit, debounceMillis: Long = 1_500, minGapMillis: Long = 8_000, windowMillis: Long = 60_000)` with `fun onFinal(text: String)`, `fun setPrepNote(text: String?)`, `fun reset()`, `val failures: StateFlow<Int>`, `fun nextCueId(): Long` (shared id source for ANSWER/NOTICE cues).

- [ ] **Step 1: Write the failing test**

```kotlin
package com.artjiang.helix.conversate

import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.advanceTimeBy
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class CueEngineTest {
    private class Rig(scope: TestScope, var reply: () -> String) {
        val emitted = mutableListOf<Cue>()
        val prompts = mutableListOf<String>()
        val engine = CueEngine(
            scope = scope.backgroundScope,
            classify = { p, _ -> prompts += p; reply() },
            prompt = CuePrompt(1, 600, "S={{shown}} P={{prep_note}} T={{transcript}}"),
            clock = { scope.testScheduler.currentTime },
            emit = { emitted += it },
        )
    }
    private fun json(vararg titles: String) =
        """{"cues":[${titles.joinToString(",") { """{"type":"CONCEPT","title":"$it","body":"b $it","entity":"$it"}""" }}]}"""

    @Test
    fun `debounces finals into one call`() = runTest {
        val rig = Rig(this) { json("RAG") }
        rig.engine.onFinal("We use"); advanceTimeBy(500)
        rig.engine.onFinal("RAG here."); advanceTimeBy(1_600)
        assertEquals(1, rig.prompts.size)
        assertTrue(rig.prompts[0].contains("We use RAG here."))
        assertEquals(listOf("RAG"), rig.emitted.map { it.title })
    }

    @Test
    fun `at most one cue per gap and no repeats`() = runTest {
        val rig = Rig(this) { json("RAG", "API") }
        rig.engine.onFinal("a"); advanceTimeBy(1_600)
        assertEquals(listOf("RAG"), rig.emitted.map { it.title })
        rig.engine.onFinal("b"); advanceTimeBy(1_600)
        assertEquals(1, rig.emitted.size)
        advanceTimeBy(8_000); rig.engine.onFinal("c"); advanceTimeBy(1_600)
        assertEquals(listOf("RAG", "API"), rig.emitted.map { it.title })
        assertTrue(rig.prompts.last().contains("S=RAG"))
    }

    @Test
    fun `failures are counted and reset on success`() = runTest {
        var fail = true
        val rig = Rig(this) { if (fail) error("boom") else json("X") }
        repeat(3) { rig.engine.onFinal("t$it"); advanceTimeBy(1_600) }
        assertEquals(3, rig.engine.failures.value)
        fail = false
        rig.engine.onFinal("ok"); advanceTimeBy(1_600)
        assertEquals(0, rig.engine.failures.value)
    }

    @Test
    fun `malformed output emits nothing`() = runTest {
        val rig = Rig(this) { "no json" }
        rig.engine.onFinal("x"); advanceTimeBy(1_600)
        assertEquals(0, rig.emitted.size)
    }

    @Test
    fun `transcript window drops old text and prep note is included`() = runTest {
        val rig = Rig(this) { json() }
        rig.engine.setPrepNote("Acme deal")
        rig.engine.onFinal("old"); advanceTimeBy(61_000)
        rig.engine.onFinal("new"); advanceTimeBy(1_600)
        assertTrue(rig.prompts.last().contains("T=new"))
        assertTrue(rig.prompts.last().contains("P=Acme deal"))
    }
}
```

- [ ] **Step 2: Run → FAIL.**

- [ ] **Step 3: Implement**

```kotlin
// Turns the live transcript into Conversate cues (spec §5.4): debounce finals,
// one LLM call over the last minute + Prep Note, at most one new cue per
// [minGapMillis], never the same entity twice per session.
package com.artjiang.helix.conversate

import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import java.util.concurrent.atomic.AtomicLong

class CueEngine(
    private val scope: CoroutineScope,
    private val classify: suspend (String, Int) -> String,
    private val prompt: CuePrompt,
    private val clock: () -> Long,
    private val emit: (Cue) -> Unit,
    private val debounceMillis: Long = 1_500,
    private val minGapMillis: Long = 8_000,
    private val windowMillis: Long = 60_000,
) {
    private data class Line(val text: String, val at: Long)

    private val window = ArrayDeque<Line>()
    private val shownKeys = linkedSetOf<String>()
    private val shownTitles = mutableListOf<String>()
    private var prepNote: String = ""
    private var lastEmitAt = Long.MIN_VALUE / 2
    private var pending: Job? = null
    private val ids = AtomicLong(0)
    private val failureState = MutableStateFlow(0)
    val failures: StateFlow<Int> = failureState.asStateFlow()

    fun nextCueId(): Long = ids.incrementAndGet()

    fun setPrepNote(text: String?) { prepNote = text.orEmpty() }

    fun reset() {
        pending?.cancel()
        window.clear(); shownKeys.clear(); shownTitles.clear()
        lastEmitAt = Long.MIN_VALUE / 2
        failureState.value = 0
    }

    fun onFinal(text: String) {
        val trimmed = text.trim()
        if (trimmed.isEmpty()) return
        window.addLast(Line(trimmed, clock()))
        pending?.cancel()
        pending = scope.launch {
            delay(debounceMillis)
            run()
        }
    }

    private suspend fun run() {
        val now = clock()
        while (window.isNotEmpty() && now - window.first().at > windowMillis) window.removeFirst()
        if (window.isEmpty() || now - lastEmitAt < minGapMillis) return
        val text = prompt.render(
            transcript = window.joinToString(" ") { it.text },
            prepNote = prepNote,
            shown = shownTitles,
        )
        val raw = runCatching { classify(text, prompt.maxTokens) }.getOrElse {
            failureState.value += 1
            return
        }
        failureState.value = 0
        val parsed = CueParser.parse(raw) ?: return
        val fresh = parsed.firstOrNull { key(it) !in shownKeys } ?: return
        shownKeys += key(fresh)
        shownTitles += fresh.title
        lastEmitAt = clock()
        emit(Cue(nextCueId(), fresh.type, fresh.title, fresh.body, fresh.detail, fresh.entity, createdAtMillis = lastEmitAt))
    }

    private fun key(c: ParsedCue) = (c.entity ?: c.title).lowercase().trim()
}
```

- [ ] **Step 4: Run → PASS.**
- [ ] **Step 5: Commit** — `git commit -m "feat(conversate): cue engine with debounce, gating and dedupe"`.

---

### Task 12: Prep Notes and Conversate settings

**Files:**
- Create: `android/app/src/main/java/com/artjiang/helix/conversate/PrepNoteRepository.kt`
- Modify: `android/app/src/main/java/com/artjiang/helix/data/SettingsRepository.kt` (after `setSessionTapToggleEnabled`, keys near line 287, defaults near 294)
- Test: `android/app/src/test/java/com/artjiang/helix/conversate/PrepNoteRepositoryTest.kt`

**Interfaces:**
- Produces: `@Serializable data class PrepNote(id: String, title: String, text: String, updatedAtMillis: Long)` with `fun toRef(): PrepNoteRef`; `class PrepNoteRepository(file: File, scope: CoroutineScope) { val notes: StateFlow<List<PrepNote>>; suspend fun upsert(note: PrepNote); suspend fun delete(id: String); suspend fun loaded(): List<PrepNote>; companion { const val MAX_CHARS = 5_000; fun new(title: String, text: String, now: Long): PrepNote } }`. Settings: `conversateEnabled: Flow<Boolean>` (default false), `conversatePrefs: Flow<ConversatePrefs>`, `suspend fun setConversateEnabled(Boolean)`, `suspend fun setConversatePrefs(ConversatePrefs)`.

- [ ] **Step 1: Write the failing test**

```kotlin
package com.artjiang.helix.conversate

import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder

class PrepNoteRepositoryTest {
    @get:Rule val tmp = TemporaryFolder()

    @Test
    fun `upsert, persist, reload, delete`() = runTest {
        val file = tmp.newFile("prep.json").also { it.delete() }
        val repo = PrepNoteRepository(file, backgroundScope)
        val note = PrepNoteRepository.new("Acme", "Context", now = 1)
        repo.upsert(note)
        repo.upsert(note.copy(text = "Updated"))
        assertEquals(listOf("Updated"), repo.loaded().map { it.text })
        val reopened = PrepNoteRepository(file, backgroundScope)
        assertEquals(listOf("Acme"), reopened.loaded().map { it.title })
        reopened.delete(note.id)
        assertEquals(emptyList<PrepNote>(), reopened.loaded())
    }

    @Test
    fun `text is capped at 5000 chars`() {
        val note = PrepNoteRepository.new("t", "x".repeat(6_000), now = 0)
        assertEquals(5_000, note.text.length)
    }
}
```

- [ ] **Step 2: Run → FAIL.**

- [ ] **Step 3: Implement `PrepNoteRepository.kt`**

```kotlin
// Prep Notes: wearer-supplied context loaded into a Conversate session.
package com.artjiang.helix.conversate

import com.artjiang.helix.data.JsonFileStore
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.flow.StateFlow
import kotlinx.serialization.Serializable
import java.io.File
import java.util.UUID

@Serializable
data class PrepNote(val id: String, val title: String, val text: String, val updatedAtMillis: Long) {
    fun toRef() = PrepNoteRef(id, title, text)
}

class PrepNoteRepository(file: File, scope: CoroutineScope) {
    companion object {
        const val MAX_CHARS = 5_000
        fun new(title: String, text: String, now: Long) =
            PrepNote(UUID.randomUUID().toString(), title.trim().ifEmpty { "Untitled" }, text.take(MAX_CHARS), now)
    }

    private val store = JsonFileStore(file, PrepNote.serializer(), scope)
    val notes: StateFlow<List<PrepNote>> = store.items

    suspend fun upsert(note: PrepNote) = store.mutate { list ->
        val capped = note.copy(text = note.text.take(MAX_CHARS))
        if (list.any { it.id == capped.id }) list.map { if (it.id == capped.id) capped else it } else list + capped
    }

    suspend fun delete(id: String) = store.mutate { list -> list.filterNot { it.id == id } }

    suspend fun loaded(): List<PrepNote> = store.loaded()
}
```

(`JsonFileStore` is `internal` in package `com.artjiang.helix.data`; same module, so the import works.)

- [ ] **Step 4: Settings** — in `SettingsRepository.kt` add, following the `sessionTapToggleEnabled` pattern:

```kotlin
    val conversateEnabled: Flow<Boolean> =
        appContext.helixDataStore.data.map { prefs -> prefs[CONVERSATE_ENABLED_KEY] ?: false }

    suspend fun setConversateEnabled(enabled: Boolean) {
        appContext.helixDataStore.edit { prefs -> prefs[CONVERSATE_ENABLED_KEY] = enabled }
    }

    val conversatePrefs: Flow<ConversatePrefs> =
        appContext.helixDataStore.data.map { prefs ->
            ConversatePrefs(
                captionsOn = prefs[CONVERSATE_CAPTIONS_KEY] ?: true,
                cuesOn = prefs[CONVERSATE_CUES_KEY] ?: true,
                autoPopup = prefs[CONVERSATE_AUTO_POPUP_KEY] ?: true,
                cueDurationMillis = (prefs[CONVERSATE_CUE_SECONDS_KEY] ?: 6).coerceIn(3, 15) * 1_000L,
            )
        }

    suspend fun setConversatePrefs(value: ConversatePrefs) {
        appContext.helixDataStore.edit { prefs ->
            prefs[CONVERSATE_CAPTIONS_KEY] = value.captionsOn
            prefs[CONVERSATE_CUES_KEY] = value.cuesOn
            prefs[CONVERSATE_AUTO_POPUP_KEY] = value.autoPopup
            prefs[CONVERSATE_CUE_SECONDS_KEY] = (value.cueDurationMillis / 1_000L).toInt().coerceIn(3, 15)
        }
    }
```

and in the companion keys block:

```kotlin
        private val CONVERSATE_ENABLED_KEY = booleanPreferencesKey("conversate_enabled")
        private val CONVERSATE_CAPTIONS_KEY = booleanPreferencesKey("conversate_captions")
        private val CONVERSATE_CUES_KEY = booleanPreferencesKey("conversate_cues")
        private val CONVERSATE_AUTO_POPUP_KEY = booleanPreferencesKey("conversate_auto_popup")
        private val CONVERSATE_CUE_SECONDS_KEY = intPreferencesKey("conversate_cue_seconds")
```

(import `androidx.datastore.preferences.core.intPreferencesKey` and `com.artjiang.helix.conversate.ConversatePrefs`.)

- [ ] **Step 5: Run full suite → PASS.**
- [ ] **Step 6: Commit** — `git commit -m "feat(conversate): prep note store and conversate settings"`.

---

### Task 13: ConversateController + HelixBridge integration

**Files:**
- Create: `android/app/src/main/java/com/artjiang/helix/conversate/ConversateController.kt`
- Modify: `android/app/src/main/java/com/artjiang/helix/HelixBridge.kt` (construction ~line 100-175; `onSegment` ~517; `handleInbound` ~744; `presentToGlasses` ~1034; `maybeRepaintHudWhileStreaming` ~1583)
- Test: `android/app/src/test/java/com/artjiang/helix/conversate/ConversateControllerTest.kt`, `android/app/src/test/java/com/artjiang/helix/conversate/ConversateTouchpadRoutingTest.kt`

**Interfaces:**
- Consumes: everything above.
- Produces:

```kotlin
class ConversateController(
    scope: CoroutineScope,
    sendScreen: suspend (List<ByteArray>) -> G1ScreenDeliveryOutcome,
    clearScreen: suspend () -> Unit,
    arbiter: HudArbiter,
    classify: suspend (String, Int) -> String,
    clock: () -> Long = System::currentTimeMillis,
    menu: MenuSpec = MenuSpec.load(),
    prompt: CuePrompt = CuePrompt.load(),
    onEffect: (SessionEffect) -> Unit,
) {
    val enabled: StateFlow<Boolean>; val isLive: StateFlow<Boolean>
    val screen: StateFlow<ScreenModel>; val hudPreview: StateFlow<String>; val cueFailures: StateFlow<Int>
    fun setEnabled(enabled: Boolean)
    fun setPrefs(prefs: ConversatePrefs)
    fun setPrepNotes(notes: List<PrepNote>)
    fun handleTouchpad(frame: G1TouchpadFrame): Boolean   // true = consumed (enabled)
    fun handleStatus(event: G1StatusEvent?)
    fun onSegment(segment: TranscriptSegment)
    fun offerExternal(text: String, priority: HudArbiter.Priority)  // answers/notices while live
    fun intent(intent: ConversateIntent, source: IntentSource = IntentSource.PHONE)
    fun start(prepNoteId: String?); fun end(); fun setPaused(paused: Boolean)
}
```

- [ ] **Step 1: Write the failing tests**

`ConversateControllerTest.kt`:

```kotlin
package com.artjiang.helix.conversate

import com.artjiang.helix.HudArbiter
import com.artjiang.helix.core.TranscriptSegment
import com.artjiang.helix.g1.G1ScreenDeliveryOutcome
import com.artjiang.helix.g1.G1TouchpadFrame
import com.artjiang.helix.g1.G1TouchpadSide
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.advanceTimeBy
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class ConversateControllerTest {
    private class Rig(scope: TestScope) {
        val sent = mutableListOf<String>()
        val effects = mutableListOf<SessionEffect>()
        var clears = 0
        val controller = ConversateController(
            scope = scope.backgroundScope,
            sendScreen = { p -> sent += String(p.first().copyOfRange(9, p.first().size)); G1ScreenDeliveryOutcome.deliveredToBoth(p.size) },
            clearScreen = { clears++ },
            arbiter = HudArbiter { scope.testScheduler.currentTime },
            classify = { _, _ -> """{"cues":[]}""" },
            clock = { scope.testScheduler.currentTime },
            onEffect = { effects += it },
        )
    }

    @Test
    fun `disabled controller consumes nothing`() = runTest {
        val rig = Rig(this)
        assertFalse(rig.controller.handleTouchpad(G1TouchpadFrame(23, G1TouchpadSide.LEFT)))
    }

    @Test
    fun `long press opens menu, select starts, captions reach the lens`() = runTest {
        val rig = Rig(this)
        rig.controller.setEnabled(true)
        assertTrue(rig.controller.handleTouchpad(G1TouchpadFrame(23, G1TouchpadSide.LEFT)))
        assertTrue(rig.controller.handleTouchpad(G1TouchpadFrame(24, G1TouchpadSide.LEFT)))
        advanceTimeBy(500)
        assertTrue(rig.sent.last().startsWith("CONVERSATE"))
        rig.controller.handleTouchpad(G1TouchpadFrame(23, G1TouchpadSide.LEFT))
        assertEquals(listOf<SessionEffect>(SessionEffect.Start(null)), rig.effects)
        rig.controller.onSegment(TranscriptSegment("hello world", false, 0))
        advanceTimeBy(2_000)
        assertEquals("hello world", rig.sent.last())
    }

    @Test
    fun `answer while live becomes an answer cue`() = runTest {
        val rig = Rig(this)
        rig.controller.setEnabled(true)
        rig.controller.start(null)
        rig.controller.offerExternal("Q3 revenue was 4M.", HudArbiter.Priority.ANSWER)
        advanceTimeBy(1_000)
        assertTrue(rig.sent.last().startsWith("* ANSWER"))
    }

    @Test
    fun `end clears the lens`() = runTest {
        val rig = Rig(this)
        rig.controller.setEnabled(true)
        rig.controller.start(null)
        rig.controller.onSegment(TranscriptSegment("hi", true, 0)); advanceTimeBy(1_000)
        rig.controller.end(); advanceTimeBy(1_000)
        assertEquals(1, rig.clears)
        assertFalse(rig.controller.isLive.value)
    }
}
```

`ConversateTouchpadRoutingTest.kt` — pins Review Focus #1 at the bridge seam by testing the pure routing helper the bridge uses:

```kotlin
package com.artjiang.helix.conversate

import org.junit.Assert.assertEquals
import org.junit.Test

class ConversateTouchpadRoutingTest {
    @Test
    fun `every touchpad index is owned by conversate when enabled`() {
        listOf(0, 1, 23, 24).forEach { idx ->
            assertEquals("idx $idx", TouchpadOwner.CONVERSATE, TouchpadOwner.route(idx, conversateEnabled = true))
        }
    }

    @Test
    fun `legacy owns everything when disabled`() {
        listOf(0, 1, 23, 24).forEach { idx ->
            assertEquals("idx $idx", TouchpadOwner.LEGACY, TouchpadOwner.route(idx, conversateEnabled = false))
        }
    }
}
```

- [ ] **Step 2: Run → FAIL.**

- [ ] **Step 3: Implement `ConversateController.kt`**

```kotlin
// Wires the Conversate pieces together and is the only Conversate type
// HelixBridge talks to. Call every method from the bridge scope (main thread);
// the session is not thread-safe by design.
package com.artjiang.helix.conversate

import com.artjiang.helix.HudArbiter
import com.artjiang.helix.core.TranscriptSegment
import com.artjiang.helix.g1.G1ScreenDeliveryOutcome
import com.artjiang.helix.g1.G1StatusEvent
import com.artjiang.helix.g1.G1TouchpadFrame
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch

enum class TouchpadOwner {
    CONVERSATE, LEGACY;

    companion object {
        /** Spec §4.1: while enabled, Conversate sees every index before TouchpadDecider. */
        fun route(@Suppress("UNUSED_PARAMETER") notifyIndex: Int, conversateEnabled: Boolean) =
            if (conversateEnabled) CONVERSATE else LEGACY
    }
}

class ConversateController(
    private val scope: CoroutineScope,
    sendScreen: suspend (List<ByteArray>) -> G1ScreenDeliveryOutcome,
    clearScreen: suspend () -> Unit,
    arbiter: HudArbiter,
    classify: suspend (String, Int) -> String,
    private val clock: () -> Long = System::currentTimeMillis,
    menu: MenuSpec = MenuSpec.load(),
    prompt: CuePrompt = CuePrompt.load(),
    private val onEffect: (SessionEffect) -> Unit,
) {
    private val composer = G1HudComposer()
    private val captions = CaptionBuffer()
    private val session = ConversateSession(
        menu = menu,
        clock = clock,
        detailPageCount = composer::detailPageCount,
        textPageCount = composer::textPageCount,
    )
    private val driver = ConversateHudDriver(scope, sendScreen, clearScreen, arbiter, clock)
    private val deduper = IntentDeduper(clock)
    private val engine = CueEngine(scope, classify, prompt, clock, emit = { cue -> session.onCue(cue); render() })
    private var prepNotes: List<PrepNote> = emptyList()
    private var ticker: Job? = null

    private val enabledState = MutableStateFlow(false)
    val enabled: StateFlow<Boolean> = enabledState.asStateFlow()
    private val liveState = MutableStateFlow(false)
    val isLive: StateFlow<Boolean> = liveState.asStateFlow()
    private val screenState = MutableStateFlow<ScreenModel>(ScreenModel.Blank)
    val screen: StateFlow<ScreenModel> = screenState.asStateFlow()
    private val previewState = MutableStateFlow("")
    val hudPreview: StateFlow<String> = previewState.asStateFlow()
    val cueFailures: StateFlow<Int> = engine.failures

    fun setEnabled(enabled: Boolean) {
        if (enabledState.value == enabled) return
        enabledState.value = enabled
        if (!enabled) {
            if (session.isLive) end()
            scope.launch { driver.shutdown() }
        }
    }

    fun setPrefs(prefs: ConversatePrefs) { session.updatePrefs(prefs); render() }

    fun setPrepNotes(notes: List<PrepNote>) {
        prepNotes = notes
        session.setPrepNotes(notes.map { it.toRef() })
    }

    fun handleTouchpad(frame: G1TouchpadFrame): Boolean {
        if (TouchpadOwner.route(frame.notifyIndex, enabledState.value) != TouchpadOwner.CONVERSATE) return false
        G1InputMapper.map(frame, session.selectContext)?.let { intent(it, IntentSource.G1_TOUCHPAD) }
        return true
    }

    fun handleStatus(event: G1StatusEvent?) {
        if (!enabledState.value) return
        G1InputMapper.map(event)?.let { intent(it, IntentSource.G1_TOUCHPAD) }
    }

    fun intent(intent: ConversateIntent, source: IntentSource = IntentSource.PHONE) {
        if (!deduper.accept(intent, source)) return
        apply(session.onIntent(intent))
    }

    fun onSegment(segment: TranscriptSegment) {
        if (!session.isLive) return
        captions.onSegment(segment)
        session.onCaptionLines(captions.lines())
        if (segment.isFinal) engine.onFinal(segment.text)
        render()
    }

    fun offerExternal(text: String, priority: HudArbiter.Priority) {
        if (!session.isLive) return
        val type = if (priority == HudArbiter.Priority.ANSWER) CueType.ANSWER else CueType.NOTICE
        val lines = text.trim()
        val title = if (type == CueType.ANSWER) "Answer" else "Notice"
        session.onCue(
            Cue(
                id = engine.nextCueId(),
                type = type,
                title = title,
                body = lines.take(CueParser.BODY_MAX),
                detail = lines.takeIf { it.length > CueParser.BODY_MAX }?.take(CueParser.DETAIL_MAX),
                createdAtMillis = clock(),
            ),
        )
        render()
    }

    fun start(prepNoteId: String?) = apply(session.startLive(prepNoteId))

    fun end() = apply(session.endLive())

    fun setPaused(paused: Boolean) { session.setPaused(paused); render() }

    private fun apply(effects: List<SessionEffect>) {
        effects.forEach { effect ->
            when (effect) {
                is SessionEffect.Start -> {
                    captions.clear()
                    engine.reset()
                    engine.setPrepNote(prepNotes.firstOrNull { it.id == effect.prepNoteId }?.text)
                    liveState.value = true
                    startTicker()
                }
                SessionEffect.End -> {
                    liveState.value = false
                    engine.reset()
                    captions.clear()
                }
                else -> Unit
            }
            onEffect(effect)
        }
        render()
    }

    private fun startTicker() {
        ticker?.cancel()
        ticker = scope.launch {
            while (isActive) {
                delay(250)
                session.tick()
                render()
                if (!session.isLive && screenState.value == ScreenModel.Blank) break
            }
        }
    }

    private fun render() {
        val model = session.screen()
        screenState.value = model
        val frame = composer.compose(model)
        previewState.value = frame?.text.orEmpty()
        driver.submit(frame, interactive = model.isInteractive)
    }
}
```

Note: the ticker only runs during a session; the idle menu needs no timers (its state changes only on intents, which call `render()`).

- [ ] **Step 4: Run controller tests → PASS.**

- [ ] **Step 5: Bridge integration** — in `HelixBridge.kt`:

(a) after `private val engine = ConversationEngine(...)` construct:

```kotlin
    val prepNoteRepository = PrepNoteRepository(File(appContext.filesDir, "prep_notes.json"), scope)

    val conversate = ConversateController(
        scope = scope,
        sendScreen = { packets -> transport.sendScreenDetailed(packets) },
        clearScreen = { transport.send(G1Command(bytes = G1CommandEncoder.exitAllFunctions())) },
        arbiter = hudArbiter,
        classify = { prompt, maxTokens ->
            val provider = fastProvider
            if (provider.kind == ProviderKind.DETERMINISTIC) {
                throw IllegalStateException("No provider configured for Conversate cues.")
            }
            provider.classify(prompt, maxTokens)
        },
        onEffect = ::applyConversateEffect,
    )

    private fun applyConversateEffect(effect: SessionEffect) {
        when (effect) {
            is SessionEffect.Start -> {
                // Free the lens from any legacy answer lifecycle first.
                hudSession.reset()
                if (!isListening.value) startListening()
            }
            SessionEffect.End -> if (isListening.value) stopListening()
            is SessionEffect.SetPaused -> if (effect.paused) stopListening() else startListening()
            is SessionEffect.SetCaptions, is SessionEffect.SetCues ->
                scope.launch { settingsRepository.setConversatePrefs(conversatePrefs.value.let {
                    when (effect) {
                        is SessionEffect.SetCaptions -> it.copy(captionsOn = effect.on)
                        is SessionEffect.SetCues -> it.copy(cuesOn = effect.on)
                        else -> it
                    }
                }) }
        }
    }

    val conversateEnabled: StateFlow<Boolean> = settingsRepository.conversateEnabled
        .stateIn(scope, SharingStarted.Eagerly, false)
    val conversatePrefs: StateFlow<ConversatePrefs> = settingsRepository.conversatePrefs
        .stateIn(scope, SharingStarted.Eagerly, ConversatePrefs())

    fun setConversateEnabled(enabled: Boolean) { scope.launch { settingsRepository.setConversateEnabled(enabled) } }
    fun setConversatePrefs(prefs: ConversatePrefs) { scope.launch { settingsRepository.setConversatePrefs(prefs) } }
    fun startConversate(prepNoteId: String?) = conversate.start(prepNoteId)
    fun endConversate() = conversate.end()
    fun upsertPrepNote(note: PrepNote) { scope.launch { prepNoteRepository.upsert(note) } }
    fun deletePrepNote(id: String) { scope.launch { prepNoteRepository.delete(id) } }
```

Ordering matters: these must be declared **after** `hudSession`, `transport`, `fastProvider` and `settingsRepository` (property initialisers run top to bottom). If `hudSession` is declared later in the file (~line 437), place this block after it.

(b) in `init { ... }` after `sourceSwitch.onSegment = ...` replace that line with:

```kotlin
        sourceSwitch.onSegment = { segment ->
            scope.launch {
                conversate.onSegment(segment)
                handleSegment(segment)
            }
        }
        scope.launch { conversateEnabled.collect { conversate.setEnabled(it) } }
        scope.launch { conversatePrefs.collect { conversate.setPrefs(it) } }
        scope.launch { prepNoteRepository.notes.collect { conversate.setPrepNotes(it) } }
```

(c) in `handleInbound`, after the `when (status) { ... }` block insert:

```kotlin
            conversate.handleStatus(status)
```

and replace the start of the touchpad section so Conversate goes first:

```kotlin
            val frame = G1StatusDecoder.decodeTouchpad(data, touchpadSide) ?: return@launch
            lastTouchpadState.value = "${touchpadSide.name.lowercase()} pad - index ${frame.notifyIndex}"
            // Spec §4.1: while Conversate is enabled it owns every touchpad index;
            // the legacy decider (manual question / StopListening / ClearHud /
            // tap counter) must never see the event.
            if (conversate.handleTouchpad(frame)) return@launch
```

(d) in `presentToGlasses`, right after `if (trimmed.isEmpty()) return`:

```kotlin
        if (conversate.isLive.value) {
            conversate.offerExternal(trimmed, priority)
            return
        }
```

(e) in `maybeRepaintHudWhileStreaming`, first line:

```kotlin
        if (conversate.isLive.value) return
```

(Add imports: `com.artjiang.helix.conversate.*`, `java.io.File`.)

- [ ] **Step 6: Full suite + build**

Run: `cd android && JAVA_HOME=/opt/homebrew/opt/openjdk@17 ./gradlew :app:testDebugUnitTest :app:assembleDebug`
Expected: all PASS, BUILD SUCCESSFUL. Existing `TouchpadDeciderTest` etc. must be unchanged and green (Conversate defaults to disabled).

- [ ] **Step 7: Commit** — `git commit -m "feat(conversate): controller and HelixBridge routing seam"`.

---

### Task 14: Phone UI — Conversate card, Prep Notes, settings

**Files:**
- Create: `android/app/src/main/java/com/artjiang/helix/ui/ConversateCard.kt`
- Create: `android/app/src/main/java/com/artjiang/helix/ui/PrepNotesSheet.kt`
- Modify: `android/app/src/main/java/com/artjiang/helix/ui/AssistantScreen.kt` (top of the main `Column` at ~line 298)
- Modify: `android/app/src/main/java/com/artjiang/helix/ui/SettingsScreen.kt` (new `HelixSection` after the first one at ~line 99)

**Interfaces:**
- Consumes: bridge `conversateEnabled`, `conversatePrefs`, `conversate.isLive`, `conversate.hudPreview`, `conversate.cueFailures`, `prepNoteRepository.notes`, `startConversate`, `endConversate`, `conversate.setPaused`, `conversate.intent`, `upsertPrepNote`, `deletePrepNote`, `setConversateEnabled`, `setConversatePrefs`.
- Produces: `@Composable fun ConversateCard(bridge: HelixBridge)`, `@Composable fun PrepNotesSheet(bridge: HelixBridge, onDismiss: () -> Unit)`, `@Composable fun ConversateSettingsSection(bridge: HelixBridge)`.

- [ ] **Step 1: `ConversateCard.kt`**

```kotlin
package com.artjiang.helix.ui

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.material3.Button
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontFamily
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.artjiang.helix.HelixBridge
import com.artjiang.helix.conversate.ConversateIntent

/** Assistant-tab control surface for Conversate (spec §5.5). */
@Composable
fun ConversateCard(bridge: HelixBridge) {
    val enabled by bridge.conversateEnabled.collectAsStateWithLifecycle()
    val live by bridge.conversate.isLive.collectAsStateWithLifecycle()
    val preview by bridge.conversate.hudPreview.collectAsStateWithLifecycle()
    val failures by bridge.conversate.cueFailures.collectAsStateWithLifecycle()
    val notes by bridge.prepNoteRepository.notes.collectAsStateWithLifecycle()
    var selectedNoteId by remember { mutableStateOf<String?>(null) }
    var pickerOpen by remember { mutableStateOf(false) }
    var editorOpen by remember { mutableStateOf(false) }
    var paused by remember { mutableStateOf(false) }

    HelixSection(title = "Conversate", subtitle = "Live captions and AI cues on your glasses") {
        ToggleRow(
            title = "Conversate mode",
            checked = enabled,
            detail = "Hold the left pad for the menu. Double-tap goes back.",
            onCheckedChange = bridge::setConversateEnabled,
        )
        if (!enabled) return@HelixSection
        Row(horizontalArrangement = Arrangement.spacedBy(HelixSpacing.s8)) {
            TextButton(onClick = { pickerOpen = true }) {
                Text("Prep note: " + (notes.firstOrNull { it.id == selectedNoteId }?.title ?: "None"))
            }
            DropdownMenu(expanded = pickerOpen, onDismissRequest = { pickerOpen = false }) {
                DropdownMenuItem(text = { Text("None") }, onClick = { selectedNoteId = null; pickerOpen = false })
                notes.forEach { n ->
                    DropdownMenuItem(text = { Text(n.title) }, onClick = { selectedNoteId = n.id; pickerOpen = false })
                }
            }
            TextButton(onClick = { editorOpen = true }) { Text("Manage") }
        }
        Row(horizontalArrangement = Arrangement.spacedBy(HelixSpacing.s8)) {
            if (!live) {
                Button(onClick = { bridge.startConversate(selectedNoteId) }) { Text("Start") }
            } else {
                OutlinedButton(onClick = { paused = !paused; bridge.conversate.setPaused(paused); if (paused) bridge.stopListening() else bridge.startListening() }) {
                    Text(if (paused) "Resume" else "Pause")
                }
                Button(onClick = { bridge.endConversate() }) { Text("End") }
                TextButton(onClick = { bridge.conversate.intent(ConversateIntent.MENU) }) { Text("Menu") }
            }
        }
        if (failures >= 3) {
            Text("Cues unavailable - check your AI provider key.", color = MaterialTheme.colorScheme.error)
        }
        if (preview.isNotEmpty()) {
            LinenCard(modifier = Modifier.fillMaxWidth()) {
                Text(preview, fontFamily = FontFamily.Monospace, style = MaterialTheme.typography.bodySmall)
            }
        }
    }
    if (editorOpen) PrepNotesSheet(bridge, onDismiss = { editorOpen = false })
}
```

- [ ] **Step 2: `PrepNotesSheet.kt`**

```kotlin
package com.artjiang.helix.ui

import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.artjiang.helix.HelixBridge
import com.artjiang.helix.conversate.PrepNote
import com.artjiang.helix.conversate.PrepNoteRepository

/** List + editor for Prep Notes (text, or imported from a .txt file). */
@Composable
fun PrepNotesSheet(bridge: HelixBridge, onDismiss: () -> Unit) {
    val notes by bridge.prepNoteRepository.notes.collectAsStateWithLifecycle()
    var editing by remember { mutableStateOf<PrepNote?>(null) }
    val context = LocalContext.current
    val importer = rememberLauncherForActivityResult(ActivityResultContracts.OpenDocument()) { uri: Uri? ->
        if (uri == null) return@rememberLauncherForActivityResult
        val text = runCatching {
            context.contentResolver.openInputStream(uri)?.bufferedReader()?.use { it.readText() }
        }.getOrNull().orEmpty()
        val name = uri.lastPathSegment?.substringAfterLast('/')?.substringBeforeLast('.') ?: "Imported"
        editing = PrepNoteRepository.new(name, text, System.currentTimeMillis())
    }

    val current = editing
    if (current != null) {
        var title by remember(current.id) { mutableStateOf(current.title) }
        var text by remember(current.id) { mutableStateOf(current.text) }
        AlertDialog(
            onDismissRequest = { editing = null },
            title = { Text("Prep note") },
            text = {
                Column {
                    OutlinedTextField(title, { title = it }, label = { Text("Title") }, singleLine = true)
                    OutlinedTextField(
                        value = text,
                        onValueChange = { text = it.take(PrepNoteRepository.MAX_CHARS) },
                        label = { Text("Context (${text.length}/${PrepNoteRepository.MAX_CHARS})") },
                        modifier = Modifier.fillMaxWidth().heightIn(min = 160.dp),
                    )
                }
            },
            confirmButton = {
                TextButton(onClick = {
                    bridge.upsertPrepNote(current.copy(title = title.ifBlank { "Untitled" }, text = text, updatedAtMillis = System.currentTimeMillis()))
                    editing = null
                }) { Text("Save") }
            },
            dismissButton = { TextButton(onClick = { editing = null }) { Text("Cancel") } },
        )
        return
    }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("Prep notes") },
        text = {
            Column {
                if (notes.isEmpty()) Text("No prep notes yet.")
                notes.forEach { n ->
                    Row {
                        TextButton(onClick = { editing = n }, modifier = Modifier.weight(1f)) { Text(n.title) }
                        TextButton(onClick = { bridge.deletePrepNote(n.id) }) { Text("Delete") }
                    }
                }
            }
        },
        confirmButton = {
            TextButton(onClick = { editing = PrepNoteRepository.new("", "", System.currentTimeMillis()) }) { Text("New") }
        },
        dismissButton = {
            Row {
                TextButton(onClick = { importer.launch(arrayOf("text/plain")) }) { Text("Import .txt") }
                TextButton(onClick = onDismiss) { Text("Done") }
            }
        },
    )
}
```

- [ ] **Step 3: Settings section** — append to `SettingsScreen.kt`:

```kotlin
@Composable
fun ConversateSettingsSection(bridge: HelixBridge) {
    val prefs by bridge.conversatePrefs.collectAsStateWithLifecycle()
    HelixSection(title = "Conversate", subtitle = "What appears on the glasses during a session") {
        ToggleRow("Live captions", prefs.captionsOn) { bridge.setConversatePrefs(prefs.copy(captionsOn = it)) }
        ToggleRow("AI cues", prefs.cuesOn) { bridge.setConversatePrefs(prefs.copy(cuesOn = it)) }
        ToggleRow("Auto pop-up", prefs.autoPopup, detail = "Off: new cues wait until you tap.") {
            bridge.setConversatePrefs(prefs.copy(autoPopup = it))
        }
        SliderRow("Cue duration", (prefs.cueDurationMillis / 1000).toInt(), 3..15, suffix = " s") {
            bridge.setConversatePrefs(prefs.copy(cueDurationMillis = it * 1_000L))
        }
    }
}
```

and call `ConversateSettingsSection(bridge)` after the first `HelixSection(...)` block in `SettingsScreen`. In `AssistantScreen`, call `ConversateCard(bridge)` as the first child of the main `Column` at ~line 298.

- [ ] **Step 4: Build** — `./gradlew :app:assembleDebug :app:testDebugUnitTest` → BUILD SUCCESSFUL, all PASS. Fix any import or `HelixSpacing` name mismatches against `ui/Components.kt` / `HelixTokens.kt`.
- [ ] **Step 5: Commit** — `git commit -m "feat(conversate): phone UI - card, prep notes, settings"`.

---

### Task 15: Gates, hardware acceptance, docs

**Files:**
- Modify: `docs/superpowers/specs/2026-10-04-conversate-g1-g2-design.md` (§10 results, Plan A status)
- Modify: `CLAUDE.md` (Key Files: `conversate-core/`, `android/.../conversate/`; one line under Touchpad Behavior: "Conversate mode owns the touchpad: long-press menu/select, taps page, double-tap back")

- [ ] **Step 1:** `cd android && JAVA_HOME=/opt/homebrew/opt/openjdk@17 ./gradlew :app:testDebugUnitTest :app:assembleDebug` → all PASS; record test count.
- [ ] **Step 2:** From repo root: `bash scripts/run_gate.sh` → exit 0.
- [ ] **Step 3: Hardware acceptance on G1** (force-stop `com.even.g1` first), each item pass/fail in the spec:
  1. Enable Conversate; hold left pad → menu appears < 300 ms; no manual question fires; release does not stop listening.
  2. Select "Start Conversate" with a Prep Note → captions appear ≤ ~1 s after speech.
  3. Say "We're evaluating retrieval augmented generation for support" → a CONCEPT cue pops and fades after the configured duration.
  4. Ask "What's the capital of Australia?" → ANSWER cue; right tap opens detail; double-tap returns.
  5. Menu: Captions off → lens blanks between cues; Cues off → no cues; Pause → "|| Paused", transcription stops.
  6. Double-tap twice → session ends, lens clears, firmware dashboard returns. Single double-tap then wait 3 s → stays live.
  7. Rapid 5 right taps in the menu → cursor lands correctly with no lag tail.
  8. Disable Conversate → legacy touchpad behaviour (right tap = manual question) is back.
- [ ] **Step 4: Commit**

```bash
git add docs/superpowers/specs/2026-10-04-conversate-g1-g2-design.md CLAUDE.md
git commit -m "docs: Conversate Plan A hardware acceptance and repo docs"
```
