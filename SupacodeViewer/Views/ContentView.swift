import SwiftUI

struct ContentView: View {
    @Environment(SupacodeConnection.self) private var connection
    @Environment(TerminalSessionPool.self) private var sessionPool
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
               let surfaces = resolveSurfaces(worktree) {
                TerminalContainerView(surfaces: surfaces, sessionPool: sessionPool)
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

    private func resolveSurfaces(_ worktree: SupacodeWorktree) -> [SupacodeSurface]? {
        guard let tab = worktree.tabs.first, !tab.surfaces.isEmpty else { return nil }
        return tab.surfaces
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
    let surfaces: [SupacodeSurface]
    let sessionPool: TerminalSessionPool

    @State private var selectedSurfaceID: String?

    private var activeSurfaceID: String {
        selectedSurfaceID
            ?? surfaces.first(where: \.isFocused)?.id
            ?? surfaces[0].id
    }

    var body: some View {
        VStack(spacing: 0) {
            if surfaces.count > 1 {
                SurfacePickerView(
                    surfaces: surfaces,
                    selectedID: activeSurfaceID,
                    onSelect: { selectedSurfaceID = $0 }
                )
            }

            ZStack {
                Color(red: 0x1E/255, green: 0x1E/255, blue: 0x1E/255)
                    .ignoresSafeArea()

                if let session = sessionPool.session(for: activeSurfaceID) {
                    TerminalView(session: session)

                    if case .disconnected(let reason) = session.connectionStatus {
                        disconnectedOverlay(reason: reason, surfaceID: session.surfaceID) {
                            session.reconnect()
                        }
                    }
                }
            }
        }
    }

    private func disconnectedOverlay(reason: String, surfaceID: String, onReconnect: @escaping () -> Void) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "bolt.slash")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("Disconnected")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text(reason)
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Text("Surface: \(surfaceID)")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .monospaced()
            Button("Reconnect", action: onReconnect)
                .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.black.opacity(0.6))
    }
}

// MARK: - Surface Picker

private struct SurfacePickerView: View {
    let surfaces: [SupacodeSurface]
    let selectedID: String
    let onSelect: (String) -> Void

    var body: some View {
        HStack(spacing: 2) {
            ForEach(Array(surfaces.enumerated()), id: \.element.id) { index, surface in
                Button {
                    onSelect(surface.id)
                } label: {
                    HStack(spacing: 4) {
                        Text("\(index + 1)")
                            .font(.caption)
                            .fontWeight(surface.id == selectedID ? .bold : .regular)
                        if surface.agents.contains(where: { $0.activity == "busy" }) {
                            Circle()
                                .fill(.yellow)
                                .frame(width: 6, height: 6)
                        } else if let firstAgent = surface.agents.first {
                            Image(agentIconName(firstAgent.agent))
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 12, height: 12)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(surface.id == selectedID ? Color.white.opacity(0.15) : .clear)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .foregroundStyle(surface.id == selectedID ? .primary : .secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .background(Color(red: 0x16/255, green: 0x16/255, blue: 0x16/255))
    }

    private func agentIconName(_ agent: String) -> String {
        switch agent {
        case "claude": return "claude-code-mark"
        default: return "\(agent)-mark"
        }
    }
}
