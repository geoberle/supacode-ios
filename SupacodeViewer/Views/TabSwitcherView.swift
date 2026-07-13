import SwiftUI

struct TabSwitcherView: View {
    let worktreeName: String
    let tabs: [SupacodeTab]
    let selectedTabID: String
    let onSelect: (String) -> Void

    var body: some View {
        HStack(spacing: 0) {
            Text(worktreeName)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Spacer()

            HStack(spacing: 2) {
                ForEach(Array(zip(tabs.indices, tabs)), id: \.1.id) { index, tab in
                    Button {
                        onSelect(tab.id)
                    } label: {
                        HStack(spacing: 4) {
                            Text("\(index + 1)")
                                .font(.caption)
                                .fontWeight(tab.id == selectedTabID ? .bold : .regular)
                            if isBusy(tab) {
                                Circle()
                                    .fill(.yellow)
                                    .frame(width: 6, height: 6)
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(tab.id == selectedTabID ? Color.white.opacity(0.15) : .clear)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(tab.id == selectedTabID ? .primary : .secondary)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .background(Color(red: 0x25/255, green: 0x25/255, blue: 0x26/255))
    }

    private func isBusy(_ tab: SupacodeTab) -> Bool {
        tab.surfaces.contains { surface in
            surface.agents.contains { $0.activity == "busy" }
        }
    }
}
