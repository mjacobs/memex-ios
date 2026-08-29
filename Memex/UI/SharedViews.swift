import SwiftUI

struct TagChip: View {
    let tag: String

    var body: some View {
        Text("#\(tag)")
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(.quaternary, in: Capsule())
            .accessibilityLabel("Tag \(tag)")
    }
}

struct KindBadge: View {
    let kind: String

    private var color: Color {
        switch kind {
        case "digest": .purple
        case "review": .orange
        case "link": .teal
        case "research": .indigo
        default: .blue
        }
    }

    var body: some View {
        Text(kind.capitalized)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.16), in: Capsule())
    }
}

struct ErrorNotice: View {
    let message: String
    var retry: (() -> Void)?

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text(message)
                .font(.callout)
                .frame(maxWidth: .infinity, alignment: .leading)
            if let retry {
                Button("Retry", action: retry)
                    .font(.callout.weight(.semibold))
            }
        }
        .padding()
        .background(.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
    }
}
