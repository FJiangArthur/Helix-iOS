import AVFoundation
import Combine

protocol AudioManagerProtocol {
    var audioPublisher: AnyPublisher<ProcessedAudio, AudioError> { get }
    var isRecording: Bool { get }
    
    func startRecording() throws
    func stopRecording()
    func configure(sampleRate: Double, bufferDuration: TimeInterval) throws
    
    // Recording storage
    func startStoringRecording()
    func stopStoringRecording()
    func saveLastRecording(filename: String) -> URL?
    func getRecordingDuration() -> TimeInterval
}

class AudioManager: NSObject, AudioManagerProtocol {
    private let audioEngine = AVAudioEngine()
    private let audioSession = AVAudioSession.sharedInstance()
    private let processingQueue = DispatchQueue(label: "audio.processing", qos: .userInteractive)

    // Desired format for downstream processing (16-kHz mono float32)
    private let targetSampleRate: Double = 16_000
    private var audioConverter: AVAudioConverter?
    
    // Test mode when running under XCTest
    private let isTesting: Bool = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    private var testRecording = false
    private var testSampleRate: Double = 16000.0
    private var testBufferDuration: TimeInterval = 0.005
    
    // Recording storage
    private var recordedBuffers: [AVAudioPCMBuffer] = []
    private var isStoringRecording = false
    private let recordingQueue = DispatchQueue(label: "audio.recording", qos: .userInitiated)
    
    private let audioSubject = PassthroughSubject<ProcessedAudio, AudioError>()
    private var cancellables = Set<AnyCancellable>()
    
    var audioPublisher: AnyPublisher<ProcessedAudio, AudioError> {
        audioSubject.eraseToAnyPublisher()
    }
    
    var isRecording: Bool {
        isTesting ? testRecording : audioEngine.isRunning
    }
    
    override init() {
        super.init()
        setupAudioSession()
    }
    
    func startRecording() throws {
        guard !isRecording else { return }
        if isTesting {
            // simulate audio in tests
            testRecording = true
            scheduleTestAudio()
        } else {
            try configureAudioEngine()
            try audioEngine.start()
        }
    }
    
    func stopRecording() {
        if isTesting {
            testRecording = false
        } else if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
    }
    
    func configure(sampleRate: Double = 16000.0, bufferDuration: TimeInterval = 0.005) throws {
        if isTesting {
            testSampleRate = sampleRate
            testBufferDuration = bufferDuration
        } else {
            try audioSession.setPreferredSampleRate(sampleRate)
            try audioSession.setPreferredIOBufferDuration(bufferDuration)
        }
    }
    
    // MARK: - Recording Storage
    
    func startStoringRecording() {
        recordingQueue.async { [weak self] in
            self?.recordedBuffers.removeAll()
            self?.isStoringRecording = true
            print("🎙️ AudioManager: Started storing recording")
        }
    }
    
    func stopStoringRecording() {
        recordingQueue.async { [weak self] in
            self?.isStoringRecording = false
            print("🎙️ AudioManager: Stopped storing recording (\(self?.recordedBuffers.count ?? 0) buffers)")
        }
    }
    
    func saveLastRecording(filename: String = "last_recording.wav") -> URL? {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = documentsPath.appendingPathComponent(filename)
        
        guard !recordedBuffers.isEmpty else {
            print("❌ AudioManager: No recorded audio to save")
            return nil
        }
        
        // Convert recorded buffers to WAV data
        if let wavData = convertBuffersToWAVData(recordedBuffers) {
            do {
                try wavData.write(to: fileURL)
                print("✅ AudioManager: Saved recording to \(fileURL.path)")
                return fileURL
            } catch {
                print("❌ AudioManager: Failed to save recording: \(error)")
                return nil
            }
        }
        
        return nil
    }
    
    func getRecordingDuration() -> TimeInterval {
        return recordedBuffers.reduce(0.0) { total, buffer in
            return total + Double(buffer.frameLength) / buffer.format.sampleRate
        }
    }
    
