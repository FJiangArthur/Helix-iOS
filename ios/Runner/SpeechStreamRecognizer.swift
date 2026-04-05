//
//  SpeechStreamRecognizer.swift
//  Runner
//
//  Created by edy on 2024/4/16.
//
import AVFoundation
import Flutter
import Speech

enum TranscriptionBackend: String {
    case openai
    case appleCloud
    case appleOnDevice
    case whisper
}

class SpeechStreamRecognizer {
    static let shared = SpeechStreamRecognizer()

    private enum InputSource {
        case glassesPcm
        case microphone
    }

    private var recognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    private var lastRecognizedText = ""
    private var lastEmittedText = ""
    private var didEmitFinalResult = false
    private var activeInputSource: InputSource = .glassesPcm
    private var pendingStartCompletion: ((Result<Void, Error>) -> Void)?
    private var activeBackend: TranscriptionBackend = .appleCloud
    private let openaiTranscriber = OpenAIRealtimeTranscriber()
    let whisperTranscriber = WhisperBatchTranscriber()
    private let speakerTurnDetector = SpeakerTurnDetector()
    var enableDiarization = false
    var noiseReductionEnabled = false
    private lazy var rnnoiseProcessor = RNNoiseProcessor()
    /// Tracks consecutive silence duration for VAD-gated audio engine pause.
    private var consecutiveSilenceDuration: TimeInterval = 0
    /// Timestamp of the last detected voice activity.
    private var lastVoiceActivityTime: Date = Date()
    /// Duration of consecutive silence before pausing the audio engine.
    private static let silencePauseDuration: TimeInterval = 5.0
    /// Trailing buffer duration after last voice detection to avoid clipping.
    private static let vadTrailingBufferSec: TimeInterval = 0.3
    /// RMS energy threshold for VAD gating on the microphone input.
    private static let micVadThreshold: Float = 0.01
    /// Tracks whether the audio engine was paused due to silence.
    private var audioEnginePausedForSilence = false
    /// Raw PCM data buffer kept for diarization energy analysis.
    private var diarizationPcmBuffer = Data()
    /// Max size of the diarization PCM buffer (~30 seconds).
    private static let maxDiarizationPcmBytes = 30 * 16000 * 2
    private var speechEventSink: FlutterEventSink?
    private var pendingSpeechEvents: [[String: Any]] = []
    private var shouldBufferSpeechEvents = false
    private var didLogFirstPartialEmission = false
    private var didLogFinalEmission = false
    private var segmentCounter: Int = 0
    /// Monotonically increasing ID so callbacks from cancelled recognition tasks
    /// can detect they are stale and skip cleanup that would destroy the new task.
    private var recognitionGeneration: Int = 0
    var isPaused = false
    /// Callback for streaming PCM audio output from OpenAI Realtime voice responses.
    var onRealtimeAudioOutput: ((Data) -> Void)?
    /// Callback when a voice response audio stream completes.
    var onRealtimeAudioDone: (() -> Void)?
    private var isInputTapInstalled = false
    private var segmentRestartTimer: Timer?
    private static let segmentRestartInterval: TimeInterval = 15  // restart recognition every 15s to prevent degradation
    // Segment restart interval reduced from 25s to 15s for more responsive partials

    private var currentLanguageIdentifier: String = "EN"
    private var currentSource: String = "glasses"
    private let glassesPcmFormat = AVAudioFormat(
        commonFormat: .pcmFormatInt16,
        sampleRate: 16000,
        channels: 1,
        interleaved: false
    )!

    private var openAIMicrophoneConverter: AVAudioConverter?
    private var openAIMicrophoneInputFormat: AVAudioFormat?
    private let openAIMicrophoneOutputFormat = AVAudioFormat(
        commonFormat: .pcmFormatInt16,
        sampleRate: 16_000,
        channels: 1,
        interleaved: false
    )!

    private let openAIMicrophoneOutputFormat24kHz = AVAudioFormat(
        commonFormat: .pcmFormatInt16,
        sampleRate: 24_000,
        channels: 1,
        interleaved: false
    )!

    private var openAIMicrophoneConverter24kHz: AVAudioConverter?
    private var openAIMicrophoneInputFormat24kHz: AVAudioFormat?

    let languageDic = [
        "CN": "zh-CN",
        "EN": "en-US",
        "RU": "ru-RU",
        "KR": "ko-KR",
        "JP": "ja-JP",
        "ES": "es-ES",
        "FR": "fr-FR",
        "DE": "de-DE",
        "NL": "nl-NL",
        "NB": "nb-NO",
        "DA": "da-DK",
        "SV": "sv-SE",
        "FI": "fi-FI",
        "IT": "it-IT"
    ]

    enum RecognizerError: Error, LocalizedError {
        case nilRecognizer
        case notAuthorizedToRecognize
        case notPermittedToRecord
        case recognizerIsUnavailable

        var message: String {
            switch self {
            case .nilRecognizer: return "Can't initialize speech recognizer"
            case .notAuthorizedToRecognize: return "Not authorized to recognize speech"
            case .notPermittedToRecord: return "Not permitted to record audio"
            case .recognizerIsUnavailable: return "Recognizer is unavailable"
            }
        }

        var errorDescription: String? { message }
    }

    private init() {}

    func attachEventSink(_ sink: @escaping FlutterEventSink) {
        DispatchQueue.main.async {
            self.speechEventSink = sink
            self.shouldBufferSpeechEvents = true
            self.log("Speech event sink attached")
            self.flushBufferedSpeechEvents()
        }
    }

    func detachEventSink() {
        DispatchQueue.main.async {
            self.log("Speech event sink detached")
            self.speechEventSink = nil
            self.shouldBufferSpeechEvents = false
            self.pendingSpeechEvents.removeAll()
        }
    }

