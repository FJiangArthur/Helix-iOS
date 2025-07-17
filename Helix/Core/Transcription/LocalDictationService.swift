// ABOUTME: Local dictation service using iOS native dictation capabilities
// ABOUTME: Provides offline speech recognition without requiring internet connectivity

import Speech
import AVFoundation
import Combine

class LocalDictationService: NSObject, SpeechRecognitionServiceProtocol {
    private let transcriptionSubject = PassthroughSubject<TranscriptionResult, TranscriptionError>()
    private let processingQueue = DispatchQueue(label: "local.dictation", qos: .userInitiated)
    
    private var audioEngine: AVAudioEngine?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var speechRecognizer: SFSpeechRecognizer?
    
    private var currentLocale: Locale = Locale(identifier: "en-US")
    private var customVocabulary: [String] = []
    private var isCurrentlyRecognizing = false
    
    // Configuration for local dictation
    private let bufferDuration: TimeInterval = 1.0 // Process audio in 1-second chunks
    private var audioBuffer: [Float] = []
    private var lastProcessedTime: TimeInterval = 0
    
    var transcriptionPublisher: AnyPublisher<TranscriptionResult, TranscriptionError> {
        transcriptionSubject.eraseToAnyPublisher()
    }
    
    var isRecognizing: Bool {
        isCurrentlyRecognizing
    }
    
    override init() {
        super.init()
        setupLocalDictation()
        requestPermissions()
    }
    
    deinit {
        cleanupRecognition()
    }
    
    // MARK: - SpeechRecognitionServiceProtocol
    
    func startStreamingRecognition() {
        guard !isCurrentlyRecognizing else {
            return
        }
        
        guard speechRecognizer?.isAvailable == true else {
            transcriptionSubject.send(completion: .failure(.recognitionNotAvailable))
            return
        }
        
        processingQueue.async { [weak self] in
            self?.setupLocalRecognition()
        }
    }
    
    func stopRecognition() {
        guard isCurrentlyRecognizing else { return }
        
        processingQueue.async { [weak self] in
            self?.cleanupRecognition()
        }
    }
    
    func setLanguage(_ locale: Locale) {
        stopRecognition()
        currentLocale = locale
        setupLocalDictation()
    }
    
    func addCustomVocabulary(_ words: [String]) {
        customVocabulary.append(contentsOf: words)
    }
    
    func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        guard isCurrentlyRecognizing,
              let request = recognitionRequest,
              buffer.frameLength > 0 else {
            return
        }
        
