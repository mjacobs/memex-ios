import Foundation
import Observation

enum CaptureMode: String, CaseIterable, Identifiable {
    case text
    case voice

    var id: String { rawValue }
    var label: String { rawValue.capitalized }
}

enum CapturePhase: Equatable {
    case idle
    case requestingPermission
    case recording
    case uploading
    case processing(id: String, attempt: Int)
    case success
    case timeout(id: String)
    case failure(String)
}

@MainActor
@Observable
final class CaptureStore {
    var mode: CaptureMode = .text
    var text = ""
    private(set) var phase: CapturePhase = .idle
    private(set) var duration: TimeInterval = 0
    private(set) var level: Double = 0

    @ObservationIgnored private let recorder: any AudioRecording
    @ObservationIgnored private let pollDelay: Duration
    @ObservationIgnored private let maxPollAttempts: Int
    @ObservationIgnored private var meterTask: Task<Void, Never>?

    init(
        recorder: any AudioRecording = LiveAudioRecorder(),
        pollDelay: Duration = .seconds(1),
        maxPollAttempts: Int = 30
    ) {
        self.recorder = recorder
        self.pollDelay = pollDelay
        self.maxPollAttempts = maxPollAttempts
    }

    var isBusy: Bool {
        switch phase {
        case .requestingPermission, .recording, .uploading, .processing:
            true
        case .idle, .success, .timeout, .failure:
            false
        }
    }

    func setMode(_ mode: CaptureMode) {
        guard !isBusy else { return }
        self.mode = mode
        phase = .idle
    }

    func submitText(api: any MemexAPI) async -> Bool {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else {
            phase = .failure("Write something to capture.")
            return false
        }
        phase = .uploading
        do {
            _ = try await api.captureText(value)
            phase = .success
            return true
        } catch is CancellationError {
            phase = .idle
            return false
        } catch {
            phase = .failure(error.localizedDescription)
            return false
        }
    }

    func startRecording() async {
        phase = .requestingPermission
        let granted = await recorder.requestPermission()
        guard !Task.isCancelled else {
            phase = .idle
            return
        }
        guard granted else {
            phase = .failure("Microphone access is required for voice capture. You can enable it in Settings.")
            return
        }

        do {
            _ = try recorder.start()
            duration = 0
            level = 0
            phase = .recording
            startMetering()
        } catch {
            phase = .failure(error.localizedDescription)
        }
    }

    func stopAndSubmit(api: any MemexAPI) async -> Bool {
        guard case .recording = phase,
              let url = recorder.stop()
        else {
            return false
        }
        meterTask?.cancel()
        meterTask = nil
        phase = .uploading
        defer { try? FileManager.default.removeItem(at: url) }

        do {
            let data = try Data(contentsOf: url)
            try Task.checkCancellation()
            let id = try await api.captureAudio(data, mimeType: "audio/mp4")
            for attempt in 1...maxPollAttempts {
                try Task.checkCancellation()
                phase = .processing(id: id, attempt: attempt)
                let capture = try await api.capture(id: id)
                switch capture.status {
                case "enriched":
                    phase = .success
                    return true
                case "failed":
                    phase = .failure(capture.error ?? "Voice capture enrichment failed.")
                    return false
                default:
                    if attempt < maxPollAttempts {
                        try await Task.sleep(for: pollDelay)
                    }
                }
            }
            phase = .timeout(id: id)
            return false
        } catch is CancellationError {
            phase = .idle
            return false
        } catch {
            phase = .failure(error.localizedDescription)
            return false
        }
    }

    func discardRecording() {
        meterTask?.cancel()
        meterTask = nil
        recorder.cancel()
        duration = 0
        level = 0
        phase = .idle
    }

    func cancel() {
        discardRecording()
    }

    private func startMetering() {
        meterTask?.cancel()
        meterTask = Task { [weak self] in
            while let self, !Task.isCancelled, self.recorder.isRecording {
                self.duration = self.recorder.currentTime
                self.level = self.recorder.normalizedLevel
                try? await Task.sleep(for: .milliseconds(100))
            }
        }
    }
}
