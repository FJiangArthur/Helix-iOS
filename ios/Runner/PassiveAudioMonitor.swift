import AVFoundation
import Speech
import Flutter

class PassiveAudioMonitor: NSObject, SFSpeechRecognizerDelegate {
    static let shared = PassiveAudioMonitor()

    enum MonitorState: String {
        case idle, speechDetected, recognizing, silence
    }

    // Public
    private(set) var state: MonitorState = .idle
    private(set) var isActive = false
    private(set) var segmentCount = 0
    var eventSink: FlutterEventSink?

    // Audio
    private var audioEngine = AVAudioEngine()
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?

    // Config
    private var vadThreshold: Float = 0.01 // ~-40dB
    private let silenceTimeout: TimeInterval = 3.0
    private var silenceTimer: Timer?

    // MARK: - Lifecycle

    func start(language: String, vadThreshold: Float) {
        guard !isActive else { return }
        self.vadThreshold = vadThreshold

        // Setup speech recognizer with on-device requirement
        let locale = Locale(identifier: mapLanguageCode(language))
        speechRecognizer = SFSpeechRecognizer(locale: locale)
        speechRecognizer?.delegate = self

        guard speechRecognizer?.isAvailable == true,
              speechRecognizer?.supportsOnDeviceRecognition == true else {
            emitError("On-device speech recognition not available for \(language)")
            return
        }

        // Configure audio session
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .measurement,
                options: [.mixWithOthers, .allowBluetooth, .duckOthers])
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            emitError("Failed to configure audio session: \(error)")
            return
        }

        // Install audio tap for VAD
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 4096, format: recordingFormat) { [weak self] buffer, _ in
            guard let self = self else { return }
            let rms = self.computeRMS(buffer)

            switch self.state {
            case .idle:
                if rms > self.vadThreshold {
                    DispatchQueue.main.async {
                        self.state = .speechDetected
                        self.startOnDeviceRecognition(format: recordingFormat)
                    }
                }
            case .speechDetected, .recognizing:
                // Append to recognition request
                self.recognitionRequest?.append(buffer)
                if rms > self.vadThreshold {
                    DispatchQueue.main.async { self.resetSilenceTimer() }
                }
            case .silence:
                // Still appending during silence countdown
                self.recognitionRequest?.append(buffer)
                if rms > self.vadThreshold {
                    DispatchQueue.main.async {
                        self.state = .recognizing
                        self.resetSilenceTimer()
                    }
                }
            }
        }

        audioEngine.prepare()
        do {
            try audioEngine.start()
            isActive = true
            state = .idle
        } catch {
            emitError("Failed to start audio engine: \(error)")
        }
    }

    func stop() {
        isActive = false
        silenceTimer?.invalidate()
        silenceTimer = nil
        stopRecognition()
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        state = .idle
    }

    func pause() {
        guard isActive else { return }
        silenceTimer?.invalidate()
        stopRecognition()
        audioEngine.pause()
        state = .idle
    }

    func resume() {
        guard isActive else { return }
        do {
            try audioEngine.start()
            state = .idle
        } catch {
            emitError("Failed to resume audio engine: \(error)")
        }
    }

    // MARK: - On-Device Recognition

    private func startOnDeviceRecognition(format: AVAudioFormat) {
        stopRecognition() // Clean up any prior

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let request = recognitionRequest else { return }

        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = true
        // For iOS 16+: request.addsPunctuation = true
        if #available(iOS 16, *) {
            request.addsPunctuation = true
        }

        state = .recognizing
        resetSilenceTimer()

        recognitionTask = speechRecognizer?.recognitionTask(with: request) { [weak self] result, error in
            guard let self = self else { return }

            if let result = result {
                let text = result.bestTranscription.formattedString
                let isFinal = result.isFinal

                self.emitTranscript(text: text, isFinal: isFinal)

                if isFinal {
                    self.segmentCount += 1
                    self.finishRecognition()
                }
            }

            if let error = error {
                // Recognition ended (timeout, etc.) — finish and return to idle
                let nsError = error as NSError
                // Code 203 = "no speech detected", 209 = "retry" — normal, not errors
                if nsError.domain == "kAFAssistantErrorDomain" && (nsError.code == 203 || nsError.code == 209) {
                    self.finishRecognition()
                } else {
                    self.emitError("Recognition error: \(error.localizedDescription)")
                    self.finishRecognition()
                }
            }
        }
    }

    private func stopRecognition() {
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil
    }

    private func finishRecognition() {
        stopRecognition()
        state = .idle
        silenceTimer?.invalidate()
        silenceTimer = nil
    }

    // MARK: - VAD

    private func computeRMS(_ buffer: AVAudioPCMBuffer) -> Float {
        guard let channelData = buffer.floatChannelData else { return 0 }
        let channelDataValue = channelData.pointee
        let count = Int(buffer.frameLength)
        guard count > 0 else { return 0 }

        var sum: Float = 0
        for i in 0..<count {
            sum += channelDataValue[i] * channelDataValue[i]
        }
        return sqrt(sum / Float(count))
    }

    private func resetSilenceTimer() {
        silenceTimer?.invalidate()
        silenceTimer = Timer.scheduledTimer(withTimeInterval: silenceTimeout, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            self.state = .silence
            // After silence timeout, finish the current recognition segment
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                if self.state == .silence {
                    self.finishRecognition()
                }
            }
        }
    }

    // MARK: - Event Emission

    private func emitTranscript(text: String, isFinal: Bool) {
        let event: [String: Any] = [
            "script": text,
            "isFinal": isFinal,
            "timestampMs": Int(Date().timeIntervalSince1970 * 1000),
            "language": speechRecognizer?.locale.identifier ?? "",
        ]
        DispatchQueue.main.async {
            self.eventSink?(event)
        }
    }

    private func emitError(_ message: String) {
        DispatchQueue.main.async {
            self.eventSink?(FlutterError(code: "PASSIVE_AUDIO", message: message, details: nil))
        }
    }

    // MARK: - Helpers

    private func mapLanguageCode(_ code: String) -> String {
        switch code.lowercased() {
        case "zh": return "zh-CN"
        case "en": return "en-US"
        case "ja": return "ja-JP"
        case "ko": return "ko-KR"
        case "es": return "es-ES"
        case "ru": return "ru-RU"
        default: return "en-US"
        }
    }

    // MARK: - SFSpeechRecognizerDelegate

    func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        if !available && isActive {
            emitError("On-device speech recognition became unavailable")
        }
    }
}

// MARK: - Flutter Event Stream Handler

class PassiveAudioEventHandler: NSObject, FlutterStreamHandler {
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        PassiveAudioMonitor.shared.eventSink = events
        return nil
    }
    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        PassiveAudioMonitor.shared.eventSink = nil
        return nil
    }
}
