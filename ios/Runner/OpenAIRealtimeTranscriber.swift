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
    var onUsage: (([String: Any]) -> Void)?

    var isActive: Bool { webSocketTask != nil }

    private var webSocketTask: URLSessionWebSocketTask?
    private var urlSession: URLSession?
    private var audioBuffer = Data()
    private let audioQueue = DispatchQueue(label: "com.helix.openai.audio")
    private var sendTimerSource: DispatchSourceTimer?
    private var pingTimer: Timer?
    private var isConnected = false
    private var retryCount = 0
    private let maxRetries = 2
    private var apiKey: String = ""
    private var model: String = "gpt-4o-mini-transcribe"
    private var language: String = "en"
    private var mode: RealtimeMode = .transcriptionOnly
    var inputAlready24kHz = false
    private var voice: String = "alloy"
    private var systemInstructions: String = ""
    private var lastRecognizedText = ""
    private var currentTranscriptItemID: String?
    private var currentTranscriptBuffer = ""
    private var pendingCompletion: ((Result<Void, Error>) -> Void)?
    private var connectTimeoutWork: DispatchWorkItem?
    private var lastDisconnectMessage: String?
    private var isStopping = false
    private var sessionConfigured = false
    private var delayedDisconnectWork: DispatchWorkItem?
    private var sessionCounter: Int = 0
    private var transcriptionFailureTimestamps: [Date] = []
    /// VAD threshold override. Mapped from user's vadSensitivity setting.
    var vadThreshold: Double = 0.35
    /// Transcription prompt for accuracy hints.
    var transcriptionPrompt: String = ""
    /// Stale-partial detection: tracks consecutive identical transcription emissions
    /// to detect when the OpenAI API stops making progress and needs a reconnect.
    private var lastEmittedPartialText = ""
    private var stalePartialCount = 0
    private static let stalePartialThreshold = 25  // reconnect after 25 identical partials (~2.5s at 100ms intervals)

    private let sendIntervalMs: Double = 100
    private let pingIntervalSeconds: TimeInterval = 10
    private let targetSampleRate = 24000
    private let sourceSampleRate = 16000

    private func debugLog(_ message: @autoclosure () -> String) {
        #if DEBUG
        NSLog("%@", message())
        #endif
    }

    private func warningLog(_ message: @autoclosure () -> String) {
        NSLog("%@", message())
    }

    private func resolvedLanguageCode() -> String {
        let languageMap: [String: String] = [
            "en": "en", "zh": "zh", "ja": "ja", "ko": "ko",
            "es": "es", "ru": "ru", "fr": "fr", "de": "de",
        ]
        return languageMap[language] ?? "en"
    }

    private func sessionConfigEvent(for resolvedLang: String) -> [String: Any] {
        var transcriptionConfig: [String: Any] = [
            "model": model,
            "language": resolvedLang,
        ]
        if !transcriptionPrompt.isEmpty {
            transcriptionConfig["prompt"] = transcriptionPrompt
        }

        switch mode {
        case .transcriptionOnly:
            return [
                "type": "transcription_session.update",
                "session": [
                    "input_audio_format": "pcm16",
                    "input_audio_transcription": transcriptionConfig,
                    "turn_detection": [
                        "type": "server_vad",
                        "threshold": vadThreshold,
                        "prefix_padding_ms": 500,
                        "silence_duration_ms": 1000,
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
                    "input_audio_transcription": transcriptionConfig,
                    "turn_detection": [
                        "type": "server_vad",
                        "threshold": vadThreshold,
                        "prefix_padding_ms": 500,
                        "silence_duration_ms": 1200,
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
        // Cancel any pending delayed disconnect from a previous stop()
        delayedDisconnectWork?.cancel()
        delayedDisconnectWork = nil
        sessionCounter += 1

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
        self.appendAudioLogCount = 0
        self.flushLogCount = 0
        self.messageLogCount = 0
        self.transcriptionFailureTimestamps = []

        connect(completion: completion)
    }

    private var appendAudioLogCount = 0
    func appendAudio(_ pcmData: Data) {
        audioQueue.async {
            self.audioBuffer.append(pcmData)
            let maxBufferSize = 5 * 24000 * 2
            if self.audioBuffer.count > maxBufferSize {
                let overflow = self.audioBuffer.count - maxBufferSize
                self.audioBuffer.removeFirst(overflow)
            }
        }
        appendAudioLogCount += 1
        if appendAudioLogCount == 1 || appendAudioLogCount % 50 == 0 {
            warningLog("[OpenAITranscriber] appendAudio #\(appendAudioLogCount)")
        }
    }

    func stop() {
        isStopping = true
        sendTimerSource?.cancel()
        sendTimerSource = nil
        pingTimer?.invalidate()
        pingTimer = nil

        // Synchronously drain buffer
        var remaining = Data()
        audioQueue.sync {
            remaining = self.audioBuffer
            self.audioBuffer = Data()
        }
        if !remaining.isEmpty {
            let dataToSend: Data
            if inputAlready24kHz {
                dataToSend = remaining
            } else {
                dataToSend = AudioResampler.resample(
                    pcm16Data: remaining,
                    fromRate: sourceSampleRate,
                    toRate: targetSampleRate
                )
            }
            let base64 = dataToSend.base64EncodedString()
            sendEvent(["type": "input_audio_buffer.append", "audio": base64])
            sendEvent(["type": "input_audio_buffer.commit"])
        }

        let currentSession = sessionCounter
        let work = DispatchWorkItem { [weak self] in
            guard let self = self, self.sessionCounter == currentSession else { return }
            self.disconnect()
        }
        delayedDisconnectWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: work)
    }

    // MARK: - URLSessionWebSocketDelegate

    func urlSession(
        _ session: URLSession,
        webSocketTask: URLSessionWebSocketTask,
        didOpenWithProtocol protocol: String?
    ) {
        warningLog("[OpenAITranscriber] WebSocket opened")
        connectTimeoutWork?.cancel()
        connectTimeoutWork = nil

        isConnected = true
        retryCount = 0
        sessionConfigured = false  // Wait for server confirmation before flushing
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
        debugLog(
            "[OpenAITranscriber] WebSocket closed: code=\(closeCode.rawValue), "
            + "reasonChars=\(reasonStr.count)"
        )
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
        warningLog(
            "[OpenAITranscriber] Session error domain=\(nsError.domain) "
            + "code=\(nsError.code)"
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
            self.warningLog("[OpenAITranscriber] Connection timed out")
            completion(.failure(TranscriberError.connectionFailed("Connection timed out")))
        }
        connectTimeoutWork = timeout
        DispatchQueue.main.asyncAfter(deadline: .now() + 15, execute: timeout)

        warningLog("[OpenAITranscriber] Connecting mode=\(mode), session=\(sessionModel), url=\(urlString)")
    }

    private func sendSessionConfig() {
        let resolvedLang = resolvedLanguageCode()
        sendEvent(sessionConfigEvent(for: resolvedLang))
        switch mode {
        case .transcriptionOnly:
            warningLog("[OpenAITranscriber] Transcription config sent, model=\(model), language=\(resolvedLang)")
        case .conversation:
            warningLog("[OpenAITranscriber] Conversation config sent, model=\(model), language=\(resolvedLang)")
        }
    }

    private func disconnect() {
        connectTimeoutWork?.cancel()
        connectTimeoutWork = nil
        sendTimerSource?.cancel()
        sendTimerSource = nil
        pingTimer?.invalidate()
        pingTimer = nil
        isConnected = false
        sessionConfigured = false
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
        debugLog("[OpenAITranscriber] Reconnecting session to recover from stale transcription")
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
                self.debugLog("[OpenAITranscriber] Reconnect succeeded")
            case .failure(let error):
                self.warningLog(
                    "[OpenAITranscriber] Reconnect failed: \(error.localizedDescription)"
                )
                DispatchQueue.main.async {
                    self.onError?("Transcription reconnect failed: \(error.localizedDescription)")
                }
            }
        }
    }

    private func startSendTimer() {
        sendTimerSource?.cancel()
        sendTimerSource = nil

        let timer = DispatchSource.makeTimerSource(queue: audioQueue)
        timer.schedule(deadline: .now() + sendIntervalMs / 1000.0,
                       repeating: sendIntervalMs / 1000.0)
        timer.setEventHandler { [weak self] in
            self?.flushAudioBuffer()
        }
        sendTimerSource = timer
        timer.resume()
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
                self.warningLog("[OpenAITranscriber] Ping failed: \(error.localizedDescription)")
                self.handleDisconnect(error: error)
            }
        }
    }

    private var flushLogCount = 0
    private func flushAudioBuffer() {
        var chunk = Data()
        audioQueue.sync {
            guard !self.audioBuffer.isEmpty else { return }
            chunk = self.audioBuffer
            self.audioBuffer = Data()
        }

        guard !chunk.isEmpty, isConnected, sessionConfigured else {
            if !chunk.isEmpty {
                // Put it back if we can't send yet
                audioQueue.async { self.audioBuffer = chunk + self.audioBuffer }
            }
            return
        }

        let dataToSend: Data
        if inputAlready24kHz {
            dataToSend = chunk
        } else {
            dataToSend = AudioResampler.resample(
                pcm16Data: chunk,
                fromRate: sourceSampleRate,
                toRate: targetSampleRate
            )
        }

        flushLogCount += 1
        if flushLogCount == 1 || flushLogCount % 50 == 0 {
            warningLog("[OpenAITranscriber] flushAudio #\(flushLogCount) chunkBytes=\(chunk.count) sendBytes=\(dataToSend.count)")
        }

        let base64Audio = dataToSend.base64EncodedString()
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
                    self.warningLog("[OpenAITranscriber] Send error: \(error.localizedDescription)")
                }
            }
        } catch {
            warningLog("[OpenAITranscriber] JSON serialization error: \(error)")
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
                self.warningLog("[OpenAITranscriber] Receive error: \(error.localizedDescription)")
                self.handleDisconnect(error: error)
            }
        }
    }

    private var messageLogCount = 0
    private func handleMessage(_ text: String) {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String else {
            warningLog("[OpenAITranscriber] Failed to parse message: \(text.prefix(200))")
            return
        }

        messageLogCount += 1
        if messageLogCount <= 5 || type.contains("error") || type.contains("transcription") {
            warningLog("[OpenAITranscriber] Message #\(messageLogCount): \(type)")
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
                        self.debugLog(
                            "[OpenAITranscriber] Stale partial detected "
                            + "(\(self.stalePartialCount)x), reconnecting"
                        )
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
            emitUsageIfPresent(json, operationType: "transcription")

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
            emitUsageIfPresent(json, operationType: "response")

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
            warningLog("[OpenAITranscriber] API error received")
            if isStopping && errorMsg.lowercased().contains("buffer too small") {
                debugLog("[OpenAITranscriber] Ignoring shutdown buffer commit error")
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

        case "conversation.item.input_audio_transcription.failed":
            let errorInfo = json["error"] as? [String: Any]
            let errorMsg = errorInfo?["message"] as? String ?? "unknown"
            let errorCode = errorInfo?["code"] as? String ?? "unknown"
            let errorType = errorInfo?["type"] as? String ?? "unknown"
            warningLog("[OpenAITranscriber] TRANSCRIPTION FAILED: code=\(errorCode) type=\(errorType) message=\(errorMsg)")

            // Clear the server's audio buffer to recover
            sendEvent(["type": "input_audio_buffer.clear"])

            // Track failures and reconnect if 3+ in 30 seconds
            let now = Date()
            transcriptionFailureTimestamps.append(now)
            transcriptionFailureTimestamps = transcriptionFailureTimestamps.filter {
                now.timeIntervalSince($0) < 30
            }
            if transcriptionFailureTimestamps.count >= 3 {
                warningLog("[OpenAITranscriber] 3+ transcription failures in 30s, reconnecting")
                transcriptionFailureTimestamps.removeAll()
                reconnectSession()
                return
            }

            DispatchQueue.main.async {
                self.onError?("Transcription failed: \(errorMsg)")
            }

        case "transcription_session.created", "transcription_session.updated",
             "session.created", "session.updated":
            warningLog("[OpenAITranscriber] Session event: \(type)")
            if type.contains("updated") || type.contains("created") {
                sessionConfigured = true
            }

        default:
            break
        }
    }

    private func handleDisconnect(error: Error) {
        guard isConnected else { return }
        guard !isStopping else {
            isConnected = false
            sendTimerSource?.cancel()
            sendTimerSource = nil
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
        sendTimerSource?.cancel()
        sendTimerSource = nil
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
            warningLog(
                "[OpenAITranscriber] Reconnecting (attempt \(retryCount)/\(maxRetries))"
            )
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(retryCount)) { [weak self] in
                self?.connect()
            }
        } else {
            warningLog("[OpenAITranscriber] Max retries reached, giving up")
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

    private func emitUsageIfPresent(_ json: [String: Any], operationType: String) {
        guard let usage = json["usage"] as? [String: Any] else { return }
        var payload = usage
        payload["operationType"] = operationType
        payload["model"] = model
        DispatchQueue.main.async { [weak self] in
            self?.onUsage?(payload)
        }
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
