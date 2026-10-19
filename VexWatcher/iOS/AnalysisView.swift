import SwiftUI

struct AnalysisView: View {
    @ObservedObject var model: PhoneModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    Button {
                        Task { await model.loadAnalyses() }
                    } label: {
                        Label(model.analysisLoading ? "Reading events…" : "Refresh", systemImage: "arrow.clockwise")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(model.analysisLoading)
                    if let error = model.analysisError {
                        Text(error)
                            .font(.subheadline)
                            .foregroundStyle(.red)
                    }
                    if let live = model.liveWriteup {
                        NavigationLink {
                            WriteupDetail(writeup: live)
                        } label: {
                            writeupRow(live, badge: "Now")
                        }
                        .buttonStyle(.plain)
                    }
                    if model.writeups.isEmpty, !model.analysisLoading {
                        Text("Finished competitions show up here after 95070D plays them. Each one is a post-game read from the scores, with the livestream when VEX listed one.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    ForEach(model.writeups) { writeup in
                        NavigationLink {
                            WriteupDetail(writeup: writeup)
                        } label: {
                            writeupRow(writeup, badge: "Post-game")
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(20)
            }
            .vexScreen()
            .refreshable { await model.loadAnalyses() }
            .navigationTitle("Analysis")
            .navigationBarTitleDisplayMode(.inline)
            .task { await model.loadAnalyses() }
        }
    }

    private var header: some View {
        VStack(spacing: 6) {
            Text("Post-game")
                .font(.system(size: 34, weight: .bold, design: .rounded))
            Text("Comps 95070D has gone to")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
    }

    private func writeupRow(_ writeup: CompWriteup, badge: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(badge)
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(writeup.finished ? VexLook.green : VexLook.red, in: Capsule())
                    .foregroundStyle(.white)
                Spacer()
                if writeup.webcast != nil {
                    Image(systemName: "play.rectangle.fill")
                        .foregroundStyle(VexLook.red)
                }
            }
            Text(writeup.name)
                .font(.headline)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)
            Text(writeup.headline)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
            let meta = [writeup.when, writeup.place].filter { !$0.isEmpty }.joined(separator: " · ")
            if !meta.isEmpty {
                Text(meta)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .vexCard()
    }
}

private struct WriteupDetail: View {
    var writeup: CompWriteup

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text(writeup.placeLine)
                    .font(.title2.weight(.bold))
                section("Before", lines: writeup.before)
                section("After", lines: writeup.after)
                matchList(writeup.matches)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Awards")
                        .font(.headline)
                    ForEach(writeup.awards) { award in
                        VStack(alignment: .leading, spacing: 3) {
                            Text(award.winners)
                                .font(.title3.weight(.bold))
                            HStack {
                                Text(award.title)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                Spacer()
                                if award.ours {
                                    Text("Us")
                                        .font(.caption2.weight(.bold))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(VexLook.green, in: Capsule())
                                        .foregroundStyle(.white)
                                }
                            }
                        }
                    }
                }
                .vexCard()
                if let webcast = writeup.webcast, let url = URL(string: webcast) {
                    Link(destination: url) {
                        Label("Open the livestream", systemImage: "play.rectangle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(20)
        }
        .vexScreen()
        .navigationTitle(writeup.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func matchList(_ matches: [RecentMatch]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Matches")
                .font(.headline)
            if matches.isEmpty {
                Text("No matches posted yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(matches) { match in
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text(match.result)
                            .font(.caption.weight(.bold))
                            .frame(width: 22, height: 22)
                            .background(resultColor(match.result).opacity(0.16), in: Circle())
                            .foregroundStyle(resultColor(match.result))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(match.label)
                                .font(.subheadline.weight(.semibold))
                            if !match.detail.isEmpty {
                                Text(match.detail)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer(minLength: 8)
                        Text(match.scoreline)
                            .font(.subheadline.monospacedDigit())
                    }
                }
            }
        }
        .vexCard()
    }

    private func resultColor(_ result: String) -> Color {
        switch result {
        case "W": return VexLook.green
        case "L": return VexLook.red
        default: return VexLook.amber
        }
    }

    private func section(_ title: String, lines: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                Text(line)
                    .font(.body)
            }
        }
        .vexCard()
    }
}
