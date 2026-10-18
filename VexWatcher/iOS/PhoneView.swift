import SwiftUI

private enum Route: Hashable {
    case event(Int)
    case team(Int)
}

struct PhoneView: View {
    @ObservedObject var model: PhoneModel
    @State private var path = NavigationPath()
    @StateObject private var scouts = ScoutStore()
    @State private var scoutDraft = ScoutDraft()
    @State private var showToken = false

    var body: some View {
        TabView {
            AwardsView(model: model)
                .tabItem {
                    Label("Awards", systemImage: "rosette")
                }
            ScoutFormView(model: model, store: scouts, draft: $scoutDraft)
                .tabItem {
                    Label("Scout", systemImage: "list.clipboard")
                }
            eventsRoot
                .tabItem {
                    Label("Events", systemImage: "flag.checkered")
                }
            PitFormView(model: model)
                .tabItem {
                    Label("Pit", systemImage: "wrench.and.screwdriver")
                }
            AllianceView(model: model)
                .tabItem {
                    Label("Alliance", systemImage: "person.2")
                }
            StrategyView()
                .tabItem {
                    Label("Strategy", systemImage: "lightbulb")
                }
        }
        .tint(.accentColor)
        .task { await model.bootstrap() }
    }

    private var eventsRoot: some View {
        NavigationStack(path: $path) {
            HomeScreen(model: model)
                .navigationTitle("95070D")
                .navigationDestination(for: Route.self) { route in
                    switch route {
                    case .event(let id):
                        EventScreen(eventID: id, model: model)
                    case .team(let id):
                        if let team = model.team(id: id) {
                            TeamDetail(team: team, note: model.report?.note ?? "")
                        } else {
                            Text("That team is not in the current results.")
                        }
                    }
                }
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Token") { showToken = true }
                    }
                }
                .sheet(isPresented: $showToken) {
                    TokenSheet(model: model)
                }
                .onChange(of: model.pendingEventID) { _, id in
                    guard let id else { return }
                    path.append(Route.event(id))
                    model.pendingEventID = nil
                }
        }
    }
}

private struct HomeScreen: View {
    @ObservedObject var model: PhoneModel
    @State private var teamDraft = ""
    @State private var query = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                teamCard
                if let report = model.report {
                    if let mine = model.myTeam(in: report) {
                        NavigationLink(value: Route.team(mine.id)) {
                            HeroCard(team: mine, eventName: report.eventName)
                        }
                        .buttonStyle(.plain)
                    } else if !model.teamNumber.isEmpty {
                        Text("\(model.teamNumber) is not in \(report.eventName).")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                if let error = model.errorMessage {
                    Text(error)
                        .font(.subheadline)
                        .foregroundStyle(.red)
                }
                eventsCard
            }
            .padding(20)
        }
        .vexScreen()
        .refreshable { await model.reload(keepCurrent: true) }
        .onAppear { teamDraft = model.teamNumber }
        .onChange(of: model.teamNumber) { _, number in
            if teamDraft != number { teamDraft = number }
        }
    }

    private var teamCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(model.season.name.isEmpty ? "Your team" : model.season.name)
                .font(.headline)
            if model.programs.count > 1 {
                Picker("Program", selection: Binding(
                    get: { model.programID },
                    set: { id in Task { await model.selectProgram(id) } }
                )) {
                    ForEach(model.programs) { program in
                        Text(program.name).tag(program.id)
                    }
                }
                .pickerStyle(.menu)
            }
            HStack {
                TextField("Team number", text: $teamDraft)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { Task { await model.saveTeam(teamDraft) } }
                Button("Load") { Task { await model.saveTeam(teamDraft) } }
                    .buttonStyle(.borderedProminent)
                    .disabled(model.loading || normalizedTeamNumber(teamDraft).isEmpty)
            }
            HStack {
                TextField("Or an event code", text: $query)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { Task { await model.lookup(query) } }
                Button("Look up") { Task { await model.lookup(query) } }
                    .disabled(model.loading || query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .vexCard()
    }

    private var eventsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Events")
                .font(.headline)
            if model.orderedEvents.isEmpty {
                Text(model.token.isEmpty
                    ? "Tap Token and paste a free Robot Events API token from events.vex.com/api/v2."
                    : "No events yet. Enter a team number or an event code like RE-V5RC-26-1234.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(model.orderedEvents) { event in
                    NavigationLink(value: Route.event(event.id)) {
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(event.name)
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(.primary)
                                    .multilineTextAlignment(.leading)
                                Text([event.when, event.place].filter { !$0.isEmpty }.joined(separator: " · "))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 8)
                            if event.isLive {
                                Text("LIVE")
                                    .font(.caption2.weight(.bold))
                                    .tracking(0.6)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(VexLook.red, in: Capsule())
                                    .foregroundStyle(.white)
                            }
                        }
                        .padding(.vertical, 6)
                    }
                }
            }
        }
        .vexCard()
    }
}

private struct HeroCard: View {
    var team: TeamReport
    var eventName: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ScorePlate(percent: team.overall, grade: team.grade, caption: "\(team.number) · \(eventName)")
            Text("\(team.placeLabel) · \(team.record)")
                .font(.subheadline.weight(.medium).monospacedDigit())
            VStack(alignment: .leading, spacing: 6) {
                ForEach(team.abilities, id: \.self) { line in
                    HStack(spacing: 8) {
                        Circle()
                            .fill(VexLook.red)
                            .frame(width: 6, height: 6)
                        Text(line)
                            .font(.subheadline)
                    }
                }
            }
        }
    }
}

private struct EventScreen: View {
    var eventID: Int
    @ObservedObject var model: PhoneModel
    @State private var sort: TeamSort = .rank

