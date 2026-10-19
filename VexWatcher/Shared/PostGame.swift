import Foundation

struct AwardLine: Identifiable, Equatable {
    var title: String
    var winners: String
    var ours: Bool
    var id: String { "\(title) \(winners)" }
}

struct CompWriteup: Identifiable, Equatable {
    var id: Int
    var name: String
    var when: String
    var place: String
    var finished: Bool
    var headline: String
    var placeLine: String
    var before: [String]
    var after: [String]
    var awards: [AwardLine]
    var matches: [RecentMatch]
    var webcast: String?
}

enum PostGame {
    static func writeup(event: EventSummary, report: EventReport, home: TeamReport, webcast: String?, includeStreamNote: Bool = true) -> CompWriteup {
        let played = home.wins + home.losses + home.ties
        let field = report.teams.filter { $0.wins + $0.losses + $0.ties > 0 }
        let fieldAverage = field.isEmpty ? 0 : field.map(\.averagePoints).reduce(0, +) / Double(field.count)
        let placeLine = placeSentence(home: home, field: report.teams.count, live: event.isLive)
        var after: [String] = []

        if played > 0 {
            let average = Int(home.averagePoints.rounded())
            let fieldLine = fieldAverage > 0 ? " The field averaged \(Int(fieldAverage.rounded()))." : ""
            after.append("\(home.record). About \(average) points a match, high score \(home.highScore).\(fieldLine)")
            after.append(scoreRead(home: home, fieldAverage: fieldAverage))
        } else {
            after.append("No qualification matches are posted for \(home.number) at this event yet.")
        }

        if home.skillsTotal > 0 {
            var skill = "Skills were \(home.skillsTotal) combined"
            if let driver = home.driver { skill += ", driver \(driver)" }
            if let programming = home.programming { skill += ", autonomous \(programming)" }
            skill += "."
            if let rank = home.programmingRank, rank > 0, rank <= 5 {
                skill += " Autonomous is near the top of this field. Keep that routine."
            } else if (home.programming ?? 0) == 0 {
                skill += " Autonomous is still at zero. That is the first thing to fix before the next event."
            }
            after.append(skill)
        }

        after.append(elimLine(report: report, home: home))
        after.append(nextStep(home: home, fieldAverage: fieldAverage))

        if let webcast, !webcast.isEmpty {
            after.append("This event has a livestream. The writeup uses the posted scores. Open the stream to rewatch the same matches.")
        } else if includeStreamNote {
            after.append("No livestream was listed for this event. The writeup uses the posted scores.")
        }

        let headline: String
        if event.isLive {
            headline = home.rank > 0 ? "So far · \(home.placeLabel)" : (played > 0 ? "So far · \(home.record)" : "Event is still going")
        } else if home.rank > 0 {
            headline = "\(home.placeLabel) · \(home.record)"
        } else {
            headline = "Post-game"
        }

        return CompWriteup(
            id: event.id,
            name: event.name,
            when: event.when,
            place: event.place,
            finished: !event.isLive,
            headline: headline,
            placeLine: placeLine,
            before: beforeLines(report: report, home: home),
            after: after,
            awards: awardLines(report: report, home: home),
            matches: Array(home.recent.reversed()),
            webcast: webcast
        )
    }

    private static func placeSentence(home: TeamReport, field: Int, live: Bool) -> String {
        if home.rank > 0 {
            let verb = live ? "is" : "finished"
            return "\(home.number) \(verb) \(home.placeLabel) of \(field)."
        }
        return "\(home.number) does not have a rank at this event yet."
    }

    private static func beforeLines(report: EventReport, home: TeamReport) -> [String] {
        var lines = [
            "Going in: pick one wall, score one load, and back straight out. If that wall is blocked, take the other wall. In the last 20 seconds, finish the stack you already have."
        ]
        let outlook = ScoutMath.allianceChances(home: home, teams: report.teams)
        let partner = outlook.picks.first.flatMap { pick in
            report.teams.first { normalizedTeamNumber($0.number) == normalizedTeamNumber(pick.number) }
        }
        if let best = outlook.picks.first, let chance = best.chance {
            lines.append("Best alliance partner in this field was \(best.number)\(best.name.isEmpty ? "" : ", \(best.name)"). About \(chance)% to beat a random other alliance.")
        }
        let forecast = AwardEligibility.forecast(report: report, home: home, partner: partner)
        lines.append("States chance with that read was \(forecast.states.chance)%. Worlds was \(forecast.worlds.chance)%.")
        return lines
    }

    private static func awardLines(report: EventReport, home: TeamReport) -> [AwardLine] {
        let mine = normalizedTeamNumber(home.number)
        if report.awards.isEmpty {
            return [AwardLine(title: "Awards", winners: "Not posted yet.", ours: false)]
        }
        var lines = report.awards.map { award in
            let ours = award.winners.contains { normalizedTeamNumber($0) == mine }
            let winners = award.winners.isEmpty ? "No team listed" : labeled(award.winners, teams: report.teams)
            return AwardLine(title: award.title, winners: winners, ours: ours)
        }
        let states = statesWinners(report.awards)
        if !states.isEmpty {
            lines.insert(
                AwardLine(
                    title: "States",
                    winners: labeled(states, teams: report.teams),
                    ours: states.contains { normalizedTeamNumber($0) == mine }
                ),
                at: 0
            )
        }
        return lines
    }

