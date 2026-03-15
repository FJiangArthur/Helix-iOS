//
//  SpeechStreamRecognizer.swift
//  Runner
//
//  Created by edy on 2024/4/16.
//
import AVFoundation
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

    func startRecognition(
        identifier: String,
        source: String = "glasses",
        backend: TranscriptionBackend = .appleCloud,
        apiKey: String? = nil,
        model: String? = nil,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        print("[SpeechRecognizer] startRecognition called — identifier=\(identifier), source=\(source)")
        stopRecognition(emitFinal: false)
        pendingStartCompletion = completion
        activeBackend = backend

        if backend == .openai {
            startOpenAIRecognition(
                identifier: identifier,
                source: source,
                apiKey: apiKey ?? "",
                model: model ?? "gpt-4o-mini-transcribe",
                completion: completion
            )
            return
        }

        Task { @MainActor in
            let speechAuthorized = await SFSpeechRecognizer.hasAuthorizationToRecognize()
            print("[SpeechRecognizer] Speech authorization: \(speechAuthorized)")
            guard speechAuthorized else {
                self.failToStart(RecognizerError.notAuthorizedToRecognize)
                return
            }

            if source.lowercased() == "microphone" {
                let micAuthorized = await AVAudioSession.sharedInstance().hasPermissionToRecord()
                print("[SpeechRecognizer] Microphone authorization: \(micAuthorized)")
                guard micAuthorized else {
                    self.failToStart(RecognizerError.notPermittedToRecord)
                    return
                }
            }

            self.beginRecognition(identifier: identifier, source: source)
        }
    }

    private func beginRecognition(identifier: String, source: String) {
        print("[SpeechRecognizer] beginRecognition — identifier=\(identifier), source=\(source)")

        lastRecognizedText = ""
        lastEmittedText = ""
        didEmitFinalResult = false
        activeInputSource = source.lowercased() == "microphone"
            ? .microphone
            : .glassesPcm

        let localeIdentifier = languageDic[identifier] ?? "en-US"
        print("[SpeechRecognizer] Creating recognizer for locale: \(localeIdentifier)")
        recognizer = SFSpeechRecognizer(locale: Locale(identifier: localeIdentifier))

        guard let recognizer = recognizer else {
            print("[SpeechRecognizer] ERROR: recognizer is nil for locale \(localeIdentifier)")
            failToStart(RecognizerError.nilRecognizer)
            return
        }

        guard recognizer.isAvailable else {
            print("[SpeechRecognizer] ERROR: recognizer not available (network issue or unsupported locale)")
            failToStart(RecognizerError.recognizerIsUnavailable)
            return
        }
        print("[SpeechRecognizer] Recognizer available — supportsOnDeviceRecognition=\(recognizer.supportsOnDeviceRecognition)")

        let audioSession = AVAudioSession.sharedInstance()
        do {
            print("[SpeechRecognizer] Configuring audio session...")
            try audioSession.setCategory(
                .playAndRecord,
                mode: .voiceChat,
                options: [.defaultToSpeaker, .mixWithOthers, .allowBluetooth, .allowBluetoothA2DP]
            )
            try audioSession.setPreferredSampleRate(16000)
            try audioSession.setPreferredIOBufferDuration(0.02)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            print("[SpeechRecognizer] Audio session configured — sampleRate=\(audioSession.sampleRate), ioBufferDuration=\(audioSession.ioBufferDuration)")
        } catch {
            print("[SpeechRecognizer] Audio session setup FAILED: \(error.localizedDescription)")
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
                print("[SpeechRecognizer] Result — isFinal=\(result.isFinal), text=\"\(text.prefix(80))\"")
                if !text.isEmpty {
                    self.lastRecognizedText = text
                    self.emitTranscript(text, isFinal: result.isFinal)
                }

                if result.isFinal {
                    self.cleanupRecognition(deactivateSession: true)
                }
            }

            if let error = error {
                print("[SpeechRecognizer] Recognition error: \(error.localizedDescription)")
                self.completePendingStart(.failure(error))
                self.emitError("Speech recognition failed: \(error.localizedDescription)")
                self.emitTranscript(self.lastRecognizedText, isFinal: true)
                self.cleanupRecognition(deactivateSession: true)
            }
        }

        if activeInputSource == .microphone {
            do {
                try startMicrophoneCapture()
                print("[SpeechRecognizer] Microphone capture started successfully")
                completePendingStart(.success(()))
            } catch {
                print("[SpeechRecognizer] Microphone capture FAILED: \(error.localizedDescription)")
                failToStart(
                    error,
                    messageOverride: "Failed to start microphone capture: \(error.localizedDescription)"
                )
            }
        } else {
            print("[SpeechRecognizer] Glasses PCM mode — waiting for appendPCMData calls")
            completePendingStart(.success(()))
        }
    }

    private func startOpenAIRecognition(
        identifier: String,
        source: String,
        apiKey: String,
        model: String,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        lastRecognizedText = ""
        lastEmittedText = ""
        didEmitFinalResult = false
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

        let langMap: [String: String] = [
            "CN": "zh", "EN": "en", "JP": "ja", "KR": "ko",
            "ES": "es", "RU": "ru", "FR": "fr", "DE": "de",
        ]
        let lang = langMap[identifier] ?? "en"

        openaiTranscriber.start(apiKey: apiKey, model: model, language: lang) { [weak self] result in
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
                        let recordingFormat = AVAudioFormat(
                            commonFormat: .pcmFormatInt16,
                            sampleRate: 16000,
                            channels: 1,
                            interleaved: false
                        )!
                        inputNode.removeTap(onBus: 0)
                        inputNode.installTap(onBus: 0, bufferSize: 1600, format: recordingFormat) {
                            [weak self] buffer, _ in
                            guard let self = self,
                                  let channelData = buffer.int16ChannelData else { return }
                            let frameLength = Int(buffer.frameLength)
                            let data = Data(bytes: channelData.pointee, count: frameLength * 2)
                            self.openaiTranscriber.appendAudio(data)
                        }
                        self.audioEngine.prepare()
                        try self.audioEngine.start()
                        print("[SpeechRecognizer] OpenAI mic capture started")
                        completion(.success(()))
                    } catch {
                        print("[SpeechRecognizer] OpenAI mic setup failed: \(error)")
                        completion(.failure(error))
                    }
                } else {
                    print("[SpeechRecognizer] OpenAI glasses PCM mode ready")
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

        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) {
            [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()
    }

    private func stopRecognition(emitFinal: Bool) {
        if activeBackend == .openai {
            if emitFinal {
                emitTranscript(lastRecognizedText, isFinal: true)
            }
            openaiTranscriber.stop()
            if audioEngine.isRunning {
                audioEngine.stop()
            }
            audioEngine.inputNode.removeTap(onBus: 0)
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
        } else {
            lastEmittedText = normalized
        }

        DispatchQueue.main.async {
            let hasSink = BluetoothManager.shared.blueSpeechSink != nil
            if !hasSink {
                print("[SpeechRecognizer] WARNING: blueSpeechSink is nil — transcript will be lost")
            }
            BluetoothManager.shared.blueSpeechSink?([
                "script": normalized,
                "isFinal": isFinal
            ])
        }
    }

    private func emitError(_ message: String) {
        DispatchQueue.main.async {
            BluetoothManager.shared.blueSpeechSink?([
                "script": self.lastRecognizedText,
                "isFinal": true,
                "error": message
            ])
        }
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

    private func cleanupRecognition(deactivateSession: Bool) {
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        audioEngine.inputNode.removeTap(onBus: 0)

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
            print("Error stop audio session: \(error.localizedDescription)")
        }
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
