import SwiftUI

struct NoteDetailView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var store: NoteDetailStore

    init(note: Note) {
        _store = State(initialValue: NoteDetailStore(note: note))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if let error = store.errorMessage {
                    ErrorNotice(message: error) {
                        guard let api = environment.api else { return }
                        Task { await store.load(api: api) }
                    }
                }

                HStack {
                    KindBadge(kind: store.note.kind)
                    Spacer()
                    Text(MemexDateFormatting.displayDate(store.note.createdAt))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if !store.note.summary.isEmpty {
                    Text(store.note.summary)
                        .font(.title2.bold())
                        .textSelection(.enabled)
                }

                if !store.note.tags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(store.note.tags, id: \.self) { tag in
                                TagChip(tag: tag)
                            }
                        }
                    }
                }

                if let transcript = store.note.transcript, !transcript.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Transcript", systemImage: "waveform")
                            .font(.headline)
                        Text(transcript)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                }

                if !store.note.body.isEmpty {
                    MarkdownView(markdown: store.note.body)
                        .textSelection(.enabled)
                }

                TraceView(trace: store.note.trace)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
        .navigationTitle("Note")
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if store.isLoading {
                ProgressView()
                    .padding()
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
        }
        .task {
            guard let api = environment.api else { return }
            await store.load(api: api)
        }
    }
}

#Preview {
    NavigationStack {
        NoteDetailView(note: PreviewFixtures.note)
    }
    .environment(AppEnvironment.preview())
}
