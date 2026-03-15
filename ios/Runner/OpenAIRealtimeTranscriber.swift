import Foundation

class OpenAIRealtimeTranscriber: NSObject {

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
    var onError: ((String) -> Void)?

    private var webSocketTask: URLSessionWebSocketTask?
    private var urlSession: URLSession?
    private var audioBuffer = Data()
    private var sendTimer: Timer?
    private var isConnected = false
    private var retryCount = 0
    private let maxRetries = 1
    private var apiKey: String = ""
    private var model: String = "gpt-4o-mini-transcribe"
    private var language: String = "en"
    private var lastRecognizedText = ""

    private let sendIntervalMs: Double = 100
    private let targetSampleRate = 24000
    private let sourceSampleRate = 16000

    func start(
        apiKey: String,
        model: String,
        language: String,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        guard !apiKey.isEmpty else {
            completion(.failure(TranscriberError.missingApiKey))
            return
        }

        self.apiKey = apiKey
        self.model = model
        self.language = language
        self.retryCount = 0
        self.lastRecognizedText = ""
        self.audioBuffer = Data()

        connect(completion: completion)
    }

    func appendAudio(_ pcmData: Data) {
        guard isConnected else { return }
        audioBuffer.append(pcmData)
    }

    func stop() {
        sendTimer?.invalidate()
        sendTimer = nil
        flushAudioBuffer()
        sendEvent(["type": "input_audio_buffer.commit"])

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.disconnect()
        }
    }

    private func connect(completion: ((Result<Void, Error>) -> Void)? = nil) {
        let urlString = "wss://api.openai.com/v1/realtime?intent=transcription&model=\(model)"
        guard let url = URL(string: urlString) else {
            completion?(.failure(TranscriberError.connectionFailed("Invalid URL")))
            return
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("realtime=v1", forHTTPHeaderField: "OpenAI-Beta")
        request.timeoutInterval = 30

        let session = URLSession(configuration: .default, delegate: nil, delegateQueue: .main)
        self.urlSession = session
        let task = session.webSocketTask(with: request)
        self.webSocketTask = task
        task.resume()

        receiveMessage()

        let languageMap: [String: String] = [
            "en": "en", "zh": "zh", "ja": "ja", "ko": "ko",
            "es": "es", "ru": "ru", "fr": "fr", "de": "de",
        ]
        let resolvedLang = languageMap[language] ?? "en"

        sendEvent([
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
        ])

        isConnected = true
        startSendTimer()
        completion?(.success(()))
        print("[OpenAITranscriber] Connected to \(model), language=\(resolvedLang)")
    }

    private func disconnect() {
        sendTimer?.invalidate()
        sendTimer = nil
        isConnected = false
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
        urlSession?.invalidateAndCancel()
        urlSession = nil
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
        guard let task = webSocketTask else { return }
        do {
            let data = try JSONSerialization.data(withJSONObject: event)
            let message = URLSessionWebSocketTask.Message.string(String(data: data, encoding: .utf8)!)
            task.send(message) { error in
                if let error = error {
                    print("[OpenAITranscriber] Send error: \(error.localizedDescription)")
                }
            }
        } catch {
            print("[OpenAITranscriber] JSON serialization error: \(error)")
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
                print("[OpenAITranscriber] Receive error: \(error.localizedDescription)")
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
                lastRecognizedText = delta
                DispatchQueue.main.async {
                    self.onTranscript?(delta, false)
                }
            }

        case "conversation.item.input_audio_transcription.completed":
            if let transcript = json["transcript"] as? String, !transcript.isEmpty {
                lastRecognizedText = transcript
                DispatchQueue.main.async {
                    self.onTranscript?(transcript, true)
                }
            }

        case "error":
            let errorMsg = extractError(json)
            print("[OpenAITranscriber] API error: \(errorMsg)")
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

        case "transcription_session.created", "transcription_session.updated":
            print("[OpenAITranscriber] Session event: \(type)")

        default:
            break
        }
    }

    private func handleDisconnect(error: Error) {
        isConnected = false
        sendTimer?.invalidate()
        sendTimer = nil

        let nsError = error as NSError
        if nsError.code == 401 || nsError.code == 403 {
            DispatchQueue.main.async {
                self.onError?("OpenAI API key is invalid or expired")
            }
            return
        }

        if retryCount < maxRetries {
            retryCount += 1
            print("[OpenAITranscriber] Reconnecting (attempt \(retryCount))...")
            connect()
        } else {
            print("[OpenAITranscriber] Max retries reached, giving up")
            DispatchQueue.main.async {
                self.onError?("WebSocket connection lost after \(self.maxRetries + 1) attempts")
            }
        }
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
