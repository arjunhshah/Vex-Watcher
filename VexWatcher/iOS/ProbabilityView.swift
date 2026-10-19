import SwiftUI

struct ProbabilityView: View {
    @ObservedObject var model: PhoneModel
    @State private var choice = ""
    @State private var lockedNumber = ""

    private var eventID: Int? { model.report?.eventID }

    private var partners: [TeamReport] {
        guard let report = model.report, let home = model.myTeam(in: report) else { return [] }
        return report.teams
            .filter { $0.id != home.id }
            .ranked()
    }

    private var lockedPartner: TeamReport? {
        let wanted = normalizedTeamNumber(lockedNumber)
        guard !wanted.isEmpty else { return nil }
        return partners.first { normalizedTeamNumber($0.number) == wanted }
    }

    private var forecast: QualificationForecast? {
        guard let report = model.report, let home = model.myTeam(in: report) else { return nil }
        return AwardEligibility.forecast(report: report, home: home, partner: lockedPartner)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    Button {
                        Task { await model.reload(keepCurrent: true) }
                    } label: {
                        Label(model.loading ? "Refreshing…" : "Refresh", systemImage: "arrow.clockwise")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(model.loading)
                    if let error = model.errorMessage {
                        Text(error)
                            .font(.subheadline)
                            .foregroundStyle(.red)
                    }
                    lockBox
                    if let forecast {
                        levelCard(forecast.states)
                        levelCard(forecast.worlds)
                        Text("These percents are estimates from this event’s rankings. Judges still pick several awards, and the event page decides how far the qualifying list goes.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else if model.report == nil {
                        Text("Load 95070D’s event on the Events tab. The percents fill in from that field.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("95070D is not in the loaded event.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(20)
            }
            .vexScreen()
            .refreshable { await model.reload(keepCurrent: true) }
            .navigationTitle("Probability")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { restoreLock() }
            .onChange(of: eventID) { _, _ in restoreLock() }
        }
    }

    private var header: some View {
        VStack(spacing: 6) {
            Text("Next level")
                .font(.system(size: 34, weight: .bold, design: .rounded))
            Text(model.report?.eventName ?? "States and Worlds")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            if let report = model.report, report.ongoing || report.bracket.contains(where: { !$0.scored }) {
                Text("Live from VEX Events · \(report.updated.formatted(date: .omitted, time: .shortened))")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(VexLook.red)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
    }

    private var lockBox: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Alliance partner", systemImage: lockedPartner == nil ? "lock.open" : "lock.fill")
                    .font(.headline)
                Spacer()
                if lockedPartner != nil {
                    Text("Locked")
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(VexLook.green, in: Capsule())
                        .foregroundStyle(.white)
                }
            }
            if partners.isEmpty {
                Text("Load an event to pick a partner. Each event keeps its own lock.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Picker("Partner", selection: $choice) {
                    Text("None").tag("")
                    ForEach(partners) { team in
                        Text("\(team.number) · \(team.overall)%").tag(team.number)
                    }
                }
                if let partner = lockedPartner {
                    Text("\(partner.number) is locked for this event\(model.report?.eventName.isEmpty == false ? ": \(model.report!.eventName)" : ""). The next competition starts empty.")
                        .font(.subheadline)
                    Button("Unlock") { clearLock() }
                        .buttonStyle(.bordered)
                } else {
                    Text("Lock a partner for this competition. A different event uses a different partner.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Button("Lock in") { saveLock() }
                        .buttonStyle(.borderedProminent)
                        .disabled(normalizedTeamNumber(choice).isEmpty)
                }
            }
        }
        .vexCard()
    }

    private func levelCard(_ level: LevelOdds) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(level.name)
                    .font(.headline)
                Spacer()
                Text("\(level.chance)%")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(chanceColor(level.chance))
            }
            Text(level.detail)
                .font(.subheadline)
            ForEach(level.paths) { path in
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(path.name)
                        Spacer()
                        Text("\(path.chance)%")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    .font(.subheadline.weight(.semibold))
                    Text(path.detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .vexCard()
    }

    private func chanceColor(_ chance: Int) -> Color {
        if chance >= 40 { return VexLook.green }
        if chance >= 15 { return VexLook.amber }
        return VexLook.red
    }

    private func restoreLock() {
        guard let eventID else {
            lockedNumber = ""
            choice = ""
            return
        }
        let saved = locks["\(eventID)"] ?? ""
        lockedNumber = saved
        choice = saved
    }

    private func saveLock() {
        guard let eventID else { return }
        let number = normalizedTeamNumber(choice)
        guard !number.isEmpty else { return }
        var next = locks
        next["\(eventID)"] = number
        UserDefaults.standard.set(next, forKey: lockKey)
        lockedNumber = number
    }

    private func clearLock() {
        guard let eventID else { return }
        var next = locks
        next["\(eventID)"] = nil
        UserDefaults.standard.set(next, forKey: lockKey)
        lockedNumber = ""
        choice = ""
    }

    private var locks: [String: String] {
        UserDefaults.standard.dictionary(forKey: lockKey) as? [String: String] ?? [:]
    }

    private var lockKey: String { "vex.allianceLocks" }
}
