import SwiftUI

struct NativeAssistantView: View {
    @Binding var selectedMode: NativeConversationMode
    @Binding var isListening: Bool
    @Binding var draftQuestion: String

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                AssistantCommandBand(
                    selectedMode: $selectedMode,
                    isListening: $isListening,
                    draftQuestion: $draftQuestion
                )

                MetricsGrid(metrics: NativeHelixPreviewData.metrics)

                NativeSection(
                    "Live workspace",
                    subtitle: "Transcript, detected question, answer, and HUD status in one scan."
                ) {
                    VStack(spacing: 12) {
                        LiveWorkspaceRow(
                            title: "Transcript",
                            value: "The rollout is green except for physical-device connectivity proof.",
                            symbolName: "waveform",
                            tint: NativeHelixTheme.teal
                        )
                        LiveWorkspaceRow(
                            title: "Detected question",
                            value: "What should I say about the remaining risk?",
                            symbolName: "questionmark.bubble",
                            tint: NativeHelixTheme.indigo
                        )
                        LiveWorkspaceRow(
                            title: "Answer",
                            value: "Say the build and simulator launch are verified; the phone needs a trusted CoreDevice tunnel before install.",
                            symbolName: "sparkles",
                            tint: NativeHelixTheme.green
                        )
                    }
                }

                NativeSection("Recent activity") {
                    VStack(spacing: 0) {
                        ForEach(NativeHelixPreviewData.timeline) { item in
                            TimelineRow(item: item)
                            if item.id != NativeHelixPreviewData.timeline.last?.id {
                                Divider().padding(.leading, 34)
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
}

private struct AssistantCommandBand: View {
    @Binding var selectedMode: NativeConversationMode
    @Binding var isListening: Bool
    @Binding var draftQuestion: String

    var body: some View {
        NativeSection("Assistant", subtitle: selectedMode.summary) {
            VStack(alignment: .leading, spacing: 14) {
                Picker("Conversation mode", selection: $selectedMode) {
                    ForEach(NativeConversationMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                HStack(spacing: 10) {
                    NativeStatusPill(
                        text: isListening ? "Listening" : "Ready",
                        tint: isListening ? NativeHelixTheme.green : NativeHelixTheme.secondaryInk
                    )
                    NativeStatusPill(text: "G1 HUD ready", tint: NativeHelixTheme.teal)
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

                    Button {
                        isListening.toggle()
                    } label: {
                        Label(isListening ? "Pause" : "Listen", systemImage: isListening ? "pause.fill" : "mic.fill")
                            .labelStyle(.iconOnly)
                    }
                    .buttonStyle(NativeHelixSecondaryButtonStyle())
                    .accessibilityLabel(isListening ? "Pause listening" : "Start listening")
                }

                HStack(spacing: 10) {
                    Button("Send to G1") {
                        draftQuestion = ""
                    }
                    .buttonStyle(NativeHelixPrimaryButtonStyle())

                    Button("Save session") {}
                        .buttonStyle(NativeHelixSecondaryButtonStyle())
                }
            }
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
                Text(value)
                    .font(.subheadline)
                    .foregroundStyle(NativeHelixTheme.ink)
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
