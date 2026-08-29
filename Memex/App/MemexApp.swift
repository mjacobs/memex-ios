import SwiftUI

@main
struct MemexApp: App {
    @State private var environment = AppEnvironment.initial()

    var body: some Scene {
        WindowGroup {
            AppShellView()
                .environment(environment)
                .task {
                    await environment.restoreConnection()
                }
        }
    }
}
