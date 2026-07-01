import HelixCore
import HelixRuntime
import SwiftUI

@MainActor
struct NativeAssistantView: View {
    let runtime: HelixRuntimeDependencies
    @Binding var draftQuestion: String

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                AssistantWorkspacePanel(
                    runtime: runtime,
                    draftQuestion: $draftQuestion,
                    timelineItems: timelineItems
                )
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .scrollContentBackground(.hidden)
    }

    private var timelineItems: [NativeTimelineItem] {
        runtime.assistantSession.eventLog.suffix(5).enumerated().map { index, event in
            NativeTimelineItem(
                id: "\(index)-\(event)",
                title: eventTitle(for: event),
                detail: event,
                time: "Now",
                symbolName: eventSymbol(for: event)
            )
        }
    }

    private func eventTitle(for event: String) -> String {
        if event.contains("answerCompleted") { return "Answer completed" }
        if event.contains("hudPagesUpdated") { return "HUD pages updated" }
        if event.contains("questionDetected") || event.contains("manualQuestion") { return "Question routed" }
        if event.contains("transcriptFinal") { return "Transcript finalized" }
        if event.contains("failure") { return "Runtime failure" }
        return "Runtime event"
    }

    private func eventSymbol(for event: String) -> String {
        if event.contains("answer") { return "sparkles" }
        if event.contains("hud") { return "eyeglasses" }
        if event.contains("question") { return "questionmark.bubble" }
        if event.contains("transcript") { return "waveform" }
        if event.contains("failure") { return "exclamationmark.triangle" }
        return "circle.dashed"
    }
}

@MainActor
private struct AssistantWorkspacePanel: View {
    let runtime: HelixRuntimeDependencies
    @Binding var draftQuestion: String
    let timelineItems: [NativeTimelineItem]