    func startRecognition(
        identifier: String,
        source: String = "glasses",
        backend: TranscriptionBackend = .appleCloud,
        apiKey: String? = nil,
        model: String? = nil,
        realtimeConversation: Bool = false,
        systemPrompt: String? = nil,
        voice: String = "alloy",
        vadSensitivity: Double = 0.5,
        transcriptionPrompt: String = "",
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        log("Starting recognition language=\(identifier) source=\(source) backend=\(backend.rawValue)")
        // Only stop if there's actually an active session to avoid killing
        // an in-flight OpenAI WebSocket connection on a redundant restart.
        if openaiTranscriber.isActive || whisperTranscriber.isActive || recognitionTask != nil {
            stopRecognition(emitFinal: false)
        }
        pendingStartCompletion = completion
        activeBackend = backend
        pendingSpeechEvents.removeAll()
        shouldBufferSpeechEvents = true

        // Map vadSensitivity (0.0-1.0, higher=more sensitive) to threshold (0.2-0.6, lower=more sensitive)
        openaiTranscriber.vadThreshold = 0.6 - (vadSensitivity * 0.4)
        openaiTranscriber.transcriptionPrompt = transcriptionPrompt

        if backend == .openai {
            startOpenAIRecognition(
                identifier: identifier,
                source: source,
                apiKey: apiKey ?? "",
                model: model ?? "gpt-4o-mini-transcribe",
                realtimeConversation: realtimeConversation,
                systemPrompt: systemPrompt,
                voice: voice,
                completion: completion
            )
            return
        }

        if backend == .whisper {
            whisperTranscriber.transcriptionPrompt = transcriptionPrompt
            startWhisperRecognition(
                identifier: identifier,
                source: source,
                apiKey: apiKey ?? "",
                model: model ?? "whisper-1",
                completion: completion
            )
            return
        }

        Task { @MainActor in
            let speechAuthorized = await SFSpeechRecognizer.hasAuthorizationToRecognize()
            self.log("Speech permission granted=\(speechAuthorized)")
            guard speechAuthorized else {
                self.failToStart(RecognizerError.notAuthorizedToRecognize)
                return
            }

            if source.lowercased() == "microphone" {
                let micAuthorized = await AVAudioSession.sharedInstance().hasPermissionToRecord()
                self.log("Microphone permission granted=\(micAuthorized)")
                guard micAuthorized else {
                    self.failToStart(RecognizerError.notPermittedToRecord)
                    return
                }
            }

            self.beginRecognition(identifier: identifier, source: source)
        }
    }

    private func beginRecognition(identifier: String, source: String) {

        lastRecognizedText = ""
        lastEmittedText = ""
        didEmitFinalResult = false
        didLogFirstPartialEmission = false
        didLogFinalEmission = false
        diarizationPcmBuffer = Data()
        currentLanguageIdentifier = identifier
        currentSource = source
        activeInputSource = source.lowercased() == "microphone"
            ? .microphone
            : .glassesPcm

        let localeIdentifier = languageDic[identifier] ?? "en-US"
        recognizer = SFSpeechRecognizer(locale: Locale(identifier: localeIdentifier))
        log("Recognizer locale=\(localeIdentifier)")

        guard let recognizer = recognizer else {
            failToStart(RecognizerError.nilRecognizer)
            return
        }

        log("Recognizer available=\(recognizer.isAvailable)")
        guard recognizer.isAvailable else {
            failToStart(RecognizerError.recognizerIsUnavailable)
            return
        }

        let audioSession = AVAudioSession.sharedInstance()
        do {
            // Use .measurement mode for glasses-only input to skip unnecessary
            // echo cancellation DSP; keep .voiceChat for phone microphone.
            let sessionMode: AVAudioSession.Mode = (activeInputSource == .glassesPcm)
                ? .measurement
                : .voiceChat
            try audioSession.setCategory(
                .playAndRecord,
                mode: sessionMode,
                options: [.defaultToSpeaker, .mixWithOthers, .allowBluetooth, .allowBluetoothA2DP]
            )
            try audioSession.setPreferredSampleRate(16000)
            try audioSession.setPreferredIOBufferDuration(0.02)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            log("Audio session configured source=\(source) mode=\(sessionMode == .measurement ? "measurement" : "voiceChat")")
        } catch {
            failToStart(error, messageOverride: "Error setting up audio session: \(error.localizedDescription)")
            return
        }

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            failToStart(
                RecognizerError.nilRecognizer,
                messageOverride: "Failed to create recognition request"
            )
            return
        }

        recognitionRequest.shouldReportPartialResults = true
        recognitionRequest.requiresOnDeviceRecognition = (activeBackend == .appleOnDevice)

        recognitionGeneration += 1
        let generation = recognitionGeneration
        recognitionTask = recognizer.recognitionTask(with: recognitionRequest) {
            [weak self] result, error in
            // Serialize all state mutations on the main queue to prevent race
            // conditions when Apple's recognizer fires concurrent callbacks.
            DispatchQueue.main.async {
                guard let self = self else { return }
                // After a segment restart the old task fires a cancellation callback.
                // Ignore it — the new task is already running.
                guard self.recognitionGeneration == generation else { return }

                if let result = result {
                    let text = result.bestTranscription.formattedString
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    if !text.isEmpty {
                        self.lastRecognizedText = text
                        self.emitTranscript(text, isFinal: result.isFinal)
                    }

                    if result.isFinal {
                        self.cleanupRecognition(deactivateSession: true)
                    }
                }

                if let error = error {
                    let nsError = error as NSError
                    // Code 203 = "no speech detected", 209 = "retry" — benign for
                    // continuous listening; restart the segment instead of killing the session.
                    if nsError.domain == "kAFAssistantErrorDomain" && (nsError.code == 203 || nsError.code == 209) {
                        self.log("Benign Apple Speech error (code \(nsError.code)), restarting segment")
                        self.restartRecognitionSegment()
                    } else {
                        self.completePendingStart(.failure(error))
                        self.emitError("Speech recognition failed: \(error.localizedDescription)")
                        self.emitTranscript(self.lastRecognizedText, isFinal: true)
                        self.cleanupRecognition(deactivateSession: true)
                    }
                }
            }
        }

        if activeInputSource == .microphone {
            do {
                try startMicrophoneCapture()
                log("Microphone capture started")
                completePendingStart(.success(()))
            } catch {
                failToStart(
                    error,
                    messageOverride: "Failed to start microphone capture: \(error.localizedDescription)"
                )
            }
        } else {
            completePendingStart(.success(()))
        }

