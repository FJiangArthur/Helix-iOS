import AVFoundation
import Accelerate

protocol VoiceActivityDetectorProtocol {
    func detectVoiceActivity(in buffer: AVAudioPCMBuffer) -> VoiceActivityResult
    func updateBackground(with buffer: AVAudioPCMBuffer)
    func setSensitivity(_ sensitivity: Float)
}

struct VoiceActivityResult {
    let hasVoice: Bool
    let confidence: Float
    let energy: Float
    let spectralCentroid: Float
    let zeroCrossingRate: Float
    let timestamp: TimeInterval
}

class VoiceActivityDetector: VoiceActivityDetectorProtocol {
    private var backgroundEnergyLevel: Float = 0.0
    private var backgroundSpectralCentroid: Float = 0.0
    private var sensitivity: Float = 0.5
    private let adaptationRate: Float = 0.01
    
    // Thresholds for voice detection
    private let energyThresholdMultiplier: Float = 2.5
    private let spectralCentroidThreshold: Float = 1000.0
    private let zeroCrossingRateThreshold: Float = 0.1
    
    private var frameCount: Int = 0
    
    func detectVoiceActivity(in buffer: AVAudioPCMBuffer) -> VoiceActivityResult {
        guard let audioData = buffer.floatChannelData?[0] else {
            return VoiceActivityResult(
                hasVoice: false,
                confidence: 0.0,
                energy: 0.0,
                spectralCentroid: 0.0,
                zeroCrossingRate: 0.0,
                timestamp: Date().timeIntervalSince1970
            )
        }
        
        let frameLength = Int(buffer.frameLength)
        let sampleRate = buffer.format.sampleRate
        
        // Calculate audio features
        let energy = calculateEnergy(audioData, frameLength: frameLength)
        let spectralCentroid = calculateSpectralCentroid(audioData, frameLength: frameLength, sampleRate: sampleRate)
        let zeroCrossingRate = calculateZeroCrossingRate(audioData, frameLength: frameLength, sampleRate: sampleRate)
        
        // Determine voice activity
        let hasVoice = isVoiceDetected(energy: energy, spectralCentroid: spectralCentroid, zeroCrossingRate: zeroCrossingRate)
        let confidence = calculateConfidence(energy: energy, spectralCentroid: spectralCentroid, zeroCrossingRate: zeroCrossingRate)
        
        return VoiceActivityResult(
            hasVoice: hasVoice,
            confidence: confidence,
            energy: energy,
            spectralCentroid: spectralCentroid,
            zeroCrossingRate: zeroCrossingRate,
            timestamp: Date().timeIntervalSince1970
        )
    }
    
    func updateBackground(with buffer: AVAudioPCMBuffer) {
        guard let audioData = buffer.floatChannelData?[0] else { return }
        
        let frameLength = Int(buffer.frameLength)
        let sampleRate = buffer.format.sampleRate
        
        let energy = calculateEnergy(audioData, frameLength: frameLength)
        let spectralCentroid = calculateSpectralCentroid(audioData, frameLength: frameLength, sampleRate: sampleRate)
        
        // Update background levels with exponential smoothing
        if frameCount == 0 {
            backgroundEnergyLevel = energy
            backgroundSpectralCentroid = spectralCentroid
        } else {
            backgroundEnergyLevel = adaptationRate * energy + (1 - adaptationRate) * backgroundEnergyLevel
            backgroundSpectralCentroid = adaptationRate * spectralCentroid + (1 - adaptationRate) * backgroundSpectralCentroid
        }
        
        frameCount += 1
    }
    
    func setSensitivity(_ sensitivity: Float) {
        self.sensitivity = max(0.0, min(1.0, sensitivity))
    }
    
    private func calculateEnergy(_ audioData: UnsafePointer<Float>, frameLength: Int) -> Float {
        var energy: Float = 0.0
        
        // Calculate RMS energy
        vDSP_rmsqv(audioData, 1, &energy, vDSP_Length(frameLength))
        
        // Convert to dB
        let energyDB = 20.0 * log10(max(energy, 1e-10))
        
        return energyDB
    }
    
