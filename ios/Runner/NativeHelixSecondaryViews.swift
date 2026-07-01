import HelixCore
import HelixG1
import HelixRuntime
import SwiftUI

@MainActor
struct NativeDeviceView: View {
    let runtime: HelixRuntimeDependencies

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                NativeSection("G1 connection", subtitle: runtime.g1DeviceState.connectionSummary) {
                    VStack(spacing: 12) {
                        DeviceLensRow(
                            side: "Left lens",
                            state: runtime.g1DeviceState.leftLensConnected ? "Connected" : "Waiting",
                            tint: runtime.g1DeviceState.leftLensConnected ? NativeHelixTheme.green : NativeHelixTheme.secondaryInk
                        )
                        DeviceLensRow(
                            side: "Right lens",
                            state: runtime.g1DeviceState.rightLensConnected ? "Connected" : "Waiting",
                            tint: runtime.g1DeviceState.rightLensConnected ? NativeHelixTheme.green : NativeHelixTheme.secondaryInk
                        )
                        DeviceLensRow(
                            side: "HUD packets",
                            state: "\(runtime.g1DeviceState.sentPacketCount) queued",
                            tint: NativeHelixTheme.indigo
                        )
                    }
                }

                NativeSection("HUD controls", subtitle: runtime.g1DeviceState.currentPageSummary) {
                    HStack(spacing: 10) {
                        Button("Previous") {
                            runtime.g1DeviceState.handleTouchpad(notifyIndex: 1, side: .left)
                        }
                        .buttonStyle(NativeHelixSecondaryButtonStyle())

                        Button("Push answer") {
                            runtime.g1DeviceState.presentText(runtime.assistantSession.currentAnswer)
                        }
                        .buttonStyle(NativeHelixPrimaryButtonStyle())
                        .disabled(runtime.assistantSession.currentAnswer.isEmpty)
                        .opacity(runtime.assistantSession.currentAnswer.isEmpty ? 0.45 : 1)

                        Button("Next") {
                            runtime.g1DeviceState.handleTouchpad(notifyIndex: 1, side: .right)
                        }
                        .buttonStyle(NativeHelixSecondaryButtonStyle())
                    }
                }

                NativeSection("Touchpad") {
                    VStack(alignment: .leading, spacing: 10) {
                        NativeStatusPill(
                            text: runtime.g1DeviceState.lastTouchpadSummary,
                            tint: NativeHelixTheme.teal
                        )
                        if let firstPage = runtime.g1DeviceState.hudPages.first {
                            Text(firstPage.text)
                                .font(.footnote)
                                .foregroundStyle(NativeHelixTheme.secondaryInk)
                                .lineLimit(3)
                        } else {
                            NativeEmptyState(
                                title: "No HUD page loaded",
                                detail: "Send an answer from Assistant to preview G1 pagination here.",
                                symbolName: "eyeglasses"
                            )
                        }
                    }
                }
            }
            .padding(16)
        }
        .scrollContentBackground(.hidden)
    }
}

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
                    CompactTagGrid(
                        values: [
                            "\(runtime.sessionArchive.sessions.reduce(0) { $0 + $1.answerCount }) answers",
                            "\(runtime.sessionArchive.sessions.reduce(0) { $0 + $1.segmentCount }) transcript turns",
                            runtime.sessionArchive.totalCostSummary,
                            runtime.sessionArchive.activeProjectSummary
                        ]
                    )
                }
            }
            .padding(16)
        }
        .scrollContentBackground(.hidden)
        .task {
            await runtime.sessionArchive.refresh()
        }
    }
}

@MainActor
struct NativeKnowledgeView: View {
    let runtime: HelixRuntimeDependencies
    @State private var selectedBucket = KnowledgeBucket.projects
    @State private var draftItem = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                NativeSection("Knowledge", subtitle: runtime.knowledgeLibrary.activeProjectName) {
                    Picker("Knowledge bucket", selection: $selectedBucket) {
                        ForEach(KnowledgeBucket.allCases, id: \.self) { bucket in
                            Text(bucket.title).tag(bucket)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 10)], spacing: 10) {
                    ForEach(knowledgeBuckets) { bucket in
                        KnowledgeBucketTile(bucket: bucket)
                    }
                }