    private func setupAudioSession() {
        do {
            // Use .measurement mode for better speech recognition sensitivity
            // .default mode may filter out quiet speech
            try audioSession.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker, .allowBluetooth])
            try audioSession.setActive(true)
            
            // Request microphone permission explicitly
            audioSession.requestRecordPermission { granted in
                if !granted {
                    DispatchQueue.main.async { [weak self] in
                        self?.audioSubject.send(completion: .failure(.permissionDenied))
                    }
                }
            }
        } catch {
            audioSubject.send(completion: .failure(.sessionSetupFailed(error)))
        }
    }
    
    private func configureAudioEngine() throws {
        let inputNode = audioEngine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)
        
        // The format passed to `installTap` MUST match the node's
        // `outputFormat(forBus:)`.  Supplying a mismatching format (e.g. a
        // different sample-rate or channel count) will raise an Objective-C
        // exception at runtime which cannot be caught from Swift and will
        // crash the application (this is the crash that has been observed on
        // Thread 1 when hitting the record button).

        // Therefore we use the node's own output format here to avoid the
        // mismatch crash.  If the app requires a specific target format (e.g.
        // 16 kHz mono) we can perform the conversion later in
        // `processAudioBuffer` via `AVAudioConverter`.

        let format = inputFormat

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, time in
            self?.processAudioBuffer(buffer, at: time)
        }
    }
    
    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer, at time: AVAudioTime) {
        processingQueue.async { [weak self] in
            guard let self = self else { return }

            // Calculate audio level for debugging
            let audioLevel = self.calculateAudioLevel(buffer)
            if audioLevel > 0.01 { // Only log when there's actual audio
                print("🔊 Audio level: \(String(format: "%.3f", audioLevel))")
            }
            
            // Store recording if enabled
            if self.isStoringRecording, let copiedBuffer = self.copyAudioBuffer(buffer) {
                self.recordingQueue.async {
                    self.recordedBuffers.append(copiedBuffer)
                }
            }

            let sourceFormat = buffer.format
            if sourceFormat.sampleRate != self.targetSampleRate || sourceFormat.channelCount != 1 {
                // Lazily create converter once we know source format
                if self.audioConverter == nil {
                    guard let desiredFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32,
                                                             sampleRate: self.targetSampleRate,
                                                             channels: 1,
                                                             interleaved: false) else {
                        print("❌ AudioManager: Failed to create desired audio format")
                        return
                    }
                    self.audioConverter = AVAudioConverter(from: sourceFormat, to: desiredFormat)
                }

                guard let converter = self.audioConverter else {
                    print("❌ AudioManager: Missing audio converter")
                    return
                }

                let desiredFormat = converter.outputFormat

                let capacity = AVAudioFrameCount(desiredFormat.sampleRate / 100 * 2)
                guard let convertedBuffer = AVAudioPCMBuffer(pcmFormat: desiredFormat,
                                                             frameCapacity: capacity) else {
                    print("❌ AudioManager: Failed to create converted buffer")
                    return
                }

                var error: NSError?
                let inputBlock: AVAudioConverterInputBlock = { inNumPackets, outStatus in
                    outStatus.pointee = .haveData
                    return buffer
                }

                converter.convert(to: convertedBuffer, error: &error, withInputFrom: inputBlock)

                if let error {
                    self.audioSubject.send(completion: .failure(.processingFailed(error)))
                    return
                }

                let processed = ProcessedAudio(buffer: convertedBuffer,
                                               timestamp: time.sampleTime,
                                               sampleRate: desiredFormat.sampleRate,
                                               channelCount: Int(desiredFormat.channelCount))
                self.audioSubject.send(processed)
            } else {
                let processedAudio = ProcessedAudio(
                    buffer: buffer,
                    timestamp: time.sampleTime,
                    sampleRate: buffer.format.sampleRate,
                    channelCount: Int(buffer.format.channelCount)
                )
                self.audioSubject.send(processedAudio)
            }
        }
    }
    
    // MARK: - Audio Analysis
    private func copyAudioBuffer(_ buffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
        let format = buffer.format
        guard let copiedBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: buffer.frameLength) else {
            return nil
        }
        
        copiedBuffer.frameLength = buffer.frameLength
        
        // Copy the audio data
        if let srcChannelData = buffer.floatChannelData,
           let dstChannelData = copiedBuffer.floatChannelData {
            for channel in 0..<Int(format.channelCount) {
                memcpy(dstChannelData[channel], srcChannelData[channel], Int(buffer.frameLength) * MemoryLayout<Float>.size)
            }
        }
        
        return copiedBuffer
    }
    
    private func convertBuffersToWAVData(_ buffers: [AVAudioPCMBuffer]) -> Data? {
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
        return convertPCMBufferToWAVData(combinedBuffer)
    }
    
    private func convertPCMBufferToWAVData(_ buffer: AVAudioPCMBuffer) -> Data? {
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
        wavData.append(contentsOf: withUnsafeBytes(of: UInt32(16).littleEndian) { Array($0) })
        wavData.append(contentsOf: withUnsafeBytes(of: UInt16(1).littleEndian) { Array($0) })
        wavData.append(contentsOf: withUnsafeBytes(of: UInt16(channelCount).littleEndian) { Array($0) })
        wavData.append(contentsOf: withUnsafeBytes(of: UInt32(sampleRate).littleEndian) { Array($0) })
        wavData.append(contentsOf: withUnsafeBytes(of: UInt32(byteRate).littleEndian) { Array($0) })
        wavData.append(contentsOf: withUnsafeBytes(of: UInt16(blockAlign).littleEndian) { Array($0) })
        wavData.append(contentsOf: withUnsafeBytes(of: UInt16(16).littleEndian) { Array($0) })
        
        // data chunk
        wavData.append("data".data(using: .ascii)!)
        wavData.append(contentsOf: withUnsafeBytes(of: UInt32(dataSize).littleEndian) { Array($0) })
        wavData.append(pcmData)
        
        return wavData
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
    
    // MARK: - Test audio simulation
    private func scheduleTestAudio() {
        guard testRecording else { return }
        // send mock buffer after specified duration
        processingQueue.asyncAfter(deadline: .now() + testBufferDuration) { [weak self] in
            guard let self = self, self.testRecording else { return }
            // create silent buffer
            guard let format = AVAudioFormat(standardFormatWithSampleRate: self.testSampleRate, channels: 1) else {
                print("❌ AudioManager: Failed to create audio format")
                return
            }
            guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 1024) else {
                print("❌ AudioManager: Failed to create audio buffer")
                return
            }
            buffer.frameLength = 1024
            let processed = ProcessedAudio(
                buffer: buffer,
                timestamp: AVAudioFramePosition(Date().timeIntervalSince1970 * self.testSampleRate),
                sampleRate: self.testSampleRate,
                channelCount: 1
            )
            self.audioSubject.send(processed)
            // schedule next
            self.scheduleTestAudio()
        }
    }
}

// MARK: - Data Models

struct ProcessedAudio {
    let buffer: AVAudioPCMBuffer
    let timestamp: AVAudioFramePosition
    let sampleRate: Double
    let channelCount: Int
    let id: UUID = UUID()
    
    var duration: TimeInterval {
        Double(buffer.frameLength) / sampleRate
    }
}

enum AudioError: Error {
    case sessionSetupFailed(Error)
    case formatConfigurationFailed
    case recordingStartFailed(Error)
    case processingFailed(Error)
    case permissionDenied
    
    var localizedDescription: String {
        switch self {
        case .sessionSetupFailed(let error):
            return "Audio session setup failed: \(error.localizedDescription)"
        case .formatConfigurationFailed:
            return "Audio format configuration failed"
        case .recordingStartFailed(let error):
            return "Recording start failed: \(error.localizedDescription)"
        case .processingFailed(let error):
            return "Audio processing failed: \(error.localizedDescription)"
        case .permissionDenied:
            return "Microphone permission denied"
        }
    }
}