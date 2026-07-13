import SwiftUI
import SwiftTerm

struct TerminalView: UIViewRepresentable {
    let session: TerminalSession

    func makeUIView(context: Context) -> SwiftTerm.TerminalView {
        let terminalView = SwiftTerm.TerminalView()
        let fontSize: CGFloat = UIDevice.current.userInterfaceIdiom == .pad ? 14 : 11
        let font = UIFont(name: "SFMono-Regular", size: fontSize)
            ?? UIFont(name: "Menlo", size: fontSize)
            ?? UIFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        terminalView.font = font
        terminalView.nativeForegroundColor = UIColor(red: 0xD4/255, green: 0xD4/255, blue: 0xD4/255, alpha: 1)
        terminalView.nativeBackgroundColor = UIColor(red: 0x1E/255, green: 0x1E/255, blue: 0x1E/255, alpha: 1)
        terminalView.caretColor = UIColor.white
        terminalView.terminalDelegate = context.coordinator
        context.coordinator.terminalView = terminalView
        context.coordinator.bind(session)
        return terminalView
    }

    func updateUIView(_ uiView: SwiftTerm.TerminalView, context: Context) {
        context.coordinator.bind(session)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject, TerminalViewDelegate {
        weak var terminalView: SwiftTerm.TerminalView?
        private var currentSession: TerminalSession?
        private var lastCols: Int = 0
        private var lastRows: Int = 0

        @MainActor
        func bind(_ session: TerminalSession) {
            guard currentSession !== session else { return }
            currentSession = session
            session.onOutput = { [weak self] bytes in
                self?.terminalView?.feed(byteArray: bytes[...])
            }
            if lastCols > 0, lastRows > 0 {
                session.sendResize(cols: lastCols, rows: lastRows)
            }
        }

        func send(source: SwiftTerm.TerminalView, data: ArraySlice<UInt8>) {
            Task { @MainActor in
                currentSession?.send(data)
            }
        }

        func sizeChanged(source: SwiftTerm.TerminalView, newCols: Int, newRows: Int) {
            lastCols = newCols
            lastRows = newRows
            Task { @MainActor in
                currentSession?.sendResize(cols: newCols, rows: newRows)
            }
        }
        func setTerminalTitle(source: SwiftTerm.TerminalView, title: String) {}
        func hostCurrentDirectoryUpdate(source: SwiftTerm.TerminalView, directory: String?) {}
        func scrolled(source: SwiftTerm.TerminalView, position: Double) {}
        func requestOpenLink(source: SwiftTerm.TerminalView, link: String, params: [String: String]) {}
        func bell(source: SwiftTerm.TerminalView) {}
        func clipboardCopy(source: SwiftTerm.TerminalView, content: Data) {}
        func iTermContent(source: SwiftTerm.TerminalView, content: ArraySlice<UInt8>) {}
        func rangeChanged(source: SwiftTerm.TerminalView, startY: Int, endY: Int) {}
    }
}
