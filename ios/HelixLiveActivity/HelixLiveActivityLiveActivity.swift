import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

struct HelixLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: HelixLiveActivityAttributes.self) { context in
            // Lock Screen presentation
            lockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded regions
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: modeIcon(context.attributes.mode))
                        .font(.title2)
                        .foregroundColor(.cyan)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(formatDuration(context.state.duration))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(spacing: 4) {
                        if !context.state.question.isEmpty {
                            Text(context.state.question)
                                .font(.caption)
                                .foregroundColor(.cyan)
                                .lineLimit(2)
                        }
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 6) {
                        // Answer capped at 2 lines so the button row always
                        // has room inside the Dynamic Island's vertical budget.
                        if !context.state.answer.isEmpty {
                            Text(context.state.answer)
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.8))
                                .lineLimit(2)
                                .truncationMode(.tail)
                        } else if context.state.status == "thinking" {
                            HStack(spacing: 4) {
                                ProgressView()
                                    .scaleEffect(0.6)
                                Text("Thinking...")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        HStack(spacing: 12) {
                            Button(intent: AskQuestionIntent()) {
                                Image(systemName: "questionmark.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(.cyan)
                                    .frame(width: 44, height: 44)
                                    .background(Color.cyan.opacity(0.15), in: Circle())
                                    .overlay(Circle().stroke(Color.cyan.opacity(0.4), lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                            if context.state.status == "paused" {
                                Button(intent: ResumeTranscriptionIntent()) {
                                    Image(systemName: "play.circle.fill")
                                        .font(.title2)
                                        .foregroundColor(.green)
                                        .frame(width: 44, height: 44)
                                        .background(Color.green.opacity(0.15), in: Circle())
                                        .overlay(Circle().stroke(Color.green.opacity(0.4), lineWidth: 1))
                                }
                                .buttonStyle(.plain)
                            } else {
                                Button(intent: PauseTranscriptionIntent()) {
                                    Image(systemName: "pause.circle.fill")
                                        .font(.title2)
                                        .foregroundColor(.yellow)
                                        .frame(width: 44, height: 44)
                                        .background(Color.yellow.opacity(0.15), in: Circle())
                                        .overlay(Circle().stroke(Color.yellow.opacity(0.4), lineWidth: 1))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            } compactLeading: {
                Image(systemName: modeIcon(context.attributes.mode))
                    .foregroundColor(.cyan)
            } compactTrailing: {
                Text(statusEmoji(context.state.status))
            } minimal: {
                Image(systemName: "brain.head.profile")
                    .foregroundColor(.cyan)
            }
        }
    }

    @ViewBuilder
    private func lockScreenView(context: ActivityViewContext<HelixLiveActivityAttributes>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header: mode + duration
            HStack {
                Image(systemName: modeIcon(context.attributes.mode))
                    .foregroundColor(.cyan)
                    .font(.subheadline)
                Text(context.attributes.mode)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.cyan)
                Spacer()
                if context.state.status == "listening" {
                    Circle()
                        .fill(.red)
                        .frame(width: 8, height: 8)
                }
                Text(formatDuration(context.state.duration))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Question
            if !context.state.question.isEmpty && context.state.question != "Listening..." {
                HStack(alignment: .top, spacing: 6) {
                    Text("Q")
                        .font(.caption.weight(.bold))
                        .foregroundColor(.cyan)
                        .frame(width: 16)
                    Text(context.state.question)
                        .font(.subheadline)
                        .foregroundColor(.white)
                        .lineLimit(2)
                }
            } else {
                HStack(spacing: 6) {
                    Image(systemName: "waveform")
                        .foregroundColor(.cyan.opacity(0.6))
                    Text("Listening...")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.5))
                }
            }

            // Answer — cap at 2 lines so the button row below always has room.
            // iOS Live Activity has a strict vertical budget; letting the
            // answer expand to 4 lines pushes the buttons off-screen.
            if !context.state.answer.isEmpty {
                HStack(alignment: .top, spacing: 6) {
                    Text("A")
                        .font(.caption.weight(.bold))
                        .foregroundColor(.green)
                        .frame(width: 16)
                    Text(context.state.answer)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.85))
                        .lineLimit(2)
                        .truncationMode(.tail)
                }
            } else if context.state.status == "thinking" {
                HStack(spacing: 6) {
                    ProgressView()
                        .scaleEffect(0.7)
                        .tint(.green)
                    Text("Generating response...")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.5))
                }
            }

            HStack(spacing: 10) {
                Button(intent: AskQuestionIntent()) {
                    Label("Ask", systemImage: "questionmark.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.cyan)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(Color.cyan.opacity(0.15), in: Capsule())
                        .overlay(Capsule().stroke(Color.cyan.opacity(0.4), lineWidth: 1))
                }
                .buttonStyle(.plain)

                if context.state.status == "paused" {
                    Button(intent: ResumeTranscriptionIntent()) {
                        Label("Resume", systemImage: "play.circle.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.green)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background(Color.green.opacity(0.15), in: Capsule())
                            .overlay(Capsule().stroke(Color.green.opacity(0.4), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                } else {
                    Button(intent: PauseTranscriptionIntent()) {
                        Label("Pause", systemImage: "pause.circle.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.yellow)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background(Color.yellow.opacity(0.15), in: Capsule())
                            .overlay(Capsule().stroke(Color.yellow.opacity(0.4), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, 6)
        }
        .padding(16)
        .background(Color.black)
    }

    private func modeIcon(_ mode: String) -> String {
        switch mode.lowercased() {
        case "interview": return "briefcase.fill"
        case "passive": return "ear.fill"
        case "proactive": return "brain.head.profile"
        default: return "bubble.left.and.bubble.right.fill"
        }
    }

    private func statusEmoji(_ status: String) -> String {
        switch status {
        case "listening": return "🎙"
        case "thinking": return "💭"
        case "answered": return "✅"
        default: return "⏸"
        }
    }

    private func formatDuration(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }
}
