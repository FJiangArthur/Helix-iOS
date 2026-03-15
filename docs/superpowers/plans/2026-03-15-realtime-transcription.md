# Realtime Transcription Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace broken SFSpeechRecognizer-only transcription with a multi-backend system (OpenAI Realtime WebSocket, Apple Cloud, Apple On-Device) and add microphone source selection.

**Architecture:** Native Swift handles all audio capture and transcription. `SpeechStreamRecognizer` routes to the selected backend. All backends emit through the same `blueSpeechSink` EventChannel, so the entire Dart pipeline (ConversationListeningSession → ConversationEngine → UI) remains unchanged. Settings are read from `SettingsManager` in Dart and forwarded via the `startEvenAI` platform method.

**Tech Stack:** Swift (URLSessionWebSocketTask, AVFoundation, Speech), Dart/Flutter (platform channels, SharedPreferences, FlutterSecureStorage)

**Spec:** `docs/superpowers/specs/2026-03-15-realtime-transcription-design.md`

---

## File Map

| File | Action | Responsibility |
|------|--------|---------------|
| `ios/Runner/AudioResampler.swift` | Create | PCM16 sample rate conversion (16kHz → 24kHz) |
| `ios/Runner/OpenAIRealtimeTranscriber.swift` | Create | WebSocket client for OpenAI Realtime transcription API |
| `ios/Runner/SpeechStreamRecognizer.swift` | Modify | Add `TranscriptionBackend` enum, backend routing, delegate `appendPCMData` |
| `ios/Runner/AppDelegate.swift` | Modify | Parse new `startEvenAI` params (backend, apiKey, model) |
| `lib/services/settings_manager.dart` | Modify | Add transcription settings fields + persistence |
| `lib/services/conversation_listening_session.dart` | Modify | Read transcription settings, forward to native `startEvenAI` |
| `lib/screens/settings_screen.dart` | Modify | Add Transcription settings section |
| `lib/screens/home_screen.dart` | Modify | Apply `preferredMicSource` override |

---

## Chunk 1: Audio Resampler + OpenAI WebSocket Client (Native Swift)

### Task 1: AudioResampler

**Files:**
- Create: `ios/Runner/AudioResampler.swift`

- [ ] **Step 1: Create AudioResampler.swift**

```swift
// ios/Runner/AudioResampler.swift
import Foundation

/// Resamples PCM16 (signed 16-bit little-endian) audio between sample rates.
struct AudioResampler {

    /// Resample PCM16 data from one sample rate to another using linear interpolation.
    /// - Parameters:
    ///   - pcm16Data: Raw PCM16 bytes (signed 16-bit LE, mono)
    ///   - fromRate: Source sample rate (e.g. 16000)
    ///   - toRate: Target sample rate (e.g. 24000)
    /// - Returns: Resampled PCM16 data at the target rate
    static func resample(pcm16Data: Data, fromRate: Int, toRate: Int) -> Data {
        if fromRate == toRate { return pcm16Data }

        let inputSamples = pcm16Data.withUnsafeBytes {
            Array($0.bindMemory(to: Int16.self))
        }
        guard !inputSamples.isEmpty else { return Data() }

        let ratio = Double(fromRate) / Double(toRate)
        let outputCount = Int(Double(inputSamples.count) / ratio)
        var output = [Int16](repeating: 0, count: outputCount)

        for i in 0..<outputCount {
            let srcIndex = Double(i) * ratio
            let srcIndexInt = Int(srcIndex)
            let frac = srcIndex - Double(srcIndexInt)

            let s0 = inputSamples[min(srcIndexInt, inputSamples.count - 1)]
            let s1 = inputSamples[min(srcIndexInt + 1, inputSamples.count - 1)]

            let interpolated = Double(s0) * (1.0 - frac) + Double(s1) * frac
            output[i] = Int16(clamping: Int(interpolated.rounded()))
        }

        return output.withUnsafeBufferPointer { Data(buffer: $0) }
    }
}
```

- [ ] **Step 2: Verify it compiles**

Run: Build the iOS project in Xcode or via `flutter build ios --no-codesign 2>&1 | tail -5`

- [ ] **Step 3: Commit**

```bash
git add ios/Runner/AudioResampler.swift
git commit -m "feat(transcription): add AudioResampler for PCM16 sample rate conversion"
```

