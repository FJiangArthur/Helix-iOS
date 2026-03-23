import Foundation

enum RealtimeMode {
    case transcriptionOnly
    case conversation
}

class OpenAIRealtimeTranscriber: NSObject, URLSessionWebSocketDelegate {

    enum TranscriberError: Error, LocalizedError {
        case missingApiKey
        case connectionFailed(String)
        case authenticationFailed

        var errorDescription: String? {
            switch self {
            case .missingApiKey: return "OpenAI API key is required for realtime transcription"
            case .connectionFailed(let msg): return "WebSocket connection failed: \(msg)"
            case .authenticationFailed: return "OpenAI API key is invalid or expired"
            }
        }
    }

    var onTranscript: ((String, Bool) -> Void)?
    var onTranscriptWithId: ((String, Bool, String?) -> Void)?
    var onResponse: ((String, Bool) -> Void)?
    var onError: ((String) -> Void)?
    var onAudioOutput: ((Data) -> Void)?
    var onAudioOutputDone: (() -> Void)?

    var isActive: Bool { webSocketTask != nil }

    private var webSocketTask: URLSessionWebSocketTask?
    private var urlSession: URLSession?
    private var audioBuffer = Data()
    private var sendTimer: Timer?
    private var pingTimer: Timer?
    private var isConnected = false
    private var retryCount = 0
    private let maxRetries = 2
    private var apiKey: String = ""
    private var model: String = "gpt-4o-mini-transcribe"
    private var language: String = "en"
    private var mode: RealtimeMode = .transcriptionOnly
    private var voice: String = "alloy"
    private var systemInstructions: String = ""
    private var lastRecognizedText = ""
    private var currentTranscriptItemID: String?
    private var currentTranscriptBuffer = ""
    private var pendingCompletion: ((Result<Void, Error>) -> Void)?
    private var connectTimeoutWork: DispatchWorkItem?
    private var lastDisconnectMessage: String?
    private var isStopping = false
    /// Stale-partial detection: tracks consecutive identical transcription emissions
    /// to detect when the OpenAI API stops making progress and needs a reconnect.
    private var lastEmittedPartialText = ""
    private var stalePartialCount = 0
    private static let stalePartialThreshold = 25  // reconnect after 25 identical partials (~2.5s at 100ms intervals)

    private let sendIntervalMs: Double = 100
    private let pingIntervalSeconds: TimeInterval = 10
    private let targetSampleRate = 24000
    private let sourceSampleRate = 16000

    private func resolvedLanguageCode() -> String {
        let languageMap: [String: String] = [
            "en": "en", "zh": "zh", "ja": "ja", "ko": "ko",
            "es": "es", "ru": "ru", "fr": "fr", "de": "de",
        ]
        return languageMap[language] ?? "en"
    }

    private func sessionConfigEvent(for resolvedLang: String) -> [String: Any] {
        switch mode {
        case .transcriptionOnly:
            return [
                "type": "transcription_session.update",
                "session": [
                    "input_audio_format": "pcm16",
                    "input_audio_transcription": [
                        "model": model,
                        "language": resolvedLang,
                    ],
                    "turn_detection": [
                        "type": "server_vad",
                        "threshold": 0.5,
                        "prefix_padding_ms": 300,
                        "silence_duration_ms": 500,
                    ],
                ],
            ]
        case .conversation:
            return [
                "type": "session.update",
                "session": [
                    "modalities": ["text", "audio"],
                    "voice": voice,
                    "output_audio_format": "pcm16",
                    "instructions": systemInstructions,
                    "input_audio_format": "pcm16",
                    "input_audio_transcription": [
                        "model": model,
                        "language": resolvedLang,
                    ],
                    "turn_detection": [
                        "type": "server_vad",
                        "threshold": 0.5,
                        "prefix_padding_ms": 300,
                        "silence_duration_ms": 800,
                    ],
                ],
            ]
        }
    }

    func start(
        apiKey: String,
        model: String,
        language: String,
        mode: RealtimeMode = .transcriptionOnly,
        systemPrompt: String = "",
        voice: String = "alloy",
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        guard !apiKey.isEmpty else {
            completion(.failure(TranscriberError.missingApiKey))
            return
        }

        self.apiKey = apiKey
        self.model = model
        self.language = language
        self.mode = mode
        self.voice = voice
        self.systemInstructions = systemPrompt
        self.retryCount = 0
        self.lastRecognizedText = ""
        self.currentTranscriptItemID = nil
        self.currentTranscriptBuffer = ""
        self.audioBuffer = Data()
        self.isStopping = false
        self.lastEmittedPartialText = ""
        self.stalePartialCount = 0

        connect(completion: completion)
    }

