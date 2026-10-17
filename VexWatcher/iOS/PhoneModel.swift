import Foundation
import WatchConnectivity

@MainActor
final class PhoneModel: NSObject, ObservableObject {
    @Published var token = ""
    @Published var teamNumber = ""
    @Published var programID = 1
    @Published var programs: [ProgramChoice] = []
    @Published var season = SeasonInfo(id: 0, name: "")
    @Published var events: [EventSummary] = []
    @Published var report: EventReport?
    @Published var status = "Add a RobotEvents token to start."
    @Published var errorMessage: String?
    @Published var loading = false
    @Published var watchStatus = "Pair your Apple Watch"
    @Published var pendingEventID: Int?

    private var started = false
    private var generation = 0
    private var pinnedEventID: Int?
    private let defaults = UserDefaults.standard

    func bootstrap() async {
        guard !started else { return }
        started = true
        loadCache()
        activateWatch()
        guard !cleanedToken.isEmpty else { return }
        await reload(keepCurrent: report != nil)
    }

    func saveToken(_ raw: String) async {
        token = cleaned(raw)
        defaults.set(token, forKey: Keys.token)
        errorMessage = nil
        await reload(keepCurrent: false)
    }

    func saveTeam(_ raw: String) async {
        teamNumber = normalizedTeamNumber(raw)
        defaults.set(teamNumber, forKey: Keys.team)
        pinnedEventID = nil
        await reload(keepCurrent: false)
    }

    func selectProgram(_ id: Int) async {
        guard id != programID else { return }
        programID = id
        defaults.set(id, forKey: Keys.program)
        pinnedEventID = nil
        report = nil
        events = []
        await reload(keepCurrent: false)
    }

    func lookup(_ text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if trimmed.contains("-") || trimmed.uppercased().hasPrefix("RE") {
            await loadSKU(trimmed)
        } else {
            await saveTeam(trimmed)
        }
    }

    func open(eventID: Int, divisionID: Int? = nil, quiet: Bool = false) async {
        guard let event = events.first(where: { $0.id == eventID }) ?? (report?.eventID == eventID ? event(from: report!) : nil) else {
            errorMessage = "That event is not loaded."
            return
        }
        if !events.contains(where: { $0.id == event.id }) {
            events.insert(event, at: 0)
        }
        generation += 1
        let ticket = generation
        pinnedEventID = eventID
        let division = divisionID ?? (report?.eventID == eventID ? report?.divisionID : nil)
        await loadReport(for: event, divisionID: division, ticket: ticket, quiet: quiet)
    }

    func reload(keepCurrent: Bool) async {
        generation += 1
        let ticket = generation
        loading = true
        defer { if ticket == generation { loading = false } }
        do {
            let api = try client()
            status = "Loading programs…"
            let listed = try await api.programs()
            if ticket != generation { return }
            if !listed.isEmpty {
                programs = listed
                if !listed.contains(where: { $0.id == programID }) {
                    programID = preferredProgramID(in: listed) ?? listed[0].id
                    defaults.set(programID, forKey: Keys.program)
                }
            }
            status = "Loading the season…"
            let current = try await api.currentSeason(programID: programID)
            if ticket != generation { return }
            season = current
            defaults.set(try SnapshotCoding.encoder().encode(current), forKey: Keys.season)

            let number = normalizedTeamNumber(teamNumber)
            if !number.isEmpty {
                status = "Finding \(number)…"
                guard let team = try await api.findTeam(number: number, programID: programID) else {
                    events = []
                    report = nil
                    errorMessage = "No team \(number) in \(programName)."
                    status = "Check the team number."
                    pushWatch()
                    return
                }
                status = "Loading events…"
                events = try await api.events(teamID: team.id, seasonID: current.id)
                cacheEvents()
            }
            if ticket != generation { return }

            let target: EventSummary?
            if keepCurrent, let pinnedEventID, let existing = events.first(where: { $0.id == pinnedEventID }) {
                target = existing
            } else if keepCurrent, let currentReport = report, let existing = events.first(where: { $0.id == currentReport.eventID }) {
                target = existing
            } else {
                target = featuredEvent()
            }
            guard let target else {
                status = number.isEmpty ? "Enter a team number or an event code." : "No events for \(number) this season."
                errorMessage = nil
                pushWatch()
                return
            }
            await loadReport(for: target, divisionID: report?.eventID == target.id ? report?.divisionID : nil, ticket: ticket)
        } catch {
            if ticket != generation { return }
            errorMessage = error.localizedDescription
            status = "Couldn't refresh."
        }
    }

