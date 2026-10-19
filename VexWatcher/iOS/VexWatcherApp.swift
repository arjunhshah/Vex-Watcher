import SwiftUI
import UserNotifications

@main
struct VexWatcherApp: App {
    @StateObject private var model = PhoneModel()

    init() {
        UNUserNotificationCenter.current().delegate = CompNotificationBridge.shared
    }

    var body: some Scene {
        WindowGroup {
            PhoneView(model: model)
        }
    }
}
