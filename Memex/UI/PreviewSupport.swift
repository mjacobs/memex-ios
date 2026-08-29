import Foundation

enum PreviewFixtures {
    static let note = Note(
        id: "01previewnote",
        createdAt: "2026-08-29T18:30:00Z",
        kind: "capture",
        summary: "Follow up with the finance agent",
        body: "Remember to **follow up** about the quarterly report.\n\n- Ask for the final numbers\n- Confirm the deadline",
        tags: ["finance", "follow-up"],
        taskIDs: ["01previewtask"],
        trace: [
            TraceEvent(
                t: "2026-08-29T18:30:01Z",
                role: "user",
                text: "Follow up with the finance agent",
                tool: nil,
                args: nil,
                result: nil
            ),
            TraceEvent(
                t: "2026-08-29T18:30:02Z",
                role: "tool",
                text: nil,
                tool: "create_tasks",
                args: ["title": .string("Follow up with the finance agent")],
                result: .object(["task_ids": .array([.string("01previewtask")])])
            )
        ]
    )

    static let digest = Note(
        id: "01previewdigest",
        createdAt: "2026-08-29T10:00:00Z",
        kind: "digest",
        summary: "Daily digest of saved notes and open work",
        body: "## Today\n\nThree notes were captured and two tasks remain open.",
        tags: ["daily-digest"]
    )

    static let task = MemexTask(
        id: "01previewtask",
        title: "Follow up with the finance agent",
        status: .open,
        createdAt: "2026-08-29T18:30:00Z",
        updatedAt: "2026-08-29T18:30:00Z",
        tags: ["finance"],
        sourceNoteID: note.id
    )
}

actor PreviewMemexAPI: MemexAPI {
    func health() async throws {}

    func notes(limit: Int, tag: String?, kind: String?) async throws -> [Note] {
        [PreviewFixtures.note, PreviewFixtures.digest]
            .filter { tag == nil || $0.tags.contains(tag!) }
            .filter { kind == nil || $0.kind == kind }
    }

    func note(id: String) async throws -> Note {
        id == PreviewFixtures.digest.id ? PreviewFixtures.digest : PreviewFixtures.note
    }

    func captureText(_ text: String) async throws -> CaptureResponse {
        try JSONDecoder().decode(
            CaptureResponse.self,
            from: Data(#"{"capture":{"id":"01capture","kind":"text","status":"enriched"},"tasks":[]}"#.utf8)
        )
    }

    func captureAudio(_ data: Data, mimeType: String) async throws -> String {
        "01capture"
    }

    func capture(id: String) async throws -> Capture {
        Capture(
            id: id,
            createdAt: nil,
            source: "ios",
            deviceID: "preview",
            kind: "audio",
            text: nil,
            url: nil,
            status: "enriched",
            error: nil,
            noteID: PreviewFixtures.note.id
        )
    }

    func tasks(status: TaskStatus) async throws -> [MemexTask] {
        var task = PreviewFixtures.task
        task.status = status
        return [task]
    }

    func updateTask(id: String, status: TaskStatus) async throws -> MemexTask {
        var task = PreviewFixtures.task
        task.status = status
        return task
    }
}