    private func loadSKU(_ sku: String) async {
        generation += 1
        let ticket = generation
        loading = true
        defer { if ticket == generation { loading = false } }
        do {
            let api = try client()
            if programs.isEmpty {
                programs = try await api.programs()
            }
            if season.id == 0 {
                season = try await api.currentSeason(programID: programID)
            }
            status = "Looking up \(sku.uppercased())…"
            guard let event = try await api.event(sku: sku) else {
                errorMessage = "No event matches \(sku.uppercased())."
                return
            }
            if ticket != generation { return }
            if !events.contains(where: { $0.id == event.id }) {
                events.insert(event, at: 0)
            }
            pendingEventID = event.id
            await loadReport(for: event, divisionID: nil, ticket: ticket)
        } catch {
            if ticket != generation { return }
            errorMessage = error.localizedDescription
            status = "Couldn't open that event."
        }
    }

    private func loadReport(for event: EventSummary, divisionID: Int?, ticket: Int? = nil, quiet: Bool = false) async {
        let active = ticket ?? generation
        if !quiet { loading = true }
        defer { if !quiet, active == generation { loading = false } }
        do {
            let api = try client()
            status = "Loading \(event.name)…"
            let next = try await api.report(event: event, divisionID: divisionID)
            if active != generation { return }
            report = next
            cacheReport(next)
            errorMessage = nil
            status = "Updated \(next.updated.formatted(date: .omitted, time: .shortened))"
            pushWatch()
        } catch {
            if active != generation { return }
            errorMessage = error.localizedDescription
            status = "Couldn't load \(event.name)."
        }
    }

    func team(id: Int) -> TeamReport? {
        report?.teams.first { $0.id == id }
    }

    func myTeam(in report: EventReport) -> TeamReport? {
        let wanted = normalizedTeamNumber(teamNumber)
        guard !wanted.isEmpty else { return nil }
        return report.teams.first { normalizedTeamNumber($0.number) == wanted }
    }

    var orderedEvents: [EventSummary] {
        let now = Date()
        return events.sorted { a, b in
            if a.isLive != b.isLive { return a.isLive && !b.isLive }
            let aFuture = (a.start ?? .distantPast) >= now
            let bFuture = (b.start ?? .distantPast) >= now
            if aFuture != bFuture { return aFuture && !bFuture }
            if aFuture { return (a.start ?? .distantFuture) < (b.start ?? .distantFuture) }
            return (a.start ?? .distantPast) > (b.start ?? .distantPast)
        }
    }

    var programName: String {
        programs.first { $0.id == programID }?.name ?? "VEX"
    }

    private var cleanedToken: String { cleaned(token) }

