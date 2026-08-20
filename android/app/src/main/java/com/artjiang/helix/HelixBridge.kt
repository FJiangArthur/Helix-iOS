// App-scope coordinator. Android port of ios/Runner/HelixNativeBridge.swift:
// owns settings, the AI engine, the BLE link + G1 transport, transcription, and
// the HUD arbiter, and exposes everything the Compose UI observes.
package com.artjiang.helix

import android.content.Context
import com.artjiang.helix.ai.ConversationEngine
import com.artjiang.helix.ai.ConversationEvent
import com.artjiang.helix.ai.ProviderFactory
import com.artjiang.helix.ai.Turn
import com.artjiang.helix.ble.DiscoveredPair
import com.artjiang.helix.ble.G1BluetoothManager
import com.artjiang.helix.ble.LensConnectionState
import com.artjiang.helix.core.ConversationMode
import com.artjiang.helix.core.HelixSettings
import com.artjiang.helix.core.KnowledgeBucket
import com.artjiang.helix.core.ProviderKind
import com.artjiang.helix.data.KnowledgeRepository
import com.artjiang.helix.data.SessionRepository
import com.artjiang.helix.data.SettingsRepository
import com.artjiang.helix.g1.G1AckPolicy
import com.artjiang.helix.g1.G1Command
import com.artjiang.helix.g1.G1CommandEncoder
import com.artjiang.helix.g1.G1CommandTransport
import com.artjiang.helix.g1.G1HudPage
import com.artjiang.helix.g1.G1HudPresenter
import com.artjiang.helix.g1.G1Side
import com.artjiang.helix.g1.G1StatusDecoder
import com.artjiang.helix.g1.G1StatusEvent
import com.artjiang.helix.g1.G1TouchpadSide
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import com.artjiang.helix.speech.TranscriptionService

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
    val knowledgeRepository = KnowledgeRepository(appContext)
    val sessionRepository = SessionRepository(appContext)

    val bluetooth = G1BluetoothManager(appContext, scope)
    private val transport = G1CommandTransport(bluetooth)
    private val hudPresenter = G1HudPresenter()
    val hudArbiter = HudArbiter()

    val transcription = TranscriptionService(appContext)

    private val providerFactory = ProviderFactory(settingsRepository)
    private val engine = ConversationEngine(
        settings = HelixSettings(),
        knowledgeProvider = { query -> knowledgeRepository.search(query) },
    )

    // MARK: - UI state

    val settings: StateFlow<HelixSettings> =
        settingsRepository.settings.stateIn(scope, SharingStarted.Eagerly, HelixSettings())

    val knowledgeItems = knowledgeRepository.items
    val sessions = sessionRepository.sessions

    val isListening: StateFlow<Boolean> = transcription.isListening
    val partialTranscript: StateFlow<String> = transcription.partialTranscript
    val speechError: StateFlow<String> = transcription.errorMessage

    val leftLens: StateFlow<LensConnectionState> = bluetooth.leftState
    val rightLens: StateFlow<LensConnectionState> = bluetooth.rightState
    val isScanning: StateFlow<Boolean> = bluetooth.isScanning
    val discoveredPairs: StateFlow<List<DiscoveredPair>> = bluetooth.discoveredPairs
    val connectionPhase: StateFlow<String> = bluetooth.connectionPhase
    val bluetoothError: StateFlow<String> = bluetooth.errorMessage

    private val lastTurnState = MutableStateFlow<Turn?>(null)
    val lastTurn: StateFlow<Turn?> = lastTurnState.asStateFlow()

    private val transcriptState = MutableStateFlow("")
    val transcriptText: StateFlow<String> = transcriptState.asStateFlow()

    private val isAnsweringState = MutableStateFlow(false)
    val isAnswering: StateFlow<Boolean> = isAnsweringState.asStateFlow()

    private val batteryState = MutableStateFlow<Int?>(null)
    val batteryPercent: StateFlow<Int?> = batteryState.asStateFlow()

    private val chargingState = MutableStateFlow(false)
    val isCharging: StateFlow<Boolean> = chargingState.asStateFlow()

    private val hudPagesState = MutableStateFlow<List<G1HudPage>>(emptyList())
    val hudPages: StateFlow<List<G1HudPage>> = hudPagesState.asStateFlow()

    private val hudPageIndexState = MutableStateFlow(0)
    val hudPageIndex: StateFlow<Int> = hudPageIndexState.asStateFlow()

    private val eventLogState = MutableStateFlow<List<ConversationEvent>>(emptyList())
    val eventLog: StateFlow<List<ConversationEvent>> = eventLogState.asStateFlow()

    private val lastTouchpadState = MutableStateFlow("No touchpad input yet")
    val lastTouchpadSummary: StateFlow<String> = lastTouchpadState.asStateFlow()

    private val displayPrefsState = MutableStateFlow(GlassesDisplayPrefs())
    val displayPrefs: StateFlow<GlassesDisplayPrefs> = displayPrefsState.asStateFlow()

    /** The provider that will actually answer — DETERMINISTIC when keyless. */
    private val effectiveProviderState = MutableStateFlow(ProviderKind.DETERMINISTIC)
    val effectiveProvider: StateFlow<ProviderKind> = effectiveProviderState.asStateFlow()

    val isGlassesConnected: Boolean
        get() = leftLens.value == LensConnectionState.READY || rightLens.value == LensConnectionState.READY

    // MARK: - Session plumbing

    private var sessionJob: Job? = null
    private var hudSendJob: Job? = null
    private var heartbeatCounter: Byte = 0
    private var positionCounter: Byte = 0

    init {
        bluetooth.onInbound = ::handleInbound
        bluetooth.onBothLensesReady = ::startGlassesSession
        bluetooth.onAllDisconnected = ::stopGlassesSession

        transcription.onSegment = { segment ->
            if (segment.isFinal) handleFinalTranscript(segment.text)
        }

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
    }

    private suspend fun rebuildProvider(current: HelixSettings) {
        // The factory reads the KeyStore on every make(), so a newly stored key
        // takes effect without rebuilding the factory itself.
        val provider = providerFactory.make(current)
        engine.setProvider(provider)
        effectiveProviderState.value = provider.kind
    }

    // MARK: - Settings

    fun updateSettings(transform: (HelixSettings) -> HelixSettings) {
        scope.launch { settingsRepository.update(transform) }
    }

    fun setApiKey(kind: String, value: String?) {
        settingsRepository.setKey(kind, value)
        updateSettings { current ->
            val existing = current.providers[kind] ?: return@updateSettings current
            current.copy(
                providers = current.providers + (kind to existing.copy(hasKey = !value.isNullOrBlank())),
            )
        }
    }

    fun hasApiKey(kind: String): Boolean = settingsRepository.hasKey(kind)

    // MARK: - Bluetooth

    fun startScan() = bluetooth.startScan()

    fun stopScan() = bluetooth.stopScan()

    fun connect(pair: DiscoveredPair) = bluetooth.connect(pair)

    fun disconnectGlasses() = bluetooth.disconnect()

    fun clearBluetoothError() = bluetooth.clearError()

    /**
     * Inbound BLE notifications arrive on a binder thread. Everything below
     * touches main-thread-only state (the recognizer) or UI StateFlows, so the
     * whole handler hops to the bridge scope (Main.immediate) first.
     */
    private fun handleInbound(data: ByteArray, side: G1Side) {
        scope.launch {
            transport.handleInbound(data, side)

            when (val status = G1StatusDecoder.decode(data)) {
                is G1StatusEvent.Battery -> {
                    batteryState.value = status.percent
                    chargingState.value = status.isCharging
                }

                is G1StatusEvent.CaseBatteryPercent -> batteryState.value = status.percent
                is G1StatusEvent.CaseCharging -> chargingState.value = status.isCharging
                is G1StatusEvent.HeadUp -> syncDateTime()
                else -> Unit
            }

            val touchpadSide = if (side == G1Side.RIGHT) G1TouchpadSide.RIGHT else G1TouchpadSide.LEFT
            val frame = G1StatusDecoder.decodeTouchpad(data, touchpadSide) ?: return@launch
            lastTouchpadState.value = "${touchpadSide.name.lowercase()} pad - index ${frame.notifyIndex}"
            applyTouchpad(TouchpadDecider.decide(frame.notifyIndex, touchpadSide, engine.activeAnswer != null))
        }
    }

    private fun applyTouchpad(effect: TouchpadEffect) {
        when (effect) {
            is TouchpadEffect.ChangePage -> showPage(hudPageIndexState.value + effect.delta)
            TouchpadEffect.TriggerManualQuestion -> triggerManualQuestion()
            TouchpadEffect.StopListening -> transcription.stop()
            TouchpadEffect.ToggleListening -> transcription.toggle()
            TouchpadEffect.ClearHud -> {
                hudPagesState.value = emptyList()
                hudPageIndexState.value = 0
                scope.launch {
                    transport.send(G1Command(bytes = G1CommandEncoder.exitAllFunctions()))
                    hudArbiter.releaseDisplay()
                }
            }

            TouchpadEffect.None -> Unit
        }
    }

    // MARK: - Glasses session

    private fun startGlassesSession() {
        stopGlassesSession()
        val current = settings.value
        sessionJob = scope.launch {
            // Init handshake (0x4D 0xFB, ACK 0xC9), with the legacy fallback.
            val acked = transport.send(
                G1Command(
                    bytes = G1CommandEncoder.initHandshake(),
                    ackPolicy = G1AckPolicy.Required(0x4D),
                ),
            )
            if (!acked) transport.send(G1Command(bytes = byteArrayOf(0x4D, 0x01)))

            transport.send(G1Command(bytes = G1CommandEncoder.silentModeOff()))
            transport.send(G1Command(bytes = G1CommandEncoder.wearDetectionOff()))
            transport.send(
                G1Command(
                    bytes = G1CommandEncoder.dateTimeSync(System.currentTimeMillis(), nextPositionCounter()),
                ),
            )
            applyGlassesDisplaySettings(current)

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
        scope.launch { transport.reset() }
    }

    /** Pushes brightness / head-up angle / display position from settings. */
    suspend fun applyGlassesDisplaySettings(@Suppress("UNUSED_PARAMETER") current: HelixSettings) {
        val display = displayPrefsState.value
        transport.send(
            G1Command(bytes = G1CommandEncoder.brightness(display.brightness, display.autoBrightness)),
        )
        transport.send(G1Command(bytes = G1CommandEncoder.headUpAngle(display.headUpAngle)))
        transport.send(
            G1Command(
                bytes = G1CommandEncoder.displayPosition(
                    height = display.displayHeight,
                    depth = display.displayDepth,
                    counter = nextPositionCounter(),
                ),
                ackPolicy = G1AckPolicy.Required(0x26),
            ),
        )
    }

    fun pushGlassesDisplaySettings() {
        if (!isGlassesConnected) return
        scope.launch { applyGlassesDisplaySettings(settings.value) }
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

    // MARK: - HUD output

    /** Paginates [text] locally and mirrors the first page to the glasses. */
    fun presentToGlasses(text: String, priority: HudArbiter.Priority = HudArbiter.Priority.ANSWER) {
        val trimmed = text.trim()
        if (trimmed.isEmpty()) return
        hudPagesState.value = hudPresenter.textPages(trimmed)
        hudPageIndexState.value = 0
        sendCurrentPage(priority)
    }

    /** Moves to [index] (clamped) and re-pushes that page. Used by the UI and touchpad. */
    fun showPage(index: Int) {
        val pages = hudPagesState.value
        if (pages.isEmpty()) return
        hudPageIndexState.value = index.coerceIn(0, pages.size - 1)
        sendCurrentPage(HudArbiter.Priority.ANSWER)
    }

    fun showPreviousPage() = showPage(hudPageIndexState.value - 1)

    fun showNextPage() = showPage(hudPageIndexState.value + 1)

    private fun sendCurrentPage(priority: HudArbiter.Priority) {
        if (!isGlassesConnected) return
        val pages = hudPagesState.value
        val page = pages.getOrNull(hudPageIndexState.value) ?: return

        // Cancel any in-flight push so two pages can never interleave packets.
        hudSendJob?.cancel()
        hudSendJob = scope.launch {
            if (!hudArbiter.requestDisplay(priority)) return@launch
            // sendScreen owns the left-then-400ms-then-right ordering.
            transport.sendScreen(page.packets)
        }
    }

    // MARK: - Listening / answering

    fun toggleListening() = transcription.toggle()

    fun startListening() = transcription.start()

    fun stopListening() = transcription.stop()

    fun clearSpeechError() = transcription.clearError()

    private fun handleFinalTranscript(text: String) {
        transcriptState.value = text
        scope.launch {
            isAnsweringState.value = true
            val turn = engine.processLiveTranscript(text)
            isAnsweringState.value = false
            publish(turn)
            turn.answer?.let { answer ->
                if (isGlassesConnected) presentToGlasses(answer.text)
            }
        }
    }

    /** Manual detection over the latest transcript (right pad / EvenAI start). */
    fun triggerManualQuestion() {
        val transcript = transcriptState.value.ifBlank { partialTranscript.value }
        if (transcript.isBlank()) return
        askQuestion(transcript)
    }

    fun askQuestion(text: String) {
        val question = text.trim()
        if (question.isEmpty()) return
        scope.launch {
            isAnsweringState.value = true
            val turn = engine.answerTextQuestion(question)
            isAnsweringState.value = false
            publish(turn)
        }
    }

    private fun publish(turn: Turn) {
        lastTurnState.value = turn
        eventLogState.value = engine.eventLog()
    }

    fun setMode(mode: ConversationMode) = updateSettings { it.copy(mode = mode) }

    // MARK: - Archive / knowledge

    fun saveCurrentSession() {
        val turn = lastTurnState.value
        val answer = turn?.answer?.text.orEmpty()
        val question = turn?.question?.text.orEmpty()
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

    fun removeKnowledge(id: String) {
        scope.launch { knowledgeRepository.remove(id) }
    }

    companion object {
        const val HEARTBEAT_INTERVAL_MILLIS = 10_000L
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
data class GlassesDisplayPrefs(
    val brightness: Int = 30,
    val autoBrightness: Boolean = true,
    val headUpAngle: Int = 30,
    val displayHeight: Int = 4,
    val displayDepth: Int = 5,
)
