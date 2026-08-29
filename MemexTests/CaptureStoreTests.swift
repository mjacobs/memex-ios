import XCTest
@testable import Memex

@MainActor
final class CaptureStoreTests: XCTestCase {
    func testTextCaptureTrimsAndSubmits() async {
        let api = TestMemexAPI()
        let store = CaptureStore(recorder: TestAudioRecorder())
        store.text = "  Remember this  \n"

        let succeeded = await store.submitText(api: api)
        let capturedText = await api.lastCapturedText()

        XCTAssertTrue(succeeded)
        XCTAssertEqual(store.phase, .success)
        XCTAssertEqual(capturedText, "Remember this")
    }

    func testVoiceCaptureUploadsThenPollsUntilEnriched() async {
        let pending = capture(status: "pending")
        let enriched = capture(status: "enriched")
        let api = TestMemexAPI(captures: [pending, enriched])
        let recorder = TestAudioRecorder()
        let store = CaptureStore(recorder: recorder, pollDelay: .zero, maxPollAttempts: 3)

        await store.startRecording()
        let succeeded = await store.stopAndSubmit(api: api)

        XCTAssertTrue(succeeded)
        XCTAssertEqual(store.phase, .success)
    }

    func testVoiceCaptureTimeoutKeepsCaptureIDVisible() async {
        let api = TestMemexAPI(captures: [capture(status: "pending"), capture(status: "processing")])
        let store = CaptureStore(
            recorder: TestAudioRecorder(),
            pollDelay: .zero,
            maxPollAttempts: 2
        )

        await store.startRecording()
        let succeeded = await store.stopAndSubmit(api: api)

        XCTAssertFalse(succeeded)
        XCTAssertEqual(store.phase, .timeout(id: "01capture"))
    }

    private func capture(status: String) -> Capture {
        Capture(
            id: "01capture",
            createdAt: nil,
            source: "ios",
            deviceID: "test",
            kind: "audio",
            text: nil,
            url: nil,
            status: status,
            error: nil,
            noteID: nil
        )
    }
}

@MainActor
private final class TestAudioRecorder: AudioRecording {
    private var url: URL?
    private(set) var isRecording = false
    var currentTime: TimeInterval { isRecording ? 1 : 0 }
    var normalizedLevel: Double { isRecording ? 0.5 : 0 }

    func requestPermission() async -> Bool { true }

    func start() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString).appendingPathExtension("m4a")
        try Data("audio".utf8).write(to: url)
        self.url = url
        isRecording = true
        return url
    }

    func stop() -> URL? {
        isRecording = false
        let result = url
        url = nil
        return result
    }

    func cancel() {
        isRecording = false
        if let url { try? FileManager.default.removeItem(at: url) }
        url = nil
    }
}
