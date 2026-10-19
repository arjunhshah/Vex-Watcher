import Foundation
import UserNotifications

struct CompNotice: Equatable {
    var title: String
    var detail: String
}

enum CompReminder {
    private static let lead: TimeInterval = 3 * 60

    static func notice(events: [EventSummary], team: String, now: Date = Date()) -> CompNotice? {
        guard let event = soonest(in: events, now: now), let kick = kickoff(for: event) else { return nil }
        let remaining = kick.date.timeIntervalSince(now)
        guard remaining <= lead, remaining > -60 else { return nil }
        let number = team.isEmpty ? "Your team" : team
        let minutes = max(0, Int((remaining / 60).rounded(.up)))
        let title: String
        if minutes <= 0 {
            title = "\(number) is starting"
        } else if minutes == 1 {
            title = "\(number) starts in 1 minute"
        } else {
            title = "\(number) starts in \(minutes) minutes"
        }
        var detail = event.name
        if !kick.clockWasListed {
            detail += ". No start time was listed, so this is 3 minutes before 8:00 AM."
        }
        return CompNotice(title: title, detail: detail)
    }

    static func upcomingLine(events: [EventSummary], now: Date = Date()) -> String? {
        guard let event = soonest(in: events, now: now), let kick = kickoff(for: event) else { return nil }
        let when = kick.date.formatted(date: .abbreviated, time: .shortened)
        if kick.clockWasListed {
            return "Next comp is \(event.name) at \(when). You’ll get a notice 3 minutes before."
        }
        return "Next comp is \(event.name) on \(when). No start time was listed, so the notice is 3 minutes before 8:00 AM."
    }

    static func schedule(events: [EventSummary], team: String) async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        if settings.authorizationStatus == .notDetermined {
            _ = try? await center.requestAuthorization(options: [.alert, .sound])
        }
        let allowed = await center.notificationSettings().authorizationStatus
        let pending = await center.pendingNotificationRequests()
        center.removePendingNotificationRequests(withIdentifiers: pending.map(\.identifier).filter { $0.hasPrefix("vex.comp.") })
        guard allowed == .authorized || allowed == .provisional || allowed == .ephemeral else { return }

        let now = Date()
        let number = team.isEmpty ? "Your team" : team
        let upcoming = events.compactMap { event -> (EventSummary, Date, Bool)? in
            guard let kick = kickoff(for: event) else { return nil }
            return (event, kick.date, kick.clockWasListed)
        }
        .filter { $0.1.timeIntervalSince(now) > -60 }
        .sorted { $0.1 < $1.1 }
        .prefix(24)

        for (event, start, listed) in upcoming {
            let fire = start.addingTimeInterval(-lead)
            guard fire.timeIntervalSince(now) > 1 else { continue }
            let content = UNMutableNotificationContent()
            content.title = "\(number) starts in 3 minutes"
            content.body = listed
                ? event.name
                : "\(event.name). No start time was listed, so this is 3 minutes before 8:00 AM."
            content.sound = .default
            let parts = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: fire)
            let trigger = UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)
            try? await center.add(UNNotificationRequest(identifier: "vex.comp.\(event.id)", content: content, trigger: trigger))
        }
    }

    private static func soonest(in events: [EventSummary], now: Date) -> EventSummary? {
        events
            .compactMap { event -> (EventSummary, Date)? in
                guard let kick = kickoff(for: event) else { return nil }
                guard kick.date.timeIntervalSince(now) > -60 else { return nil }
                return (event, kick.date)
            }
            .min { $0.1 < $1.1 }?
            .0
    }

    private static func kickoff(for event: EventSummary) -> (date: Date, clockWasListed: Bool)? {
        guard let start = event.start else { return nil }
        if isDateOnly(start) {
            guard let morning = morningStart(on: start) else { return nil }
            return (morning, false)
        }
        return (start, true)
    }

    private static func isDateOnly(_ date: Date) -> Bool {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        let parts = calendar.dateComponents([.hour, .minute, .second], from: date)
        return parts.hour == 0 && parts.minute == 0 && parts.second == 0
    }

    /// RobotEvents often sends only the competition day. Use 8:00 AM local on that day.
    private static func morningStart(on date: Date) -> Date? {
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        let day = utc.dateComponents([.year, .month, .day], from: date)
        var local = DateComponents()
        local.year = day.year
        local.month = day.month
        local.day = day.day
        local.hour = 8
        local.minute = 0
        return Calendar.current.date(from: local)
    }
}

final class CompNotificationBridge: NSObject, UNUserNotificationCenterDelegate {
    static let shared = CompNotificationBridge()

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}
