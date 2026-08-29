@preconcurrency import AVFAudio
import Foundation

@MainActor
protocol AudioRecording: AnyObject {
    var isRecording: Bool { get }
    var currentTime: TimeInterval { get }
    var normalizedLevel: Double { get }

    func requestPermission() async -> Bool
    func start() throws -> URL
    func stop() -> URL?
    func cancel()
}

@MainActor
final class LiveAudioRecorder: NSObject, AudioRecording {
    private var recorder: AVAudioRecorder?
    private var recordingURL: URL?

    override init() {
        super.init()
        cleanStaleRecordings()
    }

    var isRecording: Bool {
        recorder?.isRecording == true
    }

    var currentTime: TimeInterval {
        recorder?.currentTime ?? 0
    }

    var normalizedLevel: Double {
        guard let recorder, recorder.isRecording else { return 0 }
        recorder.updateMeters()
        let decibels = recorder.averagePower(forChannel: 0)
        guard decibels > -60 else { return 0 }
        return min(1, max(0, pow(10, Double(decibels) / 30)))
    }

    func requestPermission() async -> Bool {
        await AVAudioApplication.requestRecordPermission()
    }

    func start() throws -> URL {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement)
        try session.setActive(true)

        let url = FileManager.default.temporaryDirectory
            .appending(path: "memex-recording-\(UUID().uuidString)")
            .appendingPathExtension("m4a")
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        let recorder = try AVAudioRecorder(url: url, settings: settings)
        recorder.isMeteringEnabled = true
        recorder.prepareToRecord()
        guard recorder.record() else {
            throw AudioRecorderError.couldNotStart
        }
        self.recorder = recorder
        recordingURL = url
        return url
    }

    func stop() -> URL? {
        recorder?.stop()
        recorder = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        let url = recordingURL
        recordingURL = nil
        return url
    }

    func cancel() {
        recorder?.stop()
        recorder = nil
        if let recordingURL {
            try? FileManager.default.removeItem(at: recordingURL)
        }
        recordingURL = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func cleanStaleRecordings() {
        let directory = FileManager.default.temporaryDirectory
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        ) else { return }
        for file in files where file.lastPathComponent.hasPrefix("memex-recording-") {
            try? FileManager.default.removeItem(at: file)
        }
    }
}

enum AudioRecorderError: LocalizedError {
    case couldNotStart

    var errorDescription: String? {
        "Voice recording could not start."
    }
}
