import Foundation
import WatchConnectivity

@MainActor
final class WatchModel: NSObject, ObservableObject {
    @Published var snapshot: WatchSnapshot?
    @Published var phoneReachable = false
    @Published var status = "Open Vex Watcher on your iPhone"

    private var started = false
    private let storeKey = "vex.watch.snapshot"

    func activate() {
        guard !started else { return }
        started = true
        if let data = UserDefaults.standard.data(forKey: storeKey),
           let saved = try? SnapshotCoding.decoder().decode(WatchSnapshot.self, from: data) {
            snapshot = saved
            status = "Open Vex Watcher on your iPhone"
        }
        guard WCSession.isSupported() else {
            status = "Open Vex Watcher on your iPhone"
            return
        }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    private func apply(_ context: [String: Any]) {
        guard let data = context["snapshot"] as? Data,
              let snapshot = try? SnapshotCoding.decoder().decode(WatchSnapshot.self, from: data) else {
            if self.snapshot == nil || !phoneReachable {
                status = "Open Vex Watcher on your iPhone"
            }
            return
        }
        self.snapshot = snapshot
        UserDefaults.standard.set(data, forKey: storeKey)
        status = phoneReachable ? "From your iPhone" : "Open Vex Watcher on your iPhone"
    }
}

extension WatchModel: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        let context = session.receivedApplicationContext
        let reachable = session.isReachable
        Task { @MainActor in
            self.phoneReachable = reachable
            self.apply(context)
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        Task { @MainActor in
            self.apply(applicationContext)
        }
    }

    #if os(iOS)
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
    #endif

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        let reachable = session.isReachable
        Task { @MainActor in
            self.phoneReachable = reachable
            if self.snapshot == nil || !reachable {
                self.status = "Open Vex Watcher on your iPhone"
            } else {
                self.status = "From your iPhone"
            }
        }
    }
}