---

### Task 2: OpenAIRealtimeTranscriber

**Files:**
- Create: `ios/Runner/OpenAIRealtimeTranscriber.swift`

- [ ] **Step 1: Create OpenAIRealtimeTranscriber.swift**

```swift
// ios/Runner/OpenAIRealtimeTranscriber.swift
import Foundation

/// Manages a WebSocket connection to the OpenAI Realtime Transcription API.
/// Accepts PCM16 audio at 16kHz, resamples to 24kHz, and streams to the API.
/// Transcription results are delivered via the `onTranscript` callback.
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

    /// Called on transcription results. Parameters: (text, isFinal)
    var onTranscript: ((String, Bool) -> Void)?
    /// Called on errors.
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

    private let sendIntervalMs: Double = 100 // Send audio every 100ms
    private let targetSampleRate = 24000
    private let sourceSampleRate = 16000

    // MARK: - Public API

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
        // Accumulate raw 16kHz PCM; the send timer flushes periodically
        audioBuffer.append(pcmData)
    }

    func stop() {
        sendTimer?.invalidate()
        sendTimer = nil
        // Flush remaining audio
        flushAudioBuffer()
        // Send commit to signal end of audio
        sendEvent(["type": "input_audio_buffer.commit"])

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.disconnect()
        }
    }

    // MARK: - Connection

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

        // Start listening for messages
        receiveMessage()

        // Configure session after connection
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

    // MARK: - Audio Sending

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

        // Resample 16kHz → 24kHz
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

    // MARK: - WebSocket Communication

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
                // Continue listening
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
        // HTTP 401 = auth failure, don't retry
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
```

- [ ] **Step 2: Verify it compiles**

Run: `flutter build ios --no-codesign 2>&1 | tail -5`

- [ ] **Step 3: Commit**

```bash
git add ios/Runner/OpenAIRealtimeTranscriber.swift
git commit -m "feat(transcription): add OpenAI Realtime WebSocket transcriber"
```

---

## Chunk 2: Backend Routing in SpeechStreamRecognizer + AppDelegate

### Task 3: Add TranscriptionBackend enum and routing to SpeechStreamRecognizer

**Files:**
- Modify: `ios/Runner/SpeechStreamRecognizer.swift`

- [ ] **Step 1: Add TranscriptionBackend enum and openaiTranscriber property**

At the top of the `SpeechStreamRecognizer` class (after `private init() {}`), add:

```swift
enum TranscriptionBackend: String {
    case openai
    case appleCloud
    case appleOnDevice
}
```

Add property inside the class:

```swift
private var activeBackend: TranscriptionBackend = .appleCloud
private let openaiTranscriber = OpenAIRealtimeTranscriber()
```

- [ ] **Step 2: Update startRecognition signature**

Replace the existing `startRecognition` method signature and body. The new signature adds `backend`, `apiKey`, and `model` parameters. Route to OpenAI or Apple depending on backend:

```swift
func startRecognition(
    identifier: String,
    source: String = "glasses",
    backend: TranscriptionBackend = .appleCloud,
    apiKey: String? = nil,
    model: String? = nil,
    completion: @escaping (Result<Void, Error>) -> Void
) {
    print("[SpeechRecognizer] startRecognition — identifier=\(identifier), source=\(source), backend=\(backend.rawValue)")
    stopRecognition(emitFinal: false)
    activeBackend = backend
    pendingStartCompletion = completion

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
```

- [ ] **Step 3: Add startOpenAIRecognition method**

Add this new method to `SpeechStreamRecognizer`:

```swift
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

    // Wire up callbacks
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

    // Map language code
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
                // Set up audio session and mic capture for OpenAI path
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
                // Glasses PCM path: appendPCMData will forward to openaiTranscriber
                print("[SpeechRecognizer] OpenAI glasses PCM mode ready")
                completion(.success(()))
            }
        case .failure(let error):
            completion(.failure(error))
        }
    }
}
```

- [ ] **Step 4: Update appendPCMData to delegate by backend**

Replace the existing `appendPCMData` method body to route by active backend:

