import Speech
import AVFoundation
import Combine

protocol SpeechRecognitionServiceProtocol {
    var transcriptionPublisher: AnyPublisher<TranscriptionResult, TranscriptionError> { get }
    var isRecognizing: Bool { get }
    
    func startStreamingRecognition()
    func stopRecognition()
    func setLanguage(_ locale: Locale)
    func addCustomVocabulary(_ words: [String])
    func processAudioBuffer(_ buffer: AVAudioPCMBuffer)
}

struct TranscriptionResult {
    let text: String
    let speakerId: UUID?
    let confidence: Float
    let isFinal: Bool
    let timestamp: TimeInterval
    let wordTimings: [WordTiming]
    let alternatives: [String]
    
    init(text: String, speakerId: UUID? = nil, confidence: Float = 0.0, isFinal: Bool = false, wordTimings: [WordTiming] = [], alternatives: [String] = []) {
        self.text = text
        self.speakerId = speakerId
        self.confidence = confidence
        self.isFinal = isFinal
        self.timestamp = Date().timeIntervalSince1970
        self.wordTimings = wordTimings
        self.alternatives = alternatives
    }
}

/// Represents timing information for a recognized word in transcription.
/// Conforms to Codable and Hashable for use across display and data models.
struct WordTiming: Codable, Hashable {
    let word: String
    let startTime: TimeInterval
    let endTime: TimeInterval
    let confidence: Float
}

enum TranscriptionError: Error {
    case permissionDenied
    case recognitionNotAvailable
    case audioEngineError(Error)
    case recognitionFailed(Error)
    case invalidAudioFormat
    case serviceUnavailable
    
    var localizedDescription: String {
        switch self {
        case .permissionDenied:
            return "Speech recognition permission denied"
        case .recognitionNotAvailable:
            return "Speech recognition not available on this device"
        case .audioEngineError(let error):
            return "Audio engine error: \(error.localizedDescription)"
        case .recognitionFailed(let error):
            return "Speech recognition failed: \(error.localizedDescription)"
        case .invalidAudioFormat:
            return "Invalid audio format for speech recognition"
        case .serviceUnavailable:
            return "Speech recognition service unavailable"
        }
    }
}

class SpeechRecognitionService: NSObject, SpeechRecognitionServiceProtocol {
    private let speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    
    private let transcriptionSubject = PassthroughSubject<TranscriptionResult, TranscriptionError>()
    private let processingQueue = DispatchQueue(label: "speech.recognition", qos: .userInitiated)
    
    private var currentLocale: Locale = Locale(identifier: "en-US")
    private var customVocabulary: [String] = []
    private var isCurrentlyRecognizing = false
    
    // Configuration
    private let maxRecognitionDuration: TimeInterval = 60.0
    private let silenceTimeout: TimeInterval = 3.0
    
    var transcriptionPublisher: AnyPublisher<TranscriptionResult, TranscriptionError> {
        transcriptionSubject.eraseToAnyPublisher()
    }
    
    var isRecognizing: Bool {
        isCurrentlyRecognizing
    }
    
    override init() {
        // Try current locale first, then fall back to default
        if let recognizer = SFSpeechRecognizer(locale: currentLocale) {
            self.speechRecognizer = recognizer
        } else if let recognizer = SFSpeechRecognizer() {
            self.speechRecognizer = recognizer
            print("Warning: Speech recognizer not available for locale \(currentLocale), using default")
        } else if let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US")) {
            self.speechRecognizer = recognizer
            print("Warning: Using fallback en-US locale for speech recognition")
        } else {
            // Speech recognition not available on this device/simulator
            self.speechRecognizer = nil
            print("Warning: Speech recognition not available on this device")
        }
        
        super.init()
        
