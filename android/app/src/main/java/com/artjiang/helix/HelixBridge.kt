// App-scope coordinator. Android port of ios/Runner/HelixNativeBridge.swift:
// owns settings, the AI engine, the BLE link + G1 transport, transcription, and
// the HUD arbiter, and exposes everything the Compose UI observes.
package com.artjiang.helix

import android.content.Context
import com.artjiang.helix.ai.AnsweringPhaseTracker
import com.artjiang.helix.ai.AnswerTier
import com.artjiang.helix.ai.AutomaticNoteExtractor
import com.artjiang.helix.ai.ConversationEngine
import com.artjiang.helix.ai.ConversationEvent
import com.artjiang.helix.ai.KeyCheckResult
import com.artjiang.helix.ai.LlmQuestionDetector
import com.artjiang.helix.ai.ModelCatalog
import com.artjiang.helix.ai.ModelRole
import com.artjiang.helix.ai.ProviderErrors
import com.artjiang.helix.ai.ProviderFactory
import com.artjiang.helix.ai.QuestionSensitivity
import com.artjiang.helix.ai.RecentTranscriptBuffer
import com.artjiang.helix.ai.Turn
import com.artjiang.helix.ble.DiscoveredPair
import com.artjiang.helix.ble.G1BluetoothManager
import com.artjiang.helix.ble.LensConnectionState
import com.artjiang.helix.core.AnswerProvider
import com.artjiang.helix.core.ConversationMode
import com.artjiang.helix.core.HelixSettings
import com.artjiang.helix.core.KnowledgeBucket
import com.artjiang.helix.core.ProviderKind
import com.artjiang.helix.data.FeedRepository
import com.artjiang.helix.data.KnowledgeRepository
import com.artjiang.helix.data.AutomaticAnswerQuality
import com.artjiang.helix.data.OmiImportResult
import com.artjiang.helix.data.OmiImportService
import com.artjiang.helix.data.OmiLiveSegment
import com.artjiang.helix.data.OmiLiveService
import com.artjiang.helix.data.SessionRepository
import com.artjiang.helix.data.SettingsRepository
import com.artjiang.helix.g1.G1AckPolicy
import com.artjiang.helix.g1.G1Command
import com.artjiang.helix.g1.G1CommandEncoder
import com.artjiang.helix.g1.G1TapCounter
import com.artjiang.helix.g1.HudLineStream
import com.artjiang.helix.g1.HudSessionNotices
import com.artjiang.helix.g1.G1CommandTransport
import com.artjiang.helix.g1.G1HudPage
import com.artjiang.helix.g1.G1HudPresenter
import com.artjiang.helix.g1.G1HudSession
import com.artjiang.helix.g1.G1Side
import com.artjiang.helix.g1.G1StatusDecoder
import com.artjiang.helix.g1.G1StatusEvent
import com.artjiang.helix.g1.G1TouchpadSide
import com.artjiang.helix.g1.G1PacketEncoder
import com.artjiang.helix.g1.G1ScreenDeliveryCoverage
import com.artjiang.helix.g1.G1ScreenDeliveryOutcome
import com.artjiang.helix.g1.ProbeStats
import com.artjiang.helix.g1.TouchpadProbeLog
import com.artjiang.helix.notify.G1NotificationSender
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import com.artjiang.helix.core.TranscriptSegment
import com.artjiang.helix.speech.AudioRecordCapture
import com.artjiang.helix.speech.FileAudioCapture
import com.artjiang.helix.speech.OmiTranscriptSource
import com.artjiang.helix.speech.OpenAIRealtimeTranscriber
import com.artjiang.helix.speech.QuestionMode
import com.artjiang.helix.speech.SwitchableAudioCapture
import com.artjiang.helix.speech.TranscriptSourceSwitch
import com.artjiang.helix.speech.TranscriptionService
import com.artjiang.helix.speech.TranscriptionSource
import java.io.File
import com.artjiang.helix.conversate.ConversateController
import com.artjiang.helix.conversate.ConversatePrefs
import com.artjiang.helix.conversate.PrepNote
import com.artjiang.helix.conversate.PrepNoteRepository
import com.artjiang.helix.conversate.SessionEffect
import com.artjiang.helix.ring.R1Transport
import com.artjiang.helix.ring.RingLinkState
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.distinctUntilChanged

/**
 * The single seam between the Android shell and the pure Kotlin layers.
 *
 * Owned for the process lifetime (see [HelixApplication]); the Compose tree
 * reads its StateFlows and calls its methods, and nothing in `ui/` talks to
 * BLE, DataStore, or the engine directly.
 */