```swift
func appendPCMData(_ pcmData: Data) {
    guard activeInputSource == .glassesPcm else { return }

    if activeBackend == .openai {
        openaiTranscriber.appendAudio(pcmData)
        return
    }

    // Existing Apple Speech path
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
```

- [ ] **Step 5: Update stopRecognition to handle OpenAI backend**

In `stopRecognition(emitFinal:)`, add OpenAI cleanup before the existing code:

```swift
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

    // Existing Apple path
    if emitFinal {
        emitTranscript(lastRecognizedText, isFinal: true)
    }

    recognitionRequest?.endAudio()
    recognitionTask?.cancel()
    cleanupRecognition(deactivateSession: true)
}
```

- [ ] **Step 6: Update beginRecognition for on-device support**

In `beginRecognition`, after the line `recognitionRequest.shouldReportPartialResults = true`, update the `requiresOnDeviceRecognition` line:

```swift
recognitionRequest.shouldReportPartialResults = true
recognitionRequest.requiresOnDeviceRecognition = (activeBackend == .appleOnDevice)
```

- [ ] **Step 7: Verify it compiles**

Run: `flutter build ios --no-codesign 2>&1 | tail -10`

- [ ] **Step 8: Commit**

```bash
git add ios/Runner/SpeechStreamRecognizer.swift
git commit -m "feat(transcription): add multi-backend routing to SpeechStreamRecognizer"
```

---

### Task 4: Update AppDelegate to parse new startEvenAI parameters

**Files:**
- Modify: `ios/Runner/AppDelegate.swift:46-72`

- [ ] **Step 1: Update the startEvenAI case**

Replace the `case "startEvenAI":` block in `AppDelegate.swift` with:

```swift
case "startEvenAI":
    let args = call.arguments as? [String: Any] ?? [:]
    let lang = args["language"] as? String ?? "EN"
    let source = args["source"] as? String ?? "glasses"
    let backendStr = args["backend"] as? String ?? "appleCloud"
    let apiKey = args["apiKey"] as? String
    let model = args["model"] as? String

    let backend: SpeechStreamRecognizer.TranscriptionBackend
    switch backendStr {
    case "openai":
        backend = .openai
    case "appleOnDevice":
        backend = .appleOnDevice
    default:
        backend = .appleCloud
    }

    SpeechStreamRecognizer.shared.startRecognition(
        identifier: lang,
        source: source,
        backend: backend,
        apiKey: apiKey,
        model: model
    ) { startResult in
        switch startResult {
        case .success:
            result("Started speech recognition (\(backendStr))")
        case .failure(let error):
            result(
                FlutterError(
                    code: "SpeechStartFailed",
                    message: error.localizedDescription,
                    details: nil
                )
            )
        }
    }
```

Note: The `TranscriptionBackend` enum is nested inside `SpeechStreamRecognizer`, so reference it as `SpeechStreamRecognizer.TranscriptionBackend`. Alternatively, move the enum to file scope in `SpeechStreamRecognizer.swift`.

- [ ] **Step 2: Verify it compiles**

Run: `flutter build ios --no-codesign 2>&1 | tail -10`

- [ ] **Step 3: Commit**

```bash
git add ios/Runner/AppDelegate.swift
git commit -m "feat(transcription): parse backend/apiKey/model in startEvenAI handler"
```

---

## Chunk 3: Dart Settings + Platform Channel Wiring

### Task 5: Add transcription settings to SettingsManager

**Files:**
- Modify: `lib/services/settings_manager.dart:72-80` (Audio Settings section)
- Modify: `lib/services/settings_manager.dart:146-149` (initialize)
- Modify: `lib/services/settings_manager.dart:196-198` (save)

- [ ] **Step 1: Add settings fields**

In the `// Audio Settings` section (after line 80), add:

```dart
  // ---------------------------------------------------------------------------
  // Transcription Settings
  // ---------------------------------------------------------------------------

  /// Transcription backend: 'openai', 'appleCloud', 'appleOnDevice'.
  String transcriptionBackend = 'openai';

  /// Model for OpenAI transcription.
  String transcriptionModel = 'gpt-4o-mini-transcribe';

  /// Preferred mic source: 'auto', 'glasses', 'phone'.
  String preferredMicSource = 'auto';
```

- [ ] **Step 2: Add initialization**

In `initialize()`, after the Audio section (after line 149), add:

