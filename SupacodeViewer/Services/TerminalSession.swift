import Foundation

enum TerminalConnectionStatus: Sendable, Equatable {
    case connecting
    case connected
    case disconnected(String)
    case failed(String)
}

@Observable
@MainActor
final class TerminalSession {
    let surfaceID: String
    var connectionStatus: TerminalConnectionStatus = .connecting

    var onOutput: (([UInt8]) -> Void)?

    private let connection: Connection
    private let session = URLSession.shared
    private var socket: URLSessionWebSocketTask?
    private var receiveTask: Task<Void, Never>?
    private var hasRetriedOnce = false

    init(connection: Connection, surfaceID: String) {
        self.connection = connection
        self.surfaceID = surfaceID
    }

    func start() {
        connect()
    }

    func stop() {
        receiveTask?.cancel()
        receiveTask = nil
        socket?.cancel(with: .goingAway, reason: nil)
        socket = nil
    }

    func send(_ data: ArraySlice<UInt8>) {
        guard let socket else { return }
        let message = URLSessionWebSocketTask.Message.data(Data(data))
        socket.send(message) { _ in }
    }

    func sendResize(cols: Int, rows: Int) {
        guard let socket, cols > 0, rows > 0 else { return }
        let json = #"{"type":"resize","cols":\#(cols),"rows":\#(rows)}"#
        socket.send(.string(json)) { _ in }
    }

    func reconnect() {
        hasRetriedOnce = false
        connect()
    }

    // MARK: - Private

    private func connect() {
        stop()
        connectionStatus = .connecting

        guard var components = URLComponents(
            url: connection.url.appending(path: "/api/terminal/\(surfaceID)"),
            resolvingAgainstBaseURL: false
        ) else {
            connectionStatus = .failed("Invalid URL")
            return
        }
        components.scheme = connection.url.scheme == "https" ? "wss" : "ws"
        components.queryItems = [URLQueryItem(name: "token", value: connection.token)]

        guard let wsURL = components.url else {
            connectionStatus = .failed("Invalid URL")
            return
        }

        let newSocket = session.webSocketTask(with: wsURL)
        socket = newSocket
        newSocket.resume()
        connectionStatus = .connected

        receiveTask = Task { await receiveLoop(newSocket) }
    }

    private func receiveLoop(_ socket: URLSessionWebSocketTask) async {
        while !Task.isCancelled {
            do {
                let message = try await socket.receive()
                if case .data(let data) = message {
                    onOutput?([UInt8](data))
                }
            } catch {
                guard !Task.isCancelled else { return }

                let reason = error.localizedDescription
                if !hasRetriedOnce {
                    hasRetriedOnce = true
                    try? await Task.sleep(for: .seconds(1))
                    guard !Task.isCancelled else { return }
                    connect()
                } else {
                    connectionStatus = .disconnected(reason)
                }
                return
            }
        }
    }
}
