// OpenAI Realtime transcription over a websocket: microphone PCM → 24 kHz
// base64 `input_audio_buffer.append` frames → server-VAD turns →
// `conversation.item.input_audio_transcription.{delta,completed}`.
// Android counterpart of ios/Runner/OpenAIRealtimeTranscriber.swift, with
// the current nested session schema (see RealtimeEvents).
package com.artjiang.helix.speech

import com.artjiang.helix.ai.KeyStore
import com.artjiang.helix.ai.ModelCatalog
import com.artjiang.helix.ai.ProviderErrors
import com.artjiang.helix.core.ProviderKind
import com.artjiang.helix.core.TranscriptSegment
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlin.math.sqrt
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.Response
import okhttp3.WebSocket
import okhttp3.WebSocketListener
import java.util.Base64
import java.util.Locale
import java.util.concurrent.Executors
import java.util.concurrent.ScheduledExecutorService
import java.util.concurrent.ScheduledFuture
import java.util.concurrent.TimeUnit

/**
 * [TranscriptSource] backed by the OpenAI Realtime API (`intent=transcription`).
 *
 * Threads: [start]/[stop] from the caller (main); [capture] delivers PCM on
 * its own thread; OkHttp invokes the listener on its reader thread; the
 * 100 ms flush runs on [sendScheduler]. All mutable state is guarded by
 * [lock]; the StateFlows are safe from any thread.
 *
 * Failure policy:
 * - No stored key → immediate error, no network.
 * - 401/403 on upgrade, or an in-band auth error → [ProviderErrors.invalidKey],
 *   no retry (a retry storm against a bad key is what the user reported).
 * - Any other transport failure or server-initiated close → up to
 *   [MAX_RETRIES] reconnects with 1 s / 2 s backoff, then a visible error.
 * - [fail] always resets [isListening] so the UI can never stick on
 *   "Listening".
 *
 * Backpressure: the resampled outbox holds at most [OUTBOX_CAPACITY_BYTES]
 * (5 s); older audio is dropped and counted. Frames are only sent once the
 * session is configured and OkHttp's own queue is under [MAX_QUEUE_BYTES].
 */
