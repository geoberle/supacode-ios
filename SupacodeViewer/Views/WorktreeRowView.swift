import SwiftUI

struct WorktreeRowView: View {
    let worktree: SupacodeWorktree

    private var nameColor: Color {
        Color(supacodeTint: worktree.customTint) ?? .primary
    }

    private var iconColor: Color {
        guard let pullRequest = worktree.pullRequest else { return .secondary }
        if pullRequest.isDraft { return .gray }
        switch pullRequest.state {
        case "OPEN": return .green
        case "MERGED": return .purple
        case "CLOSED": return .red
        default: return .secondary
        }
    }

    var body: some View {
        Label {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(worktree.name)
                        .font(.body)
                        .foregroundStyle(nameColor)
                        .lineLimit(1)

                    if hasMetadata {
                        metadataRow
                    }
                }

                Spacer()

                if let added = worktree.addedLines, let removed = worktree.removedLines {
                    DiffStatsView(added: added, removed: removed)
                }
            }
        } icon: {
            Group {
                if worktree.isFolder {
                    Image(systemName: "folder")
                } else {
                    Image("git-branch")
                }
            }
            .foregroundStyle(iconColor)
        }
    }

    private var hasMetadata: Bool {
        worktree.pullRequest != nil || !worktree.agents.isEmpty
    }

    private var metadataRow: some View {
        HStack(spacing: 6) {
            if let pullRequest = worktree.pullRequest {
                PRBadgeView(pullRequest: pullRequest)
            }
            if !worktree.agents.isEmpty {
                AgentDotsView(agents: worktree.agents)
            }
        }
    }
}

// MARK: - PR Badge

private struct PRBadgeView: View {
    let pullRequest: SupacodePullRequest

    var body: some View {
        HStack(spacing: 3) {
            Text("#\(pullRequest.number)")
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundStyle(.white)
                .padding(.horizontal, 5)
                .padding(.vertical, 1)
                .background(pillColor, in: Capsule())

            if let checkIcon {
                Image(systemName: checkIcon)
                    .font(.system(size: 9))
                    .foregroundStyle(checkColor)
            }
        }
    }

    private var pillColor: Color {
        if pullRequest.isDraft { return .gray }
        switch pullRequest.state {
        case "OPEN": return .green
        case "MERGED": return .purple
        case "CLOSED": return .red
        default: return .gray
        }
    }

    private var checkIcon: String? {
        guard let rollup = pullRequest.statusCheckRollup else { return nil }
        switch rollup.state {
        case "SUCCESS": return "checkmark.circle.fill"
        case "FAILURE": return "xmark.circle.fill"
        case "PENDING": return "clock.circle.fill"
        default: return nil
        }
    }

    private var checkColor: Color {
        switch pullRequest.statusCheckRollup?.state {
        case "SUCCESS": return .green
        case "FAILURE": return .red
        case "PENDING": return .yellow
        default: return .secondary
        }
    }
}

// MARK: - Diff Stats

private struct DiffStatsView: View {
    let added: Int
    let removed: Int

    var body: some View {
        HStack(spacing: 2) {
            if added > 0 {
                Text("+\(added)")
                    .foregroundStyle(.green)
            }
            if removed > 0 {
                Text("-\(removed)")
                    .foregroundStyle(.red)
            }
        }
        .font(.caption2)
        .fontDesign(.monospaced)
    }
}

// MARK: - Agent Dots

private struct AgentDotsView: View {
    let agents: [SupacodeAgentInstance]

    var body: some View {
        HStack(spacing: 3) {
            ForEach(agents, id: \.agent) { agent in
                AgentDotView(agent: agent)
            }
        }
    }
}

private struct AgentDotView: View {
    let agent: SupacodeAgentInstance

    var body: some View {
        HStack(spacing: 2) {
            ZStack {
                Circle()
                    .fill(dotColor)
                    .frame(width: 7, height: 7)
                if agent.activity == "busy" {
                    PingRing(color: dotColor)
                }
            }
            .frame(width: 14, height: 14)
            Text(agent.agent)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    private var dotColor: Color {
        switch agent.activity {
        case "busy": .yellow
        case "awaitingInput": .blue
        case "idle": .green
        default: .gray
        }
    }
}

// MARK: - Ping Ring Animation

private struct PingRing: View {
    let color: Color

    var body: some View {
        Circle()
            .stroke(color, lineWidth: 0.5)
            .frame(width: 7, height: 7)
            .phaseAnimator([false, true]) { content, expanded in
                content
                    .scaleEffect(expanded ? 2.5 : 1)
                    .opacity(expanded ? 0 : 0.6)
            } animation: { expanded in
                expanded ? .easeOut(duration: 1) : .linear(duration: 0.001)
            }
    }
}
