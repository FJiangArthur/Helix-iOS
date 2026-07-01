import SwiftUI

struct NativeDeviceView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                NativeSection("G1 connection", subtitle: "Dual-lens status and HUD transport.") {
                    VStack(spacing: 12) {
                        DeviceLensRow(side: "Left lens", state: "Connected", tint: NativeHelixTheme.green)
                        DeviceLensRow(side: "Right lens", state: "Connected", tint: NativeHelixTheme.green)
                        DeviceLensRow(side: "HUD packets", state: "191 byte chunks", tint: NativeHelixTheme.indigo)
                    }
                }

                NativeSection("HUD controls") {
                    HStack(spacing: 10) {
                        Button("Previous") {}
                            .buttonStyle(NativeHelixSecondaryButtonStyle())
                        Button("Push page") {}
                            .buttonStyle(NativeHelixPrimaryButtonStyle())
                        Button("Next") {}
                            .buttonStyle(NativeHelixSecondaryButtonStyle())
                    }
                }

                NativeSection("Dashboard widgets") {
                    CompactTagGrid(
                        values: ["Clock", "Calendar", "Weather", "Todos", "Battery", "News"]
                    )
                }
            }
            .padding(16)
        }
        .scrollContentBackground(.hidden)
    }
}

struct NativeSessionsView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                NativeSection("Session archive", subtitle: "Conversation memory and recent answers.") {
                    VStack(spacing: 0) {
                        ForEach(NativeHelixPreviewData.timeline) { item in
                            TimelineSummaryRow(item: item)
                            if item.id != NativeHelixPreviewData.timeline.last?.id {
                                Divider()
                            }
                        }
                    }
                }

                NativeSection("Insights") {
                    CompactTagGrid(
                        values: ["Questions answered", "Fact checks", "Action items", "Project mentions"]
                    )
                }
            }
            .padding(16)
        }
        .scrollContentBackground(.hidden)
    }
}

struct NativeKnowledgeView: View {
    @State private var selectedBucket = "Projects"

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                NativeSection("Knowledge") {
                    Picker("Knowledge bucket", selection: $selectedBucket) {
                        ForEach(["Projects", "Facts", "Memories", "Todos"], id: \.self) { bucket in
                            Text(bucket).tag(bucket)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 10)], spacing: 10) {
                    ForEach(NativeHelixPreviewData.knowledgeBuckets) { bucket in
                        KnowledgeBucketTile(bucket: bucket)
                    }
                }
            }
            .padding(16)
        }
        .scrollContentBackground(.hidden)
    }
}

struct NativeSettingsView: View {
    @Binding var selectedMode: NativeConversationMode
    @State private var autoAnswer = true
    @State private var autoDetect = true
    @State private var bitmapHud = true
    @State private var sentenceLimit = 3.0

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                NativeSection("Conversation") {
                    VStack(spacing: 12) {
                        Picker("Default mode", selection: $selectedMode) {
                            ForEach(NativeConversationMode.allCases) { mode in
                                Text(mode.rawValue).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)

                        Toggle("Auto-detect questions", isOn: $autoDetect)
                        Toggle("Auto-answer", isOn: $autoAnswer)
                        Toggle("Bitmap HUD", isOn: $bitmapHud)

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Max response sentences: \(Int(sentenceLimit))")
                                .font(.subheadline.weight(.semibold))
                            Slider(value: $sentenceLimit, in: 1...10, step: 1)
                        }
                    }
                    .tint(NativeHelixTheme.teal)
                }

                NativeSection("AI providers") {
                    VStack(spacing: 0) {
                        ForEach(NativeHelixPreviewData.providers) { provider in
                            ProviderRow(provider: provider)
                            if provider.id != NativeHelixPreviewData.providers.last?.id {
                                Divider().padding(.leading, 34)
                            }
                        }
                    }
                }
            }
            .padding(16)
        }
        .scrollContentBackground(.hidden)
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

private struct TimelineSummaryRow: View {
    let item: NativeTimelineItem

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
            Spacer()
            Text(item.time)
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
