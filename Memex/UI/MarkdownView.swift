import SwiftUI

struct MarkdownView: View {
    let markdown: String

    private var blocks: [MarkdownBlock] {
        MarkdownBlock.parse(markdown)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                blockView(block)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func blockView(_ block: MarkdownBlock) -> some View {
        switch block {
        case .heading(let level, let text):
            inline(text)
                .font(level == 1 ? .title2.bold() : .headline)
        case .paragraph(let text):
            inline(text)
        case .bullet(let text):
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("•")
                inline(text)
            }
        case .numbered(let number, let text):
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(number).")
                    .fontWeight(.medium)
                inline(text)
            }
        case .quote(let text):
            HStack(alignment: .top, spacing: 10) {
                Capsule()
                    .fill(.tint)
                    .frame(width: 3)
                inline(text)
                    .italic()
                    .foregroundStyle(.secondary)
            }
        case .code(let text):
            ScrollView(.horizontal) {
                Text(text)
                    .font(.system(.footnote, design: .monospaced))
                    .textSelection(.enabled)
                    .padding(12)
            }
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
        }
    }

    private func inline(_ text: String) -> Text {
        if let attributed = try? AttributedString(
            markdown: text,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        ) {
            return Text(attributed)
        }
        return Text(text)
    }
}

private enum MarkdownBlock {
    case heading(Int, String)
    case paragraph(String)
    case bullet(String)
    case numbered(Int, String)
    case quote(String)
    case code(String)

    static func parse(_ markdown: String) -> [MarkdownBlock] {
        let lines = markdown.components(separatedBy: .newlines)
        var result: [MarkdownBlock] = []
        var paragraph: [String] = []
        var code: [String]? = nil

        func flushParagraph() {
            guard !paragraph.isEmpty else { return }
            result.append(.paragraph(paragraph.joined(separator: " ")))
            paragraph.removeAll()
        }

        for rawLine in lines {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("```") {
                flushParagraph()
                if let codeLines = code {
                    result.append(.code(codeLines.joined(separator: "\n")))
                    code = nil
                } else {
                    code = []
                }
                continue
            }
            if code != nil {
                code?.append(rawLine)
                continue
            }
            guard !line.isEmpty else {
                flushParagraph()
                continue
            }
            if line.hasPrefix("#") {
                flushParagraph()
                let level = line.prefix(while: { $0 == "#" }).count
                result.append(.heading(level, line.dropFirst(level).trimmingCharacters(in: .whitespaces)))
            } else if ["- ", "* ", "+ "].contains(where: line.hasPrefix) {
                flushParagraph()
                result.append(.bullet(String(line.dropFirst(2))))
            } else if line.hasPrefix(">") {
                flushParagraph()
                result.append(.quote(line.dropFirst().trimmingCharacters(in: .whitespaces)))
            } else if let dot = line.firstIndex(of: "."),
                      let number = Int(line[..<dot]),
                      line.index(after: dot) < line.endIndex {
                flushParagraph()
                result.append(.numbered(number, line[line.index(after: dot)...].trimmingCharacters(in: .whitespaces)))
            } else {
                paragraph.append(line)
            }
        }
        flushParagraph()
        if let code {
            result.append(.code(code.joined(separator: "\n")))
        }
        return result
    }
}
