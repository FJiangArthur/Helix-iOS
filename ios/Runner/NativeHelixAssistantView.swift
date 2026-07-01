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
                AssistantCommandBand(
                    runtime: runtime,
                    draftQuestion: $draftQuestion
                )

                MetricsGrid(metrics: metrics)

                NativeSection(
                    "Live workspace",
                    subtitle: "Transcript, question, answer, and HUD state from the native runtime."
                ) {
                    VStack(spacing: 12) {
                        LiveWorkspaceRow(
                            title: "Transcript",
                            value: runtime.assistantSession.transcriptText,
                            emptyValue: "No finalized transcript yet.",
                            symbolName: "waveform",
                            tint: NativeHelixTheme.teal
                        )
                        LiveWorkspaceRow(
                            title: "Detected question",
                            value: runtime.assistantSession.detectedQuestion,
                            emptyValue: "Ask manually or start a listening run.",
                            symbolName: "questionmark.bubble",
                            tint: NativeHelixTheme.indigo
                        )
                        LiveWorkspaceRow(
                            title: "Answer",
                            value: answerText,
                            emptyValue: "Answers will appear here before being sent to the G1 HUD.",
                            symbolName: "sparkles",
                            tint: NativeHelixTheme.green
                        )
                    }
                }

                NativeSection("Runtime activity") {
                    if timelineItems.isEmpty {
                        NativeEmptyState(
                            title: "No runtime events yet",
                            detail: "Ask a question or run audio input to populate the native session log.",
                            symbolName: "clock"
                        )
                    } else {
                        VStack(spacing: 0) {
                            ForEach(timelineItems) { item in
                                TimelineRow(item: item)
                                if item.id != timelineItems.last?.id {
                                    Divider().padding(.leading, 34)
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .scrollContentBackground(.hidden)
    }

    private var answerText: String {
        if !runtime.assistantSession.currentAnswer.isEmpty {
            return runtime.assistantSession.currentAnswer
        }
        return runtime.assistantSession.passiveReminder
    }

    private var metrics: [NativeMetric] {
        [
            NativeMetric(
                id: "mode",
                title: "Mode",
                value: runtime.assistantSession.mode.nativeTitle,
                detail: "\(runtime.settings.maxResponseSentences) sentence limit",
                symbolName: "text.bubble",
                tint: NativeHelixTheme.teal
            ),
            NativeMetric(
                id: "provider",
                title: "Provider",
                value: runtime.activeProviderName,
                detail: runtime.settings.llmModel,
                symbolName: "bolt.horizontal",
                tint: NativeHelixTheme.indigo
            ),
            NativeMetric(
                id: "hud",
                title: "HUD",
                value: runtime.settings.hudRenderPath.nativeTitle,
                detail: runtime.g1DeviceState.currentPageSummary,
                symbolName: "rectangle.on.rectangle",
                tint: NativeHelixTheme.green
            )
        ]
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
private struct AssistantCommandBand: View {
    let runtime: HelixRuntimeDependencies
    @Binding var draftQuestion: String

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
                    NativeStatusPill(text: runtime.g1DeviceState.currentPageSummary, tint: NativeHelixTheme.teal)
                    Spacer(minLength: 0)
                }

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

                    Button(action: askQuestion) {
                        Label("Ask", systemImage: runtime.assistantSession.isRunning ? "hourglass" : "arrow.up")
                            .labelStyle(.iconOnly)
                    }
                    .buttonStyle(NativeHelixSecondaryButtonStyle())
                    .disabled(trimmedQuestion.isEmpty || runtime.assistantSession.isRunning)
                    .opacity(trimmedQuestion.isEmpty || runtime.assistantSession.isRunning ? 0.45 : 1)
                    .accessibilityLabel("Ask Helix")
                }

                HStack(spacing: 10) {
                    Button("Send to G1", action: sendCurrentAnswerToHud)
                        .buttonStyle(NativeHelixPrimaryButtonStyle())
                        .disabled(currentAnswerText.isEmpty)
                        .opacity(currentAnswerText.isEmpty ? 0.45 : 1)

                    Button("Save session", action: saveSession)
                        .buttonStyle(NativeHelixSecondaryButtonStyle())
                        .disabled(!canSaveSession)
                        .opacity(canSaveSession ? 1 : 0.45)
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

private struct MetricsGrid: View {
    let metrics: [NativeMetric]

    var body: some View {
        Grid(horizontalSpacing: 10, verticalSpacing: 10) {
            GridRow {
                ForEach(metrics) { metric in
                    NativeMetricTile(metric: metric)
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
