import Foundation

enum ConnectionStatus: Sendable, Equatable {
    case idle
    case connecting
    case connected
    case error(ConnectionError)

    var isError: Bool {
        if case .error = self { return true }
        return false
    }
}

enum ConnectionError: Sendable, Equatable {
    case unauthorized
    case serverUnavailable
    case networkError(String)
    case decodingFailed
}

@Observable
@MainActor
final class SupacodeConnection {
    var connection: Connection? {
        didSet { connectionDidChange() }
    }
    var status: ConnectionStatus = .idle
    var state: SupacodeState?

    private let session = URLSession.shared
    private var eventTask: Task<Void, Never>?
    private var debounceTask: Task<Void, Never>?
    private var pollTask: Task<Void, Never>?

    // MARK: - REST

    func fetchState() async {
        guard let connection else {
            status = .idle
            return
        }

        if state == nil, !status.isError {
            status = .connecting
        }

        var request = URLRequest(url: connection.url.appending(path: "/api/state"))
        request.setValue("Bearer \(connection.token)", forHTTPHeaderField: "Authorization")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            status = .error(.networkError(error.localizedDescription))
            return
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            status = .error(.networkError("Invalid response"))
            return
        }

        switch httpResponse.statusCode {
        case 200:
            break
        case 401:
            status = .error(.unauthorized)
            return
        case 503:
            status = .error(.serverUnavailable)
            return
        default:
            status = .error(.networkError("HTTP \(httpResponse.statusCode)"))
            return
        }

        do {
            state = try JSONDecoder().decode(SupacodeState.self, from: data)
            status = .connected
        } catch {
            status = .error(.decodingFailed)
        }
    }

    // MARK: - Event WebSocket

    func connect() {
        eventTask?.cancel()
        eventTask = Task { await eventLoop() }
        pollTask?.cancel()
        pollTask = Task { await pollLoop() }
    }

    func disconnect() {
        eventTask?.cancel()
        eventTask = nil
        debounceTask?.cancel()
        debounceTask = nil
        pollTask?.cancel()
        pollTask = nil
    }

    func handleSceneActive() {
        Task { await fetchState() }
    }

    private func connectionDidChange() {
        disconnect()
        state = nil
        if connection != nil {
            connect()
        } else {
            status = .idle
        }
    }

    private func eventLoop() async {
        var backoff: UInt64 = 1

        while !Task.isCancelled {
            guard let connection else { return }

            await fetchState()

            guard var components = URLComponents(url: connection.url.appending(path: "/api/events"), resolvingAgainstBaseURL: false) else { return }
            components.scheme = connection.url.scheme == "https" ? "wss" : "ws"
            components.queryItems = [URLQueryItem(name: "token", value: connection.token)]

            guard let wsURL = components.url else { return }

            let socket = session.webSocketTask(with: wsURL)
            socket.resume()

            backoff = 1

            while !Task.isCancelled {
                do {
                    let message = try await socket.receive()
                    if case .string("changed") = message {
                        scheduleDebouncedFetch()
                    }
                } catch {
                    break
                }
            }

            socket.cancel(with: .goingAway, reason: nil)

            guard !Task.isCancelled else { return }

            try? await Task.sleep(for: .seconds(backoff))
            backoff = min(backoff * 2, 10)
        }
    }

    private func pollLoop() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(30))
            guard !Task.isCancelled else { return }
            await fetchState()
        }
    }

    private func scheduleDebouncedFetch() {
        debounceTask?.cancel()
        debounceTask = Task {
            try? await Task.sleep(for: .milliseconds(200))
            guard !Task.isCancelled else { return }
            await fetchState()
        }
    }
}
