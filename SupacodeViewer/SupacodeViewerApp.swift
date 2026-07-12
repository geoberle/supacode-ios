import SwiftUI

@main
struct SupacodeViewerApp: App {
    @State private var connection = SupacodeConnection()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(connection)
                .preferredColorScheme(.dark)
                .task {
                    if let saved = ConnectionStore.load() {
                        connection.connection = saved
                    }
                }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                connection.handleSceneActive()
            }
        }
    }
}
