import Foundation

struct PowerAlliance {
    var teamIDs: [Int]
    var score: Int
}

struct PowerMatch {
    var alliances: [PowerAlliance]
}

struct RawTeam {
    var id: Int
    var number: String
    var name: String
    var organization: String
    var rank: Int
    var wins: Int
    var losses: Int
    var ties: Int
    var wp: Int
    var ap: Int
    var sp: Int
    var highScore: Int
    var averagePoints: Double
    var driver: Int?
    var programming: Int?
    var driverRank: Int?
    var programmingRank: Int?
    var recent: [RecentMatch]
}

enum ScoutMath {
    /// Overall percent blends win rate, rank, skills, and scoring against this event only.
    static func rate(_ rawTeams: [RawTeam], opr: [Int: Double]) -> [TeamReport] {
        let rankedCount = rawTeams.filter { $0.rank > 0 }.count
        let programmingPool = rawTeams.compactMap { $0.programming }.map(Double.init)
        let driverPool = rawTeams.compactMap { $0.driver }.map(Double.init)
        let skillTeams = rawTeams.filter { $0.driver != nil || $0.programming != nil }
        let skillPool = skillTeams.map { Double($0.driver ?? 0) + Double($0.programming ?? 0) }
        let oprCount = rawTeams.filter { opr[$0.id] != nil }.count
        let useOPR = !rawTeams.isEmpty && oprCount * 2 >= rawTeams.count
        let scoringPool: [Double]
        if useOPR {
            scoringPool = rawTeams.compactMap { opr[$0.id] }
        } else {
            scoringPool = rawTeams.compactMap { team -> Double? in
                played(team) > 0 ? team.averagePoints : nil
            }
        }

        return rawTeams.map { team in
            let playedCount = played(team)
            let win: Double? = playedCount > 0
                ? (Double(team.wins) + 0.5 * Double(team.ties)) / Double(playedCount) * 100
                : nil
            let rankScore: Double? = team.rank > 0 && rankedCount > 1
                ? Double(rankedCount - team.rank) / Double(rankedCount - 1) * 100
                : nil
            let skills: Double? = {
                guard team.driver != nil || team.programming != nil else { return nil }
                let value = Double(team.driver ?? 0) + Double(team.programming ?? 0)
                return percentile(value, among: skillPool)
            }()
            let scoring: Double? = {
                if useOPR {
                    guard let value = opr[team.id] else { return nil }
                    return percentile(value, among: scoringPool)
                }
                guard playedCount > 0 else { return nil }
                return percentile(team.averagePoints, among: scoringPool)
            }()

            var weighted = 0.0
            var weight = 0.0
            func add(_ value: Double?, _ portion: Double) {
                guard let value else { return }
                weighted += value * portion
                weight += portion
            }
            add(win, 0.30)
            add(rankScore, 0.25)
            add(skills, 0.25)
            add(scoring, 0.20)
            let overall = weight > 0 ? Int((weighted / weight).rounded()) : 0
            let clamped = min(100, max(0, overall))

            var components: [ScoreComponent] = []
            if let win { components.append(ScoreComponent(name: "Win rate", percent: Int(win.rounded()))) }
            if let rankScore { components.append(ScoreComponent(name: "Rank", percent: Int(rankScore.rounded()))) }
            if let skills { components.append(ScoreComponent(name: "Skills", percent: Int(skills.rounded()))) }
            if let scoring { components.append(ScoreComponent(name: "Scoring", percent: Int(scoring.rounded()))) }

            let programmingPercent = team.programming.map { percentile(Double($0), among: programmingPool) }
            let driverPercent = team.driver.map { percentile(Double($0), among: driverPool) }

            return TeamReport(
                id: team.id,
                number: team.number,
                name: team.name,
                organization: team.organization,
                rank: team.rank,
                wins: team.wins,
                losses: team.losses,
                ties: team.ties,
                wp: team.wp,
                ap: team.ap,
                sp: team.sp,
                highScore: team.highScore,
                averagePoints: team.averagePoints,
                driver: team.driver,
                programming: team.programming,
                driverRank: team.driverRank,
                programmingRank: team.programmingRank,
                opr: opr[team.id],
                overall: clamped,
                grade: grade(clamped),
                abilities: abilities(
                    programming: team.programming,
                    programmingPercent: programmingPercent,
                    driver: team.driver,
                    driverPercent: driverPercent,
                    played: playedCount,
                    win: win,
                    scoring: scoring
                ),
                components: components,
                recent: team.recent
            )
        }
    }

