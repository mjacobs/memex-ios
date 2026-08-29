import Foundation
import Observation

@MainActor
@Observable
final class TasksStore {
    private(set) var tasks: [MemexTask]
    private(set) var isLoading = false
    private(set) var hasLoaded = false
    private(set) var mutatingIDs: Set<String> = []
    private(set) var errorMessage: String?
    var selectedStatus: TaskStatus = .open
    private var loadGeneration = 0

    init(tasks: [MemexTask] = []) {
        self.tasks = tasks
        hasLoaded = !tasks.isEmpty
    }

    func load(api: any MemexAPI, force: Bool = false) async {
        guard force || !hasLoaded else { return }
        loadGeneration += 1
        let generation = loadGeneration
        let requestedStatus = selectedStatus
        isLoading = true
        errorMessage = nil
        defer {
            if generation == loadGeneration {
                isLoading = false
                hasLoaded = true
            }
        }
        do {
            let loadedTasks = try await api.tasks(status: requestedStatus)
            guard generation == loadGeneration,
                  requestedStatus == selectedStatus
            else { return }
            tasks = loadedTasks
        } catch is CancellationError {
            return
        } catch {
            if generation == loadGeneration {
                errorMessage = error.localizedDescription
            }
        }
    }

    func select(_ status: TaskStatus, api: any MemexAPI) async {
        guard status != selectedStatus else { return }
        selectedStatus = status
        hasLoaded = false
        tasks = []
        await load(api: api, force: true)
    }

    func toggle(_ task: MemexTask, api: any MemexAPI) async {
        guard task.status != .dropped,
              !mutatingIDs.contains(task.id),
              let index = tasks.firstIndex(where: { $0.id == task.id })
        else {
            return
        }

        let original = tasks[index]
        let newStatus: TaskStatus = task.status == .done ? .open : .done
        mutatingIDs.insert(task.id)
        errorMessage = nil
        tasks.remove(at: index)
        defer { mutatingIDs.remove(task.id) }

        do {
            _ = try await api.updateTask(id: task.id, status: newStatus)
        } catch is CancellationError {
            tasks.insert(original, at: min(index, tasks.count))
        } catch {
            tasks.insert(original, at: min(index, tasks.count))
            errorMessage = "Couldn’t update \"\(task.title)\". \(error.localizedDescription)"
        }
    }
}