class OpenAIRealtimeTranscriber(
    private val keyStore: KeyStore,
    private val capture: AudioCapture,
    private val client: OkHttpClient = defaultClient,
    private val url: String = DEFAULT_URL,
    private val model: () -> String = { RealtimeEvents.DEFAULT_MODEL },
    private val language: String = RealtimeEvents.languageCode(Locale.getDefault()),
    private val sendScheduler: ScheduledExecutorService = defaultScheduler,
    private val clock: () -> Long = System::currentTimeMillis,
    /**
     * Where diagnostic lines go besides [diagnostics]. Defaults to logcat
     * (tag [LOG_TAG]); JVM unit tests inject a no-op or a list because
     * android.util.Log is not mocked on the host.
     */
    private val logSink: (String) -> Unit = { line -> android.util.Log.i(LOG_TAG, line) },
    /** connect → SessionReady watchdog; <= 0 disables (unit tests). */
    private val connectWatchdogMillis: Long = CONNECT_WATCHDOG_MILLIS,
    /** SessionReady → first delta watchdog (gated on speech energy); <= 0 disables. */
    private val firstDeltaWatchdogMillis: Long = FIRST_DELTA_WATCHDOG_MILLIS,
    /** Stop → final transcript grace period; <= 0 disables the timeout (tests). */
    private val gracefulStopTimeoutMillis: Long = GRACEFUL_STOP_TIMEOUT_MILLIS,
) : TranscriptSource {

    private val listeningState = MutableStateFlow(false)
    override val isListening: StateFlow<Boolean> = listeningState.asStateFlow()

    private val partialState = MutableStateFlow("")
    override val partialTranscript: StateFlow<String> = partialState.asStateFlow()

    private val errorState = MutableStateFlow("")
    override val errorMessage: StateFlow<String> = errorState.asStateFlow()

    override var onSegment: ((TranscriptSegment) -> Unit)? = null

    /**
     * Bounded (last [DIAG_MAX_LINES]) timestamped diagnostic trail: unknown
     * server events, post-config errors, outbox drops, watchdog firings and
     * session lifecycle. A stall must never be symptomless again.
     */
    private val diagnosticsState = MutableStateFlow<List<String>>(emptyList())
    val diagnostics: StateFlow<List<String>> = diagnosticsState.asStateFlow()

    /** Smoothed microphone level, 0..1 (per-frame RMS of the raw capture). */
    private val inputLevelState = MutableStateFlow(0f)
    val inputLevel: StateFlow<Float> = inputLevelState.asStateFlow()

    /** True once any frame since session start carried speech-level RMS. */
    @Volatile
    var speechEnergySeen: Boolean = false
        private set

    /** True once the first transcript delta of the session arrived. */
    @Volatile
    var hasFirstDelta: Boolean = false
        private set

    /** True while the realtime session is configured (audio may flow). */
    val sessionReady: Boolean
        get() = synchronized(lock) { sessionConfigured }

    /**
     * Harness hook: sees every raw server frame verbatim, before parsing —
     * the live E2E test writes these to a .jsonl file.
     */
    internal var onRawFrame: ((String) -> Unit)? = null

    private val lock = Any()

    // Guarded by [lock].
    private var webSocket: WebSocket? = null
    private var socketGeneration = 0
    private var sessionConfigured = false
    private var retryCount = 0
    private var apiKey: String = ""
    private var resampler: PcmResampler? = null
    private var flushTask: ScheduledFuture<*>? = null
    private var bytesSinceCommit = 0L
    /**
     * `gpt-live-transcribe` rejects server VAD configuration, so the client
     * must close each audible turn after trailing silence while keeping the
     * websocket open for TranscriptCompleted.
     */
    private var clientTurnCommitEnabled = false
    private var speechSinceClientCommit = false
    private var clientCommitPending = false
    private var lastSpeechAtMillis = 0L
    private var pendingTranscriptCompletions = 0
    private var gracefulStopPending = false
    private var gracefulStopTask: ScheduledFuture<*>? = null
    private var currentItemId: String? = null
    private val transcriptFailures = ArrayDeque<Long>()
    private var connectWatchdogTask: ScheduledFuture<*>? = null
    private var deltaWatchdogTask: ScheduledFuture<*>? = null

    /**
     * The pending backoff reconnect from [reconnectOrFail].
     *
     * Tracked — like the watchdogs — because it must not outlive the session
     * that scheduled it. Left dangling, a reconnect scheduled 1-2 s before the
     * user stopped would fire into the NEXT session (which has already set
     * [listeningState] back to true), open a second websocket, and win or lose
     * the [socketGeneration] race at random. That is the "cannot stop / end /
     * restart a session" symptom: the restart reports listening but the
     * surviving socket is the orphan, so no transcript ever arrives.
     */
    private var reconnectTask: ScheduledFuture<*>? = null

    /**
     * Bumped by every [start] / [stop] / [fail]. A scheduled reconnect carries
     * the generation it was born in and refuses to run under any other, so
     * cancellation losing a race with the scheduler is still safe.
     */
    private var sessionGeneration = 0

    private var droppedReported = false

    // "No audio" hysteresis, updated only from the capture thread in onPcm.
    @Volatile
    private var lastEnergyAtMillis = 0L

    @Volatile
    private var noAudioReported = false

    /** Millis of the first speech-level frame this session (0 = none yet). */
    @Volatile
    private var speechEnergySinceMillis = 0L

    // Outbox ring of 24 kHz PCM16 LE bytes, guarded by [lock].
    private val outbox = ByteArray(OUTBOX_CAPACITY_BYTES)
    private var outboxHead = 0
    private var outboxSize = 0

    /** Bytes discarded because the outbox overflowed (session not ready / slow link). */
    @Volatile
    var droppedBytes: Long = 0
        private set

    /** Bytes waiting in the outbox. */
    val bufferedBytes: Int get() = synchronized(lock) { outboxSize }

    override fun clearError() {
        errorState.value = ""
    }

    override fun start() {
        var stoppedSocket: WebSocket? = null
        synchronized(lock) {
            if (listeningState.value) return
            val key = keyStore.keyFor(ProviderKind.OPENAI.name)?.trim().orEmpty()
            if (key.isEmpty()) {
                errorState.value = MISSING_KEY_MESSAGE
                return
            }
            apiKey = key
            // A rapid restart may arrive while stop() is deliberately keeping
            // the previous socket alive for its tail final. Detach and
            // invalidate that socket before the new capture can block or emit:
            // otherwise its listener sees listening=true under the old socket
            // generation and publishes the prior session's final into this one.
            stoppedSocket = webSocket
            webSocket = null
            socketGeneration += 1
            errorState.value = ""
            partialState.value = ""
            retryCount = 0
            droppedBytes = 0
            droppedReported = false
            bytesSinceCommit = 0
            clientTurnCommitEnabled = !RealtimeEvents.supportsServerVad(model())
            speechSinceClientCommit = false
            clientCommitPending = false
            lastSpeechAtMillis = 0L
            pendingTranscriptCompletions = 0
            gracefulStopPending = false
            gracefulStopTask?.cancel(false)
            gracefulStopTask = null
            currentItemId = null
            transcriptFailures.clear()
            speechEnergySeen = false
            speechEnergySinceMillis = 0
            hasFirstDelta = false
            noAudioReported = false
            lastEnergyAtMillis = clock()
            inputLevelState.value = 0f
            clearOutbox()
            // A reconnect left over from the previous session must never open a
            // socket for this one; the generation bump makes any that already
            // escaped cancellation a no-op.
            cancelReconnect()
            sessionGeneration += 1
            listeningState.value = true
        }
        stoppedSocket?.let { socket ->
            if (!socket.close(NORMAL_CLOSURE, "restart")) socket.cancel()
        }
        diag("session start (model=${model()}, lang=$language)")

        capture.start(::onPcm) { message -> fail("Microphone error: $message") }
        synchronized(lock) {
            if (!listeningState.value) return // capture failed synchronously
            resampler = PcmResampler(capture.sampleRateHz, RealtimeEvents.SAMPLE_RATE)
            flushTask = runCatching {
                sendScheduler.scheduleAtFixedRate(
                    { runCatching { flushAudio() } },
                    FLUSH_INTERVAL_MILLIS,
                    FLUSH_INTERVAL_MILLIS,
                    TimeUnit.MILLISECONDS,
                )
            }.getOrNull()
        }
        connect()
    }

    override fun stop() {
        var stopSocketGeneration = 0
        synchronized(lock) {
            if (!listeningState.value && webSocket == null) return
            if (gracefulStopPending) return
            listeningState.value = false
            flushTask?.cancel(false)
            flushTask = null
            cancelWatchdogs()
            cancelReconnect()
            sessionGeneration += 1
            // Keep the current socket generation eligible for a final. It is
            // invalidated only when the final arrives or the grace timer ends.
            gracefulStopPending = webSocket != null && sessionConfigured
            stopSocketGeneration = socketGeneration
        }
        capture.stop()
        flushAudio()
        val socket: WebSocket?
        val commit: Boolean
        val waitForFinal: Boolean
        synchronized(lock) {
            socket = webSocket
            commit = sessionConfigured && bytesSinceCommit >= MIN_COMMIT_BYTES
            if (commit) {
                bytesSinceCommit = 0
                pendingTranscriptCompletions += 1
            }
            waitForFinal = gracefulStopPending && pendingTranscriptCompletions > 0
            clearOutbox()
            inputLevelState.value = 0f
        }
        if (commit) socket?.send(RealtimeEvents.audioCommit())
        if (waitForFinal) {
            diag("stop requested; awaiting final transcript")
            scheduleGracefulStopTimeout()
        } else {
            finishGracefulStop("stop", stopSocketGeneration)
        }
    }

    // MARK: - Audio path

    private fun onPcm(samples: ShortArray, length: Int) {
        val shouldBuffer = if (length > 0 && listeningState.value) trackEnergy(samples, length) else false
        if (!shouldBuffer) return
        val bytes: ByteArray
        synchronized(lock) {
            if (!listeningState.value) return
            // A flush may have committed between RMS classification and this
            // lock. Do not enqueue that now-idle quiet frame into the next turn.
            if (clientTurnCommitEnabled && !speechSinceClientCommit && !clientCommitPending) return
            val converter = resampler ?: return
            val resampled = converter.resample(samples, length)
            bytes = ByteArray(resampled.size * 2)
            var i = 0
            for (s in resampled) {
                bytes[i++] = (s.toInt() and 0xFF).toByte()
                bytes[i++] = ((s.toInt() shr 8) and 0xFF).toByte()
            }
            enqueue(bytes)
        }
    }

    /**
     * Per-frame RMS of the raw capture: feeds [inputLevel] (smoothed 0..1),
     * latches [speechEnergySeen] for the first-delta watchdog, and drives
     * the "no audio" hysteresis — [NO_AUDIO_WINDOW_MILLIS] continuously
     * below the near-zero floor while listening surfaces
     * [NO_AUDIO_MESSAGE]; any spike resets (and clears the banner). Runs on
     * the capture thread only, so a gated FileAudioCapture that has not
     * started streaming can never trigger it (no frames, no checks).
     */
    private fun trackEnergy(samples: ShortArray, length: Int): Boolean {
        var sum = 0.0
        for (i in 0 until length) {
            val s = samples[i].toDouble()
            sum += s * s
        }
        val rms = (sqrt(sum / length) / 32768.0).toFloat()
        val previous = inputLevelState.value
        inputLevelState.value = if (rms > previous) rms else {
            (previous * INPUT_LEVEL_DECAY + rms * (1f - INPUT_LEVEL_DECAY)).coerceIn(0f, 1f)
        }
        val now = clock()
        var firstSpeech = false
        var shouldBuffer = true
        synchronized(lock) {
            if (rms >= SPEECH_RMS_FLOOR) {
                if (!speechEnergySeen) {
                    speechEnergySeen = true
                    speechEnergySinceMillis = now
                    firstSpeech = true
                }
                if (clientTurnCommitEnabled) {
                    lastSpeechAtMillis = now
                    speechSinceClientCommit = true
                    clientCommitPending = false
                }
            } else if (
                clientTurnCommitEnabled &&
                speechSinceClientCommit &&
                !clientCommitPending &&
                now - lastSpeechAtMillis >= CLIENT_TURN_SILENCE_MILLIS
            ) {
                clientCommitPending = true
            }
            shouldBuffer = !clientTurnCommitEnabled || speechSinceClientCommit || clientCommitPending
        }
        if (firstSpeech) diag("speech energy detected (rms=%.4f)".format(Locale.ROOT, rms))
        if (rms > NO_AUDIO_RMS_FLOOR) {
            lastEnergyAtMillis = now
            if (noAudioReported) {
                noAudioReported = false
                if (errorState.value == NO_AUDIO_MESSAGE) errorState.value = ""
            }
        } else if (
            !speechEnergySeen &&
            !noAudioReported &&
            now - lastEnergyAtMillis >= NO_AUDIO_WINDOW_MILLIS
        ) {
            noAudioReported = true
            diag("no audio energy for ${now - lastEnergyAtMillis} ms")
            errorState.value = NO_AUDIO_MESSAGE
        }
        return shouldBuffer
    }

    /** Caller holds [lock]. Appends, evicting the oldest bytes on overflow. */
    private fun enqueue(bytes: ByteArray) {
        var offset = 0
        var length = bytes.size
        if (length > OUTBOX_CAPACITY_BYTES) {
            droppedBytes += length - OUTBOX_CAPACITY_BYTES
            offset = length - OUTBOX_CAPACITY_BYTES
            length = OUTBOX_CAPACITY_BYTES
        }
        val overflow = outboxSize + length - OUTBOX_CAPACITY_BYTES
        if (overflow > 0) {
            outboxHead = (outboxHead + overflow) % OUTBOX_CAPACITY_BYTES
            outboxSize -= overflow
            droppedBytes += overflow
        }
        val tail = (outboxHead + outboxSize) % OUTBOX_CAPACITY_BYTES
        val firstRun = minOf(length, OUTBOX_CAPACITY_BYTES - tail)
        System.arraycopy(bytes, offset, outbox, tail, firstRun)
        if (firstRun < length) System.arraycopy(bytes, offset + firstRun, outbox, 0, length - firstRun)
        outboxSize += length
        if (droppedBytes > 0 && !droppedReported) {
            droppedReported = true
            diag("outbox overflow: dropping oldest audio (session not ready or slow link)")
        }
    }

    /** Caller holds [lock]. */
    private fun drainOutbox(): ByteArray {
        val out = ByteArray(outboxSize)
        val firstRun = minOf(outboxSize, OUTBOX_CAPACITY_BYTES - outboxHead)
        System.arraycopy(outbox, outboxHead, out, 0, firstRun)
        if (firstRun < outboxSize) System.arraycopy(outbox, 0, out, firstRun, outboxSize - firstRun)
        clearOutbox()
        return out
    }

    /** Caller holds [lock]. */
    private fun clearOutbox() {
        outboxHead = 0
        outboxSize = 0
    }

    /**
     * Sends everything buffered as one append frame — only once the session
     * is configured and OkHttp's queue is not already backed up. Runs every
     * [FLUSH_INTERVAL_MILLIS] on [sendScheduler]; tests call it directly.
     */
    internal fun flushAudio() {
        val socket: WebSocket
        val payload: ByteArray?
        val commit: Boolean
        synchronized(lock) {
            if (!sessionConfigured) return
            socket = webSocket ?: return
            if (socket.queueSize() >= MAX_QUEUE_BYTES) return
            payload = if (outboxSize > 0) drainOutbox() else null
            bytesSinceCommit += payload?.size ?: 0
            commit = clientTurnCommitEnabled &&
                clientCommitPending &&
                bytesSinceCommit >= MIN_COMMIT_BYTES
            if (commit) {
                bytesSinceCommit = 0
                clientCommitPending = false
                speechSinceClientCommit = false
                lastSpeechAtMillis = 0L
                pendingTranscriptCompletions += 1
            }
        }
        payload?.let {
            socket.send(RealtimeEvents.audioAppend(Base64.getEncoder().encodeToString(it)))
        }
        if (commit) {
            socket.send(RealtimeEvents.audioCommit())
            diag("client silence commit; awaiting final transcript")
        }
    }

    // MARK: - Socket lifecycle

    private fun connect() {
        val request = Request.Builder()
            .url(url)
            .addHeader("Authorization", "Bearer $apiKey")
            // No "OpenAI-Beta: realtime=v1" header: that selects the deprecated
            // beta interface, which rejects the GA session.update shape.
            .build()
        val generation: Int
        synchronized(lock) {
            if (!listeningState.value) return
            socketGeneration += 1
            generation = socketGeneration
            sessionConfigured = false
            bytesSinceCommit = 0
        }
        scheduleConnectWatchdog(generation)
        val socket = client.newWebSocket(request, SocketListener(generation))
        synchronized(lock) {
            if (socketGeneration == generation && listeningState.value) {
                webSocket = socket
            } else {
                socket.cancel()
            }
        }
    }

    private inner class SocketListener(private val generation: Int) : WebSocketListener() {

        /** Caller holds [lock]. */
        private fun isCurrentLocked(): Boolean =
            generation == socketGeneration && (listeningState.value || gracefulStopPending)

        private fun isCurrent(): Boolean = synchronized(lock) {
            isCurrentLocked()
        }

        override fun onOpen(webSocket: WebSocket, response: Response) {
            if (!isCurrent()) return
            diag("socket connected; sending session.update (model=${model()})")
            webSocket.send(RealtimeEvents.sessionUpdate(model = model(), language = language))
        }

        override fun onMessage(webSocket: WebSocket, text: String) {
            if (!isCurrent()) return
            runCatching { onRawFrame?.invoke(text) }
            when (val event = RealtimeEvents.parse(text)) {
                RealtimeServerEvent.SessionReady -> {
                    val firstForSocket: Boolean
                    synchronized(lock) {
                        firstForSocket = !sessionConfigured
                        sessionConfigured = true
                        retryCount = 0
                        if (firstForSocket) {
                            connectWatchdogTask?.cancel(false)
                            connectWatchdogTask = null
                        }
                    }
                    if (firstForSocket) {
                        diag("session configured")
                        scheduleDeltaWatchdog(generation)
                    }
                }

                is RealtimeServerEvent.TranscriptDelta -> {
                    if (!hasFirstDelta) {
                        // diag before the flag: observers poll hasFirstDelta.
                        diag("first transcript delta")
                        hasFirstDelta = true
                        synchronized(lock) {
                            deltaWatchdogTask?.cancel(false)
                            deltaWatchdogTask = null
                        }
                    }
                    val running = synchronized(lock) {
                        if (currentItemId != event.itemId) {
                            currentItemId = event.itemId
                            partialState.value = ""
                        }
                        (partialState.value + event.delta).also { partialState.value = it }
                    }
                    if (running.isNotBlank()) {
                        onSegment?.invoke(TranscriptSegment(running, isFinal = false, timestampMillis = clock()))
                    }
                }

                is RealtimeServerEvent.TranscriptCompleted -> {
                    val text = event.transcript.trim()
                    val closeAfterFinal = synchronized(lock) {
                        // onRawFrame and parsing are intentionally outside the
                        // state lock. A restart can happen while either runs,
                        // so re-check ownership at the final publication point
                        // and mutate/callback atomically with start().
                        if (!isCurrentLocked()) return
                        diag("transcript completed")
                        // A completed transcript is transcript progress even
                        // when no delta preceded it (some models emit finals only).
                        if (!hasFirstDelta) {
                            diag("first transcript (completed, no delta)")
                            hasFirstDelta = true
                        }
                        deltaWatchdogTask?.cancel(false)
                        deltaWatchdogTask = null
                        currentItemId = null
                        partialState.value = ""
                        if (pendingTranscriptCompletions > 0) pendingTranscriptCompletions -= 1
                        if (!clientTurnCommitEnabled) bytesSinceCommit = 0
                        val shouldClose = gracefulStopPending && pendingTranscriptCompletions == 0
                        if (text.isNotEmpty()) {
                            onSegment?.invoke(TranscriptSegment(text, isFinal = true, timestampMillis = clock()))
                        }
                        shouldClose
                    }
                    if (closeAfterFinal) finishGracefulStop("final received", generation)
                }

                is RealtimeServerEvent.TranscriptFailed -> {
                    diag("transcription failed: ${event.message}")
                    // Clear both sides together so stale local audio isn't
                    // replayed into a freshly cleared server buffer.
                    webSocket.send(RealtimeEvents.audioClear())
                    var closeAfterFailure = false
                    val tooMany = synchronized(lock) {
                        // Inside the lock: clearOutbox mutates the ring fields
                        // that enqueue()/drainOutbox() touch on other threads.
                        clearOutbox()
                        partialState.value = ""
                        if (pendingTranscriptCompletions > 0) pendingTranscriptCompletions -= 1
                        closeAfterFailure = gracefulStopPending && pendingTranscriptCompletions == 0
                        val now = clock()
                        transcriptFailures.addLast(now)
                        while (transcriptFailures.isNotEmpty() && now - transcriptFailures.first() > FAILURE_WINDOW_MILLIS) {
                            transcriptFailures.removeFirst()
                        }
                        transcriptFailures.size >= MAX_TRANSCRIPT_FAILURES
                    }
                    if (tooMany) {
                        synchronized(lock) { transcriptFailures.clear() }
                        reconnectOrFail("transcription kept failing: ${event.message}")
                    }
                    if (closeAfterFailure) finishGracefulStop("final failed", generation)
                }

                is RealtimeServerEvent.ApiError -> when {
                    event.isAuth -> fail(ProviderErrors.invalidKey(ProviderKind.OPENAI))
                    // A rejected session config can never succeed by retrying.
                    !synchronized(lock) { sessionConfigured } -> fail("OpenAI realtime session error: ${event.message}")
                    // In-session errors (e.g. a bad model or quota problem)
                    // are not fatal, but they must be visible: surface the
                    // message without tearing the session down.
                    else -> {
                        diag("server error (post-config): ${event.code ?: "?"}: ${event.message}")
                        errorState.value = "OpenAI realtime error: ${event.message}"
                    }
                }

                is RealtimeServerEvent.Unknown -> diag("unknown event: ${event.type.ifEmpty { "<unparseable>" }}")
            }
        }

        override fun onClosing(webSocket: WebSocket, code: Int, reason: String) {
            if (!isCurrent()) return
            if (synchronized(lock) { gracefulStopPending }) {
                finishGracefulStop("server closed during stop", generation)
                return
            }
            webSocket.close(NORMAL_CLOSURE, null)
            reconnectOrFail("connection closed ($code${if (reason.isBlank()) "" else ": $reason"})")
        }

        override fun onFailure(webSocket: WebSocket, t: Throwable, response: Response?) {
            if (!isCurrent()) return
            if (synchronized(lock) { gracefulStopPending }) {
                finishGracefulStop("socket failed during stop", generation)
                return
            }
            val code = response?.code
            if (code == 401 || code == 403) {
                fail(ProviderErrors.invalidKey(ProviderKind.OPENAI))
                return
            }
            val transient = t is java.net.UnknownHostException ||
                t is java.net.ConnectException ||
                t is java.net.SocketTimeoutException
            val detail = when {
                code != null -> "HTTP $code"
                // DNS blackouts during Wi-Fi/cellular handoffs or VPN route
                // changes resolve themselves within seconds; say what the user
                // can act on instead of echoing the resolver error.
                t is java.net.UnknownHostException ->
                    "no internet connection — check Wi-Fi, mobile data, or VPN"
                else -> t.message?.takeIf { it.isNotBlank() } ?: t::class.simpleName.orEmpty()
            }
            reconnectOrFail(detail, transient = transient)
        }
    }

    private fun reconnectOrFail(reason: String, transient: Boolean = false) {
        // Transient network errors (DNS/connect/timeout) get a longer, more
        // patient budget than protocol failures: a handoff blackout typically
        // clears within a few seconds.
        val maxRetries = if (transient) TRANSIENT_MAX_RETRIES else MAX_RETRIES
        val delayMillis: Long
        val stale: WebSocket?
        val attempt: Int
        val session: Int
        synchronized(lock) {
            if (!listeningState.value) return
            session = sessionGeneration
            if (retryCount >= maxRetries) {
                // Fall through to fail() outside the lock.
                delayMillis = -1
            } else {
                retryCount += 1
                delayMillis = RETRY_BASE_DELAY_MILLIS * retryCount
            }
            attempt = retryCount
            stale = webSocket
            webSocket = null
            sessionConfigured = false
            socketGeneration += 1
            cancelWatchdogs()
        }
        stale?.cancel()
        if (delayMillis >= 0) diag("reconnecting (attempt $attempt/$maxRetries): $reason")
        if (delayMillis < 0) {
            fail("OpenAI realtime transcription stopped: $reason")
            return
        }
        runCatching {
            sendScheduler.schedule(
                {
                    // Refuse to connect for a session that has since been
                    // stopped, failed, or replaced by a restart.
                    val current = synchronized(lock) {
                        reconnectTask = null
                        listeningState.value && session == sessionGeneration
                    }
                    if (current) connect()
                },
                delayMillis,
                TimeUnit.MILLISECONDS,
            )
        }.onSuccess { task ->
            val keep = synchronized(lock) {
                if (listeningState.value && session == sessionGeneration) {
                    reconnectTask = task
                    true
                } else {
                    false
                }
            }
            // The session ended while we were scheduling; drop the retry.
            if (!keep) task.cancel(false)
        }.onFailure { fail("OpenAI realtime transcription stopped: $reason") }
    }

    /** Terminal failure: tears everything down and resets the listening flag. */
    private fun fail(message: String) {
        val socket: WebSocket?
        synchronized(lock) {
            listeningState.value = false
            sessionConfigured = false
            flushTask?.cancel(false)
            flushTask = null
            cancelWatchdogs()
            cancelReconnect()
            gracefulStopTask?.cancel(false)
            gracefulStopTask = null
            gracefulStopPending = false
            pendingTranscriptCompletions = 0
            sessionGeneration += 1
            socket = webSocket
            webSocket = null
            socketGeneration += 1
            partialState.value = ""
            clearOutbox()
            inputLevelState.value = 0f
            errorState.value = message
        }
        capture.stop()
        socket?.cancel()
        diag("failed: $message")
    }

    /** Closes the stop-grace socket without allowing its close to reconnect. */
    private fun finishGracefulStop(reason: String, expectedSocketGeneration: Int) {
        val socket: WebSocket?
        synchronized(lock) {
            // Completion and close callbacks race rapid restart. Only the
            // generation that owns the grace socket may clear shared state or
            // close/release it; a newer start owns everything after this gate.
            if (expectedSocketGeneration != socketGeneration) return
            gracefulStopTask?.cancel(false)
            gracefulStopTask = null
            gracefulStopPending = false
            pendingTranscriptCompletions = 0
            sessionConfigured = false
            bytesSinceCommit = 0
            speechSinceClientCommit = false
            clientCommitPending = false
            lastSpeechAtMillis = 0L
            partialState.value = ""
            clearOutbox()
            socket = webSocket
            webSocket = null
            socketGeneration += 1
        }
        socket?.let { if (!it.close(NORMAL_CLOSURE, "stop")) it.cancel() }
        diag("session stopped ($reason)")
    }

    private fun scheduleGracefulStopTimeout() {
        if (gracefulStopTimeoutMillis <= 0) return
        val generation = synchronized(lock) { socketGeneration }
        val task = runCatching {
            sendScheduler.schedule(
                {
                    val shouldClose = synchronized(lock) {
                        gracefulStopPending && generation == socketGeneration
                    }
                    if (shouldClose) finishGracefulStop("final timeout", generation)
                },
                gracefulStopTimeoutMillis,
                TimeUnit.MILLISECONDS,
            )
        }.getOrNull()
        synchronized(lock) {
            gracefulStopTask?.cancel(false)
            if (gracefulStopPending && generation == socketGeneration) {
                gracefulStopTask = task
            } else {
                task?.cancel(false)
            }
        }
    }

    // MARK: - Watchdogs & diagnostics

    /** Caller holds [lock]. */
    private fun cancelWatchdogs() {
        connectWatchdogTask?.cancel(false)
        connectWatchdogTask = null
        deltaWatchdogTask?.cancel(false)
        deltaWatchdogTask = null
    }

    /**
     * Cancels the pending backoff reconnect. Caller holds [lock]. Separate from
     * [cancelWatchdogs] because [reconnectOrFail] cancels the watchdogs of the
     * socket it is replacing while deliberately keeping its own retry alive.
     */
    private fun cancelReconnect() {
        reconnectTask?.cancel(false)
        reconnectTask = null
    }

    /**
     * connect → SessionReady watchdog: if the session is still not
     * configured [connectWatchdogMillis] after the connect attempt started,
     * the UI must not sit on "Listening" forever.
     */
    private fun scheduleConnectWatchdog(generation: Int) {
        if (connectWatchdogMillis <= 0) return
        val task = runCatching {
            sendScheduler.schedule(
                {
                    val fire = synchronized(lock) {
                        listeningState.value && !sessionConfigured && generation == socketGeneration
                    }
                    if (fire) {
                        diag("watchdog: no SessionReady within $connectWatchdogMillis ms")
                        fail(CONNECT_WATCHDOG_MESSAGE)
                    }
                },
                connectWatchdogMillis,
                TimeUnit.MILLISECONDS,
            )
        }.getOrNull()
        synchronized(lock) {
            connectWatchdogTask?.cancel(false)
            if (generation == socketGeneration && listeningState.value) {
                connectWatchdogTask = task
            } else {
                task?.cancel(false)
                connectWatchdogTask = null
            }
        }
    }

    /**
     * SessionReady → first transcript watchdog, gated on speech energy: it
     * fires only after [firstDeltaWatchdogMillis] of *speech-level* input
     * with no transcript back — silence alone reschedules forever, so a
     * quiet room never trips it.
     */
    private fun scheduleDeltaWatchdog(generation: Int, delayMillis: Long = firstDeltaWatchdogMillis) {
        if (firstDeltaWatchdogMillis <= 0) return
        val task = runCatching {
            sendScheduler.schedule({ checkFirstDelta(generation) }, delayMillis, TimeUnit.MILLISECONDS)
        }.getOrNull()
        synchronized(lock) {
            deltaWatchdogTask?.cancel(false)
            if (generation == socketGeneration && listeningState.value) {
                deltaWatchdogTask = task
            } else {
                task?.cancel(false)
                deltaWatchdogTask = null
            }
        }
    }

    private fun checkFirstDelta(generation: Int) {
        val active = synchronized(lock) {
            listeningState.value && sessionConfigured && generation == socketGeneration
        }
        if (!active || hasFirstDelta) return
        val speechSince = speechEnergySinceMillis
        if (speechSince == 0L) {
            // Nothing worth transcribing was heard yet; keep watching.
            scheduleDeltaWatchdog(generation)
            return
        }
        val remaining = firstDeltaWatchdogMillis - (clock() - speechSince)
        if (remaining > 0) {
            scheduleDeltaWatchdog(generation, remaining)
            return
        }
        diag("watchdog: speech energy but no transcript within $firstDeltaWatchdogMillis ms")
        fail(deltaWatchdogMessage(model()))
    }

    /**
     * Records a timestamped line in [diagnostics] (bounded to
     * [DIAG_MAX_LINES]) and mirrors it to [logSink] (logcat in production).
     */
    private fun diag(message: String) {
        val line = String.format(Locale.ROOT, "%1\$tH:%1\$tM:%1\$tS.%1\$tL %2\$s", clock(), message)
        runCatching { logSink(line) }
        diagnosticsState.update { existing ->
            if (existing.size >= DIAG_MAX_LINES) existing.drop(existing.size - DIAG_MAX_LINES + 1) + line
            else existing + line
        }
    }

    companion object {
        /**
         * GA endpoint. The server requires either ?model= or ?intent= on the
         * socket URL; intent=transcription selects a transcription session,
         * whose model is then set via session.update.
         */
        const val DEFAULT_URL = "wss://api.openai.com/v1/realtime?intent=transcription"
        const val MISSING_KEY_MESSAGE =
            "OpenAI API key is required for realtime transcription. Add it in Settings."

        const val FLUSH_INTERVAL_MILLIS = 100L
        const val MAX_RETRIES = 2

        /** Retry budget for DNS/connect/timeout failures (1s..5s backoff ≈ 15 s total). */
        const val TRANSIENT_MAX_RETRIES = 5
        const val RETRY_BASE_DELAY_MILLIS = 1_000L

        /** 5 s of 24 kHz PCM16 mono. */
        const val OUTBOX_CAPACITY_BYTES = RealtimeEvents.SAMPLE_RATE * 2 * 5

        /** Skip sending while OkHttp still has this much queued (slow link). */
        const val MAX_QUEUE_BYTES = 1L shl 20

        /** 100 ms at 24 kHz — the API rejects commits with less audio than that. */
        const val MIN_COMMIT_BYTES = RealtimeEvents.SAMPLE_RATE * 2 / 10

        const val MAX_TRANSCRIPT_FAILURES = 3
        const val FAILURE_WINDOW_MILLIS = 30_000L
        const val NORMAL_CLOSURE = 1000
        const val GRACEFUL_STOP_TIMEOUT_MILLIS = 1_500L

        // MARK: Diagnostics

        const val LOG_TAG = "HelixRealtime"
        const val DIAG_MAX_LINES = 50

        const val CONNECT_WATCHDOG_MILLIS = 10_000L
        const val FIRST_DELTA_WATCHDOG_MILLIS = 15_000L
        const val CONNECT_WATCHDOG_MESSAGE =
            "OpenAI session never became ready — check your network connection and API key, then try again."
        const val DELTA_WATCHDOG_MESSAGE =
            "OpenAI is not returning transcripts — check the transcription model in Settings, or try again."

        /**
         * The watchdog message, naming the model when it is the likely cause.
         *
         * "Check the transcription model in Settings" is useless on its own:
         * the user cannot tell which ids are valid. When the selected id is a
         * batch-only transcription model (`gpt-transcribe` and friends), the
         * realtime socket will never stream it — say exactly that, and list
         * what to pick instead.
         */
        fun deltaWatchdogMessage(model: String): String {
            val id = model.trim()
            if (id.isEmpty() || ModelCatalog.isRealtimeTranscriptionModel(id)) {
                return DELTA_WATCHDOG_MESSAGE
            }
            val supported = ModelCatalog.OPENAI_TRANSCRIPTION_FALLBACKS.joinToString(", ")
            return "\"$id\" is not a realtime transcription model, so OpenAI streams " +
                "nothing back. Pick one of these in Settings → Transcription model: $supported."
        }

        /** RMS (0..1) below this is treated as dead-mic silence. */
        const val NO_AUDIO_RMS_FLOOR = 0.002f

        /** RMS (0..1) at or above this counts as speech-level energy. */
        const val SPEECH_RMS_FLOOR = 0.015f

        /** Continuous near-zero input for this long surfaces [NO_AUDIO_MESSAGE]. */
        const val NO_AUDIO_WINDOW_MILLIS = 5_000L
        const val NO_AUDIO_MESSAGE = "No audio detected — check the microphone."

        /** Speech-end timeout used only when the selected model has no server VAD. */
        const val CLIENT_TURN_SILENCE_MILLIS = 1_000L

        /** Exponential decay for [inputLevel] when the signal falls (attack is instant). */
        const val INPUT_LEVEL_DECAY = 0.7f

        val defaultClient: OkHttpClient by lazy {
            OkHttpClient.Builder().pingInterval(10, TimeUnit.SECONDS).build()
        }

        val defaultScheduler: ScheduledExecutorService by lazy {
            Executors.newSingleThreadScheduledExecutor { runnable ->
                Thread(runnable, "helix-realtime-send").apply { isDaemon = true }
            }
        }
    }
}
