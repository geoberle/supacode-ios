import Foundation

@Observable
@MainActor
final class TerminalSessionPool {
    private var sessions: [String: TerminalSession] = [:]
    private var connection: Connection?

    func setConnection(_ connection: Connection?) {
        guard connection?.url != self.connection?.url || connection?.token != self.connection?.token else { return }
        stopAll()
        self.connection = connection
    }

    func session(for surfaceID: String) -> TerminalSession? {
        guard let connection else { return nil }

        if let existing = sessions[surfaceID] {
            if case .disconnected = existing.connectionStatus {
                existing.stop()
                sessions.removeValue(forKey: surfaceID)
            } else {
                return existing
            }
        }

        let session = TerminalSession(connection: connection, surfaceID: surfaceID)
        sessions[surfaceID] = session
        session.start()
        return session
    }

    func evictStaleSurfaces(activeSurfaceIDs: Set<String>) {
        for (surfaceID, session) in sessions where !activeSurfaceIDs.contains(surfaceID) {
            session.stop()
            sessions.removeValue(forKey: surfaceID)
        }
    }

    func stopAll() {
        for session in sessions.values {
            session.stop()
        }
        sessions.removeAll()
    }
}