        speechRecognizer?.delegate = self
        requestPermissions()
    }
    
    func startStreamingRecognition() {
        guard !isCurrentlyRecognizing else {
            print("Speech recognition already in progress")
            return
        }
        
        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            transcriptionSubject.send(completion: .failure(.recognitionNotAvailable))
            return
        }
        
        processingQueue.async { [weak self] in
            guard let self = self else { return }
            self.setupRecognitionRequest()
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
        guard let newRecognizer = SFSpeechRecognizer(locale: locale) else {
            print("Speech recognizer not available for locale: \(locale)")
            return
        }
        
        // Note: In a real implementation, you would replace the recognizer
        // For this demo, we'll just update the locale reference
        print("Updated speech recognition locale to: \(locale.identifier)")
    }
    
    func addCustomVocabulary(_ words: [String]) {
        customVocabulary.append(contentsOf: words)
        print("Added \(words.count) words to custom vocabulary")
    }
    
    func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        guard isCurrentlyRecognizing,
              let request = recognitionRequest else {
            return
        }
        
        processingQueue.async {
            request.append(buffer)
        }
    }
    
    private func requestPermissions() {
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            DispatchQueue.main.async {
                switch status {
                case .authorized:
                    print("Speech recognition authorized")
                case .denied, .restricted, .notDetermined:
                    self?.transcriptionSubject.send(completion: .failure(.permissionDenied))
                @unknown default:
                    self?.transcriptionSubject.send(completion: .failure(.permissionDenied))
                }
            }
        }
    }
    
    private func setupRecognitionRequest() {
        // Cancel and clean up any existing task
        recognitionTask?.cancel()
        recognitionRequest?.endAudio()
        recognitionTask = nil
        
        // Create new recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        
        guard let recognitionRequest = recognitionRequest else {
            transcriptionSubject.send(completion: .failure(.serviceUnavailable))
            return
        }
        
        // Configure recognition request
        recognitionRequest.shouldReportPartialResults = true
        recognitionRequest.requiresOnDeviceRecognition = false
        
        // Add context strings for better recognition
        if !customVocabulary.isEmpty {
            recognitionRequest.contextualStrings = customVocabulary
        }
        
        // Start recognition task
        guard let speechRecognizer = speechRecognizer else {
            transcriptionSubject.send(completion: .failure(.recognitionNotAvailable))
            return
        }
        
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            if let err = error {
                print("🛑 Speech recogniser callback error: \(err.localizedDescription)")
            }
            self?.handleRecognitionResult(result: result, error: error)
        }
        
        isCurrentlyRecognizing = true
        print("Started speech recognition")
    }
    
    func handleRecognitionResult(result: SFSpeechRecognitionResult?, error: Error?) {
        if let error = error as NSError? {
            // kAFAssistantErrorDomain 1101 => "No speech detected"
            // Treat as non-fatal: keep the recognition session alive so the
            // user can continue talking without the entire transcription
            // pipeline shutting down.
            if error.domain == "kAFAssistantErrorDomain" && error.code == 1101 {
                print("⚠️ Speech recogniser reported 'no speech' – ignoring and continuing session")
                return
            }

            transcriptionSubject.send(completion: .failure(.recognitionFailed(error)))
            cleanupRecognition()
            return
        }
        
        guard let result = result else { return }
        
        let transcription = result.bestTranscription
        let isFinal = result.isFinal
        
        // Extract word timings
        let wordTimings = transcription.segments.map { segment in
            WordTiming(
                word: segment.substring,
                startTime: segment.timestamp,
                endTime: segment.timestamp + segment.duration,
                confidence: segment.confidence
            )
        }
        
        // Get alternative transcriptions
        let alternatives = result.transcriptions.dropFirst().map { $0.formattedString }
        
        let transcriptionResult = TranscriptionResult(
            text: transcription.formattedString,
            speakerId: nil, // Will be set by speaker identification
            confidence: transcription.segments.isEmpty ? 0.0 : transcription.segments.map { $0.confidence }.reduce(0, +) / Float(transcription.segments.count),
            isFinal: isFinal,
            wordTimings: wordTimings,
            alternatives: Array(alternatives.prefix(3))
        )
        
        transcriptionSubject.send(transcriptionResult)
        
        if isFinal {
            // Restart recognition for continuous transcription
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                if self?.isCurrentlyRecognizing == true {
                    self?.setupRecognitionRequest()
                }
            }
        }
    }
    
    func cleanupRecognition() {
        recognitionTask?.cancel()
        recognitionTask = nil
        
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        
        isCurrentlyRecognizing = false
        print("Stopped speech recognition")
    }
}

