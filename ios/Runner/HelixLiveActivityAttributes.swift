import ActivityKit
import Foundation

/// Shared data model for the Helix Live Activity (lock screen Q&A).
struct HelixLiveActivityAttributes: ActivityAttributes {
    /// Static data set when the activity starts.
    let mode: String  // "General", "Interview", "Passive", "Proactive"
    /// Session start timestamp. The widget renders elapsed time locally
    /// via `Text(timerInterval:)` off this value, so the app never needs
    /// to push a new content state just to advance the seconds counter.
    /// Eliminates the 1 Hz ActivityKit update storm that was driving
    /// chronod + runningboardd wakeups during recording (Tier-1 thermal).
    let startedAt: Date

    /// Dynamic data updated in real time.
    struct ContentState: Codable, Hashable {
        let question: String   // Detected question or "Listening..."
        let answer: String     // AI response (truncated for display)
        let status: String     // "listening", "thinking", "answered", "paused"
    }
}
