import SwiftUI

struct CaptureView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss
    @State private var store = CaptureStore()
    @State private var operation: Task<Void, Never>?
    @FocusState private var textFocused: Bool

    let onSuccess: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Picker("Capture type", selection: modeBinding) {
                ForEach(CaptureMode.allCases) { mode in
                    Label(mode.label, systemImage: mode == .text ? "text.alignleft" : "waveform")
                        .tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .disabled(store.isBusy)

            Group {
                switch store.mode {
                case .text:
                    textCapture
                case .voice:
                    voiceCapture
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding()
        .navigationTitle("Quick Capture")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
                    .disabled(store.phase == .uploading || isProcessing)
            }
        }
        .interactiveDismissDisabled(store.isBusy)
        .onDisappear {
            operation?.cancel()
            store.cancel()
        }
        .task {
            if store.mode == .text {
                textFocused = true
            }
        }
    }

    private var modeBinding: Binding<CaptureMode> {
        Binding(
            get: { store.mode },
            set: { mode in
                store.setMode(mode)
                textFocused = mode == .text
            }
        )
    }

    private var textCapture: some View {
        VStack(spacing: 16) {
            TextEditor(text: $store.text)
                .focused($textFocused)
                .font(.body)
                .padding(10)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 14))
                .overlay(alignment: .topLeading) {
                    if store.text.isEmpty {
                        Text("What’s on your mind?")
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 15)
                            .padding(.vertical, 18)
                            .allowsHitTesting(false)
                    }
                }
                .accessibilityIdentifier("capture.text")

            phaseMessage

            Button {
                guard let api = environment.api else { return }
                operation = Task {
                    if await store.submitText(api: api) {
                        onSuccess()
                    }
                }
            } label: {
                Label(store.phase == .uploading ? "Saving…" : "Capture Note", systemImage: "arrow.up.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(store.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || store.isBusy)
            .accessibilityIdentifier("capture.submitText")
        }
    }

    @ViewBuilder
    private var voiceCapture: some View {
        VStack(spacing: 24) {
            Spacer()

            waveform

            Text(durationText)
                .font(.system(.title, design: .monospaced).weight(.semibold))
                .contentTransition(.numericText())
                .accessibilityLabel("Recording duration \(durationText)")

            phaseMessage

            switch store.phase {
            case .requestingPermission:
                ProgressView("Requesting microphone access…")
            case .recording:
                HStack(spacing: 24) {
                    Button("Discard", role: .destructive) {
                        store.discardRecording()
                    }
                    .buttonStyle(.bordered)

                    Button {
                        guard let api = environment.api else { return }
                        operation = Task {
                            if await store.stopAndSubmit(api: api) {
                                onSuccess()
                            }
                        }
                    } label: {
                        Label("Stop & Send", systemImage: "stop.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .accessibilityIdentifier("capture.stopRecording")
                }
            case .uploading, .processing:
                ProgressView(store.phase == .uploading ? "Uploading audio…" : "Memex is processing…")
            default:
                Button {
                    operation = Task { await store.startRecording() }
                } label: {
                    Label("Start Recording", systemImage: "mic.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .accessibilityIdentifier("capture.startRecording")
            }

            Spacer()
        }
    }

    private var waveform: some View {
        HStack(alignment: .center, spacing: 5) {
            ForEach(0..<15, id: \.self) { index in
                Capsule()
                    .fill(store.phase == .recording ? Color.cyan : Color.secondary.opacity(0.4))
                    .frame(
                        width: 5,
                        height: max(8, 18 + store.level * Double(12 + (index % 5) * 7))
                    )
                    .animation(.easeOut(duration: 0.1), value: store.level)
            }
        }
        .frame(height: 90)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var phaseMessage: some View {
        switch store.phase {
        case .failure(let message):
            ErrorNotice(message: message, retry: nil)
        case .timeout(let id):
            ErrorNotice(
                message: "Upload succeeded, but processing is still running. Capture \(id) may appear in Feed shortly.",
                retry: nil
            )
        default:
            EmptyView()
        }
    }

    private var isProcessing: Bool {
        if case .processing = store.phase { return true }
        return false
    }

    private var durationText: String {
        let seconds = Int(store.duration)
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
}

#Preview("Text Capture") {
    NavigationStack {
        CaptureView(onSuccess: {})
    }
    .environment(AppEnvironment.preview())
}
