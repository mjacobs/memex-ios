import Foundation
import Observation

@MainActor
@Observable
final class FeedStore {
    private(set) var notes: [Note]
    private(set) var isLoading = false
    private(set) var hasLoaded = false
    private(set) var errorMessage: String?
    var selectedKind: String?
    var selectedTag: String?

    init(notes: [Note] = []) {
        self.notes = notes
        hasLoaded = !notes.isEmpty
    }

    var availableTags: [String] {
        Array(Set(notes.flatMap(\.tags))).sorted()
    }

    var visibleNotes: [Note] {
        notes.filter { note in
            (selectedKind == nil || note.kind == selectedKind) &&
                (selectedTag == nil || note.tags.contains(selectedTag!))
        }
    }

    func load(api: any MemexAPI, force: Bool = false) async {
        guard !isLoading else { return }
        guard force || !hasLoaded else { return }
        isLoading = true
        errorMessage = nil
        defer {
            isLoading = false
            hasLoaded = true
        }
        do {
            notes = try await api.notes(limit: 50, tag: nil, kind: nil)
        } catch is CancellationError {
            return
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

@MainActor
@Observable
final class NoteDetailStore {
    private(set) var note: Note
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    init(note: Note) {
        self.note = note
    }

    func load(api: any MemexAPI) async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            note = try await api.note(id: note.id)
        } catch is CancellationError {
            return
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
