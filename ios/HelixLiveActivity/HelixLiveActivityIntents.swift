import AppIntents

struct AskQuestionIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Ask Question"
    init() {}
    func perform() async throws -> some IntentResult {
        HelixLiveActivityIntentBridge.post(.askQuestion)
        return .result()
    }
}

struct PauseTranscriptionIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Pause"
    init() {}
    func perform() async throws -> some IntentResult {
        HelixLiveActivityIntentBridge.post(.pauseTranscription)
        return .result()
    }
}

struct ResumeTranscriptionIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Resume"
    init() {}
    func perform() async throws -> some IntentResult {
        HelixLiveActivityIntentBridge.post(.resumeTranscription)
        return .result()
    }
}
