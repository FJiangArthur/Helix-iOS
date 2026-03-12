//
//  SpeechStreamRecognizer.swift
//  Runner
//
//  Created by edy on 2024/4/16.
//
import AVFoundation
import Speech

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

    enum RecognizerError: Error {
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
    }

    private init() {
        requestPermissionsIfNeeded()
    }

    private func requestPermissionsIfNeeded() {
        if #available(iOS 13.0, *) {
            Task {
                _ = await SFSpeechRecognizer.hasAuthorizationToRecognize()
                _ = await AVAudioSession.sharedInstance().hasPermissionToRecord()
            }
        }
    }

    func startRecognition(identifier: String, source: String = "glasses") {
        stopRecognition(emitFinal: false)

        lastRecognizedText = ""
        lastEmittedText = ""
        didEmitFinalResult = false
        activeInputSource = source.lowercased() == "microphone"
            ? .microphone
            : .glassesPcm

        let localeIdentifier = languageDic[identifier] ?? "en-US"
        recognizer = SFSpeechRecognizer(locale: Locale(identifier: localeIdentifier))

        guard let recognizer = recognizer else {
            emitError(RecognizerError.nilRecognizer.message)
            return
        }

        guard recognizer.isAvailable else {
            emitError(RecognizerError.recognizerIsUnavailable.message)
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
        } catch {
            emitError("Error setting up audio session: \(error.localizedDescription)")
            return
        }

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            emitError("Failed to create recognition request")
            return
        }

        recognitionRequest.shouldReportPartialResults = true
        recognitionRequest.requiresOnDeviceRecognition = false

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
                self.emitError("Speech recognition failed: \(error.localizedDescription)")
                self.emitTranscript(self.lastRecognizedText, isFinal: true)
                self.cleanupRecognition(deactivateSession: true)
            }
        }

        if activeInputSource == .microphone {
            startMicrophoneCapture()
        }
    }

    func stopRecognition() {
        stopRecognition(emitFinal: true)
    }

    func appendPCMData(_ pcmData: Data) {
        guard activeInputSource == .glassesPcm else { return }
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

    private func startMicrophoneCapture() {
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) {
            [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }

        audioEngine.prepare()

        do {
            try audioEngine.start()
        } catch {
            emitError("Failed to start microphone capture: \(error.localizedDescription)")
            cleanupRecognition(deactivateSession: true)
        }
    }

    private func stopRecognition(emitFinal: Bool) {
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