                NativeSection(selectedBucket.addTitle) {
                    HStack(spacing: 10) {
                        TextField(selectedBucket.placeholder, text: $draftItem, axis: .vertical)
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

                        Button("Add", action: addKnowledgeItem)
                            .buttonStyle(NativeHelixPrimaryButtonStyle())
                            .disabled(draftItem.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            .opacity(draftItem.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.45 : 1)
                    }
                }

                NativeSection(selectedBucket.title) {
                    KnowledgeBucketList(bucket: selectedBucket, snapshot: runtime.knowledgeLibrary.snapshot)
                }
            }
            .padding(16)
        }
        .scrollContentBackground(.hidden)
        .task {
            await runtime.knowledgeLibrary.refresh()
        }
    }

    private var knowledgeBuckets: [NativeKnowledgeBucket] {
        let snapshot = runtime.knowledgeLibrary.snapshot
        return [
            NativeKnowledgeBucket(
                id: "projects",
                title: "Projects",
                count: "\(snapshot.projects.count)",
                detail: runtime.knowledgeLibrary.activeProjectName,
                symbolName: "folder"
            ),
            NativeKnowledgeBucket(
                id: "facts",
                title: "Facts",
                count: "\(snapshot.facts.count)",
                detail: "Reviewed memory",
                symbolName: "checkmark.seal"
            ),
            NativeKnowledgeBucket(
                id: "todos",
                title: "Todos",
                count: "\(snapshot.openTodoCount)",
                detail: runtime.knowledgeLibrary.reviewSummary,
                symbolName: "checklist"
            ),
            NativeKnowledgeBucket(
                id: "documents",
                title: "Docs",
                count: "\(snapshot.documents.count)",
                detail: runtime.knowledgeLibrary.documentSummary,
                symbolName: "doc.text.magnifyingglass"
            )
        ]
    }

    private func addKnowledgeItem() {
        let text = draftItem.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        Task {
            switch selectedBucket {
            case .projects:
                await runtime.knowledgeLibrary.createProject(name: text, activate: true)
            case .facts:
                await runtime.knowledgeLibrary.addFact(text, source: "Manual")
            case .memories:
                await runtime.knowledgeLibrary.addMemory(text, source: "Manual")
            case .todos:
                await runtime.knowledgeLibrary.addTodo(text)
            }
            draftItem = ""
        }
    }
}

@MainActor
struct NativeSettingsView: View {
    let runtime: HelixRuntimeDependencies

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                NativeSection("Conversation") {
                    VStack(spacing: 12) {
                        Picker("Default mode", selection: modeBinding) {
                            ForEach(ConversationMode.allCases, id: \.self) { mode in
                                Text(mode.nativeTitle).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)

                        Toggle("Auto-detect questions", isOn: autoDetectBinding)
                        Toggle("Auto-answer", isOn: autoAnswerBinding)
                        Toggle("Live fact-check", isOn: factCheckBinding)
                        Toggle("Bitmap HUD", isOn: bitmapHudBinding)

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Max response sentences: \(runtime.settings.maxResponseSentences)")
                                .font(.subheadline.weight(.semibold))
                            Slider(value: sentenceLimitBinding, in: 1...10, step: 1)
                        }
                    }
                    .tint(NativeHelixTheme.teal)
                }

                NativeSection("Runtime") {
                    CompactTagGrid(
                        values: [
                            runtime.settings.transcriptionBackend.nativeTitle,
                            runtime.settings.webSearchMode.nativeTitle,
                            runtime.assistantSession.memorySummary,
                            runtime.assistantSession.latencySummary
                        ]
                    )
                }

                NativeSection("AI providers") {
                    VStack(spacing: 0) {
                        ForEach(providerRows) { provider in
                            ProviderRow(provider: provider)
                            if provider.id != providerRows.last?.id {
                                Divider().padding(.leading, 34)
                            }
                        }
                    }
                }
            }
            .padding(16)
        }
        .scrollContentBackground(.hidden)
        .task {
            await runtime.refreshSettings()
        }
    }

    private var modeBinding: Binding<ConversationMode> {
        Binding(
            get: { runtime.assistantSession.mode },
            set: { runtime.assistantSession.setMode($0) }
        )
    }

    private var autoDetectBinding: Binding<Bool> {
        Binding(
            get: { runtime.settings.autoDetectQuestions },
            set: { newValue in Task { await runtime.setAutoDetectQuestions(newValue) } }
        )
    }

    private var autoAnswerBinding: Binding<Bool> {
        Binding(
            get: { runtime.settings.autoAnswer },
            set: { newValue in Task { await runtime.setAutoAnswer(newValue) } }
        )
    }

    private var factCheckBinding: Binding<Bool> {
        Binding(
            get: { runtime.settings.liveFactCheckEnabled },
            set: { newValue in Task { await runtime.setLiveFactCheckEnabled(newValue) } }
        )
    }

    private var bitmapHudBinding: Binding<Bool> {
        Binding(
            get: { runtime.settings.hudRenderPath == .bitmap },
            set: { newValue in Task { await runtime.updateHudRenderPath(newValue ? .bitmap : .text) } }
        )
    }

    private var sentenceLimitBinding: Binding<Double> {
        Binding(
            get: { Double(runtime.settings.maxResponseSentences) },
            set: { newValue in Task { await runtime.updateMaxResponseSentences(Int(newValue)) } }
        )
    }

    private var providerRows: [NativeProviderRow] {
        runtime.settings.providers.map { provider in
            let readiness = runtime.providerReadiness.first { $0.provider == provider.kind }
            return NativeProviderRow(
                id: provider.kind.rawValue,
                name: provider.displayName,
                model: provider.modelSelection.lightModel,
                status: readiness?.hasApiKey == true ? "Key set" : "Needs key",
                tint: readiness?.hasApiKey == true ? NativeHelixTheme.green : NativeHelixTheme.amber
            )
        }
    }
}

private struct DeviceLensRow: View {
    let side: String
    let state: String
    let tint: Color

