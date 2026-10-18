import SwiftUI

struct AllianceView: View {
    @ObservedObject var model: PhoneModel

    private var outlook: AllianceOutlook? {
        guard let report = model.report, let home = model.myTeam(in: report) else { return nil }
        return ScoutMath.allianceChances(home: home, teams: report.teams)
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
                    if let outlook {
                        if outlook.picks.isEmpty {
                            Text("No other teams are in this event yet.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(outlook.picks) { pick in
                                partnerCard(pick, best: pick.id == outlook.picks.first?.id && pick.chance != nil)
                            }
                            Text(outlook.basis)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    } else if model.report == nil {
                        Text("Load 95070D’s event on the Events tab. This list fills in from that field.")
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
            .navigationTitle("Alliance")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var header: some View {
        VStack(spacing: 6) {
            Text("Who to pick")
                .font(.system(size: 34, weight: .bold, design: .rounded))
            Text(model.report?.eventName ?? "Possible alliance members")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
    }

    private func partnerCard(_ pick: AlliancePick, best: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(pick.number)
                    .font(.headline)
                if best {
                    Text("Best pick")
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(VexLook.green, in: Capsule())
                        .foregroundStyle(.white)
                }
                Spacer(minLength: 8)
                Text(chanceText(pick.chance))
                    .font(.title3.weight(.bold).monospacedDigit())
                    .foregroundStyle(chanceColor(pick.chance))
            }
            if !pick.name.isEmpty {
                Text(pick.name)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            if !pick.line.isEmpty {
                Text(pick.line)
                    .font(.subheadline)
            }
        }
        .vexCard()
    }

    private func chanceText(_ chance: Int?) -> String {
        guard let chance else { return "—" }
        return "\(chance)%"
    }

    private func chanceColor(_ chance: Int?) -> Color {
        guard let chance else { return .secondary }
        if chance >= 60 { return VexLook.green }
        if chance >= 45 { return VexLook.amber }
        return VexLook.red
    }
}
