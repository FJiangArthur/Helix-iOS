import Foundation

/// A single word with timing information returned by Whisper verbose_json.
struct WhisperWord {
    let word: String
    let start: Double
    let end: Double
}

/// Batch Whisper API transcriber that accumulates PCM16 audio (16kHz mono),
/// chunks it at configurable intervals, encodes as WAV, and POSTs to OpenAI's
/// Whisper transcription endpoint.  Pipeline design: while chunk N is being
/// transcribed via the API, chunk N+1 is accumulating audio.
class WhisperBatchTranscriber {

    // MARK: - Callbacks

    /// Called with (transcriptText, isFinal).  Partials come from each chunk;
    /// the last chunk is marked final when `flush()` is called.
    var onTranscript: ((String, Bool) -> Void)?

    /// Called with word-level timestamps for diarization.
    var onWordTimestamps: (([WhisperWord]) -> Void)?

    /// Called with diarized speaker segments (speaker, text, start, end).
    var onDiarizedSegment: ((String, String, Double, Double) -> Void)?

    /// Called on any HTTP or parsing error.
    var onError: ((String) -> Void)?

    // MARK: - Configuration

    /// Duration in seconds before a chunk is sent to Whisper API.
    var chunkDurationSec: Double = 5.0

    /// 2-letter language code sent to Whisper.
    var language: String = "en"

    /// Model to use for transcription (whisper-1, gpt-4o-transcribe-diarize, etc.)
    var model: String = "whisper-1"

    /// Whether the current model supports native diarization.
    var isDiarizeModel: Bool { model.contains("diarize") }

    /// RMS energy threshold below which a chunk is skipped (VAD gating).
    var vadEnergyThreshold: Float = 0.005

    /// OpenAI API key.
    var apiKey: String = ""

    /// Optional transcription prompt for accuracy hints (domain vocabulary, names).
    var transcriptionPrompt: String = ""

    // MARK: - State

    var isActive: Bool { _isActive }

    private var _isActive = false

    /// Serial queue that protects the ring buffer and overlap state.
    private let bufferQueue = DispatchQueue(label: "com.helix.whisper.buffer")

    /// Accumulated PCM16 audio data (16kHz mono, little-endian Int16).
    private var ringBuffer = Data()

    /// Maximum ring buffer size in bytes (~30 seconds at 16kHz mono 16-bit).
    private static let maxRingBufferBytes = 30 * 16000 * 2  // 960,000 bytes

    /// Overlap from the end of the previous chunk (0.5 seconds).
    private static let overlapDurationSec: Double = 0.5
    private static let overlapBytes = Int(overlapDurationSec * 16000) * 2

    /// Last 0.5s of the previously sent chunk, prepended to the next.
    private var overlapBuffer = Data()

    /// Timestamp offset of the last word from the previous chunk (for dedup).
    private var lastChunkEndTimestamp: Double = 0.0

    /// Timer that fires every `chunkDurationSec` to trigger a send.
    private var chunkTimer: Timer?

    /// Tracks whether a chunk HTTP request is in flight.
    private var requestInFlight = false

    /// Monotonic chunk index for logging.
    private var chunkIndex = 0

    /// Sample rate of the incoming PCM audio.
    private static let sampleRate: Int = 16000
    private static let bitsPerSample: Int = 16
    private static let numChannels: Int = 1

    private func debugLog(_ message: @autoclosure () -> String) {
        #if DEBUG
        NSLog("%@", message())
        #endif
    }

    private func warningLog(_ message: @autoclosure () -> String) {
        NSLog("%@", message())
    }

    // MARK: - Lifecycle

    func start(apiKey: String, language: String = "en", chunkDurationSec: Double = 5.0, model: String = "whisper-1") {
        self.apiKey = apiKey
        self.language = language
        self.chunkDurationSec = chunkDurationSec
        self.model = model

        bufferQueue.sync {
            self.ringBuffer = Data()
            self.overlapBuffer = Data()
            self.lastChunkEndTimestamp = 0.0
            self.chunkIndex = 0
            self.requestInFlight = false
        }

        _isActive = true
        startChunkTimer()
        debugLog("[WhisperBatch] Started language=\(language) chunk=\(chunkDurationSec)s")
    }