        processingQueue.async {
            request.append(buffer)
        }
    }
    
    // MARK: - Local Dictation Setup
    
    private func setupLocalDictation() {
        // Initialize speech recognizer with on-device preference
        if #available(iOS 13.0, *) {
            speechRecognizer = SFSpeechRecognizer(locale: currentLocale)
            
            // Check if on-device recognition is supported for this locale
            if speechRecognizer?.supportsOnDeviceRecognition == false {
                print("⚠️ On-device recognition not supported for \(currentLocale.identifier), fallback to cloud")
            }
        } else {
            speechRecognizer = SFSpeechRecognizer(locale: currentLocale)
        }
        
        speechRecognizer?.delegate = self
    }
    
    private func setupLocalRecognition() {
        // Clean up any existing recognition
        if recognitionTask != nil {
            recognitionTask?.cancel()
            recognitionRequest?.endAudio()
            recognitionTask = nil
            recognitionRequest = nil
        }
        
        // Create recognition request optimized for local processing
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        
        guard let recognitionRequest = recognitionRequest else {
            transcriptionSubject.send(completion: .failure(.serviceUnavailable))
            return
        }
        
        // Configure for optimal local performance
        recognitionRequest.shouldReportPartialResults = true
        
        // Prefer on-device recognition when available
        if #available(iOS 13.0, *) {
            recognitionRequest.requiresOnDeviceRecognition = true
        }
        
        // Optimize for dictation tasks
        if #available(iOS 13.0, *) {
            recognitionRequest.taskHint = .dictation
        }
        
        // Add punctuation for better readability
        if #available(iOS 16.0, *) {
            recognitionRequest.addsPunctuation = true
        }
        
        // Add custom vocabulary for better recognition
        if !customVocabulary.isEmpty {
            recognitionRequest.contextualStrings = customVocabulary
        }
        
        // Set interaction identifier for session tracking
        if #available(iOS 14.0, *) {
            recognitionRequest.interactionIdentifier = UUID().uuidString
        }
        
        // Start recognition with local-optimized settings
        guard let speechRecognizer = speechRecognizer else {
            transcriptionSubject.send(completion: .failure(.recognitionNotAvailable))
            return
        }
        
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            self?.handleLocalDictationResult(result: result, error: error)
        }
        
        isCurrentlyRecognizing = true
    }
    
    private func handleLocalDictationResult(result: SFSpeechRecognitionResult?, error: Error?) {
        if let error = error as NSError? {
            // Handle local dictation specific errors
            if error.domain == "kAFAssistantErrorDomain" {
                switch error.code {
                case 1101: // No speech detected
                    // Continue listening for local dictation
                    return
                case 1107: // Recognition timeout
                    // Restart local recognition
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                        if self?.isCurrentlyRecognizing == true {
                            self?.setupLocalRecognition()
                        }
                    }
                    return
                case 203: // Network not available (should not happen with local dictation)
                    // Local dictation should work offline
                    print("⚠️ Network error in local dictation - this shouldn't happen")
                    return
                case 1700: // On-device recognition not available
                    // Fallback to cloud-based recognition if needed
                    if let request = recognitionRequest {
                        request.requiresOnDeviceRecognition = false
                        print("⚠️ Falling back to cloud recognition due to local unavailability")
                    }
                    return
                default:
                    // Check for cancellation
                    if error.localizedDescription.contains("canceled") || error.localizedDescription.contains("cancelled") {
                        return
                    }
                    print("🛑 Local dictation error: \(error.localizedDescription) (code: \(error.code))")
                }
            } else {
                if error.localizedDescription.contains("canceled") || error.localizedDescription.contains("cancelled") {
                    return
                }
                print("🛑 Local dictation error: \(error.localizedDescription)")
            }
            
            transcriptionSubject.send(completion: .failure(.recognitionFailed(error)))
            cleanupRecognition()
            return
        }
        
        guard let result = result else { return }
        
        let transcription = result.bestTranscription
        let isFinal = result.isFinal
        
        // Skip empty results
        let trimmedText = transcription.formattedString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return }
        
        // Extract word timings for local dictation
        let wordTimings = transcription.segments.map { segment in
            WordTiming(
                word: segment.substring,
                startTime: segment.timestamp,
                endTime: segment.timestamp + segment.duration,
                confidence: segment.confidence
            )
        }
        
        // Calculate average confidence
        let averageConfidence = transcription.segments.isEmpty ? 0.5 : 
            transcription.segments.map { $0.confidence }.reduce(0, +) / Float(transcription.segments.count)
        
        // Get alternative transcriptions
        let alternatives = result.transcriptions.dropFirst().map { $0.formattedString }
        
        let transcriptionResult = TranscriptionResult(
            text: transcription.formattedString,
            speakerId: nil, // Will be set by speaker identification
            confidence: averageConfidence,
            isFinal: isFinal,
            wordTimings: wordTimings,
            alternatives: Array(alternatives.prefix(3))
        )
        
        transcriptionSubject.send(transcriptionResult)
        
        if isFinal {
            // For continuous local dictation, restart after processing
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                if self?.isCurrentlyRecognizing == true {
                    self?.setupLocalRecognition()
                }
            }
        }
    }
    
    private func requestPermissions() {
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            DispatchQueue.main.async {
                switch status {
                case .authorized:
                    break
                case .denied, .restricted, .notDetermined:
                    self?.transcriptionSubject.send(completion: .failure(.permissionDenied))
                @unknown default:
                    self?.transcriptionSubject.send(completion: .failure(.permissionDenied))
                }
            }
        }
    }
    
    private func cleanupRecognition() {
        recognitionTask?.cancel()
        recognitionTask = nil
        
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        
        isCurrentlyRecognizing = false
    }
}

// MARK: - SFSpeechRecognizerDelegate

extension LocalDictationService: SFSpeechRecognizerDelegate {
    func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        if !available && isCurrentlyRecognizing {
            transcriptionSubject.send(completion: .failure(.serviceUnavailable))
            cleanupRecognition()
        }
        
        if available {
            print("✅ Local dictation service available")
        } else {
            print("⚠️ Local dictation service unavailable")
        }
    }
}

// MARK: - Local Dictation Utilities

extension LocalDictationService {
    /// Check if on-device speech recognition is supported for the current locale
    var supportsOnDeviceRecognition: Bool {
        if #available(iOS 13.0, *) {
            return speechRecognizer?.supportsOnDeviceRecognition ?? false
        }
        return false
    }
    
    /// Get the status of local dictation capabilities
    var localDictationStatus: LocalDictationStatus {
        guard let recognizer = speechRecognizer else {
            return .unavailable
        }
        
        if !recognizer.isAvailable {
            return .unavailable
        }
        
        if #available(iOS 13.0, *) {
            return recognizer.supportsOnDeviceRecognition ? .available : .cloudFallback
        }
        
        return .cloudFallback
    }
}

enum LocalDictationStatus {
    case available      // On-device recognition available
    case cloudFallback  // Only cloud recognition available
    case unavailable    // No recognition available
    
    var description: String {
        switch self {
        case .available:
            return "Local dictation available"
        case .cloudFallback:
            return "Cloud dictation available"
        case .unavailable:
            return "Dictation unavailable"
        }
    }
}