    static func offensivePower(_ matches: [PowerMatch]) -> [Int: Double] {
        var ids: [Int] = []
        var seen = Set<Int>()
        for match in matches {
            for alliance in match.alliances {
                for id in alliance.teamIDs where seen.insert(id).inserted {
                    ids.append(id)
                }
            }
        }
        let index = Dictionary(uniqueKeysWithValues: ids.enumerated().map { ($1, $0) })
        let count = ids.count
        guard count > 0 else { return [:] }

        var normal = Array(repeating: Array(repeating: 0.0, count: count), count: count)
        var target = Array(repeating: 0.0, count: count)
        var played = Array(repeating: false, count: count)

        for match in matches {
            for alliance in match.alliances {
                let columns = alliance.teamIDs.compactMap { index[$0] }
                guard !columns.isEmpty else { continue }
                for row in columns {
                    played[row] = true
                    target[row] += Double(alliance.score)
                    for column in columns {
                        normal[row][column] += 1
                    }
                }
            }
        }

        let used = ids.indices.filter { played[$0] }
        guard !used.isEmpty else { return [:] }
        let size = used.count
        var matrix = Array(repeating: Array(repeating: 0.0, count: size), count: size)
        var vector = Array(repeating: 0.0, count: size)
        for (rowIndex, row) in used.enumerated() {
            vector[rowIndex] = target[row]
            for (columnIndex, column) in used.enumerated() {
                matrix[rowIndex][columnIndex] = normal[row][column]
            }
            matrix[rowIndex][rowIndex] += 0.05
        }
        guard let solved = solve(matrix, vector) else { return [:] }
        var result: [Int: Double] = [:]
        for (rowIndex, row) in used.enumerated() {
            result[ids[row]] = solved[rowIndex]
        }
        return result
    }

    static func percentile(_ value: Double, among values: [Double]) -> Double {
        guard values.count > 1 else { return 100 }
        let below = values.reduce(0) { $0 + ($1 < value ? 1 : 0) }
        let same = values.reduce(0) { $0 + ($1 == value ? 1 : 0) }
        let mid = Double(below) + Double(max(0, same - 1)) / 2
        return mid / Double(values.count - 1) * 100
    }

    static func selfCheck() -> String? {
        let values = [10.0, 20.0, 30.0]
        let top = percentile(30, among: values)
        let mid = percentile(20, among: values)
        let low = percentile(10, among: values)
        if abs(top - 100) > 0.1 { return "top percentile \(top)" }
        if abs(mid - 50) > 0.1 { return "mid percentile \(mid)" }
        if abs(low - 0) > 0.1 { return "low percentile \(low)" }

        let matches = [
            PowerMatch(alliances: [
                PowerAlliance(teamIDs: [1, 2], score: 30),
                PowerAlliance(teamIDs: [3, 4], score: 10),
            ]),
            PowerMatch(alliances: [
                PowerAlliance(teamIDs: [1, 3], score: 28),
                PowerAlliance(teamIDs: [2, 4], score: 12),
            ]),
            PowerMatch(alliances: [
                PowerAlliance(teamIDs: [1, 4], score: 26),
                PowerAlliance(teamIDs: [2, 3], score: 14),
            ]),
        ]
        let power = offensivePower(matches)
        guard let leader = power[1], let other = power[2], power[3] != nil, power[4] != nil else {
            return "missing opr \(power)"
        }
        if leader <= other || leader <= (power[3] ?? 0) || leader <= (power[4] ?? 0) {
            return "team 1 should lead \(power)"
        }

        let reports = rate([
            sample(id: 1, rank: 1, wins: 2, losses: 0, driver: 40, programming: 30),
            sample(id: 2, rank: 2, wins: 0, losses: 2, driver: 10, programming: 5),
        ], opr: [1: 40, 2: 15])
        guard reports.count == 2, reports[0].overall > reports[1].overall else {
            return "rating order \(reports.map { $0.overall })"
        }
        return nil
    }

