import Foundation
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

enum NativeConversationMode: String, CaseIterable, Identifiable {
    case general = "General"
    case interview = "Interview"
    case passive = "Passive"

    var id: String { rawValue }

    var summary: String {
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

struct NativeMetric: Identifiable {
    let id = UUID()
    let title: String
    let value: String
    let detail: String
    let symbolName: String
    let tint: Color
}

struct NativeTimelineItem: Identifiable {
    let id = UUID()
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
    let id = UUID()
    let title: String
    let count: String
    let detail: String
    let symbolName: String
}

struct NativeHelixPreviewData {
    static let metrics = [
        NativeMetric(
            title: "Mode",
            value: "General",
            detail: "3 sentence limit",
            symbolName: "text.bubble",
            tint: NativeHelixTheme.teal
        ),
        NativeMetric(
            title: "Provider",
            value: "OpenAI",
            detail: "gpt-4.1-mini",
            symbolName: "bolt.horizontal",
            tint: NativeHelixTheme.indigo
        ),
        NativeMetric(
            title: "HUD",
            value: "Bitmap",
            detail: "G1 page-ready",
            symbolName: "rectangle.on.rectangle",
            tint: NativeHelixTheme.green
        )
    ]

    static let timeline = [
        NativeTimelineItem(
            title: "Transcript buffer",
            detail: "Meeting recap and action items are ready for question detection.",
            time: "Now",
            symbolName: "waveform"
        ),
        NativeTimelineItem(
            title: "Detected question",
            detail: "What should I say about the rollout risk?",
            time: "1m",
            symbolName: "questionmark.bubble"
        ),
        NativeTimelineItem(
            title: "HUD answer",
            detail: "Lead with the migration status, then name the remaining device-connectivity risk.",
            time: "1m",
            symbolName: "eyeglasses"
        )
    ]

    static let providers = [
        NativeProviderRow(
            id: "openai",
            name: "OpenAI",
            model: "gpt-4.1-mini",
            status: "Configured",
            tint: NativeHelixTheme.green
        ),
        NativeProviderRow(
            id: "anthropic",
            name: "Anthropic",
            model: "claude-sonnet-4",
            status: "Needs key",
            tint: NativeHelixTheme.amber
        ),
        NativeProviderRow(
            id: "deepseek",
            name: "DeepSeek",
            model: "deepseek-chat",
            status: "Available",
            tint: NativeHelixTheme.indigo
        )
    ]

    static let knowledgeBuckets = [
        NativeKnowledgeBucket(
            title: "Projects",
            count: "4",
            detail: "Active RAG contexts",
            symbolName: "folder"
        ),
        NativeKnowledgeBucket(
            title: "Facts",
            count: "38",
            detail: "Reviewed memory items",
            symbolName: "checkmark.seal"
        ),
        NativeKnowledgeBucket(
            title: "Todos",
            count: "7",
            detail: "Open follow-ups",
            symbolName: "checklist"
        ),
        NativeKnowledgeBucket(
            title: "Citations",
            count: "12",
            detail: "Recent sources",
            symbolName: "link"
        )
    ]
}
