import SwiftTerm
import SwiftUI

struct TerminalView: UIViewRepresentable {
    let poolEntry: TerminalSessionPool.PoolEntry

    func makeUIView(context: Context) -> UIView {
        let container = UIView()
        let terminal = poolEntry.terminalView
        terminal.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(terminal)
        NSLayoutConstraint.activate([
            terminal.topAnchor.constraint(equalTo: container.topAnchor),
            terminal.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            terminal.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            terminal.trailingAnchor.constraint(equalTo: container.trailingAnchor)
        ])
        return container
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        let terminal = poolEntry.terminalView
        if terminal.superview !== uiView {
            uiView.subviews.forEach { $0.removeFromSuperview() }
            terminal.translatesAutoresizingMaskIntoConstraints = false
            uiView.addSubview(terminal)
            NSLayoutConstraint.activate([
                terminal.topAnchor.constraint(equalTo: uiView.topAnchor),
                terminal.bottomAnchor.constraint(equalTo: uiView.bottomAnchor),
                terminal.leadingAnchor.constraint(equalTo: uiView.leadingAnchor),
                terminal.trailingAnchor.constraint(equalTo: uiView.trailingAnchor)
            ])
        }
    }
}
