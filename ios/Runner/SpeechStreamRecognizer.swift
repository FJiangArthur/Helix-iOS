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
    private var isInputTapInstalled = false
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

        recognitionTask = recognizer.recognitionTask(with: recognitionRequest) {
            [weak self] result, error in
            guard let self = self else { return }

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

    func stopRecognition() {
        stopRecognition(emitFinal: true)
    }

    func appendPCMData(_ pcmData: Data) {
        guard activeInputSource == .glassesPcm else { return }
        if activeBackend == .openai {
            openaiTranscriber.appendAudio(pcmData)
            return
        }
        guard let recognitionRequest = recognitionRequest else {
            print("Recognition request is not available")
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
            print("Failed to create audio buffer")
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
                print("Failed to get pointer to audio data")
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

        emitSpeechEvent([
            "script": normalized,
            "isFinal": isFinal
        ])
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
