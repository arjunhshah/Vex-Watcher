import SwiftUI

private enum Route: Hashable {
    case event(Int)
    case team(Int)
}

struct PhoneView: View {
    @ObservedObject var model: PhoneModel
    @State private var path = NavigationPath()
    @State private var showToken = false

    var body: some View {
        NavigationStack(path: $path) {
            HomeScreen(model: model)
                .navigationTitle("Vex Watcher")
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
        .tint(.accentColor)
        .task { await model.bootstrap() }
    }
}

private struct HomeScreen: View {
    @ObservedObject var model: PhoneModel
    @State private var teamDraft = ""
    @State private var query = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                watchCard
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
                Text("Your iPhone downloads the event and sends the ratings straight to your paired watch. Percents compare teams at the same event.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(20)
        }
        .background(Color(.systemGroupedBackground))
        .refreshable { await model.reload(keepCurrent: true) }
        .onAppear { teamDraft = model.teamNumber }
        .onChange(of: model.teamNumber) { _, number in
            if teamDraft != number { teamDraft = number }
        }
    }

    private var watchCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "applewatch")
                .font(.title2)
                .foregroundStyle(Color.accentColor)
                .frame(width: 44, height: 44)
                .background(Color.accentColor.opacity(0.12), in: Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text(model.watchStatus)
                    .font(.headline)
                Text(model.loading ? "Refreshing…" : model.status)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
            if model.loading { ProgressView() }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
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
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var eventsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Events")
                .font(.headline)
            if model.orderedEvents.isEmpty {
                Text(model.token.isEmpty ? "Add your token first." : "No events yet. Enter a team number or an event code like RE-V5RC-26-1234.")
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
                                Text("Live")
                                    .font(.caption.weight(.semibold))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.accentColor.opacity(0.14), in: Capsule())
                                    .foregroundStyle(Color.accentColor)
                            }
                        }
                        .padding(.vertical, 6)
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

private struct HeroCard: View {
    var team: TeamReport
    var eventName: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("\(team.overall)%")
                    .font(.system(size: 52, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(team.tint)
                VStack(alignment: .leading, spacing: 2) {
                    Text(team.grade)
                        .font(.headline)
                    Text(team.number)
                        .font(.subheadline.weight(.semibold))
                }
                Spacer()
            }
            Text(eventName)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("\(team.placeLabel) · \(team.record)")
                .font(.subheadline.monospacedDigit())
            VStack(alignment: .leading, spacing: 4) {
                ForEach(team.abilities, id: \.self) { line in
                    Text(line)
                        .font(.subheadline)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
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
                Text("\(team.placeLabel) · \(team.record) · \(team.grade)")
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
                HStack(alignment: .firstTextBaseline) {
                    Text("\(team.overall)%")
                        .font(.system(size: 64, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(team.tint)
                    VStack(alignment: .leading) {
                        Text(team.grade)
                            .font(.title3.weight(.semibold))
                        Text(team.placeLabel)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
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
                .padding(16)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))

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
        .background(Color(.systemGroupedBackground))
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
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func skillText(_ score: Int?, rank: Int?) -> String {
        guard let score else { return "—" }
        if let rank, rank > 0 { return "\(score) · \(rank.ordinal)" }
        return "\(score)"
    }

    private func resultColor(_ result: String) -> Color {
        switch result {
        case "W": return Color(red: 0, green: 0.52, blue: 0.32)
        case "L": return Color(red: 0.78, green: 0.09, blue: 0.18)
        default: return .orange
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
                    Text("Get a free token at robotevents.com/api/v2. It stays on this iPhone. The watch only receives the ratings.")
                }
                Section {
                    Link("Open RobotEvents API", destination: URL(string: "https://www.robotevents.com/api/v2")!)
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
