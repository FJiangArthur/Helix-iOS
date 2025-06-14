import AVFoundation
import Accelerate
import Foundation

protocol SpeakerDiarizationEngineProtocol {
    func identifySpeaker(in buffer: AVAudioPCMBuffer) -> SpeakerIdentification?
    func trainSpeakerModel(samples: [AVAudioPCMBuffer], speakerId: UUID) -> Bool
    func addSpeaker(id: UUID, name: String?, isCurrentUser: Bool)
    func removeSpeaker(id: UUID)
    func getCurrentSpeakers() -> [Speaker]
    func resetSpeakerModels()
}

struct SpeakerIdentification {
    let speakerId: UUID
    let confidence: Float
    let audioSegment: AudioSegment
    let embedding: SpeakerEmbedding
    let timestamp: TimeInterval
}

struct AudioSegment {
    let startTime: TimeInterval
    let endTime: TimeInterval
    let buffer: AVAudioPCMBuffer
    let energy: Float
}

public struct SpeakerEmbedding: Codable {
    public let features: [Float]
    public let dimension: Int
    
    public init(features: [Float]) {
        self.features = features
        self.dimension = features.count
    }
    
    func distance(to other: SpeakerEmbedding) -> Float {
        guard features.count == other.features.count else { return Float.greatestFiniteMagnitude }
        
        var distance: Float = 0.0
        vDSP_distancesq(features, 1, other.features, 1, &distance, vDSP_Length(features.count))
        return sqrt(distance)
    }
    
    func cosineSimilarity(to other: SpeakerEmbedding) -> Float {
        guard features.count == other.features.count else { return -1.0 }
        
        var dotProduct: Float = 0.0
        var normA: Float = 0.0
        var normB: Float = 0.0
        
        vDSP_dotpr(features, 1, other.features, 1, &dotProduct, vDSP_Length(features.count))
        vDSP_svesq(features, 1, &normA, vDSP_Length(features.count))
        vDSP_svesq(other.features, 1, &normB, vDSP_Length(features.count))
        
        let denominator = sqrt(normA) * sqrt(normB)
        return denominator > 0 ? dotProduct / denominator : -1.0
    }
}

public struct SpeakerModel: Codable {
    public let speakerId: UUID
    public let embeddings: [SpeakerEmbedding]
    public let centroid: SpeakerEmbedding
    public let threshold: Float
    public let trainingCount: Int
    
    public init(speakerId: UUID, embeddings: [SpeakerEmbedding]) {
        self.speakerId = speakerId
        self.embeddings = embeddings
        self.centroid = SpeakerModel.calculateCentroid(from: embeddings)
        self.threshold = SpeakerModel.calculateThreshold(from: embeddings, centroid: self.centroid)
        self.trainingCount = embeddings.count
    }
    
    private static func calculateCentroid(from embeddings: [SpeakerEmbedding]) -> SpeakerEmbedding {
        guard !embeddings.isEmpty else {
            return SpeakerEmbedding(features: [])
        }
        
        let dimension = embeddings.first?.dimension ?? 0
        var centroidFeatures = Array(repeating: Float(0), count: dimension)
        
        for embedding in embeddings {
            for i in 0..<min(dimension, embedding.features.count) {
                centroidFeatures[i] += embedding.features[i]
            }
        }
        
        let count = Float(embeddings.count)
        for i in 0..<dimension {
            centroidFeatures[i] /= count
        }
        
        return SpeakerEmbedding(features: centroidFeatures)
    }
    
    private static func calculateThreshold(from embeddings: [SpeakerEmbedding], centroid: SpeakerEmbedding) -> Float {
        guard embeddings.count > 1 else { return 0.5 }
        
        let distances = embeddings.map { centroid.distance(to: $0) }
        let mean = distances.reduce(0, +) / Float(distances.count)
        
        let variance = distances.map { pow($0 - mean, 2) }.reduce(0, +) / Float(distances.count)
        let standardDeviation = sqrt(variance)
        
        // Threshold is mean + 2 standard deviations
        return mean + 2 * standardDeviation
    }
    
    func matches(_ embedding: SpeakerEmbedding) -> (matches: Bool, confidence: Float) {
        let distance = centroid.distance(to: embedding)
        let similarity = centroid.cosineSimilarity(to: embedding)
        
        let distanceMatch = distance <= threshold
        let similarityThreshold: Float = 0.7
        let similarityMatch = similarity >= similarityThreshold
        
        let confidence = max(0.0, min(1.0, (similarityThreshold + similarity) / 2.0))
        
        return (distanceMatch && similarityMatch, confidence)
    }
}

