import AVFoundation

struct AudioResampler {
    static func resample(pcm16Data: Data, fromRate: Int, toRate: Int) -> Data {
        if fromRate == toRate { return pcm16Data }
        guard !pcm16Data.isEmpty else { return Data() }

        guard let inputFormat = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: Double(fromRate),
            channels: 1,
            interleaved: false
        ),
        let outputFormat = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: Double(toRate),
            channels: 1,
            interleaved: false
        ) else {
            return pcm16Data
        }

        guard let converter = AVAudioConverter(from: inputFormat, to: outputFormat) else {
            return pcm16Data
        }

        let inputFrameCount = pcm16Data.count / MemoryLayout<Int16>.size
        guard let inputBuffer = AVAudioPCMBuffer(
            pcmFormat: inputFormat,
            frameCapacity: AVAudioFrameCount(inputFrameCount)
        ) else {
            return pcm16Data
        }

        inputBuffer.frameLength = AVAudioFrameCount(inputFrameCount)
        pcm16Data.withUnsafeBytes { rawBuffer in
            guard let src = rawBuffer.baseAddress?.assumingMemoryBound(to: Int16.self) else { return }
            inputBuffer.int16ChannelData?.pointee.initialize(from: src, count: inputFrameCount)
        }

        let outputFrameCapacity = AVAudioFrameCount(
            ceil(Double(inputFrameCount) * Double(toRate) / Double(fromRate))
        )
        guard let outputBuffer = AVAudioPCMBuffer(
            pcmFormat: outputFormat,
            frameCapacity: max(outputFrameCapacity, 1)
        ) else {
            return pcm16Data
        }

        var didProvideInput = false
        var conversionError: NSError?
        let status = converter.convert(to: outputBuffer, error: &conversionError) { _, outStatus in
            if didProvideInput {
                outStatus.pointee = .noDataNow
                return nil
            }
            didProvideInput = true
            outStatus.pointee = .haveData
            return inputBuffer
        }

        guard (status == .haveData || status == .inputRanDry),
              outputBuffer.frameLength > 0,
              let channelData = outputBuffer.int16ChannelData else {
            return pcm16Data
        }

        let byteCount = Int(outputBuffer.frameLength) * MemoryLayout<Int16>.size
        return Data(bytes: channelData.pointee, count: byteCount)
    }
}