```dart
    // Transcription
    transcriptionBackend =
        prefs.getString('transcriptionBackend') ?? 'openai';
    transcriptionModel =
        prefs.getString('transcriptionModel') ?? 'gpt-4o-mini-transcribe';
    preferredMicSource =
        prefs.getString('preferredMicSource') ?? 'auto';
```

- [ ] **Step 3: Add persistence**

In `save()`, after the Audio section (after line 198), add:

```dart
    // Transcription
    await prefs.setString('transcriptionBackend', transcriptionBackend);
    await prefs.setString('transcriptionModel', transcriptionModel);
    await prefs.setString('preferredMicSource', preferredMicSource);
```

- [ ] **Step 4: Run analyze**

Run: `flutter analyze lib/services/settings_manager.dart`
Expected: No issues found

- [ ] **Step 5: Commit**

```bash
git add lib/services/settings_manager.dart
git commit -m "feat(settings): add transcription backend, model, and mic source settings"
```

---

### Task 6: Update ConversationListeningSession to forward transcription settings

**Files:**
- Modify: `lib/services/conversation_listening_session.dart:109-114`

- [ ] **Step 1: Update the startEvenAI invocation**

Replace the `_invokeMethod('startEvenAI', ...)` block in `startSession()` with:

```dart
    final langCode = _getLanguageCode();
    final sourceStr =
        source == TranscriptSource.glasses ? 'glasses' : 'microphone';
    final settings = SettingsManager.instance;
    String? apiKey;
    if (settings.transcriptionBackend == 'openai') {
      apiKey = await settings.getApiKey('openai');
    }

    appLogger.d('[ListeningSession] Calling startEvenAI — '
        'lang=$langCode, source=$sourceStr, '
        'backend=${settings.transcriptionBackend}, '
        'model=${settings.transcriptionModel}');
    try {
      await _invokeMethod('startEvenAI', {
        'language': langCode,
        'source': sourceStr,
        'backend': settings.transcriptionBackend,
        'apiKey': apiKey,
        'model': settings.transcriptionModel,
      });
      _isRunning = true;
      appLogger.d('[ListeningSession] startEvenAI succeeded — session is running');
    }
```

This replaces from the `final langCode =` line through the `_isRunning = true;` line. Keep the existing `on PlatformException catch` and `catch` blocks.

- [ ] **Step 2: Run analyze**

Run: `flutter analyze lib/services/conversation_listening_session.dart`
Expected: No issues found

- [ ] **Step 3: Run existing tests**

Run: `flutter test test/services/conversation_listening_session_test.dart`
Expected: All tests pass (the test uses a mock invokeMethod, so the new params are just extra map entries)

- [ ] **Step 4: Commit**

```bash
git add lib/services/conversation_listening_session.dart
git commit -m "feat(transcription): forward backend/apiKey/model settings in startEvenAI"
```

---

### Task 7: Apply preferredMicSource in HomeScreen

**Files:**
- Modify: `lib/screens/home_screen.dart:200-209`

- [ ] **Step 1: Update _startRecording mic source logic**

Replace the `final glassesConnected = BleManager.isBothConnected();` line and the `if (glassesConnected)` block with:

```dart
    final settings = SettingsManager.instance;
    final useGlasses = switch (settings.preferredMicSource) {
      'glasses' => BleManager.isBothConnected(),
      'phone' => false,
      _ => BleManager.isBothConnected(), // 'auto'
    };

    try {
      if (useGlasses) {
        await EvenAI.get.toStartEvenAIByOS();
      } else {
        await ConversationListeningSession.instance.startSession(
          source: TranscriptSource.phone,
        );
      }
```

- [ ] **Step 2: Run analyze**

Run: `flutter analyze lib/screens/home_screen.dart`
Expected: No issues found

- [ ] **Step 3: Commit**

```bash
git add lib/screens/home_screen.dart
git commit -m "feat(transcription): apply preferredMicSource setting in HomeScreen"
```

---

## Chunk 4: Settings UI

### Task 8: Add Transcription section to SettingsScreen

**Files:**
- Modify: `lib/screens/settings_screen.dart`

- [ ] **Step 1: Add _buildTranscriptionSection method**

