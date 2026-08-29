import SwiftUI

struct FeedView: View {
    @Environment(AppEnvironment.self) private var environment
    let store: FeedStore
    @State private var sheet: FeedSheet?

    var body: some View {
        Group {
            if store.isLoading && !store.hasLoaded {
                loadingList
            } else if let error = store.errorMessage, store.notes.isEmpty {
                ContentUnavailableView {
                    Label("Couldn’t load Feed", systemImage: "wifi.exclamationmark")
                } description: {
                    Text(error)
                } actions: {
                    Button("Retry") { refresh() }
                }
            } else if store.visibleNotes.isEmpty {
                ContentUnavailableView {
                    Label("No notes", systemImage: "note.text")
                } description: {
                    Text(store.notes.isEmpty ? "Capture your first thought." : "No notes match these filters.")
                } actions: {
                    if !store.notes.isEmpty {
                        Button("Clear filters") {
                            store.selectedKind = nil
                            store.selectedTag = nil
                        }
                    }
                    Button("Quick Capture") { sheet = .capture }
                }
            } else {
                feedList
            }
        }
        .navigationTitle("Memex")
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button("Refresh", systemImage: "arrow.clockwise") { refresh() }
                    .disabled(store.isLoading)
                Button("Settings", systemImage: "gearshape") { sheet = .settings }
            }
        }
        .overlay(alignment: .bottomTrailing) {
            Button {
                sheet = .capture
            } label: {
                Image(systemName: "plus")
                    .font(.title2.weight(.semibold))
                    .frame(width: 56, height: 56)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.circle)
            .padding(20)
            .shadow(radius: 6, y: 3)
            .accessibilityLabel("Quick Capture")
            .accessibilityIdentifier("feed.capture")
        }
        .sheet(item: $sheet) { destination in
            switch destination {
            case .capture:
                NavigationStack {
                    CaptureView {
                        sheet = nil
                        refresh()
                    }
                }
            case .settings:
                NavigationStack {
                    SettingsView(isSetup: false)
                }
            }
        }
        .task(id: environment.connectionVersion) {
            guard let api = environment.api else { return }
            await store.load(api: api, force: environment.connectionVersion > 0)
        }
    }

    private var feedList: some View {
        List {
            filterSection

            if let error = store.errorMessage {
                ErrorNotice(message: error, retry: refresh)
                    .listRowSeparator(.hidden)
            }

            ForEach(store.visibleNotes) { note in
                NavigationLink {
                    NoteDetailView(note: note)
                } label: {
                    NoteRow(note: note)
                }
                .listRowSeparator(.hidden)
                .listRowInsets(.init(top: 8, leading: 16, bottom: 8, trailing: 16))
            }
        }
        .listStyle(.plain)
        .refreshable {
            guard let api = environment.api else { return }
            await store.load(api: api, force: true)
        }
    }

    private var filterSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    filterButton("All", selected: store.selectedKind == nil) {
                        store.selectedKind = nil
                    }
                    ForEach(["capture", "digest", "review", "link", "research"], id: \.self) { kind in
                        filterButton(kind.capitalized, selected: store.selectedKind == kind) {
                            store.selectedKind = kind
                        }
                    }
                }
            }

            if !store.availableTags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        filterButton("All Tags", selected: store.selectedTag == nil) {
                            store.selectedTag = nil
                        }
                        ForEach(store.availableTags, id: \.self) { tag in
                            filterButton("#\(tag)", selected: store.selectedTag == tag) {
                                store.selectedTag = tag
                            }
                        }
                    }
                }
            }
        }
        .listRowSeparator(.hidden)
        .listRowInsets(.init(top: 6, leading: 16, bottom: 8, trailing: 0))
    }

    private var loadingList: some View {
        List(0..<4, id: \.self) { _ in
            NoteRow(note: PreviewFixtures.note)
                .redacted(reason: .placeholder)
                .listRowSeparator(.hidden)
        }
        .listStyle(.plain)
        .accessibilityLabel("Loading Feed")
    }

    private func filterButton(_ label: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(label, action: action)
            .buttonStyle(.bordered)
            .buttonBorderShape(.capsule)
            .tint(selected ? .cyan : .secondary)
            .font(.caption.weight(selected ? .bold : .regular))
    }

    private func refresh() {
        guard let api = environment.api else { return }
        Task { await store.load(api: api, force: true) }
    }
}

private enum FeedSheet: String, Identifiable {
    case capture
    case settings
    var id: String { rawValue }
}

private struct NoteRow: View {
    let note: Note

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                KindBadge(kind: note.kind)
                Spacer()
                Text(MemexDateFormatting.displayDate(note.createdAt))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(note.summary.isEmpty ? note.body : note.summary)
                .font(.headline)
                .lineLimit(2)

            if !note.body.isEmpty, note.body != note.summary {
                Text(note.body)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }

            HStack(alignment: .center) {
                ForEach(note.tags.prefix(3), id: \.self) { tag in
                    TagChip(tag: tag)
                }
                if note.tags.count > 3 {
                    Text("+\(note.tags.count - 3)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if !note.taskIDs.isEmpty {
                    Label("\(note.taskIDs.count)", systemImage: "checkmark.circle")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.cyan)
                        .accessibilityLabel("\(note.taskIDs.count) tasks")
                }
            }
        }
        .padding(14)
        .background(.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
        .contentShape(Rectangle())
        .accessibilityIdentifier("feed.note.\(note.id)")
    }
}

#Preview("Loaded Feed") {
    NavigationStack {
        FeedView(store: FeedStore(notes: [PreviewFixtures.note, PreviewFixtures.digest]))
    }
    .environment(AppEnvironment.preview())
}