    func appendAudio(_ pcmData: Data) {
        guard isConnected else { return }
        audioBuffer.append(pcmData)
    }

    func stop() {
        isStopping = true
        sendTimer?.invalidate()
        sendTimer = nil
        pingTimer?.invalidate()
        pingTimer = nil
        let hadBufferedAudio = !audioBuffer.isEmpty
        flushAudioBuffer()
        if hadBufferedAudio {
            sendEvent(["type": "input_audio_buffer.commit"])
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.disconnect()
        }
    }

    // MARK: - URLSessionWebSocketDelegate

    func urlSession(
        _ session: URLSession,
        webSocketTask: URLSessionWebSocketTask,
        didOpenWithProtocol protocol: String?
    ) {
        NSLog("[OpenAITranscriber] WebSocket opened")
        connectTimeoutWork?.cancel()
        connectTimeoutWork = nil

        isConnected = true
        lastDisconnectMessage = nil
        sendSessionConfig()
        startSendTimer()
        startPingTimer()
        receiveMessage()

        let completion = pendingCompletion
        pendingCompletion = nil
        completion?(.success(()))
    }

    func urlSession(
        _ session: URLSession,
        webSocketTask: URLSessionWebSocketTask,
        didCloseWith closeCode: URLSessionWebSocketTask.CloseCode,
        reason: Data?
    ) {
        let reasonStr = reason.flatMap { String(data: $0, encoding: .utf8) } ?? "none"
        NSLog("[OpenAITranscriber] WebSocket closed: code=\(closeCode.rawValue), reason=\(reasonStr)")
        handleDisconnect(
            error: TranscriberError.connectionFailed(
                "Closed with code \(closeCode.rawValue), reason: \(reasonStr)"
            )
        )
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        guard let error = error else { return }
        let nsError = error as NSError
        print(
            "[OpenAITranscriber] Session error: \(error.localizedDescription) " +
            "(domain=\(nsError.domain), code=\(nsError.code))"
        )

        if let completion = pendingCompletion {
            connectTimeoutWork?.cancel()
            connectTimeoutWork = nil
            pendingCompletion = nil
            isConnected = false
            completion(.failure(error))
            return
        }

        handleDisconnect(error: error)
    }

    // MARK: - Connection

    private func realtimeSessionModel(for transcriptionModel: String) -> String {
        switch transcriptionModel {
        case "gpt-4o-transcribe":
            return "gpt-4o-realtime-preview"
        default:
            return "gpt-4o-mini-realtime-preview"
        }
    }

    private func connect(completion: ((Result<Void, Error>) -> Void)? = nil) {
        let sessionModel = realtimeSessionModel(for: model)
        let urlString: String
        switch mode {
        case .transcriptionOnly:
            urlString = "wss://api.openai.com/v1/realtime?intent=transcription"
        case .conversation:
            urlString = "wss://api.openai.com/v1/realtime?model=\(sessionModel)"
        }
        guard let url = URL(string: urlString) else {
            completion?(.failure(TranscriberError.connectionFailed("Invalid URL")))
            return
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("realtime=v1", forHTTPHeaderField: "OpenAI-Beta")
        request.timeoutInterval = 30

        pendingCompletion = completion

        let session = URLSession(
            configuration: .default,
            delegate: self,
            delegateQueue: .main
        )
        self.urlSession = session
        let task = session.webSocketTask(with: request)
        self.webSocketTask = task
        task.resume()

        let timeout = DispatchWorkItem { [weak self] in
            guard let self = self, let completion = self.pendingCompletion else { return }
            self.pendingCompletion = nil
            self.disconnect()
            NSLog("[OpenAITranscriber] Connection timed out")
            completion(.failure(TranscriberError.connectionFailed("Connection timed out")))
        }
        connectTimeoutWork = timeout
        DispatchQueue.main.asyncAfter(deadline: .now() + 15, execute: timeout)

        NSLog("[OpenAITranscriber] Connecting mode=\(mode), session=\(sessionModel)...")
    }

    private func sendSessionConfig() {
        let resolvedLang = resolvedLanguageCode()
        sendEvent(sessionConfigEvent(for: resolvedLang))
        switch mode {
        case .transcriptionOnly:
            NSLog("[OpenAITranscriber] Transcription config sent, language=\(resolvedLang)")
        case .conversation:
            NSLog("[OpenAITranscriber] Conversation config sent, language=\(resolvedLang)")
        }
    }

    private func disconnect() {
        connectTimeoutWork?.cancel()
        connectTimeoutWork = nil
        sendTimer?.invalidate()
        sendTimer = nil
        pingTimer?.invalidate()
        pingTimer = nil
        isConnected = false
        pendingCompletion = nil
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
        urlSession?.invalidateAndCancel()
        urlSession = nil
        isStopping = false
    }

    /// Tear down the current WebSocket and reconnect to recover from stale
    /// transcription state. Preserves the audio buffer so incoming PCM data
    /// is not lost during the brief reconnect window.
    private func reconnectSession() {
        NSLog("[OpenAITranscriber] Reconnecting session to recover from stale transcription")
        let savedAudio = audioBuffer  // preserve in-flight audio
        disconnect()

        // Reset transcript state for the new session
        lastRecognizedText = ""
        currentTranscriptItemID = nil
        currentTranscriptBuffer = ""
        lastEmittedPartialText = ""
        stalePartialCount = 0

        connect { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success:
                // Re-inject any audio that arrived during reconnect
                if !savedAudio.isEmpty {
                    self.audioBuffer.append(savedAudio)
                }
                NSLog("[OpenAITranscriber] Reconnect succeeded")
            case .failure(let error):
                NSLog("[OpenAITranscriber] Reconnect failed: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.onError?("Transcription reconnect failed: \(error.localizedDescription)")
                }
            }
        }
    }