class SpeakerDiarizationEngine: SpeakerDiarizationEngineProtocol {
    private var speakers: [UUID: Speaker] = [:]
    private var speakerModels: [UUID: SpeakerModel] = [:]
    private let featureExtractor = VoiceFeatureExtractor()
    
    private let similarityThreshold: Float = 0.7
    private let minSamplesForTraining = 5
    private let maxSpeakers = 8
    
    private let processingQueue = DispatchQueue(label: "speaker.diarization", qos: .userInitiated)
    
    func identifySpeaker(in buffer: AVAudioPCMBuffer) -> SpeakerIdentification? {
        guard let embedding = featureExtractor.extractFeatures(from: buffer) else {
            return nil
        }
        
        var bestMatch: (speakerId: UUID, confidence: Float)?
        var bestDistance: Float = Float.greatestFiniteMagnitude
        
        for (speakerId, model) in speakerModels {
            let result = model.matches(embedding)
            
            if result.matches && result.confidence > (bestMatch?.confidence ?? 0) {
                bestMatch = (speakerId, result.confidence)
                bestDistance = model.centroid.distance(to: embedding)
            }
        }
        
        if let match = bestMatch {
            let audioSegment = AudioSegment(
                startTime: Date().timeIntervalSince1970,
                endTime: Date().timeIntervalSince1970 + Double(buffer.frameLength) / buffer.format.sampleRate,
                buffer: buffer,
                energy: calculateEnergy(buffer)
            )
            
            // Update last seen time
            speakers[match.speakerId]?.lastSeen = Date()
            
            return SpeakerIdentification(
                speakerId: match.speakerId,
                confidence: match.confidence,
                audioSegment: audioSegment,
                embedding: embedding,
                timestamp: Date().timeIntervalSince1970
            )
        }
        
        return nil
    }
    
    func trainSpeakerModel(samples: [AVAudioPCMBuffer], speakerId: UUID) -> Bool {
        guard samples.count >= minSamplesForTraining else {
            print("Not enough samples for training: \(samples.count) < \(minSamplesForTraining)")
            return false
        }
        
        var embeddings: [SpeakerEmbedding] = []
        
        for sample in samples {
            if let embedding = featureExtractor.extractFeatures(from: sample) {
                embeddings.append(embedding)
            }
        }
        
        guard embeddings.count >= minSamplesForTraining else {
            print("Failed to extract enough features for training")
            return false
        }
        
        let model = SpeakerModel(speakerId: speakerId, embeddings: embeddings)
        speakerModels[speakerId] = model
        
        if var speaker = speakers[speakerId] {
            speaker.voiceModel = model
            speakers[speakerId] = speaker
        }
        
        print("Trained speaker model for \(speakerId) with \(embeddings.count) samples")
        return true
    }
    
    func addSpeaker(id: UUID, name: String?, isCurrentUser: Bool = false) {
        let speaker = Speaker(id: id, name: name, isCurrentUser: isCurrentUser)
        speakers[id] = speaker
        print("Added speaker: \(name ?? "Unknown") (\(id))")
    }
    
    func removeSpeaker(id: UUID) {
        speakers.removeValue(forKey: id)
        speakerModels.removeValue(forKey: id)
        print("Removed speaker: \(id)")
    }
    
    func getCurrentSpeakers() -> [Speaker] {
        return Array(speakers.values)
    }
    
    func resetSpeakerModels() {
        speakerModels.removeAll()
        for speakerId in speakers.keys {
            speakers[speakerId]?.voiceModel = nil
        }
        print("Reset all speaker models")
    }
    
    private func calculateEnergy(_ buffer: AVAudioPCMBuffer) -> Float {
        guard let audioData = buffer.floatChannelData?[0] else { return 0.0 }
        
        var energy: Float = 0.0
        vDSP_rmsqv(audioData, 1, &energy, vDSP_Length(buffer.frameLength))
        
        return 20.0 * log10(max(energy, 1e-10))
    }
}

// MARK: - Voice Feature Extractor

class VoiceFeatureExtractor {
    private let fftSize = 512
    private let melFilterCount = 13
    private let sampleRate: Double = 16000
    
