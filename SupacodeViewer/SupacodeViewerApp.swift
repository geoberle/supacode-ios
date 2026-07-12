import SwiftUI

@main
struct SupacodeViewerApp: App {
    @State private var connection = SupacodeConnection()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(connection)
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                connection.handleSceneActive()
            }
        }
    }
}