class HelixBridge(
    context: Context,
    private val scope: CoroutineScope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate),
) {
    private val appContext = context.applicationContext

    val settingsRepository = SettingsRepository(appContext)
    val knowledgeRepository = KnowledgeRepository(appContext, scope)
    val sessionRepository = SessionRepository(appContext, scope)
    val feedRepository = FeedRepository(appContext, scope, limit = FEED_LIMIT)

    val bluetooth = G1BluetoothManager(appContext, scope)
    private val transport = G1CommandTransport(bluetooth)
    private val hudPresenter = G1HudPresenter()
    val hudArbiter = HudArbiter()

    private val touchpadProbe = TouchpadProbeLog(clock = System::currentTimeMillis)

    /** Spike S2: raw touchpad/status frames, newest last (Device tab, debug builds). */
    val probeLog: StateFlow<List<String>> = touchpadProbe.entries
    private val throughputProbeState = MutableStateFlow("")
    val throughputProbeResult: StateFlow<String> = throughputProbeState.asStateFlow()

    // Transcript sources. Exactly one runs at a time; the switch owns that.
    val transcription = TranscriptionService(appContext)

    // The realtime transcriber is constructed once, so its audio source is a
    // switchable seam: the mic by default, a bundled fixture WAV during debug
    // audio injection (see startDebugAudioInjection).
    private val micDelegate = AudioRecordCapture()
    private val micCapture = SwitchableAudioCapture(micDelegate)
    private val realtimeTranscriber = OpenAIRealtimeTranscriber(
        keyStore = settingsRepository,
        capture = micCapture,
        model = { openAiTranscriptionModel.value },
    )
    private val omiLive = OmiLiveService(scope)
    private val omiSource = OmiTranscriptSource(
        service = omiLive,
        scope = scope,
        feedUrl = { settingsRepository.keyFor(OMI_RELAY_KEY_KIND) },
    ).also { it.onRawSegment = ::mirrorOmiSegmentToHud }
    private val sourceSwitch = TranscriptSourceSwitch(
        sources = mapOf(
            TranscriptionSource.DEVICE to transcription,
            TranscriptionSource.OPENAI_REALTIME to realtimeTranscriber,
            TranscriptionSource.OMI to omiSource,
        ),
        scope = scope,
    )
    private val recentTranscript = RecentTranscriptBuffer()

    private val providerFactory = ProviderFactory(settingsRepository)

    /**
     * The current FAST-tier provider, kept in step with [rebuildProvider] so
     * the classify closure below always calls through to the live provider
     * (a fresh key, or a changed active provider) rather than one snapshot
     * from construction time. `@Volatile` because [rebuildProvider] writes it
     * from a coroutine and the classify closure reads it from whichever
     * dispatcher [engine]'s live-transcript path happens to run on.
     */
    @Volatile
    private var fastProvider: AnswerProvider = providerFactory.makeFast(HelixSettings())

    val questionSensitivity: StateFlow<QuestionSensitivity> =
        settingsRepository.questionSensitivity.stateIn(
            scope,
            SharingStarted.Eagerly,
            QuestionSensitivity.BALANCED,
        )

    private val llmDetector = LlmQuestionDetector(
        classify = { prompt ->
            val provider = fastProvider
            // Keyless fallback: DeterministicProvider has no real classifier —
            // its canned prose would otherwise be parsed as a fabricated
            // "question". Throwing here routes straight to
            // LlmQuestionDetector's existing network-failure fallback (the
            // heuristic result), which is exactly the right behavior when
            // there is no model to call.
            if (provider.kind == ProviderKind.DETERMINISTIC) {
                throw IllegalStateException("No provider configured for question classification.")
            }
            provider.classify(prompt)
        },
        sensitivity = { questionSensitivity.value },
    )

    private val engine = ConversationEngine(
        settings = HelixSettings(),
        llmDetector = llmDetector,
        knowledgeProvider = { query -> knowledgeRepository.search(query) },
    )

    // MARK: - UI state

    val settings: StateFlow<HelixSettings> =
        settingsRepository.settings.stateIn(scope, SharingStarted.Eagerly, HelixSettings())

    val knowledgeItems = knowledgeRepository.items
    val sessions = sessionRepository.sessions

    val isListening: StateFlow<Boolean> = sourceSwitch.isListening
    val partialTranscript: StateFlow<String> = sourceSwitch.partialTranscript
    val speechError: StateFlow<String> = sourceSwitch.errorMessage
    /** The source currently producing transcript, or null when idle. */
    val activeSource: StateFlow<TranscriptionSource?> = sourceSwitch.active

    val transcriptionSource: StateFlow<TranscriptionSource> =
        settingsRepository.transcriptionSource.stateIn(scope, SharingStarted.Eagerly, TranscriptionSource.DEVICE)
    val questionMode: StateFlow<QuestionMode> =
        settingsRepository.questionMode.stateIn(scope, SharingStarted.Eagerly, QuestionMode.AUTO_DETECT)
    /**
     * The realtime transcription model, sanitized on read.
     *
     * A store written before batch-only ids were filtered out of the picker can
     * hold e.g. `gpt-transcribe` — a `/v1/audio/transcriptions` model the
     * realtime socket never streams, which strands the user on the first-delta
     * watchdog error with no way back. Coercing here (rather than only in the
     * picker) fixes it for the transcriber too, which reads this flow directly.
     */
    val openAiTranscriptionModel: StateFlow<String> =
        settingsRepository.openAiTranscriptionModel
            .map { stored ->
                ModelCatalog.sanitizeRealtimeTranscriptionModel(
                    stored,
                    com.artjiang.helix.speech.RealtimeEvents.DEFAULT_MODEL,
                )
            }
            .stateIn(
                scope, SharingStarted.Eagerly, com.artjiang.helix.speech.RealtimeEvents.DEFAULT_MODEL,
            )

    /**
     * "Notifications on glasses" (Device tab). Master gate for the 0x4B send
     * path — both Helix's own events and mirrored phone notifications — mirroring
     * iOS `forwardNotification`'s `glassesNotificationsEnabled` guard.
     */
    val glassesNotificationsEnabled: StateFlow<Boolean> =
        settingsRepository.glassesNotificationsEnabled.stateIn(scope, SharingStarted.Eagerly, true)

    /** "Head-up dashboard" (Device tab); gates the head-up datetime resync. */
    val glassesDashboardEnabled: StateFlow<Boolean> =
        settingsRepository.glassesDashboardEnabled.stateIn(scope, SharingStarted.Eagerly, true)

    fun setGlassesNotificationsEnabled(enabled: Boolean) {
        scope.launch { settingsRepository.setGlassesNotificationsEnabled(enabled) }
    }

    fun setGlassesDashboardEnabled(enabled: Boolean) {
        scope.launch { settingsRepository.setGlassesDashboardEnabled(enabled) }
    }

    // Declared before init: the isListening collector in init reads this flow
    // synchronously on Main.immediate during construction.
    private val debugInjectionStateFlow = MutableStateFlow(false)

    /** Bumped per injection start; a stale start coroutine must not fire. */
    private var debugInjectionGeneration = 0L

    /** True while the bundled test WAV is playing into the realtime pipeline. */
    val debugInjectionActive: StateFlow<Boolean> = debugInjectionStateFlow.asStateFlow()

    private val providerErrorState = MutableStateFlow("")
    /** Friendly text for the last answer-provider failure (401 etc.), cleared on success. */
    val providerError: StateFlow<String> = providerErrorState.asStateFlow()

    /**
     * The conversation as an ordered feed (bounded to [FEED_LIMIT]), read
     * straight off the repository so it survives process death — this used to
     * be a bare in-memory MutableStateFlow, which is why a restart lost the
     * whole conversation.
     */
    val feed: StateFlow<List<FeedEntry>> = feedRepository.entries

    /**
     * Monotonic feed-entry id. Resumed past the restored feed's high-water mark
     * by the initializer below: restarting at 0 over persisted rows would mint
     * duplicate ids, and the Assistant list keys its items by id.
     *
     * Only ever touched from [scope] (Main.immediate) — [appendFeed]'s callers
     * are all on it — so a plain Long needs no further synchronization.
     */
    private var nextFeedId = 0L

    private fun appendFeed(
        kind: FeedEntry.Kind,
        text: String,
        model: String? = null,
        question: String? = null,
        answerTier: AnswerTier? = null,
        speaker: String? = null,
        isUser: Boolean = false,
    ): FeedEntry? {
        val trimmed = text.trim()
        if (trimmed.isEmpty()) return null
        // Reserve the id synchronously: two appends in the same frame must not
        // race for it while the first is suspended on the store's mutex.
        val entry = FeedEntry(
            id = ++nextFeedId,
            kind = kind,
            text = trimmed,
            model = model,
            question = question,
            answerTier = answerTier,
            atMillis = System.currentTimeMillis(),
            speaker = speaker,
            isUser = isUser,
        )
        // Fire-and-forget onto the bridge scope: the store serializes writes
        // internally and does the file I/O on Dispatchers.IO, so the caller
        // (and the UI thread) never waits on the disk.
        scope.launch { feedRepository.append(entry) }
        return entry
    }

    /**
     * Starts a fresh conversation: clears the feed, the engine's dedup and
     * session memory, and the rolling transcript window.
     *
     * `engine.reset()` existed but was unreachable — there was no UI action
     * for it, so a user had no way out of a suppressed-question state short
     * of force-stopping the app.
     */
    fun startNewConversation() {
        // Invalidate active and queued answers before clearing. The epoch and
        // pending-order reset also guard a provider that returns after cancellation
        // (for example, a blocking call that does not observe cancellation), so
        // it cannot re-append an old answer into the fresh feed.
        invalidateAnswerSession()
        scope.launch {
            engine.reset()
            recentTranscript.clear()
            feedRepository.clear()
        }
        transcriptState.value = ""
        providerErrorState.value = ""
        hudDeliveryState.value = HudDeliveryReceipt()
        automaticNoteReceiptJob?.cancel()
        automaticNoteReceiptState.value = null
    }

    val leftLens: StateFlow<LensConnectionState> = bluetooth.leftState
    val rightLens: StateFlow<LensConnectionState> = bluetooth.rightState
    val isScanning: StateFlow<Boolean> = bluetooth.isScanning
    val discoveredPairs: StateFlow<List<DiscoveredPair>> = bluetooth.discoveredPairs
    val connectionPhase: StateFlow<String> = bluetooth.connectionPhase

    /**
     * SLA-T1 hint: set by [startScan]'s watchdog when a scan has run for
     * [SCAN_CONFLICT_TIMEOUT_MILLIS] without seeing a single G1 pair while the
     * official Even Realities app is installed. See [scanConflictHint].
     */
    private val scanConflictState = MutableStateFlow("")

    /**
     * The BLE manager's own error, or — when it has none — the advertising
     * exclusivity hint. A real BLE error (permission denied, adapter off, scan
     * failure) always wins, because it is a certainty and the hint is not.
     */
    val bluetoothError: StateFlow<String> =
        kotlinx.coroutines.flow.combine(
            bluetooth.errorMessage,
            scanConflictState,
        ) { bleError, hint -> if (bleError.isNotBlank()) bleError else hint }
            .stateIn(scope, SharingStarted.Eagerly, "")

    private val lastTurnState = MutableStateFlow<Turn?>(null)
    val lastTurn: StateFlow<Turn?> = lastTurnState.asStateFlow()

    private val transcriptState = MutableStateFlow("")
    val transcriptText: StateFlow<String> = transcriptState.asStateFlow()

    private val isAnsweringState = MutableStateFlow(false)
    val isAnswering: StateFlow<Boolean> = isAnsweringState.asStateFlow()

    /**
     * True once a turn has started answering but no token has arrived yet;
     * false the moment the first delta lands, or when the turn ends. A
     * reasoning model (e.g. gpt-5.5) emits nothing while it thinks, so a
     * correct SSE stream still looks like a stalled spinner followed by a
     * sudden burst of text — this flag lets the UI say "Thinking…" honestly
     * instead of leaving the wearer staring at a bare spinner.
     */
    private val answeringPhase = AnsweringPhaseTracker()
    private val isThinkingState = MutableStateFlow(false)
    val isThinking: StateFlow<Boolean> = isThinkingState.asStateFlow()

    private val batteryState = MutableStateFlow<Int?>(null)
    val batteryPercent: StateFlow<Int?> = batteryState.asStateFlow()

    private val chargingState = MutableStateFlow(false)
    val isCharging: StateFlow<Boolean> = chargingState.asStateFlow()

    private val hudPagesState = MutableStateFlow<List<G1HudPage>>(emptyList())
    val hudPages: StateFlow<List<G1HudPage>> = hudPagesState.asStateFlow()

    private val hudPageIndexState = MutableStateFlow(0)
    val hudPageIndex: StateFlow<Int> = hudPageIndexState.asStateFlow()

    /** ACK-backed route state; HUD preview pages alone are not delivery proof. */
    private val hudDeliveryState = MutableStateFlow(HudDeliveryReceipt())
    val hudDelivery: StateFlow<HudDeliveryReceipt> = hudDeliveryState.asStateFlow()
    private var nextHudDeliveryId = 0L
    private var activeHudDeliveryId = 0L

    /** Most recent final-only automatic Knowledge save, with immediate Undo. */
    private val automaticNoteReceiptState = MutableStateFlow<AutomaticNoteReceipt?>(null)
    val automaticNoteReceipt: StateFlow<AutomaticNoteReceipt?> =
        automaticNoteReceiptState.asStateFlow()
    private var automaticNoteReceiptJob: Job? = null

    private val eventLogState = MutableStateFlow<List<ConversationEvent>>(emptyList())
    val eventLog: StateFlow<List<ConversationEvent>> = eventLogState.asStateFlow()

    private val lastTouchpadState = MutableStateFlow("No touchpad input yet")
    val lastTouchpadSummary: StateFlow<String> = lastTouchpadState.asStateFlow()

    /**
     * Per-lens result of the last screen write, e.g. "left=DELIVERED
     * right=FAILED (2 pkts)".
     *
     * `sendScreen` reports success when EITHER lens took the screen (single-lens
     * links are supported), so a lens that consistently fails is otherwise
     * invisible — the app looks fine while one eye shows stale or partial text.
     */
    val lastScreenOutcome: String
        get() = transport.lastScreenOutcome

    private val displayPrefsState = MutableStateFlow(GlassesDisplayPrefs())
    val displayPrefs: StateFlow<GlassesDisplayPrefs> = displayPrefsState.asStateFlow()

    /** The provider that will actually answer — DETERMINISTIC when keyless. */
    private val effectiveProviderState = MutableStateFlow(ProviderKind.DETERMINISTIC)
    val effectiveProvider: StateFlow<ProviderKind> = effectiveProviderState.asStateFlow()

    val isGlassesConnected: Boolean
        get() = leftLens.value == LensConnectionState.READY || rightLens.value == LensConnectionState.READY

    // MARK: - Session plumbing

    private var sessionJob: Job? = null
    private var heartbeatCounter: Byte = 0

    /**
     * Priority the running [hudSession] draws at. Set before each present so
     * the session's arbiter gate uses the right rank for this content
     * (ANSWER for answers, NOTIFICATION for mirrored Omi segments).
     */
    private var hudPriority: HudArbiter.Priority = HudArbiter.Priority.ANSWER

    /** [hudSession]'s hold on the HUD; see [AnswerLeaseGate]. */
    private val answerGate = AnswerLeaseGate(hudArbiter)

    /**
     * The current G1 text lifecycle: 0x71 for every plain-text page and 0x18
     * to clear/exit. Owns its own timers; the phone-side page mirror follows it via
     * onPageChanged. Declared before [init] so a BLE disconnect callback
     * arriving during construction can never see it uninitialized.
     */
    private val hudSession = G1HudSession(
        scope = scope,
        sendScreen = { packets ->
            // sendScreenDetailed owns the left-then-400ms-then-right ordering
            // and holds the transport queue lock for the whole screen, so a
            // lifecycle timer can never interleave packets with another write.
            //
            // Auto-advance pages don't re-ask the arbiter, so check ownership
            // here: a Conversate menu drawn since must not be overwritten.
            if (answerGate.owns()) transport.sendScreenDetailed(packets)
            else G1ScreenDeliveryOutcome.failed(packets.size)
        },
        requestDisplay = { answerGate.request(hudPriority) },
        releaseDisplay = { answerGate.release() },
        // 0x18 clears the lens and drops the firmware back to its dashboard —
        // the wearer looks up, reads the answer, and it goes away. iOS never
        // blanks at all, so this is the one piece of the lifecycle with no
        // upstream reference; it is why the dwell is user-configurable.
        clearScreen = {
            if (answerGate.owns()) transport.send(G1Command(bytes = G1CommandEncoder.exitAllFunctions()))
        },
        completeDelayMillis = { hudDwellSeconds.value * 1_000L },
        // User-tunable page cadence. The vendor hard-codes 5 s
        // (`EvenAI.updateReplyToOSByTimer`), but reading speed in peripheral
        // vision is personal, so this is a slider.
        autoAdvanceMillis = { hudScrollSeconds.value * 1_000L },
        onPageChanged = { index -> hudPageIndexState.value = index },
        onDeliveryChanged = delivery@ { event ->
            if (event.deliveryId != activeHudDeliveryId) return@delivery
            val current = hudDeliveryState.value
            hudDeliveryState.value = current.applying(event)
        },
    )
    /** Seconds each HUD page/line holds before the display advances. */
    val hudScrollSeconds: StateFlow<Int> = settingsRepository.hudScrollSeconds
        .stateIn(scope, SharingStarted.Eagerly, SettingsRepository.DEFAULT_HUD_SCROLL_SECONDS)

    fun setHudScrollSeconds(seconds: Int) {
        scope.launch { settingsRepository.setHudScrollSeconds(seconds) }
    }

    /** Whether a right-pad triple tap toggles a transcription session. */
    val sessionTapToggleEnabled: StateFlow<Boolean> = settingsRepository.sessionTapToggleEnabled
        .stateIn(scope, SharingStarted.Eagerly, SettingsRepository.DEFAULT_SESSION_TAP_TOGGLE)

    fun setSessionTapToggleEnabled(enabled: Boolean) {
        scope.launch { settingsRepository.setSessionTapToggleEnabled(enabled) }
    }

    /** Seconds an answer dwells on the lens before Helix lets it blank. */
    val hudDwellSeconds: StateFlow<Int> = settingsRepository.hudDwellSeconds
        .stateIn(scope, SharingStarted.Eagerly, SettingsRepository.DEFAULT_HUD_DWELL_SECONDS)

    fun setHudDwellSeconds(seconds: Int) {
        scope.launch { settingsRepository.setHudDwellSeconds(seconds) }
    }

    // MARK: - Conversate

    val prepNoteRepository = PrepNoteRepository(File(appContext.filesDir, "prep_notes.json"), scope)

    val conversateEnabled: StateFlow<Boolean> = settingsRepository.conversateEnabled
        .stateIn(scope, SharingStarted.Eagerly, false)

    val conversatePrefs: StateFlow<ConversatePrefs> = settingsRepository.conversatePrefs
        .stateIn(scope, SharingStarted.Eagerly, ConversatePrefs())

    /**
     * G2-style live captions + cues (spec 2026-10-04). While enabled it owns the
     * touchpad and, during a session, the HUD; disabled, the app is unchanged.
     */
    val conversate = ConversateController(
        scope = scope,
        sendScreen = { packets -> transport.sendScreenDetailed(packets) },
        clearScreen = { transport.send(G1Command(bytes = G1CommandEncoder.exitAllFunctions())) },
        arbiter = hudArbiter,
        classify = { prompt, maxTokens ->
            val provider = fastProvider
            // Same keyless guard as the question classifier: the deterministic
            // provider's canned prose must never be parsed as cues.
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
                // Stop any legacy answer lifecycle so its dwell timer cannot
                // blank the lens under the session.
                hudSession.reset()
                if (!isListening.value) startListening()
            }
            SessionEffect.End -> if (isListening.value) stopListening()
            is SessionEffect.SetPaused -> if (effect.paused) stopListening() else startListening()
            is SessionEffect.SetCaptions -> setConversatePrefs(conversatePrefs.value.copy(captionsOn = effect.on))
            is SessionEffect.SetCues -> setConversatePrefs(conversatePrefs.value.copy(cuesOn = effect.on))
            else -> Unit
        }
    }

    /** Even R1 ring as a Conversate controller (Plan B). */
    private val ring = R1Transport(appContext, scope)
    val ringState: StateFlow<RingLinkState> = ring.state
    val ringName: StateFlow<String?> = ring.deviceName
    val ringLastGesture: StateFlow<String> = ring.lastGesture
    val ringEnabled: StateFlow<Boolean> = settingsRepository.ringEnabled
        .stateIn(scope, SharingStarted.Eagerly, false)

    fun setRingEnabled(enabled: Boolean) {
        scope.launch { settingsRepository.setRingEnabled(enabled) }
    }

    /** Drops and re-establishes the ring link (e.g. after force-stopping the Even app). */
    fun reconnectRing() {
        ring.stop()
        if (conversateEnabled.value && ringEnabled.value) ring.start()
    }

    fun setConversateEnabled(enabled: Boolean) {
        scope.launch { settingsRepository.setConversateEnabled(enabled) }
    }

    fun setConversatePrefs(prefs: ConversatePrefs) {
        scope.launch { settingsRepository.setConversatePrefs(prefs) }
    }

    fun startConversate(prepNoteId: String?) = conversate.start(prepNoteId)

    fun endConversate() = conversate.end()

    fun upsertPrepNote(note: PrepNote) {
        scope.launch { prepNoteRepository.upsert(note) }
    }

    fun deletePrepNote(id: String) {
        scope.launch { prepNoteRepository.delete(id) }
    }

    private var positionCounter: Byte = 0

    init {
        bluetooth.onInbound = ::handleInbound
        bluetooth.onBothLensesReady = ::startGlassesSession
        bluetooth.onAllDisconnected = ::stopGlassesSession

        // One-shot repair of a persisted batch-only transcription model. The
        // read-side sanitize in [openAiTranscriptionModel] already keeps the
        // app working, but leaving the bad id on disk means the Settings field
        // and the effective model disagree forever.
        scope.launch {
            val stored = settingsRepository.openAiTranscriptionModel.first()
            val safe = ModelCatalog.sanitizeRealtimeTranscriptionModel(
                stored,
                com.artjiang.helix.speech.RealtimeEvents.DEFAULT_MODEL,
            )
            if (safe != stored) settingsRepository.setOpenAiTranscriptionModel(safe)
        }

        // Resume the feed id counter past whatever was restored from disk.
        // Runs before any appendFeed can: transcription is user-initiated and
        // the BLE link is not up yet at construction time.
        scope.launch {
            val restored = feedRepository.loaded()
            nextFeedId = maxOf(nextFeedId, restored.maxOfOrNull { it.id } ?: 0L)
        }

        // Sources may emit on OkHttp/audio threads; hop to the bridge scope.
        sourceSwitch.onSegment = { segment ->
            scope.launch {
                // Conversate takes partials too (live captions); the legacy
                // pipeline below still only acts on finals.
                conversate.onSegment(segment)
                handleSegment(segment)
            }
        }
        scope.launch { conversateEnabled.collect { conversate.setEnabled(it) } }
        scope.launch { conversatePrefs.collect { conversate.setPrefs(it) } }
        scope.launch { prepNoteRepository.notes.collect { conversate.setPrepNotes(it) } }
        // Ring gestures arrive on a binder thread; the controller is main-scope only.
        ring.onGesture = { gesture -> scope.launch { conversate.handleRing(gesture) } }
        scope.launch {
            combine(conversateEnabled, ringEnabled) { conversateOn, ringOn -> conversateOn && ringOn }
                .distinctUntilChanged()
                .collect { wanted -> if (wanted) ring.start() else ring.stop() }
        }

        // Keeps the glasses-side 0x04 filter in step with the user's list.
        observeNotificationWhitelist()

        // Rebuild the provider whenever settings or a stored key changes, so
        // "use for answers" and a fresh key take effect without a restart.
        scope.launch {
            settings.collect { value ->
                engine.updateSettings(value)
                rebuildProvider(value)
            }
        }
        scope.launch {
            settingsRepository.keyRevision.collect {
                rebuildProvider(settings.value)
            }
        }

        // Debug-injection cleanup for sessions that end WITHOUT stopListening()
        // (the transcriber failing itself on a socket/auth error): once the
        // injected session has actually been seen listening and then stops,
        // swap the mic back in. The saw-listening guard keeps the stop->start
        // transition inside startDebugAudioInjection from restoring early.
        scope.launch {
            var sawListening = false
            isListening.collect { listening ->
                if (!debugInjectionStateFlow.value) {
                    sawListening = false
                } else if (listening) {
                    sawListening = true
                } else if (sawListening) {
                    sawListening = false
                    restoreMicCaptureAfterInjection()
                }
            }
        }
    }

    private suspend fun rebuildProvider(current: HelixSettings) {
        // The factory reads the KeyStore on every make(), so a newly stored key
        // takes effect without rebuilding the factory itself. Run on IO: the
        // first access initializes EncryptedSharedPreferences (Keystore ops,
        // routinely 100ms+), which would stall the first frame on Main.
        // Two tiers: FAST (light model) answers auto-detected questions, SMART
        // (smart/reasoning model) answers deliberate asks.
        val (fast, smart) = kotlinx.coroutines.withContext(Dispatchers.IO) {
            providerFactory.makeFast(current) to providerFactory.make(current)
        }
        fastProvider = fast
        engine.setProviders(fast, smart)
        effectiveProviderState.value = smart.kind
    }

    // MARK: - Settings

    fun updateSettings(transform: (HelixSettings) -> HelixSettings) {
        scope.launch { settingsRepository.update(transform) }
    }

    fun setApiKey(kind: String, value: String?) {
        // Key presence is derived from the encrypted store (hasApiKey) — no
        // mirrored flag in settings JSON, which could go stale across
        // backup/restore since encrypted prefs don't survive it.
        settingsRepository.setKey(kind, value)
        providerKindOf(kind)?.let { providerKind ->
            modelCatalog.invalidate(providerKind)
            catalogState.value = catalogState.value - kind
            if (value.isNullOrBlank()) dismissKeyCheck(kind) else checkApiKey(kind)
        }
    }

    fun hasApiKey(kind: String): Boolean = settingsRepository.hasKey(kind)

    // MARK: - Model catalog / key validation

    val modelCatalog = ModelCatalog()

    sealed interface KeyCheckState {
        data object Idle : KeyCheckState
        data object Checking : KeyCheckState
        data class Valid(val chatModelCount: Int, val checkedAtMillis: Long) : KeyCheckState
        data class Unsupported(val message: String) : KeyCheckState
        data class Invalid(val message: String) : KeyCheckState
        /** Transient (network, rate limit, parse) — the key itself may be fine. */
        data class Failed(val message: String) : KeyCheckState
    }

    private val keyCheckState = MutableStateFlow<Map<String, KeyCheckState>>(emptyMap())
    /** Per-provider verdict of the last key validation, keyed by [ProviderKind.name]. */
    val keyCheck: StateFlow<Map<String, KeyCheckState>> = keyCheckState.asStateFlow()

    private val catalogState = MutableStateFlow<Map<String, ModelCatalog.CacheEntry>>(emptyMap())
    /** Raw discovered models per provider; every role derives from one fetch. */
    val catalog: StateFlow<Map<String, ModelCatalog.CacheEntry>> = catalogState.asStateFlow()

    /** Bumped per kind so a slow earlier check can't overwrite a newer verdict. */
    private val keyCheckGeneration = HashMap<String, Long>()

    private fun providerKindOf(kind: String): ProviderKind? =
        ProviderKind.entries.firstOrNull { it.name == kind && it != ProviderKind.DETERMINISTIC }

    /**
     * Validates [candidate] (typed, unsaved) or the stored key when null by
     * listing the provider's models. Never persists anything.
     */
    fun checkApiKey(kind: String, candidate: String? = null) {
        val providerKind = providerKindOf(kind) ?: return
        val generation = (keyCheckGeneration[kind] ?: 0L) + 1
        keyCheckGeneration[kind] = generation
        keyCheckState.value = keyCheckState.value + (kind to KeyCheckState.Checking)
        scope.launch {
            val key = candidate?.trim()?.takeIf { it.isNotEmpty() }
                ?: kotlinx.coroutines.withContext(Dispatchers.IO) { settingsRepository.keyFor(kind) }
            val result = if (key.isNullOrBlank()) {
                KeyCheckResult.Invalid("Invalid API key")
            } else {
                modelCatalog.checkKey(providerKind, key)
            }
            if (keyCheckGeneration[kind] != generation) return@launch
            val verdict = when (result) {
                is KeyCheckResult.Ok -> {
                    modelCatalog.cached(providerKind)?.let { entry ->
                        catalogState.value = catalogState.value + (kind to entry)
                    }
                    val chatCount = result.models.count { ModelCatalog.roleOf(it.id, providerKind) == ModelRole.CHAT }
                    KeyCheckState.Valid(chatCount, System.currentTimeMillis())
                }
                is KeyCheckResult.Invalid -> KeyCheckState.Invalid(result.message)
                is KeyCheckResult.Unsupported -> KeyCheckState.Unsupported(result.message)
                is KeyCheckResult.Failed -> KeyCheckState.Failed(result.message)
            }
            keyCheckState.value = keyCheckState.value + (kind to verdict)
        }
    }

    /** Refreshes the model list with the stored key (TTL-gated unless [force]). */
    fun refreshModels(kind: String, force: Boolean = false) {
        val providerKind = providerKindOf(kind) ?: return
        scope.launch {
            val key = kotlinx.coroutines.withContext(Dispatchers.IO) { settingsRepository.keyFor(kind) }
                ?: return@launch
            modelCatalog.listModels(providerKind, key, forceRefresh = force)
            modelCatalog.cached(providerKind)?.let { entry ->
                catalogState.value = catalogState.value + (kind to entry)
            }
        }
    }

    /** Pure, synchronous: picker options from the current catalog state. */
    fun modelOptions(kind: String, role: ModelRole = ModelRole.CHAT, pinned: String? = null): List<String> {
        val providerKind = providerKindOf(kind) ?: return emptyList()
        return ModelCatalog.options(catalogState.value[kind]?.models, providerKind, role, pinned)
    }

    fun dismissKeyCheck(kind: String) {
        keyCheckState.value = keyCheckState.value - kind
    }

    // MARK: - Bluetooth

    private var scanConflictJob: Job? = null

    /**
     * Starts a scan, plus the SLA-T1 watchdog.
     *
     * A connected BLE peripheral stops advertising. If the official Even
     * Realities app (`com.even.g1`) holds GATT links to both lenses, Helix's
     * name-based scan can never see them and the UI would sit on "Scanning..."
     * forever. Android gives no reliable way to observe another app's GATT
     * links, so this is a heuristic: zero pairs found after
     * [SCAN_CONFLICT_TIMEOUT_MILLIS] *and* that package installed. The message
     * is worded as a possibility, never a diagnosis.
     */
    fun startScan() {
        scanConflictJob?.cancel()
        scanConflictState.value = ""
        bluetooth.startScan()
        scanConflictJob = scope.launch {
            delay(SCAN_CONFLICT_TIMEOUT_MILLIS)
            val hint = scanConflictHint(
                foundPairs = discoveredPairs.value.size,
                isScanning = isScanning.value,
                vendorAppInstalled = isPackageInstalled(EVEN_REALITIES_PACKAGE),
            )
            if (hint != null) {
                android.util.Log.i(
                    G1_LOG_TAG,
                    "Scan found no G1 pairs in ${SCAN_CONFLICT_TIMEOUT_MILLIS}ms; " +
                        "$EVEN_REALITIES_PACKAGE is installed — surfacing advertising-exclusivity hint.",
                )
                scanConflictState.value = hint
            }
        }
    }

    fun stopScan() {
        scanConflictJob?.cancel()
        scanConflictJob = null
        bluetooth.stopScan()
    }

    fun connect(pair: DiscoveredPair) {
        scanConflictJob?.cancel()
        scanConflictState.value = ""
        bluetooth.connect(pair)
    }

    fun disconnectGlasses() = bluetooth.disconnect()

    fun clearBluetoothError() {
        scanConflictState.value = ""
        bluetooth.clearError()
    }

    /** True when [packageName] is installed on this device. */
    private fun isPackageInstalled(packageName: String): Boolean =
        runCatching {
            appContext.packageManager.getPackageInfo(packageName, 0)
            true
        }.getOrDefault(false)

    /**
     * Inbound BLE notifications arrive on a binder thread. Everything below
     * touches main-thread-only state (the recognizer) or UI StateFlows, so the
     * whole handler hops to the bridge scope (Main.immediate) first.
     */
    private fun handleInbound(data: ByteArray, side: G1Side) {
        scope.launch {
            // Decode once and share the event with the transport (it used to
            // decode the same frame a second time internally).
            val status = G1StatusDecoder.decode(data)
            transport.handleDecoded(status, side)
            if (data.size >= 2 && data[0] == 0xF5.toByte()) {
                touchpadProbe.record("${side.name} F5 idx=${data[1].toInt() and 0xFF}")
            }

            when (status) {
                is G1StatusEvent.Battery -> {
                    batteryState.value = status.percent
                    chargingState.value = status.isCharging
                }

                is G1StatusEvent.CaseBatteryPercent -> batteryState.value = status.percent
                is G1StatusEvent.CaseCharging -> chargingState.value = status.isCharging
                // The firmware dashboard activates on head-up once datetime is
                // synced; re-sync opportunistically so its clock stays accurate
                // — but only while the dashboard is enabled (mirrors iOS
                // HelixNativeBridge.handleHeadUp's dashboardEnabled guard).
                is G1StatusEvent.HeadUp -> if (glassesDashboardEnabled.value) syncDateTime()
                else -> Unit
            }

            val touchpadSide = if (side == G1Side.RIGHT) G1TouchpadSide.RIGHT else G1TouchpadSide.LEFT
            conversate.handleStatus(status)

            val frame = G1StatusDecoder.decodeTouchpad(data, touchpadSide) ?: return@launch
            lastTouchpadState.value = "${touchpadSide.name.lowercase()} pad - index ${frame.notifyIndex}"
            // Conversate spec §4.1: while enabled it owns every touchpad index.
            // The legacy decider (manual question / StopListening / ClearHud /
            // tap counter) must never see the event.
            if (conversate.handleTouchpad(frame)) return@launch
            val hasAnswer = engine.activeAnswer != null
            // Triple tap on the RIGHT pad toggles a transcription session.
            //
            // The firmware has no triple-tap event — the official demo app's
            // own handler (ble_manager.dart:154-175) sees only indices
            // 0/1/23/24 — so a burst is counted here from repeated index-1
            // frames. Only counted while NO answer is on screen: with an answer
            // up, index 1 is page-forward, and routing it through a 400 ms
            // burst window would make every page turn feel sluggish.
            if (frame.notifyIndex == SINGLE_TAP_INDEX &&
                touchpadSide == G1TouchpadSide.RIGHT &&
                !hasAnswer &&
                sessionTapToggleEnabled.value
            ) {
                onRightPadTap()
                return@launch
            }
            applyTouchpad(TouchpadDecider.decide(frame.notifyIndex, touchpadSide, hasAnswer))
        }
    }

    private fun applyTouchpad(effect: TouchpadEffect) {
        when (effect) {
            is TouchpadEffect.ChangePage -> showPage(hudPageIndexState.value + effect.delta)
            TouchpadEffect.TriggerManualQuestion -> triggerManualQuestion()
            TouchpadEffect.StopListening -> stopListening()
            TouchpadEffect.ToggleListening -> toggleListening()
            TouchpadEffect.ClearHud -> {
                // Exit tap: kill the lifecycle first so a pending 0x71 or
                // auto-advance can't redraw after the explicit exit.
                hudSession.reset()
                hudPagesState.value = emptyList()
                hudPageIndexState.value = 0
                scope.launch {
                    transport.send(G1Command(bytes = G1CommandEncoder.exitAllFunctions()))
                    answerGate.release()
                }
            }

            TouchpadEffect.None -> Unit
        }
    }

    // MARK: - Glasses session

    private fun startGlassesSession() {
        stopGlassesSession()
        sessionJob = scope.launch {
            // Init handshake (0x4D 0xFB, ACK 0xC9), with the legacy fallback.
            val acked = transport.send(G1Command.withAck(G1CommandEncoder.initHandshake()))
            if (!acked) transport.send(G1Command(bytes = byteArrayOf(0x4D, 0x01)))

            transport.send(G1Command(bytes = G1CommandEncoder.silentModeOff()))
            transport.send(G1Command(bytes = G1CommandEncoder.wearDetectionOff()))
            transport.send(
                G1Command(
                    bytes = G1CommandEncoder.dateTimeSync(System.currentTimeMillis(), nextPositionCounter()),
                ),
            )
            applyGlassesDisplaySettings()
            // The firmware's own notification filter is per-connection state:
            // push it now so a whitelist edited while disconnected takes effect.
            pushNotificationWhitelist()
            // A reconnected lens shows the firmware dashboard: put the
            // Conversate screen (if any) back.
            conversate.redraw()

            // Heartbeat every 10 s; battery poll every 6th beat (60 s).
            var beat = 0
            while (isActive) {
                transport.send(G1Command(bytes = G1CommandEncoder.heartbeat(nextHeartbeatCounter())))
                if (beat % 6 == 0) transport.send(G1Command(bytes = G1CommandEncoder.batteryPoll()))
                beat += 1
                delay(HEARTBEAT_INTERVAL_MILLIS)
            }
        }
    }

    private fun stopGlassesSession() {
        sessionJob?.cancel()
        sessionJob = null
        // Disconnect: drop any pending 0x71 / auto-advance so it cannot fire
        // against the next connection's screen.
        hudSession.reset()
        if (hudDeliveryState.value.phase == HudDeliveryPhase.SENDING) {
            hudDeliveryState.value = hudDeliveryState.value.copy(
                phase = HudDeliveryPhase.FAILED,
                outcome = "Glasses disconnected before delivery completed.",
            )
        }
        scope.launch { transport.reset() }
    }

    /**
     * Pushes brightness / head-up angle / display position from [displayPrefs].
     *
     * Display settings go to BOTH lenses.
     *
     * RETRACTED (2026-08-28): an earlier revision routed brightness (0x01),
     * head-up angle (0x0B) and display position (0x26) to the RIGHT lens only,
     * citing "SLA-L3 / the vendor app". That citation was wrong — the vendor
     * demo (`even-realities/EvenDemoApp` @ 3899aac) contains NO brightness,
     * head-up-angle or display-position command at all, so it cannot be the
     * source of a right-only rule. Peer review caught the fabricated citation.
     *
     * Right-only also regressed a supported state: `isGlassesConnected` is
     * `left READY || right READY`, so on a left-lens-only link every display
     * setting became a silent no-op. Both-lenses is the behaviour that shipped
     * and was observed working on hardware (the user confirmed brightness
     * changes are visible), so it stands until a real source says otherwise.
     *
     * 0x26 IS NO LONGER SENT HERE (2026-08-30). See SLA-L3b: this repo holds two
     * irreconcilable claims about that byte — `G1Commands.displayPosition`
     * (citing MentraOS) treats it as an 8-byte HUD position, while
     * `docs/research/g1-ble-protocol.md:41` calls it DASHBOARD_VISIBILITY
     * ("show/hide dashboard, must be followed by 0x18"). The vendor demo
     * implements no such command at all, so neither claim has an authoritative
     * source, and NOBODY HAS EVER OBSERVED 0x26 MOVE THE HUD on this hardware.
     *
     * Meanwhile it is the ONLY ACK-gated display command, and a lens that fails
     * to ACK it keeps its previous position while the other lens moves — the
     * left/right fusion mismatch the wearer reported. Brightness (0x01) and
     * head-up angle (0x0B) are fire-and-forget and are both confirmed working
     * on hardware, which is exactly why they are kept and this one is not.
     *
     * Sending an unverified command on every connect and every slider drag is
     * not worth a symptom we can see. [probeDisplayPositionCommand] exists to
     * settle what 0x26 really does; once observed, either restore it here or
     * delete the encoder.
     */
    suspend fun applyGlassesDisplaySettings() {
        val display = displayPrefsState.value
        transport.send(
            G1Command(
                bytes = G1CommandEncoder.brightness(display.brightness, display.autoBrightness),
            ),
        )
        transport.send(
            G1Command(
                bytes = G1CommandEncoder.headUpAngle(display.headUpAngle),
            ),
        )
    }

    /**
     * Applies HUD height/depth using the mandatory two-phase preview/commit.
     *
     * SLA-L3b: `0x26` must be sent twice — once with the preview bit set so the
     * wearer can see the placement, then again with it clear to commit and
     * dismiss the preview. An earlier revision sent only the preview (byte 5
     * hard-coded to 1) on every connect and every slider change, which left the
     * preview stuck on the lens forever. That is the "dashboard appears and
     * stays on" symptom, and it is why the HUD never appeared to move.
     */
    fun applyDisplayPosition() {
        if (!isGlassesConnected) {
            providerErrorState.value = "Connect the glasses first."
            return
        }
        positionJob?.cancel()
        positionJob = scope.launch {
            val display = displayPrefsState.value
            val previewOk = transport.send(
                G1Command.withAck(
                    G1CommandEncoder.displayPosition(
                        height = display.displayHeight,
                        depth = display.displayDepth,
                        counter = nextPositionCounter(),
                        preview = true,
                    ),
                ),
            )
            // The reference says "a few seconds later". The pause is the point:
            // it is how long the wearer gets to see the placement before it is
            // committed. Cancelling this job mid-dwell (another slider change)
            // supersedes it, and the new push starts its own preview.
            delay(POSITION_PREVIEW_DWELL_MILLIS)
            val commitOk = transport.send(
                G1Command.withAck(
                    G1CommandEncoder.displayPosition(
                        height = display.displayHeight,
                        depth = display.displayDepth,
                        counter = nextPositionCounter(),
                        preview = false,
                    ),
                ),
            )
            displayProbeState.value = when {
                previewOk && commitOk -> "Position applied (h=${display.displayHeight}, d=${display.displayDepth})."
                previewOk -> "Preview shown but the commit was not acknowledged — tap Clear dashboard."
                else -> "The glasses did not acknowledge the position command."
            }
        }
    }

    private var positionJob: Job? = null

    /**
     * Clears the firmware dashboard / stuck position preview from the lenses
     * (0x18). Kept as a rescue for a preview that was never committed.
     */
    fun clearGlassesDashboard() {
        if (!isGlassesConnected) {
            providerErrorState.value = "Connect the glasses first."
            return
        }
        positionJob?.cancel()
        scope.launch {
            val ok = transport.send(G1Command(bytes = G1CommandEncoder.exitAllFunctions()))
            displayProbeState.value =
                if (ok) "Dashboard cleared (0x18)." else "0x18 was not accepted by either lens."
        }
    }

    private val displayProbeState = MutableStateFlow("")

    /** Result of the last position apply / dashboard clear, for the Device tab. */
    val displayProbeResult: StateFlow<String> = displayProbeState.asStateFlow()

    private var displayPushJob: Job? = null

    /**
     * Conflated push: rapid preference updates (a slider drag) collapse into
     * one BLE burst instead of queueing an ACK-gated command per frame, which
     * could starve the heartbeat behind the transport queue. A push that has
     * already started sending is never cancelled mid-burst.
     */
    fun pushGlassesDisplaySettings() {
        if (!isGlassesConnected) return
        displayPushJob?.cancel()
        displayPushJob = scope.launch {
            delay(DISPLAY_PUSH_DEBOUNCE_MILLIS)
            kotlinx.coroutines.withContext(kotlinx.coroutines.NonCancellable) {
                applyGlassesDisplaySettings()
            }
        }
    }

    /** Updates a display preference and pushes it to the glasses immediately. */
    fun updateDisplayPrefs(transform: (GlassesDisplayPrefs) -> GlassesDisplayPrefs) {
        displayPrefsState.value = transform(displayPrefsState.value)
        pushGlassesDisplaySettings()
    }

    private fun syncDateTime() {
        scope.launch {
            transport.send(
                G1Command(
                    bytes = G1CommandEncoder.dateTimeSync(System.currentTimeMillis(), nextPositionCounter()),
                ),
            )
        }
    }

    private fun nextHeartbeatCounter(): Byte {
        heartbeatCounter = (heartbeatCounter + 1).toByte()
        return heartbeatCounter
    }

    private fun nextPositionCounter(): Byte {
        positionCounter = (positionCounter + 1).toByte()
        return positionCounter
    }

    /**
     * Spike S3: alternate two full 5-line screens [screens] times and report
     * per-screen send latency (both lenses ACKed). Blanks the lens afterwards.
     */
    fun runThroughputProbe(screens: Int = 20) {
        if (!isGlassesConnected) {
            throughputProbeState.value = "Glasses not connected"
            return
        }
        scope.launch {
            throughputProbeState.value = "Running…"
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
            throughputProbeState.value = ProbeStats.of(durations).summary() + " failures=$failures"
        }
    }

    // MARK: - HUD output

    /** Paginates [text] locally and runs the official HUD lifecycle for it. */
    fun presentToGlasses(
        text: String,
        priority: HudArbiter.Priority = HudArbiter.Priority.ANSWER,
        ownerFeedEntryId: Long? = null,
        answerFeedEntryIds: Set<Long> = ownerFeedEntryId?.let(::setOf) ?: emptySet(),
    ) {
        val trimmed = text.trim()
        if (trimmed.isEmpty()) return
        // During a Conversate session answers and notices become cues; the
        // session owns the lens.
        if (conversate.isLive.value) {
            conversate.offerExternal(trimmed, priority)
            return
        }
        val pages = hudPresenter.textPages(trimmed)
        val deliveryId = ++nextHudDeliveryId
        activeHudDeliveryId = deliveryId
        if (!isGlassesConnected) {
            // Keep the phone-side preview in sync even without glasses.
            hudSession.reset()
            hudPagesState.value = pages
            hudPageIndexState.value = 0
            hudDeliveryState.value = HudDeliveryReceipt(
                ownerFeedEntryId = ownerFeedEntryId,
                answerFeedEntryIds = answerFeedEntryIds,
                phase = HudDeliveryPhase.PHONE_ONLY,
                pageIndex = 0,
                pageCount = pages.size,
                outcome = "No ready glasses lens.",
            )
            // Say so. Returning silently is what made "Send to glasses" look
            // broken: the button did exactly nothing the user could perceive.
            providerErrorState.value = "Glasses not connected — the answer stayed on your phone."
            return
        }
        hudPriority = priority
        // The phone-side mirror (Device tab preview + "page n of m" pill) is
        // set eagerly. DEVIATION from the pre-lifecycle code, which asked the
        // arbiter first so a refused draw left no pages to page over: paging is
        // now delegated to hudSession, which holds no pages when a draw was
        // refused, so a refused draw can no longer push phantom pages to the
        // glasses. The preview showing text the glasses declined is cosmetic.
        hudPagesState.value = pages
        hudPageIndexState.value = 0
        hudDeliveryState.value = HudDeliveryReceipt(
            ownerFeedEntryId = ownerFeedEntryId,
            answerFeedEntryIds = answerFeedEntryIds,
            phase = HudDeliveryPhase.SENDING,
            pageIndex = 0,
            pageCount = pages.size,
        )
        // present() cancels the previous answer's pending 0x71 / auto-advance:
        // a stale completion landing here would blank the page we just drew.
        hudSession.present(pages, deliveryId)
    }

    /** Moves to [index] (clamped) and re-pushes that plain-text page at 0x71. */
    fun showPage(index: Int) {
        val pages = hudPagesState.value
        if (pages.isEmpty()) return
        val clamped = index.coerceIn(0, pages.size - 1)
        hudPageIndexState.value = clamped
        if (!isGlassesConnected) return
        hudPriority = HudArbiter.Priority.ANSWER
        hudSession.showPage(clamped)
    }

    fun showPreviousPage() = showPage(hudPageIndexState.value - 1)

    fun showNextPage() = showPage(hudPageIndexState.value + 1)

    // MARK: - Listening / answering

    fun toggleListening() {
        if (isListening.value) stopListening() else startListening()
    }

    /** Starts the selected [transcriptionSource]; the switch stops any other. */
    /**
     * Starts a transcription session. Both triggers land here — the app's own
     * start control and the glasses' triple tap — so the HUD notice and the
     * reminder cadence are identical whichever way the session began.
     */
    fun startListening() {
        val wasListening = isListening.value
        // A new session is a new conversation: clear per-session dedup state so
        // a question asked in an earlier session is answerable again. Without
        // this the suppressor persists for the whole process lifetime and
        // silently drops repeat questions (no answer ever reaches the feed).
        if (!wasListening) {
            // A plain Stop -> Start is a real session boundary too. Cancel and
            // invalidate provider work before resetting engine memory; a
            // blocking provider that returns after cancellation cannot append
            // its old answer into the restarted session.
            invalidateAnswerSession()
            scope.launch {
                engine.reset()
                // A stop -> start within the 60s window must not carry the prior
                // session's transcript tail into the new session's first
                // ON_DEMAND "Ask now" — startNewConversation() already clears
                // this for the explicit reset path, so a plain restart needs the
                // same treatment.
                recentTranscript.clear()
            }
        }
        sourceSwitch.start(transcriptionSource.value)
        // Only announce a session that actually began: a redundant start (the
        // user taps the app button while a triple-tap session is already
        // running) must not repaint the banner over live content.
        if (!wasListening) announceSessionStart()
    }

    fun stopListening() {
        val wasListening = isListening.value
        sourceSwitch.stop()
        restoreMicCaptureAfterInjection()
        if (wasListening) announceSessionStop()
    }

    // MARK: - Triple-tap session toggle

    private val tapCounter = G1TapCounter()
    private var tapBurstJob: Job? = null

    /**
     * Accumulates a right-pad tap and schedules the burst to be resolved once
     * the multi-tap window closes.
     *
     * A burst cannot be classified on arrival: the third tap of a triple looks
     * exactly like the first tap of a single until the window expires with no
     * successor. The trailing wake is therefore inherent, not a design choice.
     */
    private fun onRightPadTap() {
        tapCounter.onTap(G1TouchpadSide.RIGHT)?.let(::applyTapBurst)
        tapBurstJob?.cancel()
        val wait = tapCounter.millisUntilExpiry() ?: return
        tapBurstJob = scope.launch {
            delay(wait)
            tapCounter.pollExpired()?.let(::applyTapBurst)
        }
    }

    /**
     * A completed right-pad burst. Three taps toggle the session; a single tap
     * keeps its existing meaning (manual question) so the gesture the wearer
     * already knows is not taken away by enabling this feature.
     */
    private fun applyTapBurst(burst: G1TapCounter.Burst) {
        when {
            burst.count >= SESSION_TOGGLE_TAP_COUNT -> toggleListening()
            burst.count == 1 -> triggerManualQuestion()
            // A double tap is deliberately inert: it is the most likely
            // mis-click on the way to a triple, and firing a question for it
            // would make the triple-tap gesture feel unreliable.
            else -> Unit
        }
    }

    // MARK: - Session HUD notices

    private var sessionNoticeJob: Job? = null

    /** Wall-clock start of the running session, for the reminder's elapsed time. */
    private var sessionStartedAtMillis: Long = 0

    /**
     * Paints "Transcription started" and arms the recurring reminder.
     *
     * The reminder exists because the wearer has no other honest signal that
     * the microphone is live: the phone may be pocketed, and the HUD is blank
     * between answers. A session left running would otherwise be invisible to
     * the person wearing it.
     */
    private fun announceSessionStart() {
        sessionStartedAtMillis = System.currentTimeMillis()
        sessionNoticeJob?.cancel()
        presentSessionNotice(HudSessionNotices.SESSION_START)
        sessionNoticeJob = scope.launch {
            while (isActive) {
                delay(HudSessionNotices.REMINDER_INTERVAL_MILLIS)
                // The session may have ended while we slept; never remind about
                // a microphone that is already closed.
                if (!isListening.value) return@launch
                presentSessionNotice(
                    HudSessionNotices.reminder(
                        System.currentTimeMillis() - sessionStartedAtMillis,
                    ),
                )
            }
        }
    }

    private fun announceSessionStop() {
        sessionNoticeJob?.cancel()
        sessionNoticeJob = null
        presentSessionNotice(HudSessionNotices.SESSION_STOP)
    }

    /**
     * Draws a session notice at NOTIFICATION priority.
     *
     * Deliberately NOT [HudArbiter.Priority.ANSWER]: a reminder firing mid-answer
     * must lose to the answer the wearer is reading rather than blank it. The
     * arbiter refuses the lower rank and the notice is simply skipped — the
     * next reminder comes round in ten minutes.
     */
    private fun presentSessionNotice(text: String) {
        if (!isGlassesConnected) return
        presentToGlasses(text, HudArbiter.Priority.NOTIFICATION)
    }

    fun clearSpeechError() {
        sourceSwitch.clearError()
        omiLive.clearError()
    }

    // MARK: - Debug audio injection (debug builds only)

    /**
     * Debug-build-only test hook (long-press on the mic): swaps the realtime
     * transcriber's audio source from the microphone to the bundled fixture
     * WAV (`src/debug/assets`), selects the OpenAI Realtime source, and starts
     * listening — exercising the REAL pipeline end to end: WebSocket session,
     * streaming partials, question detection, answers, HUD pagination.
     *
     * Returns false in release builds, when no OpenAI key is stored, or when
     * the fixture cannot be staged. The mic delegate is restored by
     * [restoreMicCaptureAfterInjection] once the session stops.
     */
    fun startDebugAudioInjection(): Boolean {
        if (!shouldStartDebugInjection(BuildConfig.DEBUG, hasApiKey(ProviderKind.OPENAI.name))) return false
        // Stop whatever is listening. This also restores the mic delegate if a
        // previous injection is still active, so the swap below starts clean.
        stopListening()
        val fixture = runCatching { stageDebugFixture() }.getOrNull() ?: return false
        micCapture.swap(
            FileAudioCapture(
                file = fixture,
                // Hold playback until the realtime session is configured, so
                // the transcriber's outbox ring can't evict the opening words
                // while the socket is still connecting.
                awaitGate = { realtimeTranscriber.sessionReady },
            ),
        )
        debugInjectionStateFlow.value = true
        val generation = ++debugInjectionGeneration
        scope.launch {
            settingsRepository.setTranscriptionSource(TranscriptionSource.OPENAI_REALTIME)
            // The DataStore write above suspends; if the user cancelled the
            // injection meanwhile (restore ran, mic swapped back), starting
            // now would listen on the REAL microphone against their intent.
            if (generation != debugInjectionGeneration || !debugInjectionStateFlow.value) return@launch
            sourceSwitch.start(TranscriptionSource.OPENAI_REALTIME)
        }
        return true
    }

    /** Stages the debug asset as a real file ([FileAudioCapture] reads a [File]). */
    private fun stageDebugFixture(): File {
        val out = File(appContext.cacheDir, DEBUG_FIXTURE_ASSET)
        appContext.assets.open(DEBUG_FIXTURE_ASSET).use { input ->
            out.outputStream().use { output -> input.copyTo(output) }
        }
        return out
    }

    /**
     * The injection swap's restore point. [stopListening] is the single funnel
     * through which a session normally ends (mic tap, touchpad exit, source
     * change), and by then the transcriber has already stopped the capture —
     * the state [SwitchableAudioCapture.swap] requires. A transcriber that
     * stops itself (socket failure, auth error) bypasses [stopListening], so
     * the isListening collector in `init` routes that path here too. The
     * defensive [SwitchableAudioCapture.stop] guarantees the swap precondition
     * in both cases; it is a forwarded no-op on an already-stopped capture.
     */
    private fun restoreMicCaptureAfterInjection() {
        if (!debugInjectionStateFlow.value) return
        debugInjectionStateFlow.value = false
        micCapture.stop()
        micCapture.swap(micDelegate)
    }

    /** Persists the source; a running session is stopped rather than hot-swapped. */
    fun setTranscriptionSource(source: TranscriptionSource) {
        if (isListening.value && source != activeSource.value) stopListening()
        scope.launch { settingsRepository.setTranscriptionSource(source) }
    }

    fun setQuestionMode(mode: QuestionMode) {
        scope.launch { settingsRepository.setQuestionMode(mode) }
    }

    fun setQuestionSensitivity(sensitivity: QuestionSensitivity) {
        scope.launch { settingsRepository.setQuestionSensitivity(sensitivity) }
    }

    fun setOpenAiTranscriptionModel(model: String) {
        scope.launch { settingsRepository.setOpenAiTranscriptionModel(model) }
    }

    /** Every source's finals land here; partials are already surfaced by the switch. */
    private fun handleSegment(segment: TranscriptSegment) {
        if (!segment.isFinal) return
        val text = segment.text.trim()
        if (text.isEmpty()) return
        recentTranscript.append(text, segment.timestampMillis)
        val transcriptEntry = appendFeed(
            FeedEntry.Kind.TRANSCRIPT,
            text,
            speaker = segment.speaker,
            isUser = segment.isUser,
        )
        when (questionMode.value) {
            // Wait for question classification before extracting transcript
            // notes. Statement-form questions frequently arrive without a
            // question mark, so extracting here could save the question as a
            // "fact" moments before Helix correctly identifies it as a question.
            QuestionMode.AUTO_DETECT -> handleFinalTranscript(segment, transcriptEntry)
            // On demand: keep the transcript visible, answer only when asked.
            QuestionMode.ON_DEMAND -> {
                transcriptState.value = text
                captureAutomaticNotes(segment)
            }
        }
    }

    /**
     * Persists only conservative candidates from a finalized source segment.
     * Repository-level semantic dedupe prevents repeated finals/restarts from
     * creating copies; the receipt makes every new save visible and undoable.
     */
    private fun captureAutomaticNotes(
        segment: TranscriptSegment,
        excludedQuestionTexts: Collection<String> = emptyList(),
    ) {
        val candidates = AutomaticNoteExtractor.extract(segment, excludedQuestionTexts)
        if (candidates.isEmpty()) return
        scope.launch {
            val inserted = candidates.mapNotNull { candidate ->
                knowledgeRepository.addIfAbsent(
                    bucket = candidate.bucket,
                    text = candidate.text,
                    source = "Helix auto-note · ${candidate.kind.sourceLabel}",
                )?.let { item ->
                    AutomaticNoteSavedItem(item.id, item.bucket, item.text)
                }
            }
            if (inserted.isNotEmpty()) {
                showAutomaticNoteReceipt(inserted)
            }
        }
    }

    /** Captures a trustworthy completed Q&A without delaying answer delivery. */
    private fun captureAutomaticAnswer(turn: Turn) {
        val candidate = AutomaticNoteExtractor.extractAnswer(turn) ?: return
        scope.launch {
            val mutation = knowledgeRepository.upsertAutomaticAnswer(
                bucket = candidate.bucket,
                text = candidate.text,
                quality = if (turn.answerTier == AnswerTier.SMART) {
                    AutomaticAnswerQuality.SMART
                } else {
                    AutomaticAnswerQuality.FAST
                },
            ) ?: return@launch
            showAutomaticNoteReceipt(
                listOf(
                    AutomaticNoteSavedItem(
                        mutation.item.id,
                        mutation.item.bucket,
                        mutation.item.text,
                        previousItem = mutation.previousItem,
                    ),
                ),
            )
        }
    }

    /** Receipt stays actionable briefly, then disappears without deleting the note. */
    private fun showAutomaticNoteReceipt(items: List<AutomaticNoteSavedItem>) {
        if (items.isEmpty()) return
        val receipt = automaticNoteReceiptState.value?.mergedWith(items)
            ?: AutomaticNoteReceipt(items.distinctBy { it.id })
        automaticNoteReceiptJob?.cancel()
        automaticNoteReceiptState.value = receipt
        automaticNoteReceiptJob = scope.launch {
            delay(AUTOMATIC_NOTE_UNDO_MILLIS)
            if (automaticNoteReceiptState.value == receipt) {
                automaticNoteReceiptState.value = null
            }
        }
    }

    /** Unique id per accepted/rejected request; unlike an epoch, queueing does not supersede it. */
    private var liveTurnCounter = 0L

    /**
     * Answers are serialized in arrival order. Cancelling the active request
     * for every finalized chunk silently lost real earlier questions; the
     * bounded queue preserves accepted work while still placing a hard ceiling
     * on backlog during rapid transcription chunking.
     */
    private val answerQueue: OrderedAnswerQueue = OrderedAnswerQueue(
        scope = scope,
        maxPending = MAX_PENDING_ANSWERS,
        maxConcurrent = MAX_CONCURRENT_ANSWERS,
        onTaskStarted = { taskEpoch ->
            if (answerSessionBoundary.isCurrent(taskEpoch)) {
                activeAnswerWorkCount += 1
                isAnsweringState.value = true
                if (activeAnswerWorkCount == 1) beginAnswerStream()
            }
        },
        onTaskFinished = { taskEpoch ->
            if (answerSessionBoundary.isCurrent(taskEpoch)) {
                activeAnswerWorkCount = (activeAnswerWorkCount - 1).coerceAtLeast(0)
                if (activeAnswerWorkCount == 0) {
                    isAnsweringState.value = false
                    endAnswerStream()
                }
            }
        },
        onTaskFailure = { error ->
            providerErrorState.value = ProviderErrors.describe(error)
        },
    )
    private val answerSessionBoundary: AnswerSessionBoundary = AnswerSessionBoundary(answerQueue)
    private var activeAnswerWorkCount = 0
    private val pendingAnswerTurnIds = ArrayDeque<Long>()

    private fun invalidateAnswerSession() {
        answerSessionBoundary.invalidateForListeningStart()
        pendingAnswerTurnIds.clear()
        activeAnswerWorkCount = 0
        isAnsweringState.value = false
        endAnswerStream()
    }

    private fun enqueueAnswerJob(
        turnId: Long,
        prepare: suspend () -> (suspend () -> Unit),
    ) {
        val submittedEpoch = answerSessionBoundary.capture()
        pendingAnswerTurnIds.addLast(turnId)
        val accepted = answerQueue.submitPrepared answerTask@ {
            if (!answerSessionBoundary.isCurrent(submittedEpoch)) return@answerTask suspend {}
            val commit = try {
                prepare()
            } catch (error: Throwable) {
                // Turn preparation normally converts provider failures into a
                // Turn, but an unexpected exception still needs an ordered
                // failure commit so this id cannot strand every later stream.
                suspend { throw error }
            }
            suspend {
                try {
                    if (answerSessionBoundary.isCurrent(submittedEpoch)) commit()
                } finally {
                    pendingAnswerTurnIds.remove(turnId)
                    if (answerSessionBoundary.isCurrent(submittedEpoch) && pendingAnswerTurnIds.isNotEmpty()) {
                        // The next ordered answer may still be at its provider;
                        // restore a clean thinking row after the prior commit.
                        beginAnswerStream()
                    }
                }
            }
        }
        if (!accepted) {
            pendingAnswerTurnIds.remove(turnId)
            providerErrorState.value =
                "Too many questions are waiting for answers — this one was not queued. Ask it again shortly."
        }
    }

    private fun ownsActiveAnswer(turnId: Long): Boolean = pendingAnswerTurnIds.firstOrNull() == turnId

    // MARK: - Live answer streaming

    private val answerStreamingState = MutableStateFlow("")

    /**
     * The in-flight answer's text as it arrives, token by token; empty when no
     * answer is streaming.
     *
     * The Assistant feed is append-only and immutable by design (its auto-scroll
     * and item keys depend on that), so a growing answer cannot live in it.
     * Instead the UI renders this flow as one transient row below the feed,
     * which disappears the moment [deliver] appends the single real ANSWER
     * entry — exactly one feed entry per answer, unchanged from before.
     */
    val answerStreamingText: StateFlow<String> = answerStreamingState.asStateFlow()

    /** Last text pushed to the glasses mid-stream; guards against no-op repaints. */
    private var lastStreamedHudText: String = ""
    private var lastStreamHudMillis: Long = 0L
    private var streamHudJob: Job? = null

    /**
     * Append-only line wrapper for the streaming HUD. Reset per answer by
     * [beginAnswerStream] so a new answer never inherits frozen lines.
     */
    private val hudLineStream = HudLineStream()

    /**
     * Builds the delta sink for one turn: accumulates into
     * [answerStreamingText] and repaints the glasses on a throttle.
     *
     * Deltas arrive on the provider's IO thread, so every mutation hops to
     * [scope] (Main.immediate) first. [turnId] is re-checked there because a
     * newer ask may have superseded this answer between the network callback
     * and the dispatch — the engine's own generation gate covers the engine
     * side, this covers a new-conversation cancellation without treating a
     * later queued transcript as superseding the active answer.
     */
    private fun streamingSink(turnId: Long): (String) -> Unit = { chunk ->
        scope.launch {
            if (!ownsActiveAnswer(turnId)) return@launch
            if (answerStreamingState.value.isEmpty()) {
                android.util.Log.i(ANSWER_LOG_TAG, "first answer token turn=$turnId")
            }
            // The first token to arrive ends the "thinking" phase, even for a
            // chunk that turns out to be blank/whitespace.
            answeringPhase.onDelta()
            isThinkingState.value = answeringPhase.isThinking
            answerStreamingState.value += chunk
            maybeRepaintHudWhileStreaming(answerStreamingState.value)
        }
    }

    /**
     * Mid-stream HUD repaint: a stable, scroll-up trailing window.
     *
     * WHY NOT re-paginate the whole answer each tick (what this used to do):
     * [HudPaginator] packs greedily from the start, so re-wrapping a GROWING
     * string rewrites the last line and can shift every line after it. Each
     * repaint then went through [presentToGlasses], which cancels the running
     * lifecycle, re-paginates, re-takes the arbiter lease and redraws from PAGE
     * ONE. On the lens that reads as a full-screen flash that jumps back to the
     * beginning while new text arrives off-screen — the behaviour the wearer
     * reported.
     *
     * [HudLineStream] fixes it by being append-only: a line, once emitted, is
     * frozen, and only the still-growing last line can change. It yields a
     * frame ONLY when a line completes, and that frame is the trailing window
     * (newest text at the bottom, older lines scrolled up and off the top).
     * The protocol has no append primitive — `new_char_pos` is hard-coded 0 in
     * every reference implementation (SLA-P3), so every write is a whole-screen
     * replace; smooth scrolling comes from making each replacement STABLE.
     *
     * Per completed line, not per token: each screen is an ACK-gated
     * left-then-400ms-then-right write, so a per-token repaint would saturate
     * the BLE queue. [streamHudJob] still gates overlapping writes.
     */
    private fun maybeRepaintHudWhileStreaming(text: String) {
        if (conversate.isLive.value) return
        if (!isGlassesConnected) return
        val frame = hudLineStream.update(text) ?: return
        if (streamHudJob?.isActive == true) return
        val painted = frame.text
        if (painted.isBlank() || painted == lastStreamedHudText) return
        lastStreamedHudText = painted
        streamHudJob = scope.launch { presentToGlasses(painted) }
    }

    /** Arms a fresh stream: clears the accumulator and the throttle bookkeeping. */
    private fun beginAnswerStream() {
        streamHudJob?.cancel()
        streamHudJob = null
        answerStreamingState.value = ""
        lastStreamedHudText = ""
        hudLineStream.reset()
        // Zero, not `now`: the first delta of a new answer should paint at once
        // rather than wait out the previous answer's throttle window.
        lastStreamHudMillis = 0L
        // Thinking starts the moment the turn is armed; streamingSink clears it
        // on the first delta.
        answeringPhase.start()
        isThinkingState.value = answeringPhase.isThinking
    }

    /**
     * Ends the stream. Called before [deliver] so the transient streaming row
     * is gone in the same frame the real ANSWER feed entry appears — the reader
     * never sees the answer twice.
     */
    private fun endAnswerStream() {
        streamHudJob?.cancel()
        streamHudJob = null
        answerStreamingState.value = ""
        lastStreamedHudText = ""
        // Drop the tail: the final partial line has no completion to trigger a
        // frame, and `deliver` repaints the finished answer immediately after.
        // Flushing here would paint a frame that is overwritten milliseconds
        // later — one wasted ACK-gated screen write per answer.
        hudLineStream.reset()
        answeringPhase.end()
        isThinkingState.value = answeringPhase.isThinking
    }

    private fun handleFinalTranscript(segment: TranscriptSegment, transcriptEntry: FeedEntry?) {
        val text = segment.text.trim()
        android.util.Log.i(ANSWER_LOG_TAG, "final transcript accepted")
        transcriptState.value = text
        val turnId = ++liveTurnCounter
        enqueueAnswerJob(turnId) {
            val sink = streamingSink(turnId)
            val preview = CandidateStreamPreview(sink)
            val turns = engine.processLiveTranscriptTurns(
                text = text,
                onAnswerDelta = preview::onDelta,
                onAnswerStarted = { candidate ->
                    preview.onStarted(candidate)
                    android.util.Log.i(ANSWER_LOG_TAG, "question accepted tier=${AnswerTier.FAST.name}")
                },
                deferStateCommit = true,
            )
            suspend {
                endAnswerStream()
                engine.commitLiveTranscriptTurns(turns)
                deliverBatch(turns, transcriptEntry)
                captureAutomaticNotes(
                    segment = segment,
                    excludedQuestionTexts = turns.mapNotNull { turn -> turn.question?.text },
                )
            }
        }
    }

    /**
     * Manual ask (right pad / EvenAI start / "Ask now"). In on-demand mode the
     * last minute of conversation is answered with the recent-context prompt;
     * otherwise the latest transcript line is asked as a question.
     */
    fun triggerManualQuestion() {
        if (questionMode.value == QuestionMode.ON_DEMAND) {
            askFromRecentContext()
            return
        }
        val transcript = transcriptState.value.ifBlank { partialTranscript.value }
        if (transcript.isBlank()) return
        enqueueSmartQuestion(transcript, QuestionFeedOrigin.TRANSCRIPT)
    }

    fun askFromRecentContext() {
        val window = listOf(recentTranscript.recent(), partialTranscript.value)
            .filter { it.isNotBlank() }
            .joinToString("\n")
        if (window.isBlank()) {
            // Never a silent no-op: the button can look enabled after the
            // 60 s recent-window has drained.
            providerErrorState.value = "Nothing recent to ask about — say something first."
            return
        }
        val turnId = ++liveTurnCounter
        enqueueAnswerJob(turnId) {
            val turn = engine.answerFromRecentContext(window, streamingSink(turnId))
            suspend {
                endAnswerStream()
                // Consume the window. It is a 60s rolling buffer that nothing ever
                // cleared, so a second "Ask now" re-sent almost the same context and
                // the model returned substantially the same answer — the reported
                // "same answer keeps showing up". ON_DEMAND only: AUTO_DETECT's
                // manual trigger asks a single overwritten transcript line.
                recentTranscript.clear()
                deliver(turn)
            }
        }
    }

    fun askQuestion(text: String) {
        enqueueSmartQuestion(text, QuestionFeedOrigin.TYPED_USER)
    }

    /** Dedicated, auditable SMART-tier path from a FAST answer card. */
    fun thinkDeeper(question: String) {
        enqueueSmartQuestion(question, QuestionFeedOrigin.EXISTING_FEED)
    }

    private fun enqueueSmartQuestion(text: String, questionFeedOrigin: QuestionFeedOrigin) {
        val question = text.trim()
        if (question.isEmpty()) return
        val turnId = ++liveTurnCounter
        enqueueAnswerJob(turnId) {
            android.util.Log.i(ANSWER_LOG_TAG, "question accepted tier=${AnswerTier.SMART.name}")
            val turn = engine.answerTextQuestion(question, streamingSink(turnId))
            suspend {
                endAnswerStream()
                deliver(turn, questionFeedOrigin = questionFeedOrigin)
            }
        }
    }

    /**
     * Publishes every question/answer from one finalized segment, then sends
     * one combined HUD presentation. Consecutive `present()` calls cancel the
     * prior G1 lifecycle; batching preserves a single ACK owner.
     */
    private suspend fun deliverBatch(turns: List<Turn>, transcriptEntry: FeedEntry?) {
        val hudTurns = turns.mapNotNull { turn ->
            val answerEntry = deliver(turn, transcriptEntry, presentAnswerOnHud = false)
            val answer = turn.answer ?: return@mapNotNull null
            HudAnsweredTurn(turn.question?.text, answer.text, answerEntry?.id)
        }
        presentHudAnswerBatch(hudTurns) { presentation ->
            presentToGlasses(
                presentation.text,
                ownerFeedEntryId = presentation.ownerFeedEntryId,
                answerFeedEntryIds = presentation.answerFeedEntryIds,
            )
        }
    }

    /** Publishes a turn and optionally mirrors its answer (or passive reminder) to the HUD. */
    private suspend fun deliver(
        turn: Turn,
        transcriptEntry: FeedEntry? = null,
        presentAnswerOnHud: Boolean = true,
        questionFeedOrigin: QuestionFeedOrigin = QuestionFeedOrigin.TRANSCRIPT,
    ): FeedEntry? {
        turn.answer?.let { answer ->
            android.util.Log.i(
                ANSWER_LOG_TAG,
                "answer complete tier=${turn.answerTier?.name ?: "UNKNOWN"} " +
                    "model=${answer.model} latencyMs=${turn.providerLatencyMillis ?: -1L}",
            )
        }
        publish(turn)
        turn.question?.let { question ->
            val placement = questionFeedPlacement(questionFeedOrigin, transcriptEntry)
            val promoted = if (
                placement.shouldAppend && questionFeedOrigin == QuestionFeedOrigin.TRANSCRIPT
            ) {
                transcriptEntry?.let { source ->
                    feedRepository.promoteMatchingTranscriptToQuestion(source.id, question.text)
                } ?: false
            } else {
                false
            }
            if (placement.shouldAppend && !promoted) {
                appendFeed(
                    FeedEntry.Kind.QUESTION,
                    question.text,
                    speaker = placement.attribution.speaker,
                    isUser = placement.attribution.isUser,
                )
            }
        }
        val answerEntry = turn.answer?.let {
            appendFeed(
                FeedEntry.Kind.ANSWER,
                it.text,
                model = it.model,
                question = turn.question?.text,
                answerTier = turn.answerTier,
            )
        }
        turn.passiveReminder?.let { appendFeed(FeedEntry.Kind.REMINDER, it) }
        // presentToGlasses keeps the phone-side HUD preview in sync when the
        // glasses are offline, so it is called unconditionally here.
        if (presentAnswerOnHud) turn.answer?.let { answer ->
            presentToGlasses(answer.text, ownerFeedEntryId = answerEntry?.id)
        }
        // Passive-mode false-claim corrections surface like an answer.
        turn.passiveReminder?.let { reminder -> presentToGlasses(reminder) }
        // (A) Helix's own events as glasses notifications (0x4B). Self-gating:
        // no-ops when disconnected or the toggle is off. iOS parity —
        // HelixNativeBridge.swift:526/:531.
        turn.answer?.let { forwardHelixEvent("Helix answered", it.text) }
        turn.passiveReminder?.let { forwardHelixEvent("Fact check", it) }
        captureAutomaticAnswer(turn)
        return answerEntry
    }

    private fun publish(turn: Turn) {
        lastTurnState.value = turn
        eventLogState.value = engine.eventLog()
        turn.error?.let { providerErrorState.value = ProviderErrors.describe(it) }
        if (turn.answer != null) providerErrorState.value = ""
    }

    fun clearProviderError() {
        providerErrorState.value = ""
    }

    fun setMode(mode: ConversationMode) = updateSettings { it.copy(mode = mode) }

    // MARK: - Archive / knowledge

    fun saveCurrentSession() {
        val turn = lastTurnState.value
        saveSession(question = turn?.question?.text.orEmpty(), answer = turn?.answer?.text.orEmpty())
    }

    /**
     * Content-bound save used by the feed's answer cards: saves the card's own
     * question/answer, not whatever [lastTurn] currently holds (a later
     * passive-reminder turn must not silently no-op the button).
     */
    fun saveSession(question: String, answer: String) {
        if (answer.isEmpty() && question.isEmpty()) return
        scope.launch {
            sessionRepository.add(
                title = question.ifEmpty { "Helix session" },
                answerPreview = answer,
                transcriptTurns = listOfNotNull(transcriptState.value.takeIf { it.isNotBlank() }),
                answerCount = if (answer.isEmpty()) 0 else 1,
            )
        }
    }

    fun addKnowledge(bucket: KnowledgeBucket, text: String) {
        scope.launch { knowledgeRepository.add(bucket, text) }
    }

    fun dismissAutomaticNoteReceipt() {
        automaticNoteReceiptJob?.cancel()
        automaticNoteReceiptJob = null
        automaticNoteReceiptState.value = null
    }

    fun undoAutomaticNotes(items: List<AutomaticNoteSavedItem>) {
        if (items.isEmpty()) return
        val ids = items.mapTo(LinkedHashSet()) { it.id }
        if (automaticNoteReceiptState.value?.itemIds?.toSet() == ids) {
            automaticNoteReceiptJob?.cancel()
            automaticNoteReceiptJob = null
            automaticNoteReceiptState.value = null
        }
        scope.launch {
            items.asReversed().forEach { item ->
                knowledgeRepository.undoAutomaticAnswer(item.id, item.previousItem)
            }
        }
    }

    // MARK: - Omi import

    private val omiImportService = OmiImportService(
        keyStore = settingsRepository,
        upsertSessions = sessionRepository::addAllIfAbsent,
        upsertKnowledge = knowledgeRepository::addAllIfAbsent,
    )

    sealed interface OmiImportState {
        data object Idle : OmiImportState
        data object Running : OmiImportState
        data class Done(val result: OmiImportResult) : OmiImportState
        data class Failed(val message: String) : OmiImportState
    }

    private val omiImportStateFlow = MutableStateFlow<OmiImportState>(OmiImportState.Idle)
    val omiImportState: StateFlow<OmiImportState> = omiImportStateFlow.asStateFlow()

    val omiLastImportMillis: StateFlow<Long?> =
        settingsRepository.omiLastImportMillis.stateIn(scope, SharingStarted.Eagerly, null)

    /** Manual, idempotent import of Omi conversations + memories. */
    fun importFromOmi() {
        if (omiImportStateFlow.value == OmiImportState.Running) return
        omiImportStateFlow.value = OmiImportState.Running
        scope.launch {
            runCatching { omiImportService.importAll() }
                .onSuccess { result ->
                    settingsRepository.setOmiLastImport(System.currentTimeMillis())
                    omiImportStateFlow.value = OmiImportState.Done(result)
                }
                .onFailure { error ->
                    omiImportStateFlow.value =
                        OmiImportState.Failed(error.message ?: "Omi import failed.")
                }
        }
    }

    fun dismissOmiImportState() {
        if (omiImportStateFlow.value != OmiImportState.Running) {
            omiImportStateFlow.value = OmiImportState.Idle
        }
    }

    // MARK: - Omi live transcript → glasses

    val isOmiLiveActive: StateFlow<Boolean> = omiLive.isActive
    val omiLiveError: StateFlow<String> = omiLive.errorMessage
    val omiLastSegment: StateFlow<OmiLiveSegment?> = omiLive.lastSegment

    /** Selects Omi as the source and starts it (Settings shortcut). */
    fun startOmiLive() {
        if (settingsRepository.keyFor(OMI_RELAY_KEY_KIND).isNullOrBlank()) return
        scope.launch {
            settingsRepository.setTranscriptionSource(TranscriptionSource.OMI)
            sourceSwitch.start(TranscriptionSource.OMI)
        }
    }

    fun stopOmiLive() = stopListening()

    fun clearOmiLiveError() = clearSpeechError()

    /**
     * Mirrors every raw Omi segment to the HUD at NOTIFICATION priority so an
     * active answer (ANSWER, higher rank) is never clobbered by transcript text.
     */
    private fun mirrorOmiSegmentToHud(segment: OmiLiveSegment) {
        val line = segment.speaker
            ?.takeIf { !segment.isUser && it.isNotBlank() }
            ?.let { "${it.replace("SPEAKER_", "S")}: ${segment.text}" }
            ?: segment.text
        scope.launch {
            if (isGlassesConnected) presentToGlasses(line, HudArbiter.Priority.NOTIFICATION)
        }
    }

    fun removeKnowledge(id: String) {
        scope.launch { knowledgeRepository.remove(id) }
    }

    // MARK: - Phone → glasses notifications (0x4B / 0x04)

    private val notificationSender = G1NotificationSender(transport)

    /**
     * "Mirror other apps": whether whitelisted phone notifications are
     * forwarded. Off until the user both flips this and grants notification
     * access in system settings — [HelixNotificationListener] only runs once
     * Android has bound it.
     */
    val notificationMirrorEnabled: StateFlow<Boolean> =
        settingsRepository.notificationMirrorEnabled.stateIn(scope, SharingStarted.Eagerly, false)

    /** Package ids the user ticked for mirroring. */
    val notificationWhitelist: StateFlow<Set<String>> =
        settingsRepository.notificationWhitelist.stateIn(scope, SharingStarted.Eagerly, emptySet())

    fun setNotificationMirrorEnabled(enabled: Boolean) {
        scope.launch { settingsRepository.setNotificationMirrorEnabled(enabled) }
    }

    fun setNotificationWhitelisted(packageName: String, whitelisted: Boolean) {
        scope.launch { settingsRepository.setNotificationWhitelisted(packageName, whitelisted) }
    }

    /**
     * Forwards one event to the glasses as a phone notification (0x4B), the
     * Android counterpart of iOS `HelixNativeBridge.forwardNotification`.
     *
     * No-op unless the glasses are connected AND "Notifications on glasses" is
     * on. Takes the HUD arbiter at NOTIFICATION priority for its default 10 s
     * window so an active answer (higher rank) is never displaced, then sends
     * the chunk list to the LEFT lens with the reference retry policy.
     *
     * Fire-and-forget: callers on the UI/engine path must never block on BLE.
     */
    fun forwardNotificationToGlasses(
        appId: String,
        title: String,
        subtitle: String,
        message: String,
    ) {
        if (!isGlassesConnected || !glassesNotificationsEnabled.value) return
        scope.launch {
            val lease = hudArbiter.acquire(HudArbiter.Priority.NOTIFICATION) ?: return@launch
            try {
                notificationSender.sendNotification(
                    appId = appId,
                    displayName = HELIX_DISPLAY_NAME,
                    title = title,
                    subtitle = subtitle,
                    message = message,
                )
            } finally {
                // The lease MUST come back. Without this the notification held
                // the HUD for its full 10 s window after the send had already
                // finished, so a notification arriving moments later was
                // refused and never drew — "notifications don't show up".
                // 0x4B is a fire-and-forget firmware notification: the firmware
                // owns its own dismissal, so there is nothing to dwell on here.
                hudArbiter.release(lease)
            }
        }
    }

    /** Helix's own events (answers, reminders) use the app's own identity. */
    private fun forwardHelixEvent(title: String, message: String) =
        forwardNotificationToGlasses(
            appId = appContext.packageName,
            title = title,
            subtitle = "",
            message = message,
        )

    /**
     * Entry point for [HelixNotificationListener]. The service has already
     * applied [NotificationMirrorFilter]; this adds the mirror-enabled and
     * whitelist checks again so a stale binder callback cannot slip past a
     * setting the user just changed.
     */
    fun forwardMirroredNotification(
        packageName: String,
        appLabel: String,
        title: String,
        message: String,
    ) {
        if (!notificationMirrorEnabled.value) return
        if (packageName !in notificationWhitelist.value) return
        forwardNotificationToGlasses(
            appId = packageName,
            title = title.ifBlank { appLabel },
            subtitle = appLabel,
            message = message,
        )
    }

    /**
     * Pushes the whitelist (0x04) to the left lens. Called on connect and again
     * whenever the user's list changes, so the firmware's own filter always
     * matches what the app will actually send.
     */
    private fun pushNotificationWhitelist() {
        if (!isGlassesConnected) return
        val apps = notificationWhitelist.value.sorted().map {
            G1CommandEncoder.WhitelistApp(id = it, name = notificationAppLabels[it] ?: it)
        } + G1CommandEncoder.WhitelistApp(id = appContext.packageName, name = HELIX_DISPLAY_NAME)
        whitelistPushJob?.cancel()
        whitelistPushJob = scope.launch { notificationSender.sendWhitelist(apps) }
    }

    private var whitelistPushJob: Job? = null

    /**
     * Package id -> human label, filled by the settings picker so the whitelist
     * JSON carries real app names. Missing entries fall back to the package id.
     */
    private val notificationAppLabels = mutableMapOf<String, String>()

    fun recordNotificationAppLabels(labels: Map<String, String>) {
        notificationAppLabels.putAll(labels)
    }

    /**
     * Re-pushes the whitelist on every change; started from [init].
     *
     * The collect is deferred with `yield()` because [init] runs before the
     * property initializers further down the class body: touching
     * [notificationWhitelist] synchronously here would read a null field on
     * Main.immediate and crash at construction.
     */
    private fun observeNotificationWhitelist() {
        scope.launch {
            kotlinx.coroutines.yield()
            notificationWhitelist.collect { pushNotificationWhitelist() }
        }
    }

    companion object {
        /** KeyStore kind for the Omi relay feed URL (secret — it carries the token). */
        const val OMI_RELAY_KEY_KIND = "OMI_RELAY"

        /** `display_name` for Helix's own 0x4B notifications and whitelist row. */
        const val HELIX_DISPLAY_NAME = "Helix"
        const val FEED_LIMIT = 200
        const val HEARTBEAT_INTERVAL_MILLIS = 10_000L
        const val DISPLAY_PUSH_DEBOUNCE_MILLIS = 250L

        /**
         * Minimum gap between mid-stream HUD repaints. Comfortably above the
         * ≥400 ms a single screen costs (left, 400 ms settle, right), so a
         * partial repaint is never queued behind the previous one, and slow
         * enough that the wearer can actually read the growing text.
         */
        const val STREAM_HUD_INTERVAL_MILLIS = 1_200L

        /** Accepted answer backlog; overflow is visible instead of silently replacing work. */
        const val MAX_PENDING_ANSWERS = 4
        const val MAX_CONCURRENT_ANSWERS = 2
        const val AUTOMATIC_NOTE_UNDO_MILLIS = 4_000L

        /** Debug-source-set asset streamed by [startDebugAudioInjection]. */
        const val DEBUG_FIXTURE_ASSET = "helix_debug_fixture.wav"

        /**
         * Pure guard for [startDebugAudioInjection]: only debug builds with a
         * stored OpenAI key may inject. Extracted so JVM unit tests can pin
         * the release-build behavior without Android's [BuildConfig].
         */
        internal fun shouldStartDebugInjection(isDebugBuild: Boolean, hasOpenAiKey: Boolean): Boolean =
            isDebugBuild && hasOpenAiKey

        /** Log tag for BLE / HUD diagnostics. Never carries user text or secrets. */
        const val G1_LOG_TAG = "HelixG1"
        const val ANSWER_LOG_TAG = "HelixAnswer"

        /**
         * How long the position PREVIEW stays on the lens before the commit.
         * The reference says "a few seconds later"; this is the wearer's window
         * to judge the placement (SLA-L3b).
         */
        const val POSITION_PREVIEW_DWELL_MILLIS = 3_000L

        /** Firmware notify index for a single touchpad tap (0xF5 sub-code 1). */
        const val SINGLE_TAP_INDEX = 1

        /** Taps required on the right pad to toggle a transcription session. */
        const val SESSION_TOGGLE_TAP_COUNT = 3

        /**
         * SLA-L3: brightness (0x01), head-up angle (0x0B) and display position
         * (0x26) go to the right lens only — that is where the display engine
         * lives, and it is what the vendor app does.
         */

        /** The official Even Realities companion app. */
        const val EVEN_REALITIES_PACKAGE = "com.even.g1"

        /**
         * How long a fruitless scan runs before [scanConflictHint] is allowed
         * to blame advertising exclusivity. Long enough that a slow-to-wake
         * pair is not misdiagnosed.
         */
        const val SCAN_CONFLICT_TIMEOUT_MILLIS = 15_000L

        /**
         * SLA-T1 heuristic (pure, so unit tests can pin it without Android).
         *
         * Returns the user-facing hint only when a scan is still running, has
         * turned up zero pairs, and the vendor app is installed — otherwise
         * null, meaning "say nothing". Phrased as a possibility: we cannot
         * observe another app's GATT links, so this is never a certainty.
         */
        internal fun scanConflictHint(
            foundPairs: Int,
            isScanning: Boolean,
            vendorAppInstalled: Boolean,
        ): String? {
            if (!isScanning || foundPairs > 0 || !vendorAppInstalled) return null
            return "No glasses found. The Even Realities app may be holding the " +
                "connection — a connected lens stops advertising. Force-close it, " +
                "then scan again."
        }
    }
}