    func extractFeatures(from buffer: AVAudioPCMBuffer) -> SpeakerEmbedding? {
        guard let audioData = buffer.floatChannelData?[0],
              buffer.frameLength > 0 else {
            return nil
        }
        
        let frameLength = Int(buffer.frameLength)
        
        // Extract MFCC features
        let mfccFeatures = extractMFCC(audioData: audioData, frameLength: frameLength)
        
        // Extract additional prosodic features
        let prosodyFeatures = extractProsodyFeatures(audioData: audioData, frameLength: frameLength, sampleRate: buffer.format.sampleRate)
        
        // Combine all features
        var allFeatures = mfccFeatures
        allFeatures.append(contentsOf: prosodyFeatures)
        
        return SpeakerEmbedding(features: allFeatures)
    }
    
    private func extractMFCC(audioData: UnsafePointer<Float>, frameLength: Int) -> [Float] {
        // Pre-emphasis filter
        var preEmphasized = Array(repeating: Float(0), count: frameLength)
        let alpha: Float = 0.97
        preEmphasized[0] = audioData[0]
        for i in 1..<frameLength {
            preEmphasized[i] = audioData[i] - alpha * audioData[i-1]
        }
        
        // Window function (Hamming)
        for i in 0..<frameLength {
            let window = 0.54 - 0.46 * cos(2 * Float.pi * Float(i) / Float(frameLength - 1))
            preEmphasized[i] *= window
        }
        
        // Calculate power spectrum
        let powerSpectrum = calculatePowerSpectrum(preEmphasized)
        
        // Apply mel filter bank
        let melSpectrum = applyMelFilterBank(powerSpectrum)
        
        // Apply DCT to get MFCC
        let mfcc = applyDCT(melSpectrum)
        
        return mfcc
    }
    
    private func extractProsodyFeatures(audioData: UnsafePointer<Float>, frameLength: Int, sampleRate: Double) -> [Float] {
        var features: [Float] = []
        
        // Fundamental frequency (F0) estimation
        let f0 = estimateFundamentalFrequency(audioData: audioData, frameLength: frameLength, sampleRate: sampleRate)
        features.append(f0)
        
        // Energy
        var energy: Float = 0.0
        vDSP_rmsqv(audioData, 1, &energy, vDSP_Length(frameLength))
        features.append(20.0 * log10(max(energy, 1e-10)))
        
        // Zero crossing rate
        var zcr: Float = 0.0
        for i in 1..<frameLength {
            if (audioData[i] >= 0) != (audioData[i-1] >= 0) {
                zcr += 1
            }
        }
        zcr /= Float(frameLength - 1)
        features.append(zcr)
        
        // Spectral centroid
        let spectralCentroid = calculateSpectralCentroid(audioData: audioData, frameLength: frameLength, sampleRate: sampleRate)
        features.append(spectralCentroid)
        
        return features
    }
    
    private func calculatePowerSpectrum(_ input: [Float]) -> [Float] {
        let paddedSize = max(fftSize, input.count)
        let log2Size = vDSP_Length(log2(Float(paddedSize)))
        let actualFFTSize = Int(pow(2, ceil(log2(Float(paddedSize)))))
        
        guard let fftSetup = vDSP_create_fftsetup(log2Size, Int32(kFFTRadix2)) else {
            return Array(repeating: 0, count: actualFFTSize / 2)
        }
        
        defer {
            vDSP_destroy_fftsetup(fftSetup)
        }
        
        let halfSize = actualFFTSize / 2
        var paddedInput = Array(repeating: Float(0), count: actualFFTSize)
        
        for i in 0..<min(input.count, actualFFTSize) {
            paddedInput[i] = input[i]
        }
        
        var realPart = Array(repeating: Float(0), count: halfSize)
        var imagPart = Array(repeating: Float(0), count: halfSize)
        
        for i in 0..<halfSize {
            realPart[i] = paddedInput[2 * i]
            if (2 * i + 1) < actualFFTSize {
                imagPart[i] = paddedInput[2 * i + 1]
            }
        }
        
        var splitComplex = DSPSplitComplex(realp: &realPart, imagp: &imagPart)
        vDSP_fft_zrip(fftSetup, &splitComplex, 1, log2Size, Int32(FFT_FORWARD))
        
        var powerSpectrum = Array(repeating: Float(0), count: halfSize)
        vDSP_zvmags(&splitComplex, 1, &powerSpectrum, 1, vDSP_Length(halfSize))
        
        return powerSpectrum
    }
    
