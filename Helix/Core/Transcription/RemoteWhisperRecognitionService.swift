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
    
    // Timing for chunk processing
    private var lastProcessTime: Date = Date()
    private let chunkInterval: TimeInterval = 2.0 // Process chunks every 2 seconds
    private var chunkTimer: Timer?

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
        
        // Start timer for periodic chunk processing
        chunkTimer = Timer.scheduledTimer(withTimeInterval: chunkInterval, repeats: true) { [weak self] _ in
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
            
            // Copy the buffer to avoid potential issues with the original buffer being modified
            if let copiedBuffer = self.copyBuffer(buffer) {
                self.pendingBuffers.append(copiedBuffer)
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func processAccumulatedAudio(final: Bool = false) {
        processingQueue.async { [weak self] in
            guard let self = self, !self.pendingBuffers.isEmpty else { return }
            
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
        
        // Add response format parameter
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"response_format\"\r\n\r\n".data(using: .utf8)!)
        body.append("verbose_json\r\n".data(using: .utf8)!)
        
        // Add timestamp granularities
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"timestamp_granularities[]\"\r\n\r\n".data(using: .utf8)!)
        body.append("word\r\n".data(using: .utf8)!)
        
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
