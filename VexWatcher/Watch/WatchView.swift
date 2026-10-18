import SwiftUI

struct WatchRoot: View {
    @ObservedObject var model: WatchModel

    var body: some View {
        NavigationStack {
            Group {
                if let snapshot = model.snapshot, !snapshot.teams.isEmpty {
                    List {
                        if let mine = snapshot.myTeam {
                            Section {
                                NavigationLink {
                                    WatchTeam(team: mine, note: snapshot.note)
                                } label: {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("\(mine.overall)%")
                                            .font(.system(size: 36, weight: .bold, design: .rounded))
                                            .monospacedDigit()
                                            .foregroundStyle(mine.tint)
                                        Text(mine.number)
                                            .font(.caption.weight(.semibold))
                                        GradePill(grade: mine.grade)
                                        Text("\(mine.placeLabel) · \(mine.record)")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                        ForEach(mine.abilities, id: \.self) { line in
                                            Text(line)
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    .padding(.vertical, 4)
                                }
                            }
                        }
                        Section(snapshot.eventName) {
                            ForEach(snapshot.ranked) { team in
                                NavigationLink {
                                    WatchTeam(team: team, note: snapshot.note)
                                } label: {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(team.number)
                                                .font(.caption.weight(.semibold))
                                            Text(team.placeLabel)
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                        }
                                        Spacer(minLength: 4)
                                        Text("\(team.overall)%")
                                            .font(.headline.monospacedDigit())
                                            .foregroundStyle(team.tint)
                                    }
                                }
                            }
                        }
                        Section {
                            Text(model.phoneReachable ? model.status : "Open Vex Watcher on your iPhone")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text(snapshot.note)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "applewatch.radiowaves.left.and.right")
                            .font(.title2)
                            .foregroundStyle(Color.accentColor)
                        Text("Open Vex Watcher on your iPhone.")
                            .font(.caption)
                            .multilineTextAlignment(.center)
                        Text(model.status)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                }
            }
            .navigationTitle("Vex")
        }
    }
}

private struct WatchTeam: View {
    var team: TeamReport
    var note: String

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                Text("\(team.overall)%")
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(team.tint)
                GradePill(grade: team.grade)
                Text(team.placeLabel)
                    .font(.caption.weight(.semibold))
                Text(team.record)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                ForEach(team.abilities, id: \.self) { line in
                    Text(line)
                        .font(.caption2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                ForEach(team.components) { component in
                    PercentBar(name: component.name, percent: component.percent)
                }
                if let driver = team.driver {
                    Text("Driver \(driver)")
                        .font(.caption2)
                }
                if let programming = team.programming {
                    Text("Autonomous \(programming)")
                        .font(.caption2)
                }
                if let opr = team.opr {
                    Text("Adds about \(Int(opr.rounded())) pts")
                        .font(.caption2)
                }
                if team.rank > 0 {
                    Text("WP \(team.wp) · AP \(team.ap) · SP \(team.sp) · High \(team.highScore)")
                        .font(.caption2.monospacedDigit())
                }
                ForEach(team.recent.prefix(5)) { match in
                    Text("\(match.label) \(match.result) \(match.scoreline)")
                        .font(.caption2.monospacedDigit())
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                Text(note)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 4)
        }
        .navigationTitle(team.number)
    }
}