    private func applyMelFilterBank(_ powerSpectrum: [Float]) -> [Float] {
        let melFilters = createMelFilterBank(fftSize: fftSize, numFilters: melFilterCount, sampleRate: sampleRate)
        var melSpectrum = Array(repeating: Float(0), count: melFilterCount)
        
        for i in 0..<melFilterCount {
            for j in 0..<min(powerSpectrum.count, melFilters[i].count) {
                melSpectrum[i] += powerSpectrum[j] * melFilters[i][j]
            }
            melSpectrum[i] = log(max(melSpectrum[i], 1e-10))
        }
        
        return melSpectrum
    }
    
    private func applyDCT(_ melSpectrum: [Float]) -> [Float] {
        let numCoeffs = min(13, melSpectrum.count)
        var mfcc = Array(repeating: Float(0), count: numCoeffs)
        
        for i in 0..<numCoeffs {
            for j in 0..<melSpectrum.count {
                let cosValue = cos(Float.pi * Float(i) * (Float(j) + 0.5) / Float(melSpectrum.count))
                mfcc[i] += melSpectrum[j] * cosValue
            }
            
            if i == 0 {
                mfcc[i] *= sqrt(1.0 / Float(melSpectrum.count))
            } else {
                mfcc[i] *= sqrt(2.0 / Float(melSpectrum.count))
            }
        }
        
        return mfcc
    }
    
    private func createMelFilterBank(fftSize: Int, numFilters: Int, sampleRate: Double) -> [[Float]] {
        let lowFreq: Float = 0
        let highFreq = Float(sampleRate / 2)
        
        func hzToMel(_ hz: Float) -> Float {
            return 2595 * log10(1 + hz / 700)
        }
        
        func melToHz(_ mel: Float) -> Float {
            return 700 * (pow(10, mel / 2595) - 1)
        }
        
        let lowMel = hzToMel(lowFreq)
        let highMel = hzToMel(highFreq)
        
        var melPoints = Array(repeating: Float(0), count: numFilters + 2)
        for i in 0..<melPoints.count {
            melPoints[i] = lowMel + Float(i) * (highMel - lowMel) / Float(numFilters + 1)
        }
        
        var hzPoints = melPoints.map { melToHz($0) }
        var binPoints = hzPoints.map { Int($0 * Float(fftSize) / Float(sampleRate)) }
        
        var filterBank = Array(repeating: Array(repeating: Float(0), count: fftSize / 2), count: numFilters)
        
        for i in 0..<numFilters {
            let left = binPoints[i]
            let center = binPoints[i + 1]
            let right = binPoints[i + 2]
            
            for j in left..<center {
                if center > left {
                    filterBank[i][j] = Float(j - left) / Float(center - left)
                }
            }
            
            for j in center..<right {
                if right > center {
                    filterBank[i][j] = Float(right - j) / Float(right - center)
                }
            }
        }
        
        return filterBank
    }
    
    private func estimateFundamentalFrequency(audioData: UnsafePointer<Float>, frameLength: Int, sampleRate: Double) -> Float {
        // Simple autocorrelation-based F0 estimation
        let minPeriod = Int(sampleRate / 800)  // 800 Hz max
        let maxPeriod = Int(sampleRate / 50)   // 50 Hz min
        
        var maxCorrelation: Float = 0.0
        var bestPeriod = 0
        
        for period in minPeriod...min(maxPeriod, frameLength / 2) {
            var correlation: Float = 0.0
            
            for i in 0..<(frameLength - period) {
                correlation += audioData[i] * audioData[i + period]
            }
            
            if correlation > maxCorrelation {
                maxCorrelation = correlation
                bestPeriod = period
            }
        }
        
        return bestPeriod > 0 ? Float(sampleRate) / Float(bestPeriod) : 0.0
    }
    
    private func calculateSpectralCentroid(audioData: UnsafePointer<Float>, frameLength: Int, sampleRate: Double) -> Float {
        let powerSpectrum = calculatePowerSpectrum(Array(UnsafeBufferPointer(start: audioData, count: frameLength)))
        
        var weightedSum: Float = 0.0
        var magnitudeSum: Float = 0.0
        
        for i in 1..<powerSpectrum.count {
            let frequency = Float(i) * Float(sampleRate) / Float(powerSpectrum.count * 2)
            let magnitude = sqrt(powerSpectrum[i])
            
            weightedSum += frequency * magnitude
            magnitudeSum += magnitude
        }
        
        return magnitudeSum > 0 ? weightedSum / magnitudeSum : 0.0
    }
}