    private static func sample(id: Int, rank: Int, wins: Int, losses: Int, driver: Int, programming: Int) -> RawTeam {
        RawTeam(
            id: id,
            number: "\(id)A",
            name: "Team \(id)",
            organization: "",
            rank: rank,
            wins: wins,
            losses: losses,
            ties: 0,
            wp: wins * 2,
            ap: 0,
            sp: 0,
            highScore: 50,
            averagePoints: Double(30 + wins * 10),
            driver: driver,
            programming: programming,
            driverRank: nil,
            programmingRank: nil,
            recent: []
        )
    }

    private static func played(_ team: RawTeam) -> Int {
        team.wins + team.losses + team.ties
    }

    static func grade(_ percent: Int) -> String {
        switch percent {
        case 85...: return "Elite"
        case 70..<85: return "Strong"
        case 55..<70: return "Good"
        case 40..<55: return "Average"
        default: return "Developing"
        }
    }

    private static func abilities(
        programming: Int?,
        programmingPercent: Double?,
        driver: Int?,
        driverPercent: Double?,
        played: Int,
        win: Double?,
        scoring: Double?
    ) -> [String] {
        var lines: [String] = []
        if let programmingPercent, (programming ?? 0) > 0 {
            if programmingPercent >= 75 {
                lines.append("Strong autonomous")
            } else if programmingPercent >= 45 {
                lines.append("Works in autonomous")
            } else {
                lines.append("Light autonomous")
            }
        } else {
            lines.append("No autonomous score yet")
        }
        if let driverPercent, (driver ?? 0) > 0 {
            if driverPercent >= 75 {
                lines.append("Strong driver")
            } else if driverPercent >= 45 {
                lines.append("Solid driver")
            } else {
                lines.append("Developing driver")
            }
        } else {
            lines.append("No driver skills yet")
        }
        if played > 0, let win {
            if win >= 65 {
                lines.append("Wins most matches")
            } else if win >= 45 {
                lines.append("Splits matches")
            } else {
                lines.append("Loses more than it wins")
            }
        }
        if let scoring {
            if scoring >= 75 {
                lines.append("High scoring")
            } else if scoring >= 45 {
                lines.append("Middle of the pack scoring")
            } else {
                lines.append("Low scoring")
            }
        }
        return Array(lines.prefix(4))
    }

    private static func solve(_ matrix: [[Double]], _ vector: [Double]) -> [Double]? {
        let count = vector.count
        guard matrix.count == count, count > 0 else { return nil }
        var rows = matrix
        var result = vector
        for column in 0..<count {
            var pivot = column
            var best = abs(rows[column][column])
            if column + 1 < count {
                for row in (column + 1)..<count where abs(rows[row][column]) > best {
                    best = abs(rows[row][column])
                    pivot = row
                }
            }
            if best < 1e-10 { return nil }
            if pivot != column {
                rows.swapAt(pivot, column)
                result.swapAt(pivot, column)
            }
            let diagonal = rows[column][column]
            if column + 1 < count {
                for row in (column + 1)..<count {
                    let factor = rows[row][column] / diagonal
                    if factor == 0 { continue }
                    for index in column..<count {
                        rows[row][index] -= factor * rows[column][index]
                    }
                    result[row] -= factor * result[column]
                }
            }
        }
        var solution = Array(repeating: 0.0, count: count)
        var row = count - 1
        while row >= 0 {
            var sum = result[row]
            if row + 1 < count {
                for column in (row + 1)..<count {
                    sum -= rows[row][column] * solution[column]
                }
            }
            if abs(rows[row][row]) < 1e-10 { return nil }
            solution[row] = sum / rows[row][row]
            if row == 0 { break }
            row -= 1
        }
        return solution
    }
}
