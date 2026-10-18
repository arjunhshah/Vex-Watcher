import SwiftUI

struct AwardsView: View {
    @ObservedObject var model: PhoneModel

    private var readout: AwardReadout {
        AwardEligibility.readout(teamNumber: model.teamNumber, report: model.report)
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
                    ForEach(readout.awards) { award in
                        NavigationLink(value: award.id) {
                            awardCard(award)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(20)
            }
            .vexScreen()
            .refreshable { await model.reload(keepCurrent: true) }
            .navigationTitle("95070D")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: String.self) { id in
                if let award = readout.awards.first(where: { $0.id == id }) {
                    EligibleTeamsView(award: award, eventName: readout.eventName, homeNumber: normalizedTeamNumber(model.teamNumber))
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await model.reload(keepCurrent: true) }
                    } label: {
                        if model.loading {
                            ProgressView()
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                    .disabled(model.loading)
                    .accessibilityLabel("Refresh")
                }
            }
        }
    }

    private var header: some View {
        VStack(spacing: 6) {
            Text("95070D")
                .font(.system(size: 40, weight: .bold, design: .rounded))
            Text(teamLabel)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if readout.hasEvent {
                Text("\(readout.awards.filter(\.qualified).count) of \(readout.awards.count) qualified · \(readout.eventName)")
                    .font(.footnote.weight(.medium))
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
    }

    private func awardCard(_ award: AwardCard) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(award.name)
                    .font(.headline)
                Spacer(minLength: 8)
                Text(award.qualified ? "Qualified" : "Not qualified")
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(award.qualified ? VexLook.green : VexLook.red, in: Capsule())
                    .foregroundStyle(.white)
            }
            HStack {
                Text(award.eligible.isEmpty ? "See who is eligible" : "\(award.eligible.count) eligible at this event")
                    .font(.caption.weight(.semibold))
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
            }
            ForEach(award.criteria) { gate in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: gate.met ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(gate.met ? VexLook.green : .secondary)
                        .padding(.top, 2)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(gate.name)
                            .font(.body.weight(.semibold))
                        Text(gate.pointsLine)
                            .font(.title3.weight(.bold).monospacedDigit())
                            .foregroundStyle(gate.met ? VexLook.green : VexLook.red)
                        Text(gate.detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .vexCard()
    }

    private var teamLabel: String {
        if let team = model.report.flatMap({ model.myTeam(in: $0) }), !team.name.isEmpty {
            return "\(team.name) · award eligibility"
        }
        return "Redwood Robotics · award eligibility"
    }
}

private struct EligibleTeamsView: View {
    var award: AwardCard
    var eventName: String
    var homeNumber: String

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(award.eligibleNote)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if award.eligible.isEmpty {
                    Text("No teams to list yet.")
                        .font(.headline)
                } else {
                    ForEach(award.eligible) { team in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(team.number)
                                    .font(.headline)
                                if normalizedTeamNumber(team.number) == homeNumber {
                                    Text("You")
                                        .font(.caption2.weight(.bold))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(VexLook.red, in: Capsule())
                                        .foregroundStyle(.white)
                                }
                                Spacer()
                            }
                            if !team.name.isEmpty, team.name != team.number {
                                Text(team.name)
                                    .font(.subheadline)
                            }
                            Text(team.line)
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                        .vexCard()
                    }
                }
            }
            .padding(20)
        }
        .vexScreen()
        .navigationTitle(award.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !eventName.isEmpty {
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 0) {
                        Text(award.name)
                            .font(.headline)
                        Text(eventName)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
        }
    }
}