    var body: some View {
        NativeSection("Assistant", subtitle: runtime.assistantSession.mode.nativeSummary) {
            VStack(alignment: .leading, spacing: 14) {
                Picker("Conversation mode", selection: modeBinding) {
                    ForEach(ConversationMode.allCases, id: \.self) { mode in
                        Text(mode.nativeTitle).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                HStack(spacing: 10) {
                    NativeStatusPill(
                        text: runtime.assistantSession.statusText,
                        tint: runtime.assistantSession.isRunning ? NativeHelixTheme.green : NativeHelixTheme.secondaryInk
                    )
                    Spacer(minLength: 0)
                    NativeIconButton(
                        symbolName: "eyeglasses",
                        isPrimary: true,
                        isDisabled: currentAnswerText.isEmpty,
                        accessibilityLabel: "Send current answer to G1",
                        action: sendCurrentAnswerToHud
                    )
                    NativeIconButton(
                        symbolName: "tray.and.arrow.down",
                        isDisabled: !canSaveSession,
                        accessibilityLabel: "Save current session",
                        action: saveSession
                    )
                }

                CompactTagGrid(values: contextTags)

                HStack(spacing: 10) {
                    TextField("Ask or paste a question", text: $draftQuestion, axis: .vertical)
                        .textFieldStyle(.plain)
                        .font(.body)
                        .lineLimit(1...3)
                        .padding(.horizontal, 12)
                        .frame(minHeight: 44)
                        .background(NativeHelixTheme.background)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(NativeHelixTheme.hairline)
                        }

                    NativeIconButton(
                        symbolName: runtime.assistantSession.isRunning ? "hourglass" : "arrow.up",
                        isPrimary: true,
                        isDisabled: trimmedQuestion.isEmpty || runtime.assistantSession.isRunning,
                        accessibilityLabel: "Ask Helix",
                        action: askQuestion
                    )
                }

                Divider()

                LiveWorkspaceRow(
                    title: "Answer",
                    value: currentAnswerText,
                    emptyValue: "Answers will appear here before being sent to the G1 HUD.",
                    symbolName: "sparkles",
                    tint: NativeHelixTheme.green
                )
                Divider()
                LiveWorkspaceRow(
                    title: "Detected question",
                    value: runtime.assistantSession.detectedQuestion,
                    emptyValue: "Ask manually or start a listening run.",
                    symbolName: "questionmark.bubble",
                    tint: NativeHelixTheme.indigo
                )
                Divider()
                LiveWorkspaceRow(
                    title: "Transcript",
                    value: runtime.assistantSession.transcriptText,
                    emptyValue: "No finalized transcript yet.",
                    symbolName: "waveform",
                    tint: NativeHelixTheme.teal
                )

                if !timelineItems.isEmpty {
                    Divider()
                    AssistantActivityHeader(count: timelineItems.count)
                    RecentActivityList(items: timelineItems)
                }
            }
        }
    }

    private var modeBinding: Binding<ConversationMode> {
        Binding(
            get: { runtime.assistantSession.mode },
            set: { runtime.assistantSession.setMode($0) }
        )
    }

    private var trimmedQuestion: String {
        draftQuestion.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var currentAnswerText: String {
        if !runtime.assistantSession.currentAnswer.isEmpty {
            return runtime.assistantSession.currentAnswer
        }
        return runtime.assistantSession.passiveReminder
    }

    private var contextTags: [String] {
        [
            "\(runtime.activeProviderName) - \(runtime.settings.llmModel)",
            "\(runtime.settings.hudRenderPath.nativeTitle) - \(runtime.g1DeviceState.currentPageSummary)"
        ]
    }

    private var canSaveSession: Bool {
        !runtime.assistantSession.detectedQuestion.isEmpty || !currentAnswerText.isEmpty
    }

    private func askQuestion() {
        let question = trimmedQuestion
        Task {
            await runtime.assistantSession.ask(question, mode: runtime.assistantSession.mode)
            draftQuestion = ""
        }
    }

    private func sendCurrentAnswerToHud() {
        runtime.g1DeviceState.presentText(currentAnswerText)
    }

    private func saveSession() {
        let question = runtime.assistantSession.detectedQuestion
        let answer = currentAnswerText
        let title = question.isEmpty ? "Native Helix Session" : question
        Task {
            await runtime.sessionArchive.archiveSession(
                NativeSessionSummary(
                    title: title,
                    mode: runtime.assistantSession.mode,
                    transcriptPreview: runtime.assistantSession.transcriptText,
                    answerPreview: answer,
                    projectName: runtime.knowledgeLibrary.snapshot.activeProject?.name,
                    segmentCount: runtime.assistantSession.transcriptText.isEmpty ? 0 : 1,
                    answerCount: answer.isEmpty ? 0 : 1,
                    skillValue: runtime.assistantSession.activeSkill.value,
                    transcriptTurns: [runtime.assistantSession.transcriptText].filter { !$0.isEmpty },
                    answers: [answer].filter { !$0.isEmpty },
                    passiveReminders: [runtime.assistantSession.passiveReminder].filter { !$0.isEmpty },
                    latencyMetrics: runtime.assistantSession.latencyMetrics
                )
            )
        }
    }
}

private struct AssistantActivityHeader: View {
    let count: Int

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(NativeHelixTheme.teal)
                .frame(width: 22, height: 22)
            Text("Recent activity")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(NativeHelixTheme.ink)
            Spacer(minLength: 0)
            Text("\(count)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(NativeHelixTheme.secondaryInk)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct RecentActivityList: View {
    let items: [NativeTimelineItem]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(items) { item in
                TimelineRow(item: item)
                if item.id != items.last?.id {
                    Divider().padding(.leading, 34)
                }
            }
        }
    }
}

private struct LiveWorkspaceRow: View {
    let title: String
    let value: String
    let emptyValue: String
    let symbolName: String
    let tint: Color

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbolName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 22, height: 22)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(NativeHelixTheme.secondaryInk)
                Text(value.isEmpty ? emptyValue : value)
                    .font(.subheadline)
                    .foregroundStyle(value.isEmpty ? NativeHelixTheme.secondaryInk : NativeHelixTheme.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct TimelineRow: View {
    let item: NativeTimelineItem

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: item.symbolName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(NativeHelixTheme.teal)
                .frame(width: 22, height: 22)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(item.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(NativeHelixTheme.ink)
                    Spacer()
                    Text(item.time)
                        .font(.caption)
                        .foregroundStyle(NativeHelixTheme.secondaryInk)
                }
                Text(item.detail)
                    .font(.footnote)
                    .foregroundStyle(NativeHelixTheme.secondaryInk)
            }
        }
        .padding(.vertical, 10)
    }
}