    private func startSendTimer() {
        sendTimer?.invalidate()
        sendTimer = Timer.scheduledTimer(
            withTimeInterval: sendIntervalMs / 1000.0,
            repeats: true
        ) { [weak self] _ in
            self?.flushAudioBuffer()
        }
    }

    private func startPingTimer() {
        pingTimer?.invalidate()
        pingTimer = Timer.scheduledTimer(withTimeInterval: pingIntervalSeconds, repeats: true) {
            [weak self] _ in
            self?.sendPing()
        }
    }

    private func sendPing() {
        guard isConnected, let task = webSocketTask else { return }
        task.sendPing { [weak self] error in
            guard let self else { return }
            if let error {
                NSLog("[OpenAITranscriber] Ping failed: \(error.localizedDescription)")
                self.handleDisconnect(error: error)
            }
        }
    }

    private func flushAudioBuffer() {
        guard !audioBuffer.isEmpty, isConnected else { return }

        let chunk = audioBuffer
        audioBuffer = Data()

        let resampled = AudioResampler.resample(
            pcm16Data: chunk,
            fromRate: sourceSampleRate,
            toRate: targetSampleRate
        )

        let base64Audio = resampled.base64EncodedString()
        sendEvent([
            "type": "input_audio_buffer.append",
            "audio": base64Audio,
        ])
    }

    private func sendEvent(_ event: [String: Any]) {
        let eventType = event["type"] as? String ?? ""
        guard let task = webSocketTask,
              isConnected
              || eventType == "transcription_session.update"
              || eventType == "session.update"
        else { return }
        do {
            let data = try JSONSerialization.data(withJSONObject: event)
            let message = URLSessionWebSocketTask.Message.string(String(data: data, encoding: .utf8)!)
            task.send(message) { error in
                if let error = error {
                    NSLog("[OpenAITranscriber] Send error: \(error.localizedDescription)")
                }
            }
        } catch {
            NSLog("[OpenAITranscriber] JSON serialization error: \(error)")
        }
    }

    private func receiveMessage() {
        webSocketTask?.receive { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    self.handleMessage(text)
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) {
                        self.handleMessage(text)
                    }
                @unknown default:
                    break
                }
                self.receiveMessage()