    func stop() {
        _isActive = false
        chunkTimer?.invalidate()
        chunkTimer = nil
        debugLog("[WhisperBatch] Stopped")
    }

    /// Append raw PCM16 audio data from the microphone or glasses BLE.
    func appendAudio(_ pcmData: Data) {
        guard _isActive else { return }
        bufferQueue.async {
            self.ringBuffer.append(pcmData)
            // Cap at 30 seconds
            if self.ringBuffer.count > Self.maxRingBufferBytes {
                let overflow = self.ringBuffer.count - Self.maxRingBufferBytes
                self.ringBuffer.removeFirst(overflow)
            }
        }
    }

    /// Flush any remaining audio as a final chunk.  Call this when stopping.
    func flush() {
        sendCurrentChunk(isFinal: true)
    }

    // MARK: - Timer

    private func startChunkTimer() {
        chunkTimer?.invalidate()
        DispatchQueue.main.async {
            self.chunkTimer = Timer.scheduledTimer(
                withTimeInterval: self.chunkDurationSec,
                repeats: true
            ) { [weak self] _ in
                self?.sendCurrentChunk(isFinal: false)
            }
        }
    }

    // MARK: - Chunk send

    private func sendCurrentChunk(isFinal: Bool) {
        var chunkData = Data()
        var overlap = Data()

        bufferQueue.sync {
            guard !self.ringBuffer.isEmpty else { return }

            // Prepend overlap from previous chunk
            chunkData = self.overlapBuffer + self.ringBuffer

            // Save last 0.5s for next chunk's overlap
            let overlapLen = min(Self.overlapBytes, self.ringBuffer.count)
            overlap = self.ringBuffer.suffix(overlapLen)

            self.ringBuffer = Data()
            self.overlapBuffer = overlap
        }

        guard !chunkData.isEmpty else { return }

        // VAD gating: compute RMS energy and skip if below threshold
        let rms = computeRMS(chunkData)
        if rms < vadEnergyThreshold {
            debugLog("[WhisperBatch] Chunk skipped (silence), RMS=\(String(format: "%.6f", rms))")
            return
        }

        chunkIndex += 1
        let currentChunkIndex = chunkIndex

        // Encode to WAV
        let wavData = encodeWAV(pcmData: chunkData)

        debugLog(
            "[WhisperBatch] Sending chunk \(currentChunkIndex) bytes=\(chunkData.count) RMS=\(String(format: "%.4f", rms))"
        )

        // POST to Whisper API
        postToWhisper(wavData: wavData, chunkIndex: currentChunkIndex, isFinal: isFinal)
    }

    // MARK: - WAV encoding

    /// Encode raw PCM16 data as a WAV file in memory (44-byte header + raw samples).
    private func encodeWAV(pcmData: Data) -> Data {
        let dataSize = UInt32(pcmData.count)
        let fileSize = dataSize + 36  // total file size minus 8
        let byteRate = UInt32(Self.sampleRate * Self.numChannels * Self.bitsPerSample / 8)
        let blockAlign = UInt16(Self.numChannels * Self.bitsPerSample / 8)

        var wav = Data(capacity: 44 + Int(dataSize))

        // RIFF header
        wav.append(contentsOf: [0x52, 0x49, 0x46, 0x46])  // "RIFF"
        wav.appendLittleEndian(fileSize)
        wav.append(contentsOf: [0x57, 0x41, 0x56, 0x45])  // "WAVE"

        // fmt sub-chunk
        wav.append(contentsOf: [0x66, 0x6D, 0x74, 0x20])  // "fmt "
        wav.appendLittleEndian(UInt32(16))                  // sub-chunk size
        wav.appendLittleEndian(UInt16(1))                   // PCM format
        wav.appendLittleEndian(UInt16(Self.numChannels))
        wav.appendLittleEndian(UInt32(Self.sampleRate))
        wav.appendLittleEndian(byteRate)
        wav.appendLittleEndian(blockAlign)
        wav.appendLittleEndian(UInt16(Self.bitsPerSample))

        // data sub-chunk
        wav.append(contentsOf: [0x64, 0x61, 0x74, 0x61])  // "data"
        wav.appendLittleEndian(dataSize)
        wav.append(pcmData)

        return wav
    }

