import SwiftUI

struct ContentView: View {
    @Environment(SupacodeConnection.self) private var connection
    @State private var selectedWorktreeID: String?
    @State private var showConnectionSetup = false

    var body: some View {
        NavigationSplitView {
            if let repositories = connection.state?.repositories {
                WorktreeListView(
                    repositories: repositories,
                    selectedWorktreeID: $selectedWorktreeID
                )
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        statusButton
                    }
                }
            } else {
                ContentUnavailableView(
                    statusTitle,
                    systemImage: statusIcon,
                    description: Text(statusDescription)
                )
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        statusButton
                    }
                }
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
        .sheet(isPresented: $showConnectionSetup) {
            ConnectionSetupView()
        }
        .onAppear {
            if connection.connection == nil, ConnectionStore.load() == nil {
                showConnectionSetup = true
            }
        }
    }

    // MARK: - Status Button

    private var statusButton: some View {
        Button {
            showConnectionSetup = true
        } label: {
            Image(systemName: "circle.fill")
                .font(.system(size: 10))
                .foregroundStyle(statusColor)
        }
    }

    private var statusColor: Color {
        switch connection.status {
        case .connected: .green
        case .connecting: .yellow
        case .idle: .gray
        case .error: .red
        }
    }

    // MARK: - Empty State

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
