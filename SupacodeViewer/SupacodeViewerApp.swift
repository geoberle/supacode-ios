import SwiftUI

@main
struct SupacodeViewerApp: App {
    @State private var connection = SupacodeConnection()
    @State private var sessionPool = TerminalSessionPool()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(connection)
                .environment(sessionPool)
                .preferredColorScheme(.dark)
                .task {
                    if let saved = ConnectionStore.load() {
                        connection.connection = saved
                    }
                }
                .onChange(of: connection.connection) {
                    sessionPool.setConnection(connection.connection)
                }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                connection.handleSceneActive()
                sessionPool.reconnectAll()
            }
        }
    }
}
