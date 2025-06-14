import AVFoundation
import Accelerate

protocol NoiseReductionProcessorProtocol {
    func processBuffer(_ buffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer
    func updateNoiseProfile(_ buffer: AVAudioPCMBuffer)
    func setReductionLevel(_ level: Float)
}

class NoiseReductionProcessor: NoiseReductionProcessorProtocol {
    private var noiseProfile: [Float] = []
    private var reductionLevel: Float = 0.5
    private let fftSize: Int = 1024
    private let overlapFactor: Float = 0.5
    
    private var fftSetup: FFTSetup?
    private var window: [Float] = []
    
    init() {
        setupFFT()
        setupWindow()
    }
    
    deinit {
        if let fftSetup = fftSetup {
            vDSP_destroy_fftsetup(fftSetup)
        }
    }
    
    func processBuffer(_ buffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer {
        guard let inputData = buffer.floatChannelData?[0],
              let outputBuffer = AVAudioPCMBuffer(pcmFormat: buffer.format, frameCapacity: buffer.frameCapacity) else {
            return buffer
        }
        
        let frameCount = Int(buffer.frameLength)
        let outputData = outputBuffer.floatChannelData![0]
        
        // Apply spectral subtraction noise reduction
        performSpectralSubtraction(input: inputData, output: outputData, frameCount: frameCount)
        
        outputBuffer.frameLength = buffer.frameLength
        return outputBuffer
    }
    
    func updateNoiseProfile(_ buffer: AVAudioPCMBuffer) {
        guard let inputData = buffer.floatChannelData?[0] else { return }
        
        let frameCount = Int(buffer.frameLength)
        
        // Calculate power spectrum for noise profiling
        let powerSpectrum = calculatePowerSpectrum(input: inputData, frameCount: frameCount)
        
        if noiseProfile.isEmpty {
            noiseProfile = powerSpectrum
        } else {
            // Update noise profile with exponential smoothing
            let alpha: Float = 0.1
            for i in 0..<min(noiseProfile.count, powerSpectrum.count) {
                noiseProfile[i] = alpha * powerSpectrum[i] + (1 - alpha) * noiseProfile[i]
            }
        }
    }
    
    func setReductionLevel(_ level: Float) {
        reductionLevel = max(0.0, min(1.0, level))
    }
    
    private func setupFFT() {
        let log2Size = vDSP_Length(log2(Float(fftSize)))
        fftSetup = vDSP_create_fftsetup(log2Size, Int32(kFFTRadix2))
    }
    
    private func setupWindow() {
        window = Array(repeating: 0.0, count: fftSize)
        // Create Hanning window
        for i in 0..<fftSize {
            window[i] = 0.5 * (1.0 - cos(2.0 * Float.pi * Float(i) / Float(fftSize - 1)))
        }
    }
    
    private func performSpectralSubtraction(input: UnsafePointer<Float>, output: UnsafeMutablePointer<Float>, frameCount: Int) {
        guard !noiseProfile.isEmpty,
              let fftSetup = fftSetup else {
            // No noise profile available, copy input to output
            memcpy(output, input, frameCount * MemoryLayout<Float>.size)
            return
        }
        
        let hopSize = Int(Float(fftSize) * (1.0 - overlapFactor))
        var position = 0
        
        // Initialize output buffer
        memset(output, 0, frameCount * MemoryLayout<Float>.size)
        
        while position + fftSize <= frameCount {
            // Apply windowing
            var windowedFrame = Array(repeating: Float(0), count: fftSize)
            for i in 0..<fftSize {
                windowedFrame[i] = input[position + i] * window[i]
            }
            
            // Perform FFT
            let spectrum = performFFT(windowedFrame)
            
            // Apply spectral subtraction
            let cleanSpectrum = applySpectralSubtraction(spectrum)
            
            // Perform inverse FFT
            let cleanFrame = performIFFT(cleanSpectrum)
            
            // Overlap-add
            for i in 0..<fftSize {
                if position + i < frameCount {
                    output[position + i] += cleanFrame[i] * window[i]
                }
            }
            
            position += hopSize
        }
        
        // Normalize output
        normalizeOutput(output, frameCount: frameCount)
    }
    
    private func calculatePowerSpectrum(input: UnsafePointer<Float>, frameCount: Int) -> [Float] {
        guard frameCount >= fftSize else { return [] }
        
        var windowedFrame = Array(repeating: Float(0), count: fftSize)
        for i in 0..<fftSize {
            windowedFrame[i] = input[i] * window[i]
        }
        
        let spectrum = performFFT(windowedFrame)
        return spectrum.map { $0.real * $0.real + $0.imaginary * $0.imaginary }
    }
    
    private func performFFT(_ input: [Float]) -> [DSPComplex] {
        guard let fftSetup = fftSetup else { return [] }
        
        let halfSize = fftSize / 2
        var realPart = Array(repeating: Float(0), count: halfSize)
        var imagPart = Array(repeating: Float(0), count: halfSize)
        
        // Prepare input for vDSP
        for i in 0..<halfSize {
            realPart[i] = input[2 * i]
            imagPart[i] = input[2 * i + 1]
        }
        
        var splitComplex = DSPSplitComplex(realp: &realPart, imagp: &imagPart)
        vDSP_fft_zrip(fftSetup, &splitComplex, 1, vDSP_Length(log2(Float(fftSize))), Int32(FFT_FORWARD))
        
        var result: [DSPComplex] = []
        for i in 0..<halfSize {
            result.append(DSPComplex(real: realPart[i], imag: imagPart[i]))
        }
        
        return result
    }
    
    private func performIFFT(_ spectrum: [DSPComplex]) -> [Float] {
        guard let fftSetup = fftSetup,
              spectrum.count == fftSize / 2 else { return [] }
        
        let halfSize = fftSize / 2
        var realPart = spectrum.map { $0.real }
        var imagPart = spectrum.map { $0.imaginary }
        
        var splitComplex = DSPSplitComplex(realp: &realPart, imagp: &imagPart)
        vDSP_fft_zrip(fftSetup, &splitComplex, 1, vDSP_Length(log2(Float(fftSize))), Int32(FFT_INVERSE))
        
        var result = Array(repeating: Float(0), count: fftSize)
        for i in 0..<halfSize {
            result[2 * i] = realPart[i]
            result[2 * i + 1] = imagPart[i]
        }
        
        // Scale by 1/N for IFFT
        var scale = 1.0 / Float(fftSize)
        vDSP_vsmul(result, 1, &scale, &result, 1, vDSP_Length(fftSize))
        
        return result
    }
    
    private func applySpectralSubtraction(_ spectrum: [DSPComplex]) -> [DSPComplex] {
        guard spectrum.count == noiseProfile.count else { return spectrum }
        
        var result: [DSPComplex] = []
        
        for i in 0..<spectrum.count {
            let magnitude = sqrt(spectrum[i].real * spectrum[i].real + spectrum[i].imaginary * spectrum[i].imaginary)
            let phase = atan2(spectrum[i].imaginary, spectrum[i].real)
            
            let noiseMagnitude = sqrt(noiseProfile[i])
            let subtractedMagnitude = max(magnitude - reductionLevel * noiseMagnitude, 0.1 * magnitude)
            
            let newReal = subtractedMagnitude * cos(phase)
            let newImag = subtractedMagnitude * sin(phase)
            
            result.append(DSPComplex(real: newReal, imag: newImag))
        }
        
        return result
    }
    
    private func normalizeOutput(_ output: UnsafeMutablePointer<Float>, frameCount: Int) {
        var maxValue: Float = 0
        vDSP_maxv(output, 1, &maxValue, vDSP_Length(frameCount))
        
        if maxValue > 0 {
            var scale = 0.95 / maxValue
            vDSP_vsmul(output, 1, &scale, output, 1, vDSP_Length(frameCount))
        }
    }
}

// MARK: - Supporting Types

struct DSPComplex {
    let real: Float
    let imaginary: Float
    
    init(real: Float, imag: Float) {
        self.real = real
        self.imaginary = imag
    }
}