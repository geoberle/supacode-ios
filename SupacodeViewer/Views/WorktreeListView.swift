import SwiftUI

struct WorktreeListView: View {
    let repositories: [SupacodeRepository]
    @Binding var selectedWorktreeID: String?

    var body: some View {
        List(selection: $selectedWorktreeID) {
            ForEach(repositories, id: \.id) { repo in
                Section {
                    ForEach(repo.worktrees, id: \.id) { worktree in
                        WorktreeRowView(worktree: worktree)
                            .tag(worktree.id)
                    }
                } header: {
                    RepoHeaderView(repository: repo)
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Supacode")
    }
}

private struct RepoHeaderView: View {
    let repository: SupacodeRepository

    var body: some View {
        let accentColor = repository.worktrees.first.flatMap {
            Color(supacodeTint: $0.repositoryAccent)
        }
        Text(repository.name)
            .foregroundStyle(accentColor ?? .secondary)
    }
}

private struct WorktreeRowView: View {
    let worktree: SupacodeWorktree

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(worktree.name)
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color(supacodeTint: worktree.resolvedTint) ?? .primary)
                Text(worktree.branchName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: worktree.isFolder ? "folder" : "arrow.triangle.branch")
                .foregroundStyle(Color(supacodeTint: worktree.resolvedTint) ?? .secondary)
        }
    }
}
