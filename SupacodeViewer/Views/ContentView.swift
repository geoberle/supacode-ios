import Combine
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
            if let (repository, worktree) = selectedRepositoryAndWorktree,
               !worktree.tabs.isEmpty {
                TerminalContainerView(
                    repositoryName: repository.name,
                    worktreeName: worktree.name,
                    tabs: worktree.tabs,
                    sessionPool: sessionPool
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

    private var selectedRepositoryAndWorktree: (SupacodeRepository, SupacodeWorktree)? {
        guard let selectedWorktreeID else { return nil }
        for repository in connection.state?.repositories ?? [] {
            if let worktree = repository.worktrees.first(where: { $0.id == selectedWorktreeID }) {
                return (repository, worktree)
            }
        }
        return nil
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
    let repositoryName: String
    let worktreeName: String
    let tabs: [SupacodeTab]
    let sessionPool: TerminalSessionPool

    @State private var selectedTabID: String?
    @State private var selectedSurfaceID: String?
    @State private var keyboardHeight: CGFloat = 0

    private var activeTab: SupacodeTab {
        tabs.first { $0.id == selectedTabID } ?? tabs[0]
    }

    private var surfaces: [SupacodeSurface] {
        activeTab.surfaces
    }

    private var activeSurfaceID: String? {
        guard !surfaces.isEmpty else { return nil }
        if let selectedSurfaceID, surfaces.contains(where: { $0.id == selectedSurfaceID }) {
            return selectedSurfaceID
        }
        return surfaces.first(where: \.isFocused)?.id ?? surfaces[0].id
    }

    var body: some View {
        VStack(spacing: 0) {
            if tabs.count > 1 {
                TabSwitcherView(
                    worktreeName: worktreeName,
                    tabs: tabs,
                    selectedTabID: activeTab.id,
                    onSelect: { tabID in
                        selectedTabID = tabID
                        selectedSurfaceID = nil
                    }
                )
            }

            ZStack {
                Color(red: 0x1E/255, green: 0x1E/255, blue: 0x1E/255)
                    .ignoresSafeArea()

                if let activeSurfaceID, let entry = sessionPool.entry(for: activeSurfaceID) {
                    TerminalView(poolEntry: entry)

                    if case .disconnected(let reason) = entry.session.connectionStatus {
                        disconnectedOverlay(reason: reason, surfaceID: entry.session.surfaceID) {
                            entry.session.reconnect()
                        }
                    } else if !entry.session.hasReceivedData {
                        waitingOverlay(surfaceID: entry.session.surfaceID)
                    }
                }
            }
        }
        .padding(.bottom, keyboardHeight)
        .ignoresSafeArea(.keyboard)
        .onReceive(
            NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)
        ) { notification in
            guard let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
                  let window = UIApplication.shared.connectedScenes
                      .compactMap({ $0 as? UIWindowScene })
                      .flatMap(\.windows)
                      .first(where: \.isKeyWindow)
            else { return }
            keyboardHeight = max(0, window.frame.height - frame.origin.y - window.safeAreaInsets.bottom)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                HStack(spacing: 8) {
                    Text("\(repositoryName) / \(worktreeName)")
                        .font(.headline)
                        .lineLimit(1)
                    if surfaces.count > 1 {
                        SurfacePickerView(
                            surfaces: surfaces,
                            selectedID: activeSurfaceID ?? "",
                            onSelect: { selectedSurfaceID = $0 }
                        )
                        .fixedSize()
                    }
                }
            }
        }
    }

    private func waitingOverlay(surfaceID: String) -> some View {
        VStack(spacing: 12) {
            ProgressView()
                .tint(.secondary)
            Text("Waiting for terminal…")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("Surface: \(surfaceID)")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .monospaced()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.black.opacity(0.6))
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
            ForEach(Array(zip(surfaces.indices, surfaces)), id: \.1.id) { index, surface in
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
        }
    }

    private func agentIconName(_ agent: String) -> String {
        switch agent {
        case "claude": return "claude-code-mark"
        default: return "\(agent)-mark"
        }
    }
}
