import Foundation
import Combine
import AVFoundation

/// Remote speech-to-text engine that streams microphone audio to the OpenAI
/// Whisper API and publishes incremental `TranscriptionResult`s.
///
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
    
    // Networking
    private var currentTask: URLSessionDataTask?
    private let session = URLSession.shared
    
    // Voice activity detection for smart chunking
    private var lastProcessTime: Date = Date()
    private let maxChunkInterval: TimeInterval = 8.0 // Maximum time before forcing processing
    private var chunkTimer: Timer?
    private let minimumBufferDuration: TimeInterval = 3.0 // Minimum 3 seconds of audio for better accuracy
    private let silenceThreshold: Float = 0.02 // Audio level below this is considered silence
    private var consecutiveSilenceCount = 0
    private let silenceFramesRequired = 10 // Frames of silence before processing

    // MARK: - Init
    init(apiKey: String, sampleRate: Double = 16000) {
        self.apiKey = apiKey
        self.sampleRate = sampleRate
    }

    // MARK: - SpeechRecognitionServiceProtocol
    func startStreamingRecognition() {
        guard !isRecognizing else { return }
        
        // Validate API key
        guard !apiKey.isEmpty else {
            print("❌ RemoteWhisper: No API key configured")
            subject.send(completion: .failure(.serviceUnavailable))
            return
        }
        
        isRecognizing = true
        pendingBuffers.removeAll()
        lastProcessTime = Date()
        
        // Start timer for maximum chunk processing (fallback)
        chunkTimer = Timer.scheduledTimer(withTimeInterval: maxChunkInterval, repeats: true) { [weak self] _ in
            self?.processAccumulatedAudio()
        }
        
        print("ℹ️ RemoteWhisper: Started streaming recognition to Whisper API")
    }

    func stopRecognition() {
        guard isRecognizing else { return }
        
        // Stop timer
        chunkTimer?.invalidate()
        chunkTimer = nil
        
        // Cancel any in-flight request
        currentTask?.cancel()
        currentTask = nil
        
        // Process any remaining audio
        if !pendingBuffers.isEmpty {
            processAccumulatedAudio(final: true)
        }
        
        isRecognizing = false
        print("ℹ️ RemoteWhisper: Stopped Whisper recognition")
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
            guard let self = self else { return }
            
            // Calculate audio level for voice activity detection
            let audioLevel = self.calculateAudioLevel(buffer)
            
            // Copy the buffer to avoid potential issues with the original buffer being modified
            if let copiedBuffer = self.copyBuffer(buffer) {
                self.pendingBuffers.append(copiedBuffer)
            }
            
            // Voice activity detection
            if audioLevel < self.silenceThreshold {
                self.consecutiveSilenceCount += 1
                // Only log when approaching the threshold
                if self.consecutiveSilenceCount == self.silenceFramesRequired - 2 {
                    print("🔇 Approaching silence threshold...")
                }
            } else {
                self.consecutiveSilenceCount = 0
            }
            
            // Process if we have enough silence after speech
            let totalDuration = self.pendingBuffers.reduce(0.0) { total, buffer in
                return total + Double(buffer.frameLength) / buffer.format.sampleRate
            }
            
            if totalDuration >= self.minimumBufferDuration && 
               self.consecutiveSilenceCount >= self.silenceFramesRequired {
                print("🎤 Processing due to silence after speech (\(String(format: "%.1f", totalDuration))s)")
                self.processAccumulatedAudio()
                self.consecutiveSilenceCount = 0
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func processAccumulatedAudio(final: Bool = false) {
        processingQueue.async { [weak self] in
            guard let self = self, !self.pendingBuffers.isEmpty else { return }
            
            // Calculate total buffer duration
            let totalDuration = self.pendingBuffers.reduce(0.0) { total, buffer in
                return total + Double(buffer.frameLength) / buffer.format.sampleRate
            }
            
            // Only process if we have minimum duration or if final
            guard final || totalDuration >= self.minimumBufferDuration else {
                print("⏱️ RemoteWhisper: Buffer too short (\(String(format: "%.1f", totalDuration))s), waiting for more audio")
                return
            }
            
            // Also check if we have enough actual audio content (not just silence)
            let averageLevel = self.calculateAverageAudioLevel(self.pendingBuffers)
            if averageLevel < 0.001 && !final {
                print("🔇 RemoteWhisper: Audio too quiet (\(String(format: "%.4f", averageLevel))), skipping processing")
                self.pendingBuffers.removeAll() // Clear silent buffers
                return
            }
            
            print("🎤 RemoteWhisper: Processing \(String(format: "%.1f", totalDuration))s of audio (level: \(String(format: "%.3f", averageLevel)))")
            
            // Convert accumulated buffers to audio data
            guard let audioData = self.convertBuffersToAudioData(self.pendingBuffers) else {
                print("⚠️ RemoteWhisper: Failed to convert audio buffers")
                return
            }
            
            // Clear processed buffers
            self.pendingBuffers.removeAll()
            
            // Send to Whisper API
            self.sendToWhisperAPI(audioData: audioData, isFinal: final)
        }
    }
    
    private func sendToWhisperAPI(audioData: Data, isFinal: Bool) {
        guard !apiKey.isEmpty else {
            print("❌ RemoteWhisper: No API key available")
            return
        }
        
        guard let url = URL(string: "https://api.openai.com/v1/audio/transcriptions") else {
            print("❌ RemoteWhisper: Invalid API URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        // Create multipart form data
        let boundary = UUID().uuidString
        request.addValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        
        // Add model parameter
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n".data(using: .utf8)!)
        body.append("whisper-1\r\n".data(using: .utf8)!)
        
        // Add language parameter to force English and prevent Korean hallucinations
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"language\"\r\n\r\n".data(using: .utf8)!)
        body.append("en\r\n".data(using: .utf8)!)
        
        // Add temperature for more conservative transcription
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"temperature\"\r\n\r\n".data(using: .utf8)!)
        body.append("0.0\r\n".data(using: .utf8)!)
        
        // Add response format parameter
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"response_format\"\r\n\r\n".data(using: .utf8)!)
        body.append("verbose_json\r\n".data(using: .utf8)!)
        
        // Add timestamp granularities
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"timestamp_granularities[]\"\r\n\r\n".data(using: .utf8)!)
        body.append("word\r\n".data(using: .utf8)!)
        
        // Add prompt to guide transcription toward English business/technical content
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"prompt\"\r\n\r\n".data(using: .utf8)!)
        body.append("This is a conversation about technology, business, or processes. The speaker is discussing transcription, processes, or technical topics in English.\r\n".data(using: .utf8)!)
        
        // Add audio file
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"audio.wav\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/wav\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        // Cancel any existing request
        currentTask?.cancel()
        
        print("ℹ️ RemoteWhisper: Sending \(audioData.count) bytes to Whisper API")
        
        currentTask = session.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.handleWhisperResponse(data: data, response: response, error: error, isFinal: isFinal)
            }
        }
        currentTask?.resume()
    }
    
    private func handleWhisperResponse(data: Data?, response: URLResponse?, error: Error?, isFinal: Bool) {
        if let error = error {
            print("❌ RemoteWhisper: Whisper API error: \(error.localizedDescription)")
            if !error.localizedDescription.contains("cancelled") {
                subject.send(completion: .failure(.recognitionFailed(error)))
            }
            return
        }
        
        guard let data = data else {
            print("❌ RemoteWhisper: No data received from Whisper API")
            return
        }
        
        do {
            let response = try JSONDecoder().decode(WhisperResponse.self, from: data)
            
            // Filter out obvious hallucinations and foreign language content
            if isLikelyHallucination(response.text) {
                print("🚫 RemoteWhisper: Filtered out likely hallucination: \"\(response.text)\"")
                return
            }
            
            // Extract word timings
            let wordTimings = response.words?.map { word in
                WordTiming(
                    word: word.word,
                    startTime: word.start,
                    endTime: word.end,
                    confidence: 1.0 // Whisper doesn't provide word-level confidence
                )
            } ?? []
            
            let result = TranscriptionResult(
                text: response.text,
                speakerId: nil,
                confidence: 0.9, // Whisper generally has high confidence
                isFinal: isFinal,
                wordTimings: wordTimings,
                alternatives: []
            )
            
            print("ℹ️ RemoteWhisper: Received transcription: \"\(response.text)\"")
            subject.send(result)
            
        } catch {
            print("❌ RemoteWhisper: Failed to decode Whisper response: \(error.localizedDescription)")
            if let responseString = String(data: data, encoding: .utf8) {
                print("🔍 RemoteWhisper: Response data: \(responseString)")
            }
        }
    }
    
    private func calculateAudioLevel(_ buffer: AVAudioPCMBuffer) -> Float {
        guard let channelData = buffer.floatChannelData else { return 0.0 }
        
        let frameCount = Int(buffer.frameLength)
        let channelCount = Int(buffer.format.channelCount)
        
        var sum: Float = 0.0
        for channel in 0..<channelCount {
            let samples = channelData[channel]
            for frame in 0..<frameCount {
                let sample = samples[frame]
                sum += sample * sample
            }
        }
        
        let rms = sqrt(sum / Float(frameCount * channelCount))
        return rms
    }
    
    private func calculateAverageAudioLevel(_ buffers: [AVAudioPCMBuffer]) -> Float {
        guard !buffers.isEmpty else { return 0.0 }
        
        let levels = buffers.map { calculateAudioLevel($0) }
        let average = levels.reduce(0, +) / Float(levels.count)
        return average
    }
    
    private func isLikelyHallucination(_ text: String) -> Bool {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        // Filter out empty or very short responses
        if trimmedText.count < 3 {
            return true
        }
        
        // Known hallucination patterns
        let hallucinationPatterns = [
            "mbc 뉴스",
            "이덕영입니다",
            "자막뉴스",
            "방송", 
            "kbs",
            "sbs",
            "tv조선",
            "연합뉴스",
            "ytn",
            // Common Whisper hallucinations
            "thanks for watching",
            "thank you for watching",
            "subscribe",
            "like and subscribe",
            "don't forget to subscribe",
            "본 프로그램은",
            "시청해주셔서 감사합니다",
            "구독",
            "알림설정"
        ]
        
        // Check for Korean characters (likely hallucination for English speaker)
        let koreanCharacterSet = CharacterSet(charactersIn: "가-힣ㄱ-ㅎㅏ-ㅣ")
        if trimmedText.rangeOfCharacter(from: koreanCharacterSet) != nil {
            return true
        }
        
        // Check against known patterns
        for pattern in hallucinationPatterns {
            if trimmedText.contains(pattern) {
                return true
            }
        }
        
        // Filter very repetitive text
        let words = trimmedText.components(separatedBy: .whitespacesAndNewlines)
        if words.count > 2 {
            let uniqueWords = Set(words)
            if Double(uniqueWords.count) / Double(words.count) < 0.3 {
                return true // Too repetitive
            }
        }
        
        return false
    }
    
    private func copyBuffer(_ buffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
        let format = buffer.format
        guard let newBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: buffer.frameLength) else {
            return nil
        }
        
        newBuffer.frameLength = buffer.frameLength
        
        // Copy the audio data
        if let srcChannelData = buffer.floatChannelData,
           let dstChannelData = newBuffer.floatChannelData {
            for channel in 0..<Int(format.channelCount) {
                memcpy(dstChannelData[channel], srcChannelData[channel], Int(buffer.frameLength) * MemoryLayout<Float>.size)
            }
        }
        
        return newBuffer
    }
    
    private func convertBuffersToAudioData(_ buffers: [AVAudioPCMBuffer]) -> Data? {
        guard !buffers.isEmpty else { return nil }
        
        // Calculate total frame count
        let totalFrames = buffers.reduce(0) { $0 + Int($1.frameLength) }
        guard totalFrames > 0 else { return nil }
        
        // Use the format from the first buffer
        guard let format = buffers.first?.format else { return nil }
        
        // Create a combined buffer
        guard let combinedBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(totalFrames)) else {
            return nil
        }
        
        // Copy all buffers into the combined buffer
        var currentFrame: AVAudioFrameCount = 0
        for buffer in buffers {
            guard let srcData = buffer.floatChannelData,
                  let dstData = combinedBuffer.floatChannelData else {
                continue
            }
            
            for channel in 0..<Int(format.channelCount) {
                let srcPtr = srcData[channel]
                let dstPtr = dstData[channel].advanced(by: Int(currentFrame))
                memcpy(dstPtr, srcPtr, Int(buffer.frameLength) * MemoryLayout<Float>.size)
            }
            
            currentFrame += buffer.frameLength
        }
        
        combinedBuffer.frameLength = currentFrame
        
        // Convert to WAV data
        return convertToWAVData(combinedBuffer)
    }
    
    private func convertToWAVData(_ buffer: AVAudioPCMBuffer) -> Data? {
        guard let floatData = buffer.floatChannelData else { return nil }
        
        let frameCount = Int(buffer.frameLength)
        let channelCount = Int(buffer.format.channelCount)
        let sampleRate = Int(buffer.format.sampleRate)
        
        // Convert float samples to 16-bit PCM
        var pcmData = Data()
        for frame in 0..<frameCount {
            for channel in 0..<channelCount {
                let floatSample = floatData[channel][frame]
                let intSample = Int16(max(min(floatSample * 32767.0, 32767.0), -32768.0))
                pcmData.append(contentsOf: withUnsafeBytes(of: intSample.littleEndian) { Array($0) })
            }
        }
        
        // Create WAV header
        let dataSize = pcmData.count
        let fileSize = 44 + dataSize - 8
        let byteRate = sampleRate * channelCount * 2
        let blockAlign = channelCount * 2
        
        var wavData = Data()
        
        // RIFF header
        wavData.append("RIFF".data(using: .ascii)!)
        wavData.append(contentsOf: withUnsafeBytes(of: UInt32(fileSize).littleEndian) { Array($0) })
        wavData.append("WAVE".data(using: .ascii)!)
        
        // fmt chunk
        wavData.append("fmt ".data(using: .ascii)!)
        wavData.append(contentsOf: withUnsafeBytes(of: UInt32(16).littleEndian) { Array($0) }) // chunk size
        wavData.append(contentsOf: withUnsafeBytes(of: UInt16(1).littleEndian) { Array($0) }) // audio format (PCM)
        wavData.append(contentsOf: withUnsafeBytes(of: UInt16(channelCount).littleEndian) { Array($0) }) // number of channels
        wavData.append(contentsOf: withUnsafeBytes(of: UInt32(sampleRate).littleEndian) { Array($0) }) // sample rate
        wavData.append(contentsOf: withUnsafeBytes(of: UInt32(byteRate).littleEndian) { Array($0) }) // byte rate
        wavData.append(contentsOf: withUnsafeBytes(of: UInt16(blockAlign).littleEndian) { Array($0) }) // block align
        wavData.append(contentsOf: withUnsafeBytes(of: UInt16(16).littleEndian) { Array($0) }) // bits per sample
        
        // data chunk
        wavData.append("data".data(using: .ascii)!)
        wavData.append(contentsOf: withUnsafeBytes(of: UInt32(dataSize).littleEndian) { Array($0) })
        wavData.append(pcmData)
        
        return wavData
    }
}

// MARK: - Whisper API Response Models

struct WhisperResponse: Codable {
    let text: String
    let words: [WhisperWord]?
}

struct WhisperWord: Codable {
    let word: String
    let start: Double
    let end: Double
}
