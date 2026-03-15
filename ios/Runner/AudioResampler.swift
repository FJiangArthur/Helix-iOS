import Foundation

struct AudioResampler {
    static func resample(pcm16Data: Data, fromRate: Int, toRate: Int) -> Data {
        if fromRate == toRate { return pcm16Data }

        let inputSamples = pcm16Data.withUnsafeBytes {
            Array($0.bindMemory(to: Int16.self))
        }
        guard !inputSamples.isEmpty else { return Data() }

        let ratio = Double(fromRate) / Double(toRate)
        let outputCount = Int(Double(inputSamples.count) / ratio)
        var output = [Int16](repeating: 0, count: outputCount)

        for i in 0..<outputCount {
            let srcIndex = Double(i) * ratio
            let srcIndexInt = Int(srcIndex)
            let frac = srcIndex - Double(srcIndexInt)

            let s0 = inputSamples[min(srcIndexInt, inputSamples.count - 1)]
            let s1 = inputSamples[min(srcIndexInt + 1, inputSamples.count - 1)]

            let interpolated = Double(s0) * (1.0 - frac) + Double(s1) * frac
            output[i] = Int16(clamping: Int(interpolated.rounded()))
        }

        return output.withUnsafeBufferPointer { Data(buffer: $0) }
    }
}