    var body: some View {
        HStack {
            NativeStatusPill(text: side, tint: tint)
            Spacer()
            Text(state)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(NativeHelixTheme.ink)
        }
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

private struct KnowledgeBucketTile: View {
    let bucket: NativeKnowledgeBucket

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: bucket.symbolName)
                .foregroundStyle(NativeHelixTheme.indigo)
            Text(bucket.count)
                .font(.system(.title2, design: .rounded, weight: .bold))
                .foregroundStyle(NativeHelixTheme.ink)
            VStack(alignment: .leading, spacing: 2) {
                Text(bucket.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(NativeHelixTheme.ink)
                Text(bucket.detail)
                    .font(.caption)
                    .foregroundStyle(NativeHelixTheme.secondaryInk)
                    .lineLimit(1)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 132, alignment: .leading)
        .background(NativeHelixTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(NativeHelixTheme.hairline)
        }
    }
}

private struct KnowledgeBucketList: View {
    let bucket: KnowledgeBucket
    let snapshot: NativeKnowledgeSnapshot

    var body: some View {
        let items = displayItems
        if items.isEmpty {
            NativeEmptyState(
                title: "Nothing here yet",
                detail: "Use the compact input above to add native \(bucket.title.lowercased()).",
                symbolName: bucket.symbolName
            )
        } else {
            VStack(spacing: 0) {
                ForEach(items) { item in
                    KnowledgeItemRow(item: item)
                    if item.id != items.last?.id {
                        Divider()
                    }
                }
            }
        }
    }

    private var displayItems: [KnowledgeDisplayItem] {
        switch bucket {
        case .projects:
            return snapshot.projects.map {
                KnowledgeDisplayItem(
                    id: $0.id,
                    title: $0.name,
                    detail: $0.summary.isEmpty ? "\($0.documentCount) docs, \($0.factCount) facts" : $0.summary,
                    symbolName: $0.isActive ? "folder.fill" : "folder"
                )
            }
        case .facts:
            return snapshot.facts.map {
                KnowledgeDisplayItem(id: $0.id, title: $0.kind.nativeTitle, detail: $0.text, symbolName: "checkmark.seal")
            }
        case .memories:
            return snapshot.memories.map {
                KnowledgeDisplayItem(id: $0.id, title: $0.kind.nativeTitle, detail: $0.text, symbolName: "brain.head.profile")
            }
        case .todos:
            return snapshot.todos.map {
                KnowledgeDisplayItem(id: $0.id, title: $0.isComplete ? "Done" : "Open", detail: $0.text, symbolName: "checklist")
            }
        }
    }
}

private struct KnowledgeItemRow: View {
    let item: KnowledgeDisplayItem

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: item.symbolName)
                .foregroundStyle(NativeHelixTheme.teal)
                .frame(width: 22, height: 22)
            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(NativeHelixTheme.ink)
                Text(item.detail)
                    .font(.footnote)
                    .foregroundStyle(NativeHelixTheme.secondaryInk)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 10)
    }
}

private struct KnowledgeDisplayItem: Identifiable {
    let id: UUID
    let title: String
    let detail: String
    let symbolName: String
}

private enum KnowledgeBucket: String, CaseIterable {
    case projects
    case facts
    case memories
    case todos

    var title: String {
        switch self {
        case .projects: return "Projects"
        case .facts: return "Facts"
        case .memories: return "Memories"
        case .todos: return "Todos"
        }
    }

    var addTitle: String {
        switch self {
        case .projects: return "Add project"
        case .facts: return "Add fact"
        case .memories: return "Add memory"
        case .todos: return "Add todo"
        }
    }

    var placeholder: String {
        switch self {
        case .projects: return "Project name"
        case .facts: return "Fact to remember"
        case .memories: return "Conversation memory"
        case .todos: return "Follow-up item"
        }
    }

    var symbolName: String {
        switch self {
        case .projects: return "folder"
        case .facts: return "checkmark.seal"
        case .memories: return "brain.head.profile"
        case .todos: return "checklist"
        }
    }
}

private struct ProviderRow: View {
    let provider: NativeProviderRow

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(provider.tint)
                .frame(width: 10, height: 10)
            VStack(alignment: .leading, spacing: 3) {
                Text(provider.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(NativeHelixTheme.ink)
                Text(provider.model)
                    .font(.caption)
                    .foregroundStyle(NativeHelixTheme.secondaryInk)
            }
            Spacer()
            Text(provider.status)
                .font(.caption.weight(.semibold))
                .foregroundStyle(provider.tint)
        }
        .padding(.vertical, 10)
    }
}

private struct CompactTagGrid: View {
    let values: [String]

    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(values, id: \.self) { value in
                Text(value)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(NativeHelixTheme.ink)
                    .padding(.horizontal, 10)
                    .frame(height: 30)
                    .background(NativeHelixTheme.background)
                    .clipShape(Capsule())
            }
        }
    }
}

private struct FlowLayout: Layout {
    let spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
        let width = proposal.width ?? 320
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > width {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }

        return CGSize(width: width, height: y + rowHeight)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout Void
    ) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