    private static func labeled(_ numbers: [String], teams: [TeamReport]) -> String {
        numbers.map { number in
            let key = normalizedTeamNumber(number)
            guard let team = teams.first(where: { normalizedTeamNumber($0.number) == key }),
                  !team.name.isEmpty, team.name != team.number else { return number }
            return "\(team.number) · \(team.name)"
        }.joined(separator: "\n")
    }

    private static func statesWinners(_ awards: [EventAward]) -> [String] {
        var seen = Set<String>()
        var rows: [String] = []
        for award in awards where award.qualifies || qualifiesForStates(award.title) {
            for winner in award.winners {
                let key = normalizedTeamNumber(winner)
                guard !key.isEmpty, seen.insert(key).inserted else { continue }
                rows.append(winner)
            }
        }
        return rows
    }

    private static func qualifiesForStates(_ title: String) -> Bool {
        let text = title.lowercased()
        if text.contains("judge") || text.contains("inspire") || text.contains("energy") || text.contains("sportsmanship") {
            return false
        }
        let keys = ["excellence", "tournament champion", "design", "skills champion", "robot skills", "innovate", "finalist", "think", "amaze", "build", "create"]
        return keys.contains { text.contains($0) }
    }

    static func webcastMap(from page: String) -> [String: String] {
        guard let regex = try? NSRegularExpression(pattern: #"\(([A-Z]{2}-[A-Z0-9]+-\d{2}-\d+)\)"#) else { return [:] }
        let ns = page as NSString
        let found = regex.matches(in: page, range: NSRange(location: 0, length: ns.length))
        var map: [String: String] = [:]
        for (index, match) in found.enumerated() {
            guard match.numberOfRanges > 1 else { continue }
            let sku = ns.substring(with: match.range(at: 1))
            let start = match.range.location + match.range.length
            let end = index + 1 < found.count ? found[index + 1].range.location : ns.length
            guard end > start else { continue }
            let window = ns.substring(with: NSRange(location: start, length: end - start))
            if let url = firstURL(in: window) {
                map[sku.uppercased()] = url
            }
        }
        return map
    }

    private static func scoreRead(home: TeamReport, fieldAverage: Double) -> String {
        let average = home.averagePoints
        if fieldAverage > 0, average >= fieldAverage + 8 {
            return "The robot scored above this field. The points came from staying on a wall goal and leaving before the robot jammed."
        }
        if fieldAverage > 0, average + 8 < fieldAverage {
            return "The robot scored under this field. Pick one wall, score one load, and back straight out."
        }
        if home.highScore > 0, average > 0, Double(home.highScore) > average * 1.45 {
            return "One match scored much higher than the rest. The hot match is the one where the robot left the wall after each load."
        }
        if home.wins > home.losses, fieldAverage > 0, average + 4 < fieldAverage {
            return "The record is ahead of the score. The wins came without big scoring totals."
        }
        return "Scores sat with the middle of this field. The same wall plan, with a clean exit after each score, is what moves the average up."
    }

    private static func elimLine(report: EventReport, home: TeamReport) -> String {
        let number = normalizedTeamNumber(home.number)
        if report.championNumbers.contains(where: { normalizedTeamNumber($0) == number }) {
            return "Won the elimination finals."
        }
        let mine = report.bracket.filter { match in
            match.sides.contains { side in
                side.teams.contains { normalizedTeamNumber($0) == number }
            }
        }
        if mine.isEmpty {
            return report.ongoing ? "Eliminations are not posted yet." : "Did not play in eliminations."
        }
        let rounds = Set(report.bracket.map(\.round)).sorted()
        let best = mine.map(\.round).max() ?? 0
        let fromFinal = rounds.count - 1 - (rounds.firstIndex(of: best) ?? 0)
        switch fromFinal {
        case 0: return "Reached the finals."
        case 1: return "Reached the semifinals."
        case 2: return "Reached the quarterfinals."
        default: return "Played in eliminations."
        }
    }

    private static func nextStep(home: TeamReport, fieldAverage: Double) -> String {
        if (home.programming ?? 0) == 0, home.wins + home.losses + home.ties > 0 {
            return "Next event: get an autonomous score on the board before qualification starts."
        }
        if home.highScore > 0, home.averagePoints > 0, Double(home.highScore) > home.averagePoints * 1.45 {
            return "Next event: chase the high-score match every time. Back out after one load."
        }
        if fieldAverage > 0, home.averagePoints + 8 < fieldAverage {
            return "Next event: stay on one wall for the whole match and stop crossing the field."
        }
        return "Next event: keep the wall plan and leave the goal before the robot tips."
    }

    private static func firstURL(in text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: #"https?://[^\s\"'<>]+"#) else { return nil }
        let ns = text as NSString
        guard let match = regex.firstMatch(in: text, range: NSRange(location: 0, length: ns.length)) else { return nil }
        var url = ns.substring(with: match.range)
        while let last = url.last, ".,);".contains(last) {
            url.removeLast()
        }
        return url
    }
}