    var body: some View {
        Group {
            if let report = model.report, report.eventID == eventID {
                List {
                    if report.divisions.count > 1 {
                        Picker("Division", selection: Binding(
                            get: { report.divisionID },
                            set: { id in Task { await model.open(eventID: eventID, divisionID: id) } }
                        )) {
                            ForEach(report.divisions) { division in
                                Text(division.name).tag(division.id)
                            }
                        }
                    }
                    Picker("Sort", selection: $sort) {
                        ForEach(TeamSort.allCases) { item in
                            Text(item.title).tag(item)
                        }
                    }
                    .pickerStyle(.segmented)
                    .listRowSeparator(.hidden)
                    if report.teams.isEmpty {
                        Text(report.note)
                            .foregroundStyle(.secondary)
                    } else {
                        Section {
                            ForEach(sorted(report.teams)) { team in
                                NavigationLink(value: Route.team(team.id)) {
                                    TeamRow(team: team, mine: model.myTeam(in: report)?.id == team.id)
                                }
                            }
                        } footer: {
                            Text(report.note)
                        }
                    }
                }
                .navigationTitle(report.eventName)
            } else if model.loading {
                ProgressView("Loading event")
            } else {
                ContentUnavailableView("No results", systemImage: "flag.checkered", description: Text(model.errorMessage ?? "Pull to try again."))
            }
        }
        .scrollContentBackground(.hidden)
        .vexScreen()
        .refreshable { await model.open(eventID: eventID, divisionID: model.report?.divisionID) }
        .task(id: eventID) {
            await model.open(eventID: eventID)
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(45))
                guard model.report?.eventID == eventID, model.report?.ongoing == true else { continue }
                await model.open(eventID: eventID, quiet: true)
            }
        }
    }

    private func sorted(_ teams: [TeamReport]) -> [TeamReport] {
        switch sort {
        case .rank: return teams.ranked()
        case .percent: return teams.byPercent()
        case .skills: return teams.bySkills()
        }
    }
}

private enum TeamSort: String, CaseIterable, Identifiable {
    case rank, percent, skills
    var id: String { rawValue }
    var title: String {
        switch self {
        case .rank: return "Rank"
        case .percent: return "Percent"
        case .skills: return "Skills"
        }
    }
}

private struct TeamRow: View {
    var team: TeamReport
    var mine: Bool

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 3) {
                Text(team.number)
                    .font(.body.weight(.semibold))
                HStack(spacing: 6) {
                    Text("\(team.placeLabel) · \(team.record)")
                    GradePill(grade: team.grade)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                if let line = team.abilities.first {
                    Text(line)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            Text("\(team.overall)%")
                .font(.title3.weight(.bold).monospacedDigit())
                .foregroundStyle(team.tint)
        }
        .listRowBackground(mine ? Color.accentColor.opacity(0.12) : nil)
    }
}

struct TeamDetail: View {
    var team: TeamReport
    var note: String

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ScorePlate(percent: team.overall, grade: team.grade, caption: team.placeLabel)
                Text(team.name)
                    .font(.headline)
                if !team.organization.isEmpty {
                    Text(team.organization)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(team.abilities, id: \.self) { line in
                        Label(line, systemImage: "checkmark.circle.fill")
                            .font(.body)
                            .foregroundStyle(.primary)
                    }
                }
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(team.components) { component in
                        PercentBar(name: component.name, percent: component.percent)
                    }
                }
                .vexCard()

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    stat("Record", team.record)
                    stat("WP", "\(team.wp)")
                    stat("AP", "\(team.ap)")
                    stat("SP", "\(team.sp)")
                    stat("Average", "\(Int(team.averagePoints.rounded()))")
                    stat("High", "\(team.highScore)")
                    stat("Driver", skillText(team.driver, rank: team.driverRank))
                    stat("Autonomous", skillText(team.programming, rank: team.programmingRank))
                }
                if let opr = team.opr {
                    Text("Adds about \(Int(opr.rounded())) points to an alliance.")
                        .font(.subheadline)
                }
                if !team.recent.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Recent matches")
                            .font(.headline)
                        ForEach(team.recent) { match in
                            HStack {
                                Text(match.result)
                                    .font(.caption.weight(.bold))
                                    .frame(width: 22, height: 22)
                                    .background(resultColor(match.result).opacity(0.16), in: Circle())
                                    .foregroundStyle(resultColor(match.result))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("\(match.label)  \(match.scoreline)")
                                        .font(.subheadline.monospacedDigit())
                                    if !match.detail.isEmpty {
                                        Text(match.detail)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                            }
                        }
                    }
                }
                Text(note)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(20)
        }
        .vexScreen()
        .navigationTitle(team.number)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func stat(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.body.weight(.semibold).monospacedDigit())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.background, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func skillText(_ score: Int?, rank: Int?) -> String {
        guard let score else { return "—" }
        if let rank, rank > 0 { return "\(score) · \(rank.ordinal)" }
        return "\(score)"
    }

    private func resultColor(_ result: String) -> Color {
        switch result {
        case "W": return VexLook.green
        case "L": return VexLook.red
        default: return VexLook.amber
        }
    }
}

private struct TokenSheet: View {
    @ObservedObject var model: PhoneModel
    @Environment(\.dismiss) private var dismiss
    @State private var draft = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("RobotEvents token", text: $draft, axis: .vertical)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .lineLimit(3...6)
                } footer: {
                    Text("Get a free token at events.vex.com. Sign in, request access, create a token, and paste it here. It stays on this iPhone.")
                }
                Section {
                    Link("Open VEX Events API", destination: URL(string: "https://events.vex.com/api/v2/accessRequest/create")!)
                }
            }
            .navigationTitle("Token")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            await model.saveToken(draft)
                            dismiss()
                        }
                    }
                    .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear { draft = model.token }
        }
    }
}

