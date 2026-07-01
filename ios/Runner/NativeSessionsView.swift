import HelixCore
import HelixRuntime
import SwiftUI

@MainActor
struct NativeSessionsView: View {
    let runtime: HelixRuntimeDependencies

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                NativeSection("Session archive", subtitle: runtime.sessionArchive.archiveSummary) {
                    if runtime.sessionArchive.sessions.isEmpty {
                        NativeEmptyState(
                            title: "No saved sessions",
                            detail: "Ask a question in Assistant, then save the session to build native history.",
                            symbolName: "clock.arrow.circlepath"
                        )
                    } else {
                        VStack(spacing: 0) {
                            ForEach(runtime.sessionArchive.sessions) { session in
                                SessionSummaryRow(session: session)
                                if session.id != runtime.sessionArchive.sessions.last?.id {
                                    Divider()
                                }
                            }
                        }
                    }
                }

                NativeSection("Insights") {
                    CompactTagGrid(values: insightTags)
                }
            }
            .padding(16)
        }
        .scrollContentBackground(.hidden)
        .task {
            await runtime.sessionArchive.refresh()
        }
    }

    private var insightTags: [String] {
        [
            "\(runtime.sessionArchive.sessions.reduce(0) { $0 + $1.answerCount }) answers",
            "\(runtime.sessionArchive.sessions.reduce(0) { $0 + $1.segmentCount }) transcript turns",
            runtime.sessionArchive.totalCostSummary,
            runtime.sessionArchive.activeProjectSummary
        ]
    }
}

private struct SessionSummaryRow: View {
    let session: NativeSessionSummary

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: session.mode == .passive ? "ear" : "text.bubble")
                .foregroundStyle(NativeHelixTheme.teal)
                .frame(width: 22, height: 22)
            VStack(alignment: .leading, spacing: 3) {
                Text(session.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(NativeHelixTheme.ink)
                    .lineLimit(1)
                Text(session.answerPreview.isEmpty ? session.transcriptPreview : session.answerPreview)
                    .font(.footnote)
                    .foregroundStyle(NativeHelixTheme.secondaryInk)
                    .lineLimit(2)
            }
            Spacer()
            Text(session.startedAt.nativeRelativeLabel)
                .font(.caption)
                .foregroundStyle(NativeHelixTheme.secondaryInk)
        }
        .padding(.vertical, 10)
    }
}