Add this method to `_SettingsScreenState`. Find the pattern from existing `_buildSection` calls (line ~300). Add a new `_buildSection('Transcription', Icons.record_voice_over, [...])` call in the `build` method, between the 'Conversation' and 'Assistant Defaults' sections.

In the `build` method, after the Conversation section (`_buildSection('Conversation', Icons.chat, [...])`), add:

```dart
            _buildSection('Transcription', Icons.record_voice_over, [
              ListTile(
                title: const Text('Backend'),
                subtitle: Text(_transcriptionBackendLabel(settings.transcriptionBackend)),
                trailing: DropdownButton<String>(
                  value: settings.transcriptionBackend,
                  dropdownColor: const Color(0xFF1A1F35),
                  underline: const SizedBox.shrink(),
                  items: const [
                    DropdownMenuItem(value: 'openai', child: Text('OpenAI Realtime')),
                    DropdownMenuItem(value: 'appleCloud', child: Text('Apple Cloud')),
                    DropdownMenuItem(value: 'appleOnDevice', child: Text('Apple On-Device')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      settings.update((s) => s.transcriptionBackend = value);
                    }
                  },
                ),
              ),
              if (settings.transcriptionBackend == 'openai')
                ListTile(
                  title: const Text('Model'),
                  trailing: DropdownButton<String>(
                    value: settings.transcriptionModel,
                    dropdownColor: const Color(0xFF1A1F35),
                    underline: const SizedBox.shrink(),
                    items: const [
                      DropdownMenuItem(
                        value: 'gpt-4o-mini-transcribe',
                        child: Text('gpt-4o-mini-transcribe'),
                      ),
                      DropdownMenuItem(
                        value: 'gpt-4o-transcribe',
                        child: Text('gpt-4o-transcribe'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        settings.update((s) => s.transcriptionModel = value);
                      }
                    },
                  ),
                ),
              ListTile(
                title: const Text('Microphone'),
                subtitle: Text(_micSourceLabel(settings.preferredMicSource)),
                trailing: DropdownButton<String>(
                  value: settings.preferredMicSource,
                  dropdownColor: const Color(0xFF1A1F35),
                  underline: const SizedBox.shrink(),
                  items: const [
                    DropdownMenuItem(value: 'auto', child: Text('Auto')),
                    DropdownMenuItem(value: 'glasses', child: Text('Glasses')),
                    DropdownMenuItem(value: 'phone', child: Text('Phone')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      settings.update((s) => s.preferredMicSource = value);
                    }
                  },
                ),
              ),
            ]),
```

- [ ] **Step 2: Add helper label methods**

Add these methods to `_SettingsScreenState`:

```dart
  String _transcriptionBackendLabel(String backend) {
    switch (backend) {
      case 'openai':
        return 'Low-latency WebSocket transcription (requires OpenAI key)';
      case 'appleCloud':
        return 'Apple cloud speech recognition (free, ~1min limit)';
      case 'appleOnDevice':
        return 'On-device recognition (works offline, lower accuracy)';
      default:
        return backend;
    }
  }

  String _micSourceLabel(String source) {
    switch (source) {
      case 'auto':
        return 'Uses glasses mic when connected, phone mic otherwise';
      case 'glasses':
        return 'Always use glasses microphone';
      case 'phone':
        return 'Always use phone microphone';
      default:
        return source;
    }
  }
```

- [ ] **Step 3: Run analyze**

Run: `flutter analyze lib/screens/settings_screen.dart`
Expected: No issues found

- [ ] **Step 4: Commit**

```bash
git add lib/screens/settings_screen.dart
git commit -m "feat(settings): add Transcription section with backend, model, and mic pickers"
```

---

## Chunk 5: Verification

### Task 9: Run all tests and full analysis

- [ ] **Step 1: Run flutter analyze on entire project**

Run: `flutter analyze`
Expected: No issues (or only pre-existing warnings)

- [ ] **Step 2: Run all tests**

Run: `flutter test`
Expected: All tests pass

- [ ] **Step 3: Verify iOS build**

Run: `flutter build ios --no-codesign 2>&1 | tail -20`
Expected: Build succeeds

- [ ] **Step 4: Final commit if any fixups needed**

```bash
git add -A
git commit -m "fix: address lint/build issues from transcription feature"
```