/**
 * Glasses display preferences (brightness, head-up angle, HUD position).
 *
 * The shared [HelixSettings] domain type (core/Domain.kt, owned elsewhere) has
 * no fields for these, so the Android shell keeps them in its own value type
 * rather than editing the shared contract. They are session-scoped for now —
 * persisting them belongs with the upstream settings fields, not a second
 * parallel store.
 */
/**
 * One row of the Assistant conversation feed.
 *
 * `@Serializable` because [com.artjiang.helix.data.FeedRepository] persists the
 * feed verbatim — the type is small, stable, and already exactly the shape the
 * UI renders, so a parallel persistence DTO would only add a mapping to keep in
 * step. `ignoreUnknownKeys` in the data-layer Json handles forward compat, and
 * defaults on the nullable fields handle reading rows written before they existed.
 */
@kotlinx.serialization.Serializable
data class FeedEntry(
    val id: Long,
    val kind: Kind,
    val text: String,
    val model: String? = null,
    /** For ANSWER entries: the question this answer replied to (save binding). */
    val question: String? = null,
    /** FAST automatic vs SMART deliberate answer; null for legacy persisted rows. */
    val answerTier: AnswerTier? = null,
    val atMillis: Long,
    /** Speaker label when the source diarizes; null otherwise. */
    val speaker: String? = null,
    /** True only when the source or the user identifies this speaker as the wearer. */
    val isUser: Boolean = false,
) {
    enum class Kind { TRANSCRIPT, QUESTION, ANSWER, REMINDER }
}

data class GlassesDisplayPrefs(
    val brightness: Int = 30,
    val autoBrightness: Boolean = true,
    val headUpAngle: Int = 30,
    val displayHeight: Int = 4,
    val displayDepth: Int = 5,
)
