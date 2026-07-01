import HelixCore
import HelixRuntime
import SwiftUI

@MainActor
struct NativeKnowledgeView: View {
    let runtime: HelixRuntimeDependencies
    @State private var selectedBucket = KnowledgeBucket.projects
    @State private var draftItem = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                NativeSection("Knowledge", subtitle: runtime.knowledgeLibrary.activeProjectName) {
                    VStack(alignment: .leading, spacing: 12) {
                        Picker("Knowledge bucket", selection: $selectedBucket) {
                            ForEach(KnowledgeBucket.allCases, id: \.self) { bucket in
                                Text(bucket.title).tag(bucket)
                            }
                        }
                        .pickerStyle(.segmented)

                        KnowledgeStatsStrip(buckets: knowledgeBuckets)
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
                            .disabled(trimmedDraft.isEmpty)
                            .opacity(trimmedDraft.isEmpty ? 0.45 : 1)
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

    private var trimmedDraft: String {
        draftItem.trimmingCharacters(in: .whitespacesAndNewlines)
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
        let text = trimmedDraft
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

private struct KnowledgeStatsStrip: View {
    let buckets: [NativeKnowledgeBucket]

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: 8)], spacing: 8) {
            ForEach(buckets) { bucket in
                KnowledgeStatPill(bucket: bucket)
            }
        }
    }
}

private struct KnowledgeStatPill: View {
    let bucket: NativeKnowledgeBucket

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: bucket.symbolName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(NativeHelixTheme.indigo)
                .frame(width: 16, height: 16)
            VStack(alignment: .leading, spacing: 1) {
                Text("\(bucket.count) \(bucket.title)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(NativeHelixTheme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(bucket.detail)
                    .font(.caption2)
                    .foregroundStyle(NativeHelixTheme.secondaryInk)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .frame(minHeight: 42)
        .background(NativeHelixTheme.background)
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
