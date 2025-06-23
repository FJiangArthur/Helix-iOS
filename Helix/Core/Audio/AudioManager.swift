import AVFoundation
import Combine

protocol AudioManagerProtocol {
    var audioPublisher: AnyPublisher<ProcessedAudio, AudioError> { get }
    var isRecording: Bool { get }
    
    func startRecording() throws
    func stopRecording()
    func configure(sampleRate: Double, bufferDuration: TimeInterval) throws
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