import SwiftUI

enum NativeHelixTheme {
    static let background = Color(red: 0.973, green: 0.976, blue: 0.984)
    static let surface = Color.white
    static let ink = Color(red: 0.071, green: 0.082, blue: 0.110)
    static let secondaryInk = Color(red: 0.360, green: 0.384, blue: 0.431)
    static let hairline = Color(red: 0.858, green: 0.878, blue: 0.910)
    static let teal = Color(red: 0.000, green: 0.486, blue: 0.584)
    static let indigo = Color(red: 0.247, green: 0.309, blue: 0.780)
    static let green = Color(red: 0.094, green: 0.514, blue: 0.298)
    static let amber = Color(red: 0.792, green: 0.459, blue: 0.059)
}

struct NativeHelixPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.subheadline, design: .rounded, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 18)
            .frame(height: 44)
            .background(NativeHelixTheme.ink.opacity(configuration.isPressed ? 0.82 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct NativeHelixSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.subheadline, design: .rounded, weight: .semibold))
            .foregroundStyle(NativeHelixTheme.ink)
            .padding(.horizontal, 14)
            .frame(height: 40)
            .background(configuration.isPressed ? NativeHelixTheme.hairline : NativeHelixTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(NativeHelixTheme.hairline)
            }
    }
}

struct NativeSection<Content: View>: View {
    let title: String
    let subtitle: String?
    let content: Content

    init(
        _ title: String,
        subtitle: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(.headline, design: .rounded, weight: .semibold))
                    .foregroundStyle(NativeHelixTheme.ink)
                if let subtitle {
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(NativeHelixTheme.secondaryInk)
                }
            }
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(NativeHelixTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(NativeHelixTheme.hairline)
        }
    }
}

struct NativeMetricTile: View {
    let metric: NativeMetric

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: metric.symbolName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(metric.tint)
                Text(metric.title)
                    .font(.caption)
                    .foregroundStyle(NativeHelixTheme.secondaryInk)
            }
            Text(metric.value)
                .font(.system(.title3, design: .rounded, weight: .semibold))
                .foregroundStyle(NativeHelixTheme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Text(metric.detail)
                .font(.caption)
                .foregroundStyle(NativeHelixTheme.secondaryInk)
                .lineLimit(2)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 112, alignment: .leading)
        .background(metric.tint.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct NativeStatusPill: View {
    let text: String
    let tint: Color

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(tint)
                .frame(width: 7, height: 7)
            Text(text)
                .font(.caption.weight(.semibold))
                .foregroundStyle(NativeHelixTheme.ink)
        }
        .padding(.horizontal, 10)
        .frame(height: 28)
        .background(tint.opacity(0.10))
        .clipShape(Capsule())
    }
}

struct NativeEmptyState: View {
    let title: String
    let detail: String
    let symbolName: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: symbolName)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(NativeHelixTheme.teal)
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(NativeHelixTheme.ink)
            Text(detail)
                .font(.footnote)
                .foregroundStyle(NativeHelixTheme.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(NativeHelixTheme.background)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(NativeHelixTheme.hairline)
        }
    }
}
