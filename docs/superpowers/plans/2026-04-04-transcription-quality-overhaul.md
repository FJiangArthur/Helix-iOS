# Transcription Quality Overhaul Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix transcription quality (wrong/garbled/missing words, delays, sentence fragments) by overhauling the audio pipeline, VAD config, reconnect reliability, and product settings.

**Architecture:** Replace linear interpolation resampler with AVAudioConverter, add direct 48→24kHz phone mic path for Realtime and native 48kHz batch path for A/B testing, fix VAD parameters, harden WebSocket session lifecycle, and wire missing settings end-to-end.

**Tech Stack:** Swift (iOS native), Dart/Flutter, AVFoundation, OpenAI Realtime WebSocket API, OpenAI Whisper batch REST API

---

## File Structure

| File | Responsibility | Action |
|------|---------------|--------|
| `ios/Runner/AudioResampler.swift` | High-quality PCM resampling via AVAudioConverter | Rewrite |
| `ios/Runner/OpenAIRealtimeTranscriber.swift` | WebSocket transcription: VAD, session lifecycle, audio buffering, timer | Modify |
| `ios/Runner/SpeechStreamRecognizer.swift` | Mic tap routing, direct 24kHz path, BLE VAD gating | Modify |
| `ios/Runner/WhisperBatchTranscriber.swift` | Batch API: transcription prompt support | Modify |
| `ios/Runner/AppDelegate.swift` | Platform channel: pass vadSensitivity, transcriptionPrompt | Modify |
| `lib/services/settings_manager.dart` | New settings: transcriptionTransport, transcriptionPrompt, default model | Modify |
| `lib/services/conversation_listening_session.dart` | Route batch transport, pass new settings | Modify |
| `lib/screens/settings_screen.dart` | Transport toggle UI, prompt editor | Modify |

---

### Task 1: Replace AudioResampler with AVAudioConverter

**Files:**
- Rewrite: `ios/Runner/AudioResampler.swift`

- [ ] **Step 1: Rewrite AudioResampler.swift**

Replace the linear interpolation implementation with AVAudioConverter:

```swift
import AVFoundation

struct AudioResampler {
    static func resample(pcm16Data: Data, fromRate: Int, toRate: Int) -> Data {
        if fromRate == toRate { return pcm16Data }
        guard !pcm16Data.isEmpty else { return Data() }

        guard let inputFormat = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: Double(fromRate),
            channels: 1,
            interleaved: false
        ),
        let outputFormat = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: Double(toRate),
            channels: 1,
            interleaved: false
        ) else {
            return pcm16Data
        }

        guard let converter = AVAudioConverter(from: inputFormat, to: outputFormat) else {
            return pcm16Data
        }

        let inputFrameCount = pcm16Data.count / MemoryLayout<Int16>.size
        guard let inputBuffer = AVAudioPCMBuffer(
            pcmFormat: inputFormat,
            frameCapacity: AVAudioFrameCount(inputFrameCount)
        ) else {
            return pcm16Data
        }

        inputBuffer.frameLength = AVAudioFrameCount(inputFrameCount)
        pcm16Data.withUnsafeBytes { rawBuffer in
            guard let src = rawBuffer.baseAddress?.assumingMemoryBound(to: Int16.self) else { return }
            inputBuffer.int16ChannelData?.pointee.initialize(from: src, count: inputFrameCount)
        }

        let outputFrameCapacity = AVAudioFrameCount(
            ceil(Double(inputFrameCount) * Double(toRate) / Double(fromRate))
        )
        guard let outputBuffer = AVAudioPCMBuffer(
            pcmFormat: outputFormat,
            frameCapacity: max(outputFrameCapacity, 1)
        ) else {
            return pcm16Data
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
            return inputBuffer
        }

        guard (status == .haveData || status == .inputRanDry),
              outputBuffer.frameLength > 0,
              let channelData = outputBuffer.int16ChannelData else {
            return pcm16Data
        }

        let byteCount = Int(outputBuffer.frameLength) * MemoryLayout<Int16>.size
        return Data(bytes: channelData.pointee, count: byteCount)
    }
}
```

- [ ] **Step 2: Build to verify compilation**

