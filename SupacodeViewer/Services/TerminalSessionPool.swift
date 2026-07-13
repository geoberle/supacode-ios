import SwiftTerm
import UIKit

@Observable
@MainActor
final class TerminalSessionPool {
    private var entries: [String: PoolEntry] = [:]
    private var connection: Connection?

    struct PoolEntry {
        let session: TerminalSession
        let terminalView: SwiftTerm.TerminalView
        let coordinator: TerminalCoordinator
    }

    func setConnection(_ connection: Connection?) {
        guard connection?.url != self.connection?.url || connection?.token != self.connection?.token else { return }
        stopAll()
        self.connection = connection
    }

    func entry(for surfaceID: String) -> PoolEntry? {
        guard let connection else { return nil }

        if let existing = entries[surfaceID] {
            if case .disconnected = existing.session.connectionStatus {
                existing.session.reconnect()
            }
            return existing
        }

        let session = TerminalSession(connection: connection, surfaceID: surfaceID)
        let terminalView = Self.makeTerminalView()
        let coordinator = TerminalCoordinator()
        coordinator.terminalView = terminalView
        terminalView.terminalDelegate = coordinator
        coordinator.bind(session)
        session.start()

        let poolEntry = PoolEntry(session: session, terminalView: terminalView, coordinator: coordinator)
        entries[surfaceID] = poolEntry
        return poolEntry
    }

    func reconnectAll() {
        for entry in entries.values {
            if case .disconnected = entry.session.connectionStatus {
                entry.session.reconnect()
            }
        }
    }

    func stopAll() {
        for entry in entries.values {
            entry.session.stop()
        }
        entries.removeAll()
    }

    private static func makeTerminalView() -> SwiftTerm.TerminalView {
        _ = swizzleKeyboardDismiss
        let view = SwiftTerm.TerminalView()
        let fontSize: CGFloat = UIDevice.current.userInterfaceIdiom == .pad ? 14 : 11
        let font = UIFont(name: "MesloLGS-NF-Regular", size: fontSize)
            ?? UIFont(name: "Menlo", size: fontSize)
            ?? UIFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        view.font = font
        view.nativeForegroundColor = UIColor(red: 0xD4/255, green: 0xD4/255, blue: 0xD4/255, alpha: 1)
        view.nativeBackgroundColor = UIColor(red: 0x1E/255, green: 0x1E/255, blue: 0x1E/255, alpha: 1)
        view.caretColor = UIColor.white
        return view
    }
}

// MARK: - Coordinator

class TerminalCoordinator: NSObject, TerminalViewDelegate {
    weak var terminalView: SwiftTerm.TerminalView?
    private var currentSession: TerminalSession?
    private var lastCols: Int = 0
    private var lastRows: Int = 0

    @MainActor
    func bind(_ session: TerminalSession) {
        guard currentSession !== session else {
            if lastCols > 0, lastRows > 0 {
                session.sendResize(cols: lastCols, rows: lastRows)
            }
            return
        }
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

// MARK: - Keyboard Dismiss

private let swizzleKeyboardDismiss: Void = {
    let original = NSSelectorFromString("toggleInputKeyboard:")
    let replacement = #selector(TerminalAccessory.supacode_dismissKeyboard(_:))
    guard let origMethod = class_getInstanceMethod(TerminalAccessory.self, original),
          let replMethod = class_getInstanceMethod(TerminalAccessory.self, replacement)
    else { return }
    method_exchangeImplementations(origMethod, replMethod)
}()

extension TerminalAccessory {
    @objc fileprivate func supacode_dismissKeyboard(_ sender: UIButton) {
        _ = terminalView?.resignFirstResponder()
    }
}
