import XCTest
@testable import Memex

enum TestFailure: LocalizedError, Sendable {
    case expected

    var errorDescription: String? { "Expected test failure" }
}

actor TestMemexAPI: MemexAPI {
    var noteValues: [Note] = []
    var taskValues: [MemexTask] = []
    var captureValues: [Capture] = []
    var failure: TestFailure?
    private(set) var capturedText: String?
    private(set) var uploadedAudio: Data?
    private(set) var updatedTaskStatus: TaskStatus?

    init(notes: [Note] = [], tasks: [MemexTask] = [], captures: [Capture] = []) {
        noteValues = notes
        taskValues = tasks
        captureValues = captures
    }

    func setFailure(_ failure: TestFailure?) { self.failure = failure }
    func lastCapturedText() -> String? { capturedText }
    func lastUpdatedTaskStatus() -> TaskStatus? { updatedTaskStatus }

    func health() async throws {
        if let failure { throw failure }
    }

    func notes(limit: Int, tag: String?, kind: String?) async throws -> [Note] {
        if let failure { throw failure }
        return noteValues
    }

    func note(id: String) async throws -> Note {
        if let failure { throw failure }
        return noteValues.first(where: { $0.id == id }) ?? PreviewFixtures.note
    }

    func captureText(_ text: String) async throws -> CaptureResponse {
        if let failure { throw failure }
        capturedText = text
        return CaptureResponse(id: "01capture")
    }

    func captureAudio(_ data: Data, mimeType: String) async throws -> String {
        if let failure { throw failure }
        uploadedAudio = data
        return "01capture"
    }

    func capture(id: String) async throws -> Capture {
        if let failure { throw failure }
        guard !captureValues.isEmpty else { throw TestFailure.expected }
        return captureValues.removeFirst()
    }

    func tasks(status: TaskStatus) async throws -> [MemexTask] {
        if let failure { throw failure }
        return taskValues.filter { $0.status == status }
    }

    func updateTask(id: String, status: TaskStatus) async throws -> MemexTask {
        if let failure { throw failure }
        updatedTaskStatus = status
        var task = taskValues.first(where: { $0.id == id }) ?? PreviewFixtures.task
        task.status = status
        return task
    }
}

@MainActor
final class FeedStoreTests: XCTestCase {
    func testLoadAndLocalFilters() async {
        let api = TestMemexAPI(notes: [PreviewFixtures.note, PreviewFixtures.digest])
        let store = FeedStore()

        await store.load(api: api)
        store.selectedKind = "capture"
        store.selectedTag = "finance"

        XCTAssertEqual(store.notes.count, 2)
        XCTAssertEqual(store.visibleNotes.map(\.id), [PreviewFixtures.note.id])
        XCTAssertEqual(store.availableTags, ["daily-digest", "finance", "follow-up"])
    }

    func testFailedRefreshKeepsExistingNotes() async {
        let api = TestMemexAPI(notes: [PreviewFixtures.note])
        let store = FeedStore()
        await store.load(api: api)
        await api.setFailure(.expected)

        await store.load(api: api, force: true)

        XCTAssertEqual(store.notes, [PreviewFixtures.note])
        XCTAssertEqual(store.errorMessage, "Expected test failure")
    }
}