Run: `cd /Users/artjiang/develop/Helix-iOS && flutter build ios --simulator --no-codesign`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add ios/Runner/AudioResampler.swift
git commit -m "Replace linear interpolation resampler with AVAudioConverter"
```

---

### Task 2: Direct 48→24kHz phone mic path for OpenAI Realtime

**Files:**
- Modify: `ios/Runner/SpeechStreamRecognizer.swift`
- Modify: `ios/Runner/OpenAIRealtimeTranscriber.swift`

- [ ] **Step 1: Add inputAlready24kHz flag to OpenAIRealtimeTranscriber**

In `OpenAIRealtimeTranscriber.swift`, add a property and modify `flushAudioBuffer()`:

```swift
// Add property near line 45 (after `private var mode`)
var inputAlready24kHz = false
```

In `flushAudioBuffer()`, skip resampling when flag is set:

```swift
private func flushAudioBuffer() {
    guard !audioBuffer.isEmpty, isConnected else { return }

    let chunk = audioBuffer
    audioBuffer = Data()

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
```

- [ ] **Step 2: Add 24kHz output format and routing in SpeechStreamRecognizer**

In `SpeechStreamRecognizer.swift`, add a new format near the existing `openAIMicrophoneOutputFormat` (around line 88):

```swift
private let openAIMicrophoneOutputFormat24kHz = AVAudioFormat(
    commonFormat: .pcmFormatInt16,
    sampleRate: 24_000,
    channels: 1,
    interleaved: false
)!

private var openAIMicrophoneConverter24kHz: AVAudioConverter?
private var openAIMicrophoneInputFormat24kHz: AVAudioFormat?
```

Add a conversion method after `convertBufferToOpenAIInput`:

```swift
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
```

- [ ] **Step 3: Update the OpenAI mic tap to use 24kHz direct path**

In `_continueOpenAIRecognition()`, modify the mic tap callback (around line 536). Replace the existing `installTap` block:

```swift
inputNode.installTap(onBus: 0, bufferSize: 4096, format: recordingFormat) {
    [weak self] buffer, _ in
    guard let self = self,
          let data = self.convertBufferToOpenAI24kHz(buffer) else { return }
    self.openaiTranscriber.appendAudio(data)
}
self.openaiTranscriber.inputAlready24kHz = true
```

Note: `bufferSize` changed from `1600` to `4096` to avoid assumptions about hardware sample rate.

- [ ] **Step 4: Build to verify compilation**

Run: `cd /Users/artjiang/develop/Helix-iOS && flutter build ios --simulator --no-codesign`
Expected: BUILD SUCCEEDED

- [ ] **Step 5: Commit**

```bash
git add ios/Runner/SpeechStreamRecognizer.swift ios/Runner/OpenAIRealtimeTranscriber.swift
git commit -m "Add direct 48→24kHz phone mic path for OpenAI Realtime"
```

---

### Task 3: Add batch transport setting and routing

**Files:**
- Modify: `lib/services/settings_manager.dart`
- Modify: `lib/services/conversation_listening_session.dart`
- Modify: `lib/screens/settings_screen.dart`

- [ ] **Step 1: Add transcriptionTransport and transcriptionPrompt to SettingsManager**

In `settings_manager.dart`, add fields after `transcriptionModel` (around line 115):

```dart
  /// Transport mode for OpenAI transcription: '24kHz Realtime' or '48kHz Batch Proc'.
  String transcriptionTransport = '24kHz Realtime';

  /// Optional prompt for transcription accuracy (domain vocabulary, names, etc.).
  String transcriptionPrompt = '';
```

In the `_load` method (around line 328, after `whisperChunkDurationSec`):

```dart
    transcriptionTransport =
        prefs.getString('transcriptionTransport') ?? '24kHz Realtime';
    transcriptionPrompt = prefs.getString('transcriptionPrompt') ?? '';
```

In the `_save` method (around line 445, after `whisperChunkDurationSec`):

```dart
    await prefs.setString('transcriptionTransport', transcriptionTransport);
    await prefs.setString('transcriptionPrompt', transcriptionPrompt);
```

Also change the default model (line 115):

```dart
  String transcriptionModel = 'gpt-4o-transcribe';
```

And in `_load` (line 323-324):

```dart
    transcriptionModel =
        prefs.getString('transcriptionModel') ?? 'gpt-4o-transcribe';
```

- [ ] **Step 2: Route batch transport in ConversationListeningSession**

In `conversation_listening_session.dart`, modify the backend routing logic (around line 196-203). Replace the existing `isBatchApiModel`/`effectiveBackend` block:

```dart
      // Models that use the batch REST API (whisper path) regardless of
      // the selected backend setting.
      final isBatchApiModel =
          settings.transcriptionModel.contains('diarize') ||
          settings.transcriptionModel == 'whisper-1';
      // Route to batch when transport is "48kHz Batch Proc" and model supports it.
      final isBatchTransport =
          settings.transcriptionTransport == '48kHz Batch Proc' &&
          (settings.transcriptionModel == 'gpt-4o-transcribe' ||
           settings.transcriptionModel == 'gpt-4o-mini-transcribe');
      final effectiveBackend = (isBatchApiModel || isBatchTransport)
          ? 'whisper'
          : settings.transcriptionBackend;
```

Also pass the new settings in the platform channel call (around line 233-246). Add `transcriptionPrompt` and `vadSensitivity`:

```dart
      try {
        await _invokeMethod('startEvenAI', {
          'language': langCode,
          'source': sourceStr,
          'backend': effectiveBackend,
          'sessionMode': settings.openAISessionMode,
          'apiKey': apiKey,
          'model': settings.transcriptionModel,
          'systemPrompt': systemPrompt,
          'transcriptionPrompt': settings.transcriptionPrompt,
          'vadSensitivity': settings.vadSensitivity,
          if (voiceEnabled) 'voice': voiceName,
          if (effectiveBackend == 'whisper') ...{
            'enableDiarization': settings.enableDiarization,
            'whisperChunkDurationSec': settings.whisperChunkDurationSec,
          },
        });
```

- [ ] **Step 3: Add transport toggle and prompt editor to settings UI**

In `settings_screen.dart`, add the transport selector and prompt editor after the model dropdown (around line 537, after the model `onChanged` closing). Add inside the `_settings.transcriptionBackend == 'openai'` conditional block:

```dart
                if (_settings.transcriptionBackend == 'openai' &&
                    _settings.openAISessionMode == 'transcription')
                  ListTile(
                    title: const Text('Transport'),
                    trailing: DropdownButton<String>(
                      value: _settings.transcriptionTransport,
                      dropdownColor: const Color(0xFF1A1F35),
                      underline: const SizedBox.shrink(),
                      items: const [
                        DropdownMenuItem(
                          value: '24kHz Realtime',
                          child: Text('24kHz Realtime'),
                        ),
                        DropdownMenuItem(
                          value: '48kHz Batch Proc',
                          child: Text('48kHz Batch Proc'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          _settings.update(
                              (s) => s.transcriptionTransport = value);
                        }
                      },
                    ),
                  ),
                if (_settings.transcriptionBackend == 'openai')
                  ListTile(
                    title: const Text('Transcription Prompt'),
                    subtitle: Text(
                      _settings.transcriptionPrompt.isEmpty
                          ? 'None (tap to add vocabulary hints)'
                          : _settings.transcriptionPrompt.length > 50
                              ? '${_settings.transcriptionPrompt.substring(0, 50)}...'
                              : _settings.transcriptionPrompt,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                    trailing: TextButton(
                      onPressed: () => _showTranscriptionPromptDialog(),
                      child: const Text('Edit'),
                    ),
                  ),
```

Add the dialog method near the existing `_showRealtimePromptDialog` or similar methods:

```dart
  void _showTranscriptionPromptDialog() {
    final controller =
        TextEditingController(text: _settings.transcriptionPrompt);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1F35),
        title: const Text('Transcription Prompt'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Add vocabulary hints to improve accuracy. '
              'Include names, technical terms, or topics discussed.',
              style: TextStyle(color: Colors.white54, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'e.g. Names: Art, Helix. Topics: AI, smart glasses.',
                hintStyle: TextStyle(color: Colors.white24),
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              _settings
                  .update((s) => s.transcriptionPrompt = controller.text.trim());
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
```

- [ ] **Step 4: Run flutter analyze**

Run: `cd /Users/artjiang/develop/Helix-iOS && flutter analyze`
Expected: No errors

- [ ] **Step 5: Build to verify compilation**

Run: `cd /Users/artjiang/develop/Helix-iOS && flutter build ios --simulator --no-codesign`
Expected: BUILD SUCCEEDED

- [ ] **Step 6: Commit**

```bash
git add lib/services/settings_manager.dart lib/services/conversation_listening_session.dart lib/screens/settings_screen.dart
git commit -m "Add batch transport setting, transcription prompt, and default model change"
```

---

### Task 4: Update VAD parameters and wire vadSensitivity

**Files:**
- Modify: `ios/Runner/OpenAIRealtimeTranscriber.swift`
- Modify: `ios/Runner/SpeechStreamRecognizer.swift`
- Modify: `ios/Runner/AppDelegate.swift`

- [ ] **Step 1: Add vadThreshold property and update sessionConfigEvent in OpenAIRealtimeTranscriber**

In `OpenAIRealtimeTranscriber.swift`, add a property (near line 45):

```swift
/// VAD threshold override. Mapped from user's vadSensitivity setting.
var vadThreshold: Double = 0.35

/// Transcription prompt for accuracy hints.
var transcriptionPrompt: String = ""
```

Update `sessionConfigEvent()` to use the property and new defaults:

```swift
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
```

- [ ] **Step 2: Add vadSensitivity parameter to SpeechStreamRecognizer.startRecognition**

In `SpeechStreamRecognizer.swift`, add a parameter to `startRecognition()`:

```swift
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
)
```

Inside the body, before calling `startOpenAIRecognition`, set the transcriber's properties:

```swift
// Map vadSensitivity (0.0-1.0, higher=more sensitive) to threshold (0.2-0.6, lower=more sensitive)
openaiTranscriber.vadThreshold = 0.6 - (vadSensitivity * 0.4)
openaiTranscriber.transcriptionPrompt = transcriptionPrompt
```

Also pass `transcriptionPrompt` to `startWhisperRecognition` — add it as a parameter and set it before calling `whisperTranscriber.start()`:

```swift
whisperTranscriber.transcriptionPrompt = transcriptionPrompt
```

- [ ] **Step 3: Update AppDelegate to pass new parameters**

In `AppDelegate.swift`, extract the new parameters from the platform channel args (around line 53-68):

```swift
let vadSensitivity = args["vadSensitivity"] as? Double ?? 0.5
let transcriptionPrompt = args["transcriptionPrompt"] as? String ?? ""
```

Pass them to `startRecognition()` (around line 87-95):

```swift
recognizer.startRecognition(
    identifier: lang,
    source: source,
    backend: backend,
    apiKey: apiKey,
    model: model,
    realtimeConversation: realtimeConversation,
    systemPrompt: systemPrompt,
    voice: voice,
    vadSensitivity: vadSensitivity,
    transcriptionPrompt: transcriptionPrompt
) { startResult in
```

- [ ] **Step 4: Build to verify compilation**

Run: `cd /Users/artjiang/develop/Helix-iOS && flutter build ios --simulator --no-codesign`
Expected: BUILD SUCCEEDED

- [ ] **Step 5: Commit**

```bash
git add ios/Runner/OpenAIRealtimeTranscriber.swift ios/Runner/SpeechStreamRecognizer.swift ios/Runner/AppDelegate.swift
git commit -m "Update VAD parameters and wire vadSensitivity end-to-end"
```

---

### Task 5: Add transcription prompt to WhisperBatchTranscriber

**Files:**
- Modify: `ios/Runner/WhisperBatchTranscriber.swift`

- [ ] **Step 1: Add transcriptionPrompt property and wire to HTTP request**

In `WhisperBatchTranscriber.swift`, add a property (around line 49, after `apiKey`):

```swift
/// Optional transcription prompt for accuracy hints (domain vocabulary, names).
var transcriptionPrompt: String = ""
```

In `postToWhisper()`, add the prompt as a multipart field when non-empty (around line 267, after the temperature field):

```swift
if !transcriptionPrompt.isEmpty {
    body.appendMultipartField(name: "prompt", value: transcriptionPrompt, boundary: boundary)
}
```

- [ ] **Step 2: Build to verify compilation**

Run: `cd /Users/artjiang/develop/Helix-iOS && flutter build ios --simulator --no-codesign`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add ios/Runner/WhisperBatchTranscriber.swift
git commit -m "Add transcription prompt support to Whisper batch API"
```

---

### Task 6: Reconnect & session reliability fixes

**Files:**
- Modify: `ios/Runner/OpenAIRealtimeTranscriber.swift`

- [ ] **Step 1: Buffer audio during reconnect (remove isConnected guard from appendAudio)**

Replace the `appendAudio()` method:

```swift
func appendAudio(_ pcmData: Data) {
    audioBuffer.append(pcmData)
    // Cap buffer at ~5 seconds of 24kHz mono PCM16 (240KB) to prevent unbounded growth
    let maxBufferSize = 5 * 24000 * 2  // 240,000 bytes
    if audioBuffer.count > maxBufferSize {
        let overflow = audioBuffer.count - maxBufferSize
        audioBuffer.removeFirst(overflow)
    }
    appendAudioLogCount += 1
    if appendAudioLogCount == 1 || appendAudioLogCount % 50 == 0 {
        warningLog("[OpenAITranscriber] appendAudio #\(appendAudioLogCount) bufferBytes=\(audioBuffer.count) connected=\(isConnected)")
    }
}
```

- [ ] **Step 2: Gate audio flush on session configuration confirmation**

Add a property (near the other state properties around line 39):

```swift
private var sessionConfigured = false
```

Update `flushAudioBuffer()` to check the flag (modify the existing guard):

```swift
private func flushAudioBuffer() {
    guard !audioBuffer.isEmpty, isConnected, sessionConfigured else { return }
```

Set the flag to `false` on connect and `true` when session is confirmed. In `urlSession(_:webSocketTask:didOpenWithProtocol:)` (around line 203):

```swift
func urlSession(
    _ session: URLSession,
    webSocketTask: URLSessionWebSocketTask,
    didOpenWithProtocol protocol: String?
) {
    warningLog("[OpenAITranscriber] WebSocket opened")
    connectTimeoutWork?.cancel()
    connectTimeoutWork = nil

    isConnected = true
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
```

In `handleMessage()`, set the flag when session is confirmed (in the `transcription_session.created` etc. case around line 596):

```swift
case "transcription_session.created", "transcription_session.updated",
     "session.created", "session.updated":
    warningLog("[OpenAITranscriber] Session event: \(type)")
    if type.contains("updated") || type.contains("created") {
        sessionConfigured = true
    }
```

Also reset `sessionConfigured = false` in `disconnect()` (around line 330):

```swift
private func disconnect() {
    connectTimeoutWork?.cancel()
    connectTimeoutWork = nil
    sendTimer?.invalidate()
    sendTimer = nil
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
```

- [ ] **Step 3: Fix rapid start/stop race with cancellable delayed disconnect**

Add a property (near other state properties):

```swift
private var delayedDisconnectWork: DispatchWorkItem?
private var sessionCounter: Int = 0
```

Replace the `stop()` method:

```swift
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

    let currentSession = sessionCounter
    let work = DispatchWorkItem { [weak self] in
        guard let self = self, self.sessionCounter == currentSession else { return }
        self.disconnect()
    }
    delayedDisconnectWork = work
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: work)
}
```

In `start()`, cancel any pending delayed disconnect (add at the very beginning of `start()`, before the guard):

```swift
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
```

- [ ] **Step 4: Reset retry count on successful reconnect**

In `urlSession(_:webSocketTask:didOpenWithProtocol:)`, add after `isConnected = true`:

```swift
retryCount = 0
```

- [ ] **Step 5: Add recovery from transcription.failed**

Add a property for tracking failures:

```swift
private var transcriptionFailureTimestamps: [Date] = []
```

In `handleMessage()`, update the `conversation.item.input_audio_transcription.failed` case:

```swift
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
```

Reset the timestamps in `start()` (add alongside the other resets):

```swift
self.transcriptionFailureTimestamps = []
```

- [ ] **Step 6: Build to verify compilation**

Run: `cd /Users/artjiang/develop/Helix-iOS && flutter build ios --simulator --no-codesign`
Expected: BUILD SUCCEEDED

- [ ] **Step 7: Commit**

```bash
git add ios/Runner/OpenAIRealtimeTranscriber.swift
git commit -m "Fix reconnect audio loss, session config race, start/stop race, and failure recovery"
```

---

### Task 7: Move send timer off main thread

**Files:**
- Modify: `ios/Runner/OpenAIRealtimeTranscriber.swift`

- [ ] **Step 1: Replace Timer with DispatchSourceTimer on dedicated queue**

Add the queue and timer properties (replace the existing `sendTimer` declaration around line 37-38):

```swift
private let audioQueue = DispatchQueue(label: "com.helix.openai.audio")
private var sendTimerSource: DispatchSourceTimer?
```

Replace `startSendTimer()`:

```swift
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
```

Update all places that reference `sendTimer` to use `sendTimerSource`:

In `stop()`, replace `sendTimer?.invalidate()` / `sendTimer = nil` with:
```swift
sendTimerSource?.cancel()
sendTimerSource = nil
```

In `disconnect()`, same replacement:
```swift
sendTimerSource?.cancel()
sendTimerSource = nil
```

In `handleDisconnect()`, same replacement:
```swift
sendTimerSource?.cancel()
sendTimerSource = nil
```

- [ ] **Step 2: Protect audioBuffer with audioQueue**

Update `appendAudio()` to sync on the queue:

```swift
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
```

Update `flushAudioBuffer()` to run on the queue (it's already called from the timer on audioQueue, but also gate the buffer access):

```swift
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
```

Also update `stop()` — the flush before disconnect needs to be synchronous:

```swift
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
```

- [ ] **Step 3: Build to verify compilation**

Run: `cd /Users/artjiang/develop/Helix-iOS && flutter build ios --simulator --no-codesign`
Expected: BUILD SUCCEEDED

- [ ] **Step 4: Commit**

```bash
git add ios/Runner/OpenAIRealtimeTranscriber.swift
git commit -m "Move audio send timer off main thread to dedicated queue"
```

---

### Task 8: Add BLE VAD gating for OpenAI path

**Files:**
- Modify: `ios/Runner/SpeechStreamRecognizer.swift`

- [ ] **Step 1: Add VAD gating to the OpenAI BLE path in appendPCMData**

In `SpeechStreamRecognizer.swift`, modify the `.openai` case in `appendPCMData()` (around line 1002-1004). Replace:

```swift
if activeBackend == .openai {
    openaiTranscriber.appendAudio(pcmData)
    return
}
```

With:

```swift
if activeBackend == .openai {
    // VAD gating: skip silent BLE audio to save tokens
    let rms = computeBufferRMS(pcmData)
    if rms >= Self.micVadThreshold {
        lastVoiceActivityTime = Date()
        consecutiveSilenceDuration = 0
        openaiTranscriber.appendAudio(pcmData)
    } else {
        let silenceElapsed = Date().timeIntervalSince(lastVoiceActivityTime)
        if silenceElapsed < Self.vadTrailingBufferSec {
            openaiTranscriber.appendAudio(pcmData)
        }
    }
    return
}
```

- [ ] **Step 2: Build to verify compilation**

Run: `cd /Users/artjiang/develop/Helix-iOS && flutter build ios --simulator --no-codesign`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add ios/Runner/SpeechStreamRecognizer.swift
git commit -m "Add BLE VAD gating for OpenAI Realtime path"
```

---

### Task 9: Final validation

**Files:** None (validation only)

- [ ] **Step 1: Run flutter analyze**

Run: `cd /Users/artjiang/develop/Helix-iOS && flutter analyze`
Expected: No errors

- [ ] **Step 2: Run tests**

Run: `cd /Users/artjiang/develop/Helix-iOS && flutter test test/`
Expected: All tests pass

- [ ] **Step 3: Full build**

Run: `cd /Users/artjiang/develop/Helix-iOS && flutter build ios --simulator --no-codesign`
Expected: BUILD SUCCEEDED

- [ ] **Step 4: Run full validation gate**

Run: `cd /Users/artjiang/develop/Helix-iOS && bash scripts/run_gate.sh`
Expected: All gates pass
