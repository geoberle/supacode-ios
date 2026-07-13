import Foundation

// MARK: - State snapshot (GET /api/state)

struct SupacodeState: Codable, Sendable {
    let repositories: [SupacodeRepository]
}

struct SupacodeRepository: Codable, Sendable {
    let id: String
    let name: String
    let worktrees: [SupacodeWorktree]
}

struct SupacodeWorktree: Codable, Sendable {
    let id: String
    let name: String
    let branchName: String
    let isMainWorktree: Bool
    let repositoryAccent: String?
    let customTint: String?
    let addedLines: Int?
    let removedLines: Int?
    let isFolder: Bool
    let pullRequest: SupacodePullRequest?
    let agents: [SupacodeAgentInstance]
    let tabs: [SupacodeTab]

    var resolvedTint: String? {
        customTint ?? repositoryAccent
    }
}

struct SupacodeTab: Codable, Sendable {
    let id: String
    let worktreeID: String
    let surfaces: [SupacodeSurface]
}

struct SupacodeSurface: Codable, Sendable {
    let id: String
    let isFocused: Bool
    let agents: [SupacodeAgentInstance]
}

struct SupacodePullRequest: Codable, Sendable {
    let number: Int
    let title: String
    let state: String
    let isDraft: Bool
    let reviewDecision: String?
    let mergeable: String?
    let url: String
    let additions: Int
    let deletions: Int
    let statusCheckRollup: SupacodeStatusCheckRollup?
}

struct SupacodeStatusCheckRollup: Codable, Sendable {
    let state: String
    let contexts: [SupacodeCheckRun]
}

struct SupacodeCheckRun: Codable, Sendable {
    let name: String
    let status: String
    let conclusion: String?
    let detailsUrl: String?
}

struct SupacodeAgentInstance: Codable, Sendable {
    let agent: String
    let activity: String
}
