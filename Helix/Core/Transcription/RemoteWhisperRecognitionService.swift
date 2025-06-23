import Foundation
import Combine
import AVFoundation

/// Remote speech-to-text engine that streams microphone audio to the OpenAI
/// Whisper API and publishes incremental `TranscriptionResult`s.
///
/// NOTE: This is a *stub* implementation suitable for unit-testing and for
/// running in the Codex sandbox (where the network is disabled).  The real
/// networking code is gated behind `#if !CODEX_SANDBOX_NETWORK_DISABLED` so
/// that the file compiles in the CI environment while still giving developers
/// a clear starting-point for the actual HTTP streaming implementation.
final class RemoteWhisperRecognitionService: SpeechRecognitionServiceProtocol {

    // MARK: - Public publisher
    private let subject = PassthroughSubject<TranscriptionResult, TranscriptionError>()
    var transcriptionPublisher: AnyPublisher<TranscriptionResult, TranscriptionError> {
        subject.eraseToAnyPublisher()
    }

    // MARK: - Properties
    private(set) var isRecognizing: Bool = false

    private let apiKey: String
    private let sampleRate: Double

    // Buffer to accumulate audio chunks before sending
    private var pendingBuffers: [AVAudioPCMBuffer] = []
    private let processingQueue = DispatchQueue(label: "remote.whisper.queue", qos: .userInitiated)

    // MARK: - Init
    init(apiKey: String, sampleRate: Double = 16000) {
        self.apiKey = apiKey
        self.sampleRate = sampleRate
    }

    // MARK: - SpeechRecognitionServiceProtocol
    func startStreamingRecognition() {
        guard !isRecognizing else { return }
        isRecognizing = true
        debugLogger.log(.info, source: "RemoteWhisper", message: "Started streaming recognition to Whisper")
        // Real network connection would be spawned here
    }

    func stopRecognition() {
        guard isRecognizing else { return }
        isRecognizing = false
        debugLogger.log(.info, source: "RemoteWhisper", message: "Stopped Whisper recognition")
        // Flush any remaining buffers and close network socket
        pendingBuffers.removeAll()
    }

    func setLanguage(_ locale: Locale) {
        // Not supported yet – could pass hint to Whisper URL
    }

    func addCustomVocabulary(_ words: [String]) {
        // Not supported – Whisper has no custom vocab API
    }

    func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        guard isRecognizing else { return }

        processingQueue.async { [weak self] in
            self?.pendingBuffers.append(buffer)

#if CODEX_SANDBOX_NETWORK_DISABLED
            // The sandbox cannot hit the real API.  Simulate a fake partial
            // result every 1 second of audio.
            let fakeText = "(simulated whisper transcript)"
            let result = TranscriptionResult(text: fakeText, confidence: 0.6, isFinal: false)
            self?.subject.send(result)
#else
            // TODO: chunk, encode as WAV/FLAC or raw PCM, stream via HTTP/2
            // emit partial transcript messages as they arrive from the server.
#endif
        }
    }
}