    // MARK: - HTTP POST

    private func postToWhisper(wavData: Data, chunkIndex: Int, isFinal: Bool) {
        guard !apiKey.isEmpty else {
            DispatchQueue.main.async {
                self.onError?("Whisper API key is missing")
            }
            return
        }

        let boundary = "WhisperBoundary\(UUID().uuidString.replacingOccurrences(of: "-", with: ""))"
        let url = URL(string: "https://api.openai.com/v1/audio/transcriptions")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30

        // Build multipart body
        var body = Data()
        body.appendMultipartField(name: "model", value: model, boundary: boundary)
        body.appendMultipartField(name: "language", value: language, boundary: boundary)
        if isDiarizeModel {
            body.appendMultipartField(name: "response_format", value: "diarized_json", boundary: boundary)
            body.appendMultipartField(name: "chunking_strategy", value: "auto", boundary: boundary)
        } else {
            body.appendMultipartField(name: "response_format", value: "verbose_json", boundary: boundary)
            body.appendMultipartField(name: "timestamp_granularities[]", value: "word", boundary: boundary)
            body.appendMultipartField(name: "temperature", value: "0", boundary: boundary)
        }
        if !transcriptionPrompt.isEmpty {
            body.appendMultipartField(name: "prompt", value: transcriptionPrompt, boundary: boundary)
        }

        // File field
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"chunk.wav\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/wav\r\n\r\n".data(using: .utf8)!)
        body.append(wavData)
        body.append("\r\n".data(using: .utf8)!)

        // Closing boundary
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        requestInFlight = true

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            self.requestInFlight = false

            if let error = error {
                self.warningLog("[WhisperBatch] HTTP error chunk \(chunkIndex): \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.onError?("Whisper request failed: \(error.localizedDescription)")
                }
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                DispatchQueue.main.async {
                    self.onError?("Whisper: invalid response")
                }
                return
            }

            guard httpResponse.statusCode == 200, let data = data else {
                let statusCode = httpResponse.statusCode
                let body = data.flatMap { String(data: $0, encoding: .utf8) } ?? "no body"
                self.warningLog(
                    "[WhisperBatch] HTTP \(statusCode) chunk \(chunkIndex) "
                    + "(bodyChars=\(body.count))"
                )
                DispatchQueue.main.async {
                    self.onError?("Whisper API error (\(statusCode)): \(body)")
                }
                return
            }

