import SwiftUI

struct PitReport: Identifiable, Equatable, Codable {
    var id: UUID
    var savedAt: Date
    var teamNumber: String
    var drivetrain: String
    var scoresPins: Bool
    var scoresCups: Bool
    var pinCapacity: Int
    var cupCapacity: Int
    var autoPins: Bool
    var autoCups: Bool
    var autonomous: String
    var endgame: String
    var defense: String
    var notes: String

    var percent: Int {
        var score = 0
        if scoresPins { score += 20 }
        if scoresCups { score += 20 }
        switch autonomous {
        case "Match-ready": score += 25
        case "Practice": score += 12
        default: break
        }
        switch endgame {
        case "Consistent": score += 20
        case "Partial": score += 10
        default: break
        }
        if pinCapacity > 0 { score += 8 }
        if cupCapacity > 0 { score += 7 }
        return min(100, score)
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
        var parts: [String] = []
        parts.append(scoresPins ? "Scores pins" : "No pins")
        parts.append(scoresCups ? "Scores cups" : "No cups")
        parts.append("Holds \(pinCapacity) pins, \(cupCapacity) cups")
        parts.append(drivetrain)
        parts.append(autonomous == "None" ? "No auto" : autonomous)
        return parts.joined(separator: " · ")
    }
}

@MainActor
final class PitStore: ObservableObject {
    @Published private(set) var reports: [PitReport] = []
    private let key = "vex.pit.reports"

    init() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let saved = try? JSONDecoder().decode([PitReport].self, from: data) else { return }
        reports = saved
    }

    func save(_ report: PitReport) {
        if let index = reports.firstIndex(where: { $0.id == report.id }) {
            reports[index] = report
        } else {
            reports.insert(report, at: 0)
        }
        persist()
    }

    func delete(at offsets: IndexSet) {
        reports.remove(atOffsets: offsets)
        persist()
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(reports) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}

struct PitFormView: View {
    @ObservedObject var model: PhoneModel
    @StateObject private var store = PitStore()
    @State private var draft = PitDraft()
    @State private var savedNote = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ScorePlate(percent: draft.percent, grade: draft.grade, caption: "From the pit, before it runs")
                        .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                        .listRowBackground(Color.clear)
                }

                Section("Robot") {
                    TextField("Team number", text: $draft.teamNumber)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                    if let teams = model.report?.teams.ranked(), !teams.isEmpty {
                        Picker("Teams here", selection: $draft.teamNumber) {
                            Text("Choose").tag("")
                            ForEach(teams) { team in
                                Text(team.number).tag(team.number)
                            }
                        }
                    }
                    Picker("Drivetrain", selection: $draft.drivetrain) {
                        Text("Tank").tag("Tank")
                        Text("Mecanum").tag("Mecanum")
                        Text("Omni").tag("Omni")
                        Text("Swerve").tag("Swerve")
                        Text("Other").tag("Other")
                    }
                }

                Section("Pins and cups") {
                    Toggle("Can score pins", isOn: $draft.scoresPins)
                    Toggle("Can score cups", isOn: $draft.scoresCups)
                    Stepper("Holds \(draft.pinCapacity) pins", value: $draft.pinCapacity, in: 0...20)
                    Stepper("Holds \(draft.cupCapacity) cups", value: $draft.cupCapacity, in: 0...20)
                    Toggle("Scores pins in autonomous", isOn: $draft.autoPins)
                    Toggle("Scores cups in autonomous", isOn: $draft.autoCups)
                }

                Section("What else it can do") {
                    Picker("Autonomous", selection: $draft.autonomous) {
                        Text("None").tag("None")
                        Text("Practice").tag("Practice")
                        Text("Match-ready").tag("Match-ready")
                    }
                    Picker("Endgame", selection: $draft.endgame) {
                        Text("None").tag("None")
                        Text("Partial").tag("Partial")
                        Text("Consistent").tag("Consistent")
                    }
                    Picker("Defense", selection: $draft.defense) {
                        Text("None").tag("None")
                        Text("Some").tag("Some")
                        Text("Strong").tag("Strong")
                    }
                }

                Section("Notes") {
                    TextField("What did you see in the pit?", text: $draft.notes, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section {
                    Button(draft.editingID == nil ? "Save pit scout" : "Update pit scout") {
                        save()
                    }
                    .disabled(normalizedTeamNumber(draft.teamNumber).isEmpty)
                    if !savedNote.isEmpty {
                        Text(savedNote)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Saved pit scouts") {
                    if store.reports.isEmpty {
                        Text("No pit forms yet. Fill one in while the robot is in the pit.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(store.reports) { report in
                            Button {
                                draft = PitDraft(report)
                                savedNote = ""
                            } label: {
                                VStack(alignment: .leading, spacing: 3) {
                                    HStack {
                                        Text(report.teamNumber)
                                            .font(.body.weight(.semibold))
                                        Spacer()
                                        Text("\(report.percent)%")
                                            .font(.headline.monospacedDigit())
                                            .foregroundStyle(VexLook.gradeColor(report.grade))
                                    }
                                    GradePill(grade: report.grade)
                                    Text(report.summary)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    if !report.notes.isEmpty {
                                        Text(report.notes)
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
            .navigationTitle("Pit")
            .onAppear {
                if draft.teamNumber.isEmpty {
                    draft.teamNumber = normalizedTeamNumber(model.teamNumber)
                }
            }
        }
    }

    private func save() {
        let number = normalizedTeamNumber(draft.teamNumber)
        guard !number.isEmpty else { return }
        let report = draft.report(teamNumber: number)
        store.save(report)
        savedNote = "Saved \(number) · holds \(report.pinCapacity) pins, \(report.cupCapacity) cups"
        draft = PitDraft()
    }
}

private struct PitDraft {
    var editingID: UUID?
    var savedAt = Date()
    var teamNumber = ""
    var drivetrain = "Tank"
    var scoresPins = true
    var scoresCups = true
    var pinCapacity = 0
    var cupCapacity = 0
    var autoPins = false
    var autoCups = false
    var autonomous = "Practice"
    var endgame = "Partial"
    var defense = "None"
    var notes = ""

    init() {}

    init(_ report: PitReport) {
        editingID = report.id
        savedAt = report.savedAt
        teamNumber = report.teamNumber
        drivetrain = report.drivetrain
        scoresPins = report.scoresPins
        scoresCups = report.scoresCups
        pinCapacity = report.pinCapacity
        cupCapacity = report.cupCapacity
        autoPins = report.autoPins
        autoCups = report.autoCups
        autonomous = report.autonomous
        endgame = report.endgame
        defense = report.defense
        notes = report.notes
    }

    var percent: Int { report(teamNumber: teamNumber).percent }
    var grade: String { report(teamNumber: teamNumber).grade }

    func report(teamNumber: String) -> PitReport {
        PitReport(
            id: editingID ?? UUID(),
            savedAt: savedAt,
            teamNumber: normalizedTeamNumber(teamNumber),
            drivetrain: drivetrain,
            scoresPins: scoresPins,
            scoresCups: scoresCups,
            pinCapacity: pinCapacity,
            cupCapacity: cupCapacity,
            autoPins: autoPins,
            autoCups: autoCups,
            autonomous: autonomous,
            endgame: endgame,
            defense: defense,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }
}
