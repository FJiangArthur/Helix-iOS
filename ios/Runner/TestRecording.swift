// ABOUTME: Swift helper to quickly test native AVAudioRecorder functionality from the iOS host.
// ABOUTME: Provides iOS implementation; no-op on non-UIKit platforms to avoid build issues.

#if canImport(UIKit)
import AVFoundation

class TestRecording {
    static func testNativeRecording() {
        let session = AVAudioSession.sharedInstance()
        
        do {
            // Simple recording test using only native AVFoundation APIs.
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
                print("✅ Native recording setup successful")
                print("📍 Recording to: \(url)")
                recorder.record()
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    recorder.stop()
                    print("✅ Native recording test completed")
                }
            } else {
                print("❌ Failed to prepare recorder")
            }
        } catch {
            print("❌ Native recording test failed: \(error)")
        }
    }
}
#else
class TestRecording {
    static func testNativeRecording() {
        print("ℹ️ TestRecording.testNativeRecording is a no-op on this platform")
    }
}
#endif
