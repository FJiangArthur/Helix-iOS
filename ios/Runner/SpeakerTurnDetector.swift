import Foundation

/// Energy-based speaker turn detector.  Groups words by silence gaps,
/// computes RMS energy for each segment from the raw PCM, and clusters
/// into two speakers by energy (higher energy = "wearer" because the
/// glasses mic is physically closer to the wearer).
class SpeakerTurnDetector {

    struct SpeakerSegment {
        let text: String
        let speaker: String   // "wearer" or "other"
        let startTime: Double
        let endTime: Double
    }

    /// Minimum silence gap in seconds between words to start a new segment.
    var silenceGapThreshold: Double = 1.5

    /// Sample rate of the PCM data passed to `detectTurns`.
    private static let sampleRate: Int = 16000

    // MARK: - Public API

    /// Detect speaker turns from Whisper word timestamps and corresponding PCM audio.
    ///
    /// - Parameters:
    ///   - words: Word-level timestamps from WhisperBatchTranscriber.
    ///   - pcmData: Raw PCM16 audio (16kHz mono, little-endian Int16) covering
    ///              the same time span as the words.
    ///   - sampleRate: Sample rate of pcmData (default 16000).
    /// - Returns: Array of speaker segments with labels.
    func detectTurns(words: [WhisperWord], pcmData: Data, sampleRate: Int = 16000) -> [SpeakerSegment] {
        guard !words.isEmpty else { return [] }

        // Step 1: Group consecutive words separated by gaps > threshold into segments
        let groups = groupWordsByGap(words: words)

        // Step 2: Compute RMS energy for each segment from the PCM data
        var segmentsWithEnergy: [(group: [WhisperWord], rms: Float)] = []
        for group in groups {
            guard let first = group.first, let last = group.last else { continue }
            let rms = computeRMSForTimeRange(
                pcmData: pcmData,
                sampleRate: sampleRate,
                startTime: first.start,
                endTime: last.end
            )
            segmentsWithEnergy.append((group, rms))
        }

        guard !segmentsWithEnergy.isEmpty else { return [] }

        // Step 3: Cluster into 2 groups by energy using median split
        let sortedByEnergy = segmentsWithEnergy.map { $0.rms }.sorted()
        let medianRMS = sortedByEnergy[sortedByEnergy.count / 2]

        // Step 4: Label - higher energy cluster is "wearer"
        var results: [SpeakerSegment] = []
        for (group, rms) in segmentsWithEnergy {
            guard let first = group.first, let last = group.last else { continue }
            let text = group.map { $0.word }.joined(separator: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let speaker = rms >= medianRMS ? "wearer" : "other"
            results.append(SpeakerSegment(
                text: text,
                speaker: speaker,
                startTime: first.start,
                endTime: last.end
            ))
        }

        return results
    }

    // MARK: - Word grouping

    /// Group words into segments separated by silence gaps exceeding the threshold.
    private func groupWordsByGap(words: [WhisperWord]) -> [[WhisperWord]] {
        var groups: [[WhisperWord]] = []
        var currentGroup: [WhisperWord] = []

        for word in words {
            if let lastWord = currentGroup.last {
                let gap = word.start - lastWord.end
                if gap > silenceGapThreshold {
                    groups.append(currentGroup)
                    currentGroup = [word]
                } else {
                    currentGroup.append(word)
                }
            } else {
                currentGroup.append(word)
            }
        }

        if !currentGroup.isEmpty {
            groups.append(currentGroup)
        }

        return groups
    }

    // MARK: - RMS energy computation

    /// Compute RMS energy from a slice of PCM16 data corresponding to a time range.
    private func computeRMSForTimeRange(
        pcmData: Data,
        sampleRate: Int,
        startTime: Double,
        endTime: Double
    ) -> Float {
        let bytesPerSample = MemoryLayout<Int16>.size
        let totalSamples = pcmData.count / bytesPerSample

        let startSample = max(0, Int(startTime * Double(sampleRate)))
        let endSample = min(totalSamples, Int(endTime * Double(sampleRate)))

        guard startSample < endSample else { return 0 }

        let count = endSample - startSample
        var sumSquares: Float = 0

        pcmData.withUnsafeBytes { rawBuffer in
            guard let ptr = rawBuffer.baseAddress?.assumingMemoryBound(to: Int16.self) else { return }
            for i in startSample..<endSample {
                let sample = Float(ptr[i]) / Float(Int16.max)
                sumSquares += sample * sample
            }
        }

        return sqrt(sumSquares / Float(count))
    }
}
