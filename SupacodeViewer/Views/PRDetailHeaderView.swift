import SwiftUI

struct PRDetailHeaderView: View {
    let pullRequest: SupacodePullRequest
    @State private var isExpanded = false

    var body: some View {
        VStack(spacing: 0) {
            collapsedBar
            if isExpanded {
                expandedContent
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(Color(red: 0x25/255, green: 0x25/255, blue: 0x26/255))
    }

    // MARK: - Collapsed Bar

    private var collapsedBar: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                isExpanded.toggle()
            }
        } label: {
            HStack(spacing: 8) {
                prPill

                Text(pullRequest.title)
                    .font(.caption)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Spacer()

                if pullRequest.mergeable == "CONFLICTING" {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }

                if let rollup = pullRequest.statusCheckRollup {
                    checkSummaryBadge(rollup: rollup)
                }

                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var prPill: some View {
        Text("#\(pullRequest.number)")
            .font(.caption2)
            .fontWeight(.medium)
            .foregroundStyle(.white)
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background(pillColor, in: Capsule())
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

    private func checkSummaryBadge(rollup: SupacodeStatusCheckRollup) -> some View {
        let failed = rollup.contexts.filter { $0.conclusion == "FAILURE" }.count
        let total = rollup.contexts.count

        return HStack(spacing: 3) {
            Circle()
                .fill(failed > 0 ? .red : .green)
                .frame(width: 6, height: 6)
            Text("\(failed)/\(total)")
                .font(.caption2)
                .fontDesign(.monospaced)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Expanded Content

    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            Divider()
                .overlay(Color.white.opacity(0.1))

            VStack(alignment: .leading, spacing: 8) {
                if pullRequest.mergeable == "CONFLICTING" {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text("Merge Conflicts")
                            .foregroundStyle(.orange)
                    }
                    .font(.caption)
                }

                if let rollup = pullRequest.statusCheckRollup {
                    checkList(rollup: rollup)
                }

                Link(destination: URL(string: pullRequest.url)!) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.right.square")
                        Text("Open Pull Request")
                    }
                    .font(.caption)
                    .foregroundStyle(.blue)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
    }

    private func checkList(rollup: SupacodeStatusCheckRollup) -> some View {
        let sorted = rollup.contexts.sorted { a, b in
            let order = checkSortOrder(a) - checkSortOrder(b)
            if order != 0 { return order < 0 }
            return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
        }

        let failed = sorted.filter { $0.conclusion == "FAILURE" }.count
        let succeeded = sorted.filter { $0.conclusion == "SUCCESS" }.count

        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(checkSummaryText(failed: failed, succeeded: succeeded))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(sorted, id: \.name) { check in
                        checkRow(check)
                    }
                }
            }
            .frame(maxHeight: 200)
        }
    }

    private func checkRow(_ check: SupacodeCheckRun) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(checkDotColor(check))
                .frame(width: 8, height: 8)
            Text(check.name)
                .font(.caption)
                .foregroundStyle(.primary)
                .lineLimit(1)
            Spacer()
            Text(checkLabel(check))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private func checkDotColor(_ check: SupacodeCheckRun) -> Color {
        switch check.conclusion {
        case "FAILURE": return .red
        case "SUCCESS": return .green
        default:
            return check.status == "COMPLETED" ? .gray : .yellow
        }
    }

    private func checkLabel(_ check: SupacodeCheckRun) -> String {
        switch check.conclusion {
        case "FAILURE": return "Failed"
        case "SUCCESS": return "Success"
        default:
            return check.status == "COMPLETED" ? check.conclusion ?? "" : "Pending"
        }
    }

    private func checkSortOrder(_ check: SupacodeCheckRun) -> Int {
        switch check.conclusion {
        case "FAILURE": return 0
        case "SUCCESS": return 2
        default: return 1
        }
    }

    private func checkSummaryText(failed: Int, succeeded: Int) -> String {
        var parts: [String] = []
        if failed > 0 { parts.append("\(failed) failed") }
        if succeeded > 0 { parts.append("\(succeeded) successful") }
        return parts.joined(separator: ", ")
    }
}