            self.parseWhisperResponse(data: data, chunkIndex: chunkIndex, isFinal: isFinal)
        }.resume()
    }

    // MARK: - Response parsing

    private func parseWhisperResponse(data: Data, chunkIndex: Int, isFinal: Bool) {
        do {
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                DispatchQueue.main.async {
                    self.onError?("Whisper: invalid JSON response")
                }
                return
            }

            if isDiarizeModel {
                parseDiarizedResponse(json: json, chunkIndex: chunkIndex, isFinal: isFinal)
            } else {
                parseVerboseResponse(json: json, chunkIndex: chunkIndex, isFinal: isFinal)
            }

        } catch {
            warningLog("[WhisperBatch] JSON parse error: \(error.localizedDescription)")
            DispatchQueue.main.async {
                self.onError?("Whisper JSON parse error: \(error.localizedDescription)")
            }
        }
    }

    private func parseVerboseResponse(json: [String: Any], chunkIndex: Int, isFinal: Bool) {
        let text = json["text"] as? String ?? ""
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // Parse word-level timestamps
        var words: [WhisperWord] = []
        if let wordArray = json["words"] as? [[String: Any]] {
            for wordDict in wordArray {
                guard let w = wordDict["word"] as? String,
                      let start = wordDict["start"] as? Double,
                      let end = wordDict["end"] as? Double else { continue }
                words.append(WhisperWord(word: w, start: start, end: end))
            }
        }

        // Dedup words that overlap with the previous chunk's overlap region
        let dedupedWords = deduplicateOverlap(words: words)

        // Build text from deduped words if available, otherwise use full text
        let outputText: String
        if !dedupedWords.isEmpty {
            outputText = dedupedWords.map { $0.word }.joined(separator: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            outputText = trimmedText
        }

        // Update the last timestamp for next chunk's dedup
        if let lastWord = dedupedWords.last ?? words.last {
            lastChunkEndTimestamp = lastWord.end
        }

        debugLog(
            "[WhisperBatch] Chunk \(chunkIndex) transcript received "
            + "(chars=\(outputText.count), words=\(dedupedWords.count))"
        )

        DispatchQueue.main.async {
            if !outputText.isEmpty {
                self.onTranscript?(outputText, isFinal)
            }
            if !dedupedWords.isEmpty {
                self.onWordTimestamps?(dedupedWords)
            }
        }
    }

    private func parseDiarizedResponse(json: [String: Any], chunkIndex: Int, isFinal: Bool) {
        guard let segments = json["segments"] as? [[String: Any]] else {
            // Fall back to plain text if segments aren't present
            let text = (json["text"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty {
                DispatchQueue.main.async {
                    self.onTranscript?(text, isFinal)
                }
            }
            return
        }

        var fullText = ""
        for segment in segments {
            let speaker = segment["speaker"] as? String ?? "Unknown"
            let text = (segment["text"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let start = segment["start"] as? Double ?? 0
            let end = segment["end"] as? Double ?? 0

            guard !text.isEmpty else { continue }

            if !fullText.isEmpty { fullText += " " }
            fullText += text

            DispatchQueue.main.async {
                self.onDiarizedSegment?(speaker, text, start, end)
            }
        }

        debugLog(
            "[WhisperBatch] Chunk \(chunkIndex) diarized transcript "
            + "(segments=\(segments.count), chars=\(fullText.count))"
        )

        if !fullText.isEmpty {
            DispatchQueue.main.async {
                self.onTranscript?(fullText, isFinal)
            }
        }
    }

    // MARK: - Overlap deduplication

    /// Remove words whose timestamps fall within the overlap region of the
    /// previous chunk to avoid repeated words at chunk boundaries.
    private func deduplicateOverlap(words: [WhisperWord]) -> [WhisperWord] {
        guard lastChunkEndTimestamp > 0 else { return words }

        // The overlap region is the last 0.5s of the previous chunk.
        // Words with start time before the overlap boundary are duplicates.
        let overlapBoundary = Self.overlapDurationSec
        return words.filter { $0.start >= overlapBoundary }
    }

    // MARK: - VAD (energy detection)

    /// Compute RMS energy of PCM16 data for VAD gating.
    private func computeRMS(_ pcmData: Data) -> Float {
        let sampleCount = pcmData.count / MemoryLayout<Int16>.size
        guard sampleCount > 0 else { return 0 }

        var sumSquares: Float = 0
        pcmData.withUnsafeBytes { rawBuffer in
            guard let ptr = rawBuffer.baseAddress?.assumingMemoryBound(to: Int16.self) else { return }
            for i in 0..<sampleCount {
                let sample = Float(ptr[i]) / Float(Int16.max)
                sumSquares += sample * sample
            }
        }

        return sqrt(sumSquares / Float(sampleCount))
    }
}

// MARK: - Data helpers

private extension Data {
    mutating func appendLittleEndian(_ value: UInt16) {
        var v = value.littleEndian
        append(Data(bytes: &v, count: 2))
    }

    mutating func appendLittleEndian(_ value: UInt32) {
        var v = value.littleEndian
        append(Data(bytes: &v, count: 4))
    }

    mutating func appendMultipartField(name: String, value: String, boundary: String) {
        append("--\(boundary)\r\n".data(using: .utf8)!)
        append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
        append("\(value)\r\n".data(using: .utf8)!)
    }
}
