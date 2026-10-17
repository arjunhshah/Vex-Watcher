import SwiftUI

@main
struct VexWatcherApp: App {
    @StateObject private var model = PhoneModel()

    var body: some Scene {
        WindowGroup {
            PhoneView(model: model)
        }
    }
}
