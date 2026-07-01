import Foundation
import HelixCore
import SwiftUI

enum NativeHelixTab: String, CaseIterable, Identifiable {
    case assistant
    case device
    case sessions
    case knowledge
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .assistant: return "Assistant"
        case .device: return "Device"
        case .sessions: return "Sessions"
        case .knowledge: return "Knowledge"
        case .settings: return "Settings"
        }
    }

    var symbolName: String {
        switch self {
        case .assistant: return "waveform.and.magnifyingglass"
        case .device: return "eyeglasses"
        case .sessions: return "clock.arrow.circlepath"
        case .knowledge: return "folder.badge.gearshape"
        case .settings: return "slider.horizontal.3"
        }
    }
}

struct NativeMetric: Identifiable {
    let id: String
    let title: String
    let value: String
    let detail: String
    let symbolName: String
    let tint: Color
}

struct NativeTimelineItem: Identifiable {
    let id: String
    let title: String
    let detail: String
    let time: String
    let symbolName: String
}

struct NativeProviderRow: Identifiable {
    let id: String
    let name: String
    let model: String
    let status: String
    let tint: Color
}

struct NativeKnowledgeBucket: Identifiable {
    let id: String
    let title: String
    let count: String
    let detail: String
    let symbolName: String
}

extension ConversationMode {
    var nativeTitle: String {
        switch self {
        case .general: return "General"
        case .interview: return "Interview"
        case .passive: return "Passive"
        }
    }

    var nativeSummary: String {
        switch self {
        case .general:
            return "Concise answers for live conversation."
        case .interview:
            return "Speakable answers with STAR framing."
        case .passive:
            return "Quiet correction and context reminders."
        }
    }
}

extension HudRenderPath {
    var nativeTitle: String {
        switch self {
        case .bitmap: return "Bitmap"
        case .text: return "Text"
        }
    }
}

extension HelixCore.TranscriptionBackend {
    var nativeTitle: String {
        switch self {
        case .appleOnDevice: return "Apple On-Device"
        case .appleCloud: return "Apple Cloud"
        case .openAITranscription: return "OpenAI File"
        case .openAIRealtime: return "OpenAI Realtime"
        }
    }
}

extension WebSearchMode {
    var nativeTitle: String {
        switch self {
        case .disabled: return "Off"
        case .fakeDeterministic: return "Deterministic"
        case .live: return "Live"
        }
    }
}

extension NativeKnowledgeItem.Kind {
    var nativeTitle: String {
        switch self {
        case .fact: return "Fact"
        case .memory: return "Memory"
        case .todo: return "Todo"
        }
    }
}

extension Date {
    var nativeRelativeLabel: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}
