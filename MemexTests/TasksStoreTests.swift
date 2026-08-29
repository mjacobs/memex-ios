import XCTest
@testable import Memex

@MainActor
final class TasksStoreTests: XCTestCase {
    func testSuccessfulToggleOptimisticallyRemovesTask() async {
        let api = TestMemexAPI(tasks: [PreviewFixtures.task])
        let store = TasksStore(tasks: [PreviewFixtures.task])

        await store.toggle(PreviewFixtures.task, api: api)
        let updatedStatus = await api.lastUpdatedTaskStatus()

        XCTAssertTrue(store.tasks.isEmpty)
        XCTAssertEqual(updatedStatus, .done)
        XCTAssertNil(store.errorMessage)
    }

    func testFailedToggleRollsTaskBack() async {
        let api = TestMemexAPI(tasks: [PreviewFixtures.task])
        await api.setFailure(.expected)
        let store = TasksStore(tasks: [PreviewFixtures.task])

        await store.toggle(PreviewFixtures.task, api: api)

        XCTAssertEqual(store.tasks, [PreviewFixtures.task])
        XCTAssertTrue(store.errorMessage?.contains("Couldn’t update") == true)
    }
}
