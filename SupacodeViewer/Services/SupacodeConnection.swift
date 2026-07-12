import Foundation

enum ConnectionStatus: Sendable, Equatable {
    case idle
    case connecting
    case connected
    case error(ConnectionError)
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
    var connection: Connection?
    var status: ConnectionStatus = .idle
    var state: SupacodeState?

    private let session = URLSession.shared

    func fetchState() async {
        guard let connection else {
            status = .idle
            return
        }

        if state == nil {
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
}
