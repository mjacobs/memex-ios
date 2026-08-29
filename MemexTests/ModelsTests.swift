import XCTest
@testable import Memex

final class ModelsTests: XCTestCase {}

extension ModelsTests {
    func testNoteListPayloadDecodesWithoutDetailTrace() throws {
        let data = Data(
            #"{"notes":[{"id":"01note","created_at":"2026-08-29T18:30:00Z","kind":"capture","summary":"Summary","body":"Body","tags":["ios"],"task_ids":["01task"]}]}"#.utf8
        )

        let response = try JSONDecoder().decode(NotesResponse.self, from: data)

        XCTAssertEqual(response.notes.count, 1)
        XCTAssertEqual(response.notes[0].summary, "Summary")
        XCTAssertEqual(response.notes[0].trace, [])
        XCTAssertEqual(response.notes[0].taskIDs, ["01task"])
    }

    func testTracePreservesArbitraryToolJSON() throws {
        let data = Data(
            #"{"t":"2026-08-29T18:30:00Z","role":"tool","tool":"create_tasks","args":{"count":2,"enabled":true},"result":{"ids":["a","b"]}}"#.utf8
        )

        let event = try JSONDecoder().decode(TraceEvent.self, from: data)

        XCTAssertEqual(event.args?["count"], .number(2))
        XCTAssertEqual(event.args?["enabled"], .bool(true))
        XCTAssertTrue(event.result?.prettyPrinted.contains("ids") == true)
    }
}