// MARK: - SFSpeechRecognizerDelegate

extension SpeechRecognitionService: SFSpeechRecognizerDelegate {
    func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        if !available && isCurrentlyRecognizing {
            transcriptionSubject.send(completion: .failure(.serviceUnavailable))
            cleanupRecognition()
        }
        
        print("Speech recognizer availability changed: \(available)")
    }
}

// MARK: - Transcription Processor
 
class TranscriptionProcessor {
    private let punctuationModel = PunctuationModel()
    private let spellingCorrector = SpellingCorrector()
    
    func processTranscription(_ result: TranscriptionResult) -> TranscriptionResult {
        var processedText = result.text
        
        // Apply post-processing improvements
        processedText = addPunctuation(to: processedText)
        processedText = correctSpelling(in: processedText)
        processedText = capitalizeSentences(in: processedText)
        
        return TranscriptionResult(
            text: processedText,
            speakerId: result.speakerId,
            confidence: result.confidence,
            isFinal: result.isFinal,
            wordTimings: result.wordTimings,
            alternatives: result.alternatives
        )
    }
    
    private func addPunctuation(to text: String) -> String {
        return punctuationModel.addPunctuation(to: text)
    }
    
    private func correctSpelling(in text: String) -> String {
        return spellingCorrector.correctSpelling(in: text)
    }
    
    private func capitalizeSentences(in text: String) -> String {
        let sentences = text.components(separatedBy: CharacterSet(charactersIn: ".!?"))
        let capitalizedSentences = sentences.map { sentence in
            let trimmed = sentence.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { return sentence }
            return trimmed.prefix(1).uppercased() + trimmed.dropFirst()
        }
        
        return capitalizedSentences.joined(separator: ". ")
    }
}

// MARK: - Supporting Models

class PunctuationModel {
    private let pauseThreshold: TimeInterval = 0.5
    private let sentenceEndWords = Set(["period", "stop", "end", "finished"])
    
    func addPunctuation(to text: String) -> String {
        var result = text
        
        // Simple rule-based punctuation addition
        result = result.replacingOccurrences(of: " period", with: ".")
        result = result.replacingOccurrences(of: " comma", with: ",")
        result = result.replacingOccurrences(of: " question mark", with: "?")
        result = result.replacingOccurrences(of: " exclamation mark", with: "!")
        
        // Add periods at natural sentence boundaries
        let words = result.components(separatedBy: " ")
        if let lastWord = words.last?.lowercased(),
           sentenceEndWords.contains(lastWord) {
            result = result.replacingOccurrences(of: lastWord, with: ".")
        }
        
        return result
    }
}

class SpellingCorrector {
    private let commonCorrections: [String: String] = [
        "cant": "can't",
        "wont": "won't",
        "dont": "don't",
        "isnt": "isn't",
        "wasnt": "wasn't",
        "werent": "weren't",
        "shouldnt": "shouldn't",
        "couldnt": "couldn't",
        "wouldnt": "wouldn't"
    ]
    
    func correctSpelling(in text: String) -> String {
        var result = text
        
        for (incorrect, correct) in commonCorrections {
            let pattern = "\\b\(incorrect)\\b"
            result = result.replacingOccurrences(
                of: pattern,
                with: correct,
                options: [.regularExpression, .caseInsensitive]
            )
        }
        
        return result
    }
}
