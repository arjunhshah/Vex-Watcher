import SwiftUI

struct ScoutEntry: Identifiable, Equatable {
    var id: UUID
    var created: Date
    var teamNumber: String
    var matchLabel: String
    var alliance: String
    var autonomous: String
    var autonomousWinPoint: Bool
    var driver: Int
    var scoring: Int
    var consistency: Int
    var defense: String
    var result: String
    var penalties: Int
    var notes: String
    var strategy: String
    var pins: Int
    var cups: Int
    var yellowPins: Int = 0
    var toggles: Int = 0
    var midfield: Bool = false

    var percent: Int {
        let autoScore: Double
        switch autonomous {
        case "Yes": autoScore = autonomousWinPoint ? 100 : 85
        case "Partial": autoScore = 50
        default: autoScore = 10
        }
        let driverScore = Double(driver) / 5 * 100
        let scoringScore = Double(scoring) / 5 * 100
        let consistencyScore = Double(consistency) / 5 * 100
        let blended = autoScore * 0.25 + driverScore * 0.30 + scoringScore * 0.30 + consistencyScore * 0.15
        return min(100, max(0, Int(blended.rounded())))
    }

    var grade: String {
        switch percent {
        case 85...: return "Elite"
        case 70..<85: return "Strong"
        case 55..<70: return "Good"
        case 40..<55: return "Average"
        default: return "Developing"
        }
    }

    var summary: String {
        var parts = ["Auto \(autonomous.lowercased())"]
        if autonomousWinPoint { parts.append("AWP") }
        if pins > 0 { parts.append("\(pins) pins") }
        if yellowPins > 0 { parts.append("\(yellowPins) yellow") }
        if cups > 0 { parts.append("\(cups) cups") }
        if toggles > 0 { parts.append("\(toggles) toggles") }
        if midfield { parts.append("midfield") }
        if penalties > 0 { parts.append("\(penalties) penalties") }
        return parts.joined(separator: " · ")
    }

    var objectPoints: Int {
        pins * 5 + yellowPins * 10 + (midfield ? 8 : 0)
    }
}

extension ScoutEntry: Codable {
    enum CodingKeys: String, CodingKey {
        case id, created, teamNumber, matchLabel, alliance, autonomous, autonomousWinPoint
        case driver, scoring, consistency, defense, result, penalties, notes, strategy, pins, cups
        case yellowPins, toggles, midfield
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        created = try container.decode(Date.self, forKey: .created)
        teamNumber = try container.decode(String.self, forKey: .teamNumber)
        matchLabel = try container.decode(String.self, forKey: .matchLabel)
        alliance = try container.decode(String.self, forKey: .alliance)
        autonomous = try container.decode(String.self, forKey: .autonomous)
        autonomousWinPoint = try container.decode(Bool.self, forKey: .autonomousWinPoint)
        driver = try container.decode(Int.self, forKey: .driver)
        scoring = try container.decode(Int.self, forKey: .scoring)
        consistency = try container.decode(Int.self, forKey: .consistency)
        defense = try container.decode(String.self, forKey: .defense)
        result = try container.decode(String.self, forKey: .result)
        penalties = try container.decode(Int.self, forKey: .penalties)
        notes = try container.decode(String.self, forKey: .notes)
        strategy = try container.decodeIfPresent(String.self, forKey: .strategy) ?? ""
        pins = try container.decodeIfPresent(Int.self, forKey: .pins) ?? 0
        cups = try container.decodeIfPresent(Int.self, forKey: .cups) ?? 0
        yellowPins = try container.decodeIfPresent(Int.self, forKey: .yellowPins) ?? 0
        toggles = try container.decodeIfPresent(Int.self, forKey: .toggles) ?? 0
        midfield = try container.decodeIfPresent(Bool.self, forKey: .midfield) ?? false
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(created, forKey: .created)
        try container.encode(teamNumber, forKey: .teamNumber)
        try container.encode(matchLabel, forKey: .matchLabel)
        try container.encode(alliance, forKey: .alliance)
        try container.encode(autonomous, forKey: .autonomous)
        try container.encode(autonomousWinPoint, forKey: .autonomousWinPoint)
        try container.encode(driver, forKey: .driver)
        try container.encode(scoring, forKey: .scoring)
        try container.encode(consistency, forKey: .consistency)
        try container.encode(defense, forKey: .defense)
        try container.encode(result, forKey: .result)
        try container.encode(penalties, forKey: .penalties)
        try container.encode(notes, forKey: .notes)
        try container.encode(strategy, forKey: .strategy)
        try container.encode(pins, forKey: .pins)
        try container.encode(cups, forKey: .cups)
        try container.encode(yellowPins, forKey: .yellowPins)
        try container.encode(toggles, forKey: .toggles)
        try container.encode(midfield, forKey: .midfield)
    }
}

