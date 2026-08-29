import SwiftUI

struct TasksView: View {
    @Environment(AppEnvironment.self) private var environment
    let store: TasksStore

    var body: some View {
        VStack(spacing: 0) {
            Picker("Task status", selection: statusBinding) {
                ForEach(TaskStatus.allCases) { status in
                    Text(status.label).tag(status)
                }
            }
            .pickerStyle(.segmented)
            .padding()
            .accessibilityIdentifier("tasks.status")

            content
        }
        .navigationTitle("Tasks")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Refresh", systemImage: "arrow.clockwise") { refresh() }
                    .disabled(store.isLoading)
            }
        }
        .task(id: environment.connectionVersion) {
            guard let api = environment.api else { return }
            await store.load(api: api, force: environment.connectionVersion > 0)
        }
    }

    @ViewBuilder
    private var content: some View {
        if store.isLoading && !store.hasLoaded {
            List(0..<4, id: \.self) { _ in
                TaskRow(task: PreviewFixtures.task, isMutating: false, action: {})
                    .redacted(reason: .placeholder)
            }
            .listStyle(.plain)
        } else if let error = store.errorMessage, store.tasks.isEmpty {
            ContentUnavailableView {
                Label("Couldn’t load Tasks", systemImage: "wifi.exclamationmark")
            } description: {
                Text(error)
            } actions: {
                Button("Retry") { refresh() }
            }
        } else if store.tasks.isEmpty {
            ContentUnavailableView(
                "No \(store.selectedStatus.label.lowercased()) tasks",
                systemImage: store.selectedStatus == .open ? "checkmark.circle" : "tray"
            )
        } else {
            List {
                if let error = store.errorMessage {
                    ErrorNotice(message: error, retry: nil)
                        .listRowSeparator(.hidden)
                }
                ForEach(store.tasks) { task in
                    TaskRow(
                        task: task,
                        isMutating: store.mutatingIDs.contains(task.id)
                    ) {
                        toggle(task)
                    }
                    .listRowSeparator(.hidden)
                }
            }
            .listStyle(.plain)
            .refreshable {
                guard let api = environment.api else { return }
                await store.load(api: api, force: true)
            }
        }
    }

    private var statusBinding: Binding<TaskStatus> {
        Binding(
            get: { store.selectedStatus },
            set: { status in
                guard let api = environment.api else { return }
                Task { await store.select(status, api: api) }
            }
        )
    }

    private func refresh() {
        guard let api = environment.api else { return }
        Task { await store.load(api: api, force: true) }
    }

    private func toggle(_ task: MemexTask) {
        guard let api = environment.api else { return }
        Task { await store.toggle(task, api: api) }
    }
}

private struct TaskRow: View {
    let task: MemexTask
    let isMutating: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    Image(systemName: icon)
                        .font(.title3)
                        .foregroundStyle(iconColor)
                    if isMutating {
                        ProgressView()
                            .controlSize(.small)
                    }
                }
                .frame(width: 26, height: 26)

                VStack(alignment: .leading, spacing: 8) {
                    Text(task.title)
                        .font(.body.weight(.medium))
                        .strikethrough(task.status != .open)
                        .foregroundStyle(task.status == .dropped ? .secondary : .primary)
                        .multilineTextAlignment(.leading)

                    HStack {
                        ForEach(task.tags.prefix(3), id: \.self) { tag in
                            TagChip(tag: tag)
                        }
                        Spacer()
                        Text(MemexDateFormatting.displayDate(task.updatedAt))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(task.status == .dropped || isMutating)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(task.status == .dropped ? "" : "Double tap to mark \(task.status == .done ? "open" : "done")")
        .accessibilityIdentifier("tasks.task.\(task.id)")
    }

    private var icon: String {
        switch task.status {
        case .open: "circle"
        case .done: "checkmark.circle.fill"
        case .dropped: "minus.circle.fill"
        }
    }

    private var iconColor: Color {
        switch task.status {
        case .open: .cyan
        case .done: .green
        case .dropped: .secondary
        }
    }

    private var accessibilityLabel: String {
        "\(task.title), \(task.status.label)"
    }
}

#Preview("Open Tasks") {
    NavigationStack {
        TasksView(store: TasksStore(tasks: [PreviewFixtures.task]))
    }
    .environment(AppEnvironment.preview())
}
