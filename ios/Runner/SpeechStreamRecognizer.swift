//
//  SpeechStreamRecognizer.swift
//  Runner
//
//  Created by edy on 2024/4/16.
//
import AVFoundation
import Speech

class SpeechStreamRecognizer {
    static let shared = SpeechStreamRecognizer()
    
    private var recognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var lastRecognizedText: String = "" // latest accepeted recognized text
    // private var previousRecognizedText: String = ""
    let languageDic = [
        "CN": "zh-CN",
        "EN": "en-US",
        "RU": "ru-RU",
        "KR": "ko-KR",
        "JP": "ja-JP",
        "ES": "es-ES",
        "FR": "fr-FR",
        "DE": "de-DE",
        "NL": "nl-NL",
        "NB": "nb-NO",
        "DA": "da-DK",
        "SV": "sv-SE",
        "FI": "fi-FI",
        "IT": "it-IT"
    ]
    
    let dateFormatter = DateFormatter()
    
    private var lastTranscription: SFTranscription? // cache to make contrast between near results
    private var cacheString = "" // cache stream recognized formattedString
    
    enum RecognizerError: Error {
        case nilRecognizer
        case notAuthorizedToRecognize
        case notPermittedToRecord
        case recognizerIsUnavailable
        
        var message: String {
            switch self {
            case .nilRecognizer: return "Can't initialize speech recognizer"
            case .notAuthorizedToRecognize: return "Not authorized to recognize speech"
            case .notPermittedToRecord: return "Not permitted to record audio"
            case .recognizerIsUnavailable: return "Recognizer is unavailable"
            }
        }
    }
    
    private init() {
        dateFormatter.dateFormat = "HH:mm:ss.SSS"
        if #available(iOS 13.0, *) {
            Task {
                do {
                    guard await SFSpeechRecognizer.hasAuthorizationToRecognize() else {
                        throw RecognizerError.notAuthorizedToRecognize
                    }
                    /*
                     guard await AVAudioSession.sharedInstance().hasPermissionToRecord() else {
                     throw RecognizerError.notPermittedToRecord
                     }*/
                } catch {
                    HelixLogger.error("Speech recognizer permission error", error: error, category: .speech)
                }
            }
        } else {
            // Fallback on earlier versions
        }
    }
    
    func startRecognition(identifier: String) {
        lastTranscription = nil
        self.lastRecognizedText = ""
        cacheString = ""

        let localIdentifier = languageDic[identifier]
        HelixLogger.speech("Starting speech recognition", level: .info, metadata: [
            "language": identifier,
            "locale": localIdentifier ?? "en-US"
        ])

        recognizer = SFSpeechRecognizer(locale: Locale(identifier: localIdentifier ?? "en-US"))  // en-US zh-CN en-US
        guard let recognizer = recognizer else {
            HelixLogger.speech("Speech recognizer is not available", level: .error)
            return
        }

        guard recognizer.isAvailable else {
            HelixLogger.speech("Speech recognizer is currently unavailable", level: .warning)
            return
        }

        let audioSession = AVAudioSession.sharedInstance()
        do {
            //try audioSession.setCategory(.record)
            try audioSession.setCategory(.playback, options: .mixWithOthers)
            try audioSession.setActive(true)
        } catch {
            HelixLogger.error("Error setting up audio session for speech recognition", error: error, category: .speech)
            return
        }

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            HelixLogger.speech("Failed to create recognition request", level: .error)
            return
        }
        recognitionRequest.shouldReportPartialResults = true //true
        recognitionRequest.requiresOnDeviceRecognition = true

        recognitionTask = recognizer.recognitionTask(with: recognitionRequest) { [weak self] (result, error) in
            guard let self = self else { return }
            if let error = error {
                HelixLogger.error("Speech recognition error", error: error, category: .speech)
            } else if let result = result {
                    
                let currentTranscription = result.bestTranscription
                if lastTranscription == nil {
                    cacheString = currentTranscription.formattedString
                } else {
                    
                    if (currentTranscription.segments.count < lastTranscription?.segments.count ?? 1 || currentTranscription.segments.count == 1) {
                        self.lastRecognizedText += cacheString
                        cacheString = ""
                    } else {
                        cacheString = currentTranscription.formattedString
                    }
                }
                
                lastTranscription = result.bestTranscription
            }
        }
    }
    
    func stopRecognition() {
        self.lastRecognizedText += cacheString

        HelixLogger.speech("Stopping speech recognition", level: .info, metadata: [
            "textLength": "\(self.lastRecognizedText.count)"
        ])

        DispatchQueue.main.async {
            BluetoothManager.shared.blueSpeechSink?(["script": self.lastRecognizedText])
        }

        recognitionTask?.cancel()
        do {
            try AVAudioSession.sharedInstance().setActive(false)
        } catch {
            HelixLogger.error("Error stopping audio session", error: error, category: .speech)
            return
        }
        recognitionRequest = nil
        recognitionTask = nil
        recognizer = nil
    }

    func appendPCMData(_ pcmData: Data) {
        HelixLogger.speech("Appending PCM data to recognition request", level: .debug, metadata: [
            "dataSize": "\(pcmData.count)"
        ])

        guard let recognitionRequest = recognitionRequest else {
            HelixLogger.speech("Recognition request is not available", level: .warning)
            return
        }

        let audioFormat = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 16000, channels: 1, interleaved: false)!
        guard let audioBuffer = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: AVAudioFrameCount(pcmData.count) / audioFormat.streamDescription.pointee.mBytesPerFrame) else {
            HelixLogger.speech("Failed to create audio buffer", level: .error)
            return
        }
        audioBuffer.frameLength = audioBuffer.frameCapacity

        pcmData.withUnsafeBytes { (bufferPointer: UnsafeRawBufferPointer) in
            if let audioDataPointer = bufferPointer.baseAddress?.assumingMemoryBound(to: Int16.self) {
                let audioBufferPointer = audioBuffer.int16ChannelData?.pointee
                audioBufferPointer?.initialize(from: audioDataPointer, count: pcmData.count / MemoryLayout<Int16>.size)
                recognitionRequest.append(audioBuffer)
            } else {
                HelixLogger.speech("Failed to get pointer to audio data", level: .error)
            }
        }
    }
}

extension SFSpeechRecognizer {
    static func hasAuthorizationToRecognize() async -> Bool {
        await withCheckedContinuation { continuation in
            requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }
}

extension AVAudioSession {
    func hasPermissionToRecord() async -> Bool {
        await withCheckedContinuation { continuation in
            requestRecordPermission { authorized in
                continuation.resume(returning: authorized)
            }
        }
    }
}