    private func calculateSpectralCentroid(_ audioData: UnsafePointer<Float>, frameLength: Int, sampleRate: Double) -> Float {
        guard frameLength > 0 else { return 0.0 }
        
        // Calculate FFT size (next power of 2)
        let fftSize = Int(pow(2, ceil(log2(Double(frameLength)))))
        let halfFFTSize = fftSize / 2
        
        // Prepare data for FFT
        var fftInput = Array(repeating: Float(0), count: fftSize)
        for i in 0..<min(frameLength, fftSize) {
            fftInput[i] = audioData[i]
        }
        
        // Apply window function (Hamming)
        for i in 0..<fftSize {
            let window = 0.54 - 0.46 * cos(2 * Float.pi * Float(i) / Float(fftSize - 1))
            fftInput[i] *= window
        }
        
        // Calculate magnitude spectrum
        let magnitudeSpectrum = calculateMagnitudeSpectrum(fftInput, fftSize: fftSize)
        
        // Calculate spectral centroid
        var weightedSum: Float = 0.0
        var magnitudeSum: Float = 0.0
        
        for i in 1..<halfFFTSize {
            let frequency = Float(i) * Float(sampleRate) / Float(fftSize)
            let magnitude = magnitudeSpectrum[i]
            
            weightedSum += frequency * magnitude
            magnitudeSum += magnitude
        }
        
        return magnitudeSum > 0 ? weightedSum / magnitudeSum : 0.0
    }
    
    private func calculateZeroCrossingRate(_ audioData: UnsafePointer<Float>, frameLength: Int, sampleRate: Double) -> Float {
        guard frameLength > 1 else { return 0.0 }
        
        var zeroCrossings = 0
        
        for i in 1..<frameLength {
            if (audioData[i] >= 0) != (audioData[i-1] >= 0) {
                zeroCrossings += 1
            }
        }
        
        return Float(zeroCrossings) / Float(frameLength - 1) * Float(sampleRate) / 2.0
    }
    
    private func calculateMagnitudeSpectrum(_ input: [Float], fftSize: Int) -> [Float] {
        let halfSize = fftSize / 2
        let log2Size = vDSP_Length(log2(Float(fftSize)))
        
        guard let fftSetup = vDSP_create_fftsetup(log2Size, Int32(kFFTRadix2)) else {
            return Array(repeating: 0, count: halfSize)
        }
        
        defer {
            vDSP_destroy_fftsetup(fftSetup)
        }
        
        var realPart = Array(repeating: Float(0), count: halfSize)
        var imagPart = Array(repeating: Float(0), count: halfSize)
        
        // Prepare input for vDSP (interleaved to split)
        for i in 0..<halfSize {
            realPart[i] = input[2 * i]
            if (2 * i + 1) < fftSize {
                imagPart[i] = input[2 * i + 1]
            }
        }
        
        var splitComplex = DSPSplitComplex(realp: &realPart, imagp: &imagPart)
        vDSP_fft_zrip(fftSetup, &splitComplex, 1, log2Size, Int32(FFT_FORWARD))
        
        // Calculate magnitude
        var magnitude = Array(repeating: Float(0), count: halfSize)
        vDSP_zvmags(&splitComplex, 1, &magnitude, 1, vDSP_Length(halfSize))
        
        // Take square root to get magnitude from power
        var sqrtMagnitude = Array(repeating: Float(0), count: halfSize)
        vvsqrtf(&sqrtMagnitude, magnitude, [Int32(halfSize)])
        
        return sqrtMagnitude
    }
    
    private func isVoiceDetected(energy: Float, spectralCentroid: Float, zeroCrossingRate: Float) -> Bool {
        // Energy-based detection
        let energyThreshold = backgroundEnergyLevel + (energyThresholdMultiplier * (1.0 - sensitivity))
        let energyCondition = energy > energyThreshold
        
        // Spectral centroid-based detection (voice typically has higher spectral centroid than noise)
        let spectralCondition = spectralCentroid > spectralCentroidThreshold
        
        // Zero crossing rate condition (voice has moderate ZCR)
        let zcrCondition = zeroCrossingRate > zeroCrossingRateThreshold && zeroCrossingRate < 10 * zeroCrossingRateThreshold
        
        // Combine conditions
        return energyCondition && (spectralCondition || zcrCondition)
    }
    
    private func calculateConfidence(energy: Float, spectralCentroid: Float, zeroCrossingRate: Float) -> Float {
        let energyThreshold = backgroundEnergyLevel + energyThresholdMultiplier
        let energyConfidence = max(0.0, min(1.0, (energy - backgroundEnergyLevel) / energyThreshold))
        
        let spectralConfidence = max(0.0, min(1.0, spectralCentroid / (2 * spectralCentroidThreshold)))
        
        let zcrConfidence: Float
        if zeroCrossingRate < zeroCrossingRateThreshold {
            zcrConfidence = 0.0
        } else if zeroCrossingRate > 10 * zeroCrossingRateThreshold {
            zcrConfidence = 0.0
        } else {
            zcrConfidence = 1.0 - abs(zeroCrossingRate - 5 * zeroCrossingRateThreshold) / (5 * zeroCrossingRateThreshold)
        }
        
        // Weighted combination
        return 0.5 * energyConfidence + 0.3 * spectralConfidence + 0.2 * zcrConfidence
    }
}