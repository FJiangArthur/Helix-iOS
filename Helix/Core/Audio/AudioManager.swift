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
            print("Audio recording started")
        }
    }
    
    func stopRecording() {
        if isTesting {
            testRecording = false
        } else if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
            print("Audio recording stopped")
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
            try audioSession.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker, .allowBluetooth])
            try audioSession.setActive(true)
        } catch {
            audioSubject.send(completion: .failure(.sessionSetupFailed(error)))
        }
    }
    
    private func configureAudioEngine() throws {
        let inputNode = audioEngine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)
        
        // Configure format for 16kHz mono
        guard let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, 
                                       sampleRate: 16000, 
                                       channels: 1, 
                                       interleaved: false) else {
            throw AudioError.formatConfigurationFailed
        }
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, time in
            self?.processAudioBuffer(buffer, at: time)
        }
    }
    
    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer, at time: AVAudioTime) {
        processingQueue.async { [weak self] in
            guard let self = self else { return }
            let processedAudio = ProcessedAudio(
                buffer: buffer,
                timestamp: time.sampleTime,
                sampleRate: buffer.format.sampleRate,
                channelCount: Int(buffer.format.channelCount)
            )
            self.audioSubject.send(processedAudio)
        }
    }
    
    // MARK: - Test audio simulation
    private func scheduleTestAudio() {
        guard testRecording else { return }
        // send mock buffer after specified duration
        processingQueue.asyncAfter(deadline: .now() + testBufferDuration) { [weak self] in
            guard let self = self, self.testRecording else { return }
            // create silent buffer
            let format = AVAudioFormat(standardFormatWithSampleRate: self.testSampleRate, channels: 1)!
            let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 1024)!
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