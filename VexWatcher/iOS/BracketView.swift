import SwiftUI

struct BracketView: View {
    @ObservedObject var model: PhoneModel

    var body: some View {
        NavigationStack {
            ZStack {
                VexLook.ink.ignoresSafeArea()
                BracketLights()
                Group {
                    if let report = model.report, !playedMatches(report).isEmpty {
                        board(report)
                    } else {
                        waiting
                    }
                }
            }
            .navigationTitle("Bracket")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await model.reload(keepCurrent: true) }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(model.loading)
                }
            }
            .refreshable { await model.reload(keepCurrent: true) }
            .toolbarBackground(.hidden, for: .navigationBar)
            .preferredColorScheme(.dark)
        }
    }

    private var waiting: some View {
        VStack(spacing: 26) {
            GhostBracket()
                .frame(width: 280, height: 190)
            Text(waitingTitle)
                .font(.system(size: 32, weight: .black, design: .rounded))
                .foregroundStyle(.white)
            Text(waitingDetail)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white.opacity(0.72))
                .multilineTextAlignment(.center)
            if let error = model.errorMessage {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(VexLook.red)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var waitingTitle: String {
        if model.report == nil || !eventIsOver(model.report) { return "Not in elim now" }
        return "Elimination results are in."
    }

    private var waitingDetail: String {
        if model.report == nil { return "Load the event, then refresh." }
        if eventIsOver(model.report) { return "This competition is finished." }
        return "The elimination bracket is not posted yet."
    }

    private func board(_ report: EventReport) -> some View {
        let columns = roundColumns(playedMatches(report))
        return VStack(spacing: 0) {
            stageHeader(report)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .center, spacing: 0) {
                    ForEach(Array(columns.enumerated()), id: \.element.id) { index, column in
                        roundColumn(column, home: "95070D")
                        if index < columns.count - 1 {
                            FlowConnector()
                                .frame(width: 36)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 22)
            }
        }
    }

    private func stageHeader(_ report: EventReport) -> some View {
        let open = eventIsOver(report) ? 0 : report.bracket.filter { !$0.scored }.count
        return HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(report.eventName)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(liveLine(open))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white.opacity(0.7))
            }
            Spacer()
            if open > 0 {
                LiveBeacon()
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(.black.opacity(0.28))
    }

    private func roundColumn(_ column: RoundColumn, home: String) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(column.title)
                .font(.caption.weight(.black))
                .tracking(1.1)
                .textCase(.uppercase)
                .foregroundStyle(.white)
            ForEach(column.series) { series in
                seriesCard(series, home: home)
            }
        }
        .frame(width: 248, alignment: .topLeading)
    }

    private func seriesCard(_ series: BracketSeries, home: String) -> some View {
        let wins = seriesWins(series.games)
        let clinched = wins.red >= 2 || wins.blue >= 2
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(series.title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Spacer()
                if wins.red + wins.blue > 0 {
                    Text("\(wins.red)–\(wins.blue)")
                        .font(.caption.weight(.black))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(.white.opacity(0.12), in: Capsule())
                }
            }
            ForEach(series.games) { game in
                gameBlock(game, home: home)
            }
            if clinched {
                Text(wins.red >= 2 ? "Red advances" : "Blue advances")
                    .font(.caption2.weight(.black))
                    .tracking(0.6)
                    .textCase(.uppercase)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background((wins.red >= 2 ? VexLook.red : VexLook.blue).opacity(0.85), in: Capsule())
            }
        }
        .padding(12)
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [VexLook.red.opacity(0.85), .white.opacity(0.2), VexLook.blue.opacity(0.85)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: clinched ? 1.6 : 1
                )
        }
        .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
    }

    private func gameBlock(_ game: BracketMatch, home: String) -> some View {
        VStack(spacing: 4) {
            HStack {
                Text(gameLabel(game))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.62))
                Spacer()
                if !matchPlayed(game) {
                    Text("LIVE")
                        .font(.system(size: 9, weight: .black))
                        .tracking(0.8)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(VexLook.red, in: Capsule())
                }
            }
            if game.sides.isEmpty {
                Text("Waiting")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.5))
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ForEach(game.sides) { side in
                    sideRow(side, scored: matchPlayed(game), home: home)
                }
            }
        }
        .padding(6)
        .overlay {
            if !matchPlayed(game) {
                MarchingBorder()
            }
        }
    }

    private func sideRow(_ side: BracketSide, scored: Bool, home: String) -> some View {
        let tint = allianceTint(side.color)
        let ours = side.teams.contains { normalizedTeamNumber($0) == home }
        return HStack(spacing: 8) {
            Circle()
                .fill(tint)
                .frame(width: 8, height: 8)
            Text(side.teams.isEmpty ? "TBD" : side.teams.joined(separator: "  "))
                .font(.caption.weight(ours || side.winner ? .black : .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
            if ours {
                Text("YOU")
                    .font(.system(size: 8, weight: .black))
                    .tracking(0.5)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(VexLook.red, in: Capsule())
            }
            Spacer(minLength: 4)
            if scored {
                Text("\(side.score)")
                    .font(.caption.weight(.black))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
            }
            if side.winner {
                Image(systemName: "crown.fill")
                    .font(.caption2)
                    .foregroundStyle(VexLook.amber)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(tint.opacity(side.winner ? 0.55 : 0.22), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            if side.winner {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(tint, lineWidth: 1.4)
            }
        }
    }

    private func eventIsOver(_ report: EventReport?) -> Bool {
        guard let report else { return false }
        if !report.awards.isEmpty { return true }
        if let event = model.events.first(where: { $0.id == report.eventID }) {
            if let end = event.end, Date() > end.addingTimeInterval(24 * 60 * 60) { return true }
            return !event.isLive
        }
        return !report.ongoing
    }

    private func playedMatches(_ report: EventReport) -> [BracketMatch] {
        guard eventIsOver(report) else { return report.bracket }
        return report.bracket.filter(matchPlayed)
    }

    private func matchPlayed(_ match: BracketMatch) -> Bool {
        match.scored || match.sides.contains { $0.score > 0 }
    }

    private func liveLine(_ open: Int) -> String {
        if open == 0 { return "Elimination results are in." }
        if open == 1 { return "1 elimination match still to play." }
        return "\(open) elimination matches still to play."
    }

    private func gameLabel(_ game: BracketMatch) -> String {
        if game.name.isEmpty { return game.scored ? "Played" : "Up next" }
        return game.name
    }

    private func allianceTint(_ color: String) -> Color {
        switch color {
        case "red": return VexLook.red
        case "blue": return VexLook.blue
        default: return .white
        }
    }

    private func seriesWins(_ games: [BracketMatch]) -> (red: Int, blue: Int) {
        var red = 0
        var blue = 0
        for game in games {
            guard let winner = game.sides.first(where: \.winner) else { continue }
            if winner.color == "red" {
                red += 1
            } else if winner.color == "blue" {
                blue += 1
            }
        }
        return (red, blue)
    }

    private func roundColumns(_ matches: [BracketMatch]) -> [RoundColumn] {
        let rounds = Set(matches.map(\.round)).sorted()
        return rounds.map { round in
            let games = matches.filter { $0.round == round }.sorted {
                if $0.matchnum != $1.matchnum { return $0.matchnum < $1.matchnum }
                return $0.instance < $1.instance
            }
            let slots = Dictionary(grouping: games, by: \.matchnum)
            let series = slots.keys.sorted().map { slot in
                let slotGames = slots[slot] ?? []
                return BracketSeries(id: "\(round)-\(slot)", title: slotTitle(slotGames), games: slotGames)
            }
            return RoundColumn(id: round, title: roundTitle(round, sample: games.first?.name ?? ""), series: series)
        }
    }

    private func roundTitle(_ round: Int, sample: String) -> String {
        let name = sample.lowercased()
        if name.contains("semi") { return "Semifinals" }
        if name.contains("quarter") { return "Quarterfinals" }
        if name.contains("final") { return "Finals" }
        if name.contains("32") { return "Round of 32" }
        if name.contains("16") { return "Round of 16" }
        switch round {
        case 3: return "Round of 16"
        case 4: return "Quarterfinals"
        case 5: return "Semifinals"
        case 6: return "Finals"
        default: return "Round \(max(round - 2, 1))"
        }
    }

    private func slotTitle(_ games: [BracketMatch]) -> String {
        let raw = games.first?.name ?? "Match"
        if let range = raw.range(of: #"[- ]\d+$"#, options: .regularExpression) {
            let trimmed = String(raw[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
            if !trimmed.isEmpty { return trimmed }
        }
        return raw
    }
}

private struct BracketLights: View {
    var body: some View {
        LinearGradient(
            colors: [VexLook.red.opacity(0.28), VexLook.ink, VexLook.blue.opacity(0.22)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

private struct GhostBracket: View {
    var body: some View {
        GhostBracketShape()
            .stroke(
                LinearGradient(colors: [VexLook.red, .white.opacity(0.7), VexLook.blue], startPoint: .leading, endPoint: .trailing),
                style: StrokeStyle(lineWidth: 3.5, lineCap: .round, lineJoin: .round)
            )
    }
}

private struct GhostBracketShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let left = rect.minX + 8
        let mid = rect.midX
        let right = rect.maxX - 18
        let slots = [0.16, 0.38, 0.62, 0.84].map { rect.minY + rect.height * $0 }
        for slot in slots {
            path.move(to: CGPoint(x: left, y: slot))
            path.addLine(to: CGPoint(x: left + 54, y: slot))
        }
        path.move(to: CGPoint(x: left + 54, y: slots[0]))
        path.addLine(to: CGPoint(x: left + 54, y: slots[1]))
        path.move(to: CGPoint(x: left + 54, y: slots[2]))
        path.addLine(to: CGPoint(x: left + 54, y: slots[3]))
        let upper = (slots[0] + slots[1]) / 2
        let lower = (slots[2] + slots[3]) / 2
        path.move(to: CGPoint(x: left + 54, y: upper))
        path.addLine(to: CGPoint(x: mid, y: upper))
        path.move(to: CGPoint(x: left + 54, y: lower))
        path.addLine(to: CGPoint(x: mid, y: lower))
        path.move(to: CGPoint(x: mid, y: upper))
        path.addLine(to: CGPoint(x: mid, y: lower))
        path.move(to: CGPoint(x: mid, y: rect.midY))
        path.addLine(to: CGPoint(x: right, y: rect.midY))
        return path
    }
}

private struct FlowConnector: View {
    var body: some View {
        Capsule()
            .fill(
                LinearGradient(colors: [VexLook.red.opacity(0.7), .white.opacity(0.5), VexLook.blue.opacity(0.7)], startPoint: .top, endPoint: .bottom)
            )
            .frame(width: 3)
            .padding(.vertical, 28)
            .allowsHitTesting(false)
    }
}

private struct MarchingBorder: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .stroke(VexLook.amber.opacity(0.9), lineWidth: 1.2)
            .allowsHitTesting(false)
    }
}

private struct LiveBeacon: View {
    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(VexLook.red)
                .frame(width: 8, height: 8)
            Text("LIVE")
                .font(.caption2.weight(.black))
                .tracking(0.8)
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.white.opacity(0.08), in: Capsule())
    }
}

private struct RoundColumn: Identifiable {
    var id: Int
    var title: String
    var series: [BracketSeries]
}

private struct BracketSeries: Identifiable {
    var id: String
    var title: String
    var games: [BracketMatch]
}
