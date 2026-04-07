import ActivityKit
import Foundation

/// Shared data model for the Helix Live Activity (lock screen Q&A).
struct HelixLiveActivityAttributes: ActivityAttributes {
    /// Static data set when the activity starts.
    let mode: String  // "General", "Interview", "Passive", "Proactive"

    /// Dynamic data updated in real time.
    struct ContentState: Codable, Hashable {
        let question: String   // Detected question or "Listening..."
        let answer: String     // AI response (truncated for display)
        let status: String     // "listening", "thinking", "answered", "paused"
        let duration: Int      // Recording duration in seconds
    }
}
