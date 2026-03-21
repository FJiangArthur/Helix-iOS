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
    private var isInputTapInstalled = false
    private var segmentRestartTimer: Timer?
    private static let segmentRestartInterval: TimeInterval = 15  // restart recognition every 15s to prevent degradation
    // Segment restart interval reduced from 25s to 15s for more responsive partials

    private var currentLanguageIdentifier: String = "EN"
    private var currentSource: String = "glasses"
    private var openAIMicrophoneConverter: AVAudioConverter?
    private var openAIMicrophoneInputFormat: AVAudioFormat?
    private let openAIMicrophoneOutputFormat = AVAudioFormat(
        commonFormat: .pcmFormatInt16,
        sampleRate: 16_000,
        channels: 1,
        interleaved: false
    )!

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
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        log("Starting recognition language=\(identifier) source=\(source) backend=\(backend.rawValue)")
        // Only stop if there's actually an active session to avoid killing
        // an in-flight OpenAI WebSocket connection on a redundant restart.
        if openaiTranscriber.isActive || recognitionTask != nil {
            stopRecognition(emitFinal: false)
        }
        pendingStartCompletion = completion
        activeBackend = backend
        pendingSpeechEvents.removeAll()
        shouldBufferSpeechEvents = true

        if backend == .openai {
            startOpenAIRecognition(
                identifier: identifier,
                source: source,
                apiKey: apiKey ?? "",
                model: model ?? "gpt-4o-mini-transcribe",
                realtimeConversation: realtimeConversation,
                systemPrompt: systemPrompt,
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
            try audioSession.setCategory(
                .playAndRecord,
                mode: .voiceChat,
                options: [.defaultToSpeaker, .mixWithOthers, .allowBluetooth, .allowBluetoothA2DP]
            )
            try audioSession.setPreferredSampleRate(16000)
            try audioSession.setPreferredIOBufferDuration(0.02)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            log("Audio session configured source=\(source)")
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
                    self.completePendingStart(.failure(error))
                    self.emitError("Speech recognition failed: \(error.localizedDescription)")
                    self.emitTranscript(self.lastRecognizedText, isFinal: true)
                    self.cleanupRecognition(deactivateSession: true)
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
                    self.emitError("Speech recognition failed: \(error.localizedDescription)")
                    self.emitTranscript(self.lastRecognizedText, isFinal: true)
                    self.cleanupRecognition(deactivateSession: true)
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
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        lastRecognizedText = ""
        lastEmittedText = ""
        didEmitFinalResult = false
        didLogFirstPartialEmission = false
        didLogFinalEmission = false
        activeInputSource = source.lowercased() == "microphone" ? .microphone : .glassesPcm

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

        let langMap: [String: String] = [
            "CN": "zh", "EN": "en", "JP": "ja", "KR": "ko",
            "ES": "es", "RU": "ru", "FR": "fr", "DE": "de",
        ]
        let lang = langMap[identifier] ?? "en"

        let mode: RealtimeMode = realtimeConversation ? .conversation : .transcriptionOnly
        openaiTranscriber.start(apiKey: apiKey, model: model, language: lang, mode: mode, systemPrompt: systemPrompt ?? "") { [weak self] result in
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
                        inputNode.installTap(onBus: 0, bufferSize: 1600, format: recordingFormat) {
                            [weak self] buffer, _ in
                            guard let self = self,
                                  let data = self.convertBufferToOpenAIInput(buffer) else { return }
                            self.openaiTranscriber.appendAudio(data)
                        }
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

    func stopRecognition() {
        isPaused = false
        stopRecognition(emitFinal: true)
    }

    func appendPCMData(_ pcmData: Data) {
        guard activeInputSource == .glassesPcm else { return }
        guard !isPaused else { return }
        if activeBackend == .openai {
            openaiTranscriber.appendAudio(pcmData)
            return
        }
        guard let recognitionRequest = recognitionRequest else {
            log("Recognition request is not available")
            return
        }

        let audioFormat = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: 16000,
            channels: 1,
            interleaved: false
        )!

        let bytesPerFrame = audioFormat.streamDescription.pointee.mBytesPerFrame
        let frameCapacity = AVAudioFrameCount(pcmData.count) / bytesPerFrame
        guard let audioBuffer = AVAudioPCMBuffer(
            pcmFormat: audioFormat,
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
    }

    private func startMicrophoneCapture() throws {
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        removeInputTapIfNeeded()
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) {
            [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }
        isInputTapInstalled = true

        audioEngine.prepare()
        try audioEngine.start()
    }

    private func stopRecognition(emitFinal: Bool) {
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

        if emitFinal {
            emitTranscript(lastRecognizedText, isFinal: true)
        }

        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        cleanupRecognition(deactivateSession: true)
    }

    private func emitTranscript(_ text: String, isFinal: Bool) {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if normalized.isEmpty && !isFinal { return }
        if didEmitFinalResult && isFinal { return }
        if !isFinal && normalized == lastEmittedText { return }

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
        await withCheckedContinuation { continuation in
            requestRecordPermission { authorized in
                continuation.resume(returning: authorized)
            }
        }
    }
}
