import SwiftUI

@main
struct VexWatcherWatchApp: App {
    @StateObject private var model = WatchModel()

    var body: some Scene {
        WindowGroup {
            WatchRoot(model: model)
                .onAppear { model.activate() }
        }
    }
}
