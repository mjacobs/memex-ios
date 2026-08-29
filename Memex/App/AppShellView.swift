import SwiftUI

struct AppShellView: View {
    @Environment(AppEnvironment.self) private var environment

    var body: some View {
        Group {
            if environment.isRestoring {
                ProgressView("Loading Memex…")
            } else if !environment.isReady {
                NavigationStack {
                    SettingsView(isSetup: true)
                }
            } else {
                MainTabsView()
            }
        }
    }
}

#Preview {
    AppShellView()
        .environment(AppEnvironment.preview())
}

private struct MainTabsView: View {
    @State private var selectedTab: AppTab = .feed
    @State private var feedStore = FeedStore()
    @State private var tasksStore = TasksStore()

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                FeedView(store: feedStore)
            }
            .tabItem {
                Label("Feed", systemImage: "list.bullet.rectangle")
            }
            .tag(AppTab.feed)

            NavigationStack {
                TasksView(store: tasksStore)
            }
            .tabItem {
                Label("Tasks", systemImage: "checkmark.circle")
            }
            .tag(AppTab.tasks)
        }
        .tint(.cyan)
    }
}

private enum AppTab: Hashable {
    case feed
    case tasks
}