    private func cleaned(_ raw: String) -> String {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.lowercased().hasPrefix("bearer ") {
            text = String(text.dropFirst(7)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return text
    }

    private func client() throws -> RobotEventsAPI {
        let value = cleanedToken
        guard !value.isEmpty else { throw APIError.missingToken }
        return RobotEventsAPI(token: value)
    }

    private func featuredEvent() -> EventSummary? {
        if let live = orderedEvents.first(where: \.isLive) { return live }
        return orderedEvents.first
    }

    private func event(from report: EventReport) -> EventSummary {
        EventSummary(
            id: report.eventID,
            sku: report.sku,
            name: report.eventName,
            start: nil,
            end: nil,
            city: "",
            region: "",
            ongoing: report.ongoing,
            divisions: report.divisions
        )
    }

    private func loadCache() {
        token = defaults.string(forKey: Keys.token) ?? ""
        teamNumber = defaults.string(forKey: Keys.team) ?? ""
        if defaults.object(forKey: Keys.program) != nil {
            programID = defaults.integer(forKey: Keys.program)
        }
        if let data = defaults.data(forKey: Keys.season),
           let saved = try? SnapshotCoding.decoder().decode(SeasonInfo.self, from: data) {
            season = saved
        }
        if let data = defaults.data(forKey: Keys.events),
           let saved = try? SnapshotCoding.decoder().decode([EventSummary].self, from: data) {
            events = saved
        }
        if let data = defaults.data(forKey: Keys.report),
           let saved = try? SnapshotCoding.decoder().decode(EventReport.self, from: data) {
            report = saved
            status = "Updated \(saved.updated.formatted(date: .omitted, time: .shortened))"
        }
    }

    private func cacheEvents() {
        if let data = try? SnapshotCoding.encoder().encode(events) {
            defaults.set(data, forKey: Keys.events)
        }
    }

    private func cacheReport(_ report: EventReport) {
        if let data = try? SnapshotCoding.encoder().encode(report) {
            defaults.set(data, forKey: Keys.report)
        }
    }

    private func activateWatch() {
        guard WCSession.isSupported() else {
            watchStatus = "This iPhone can't connect to a watch"
            return
        }
        let session = WCSession.default
        session.delegate = self
        session.activate()
        refreshWatchStatus()
    }

    private func pushWatch() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated, let report else {
            refreshWatchStatus()
            return
        }
        var payloadTeams = report.teams
        if !fits(report: report, teams: payloadTeams) {
            let mine = normalizedTeamNumber(teamNumber)
            payloadTeams = report.teams.map { team in
                var copy = team
                if normalizedTeamNumber(team.number) != mine { copy.recent = [] }
                return copy
            }
        }
        if !fits(report: report, teams: payloadTeams) {
            payloadTeams = payloadTeams.map { team in
                var copy = team
                copy.recent = []
                return copy
            }
        }
        let snapshot = WatchSnapshot(
            updated: report.updated,
            seasonName: season.name,
            eventName: report.eventName,
            divisionName: report.divisionName,
            note: report.note,
            myNumber: teamNumber,
            teams: payloadTeams
        )
        guard let data = try? SnapshotCoding.encoder().encode(snapshot) else { return }
        do {
            try session.updateApplicationContext(["snapshot": data])
            refreshWatchStatus()
        } catch {
            watchStatus = "Couldn't send results to your watch"
        }
    }

    private func fits(report: EventReport, teams: [TeamReport]) -> Bool {
        let snapshot = WatchSnapshot(
            updated: report.updated,
            seasonName: season.name,
            eventName: report.eventName,
            divisionName: report.divisionName,
            note: report.note,
            myNumber: teamNumber,
            teams: teams
        )
        guard let data = try? SnapshotCoding.encoder().encode(snapshot) else { return false }
        return data.count < 50_000
    }

    private func refreshWatchStatus() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated else {
            watchStatus = "Connecting to your watch…"
            return
        }
        if !session.isPaired {
            watchStatus = "Pair an Apple Watch in the Watch app"
        } else if !session.isWatchAppInstalled {
            watchStatus = "Watch app installs when your watch is nearby"
        } else if session.isReachable {
            watchStatus = "Connected to your watch"
        } else {
            watchStatus = "Watch will update when it's in range"
        }
    }
}

private enum Keys {
    static let token = "vex.token"
    static let team = "vex.team"
    static let program = "vex.program"
    static let season = "vex.season"
    static let events = "vex.events"
    static let report = "vex.report"
}

extension PhoneModel: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        Task { @MainActor in
            self.refreshWatchStatus()
            self.pushWatch()
        }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            self.refreshWatchStatus()
            if session.isReachable {
                self.pushWatch()
            }
        }
    }
}
