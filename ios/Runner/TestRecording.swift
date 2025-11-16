// ABOUTME: Swift helper to quickly test native AVAudioRecorder functionality from Flutter environment.
// ABOUTME: Provides iOS implementation; no-op on non-UIKit platforms to avoid build issues.

#if canImport(UIKit)
import AVFoundation

class TestRecording {
    static func testNativeRecording() {
        let session = AVAudioSession.sharedInstance()

        do {
            // Simple recording test without flutter_sound
            try session.setCategory(.playAndRecord, mode: .default)
            try session.setActive(true)

            let settings = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 44100,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ] as [String : Any]

            let url = FileManager.default.temporaryDirectory.appendingPathComponent("test.m4a")
            let recorder = try AVAudioRecorder(url: url, settings: settings)

            if recorder.prepareToRecord() {
                HelixLogger.info("Native recording setup successful", category: .recording, metadata: [
                    "url": url.path,
                    "format": "MPEG4AAC",
                    "sampleRate": "44100",
                    "channels": "1"
                ])
                recorder.record()

                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    recorder.stop()
                    HelixLogger.info("Native recording test completed", category: .recording)
                }
            } else {
                HelixLogger.error("Failed to prepare recorder", category: .recording)
            }
        } catch {
            HelixLogger.error("Native recording test failed", error: error, category: .recording)
        }
    }
}
#else
class TestRecording {
    static func testNativeRecording() {
        HelixLogger.info("TestRecording.testNativeRecording is a no-op on this platform", category: .recording)
    }
}
#endif