        // Schedule periodic restart to prevent recognition degradation on long sessions.
        // Apple's SFSpeechRecognizer re-processes the entire audio buffer on each partial
        // result, causing increasing latency and garbled partials after ~20-30 seconds.
        startSegmentRestartTimer()
    }

    private func startSegmentRestartTimer() {
        segmentRestartTimer?.invalidate()
        segmentRestartTimer = Timer.scheduledTimer(
            withTimeInterval: Self.segmentRestartInterval,
            repeats: true
        ) { [weak self] _ in
            self?.restartRecognitionSegment()
        }
    }

    private func restartRecognitionSegment() {
        guard activeBackend != .openai else { return }  // OpenAI handles its own sessions
        guard activeBackend != .whisper else { return }  // Whisper batch handles its own chunking
        guard recognitionTask != nil else { return }
        guard !isPaused else { return }

        log("Restarting recognition segment to prevent degradation")

        // Finalize current text as a segment
        let currentText = lastRecognizedText
        if !currentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            emitTranscript(currentText, isFinal: true)
        }

        // Prepare the new recognizer and request BEFORE tearing down the old
        // task, so that appendPCMData() sees a valid recognitionRequest for
        // as much of the transition as possible.
        let localeIdentifier = languageDic[currentLanguageIdentifier] ?? "en-US"
        let newRecognizer = SFSpeechRecognizer(locale: Locale(identifier: localeIdentifier))

        guard let newRecognizer = newRecognizer, newRecognizer.isAvailable else {
            log("Recognizer unavailable during segment restart")
            return
        }

        let newRequest = SFSpeechAudioBufferRecognitionRequest()
        newRequest.shouldReportPartialResults = true
        newRequest.requiresOnDeviceRecognition = (activeBackend == .appleOnDevice)

        // Tear down old task — keep audio session alive.
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()

        // Swap to new request immediately so appendPCMData() can feed audio.
        recognitionRequest = newRequest
        recognizer = newRecognizer

        // Reset emission state for the new segment
        lastRecognizedText = ""
        lastEmittedText = ""
        didEmitFinalResult = false
        didLogFirstPartialEmission = false
        didLogFinalEmission = false

        recognitionGeneration += 1
        let generation = recognitionGeneration
        recognitionTask = newRecognizer.recognitionTask(with: newRequest) {
            [weak self] result, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                guard self.recognitionGeneration == generation else { return }

                if let result = result {
                    let text = result.bestTranscription.formattedString
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    if !text.isEmpty {
                        self.lastRecognizedText = text
                        self.emitTranscript(text, isFinal: result.isFinal)
                    }

                    if result.isFinal {
                        self.cleanupRecognition(deactivateSession: true)
                    }
                }

                if let error = error {
                    let nsError = error as NSError
                    if nsError.domain == "kAFAssistantErrorDomain" && (nsError.code == 203 || nsError.code == 209) {
                        self.log("Benign Apple Speech error (code \(nsError.code)), restarting segment")
                        self.restartRecognitionSegment()
                    } else {
                        self.emitError("Speech recognition failed: \(error.localizedDescription)")
                        self.emitTranscript(self.lastRecognizedText, isFinal: true)
                        self.cleanupRecognition(deactivateSession: true)
                    }
                }
            }
        }

        log("Recognition segment restarted gen=\(generation)")
    }

    private func startOpenAIRecognition(
        identifier: String,
        source: String,
        apiKey: String,
        model: String,
        realtimeConversation: Bool = false,
        systemPrompt: String? = nil,
        voice: String = "alloy",
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        lastRecognizedText = ""
        lastEmittedText = ""
        didEmitFinalResult = false
        didLogFirstPartialEmission = false
        didLogFinalEmission = false
        activeInputSource = source.lowercased() == "microphone" ? .microphone : .glassesPcm

        // Ensure mic permission before proceeding (phone mic path)
        if activeInputSource == .microphone {
            Task { @MainActor in
                let micAuthorized = await AVAudioSession.sharedInstance().hasPermissionToRecord()
                self.log("OpenAI mic permission granted=\(micAuthorized)")
                guard micAuthorized else {
                    self.failToStart(RecognizerError.notPermittedToRecord)
                    return
                }
                self._continueOpenAIRecognition(
                    identifier: identifier, source: source, apiKey: apiKey,
                    model: model, realtimeConversation: realtimeConversation,
                    systemPrompt: systemPrompt, voice: voice, completion: completion
                )
            }
            return
        }

        _continueOpenAIRecognition(
            identifier: identifier, source: source, apiKey: apiKey,
            model: model, realtimeConversation: realtimeConversation,
            systemPrompt: systemPrompt, voice: voice, completion: completion
        )
    }

    private func _continueOpenAIRecognition(
        identifier: String,
        source: String,
        apiKey: String,
        model: String,
        realtimeConversation: Bool = false,
        systemPrompt: String? = nil,
        voice: String = "alloy",
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        openaiTranscriber.onTranscript = { [weak self] text, isFinal in
            guard let self = self else { return }
            if !text.isEmpty {
                self.lastRecognizedText = text
                self.emitTranscript(text, isFinal: isFinal)
            }
        }
        openaiTranscriber.onError = { [weak self] message in
            self?.emitError(message)
        }
        openaiTranscriber.onResponse = { [weak self] text, isFinal in
            self?.emitAIResponse(text, isFinal: isFinal)
        }
        openaiTranscriber.onUsage = { [weak self] usage in
            self?.emitUsage(usage)
        }
        openaiTranscriber.onAudioOutput = { [weak self] audioData in
            self?.onRealtimeAudioOutput?(audioData)
        }
        openaiTranscriber.onAudioOutputDone = { [weak self] in
            self?.onRealtimeAudioDone?()
        }

        let langMap: [String: String] = [
            "CN": "zh", "EN": "en", "JP": "ja", "KR": "ko",
            "ES": "es", "RU": "ru", "FR": "fr", "DE": "de",
        ]
        let lang = langMap[identifier] ?? "en"

        let mode: RealtimeMode = realtimeConversation ? .conversation : .transcriptionOnly
        openaiTranscriber.start(apiKey: apiKey, model: model, language: lang, mode: mode, systemPrompt: systemPrompt ?? "", voice: voice) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success:
                if self.activeInputSource == .microphone {
                    let audioSession = AVAudioSession.sharedInstance()
                    do {
                        try audioSession.setCategory(
                            .playAndRecord,
                            mode: .voiceChat,
                            options: [.defaultToSpeaker, .mixWithOthers, .allowBluetooth, .allowBluetoothA2DP]
                        )
                        try audioSession.setPreferredSampleRate(16000)
                        try audioSession.setPreferredIOBufferDuration(0.02)
                        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

                        let inputNode = self.audioEngine.inputNode
                        let recordingFormat = inputNode.outputFormat(forBus: 0)
                        self.removeInputTapIfNeeded()
                        inputNode.installTap(onBus: 0, bufferSize: 4096, format: recordingFormat) {
                            [weak self] buffer, _ in
                            guard let self = self,
                                  let data = self.convertBufferToOpenAI24kHz(buffer) else { return }
                            self.openaiTranscriber.appendAudio(data)
                        }
                        self.openaiTranscriber.inputAlready24kHz = true
                        self.isInputTapInstalled = true
                        self.audioEngine.prepare()
                        try self.audioEngine.start()
                        self.log("OpenAI mic capture started")
                        completion(.success(()))
                    } catch {
                        self.log("OpenAI mic setup failed: \(error)")
                        self.openaiTranscriber.stop()
                        self.cleanupRecognition(deactivateSession: true)
                        completion(.failure(error))
                    }
                } else {
                    self.log("OpenAI glasses PCM mode ready")
                    completion(.success(()))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    // MARK: - Whisper Batch Transcription

    private func startWhisperRecognition(
        identifier: String,
        source: String,
        apiKey: String,
        model: String = "whisper-1",
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        lastRecognizedText = ""
        lastEmittedText = ""
        didEmitFinalResult = false
        didLogFirstPartialEmission = false
        didLogFinalEmission = false
        activeInputSource = source.lowercased() == "microphone" ? .microphone : .glassesPcm
        diarizationPcmBuffer = Data()

        // Configure language for Whisper (2-letter code)
        let langMap: [String: String] = [
            "CN": "zh", "EN": "en", "JP": "ja", "KR": "ko",
            "ES": "es", "RU": "ru", "FR": "fr", "DE": "de",
        ]
        let lang = langMap[identifier] ?? "en"

        // Wire up Whisper callbacks
        whisperTranscriber.onTranscript = { [weak self] text, isFinal in
            guard let self = self else { return }
            if !text.isEmpty {
                self.lastRecognizedText = text
                self.emitTranscript(text, isFinal: isFinal)
            }
        }

        whisperTranscriber.onWordTimestamps = { [weak self] words in
            guard let self = self, self.enableDiarization else { return }
            let pcmData = self.diarizationPcmBuffer
            guard !pcmData.isEmpty else { return }
            let segments = self.speakerTurnDetector.detectTurns(
                words: words,
                pcmData: pcmData,
                sampleRate: 16000
            )
            for segment in segments {
                self.emitSpeakerSegment(segment)
            }
        }

        whisperTranscriber.onDiarizedSegment = { [weak self] speaker, text, start, end in
            guard let self = self else { return }
            self.emitDiarizedTranscript(speaker: speaker, text: text, start: start, end: end)
        }

        whisperTranscriber.onError = { [weak self] message in
            self?.emitError(message)
        }

        // Start the transcriber
        whisperTranscriber.start(
            apiKey: apiKey,
            language: lang,
            chunkDurationSec: whisperTranscriber.chunkDurationSec,
            model: model
        )

        // If using microphone, set up audio session and tap
        if activeInputSource == .microphone {
            let audioSession = AVAudioSession.sharedInstance()
            do {
                try audioSession.setCategory(
                    .playAndRecord,
                    mode: .voiceChat,
                    options: [.defaultToSpeaker, .mixWithOthers, .allowBluetooth, .allowBluetoothA2DP]
                )
                try audioSession.setPreferredSampleRate(16000)
                try audioSession.setPreferredIOBufferDuration(0.02)
                try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

                let inputNode = audioEngine.inputNode
                let recordingFormat = inputNode.outputFormat(forBus: 0)
                removeInputTapIfNeeded()
                inputNode.installTap(onBus: 0, bufferSize: 1600, format: recordingFormat) {
                    [weak self] buffer, _ in
                    guard let self = self,
                          let data = self.convertBufferToOpenAIInput(buffer) else { return }
                    // VAD gating on microphone input
                    let rms = self.computeBufferRMS(data)
                    if rms >= Self.micVadThreshold {
                        self.lastVoiceActivityTime = Date()
                        self.consecutiveSilenceDuration = 0
                        if self.audioEnginePausedForSilence {
                            self.audioEnginePausedForSilence = false
                        }
                        self.whisperTranscriber.appendAudio(data)
                        // Also buffer for diarization
                        if self.enableDiarization {
                            self.appendDiarizationPcm(data)
                        }
                    } else {
                        // Check trailing buffer - keep processing briefly after voice
                        let silenceElapsed = Date().timeIntervalSince(self.lastVoiceActivityTime)
                        if silenceElapsed < Self.vadTrailingBufferSec {
                            self.whisperTranscriber.appendAudio(data)
                            if self.enableDiarization {
                                self.appendDiarizationPcm(data)
                            }
                        }
                    }
                }
                isInputTapInstalled = true
                audioEngine.prepare()
                try audioEngine.start()
                log("Whisper mic capture started")
                completion(.success(()))
            } catch {
                log("Whisper mic setup failed: \(error)")
                whisperTranscriber.stop()
                cleanupRecognition(deactivateSession: true)
                completion(.failure(error))
            }
        } else {
            // Glasses PCM mode - audio comes via appendPCMData()
            log("Whisper glasses PCM mode ready")
            completion(.success(()))
        }
    }

    /// Append PCM data to the diarization buffer (capped at ~30 seconds).
    private func appendDiarizationPcm(_ data: Data) {
        diarizationPcmBuffer.append(data)
        if diarizationPcmBuffer.count > Self.maxDiarizationPcmBytes {
            let overflow = diarizationPcmBuffer.count - Self.maxDiarizationPcmBytes
            diarizationPcmBuffer.removeFirst(overflow)
        }
    }

    /// Emit a diarized transcript from the gpt-4o-transcribe-diarize model.
    private func emitDiarizedTranscript(speaker: String, text: String, start: Double, end: Double) {
        let payload: [String: Any] = [
            "script": text,
            "isFinal": true,
            "speaker": speaker,
            "speakerStartTime": start,
            "speakerEndTime": end,
            "timestampMs": Int(Date().timeIntervalSince1970 * 1000),
        ]
        emitSpeechEvent(payload)
    }

    /// Emit a speaker segment via the speech event channel.
    private func emitSpeakerSegment(_ segment: SpeakerTurnDetector.SpeakerSegment) {
        let payload: [String: Any] = [
            "script": segment.text,
            "isFinal": true,
            "speaker": segment.speaker,
            "speakerStartTime": segment.startTime,
            "speakerEndTime": segment.endTime,
            "timestampMs": Int(Date().timeIntervalSince1970 * 1000),
        ]
        emitSpeechEvent(payload)
    }

    /// Compute RMS energy from raw PCM16 data for VAD gating.
    private func computeBufferRMS(_ pcmData: Data) -> Float {
        let sampleCount = pcmData.count / MemoryLayout<Int16>.size
        guard sampleCount > 0 else { return 0 }

        var sumSquares: Float = 0
        pcmData.withUnsafeBytes { rawBuffer in
            guard let ptr = rawBuffer.baseAddress?.assumingMemoryBound(to: Int16.self) else { return }
            for i in 0..<sampleCount {
                let sample = Float(ptr[i]) / Float(Int16.max)
                sumSquares += sample * sample
            }
        }

        return sqrt(sumSquares / Float(sampleCount))
    }

    // MARK: - File-based transcription for experimentation

    /// Transcribe an audio file using SFSpeechURLRecognitionRequest.
    /// Emits the same speech events as live recognition, enabling end-to-end
    /// pipeline testing with pre-recorded audio.
    ///
    /// - Parameters:
    ///   - fileURL: Local file URL to a WAV/M4A/MP3 audio file.
    ///   - identifier: Language identifier (e.g. "EN", "CN").
    ///   - realtime: If true, reads the file in 100ms PCM chunks to simulate
    ///     real-time streaming pace. If false, uses SFSpeechURLRecognitionRequest
    ///     for fastest-possible transcription.
    ///   - completion: Called when transcription setup succeeds or fails.
    func transcribeAudioFile(
        fileURL: URL,
        identifier: String = "EN",
        realtime: Bool = false,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        log("transcribeAudioFile path=\(fileURL.path) realtime=\(realtime) lang=\(identifier)")

        // Stop any active session first
        if recognitionTask != nil || openaiTranscriber.isActive {
            stopRecognition(emitFinal: false)
        }

        lastRecognizedText = ""
        lastEmittedText = ""
        didEmitFinalResult = false
        didLogFirstPartialEmission = false
        didLogFinalEmission = false
        currentLanguageIdentifier = identifier
        activeBackend = .appleCloud
        pendingSpeechEvents.removeAll()
        shouldBufferSpeechEvents = true

        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            let err = NSError(domain: "SpeechStreamRecognizer", code: 404,
                              userInfo: [NSLocalizedDescriptionKey: "Audio file not found: \(fileURL.path)"])
            failToStart(err)
            completion(.failure(err))
            return
        }

        let localeIdentifier = languageDic[identifier] ?? "en-US"
        recognizer = SFSpeechRecognizer(locale: Locale(identifier: localeIdentifier))

        guard let recognizer = recognizer, recognizer.isAvailable else {
            let err = RecognizerError.recognizerIsUnavailable
            failToStart(err)
            completion(.failure(err))
            return
        }

        if realtime {
            transcribeFileRealtime(fileURL: fileURL, recognizer: recognizer, completion: completion)
        } else {
            transcribeFileURL(fileURL: fileURL, recognizer: recognizer, completion: completion)
        }
    }

    /// Fast file transcription using SFSpeechURLRecognitionRequest.
    /// Apple handles decoding and pacing internally.
    private func transcribeFileURL(
        fileURL: URL,
        recognizer: SFSpeechRecognizer,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        let request = SFSpeechURLRecognitionRequest(url: fileURL)
        request.shouldReportPartialResults = true

        recognitionGeneration += 1
        let generation = recognitionGeneration
        let startTime = Date()

        recognitionTask = recognizer.recognitionTask(with: request) {
            [weak self] result, error in
            DispatchQueue.main.async {
                guard let self = self, self.recognitionGeneration == generation else { return }

                if let result = result {
                    let text = result.bestTranscription.formattedString
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    if !text.isEmpty {
                        self.lastRecognizedText = text
                        self.emitTranscript(text, isFinal: result.isFinal)
                    }
                    if result.isFinal {
                        let elapsed = Date().timeIntervalSince(startTime)
                        self.log("File transcription complete in \(String(format: "%.2f", elapsed))s chars=\(text.count)")
                        self.cleanupRecognition(deactivateSession: false)
                    }
                }

                if let error = error {
                    self.emitError("File transcription failed: \(error.localizedDescription)")
                    self.emitTranscript(self.lastRecognizedText, isFinal: true)
                    self.cleanupRecognition(deactivateSession: false)
                }
            }
        }

        log("SFSpeechURLRecognitionRequest started for \(fileURL.lastPathComponent)")
        completion(.success(()))
    }

    /// Real-time file transcription: reads PCM chunks and feeds them at real-time
    /// pace through SFSpeechAudioBufferRecognitionRequest — same path as live audio.
    private func transcribeFileRealtime(
        fileURL: URL,
        recognizer: SFSpeechRecognizer,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        recognitionRequest = request

        recognitionGeneration += 1
        let generation = recognitionGeneration
        let startTime = Date()

        recognitionTask = recognizer.recognitionTask(with: request) {
            [weak self] result, error in
            DispatchQueue.main.async {
                guard let self = self, self.recognitionGeneration == generation else { return }

                if let result = result {
                    let text = result.bestTranscription.formattedString
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    if !text.isEmpty {
                        self.lastRecognizedText = text
                        self.emitTranscript(text, isFinal: result.isFinal)
                    }
                    if result.isFinal {
                        let elapsed = Date().timeIntervalSince(startTime)
                        self.log("Realtime file transcription complete in \(String(format: "%.2f", elapsed))s")
                        self.cleanupRecognition(deactivateSession: false)
                    }
                }

                if let error = error {
                    self.emitError("Realtime file transcription failed: \(error.localizedDescription)")
                    self.emitTranscript(self.lastRecognizedText, isFinal: true)
                    self.cleanupRecognition(deactivateSession: false)
                }
            }
        }

        // Feed audio chunks on a background queue at real-time pace
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            do {
                let audioFile = try AVAudioFile(forReading: fileURL)
                let processingFormat = AVAudioFormat(
                    commonFormat: .pcmFormatInt16,
                    sampleRate: 16000,
                    channels: 1,
                    interleaved: false
                )!

                // If file isn't 16kHz mono, we need a converter
                let fileFormat = audioFile.processingFormat
                let needsConversion = fileFormat.sampleRate != 16000 ||
                    fileFormat.channelCount != 1

                let chunkDuration: TimeInterval = 0.1  // 100ms chunks
                let chunkFrames = AVAudioFrameCount(16000 * chunkDuration)  // 1600 frames

                if needsConversion {
                    // Read in file's native format then convert
                    guard let converter = AVAudioConverter(from: fileFormat, to: processingFormat) else {
                        self.log("Failed to create audio converter")
                        DispatchQueue.main.async { request.endAudio() }
                        return
                    }

                    let readBuffer = AVAudioPCMBuffer(
                        pcmFormat: fileFormat,
                        frameCapacity: AVAudioFrameCount(fileFormat.sampleRate * chunkDuration)
                    )!

                    while audioFile.framePosition < audioFile.length {
                        guard self.recognitionGeneration == generation else { break }
                        try audioFile.read(into: readBuffer)

                        let outputBuffer = AVAudioPCMBuffer(
                            pcmFormat: processingFormat, frameCapacity: chunkFrames
                        )!

                        var didProvide = false
                        let _ = converter.convert(to: outputBuffer, error: nil) { _, outStatus in
                            if didProvide {
                                outStatus.pointee = .noDataNow
                                return nil
                            }
                            didProvide = true
                            outStatus.pointee = .haveData
                            return readBuffer
                        }

                        if outputBuffer.frameLength > 0 {
                            request.append(outputBuffer)
                        }

                        Thread.sleep(forTimeInterval: chunkDuration)
                    }
                } else {
                    // Already 16kHz mono — read directly
                    let buffer = AVAudioPCMBuffer(
                        pcmFormat: processingFormat, frameCapacity: chunkFrames
                    )!

                    while audioFile.framePosition < audioFile.length {
                        guard self.recognitionGeneration == generation else { break }
                        try audioFile.read(into: buffer)
                        request.append(buffer)
                        Thread.sleep(forTimeInterval: chunkDuration)
                    }
                }

                DispatchQueue.main.async {
                    self.log("Finished feeding audio file chunks")
                    request.endAudio()
                }
            } catch {
                self.log("Error reading audio file: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.emitError("Failed to read audio file: \(error.localizedDescription)")
                    request.endAudio()
                }
            }
        }

        log("Realtime file transcription started for \(fileURL.lastPathComponent)")
        completion(.success(()))
    }

    func pauseRecognition() {
        isPaused = true
        log("Recognition paused")
    }

    func resumeRecognition() {
        isPaused = false
        log("Recognition resumed")
    }

    func stopRecognition(emitFinal: Bool = true) {
        isPaused = false
        _stopRecognition(emitFinal: emitFinal)
    }

    /// Restart the current recognition session with the same parameters.
    /// Used by GlassesMicSessionManager for continuous glasses mic sessions.
    func restartCurrentSession() {
        restartRecognitionSegment()
    }

    func appendPCMData(_ pcmData: Data) {
        guard activeInputSource == .glassesPcm else { return }
        guard !isPaused else { return }
        if activeBackend == .openai {
            openaiTranscriber.appendAudio(pcmData)
            return
        }
        if activeBackend == .whisper {
            // Apply noise reduction if enabled
            let processedData: Data
            if noiseReductionEnabled, rnnoiseProcessor.isAvailable {
                processedData = rnnoiseProcessor.processPCM16(pcmData) as Data
            } else {
                processedData = pcmData
            }
            whisperTranscriber.appendAudio(processedData)
            // Also buffer for diarization
            if enableDiarization {
                appendDiarizationPcm(processedData)
            }
            // Resume audio engine if it was paused for silence and BLE data arrives
            if audioEnginePausedForSilence {
                audioEnginePausedForSilence = false
                lastVoiceActivityTime = Date()
                consecutiveSilenceDuration = 0
            }
            return
        }
        guard let recognitionRequest = recognitionRequest else {
            log("Recognition request is not available")
            return
        }

        let bytesPerFrame = glassesPcmFormat.streamDescription.pointee.mBytesPerFrame
        let frameCapacity = AVAudioFrameCount(pcmData.count) / bytesPerFrame
        guard let audioBuffer = AVAudioPCMBuffer(
            pcmFormat: glassesPcmFormat,
            frameCapacity: frameCapacity
        ) else {
            log("Failed to create audio buffer")
            return
        }

        audioBuffer.frameLength = audioBuffer.frameCapacity

        pcmData.withUnsafeBytes { bufferPointer in
            if let audioDataPointer = bufferPointer.baseAddress?.assumingMemoryBound(to: Int16.self) {
                audioBuffer.int16ChannelData?.pointee.initialize(
                    from: audioDataPointer,
                    count: pcmData.count / MemoryLayout<Int16>.size
                )
                recognitionRequest.append(audioBuffer)
            } else {
                log("Failed to get pointer to audio data")
            }
        }

        // Buffer PCM for diarization when enabled (Apple Speech glasses path)
        if enableDiarization {
            appendDiarizationPcm(pcmData)
        }
    }

    private func startMicrophoneCapture() throws {
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        log("Mic capture format: sampleRate=\(recordingFormat.sampleRate) channels=\(recordingFormat.channelCount)")

        guard recordingFormat.sampleRate > 0 else {
            throw RecognizerError.notPermittedToRecord
        }

        removeInputTapIfNeeded()
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) {
            [weak self] buffer, _ in
            guard let self = self else { return }
            self.recognitionRequest?.append(buffer)
            // Buffer PCM for diarization when enabled
            if self.enableDiarization, let data = self.convertBufferToOpenAIInput(buffer) {
                self.appendDiarizationPcm(data)
            }
        }
        isInputTapInstalled = true

        audioEngine.prepare()
        try audioEngine.start()
        log("Audio engine started for microphone capture")
    }

    private func _stopRecognition(emitFinal: Bool) {
        segmentRestartTimer?.invalidate()
        segmentRestartTimer = nil
        log("Stopping recognition emitFinal=\(emitFinal) backend=\(activeBackend.rawValue)")
        if activeBackend == .openai {
            if emitFinal {
                emitTranscript(lastRecognizedText, isFinal: true)
            }
            openaiTranscriber.stop()
            if audioEngine.isRunning {
                audioEngine.stop()
            }
            removeInputTapIfNeeded()
            return
        }

        if activeBackend == .whisper {
            if emitFinal {
                // Flush remaining audio in the whisper buffer
                whisperTranscriber.flush()
                emitTranscript(lastRecognizedText, isFinal: true)
            }
            whisperTranscriber.stop()
            diarizationPcmBuffer = Data()
            audioEnginePausedForSilence = false
            if audioEngine.isRunning {
                audioEngine.stop()
            }
            removeInputTapIfNeeded()
            cleanupRecognition(deactivateSession: true)
            return
        }

        if emitFinal {
            emitTranscript(lastRecognizedText, isFinal: true)
        }

        diarizationPcmBuffer = Data()
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        cleanupRecognition(deactivateSession: true)
    }

    private func emitTranscript(_ text: String, isFinal: Bool) {
        // While paused, suppress all emissions from the recognizer's
        // internal buffer.  Buffered results would trigger competing
        // analysis cycles in the Dart engine and cancel the in-flight
        // answer.  The segment will be finalized when recognition
        // restarts after resume.
        if isPaused { return }

        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if normalized.isEmpty && !isFinal { return }
        if didEmitFinalResult && isFinal { return }
        if !isFinal && normalized == lastEmittedText { return }

        // Reset final guard when new speech arrives (enables multi-segment OpenAI flow)
        if !isFinal {
            didEmitFinalResult = false
            didLogFinalEmission = false
        }

        if isFinal {
            didEmitFinalResult = true
            lastEmittedText = ""
            segmentCounter += 1
            if !didLogFinalEmission {
                didLogFinalEmission = true
                log("Final transcript emitted chars=\(normalized.count)")
            }
        } else {
            lastEmittedText = normalized
            if !didLogFirstPartialEmission {
                didLogFirstPartialEmission = true
                log("First partial transcript emitted chars=\(normalized.count)")
            }
        }

        var payload: [String: Any] = [
            "script": normalized,
            "isFinal": isFinal,
            "timestampMs": Int(Date().timeIntervalSince1970 * 1000),
        ]
        if isFinal {
            payload["segmentId"] = segmentCounter
        }
        emitSpeechEvent(payload)

        // Run energy-based diarization on final Apple Speech segments
        if isFinal && enableDiarization && (activeBackend == .appleCloud || activeBackend == .appleOnDevice) {
            runAppleSpeechDiarization(text: normalized)
        }
    }

    /// Run energy-based speaker diarization on the accumulated PCM buffer for
    /// Apple Speech segments. Apple Speech doesn't provide word-level timestamps,
    /// so we treat the entire segment as a single block and assign a speaker label
    /// based on average energy.
    private func runAppleSpeechDiarization(text: String) {
        guard enableDiarization else { return }
        let pcmData = diarizationPcmBuffer
        guard !pcmData.isEmpty else { return }

        // For Apple Speech, we don't have word timestamps.
        // Create a single "word" spanning the entire segment for the detector.
        let duration = Double(pcmData.count) / (16000.0 * 2.0) // 16kHz, 16-bit
        let words = [WhisperWord(
            word: text,
            start: 0.0,
            end: duration
        )]

        let segments = speakerTurnDetector.detectTurns(
            words: words,
            pcmData: pcmData,
            sampleRate: 16000
        )

        for segment in segments {
            emitSpeakerSegment(segment)
        }

        // Clear buffer after processing
        diarizationPcmBuffer = Data()
    }

    private func emitError(_ message: String) {
        log("Speech error emitted: \(message)")
        emitSpeechEvent([
            "script": lastRecognizedText,
            "isFinal": true,
            "error": message
        ])
    }

    private func emitAIResponse(_ text: String, isFinal: Bool) {
        emitSpeechEvent([
            "aiResponse": text,
            "isFinal": isFinal,
        ])
    }

    private func emitUsage(_ usage: [String: Any]) {
        emitSpeechEvent([
            "usage": usage,
            "usageOperationType": usage["operationType"] as? String ?? "",
            "usageModel": usage["model"] as? String ?? "",
            "isUsageEvent": true,
        ])
    }

    private func failToStart(
        _ error: Error,
        messageOverride: String? = nil
    ) {
        emitError(messageOverride ?? errorMessage(for: error))
        cleanupRecognition(deactivateSession: true)
        completePendingStart(.failure(error))
    }

    private func completePendingStart(_ result: Result<Void, Error>) {
        guard let completion = pendingStartCompletion else { return }
        pendingStartCompletion = nil
        DispatchQueue.main.async {
            completion(result)
        }
    }

    private func errorMessage(for error: Error) -> String {
        if let recognizerError = error as? RecognizerError {
            return recognizerError.message
        }
        return error.localizedDescription
    }

    private func emitSpeechEvent(_ payload: [String: Any]) {
        DispatchQueue.main.async {
            if let sink = self.speechEventSink {
                sink(payload)
                return
            }

            guard self.shouldBufferSpeechEvents else {
                self.log("Dropping speech event without active sink: \(payload)")
                return
            }

            self.pendingSpeechEvents.append(payload)
        }
    }

    private func flushBufferedSpeechEvents() {
        guard let sink = speechEventSink else { return }
        guard !pendingSpeechEvents.isEmpty else { return }

        let bufferedEvents = pendingSpeechEvents
        pendingSpeechEvents.removeAll()
        log("Flushing buffered speech events count=\(bufferedEvents.count)")
        for event in bufferedEvents {
            sink(event)
        }
    }

    private func cleanupRecognition(deactivateSession: Bool) {
        segmentRestartTimer?.invalidate()
        segmentRestartTimer = nil

        if audioEngine.isRunning {
            audioEngine.stop()
        }
        removeInputTapIfNeeded()
        openAIMicrophoneConverter = nil
        openAIMicrophoneInputFormat = nil

        recognitionRequest = nil
        recognitionTask = nil
        recognizer = nil

        guard deactivateSession else { return }
        do {
            try AVAudioSession.sharedInstance().setActive(
                false,
                options: .notifyOthersOnDeactivation
            )
        } catch {
            log("Error stopping audio session: \(error.localizedDescription)")
        }
        log("Recognition cleanup finished deactivateSession=\(deactivateSession)")
    }

    private func log(_ message: String) {
        NSLog("[SpeechStreamRecognizer] %@", message)
    }

    private func removeInputTapIfNeeded() {
        guard isInputTapInstalled else { return }
        audioEngine.inputNode.removeTap(onBus: 0)
        isInputTapInstalled = false
    }

    private func convertBufferToOpenAIInput(_ buffer: AVAudioPCMBuffer) -> Data? {
        let inputFormat = buffer.format

        if openAIMicrophoneConverter == nil || openAIMicrophoneInputFormat != inputFormat {
            openAIMicrophoneInputFormat = inputFormat
            openAIMicrophoneConverter = AVAudioConverter(
                from: inputFormat,
                to: openAIMicrophoneOutputFormat
            )
        }

        guard let converter = openAIMicrophoneConverter else {
            log("Failed to create AVAudioConverter for OpenAI microphone input")
            return nil
        }

        let outputFrameCapacity = AVAudioFrameCount(
            ceil(Double(buffer.frameLength) * openAIMicrophoneOutputFormat.sampleRate / inputFormat.sampleRate)
        )

        guard let outputBuffer = AVAudioPCMBuffer(
            pcmFormat: openAIMicrophoneOutputFormat,
            frameCapacity: max(outputFrameCapacity, 1)
        ) else {
            log("Failed to allocate converted microphone buffer")
            return nil
        }

        var didProvideInput = false
        var conversionError: NSError?
        let status = converter.convert(to: outputBuffer, error: &conversionError) { _, outStatus in
            if didProvideInput {
                outStatus.pointee = .noDataNow
                return nil
            }

            didProvideInput = true
            outStatus.pointee = .haveData
            return buffer
        }

        if let conversionError {
            log("Microphone buffer conversion failed: \(conversionError.localizedDescription)")
            return nil
        }

        guard status == .haveData || status == .inputRanDry,
              outputBuffer.frameLength > 0,
              let channelData = outputBuffer.int16ChannelData else {
            return nil
        }

        let byteCount = Int(outputBuffer.frameLength) * MemoryLayout<Int16>.size
        return Data(bytes: channelData.pointee, count: byteCount)
    }

    /// Convert microphone buffer directly to 24kHz PCM16 for OpenAI Realtime.
    private func convertBufferToOpenAI24kHz(_ buffer: AVAudioPCMBuffer) -> Data? {
        let inputFormat = buffer.format

        if openAIMicrophoneConverter24kHz == nil || openAIMicrophoneInputFormat24kHz != inputFormat {
            openAIMicrophoneInputFormat24kHz = inputFormat
            openAIMicrophoneConverter24kHz = AVAudioConverter(
                from: inputFormat,
                to: openAIMicrophoneOutputFormat24kHz
            )
        }

        guard let converter = openAIMicrophoneConverter24kHz else {
            log("Failed to create AVAudioConverter for 24kHz OpenAI mic input")
            return nil
        }

        let outputFrameCapacity = AVAudioFrameCount(
            ceil(Double(buffer.frameLength) * openAIMicrophoneOutputFormat24kHz.sampleRate / inputFormat.sampleRate)
        )

        guard let outputBuffer = AVAudioPCMBuffer(
            pcmFormat: openAIMicrophoneOutputFormat24kHz,
            frameCapacity: max(outputFrameCapacity, 1)
        ) else {
            log("Failed to allocate 24kHz converted mic buffer")
            return nil
        }

        var didProvideInput = false
        var conversionError: NSError?
        let status = converter.convert(to: outputBuffer, error: &conversionError) { _, outStatus in
            if didProvideInput {
                outStatus.pointee = .noDataNow
                return nil
            }
            didProvideInput = true
            outStatus.pointee = .haveData
            return buffer
        }

        if let conversionError {
            log("24kHz mic conversion failed: \(conversionError.localizedDescription)")
            return nil
        }

        guard status == .haveData || status == .inputRanDry,
              outputBuffer.frameLength > 0,
              let channelData = outputBuffer.int16ChannelData else {
            return nil
        }

        let byteCount = Int(outputBuffer.frameLength) * MemoryLayout<Int16>.size
        return Data(bytes: channelData.pointee, count: byteCount)
    }
}

extension SFSpeechRecognizer {
    static func hasAuthorizationToRecognize() async -> Bool {
        await withCheckedContinuation { continuation in
            requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }
}

extension AVAudioSession {
    func hasPermissionToRecord() async -> Bool {
        if #available(iOS 17.0, *) {
            return await AVAudioApplication.requestRecordPermission()
        } else {
            return await withCheckedContinuation { continuation in
                requestRecordPermission { authorized in
                    continuation.resume(returning: authorized)
                }
            }
        }
    }
}