@MainActor
final class ScoutStore: ObservableObject {
    @Published private(set) var entries: [ScoutEntry] = []
    private let key = "vex.scouts"

    init() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let saved = try? JSONDecoder().decode([ScoutEntry].self, from: data) else { return }
        entries = saved
    }

    func save(_ entry: ScoutEntry) {
        if let index = entries.firstIndex(where: { $0.id == entry.id }) {
            entries[index] = entry
        } else {
            entries.insert(entry, at: 0)
        }
        persist()
    }

    func delete(_ offsets: IndexSet) {
        entries.remove(atOffsets: offsets)
        persist()
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}

struct ScoutFormView: View {
    @ObservedObject var model: PhoneModel
    @ObservedObject var store: ScoutStore
    @Binding var draft: ScoutDraft
    @State private var savedNote = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ScorePlate(percent: draft.percent, grade: draft.grade, caption: draft.guessed ? "Guess from this event. Change anything." : "From what you saw in the match")
                        .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                        .listRowBackground(Color.clear)
                }

                Section {
                    TextField("Team number", text: $draft.teamNumber)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                    if let teams = model.report?.teams.ranked(), !teams.isEmpty {
                        Picker("Teams here", selection: Binding(
                            get: { draft.teamNumber },
                            set: { number in
                                guard let team = teams.first(where: { $0.number == number }) else { return }
                                draft.fill(from: team, fieldSize: teams.count)
                                savedNote = "Filled \(team.number). Change anything, then save."
                            }
                        )) {
                            Text("Choose").tag("")
                            ForEach(teams) { team in
                                Text("\(team.number) · \(team.overall)%").tag(team.number)
                            }
                        }
                    }
                    TextField("Match, like Q12", text: $draft.matchLabel)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                    Picker("Alliance", selection: $draft.alliance) {
                        Text("Red").tag("Red")
                        Text("Blue").tag("Blue")
                    }
                    .pickerStyle(.segmented)
                    Picker("Result", selection: $draft.result) {
                        Text("Win").tag("Win")
                        Text("Loss").tag("Loss")
                        Text("Tie").tag("Tie")
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("Match")
                } footer: {
                    Text("Pick a team in Teams here and the form fills in from this event. Change any box before you save.")
                }

                Section("Autonomous") {
                    Picker("Autonomous", selection: $draft.autonomous) {
                        Text("No").tag("No")
                        Text("Partial").tag("Partial")
                        Text("Yes").tag("Yes")
                    }
                    .pickerStyle(.segmented)
                    Toggle("Autonomous win point", isOn: $draft.autonomousWinPoint)
                }

                Section {
                    Stepper("Alliance pins: \(draft.pins)", value: $draft.pins, in: 0...40)
                    Stepper("Yellow pins: \(draft.yellowPins)", value: $draft.yellowPins, in: 0...40)
                    Stepper("Cups: \(draft.cups)", value: $draft.cups, in: 0...40)
                    Stepper("Toggles set: \(draft.toggles)", value: $draft.toggles, in: 0...4)
                    Toggle("Ended in the midfield", isOn: $draft.midfield)
                    Stepper("Penalties: \(draft.penalties)", value: $draft.penalties, in: 0...10)
                    Text("About \(draft.objectPoints) points from pins and midfield.")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(VexLook.red)
                } header: {
                    Text("What they scored")
                } footer: {
                    Text("Alliance pins are 5 points. Yellow pins are 10. A robot in the midfield at the end is 8. Cups show how they stacked.")
                }

                Section("What they can do") {
                    RatingRow(title: "Driver", value: $draft.driver)
                    RatingRow(title: "Scoring", value: $draft.scoring)
                    RatingRow(title: "Consistency", value: $draft.consistency)
                    Picker("Defense", selection: $draft.defense) {
                        Text("None").tag("None")
                        Text("Some").tag("Some")
                        Text("Strong").tag("Strong")
                    }
                }

                Section("Strategy") {
                    TextField("How did they play the match?", text: $draft.strategy, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section("Notes") {
                    TextField("What did the robot do?", text: $draft.notes, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section {
                    Button(draft.editingID == nil ? "Save scout" : "Update scout") {
                        save()
                    }
                    .disabled(normalizedTeamNumber(draft.teamNumber).isEmpty)
                    if !savedNote.isEmpty {
                        Text(savedNote)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Saved") {
                    if store.entries.isEmpty {
                        Text("No scouting forms yet.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(store.entries) { entry in
                            Button {
                                draft = ScoutDraft(entry)
                            } label: {
                                VStack(alignment: .leading, spacing: 3) {
                                    HStack {
                                        Text(entry.teamNumber)
                                            .font(.body.weight(.semibold))
                                        if !entry.matchLabel.isEmpty {
                                            Text(entry.matchLabel)
                                                .foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        Text("\(entry.percent)%")
                                            .font(.headline.monospacedDigit())
                                            .foregroundStyle(VexLook.gradeColor(entry.grade))
                                    }
                                    Text("\(entry.alliance) · \(entry.result) · \(entry.summary)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    if !entry.strategy.isEmpty {
                                        Text(entry.strategy)
                                            .font(.caption)
                                            .lineLimit(2)
                                    }
                                    if !entry.notes.isEmpty {
                                        Text(entry.notes)
                                            .font(.caption)
                                            .lineLimit(2)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                        .onDelete(perform: store.delete)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .vexScreen()
            .navigationTitle("Scout")
        }
    }

    private func save() {
        let number = normalizedTeamNumber(draft.teamNumber)
        guard !number.isEmpty else { return }
        let entry = draft.entry(teamNumber: number)
        store.save(entry)
        savedNote = "Saved \(number)"
        draft = ScoutDraft()
    }
}

struct ScoutDraft {
    var editingID: UUID?
    var created = Date()
    var teamNumber = ""
    var matchLabel = ""
    var alliance = "Red"
    var autonomous = "Partial"
    var autonomousWinPoint = false
    var driver = 3
    var scoring = 3
    var consistency = 3
    var defense = "None"
    var result = "Win"
    var penalties = 0
    var pins = 0
    var cups = 0
    var yellowPins = 0
    var toggles = 0
    var midfield = false
    var notes = ""
    var strategy = ""
    var guessed = false

    init() {}

    init(_ entry: ScoutEntry) {
        editingID = entry.id
        created = entry.created
        teamNumber = entry.teamNumber
        matchLabel = entry.matchLabel
        alliance = entry.alliance
        autonomous = entry.autonomous
        autonomousWinPoint = entry.autonomousWinPoint
        driver = entry.driver
        scoring = entry.scoring
        consistency = entry.consistency
        defense = entry.defense
        result = entry.result
        penalties = entry.penalties
        pins = entry.pins
        cups = entry.cups
        yellowPins = entry.yellowPins
        toggles = entry.toggles
        midfield = entry.midfield
        notes = entry.notes
        strategy = entry.strategy
        guessed = false
    }

    mutating func fill(from team: TeamReport, fieldSize: Int) {
        editingID = nil
        created = Date()
        teamNumber = team.number
        guessed = true
        penalties = 0
        pins = 0
        cups = 0
        yellowPins = 0
        toggles = 0
        midfield = false

        let latest = team.recent.first
        matchLabel = latest?.label ?? ""
        switch latest?.color.lowercased() {
        case "red": alliance = "Red"
        case "blue": alliance = "Blue"
        default: alliance = "Red"
        }
        switch latest?.result {
        case "W": result = "Win"
        case "L": result = "Loss"
        case "T": result = "Tie"
        default:
            if team.wins > team.losses {
                result = "Win"
            } else if team.losses > team.wins {
                result = "Loss"
            } else {
                result = "Tie"
            }
        }

        let auto = team.abilities.first { $0.localizedCaseInsensitiveContains("autonomous") } ?? ""
        if auto.localizedCaseInsensitiveContains("strong") {
            autonomous = "Yes"
            autonomousWinPoint = true
        } else if auto.localizedCaseInsensitiveContains("no autonomous") {
            autonomous = "No"
            autonomousWinPoint = false
        } else if (team.programming ?? 0) > 0 {
            autonomous = "Partial"
            autonomousWinPoint = false
        } else {
            autonomous = "No"
            autonomousWinPoint = false
        }

        if let rank = team.driverRank, (team.driver ?? 0) > 0 {
            driver = stars(from: rankPercent(rank, field: fieldSize))
        } else {
            driver = stars(from: component("Skills", on: team) ?? team.overall)
        }
        scoring = stars(from: component("Scoring", on: team) ?? team.overall)
        let steady = [component("Win rate", on: team), component("Rank", on: team)].compactMap { $0 }
        if steady.isEmpty {
            consistency = stars(from: team.overall)
        } else {
            consistency = stars(from: steady.reduce(0, +) / steady.count)
        }

        let winRate = component("Win rate", on: team) ?? 0
        let scoringRate = component("Scoring", on: team) ?? 100
        if winRate >= 60 && scoringRate < 40 {
            defense = "Strong"
        } else if winRate >= 45 && scoringRate < 45 {
            defense = "Some"
        } else {
            defense = "None"
        }

        strategy = team.abilities.joined(separator: ". ")
        if !strategy.isEmpty, !strategy.hasSuffix(".") {
            strategy += "."
        }

        var bits: [String] = []
        if team.rank > 0 { bits.append("Rank \(team.rank)") }
        if team.wins + team.losses + team.ties > 0 { bits.append(team.record) }
        if let driver = team.driver { bits.append("driver skills \(driver)") }
        if let programming = team.programming { bits.append("autonomous skills \(programming)") }
        if team.averagePoints > 0 {
            bits.append("about \(Int(team.averagePoints.rounded())) points a match")
        }
        if let latest {
            bits.append("\(latest.label) \(latest.result) \(latest.scoreline)")
        }
        notes = bits.joined(separator: " · ")
    }

    private func component(_ name: String, on team: TeamReport) -> Int? {
        team.components.first { $0.name == name }?.percent
    }

    private func rankPercent(_ rank: Int, field: Int) -> Int {
        guard field > 1, rank > 0 else { return 50 }
        return Int((Double(field - rank) / Double(field - 1) * 100).rounded())
    }

    private func stars(from percent: Int) -> Int {
        switch percent {
        case 85...: return 5
        case 70..<85: return 4
        case 50..<70: return 3
        case 30..<50: return 2
        default: return 1
        }
    }

    var percent: Int { entry(teamNumber: normalizedTeamNumber(teamNumber)).percent }

    var objectPoints: Int { entry(teamNumber: normalizedTeamNumber(teamNumber)).objectPoints }

    var grade: String {
        switch percent {
        case 85...: return "Elite"
        case 70..<85: return "Strong"
        case 55..<70: return "Good"
        case 40..<55: return "Average"
        default: return "Developing"
        }
    }

    func entry(teamNumber: String) -> ScoutEntry {
        ScoutEntry(
            id: editingID ?? UUID(),
            created: created,
            teamNumber: teamNumber,
            matchLabel: matchLabel.trimmingCharacters(in: .whitespacesAndNewlines),
            alliance: alliance,
            autonomous: autonomous,
            autonomousWinPoint: autonomousWinPoint,
            driver: driver,
            scoring: scoring,
            consistency: consistency,
            defense: defense,
            result: result,
            penalties: penalties,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
            strategy: strategy.trimmingCharacters(in: .whitespacesAndNewlines),
            pins: pins,
            cups: cups,
            yellowPins: yellowPins,
            toggles: toggles,
            midfield: midfield
        )
    }
}

struct RobotTrackerView: View {
    @ObservedObject var model: PhoneModel
    @ObservedObject var store: ScoutStore
    @Binding var draft: ScoutDraft
    @State private var savedNote = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 10) {
                        TextField("Team number", text: $draft.teamNumber)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                            .textFieldStyle(.roundedBorder)
                        if let teams = model.report?.teams.ranked(), !teams.isEmpty {
                            Picker("Teams here", selection: $draft.teamNumber) {
                                Text("Choose").tag("")
                                ForEach(teams) { team in
                                    Text(team.number).tag(team.number)
                                }
                            }
                            .pickerStyle(.menu)
                        }
                        TextField("Match, like Q12", text: $draft.matchLabel)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                            .textFieldStyle(.roundedBorder)
                    }
                    .vexCard()

                    HStack(spacing: 12) {
                        ScoreCounter(title: "Pins", count: $draft.pins, tint: VexLook.red)
                        ScoreCounter(title: "Cups", count: $draft.cups, tint: VexLook.blue)
                    }

                    if !teamTotals.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(normalizedTeamNumber(draft.teamNumber))
                                .font(.headline)
                            Text(teamTotals)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .vexCard()
                    }

                    Button(draft.editingID == nil ? "Save this match" : "Update this match") {
                        save()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(normalizedTeamNumber(draft.teamNumber).isEmpty)

                    if !savedNote.isEmpty {
                        Text(savedNote)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    Text("Tap + each time the robot scores a pin or a cup. Minus takes one back. The Scout tab uses the same match.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(20)
            }
            .vexScreen()
            .navigationTitle("Tracker")
            .onAppear {
                if draft.teamNumber.isEmpty {
                    draft.teamNumber = normalizedTeamNumber(model.teamNumber)
                }
            }
        }
    }

    private var teamTotals: String {
        let number = normalizedTeamNumber(draft.teamNumber)
        guard !number.isEmpty else { return "" }
        let previous = store.entries.filter {
            normalizedTeamNumber($0.teamNumber) == number && $0.id != draft.editingID
        }
        let matches = previous.count + 1
        let pins = previous.reduce(draft.pins) { $0 + $1.pins }
        let cups = previous.reduce(draft.cups) { $0 + $1.cups }
        return "\(pins) pins and \(cups) cups across \(matches) match\(matches == 1 ? "" : "es"), including this one."
    }

    private func save() {
        let number = normalizedTeamNumber(draft.teamNumber)
        guard !number.isEmpty else { return }
        let entry = draft.entry(teamNumber: number)
        store.save(entry)
        savedNote = "Saved \(number): \(entry.pins) pins, \(entry.cups) cups"
        draft = ScoutDraft()
        draft.teamNumber = number
    }
}

private struct ScoreCounter: View {
    var title: String
    @Binding var count: Int
    var tint: Color

    var body: some View {
        VStack(spacing: 12) {
            Text(title.uppercased())
                .font(.caption.weight(.bold))
                .tracking(1)
                .foregroundStyle(tint)
            Text("\(count)")
                .font(.system(size: 64, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
            HStack(spacing: 10) {
                Button {
                    if count > 0 { count -= 1 }
                } label: {
                    Image(systemName: "minus")
                        .font(.title3.weight(.bold))
                        .frame(maxWidth: .infinity, minHeight: 52)
                }
                .buttonStyle(.bordered)
                .tint(.white)

                Button {
                    count += 1
                } label: {
                    Image(systemName: "plus")
                        .font(.title3.weight(.bold))
                        .frame(maxWidth: .infinity, minHeight: 52)
                }
                .buttonStyle(.borderedProminent)
                .tint(tint)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(VexLook.ink, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(alignment: .top) {
            Capsule()
                .fill(tint)
                .frame(height: 4)
                .padding(.horizontal, 28)
                .offset(y: 10)
        }
    }
}

private struct RatingRow: View {
    var title: String
    @Binding var value: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.semibold))
            HStack(spacing: 8) {
                ForEach(1...5, id: \.self) { mark in
                    Button {
                        value = mark
                    } label: {
                        Text("\(mark)")
                            .font(.body.weight(.bold).monospacedDigit())
                            .frame(maxWidth: .infinity, minHeight: 36)
                            .foregroundStyle(mark <= value ? Color.white : Color.primary)
                            .background(mark <= value ? VexLook.red : Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
