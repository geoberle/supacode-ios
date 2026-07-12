import SwiftUI

struct ContentView: View {
    @Environment(SupacodeConnection.self) private var connection
    @State private var selectedWorktreeID: String?

    var body: some View {
        NavigationSplitView {
            if let repositories = connection.state?.repositories {
                WorktreeListView(
                    repositories: repositories,
                    selectedWorktreeID: $selectedWorktreeID
                )
            } else {
                ContentUnavailableView(
                    statusTitle,
                    systemImage: statusIcon,
                    description: Text(statusDescription)
                )
            }
        } detail: {
            if selectedWorktreeID != nil {
                Text("Terminal placeholder")
                    .foregroundStyle(.secondary)
            } else {
                ContentUnavailableView(
                    "Select a Worktree",
                    systemImage: "arrow.triangle.branch",
                    description: Text("Choose a worktree from the sidebar")
                )
            }
        }
    }

    private var statusTitle: String {
        switch connection.status {
        case .idle: "No Connection"
        case .connecting: "Connecting…"
        case .connected: "No Worktrees"
        case .error: "Connection Error"
        }
    }

    private var statusIcon: String {
        switch connection.status {
        case .idle: "link.badge.plus"
        case .connecting: "antenna.radiowaves.left.and.right"
        case .connected: "tray"
        case .error: "exclamationmark.triangle"
        }
    }

    private var statusDescription: String {
        switch connection.status {
        case .idle: "Configure a connection to get started"
        case .connecting: "Fetching workspace state…"
        case .connected: "No worktrees found"
        case .error(let error):
            switch error {
            case .unauthorized: "Invalid token — re-pair with your Mac"
            case .serverUnavailable: "Supacode server is not ready"
            case .networkError(let message): message
            case .decodingFailed: "Unexpected response format"
            }
        }
    }
}
