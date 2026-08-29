import SwiftUI

struct TraceView: View {
    let trace: [TraceEvent]
    @State private var isExpanded = false

    var body: some View {
        if !trace.isEmpty {
            DisclosureGroup(isExpanded: $isExpanded) {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(Array(trace.enumerated()), id: \.offset) { index, event in
                        TraceEventView(index: index + 1, event: event)
                    }
                }
                .padding(.top, 12)
            } label: {
                Label("Agent Trace · \(trace.count) steps", systemImage: "point.3.connected.trianglepath.dotted")
                    .font(.headline)
            }
            .padding()
            .background(.quaternary.opacity(0.7), in: RoundedRectangle(cornerRadius: 14))
            .accessibilityIdentifier("note.trace")
        }
    }
}

private struct TraceEventView: View {
    let index: Int
    let event: TraceEvent

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("#\(index)")
                    .font(.caption.monospacedDigit().weight(.bold))
                    .foregroundStyle(.secondary)
                Label(roleLabel, systemImage: roleIcon)
                    .font(.caption.weight(.semibold))
                Spacer()
                Text(MemexDateFormatting.displayTime(event.t))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            if let text = event.text, !text.isEmpty {
                MarkdownView(markdown: text)
            }
            if let args = event.args, !args.isEmpty {
                codeSection("Arguments", value: .object(args))
            }
            if let result = event.result {
                codeSection("Result", value: result)
            }
        }
        .padding(12)
        .background(.background, in: RoundedRectangle(cornerRadius: 10))
    }

    private var roleLabel: String {
        switch event.role.lowercased() {
        case "user": "User"
        case "model": "Agent"
        case "tool": "Tool: \(event.tool ?? "call")"
        default: event.role.capitalized
        }
    }

    private var roleIcon: String {
        switch event.role.lowercased() {
        case "user": "person.fill"
        case "model": "sparkles"
        case "tool": "wrench.and.screwdriver.fill"
        default: "circle.fill"
        }
    }

    private func codeSection(_ title: String, value: JSONValue) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            ScrollView(.horizontal) {
                Text(value.prettyPrinted)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
            }
            .padding(8)
            .background(.black.opacity(0.85), in: RoundedRectangle(cornerRadius: 8))
            .foregroundStyle(.white)
        }
    }
}
