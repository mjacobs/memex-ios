import SwiftUI

struct SettingsView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss
    @State private var store = SettingsStore()
    @FocusState private var focusedField: Field?

    let isSetup: Bool

    private enum Field {
        case server
        case key
    }

    var body: some View {
        Form {
            if isSetup {
                Section {
                    Label("Connect this iPhone to your Memex server.", systemImage: "brain.head.profile")
                        .font(.headline)
                }
            }

            Section("Server") {
                TextField("https://your-service.run.app", text: $store.serverURL)
                    .textContentType(.URL)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($focusedField, equals: .server)
                    .accessibilityIdentifier("settings.serverURL")

                Text("The device key is sent only to this server origin.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Device key") {
                SecureField(
                    store.hasStoredKey ? "Leave blank to keep saved key" : "Paste device key",
                    text: $store.keyInput
                )
                .textContentType(.password)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($focusedField, equals: .key)
                .accessibilityIdentifier("settings.deviceKey")

                if store.hasStoredKey {
                    Label("A key is stored in Keychain", systemImage: "checkmark.shield")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                Button {
                    focusedField = nil
                    Task {
                        if await store.saveAndTest(environment: environment), !isSetup {
                            dismiss()
                        }
                    }
                } label: {
                    HStack {
                        if store.state == .testing {
                            ProgressView()
                        }
                        Text(store.state == .testing ? "Testing…" : "Save & Test Connection")
                    }
                    .frame(maxWidth: .infinity)
                }
                .disabled(store.state == .testing)
                .accessibilityIdentifier("settings.saveAndTest")

                if store.hasStoredKey {
                    Button("Clear device key", role: .destructive) {
                        Task { await store.clearKey(environment: environment) }
                    }
                }
            }

            resultSection
        }
        .navigationTitle(isSetup ? "Set Up Memex" : "Settings")
        .navigationBarTitleDisplayMode(.inline)
        .scrollDismissesKeyboard(.interactively)
        .toolbar {
            if !isSetup {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .task {
            store.load(from: environment)
            if isSetup && store.serverURL.isEmpty {
                focusedField = .server
            }
        }
    }

    @ViewBuilder
    private var resultSection: some View {
        switch store.state {
        case .idle, .testing:
            EmptyView()
        case .success(let message):
            Section {
                Label(message, systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .accessibilityIdentifier("settings.connectionSuccess")
            }
        case .failure(let message):
            Section {
                Label(message, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .accessibilityIdentifier("settings.connectionError")
            }
        }
    }
}

#Preview("Setup") {
    NavigationStack {
        SettingsView(isSetup: true)
    }
    .environment(AppEnvironment.preview(connected: false))
}
