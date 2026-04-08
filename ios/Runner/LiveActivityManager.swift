import ActivityKit
import Foundation

/// Manages the Helix Live Activity lifecycle: start, update, end.
/// Called from AppDelegate via method channel from Dart.
class LiveActivityManager {
    static let shared = LiveActivityManager()

    private var currentActivity: Activity<HelixLiveActivityAttributes>?

    /// Start a new Live Activity for the given conversation mode.
    func startActivity(mode: String) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            print("[LiveActivity] Activities not enabled")
            return
        }

        // End any existing activity first
        endActivity()

        let attributes = HelixLiveActivityAttributes(mode: mode, startedAt: Date())
        let initialState = HelixLiveActivityAttributes.ContentState(
            question: "Listening...",
            answer: "",
            status: "listening"
        )

        do {
            let content = ActivityContent(state: initialState, staleDate: nil)
            let activity = try Activity<HelixLiveActivityAttributes>.request(
                attributes: attributes,
                content: content,
                pushType: nil
            )
            currentActivity = activity
            print("[LiveActivity] Started: \(activity.id)")
        } catch {
            print("[LiveActivity] Failed to start: \(error)")
        }
    }

    /// Update the Live Activity with new Q&A content.
    /// Note: elapsed time is rendered by the widget off the immutable
    /// `startedAt` attribute, so this intentionally does not accept a
    /// duration parameter — adding one would re-introduce the 1 Hz
    /// ActivityKit update storm the `startedAt` field was added to kill.
    func updateActivity(question: String, answer: String, status: String) {
        guard let activity = currentActivity else { return }

        let updatedState = HelixLiveActivityAttributes.ContentState(
            question: question,
            answer: answer,
            status: status
        )

        Task {
            let content = ActivityContent(state: updatedState, staleDate: nil)
            await activity.update(content)
        }
    }

    /// End the current Live Activity.
    func endActivity() {
        guard let activity = currentActivity else { return }

        let finalState = HelixLiveActivityAttributes.ContentState(
            question: "Session ended",
            answer: "",
            status: "ended"
        )

        Task {
            let content = ActivityContent(state: finalState, staleDate: nil)
            await activity.end(content, dismissalPolicy: .immediate)
        }
        currentActivity = nil
        print("[LiveActivity] Ended")
    }

    /// End all Live Activities for this app — cleans up stale activities
    /// that survived an app crash or force-kill.
    func cleanupStaleActivities() {
        let activities = Activity<HelixLiveActivityAttributes>.activities
        guard !activities.isEmpty else { return }
        print("[LiveActivity] Cleaning up \(activities.count) stale activities")
        for activity in activities {
            Task {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
        currentActivity = nil
    }
}
