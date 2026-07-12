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
            if let worktree = selectedWorktree,
               let surfaceID = resolveSurfaceID(worktree),
               let conn = connection.connection {
                TerminalContainerView(
                    connection: conn,
                    surfaceID: surfaceID
                )
            } else if selectedWorktreeID != nil {
                ContentUnavailableView(
                    "No Terminal Session",
                    systemImage: "terminal",
                    description: Text("This worktree has no active terminal")
                )
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

    // MARK: - Worktree Resolution

    private var selectedWorktree: SupacodeWorktree? {
        guard let selectedWorktreeID else { return nil }
        return connection.state?.repositories
            .flatMap(\.worktrees)
            .first { $0.id == selectedWorktreeID }
    }

    private func resolveSurfaceID(_ worktree: SupacodeWorktree) -> String? {
        guard let tab = worktree.tabs.first else { return nil }
        return tab.activeSurfaceID ?? tab.surfaceIDs.first
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

// MARK: - Terminal Container

private struct TerminalContainerView: View {
    let connection: Connection
    let surfaceID: String

    @State private var session: TerminalSession?

    var body: some View {
        ZStack {
            Color(red: 0x1E/255, green: 0x1E/255, blue: 0x1E/255)
                .ignoresSafeArea()

            if let session {
                TerminalView(session: session)
                    .ignoresSafeArea(.keyboard)

                if session.connectionStatus == .disconnected {
                    disconnectedOverlay
                }
            } else {
                ProgressView("Connecting…")
                    .foregroundStyle(.secondary)
            }
        }
        .task(id: surfaceID) {
            let newSession = TerminalSession(connection: connection, surfaceID: surfaceID)
            session = newSession
            newSession.start()
        }
        .onDisappear {
            session?.stop()
            session = nil
        }
    }

    private var disconnectedOverlay: some View {
        VStack(spacing: 12) {
            Image(systemName: "bolt.slash")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("Disconnected")
                .font(.headline)
                .foregroundStyle(.secondary)
            Button("Reconnect") {
                session?.reconnect()
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.black.opacity(0.6))
    }
}