            case .failure(let error):
                NSLog("[OpenAITranscriber] Receive error: \(error.localizedDescription)")
                self.handleDisconnect(error: error)
            }
        }
    }

    private func handleMessage(_ text: String) {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String else {
            return
        }

        switch type {
        case "conversation.item.input_audio_transcription.delta":
            if let delta = json["delta"] as? String, !delta.isEmpty {
                let itemID = json["item_id"] as? String
                if itemID != currentTranscriptItemID {
                    currentTranscriptItemID = itemID
                    currentTranscriptBuffer = ""
                }
                currentTranscriptBuffer += delta
                lastRecognizedText = currentTranscriptBuffer

                // Stale-partial detection: if the OpenAI API sends the same
                // accumulated transcript text repeatedly, it has stalled.
                // Force a reconnect to recover audio processing.
                let trimmed = currentTranscriptBuffer
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed == lastEmittedPartialText {
                    stalePartialCount += 1
                    if stalePartialCount >= Self.stalePartialThreshold {
                        NSLog("[OpenAITranscriber] Stale partial detected (\(stalePartialCount)x), reconnecting")
                        stalePartialCount = 0
                        // Finalize current text then reconnect
                        let text = lastRecognizedText
                        DispatchQueue.main.async {
                            self.onTranscript?(text, true)
                        }
                        reconnectSession()
                        return
                    }
                } else {
                    lastEmittedPartialText = trimmed
                    stalePartialCount = 0
                }

                DispatchQueue.main.async {
                    self.onTranscript?(self.currentTranscriptBuffer, false)
                }
            }

        case "conversation.item.input_audio_transcription.completed":
            if let transcript = json["transcript"] as? String, !transcript.isEmpty {
                let itemId = json["item_id"] as? String
                currentTranscriptItemID = nil
                currentTranscriptBuffer = ""
                lastRecognizedText = transcript
                DispatchQueue.main.async {
                    self.onTranscript?(transcript, true)
                    self.onTranscriptWithId?(transcript, true, itemId)
                }
            }

        case "response.text.delta":
            if let delta = json["delta"] as? String, !delta.isEmpty {
                DispatchQueue.main.async {
                    self.onResponse?(delta, false)
                }
            }

        case "response.text.done":
            DispatchQueue.main.async {
                self.onResponse?("", true)
            }

        case "response.audio.delta":
            if let delta = json["delta"] as? String,
               let audioData = Data(base64Encoded: delta) {
                DispatchQueue.main.async { [weak self] in
                    self?.onAudioOutput?(audioData)
                }
            }

        case "response.audio.done":
            DispatchQueue.main.async { [weak self] in
                self?.onAudioOutputDone?()
            }

        case "error":
            let errorMsg = extractError(json)
            NSLog("[OpenAITranscriber] API error: \(errorMsg)")
            if isStopping && errorMsg.lowercased().contains("buffer too small") {
                NSLog("[OpenAITranscriber] Ignoring shutdown buffer commit error")
                return
            }
            if errorMsg.contains("401") || errorMsg.lowercased().contains("auth") {
                DispatchQueue.main.async {
                    self.onError?("OpenAI API key is invalid or expired")
                }
                disconnect()
            } else {
                DispatchQueue.main.async {
                    self.onError?(errorMsg)
                }
            }

        case "transcription_session.created", "transcription_session.updated",
             "session.created", "session.updated":
            NSLog("[OpenAITranscriber] Session event: \(type)")

        default:
            break
        }
    }

    private func handleDisconnect(error: Error) {
        guard isConnected else { return }
        guard !isStopping else {
            isConnected = false
            sendTimer?.invalidate()
            sendTimer = nil
            pingTimer?.invalidate()
            pingTimer = nil
            resetConnectionArtifacts()
            return
        }

        // Flush partial response buffer on disconnect in conversation mode
        if mode == .conversation {
            DispatchQueue.main.async {
                self.onResponse?("", true)
            }
        }

        isConnected = false
        sendTimer?.invalidate()
        sendTimer = nil
        pingTimer?.invalidate()
        pingTimer = nil
        lastDisconnectMessage = error.localizedDescription
        resetConnectionArtifacts()

        let nsError = error as NSError
        if nsError.code == 401 || nsError.code == 403 {
            DispatchQueue.main.async {
                self.onError?("OpenAI API key is invalid or expired")
            }
            return
        }

        if retryCount < maxRetries {
            retryCount += 1
            print(
                "[OpenAITranscriber] Reconnecting (attempt \(retryCount)/\(maxRetries)) " +
                "after error: \(error.localizedDescription)"
            )
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(retryCount)) { [weak self] in
                self?.connect()
            }
        } else {
            NSLog("[OpenAITranscriber] Max retries reached, giving up")
            DispatchQueue.main.async {
                let detail = self.lastDisconnectMessage ?? error.localizedDescription
                self.onError?(
                    "WebSocket connection lost after \(self.maxRetries + 1) attempts. \(detail)"
                )
            }
        }
    }

    private func resetConnectionArtifacts() {
        connectTimeoutWork?.cancel()
        connectTimeoutWork = nil
        pendingCompletion = nil
        webSocketTask = nil
        urlSession?.invalidateAndCancel()
        urlSession = nil
    }

    private func extractError(_ json: [String: Any]) -> String {
        if let error = json["error"] as? [String: Any] {
            return (error["message"] as? String)
                ?? (error["type"] as? String)
                ?? "Unknown API error"
        }
        return "Unknown API error"
    }
}

extension OpenAIRealtimeTranscriber {
    func debugConfigureForTesting(
        mode: RealtimeMode,
        language: String = "en",
        systemPrompt: String = ""
    ) {
        self.mode = mode
        self.language = language
        self.systemInstructions = systemPrompt
    }

    func debugSessionConfigEvent() -> [String: Any] {
        sessionConfigEvent(for: resolvedLanguageCode())
    }

    func debugHandleMessage(_ text: String) {
        handleMessage(text)
    }
}
