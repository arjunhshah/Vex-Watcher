import Foundation

struct AwardGate: Identifiable, Equatable {
    var id: String
    var name: String
    var met: Bool
    var pointsLine: String
    var detail: String
}

struct EligibleTeam: Identifiable, Equatable {
    var number: String
    var name: String
    var line: String
    var id: String { number }
}

struct AwardCard: Identifiable, Equatable {
    var id: String
    var name: String
    var qualified: Bool
    var criteria: [AwardGate]
    var eligible: [EligibleTeam] = []
    var eligibleNote: String = ""
}

struct AwardReadout: Equatable {
    var teamNumber: String
    var eventName: String
    var hasEvent: Bool
    var inEvent: Bool
    var fieldSize: Int
    var cutoff: Int
    var gates: [AwardGate]
    var awards: [AwardCard]
    var scoreGatesMet: Bool
    var headline: String
    var detail: String
}

enum AwardEligibility {
    /// Top 40% rounds up: 40% of 24 teams is 9.6, which is a top-10 cutoff.
    static func cutoff(fieldSize: Int) -> Int {
        guard fieldSize > 0 else { return 0 }
        return Int((Double(fieldSize) * 0.4).rounded(.up))
    }

    static func readout(teamNumber: String, report: EventReport?) -> AwardReadout {
        let number = normalizedTeamNumber(teamNumber)
        guard let report, !report.teams.isEmpty else {
            return AwardReadout(
                teamNumber: number,
                eventName: "",
                hasEvent: false,
                inEvent: false,
                fieldSize: 0,
                cutoff: 0,
                gates: [],
                awards: waitingAwards(),
                scoreGatesMet: false,
                headline: "Open 95070D’s event",
                detail: "Excellence is decided at each event. Open 95070D’s event on the Events tab and this page checks the three score gates. The notebook, interview, and student-work items below are required either way."
            )
        }

        guard let team = report.teams.first(where: { normalizedTeamNumber($0.number) == number }) else {
            let field = report.teams.count
            let need = cutoff(fieldSize: field)
            return AwardReadout(
                teamNumber: number,
                eventName: report.eventName,
                hasEvent: true,
                inEvent: false,
                fieldSize: field,
                cutoff: need,
                gates: [],
                awards: waitingAwards(),
                scoreGatesMet: false,
                headline: "Not at this event",
                detail: "\(number) is not in the \(field) teams loaded for \(report.eventName)."
            )
        }

        let scope = excellenceScope(team: team, teams: report.teams, levels: report.schoolLevels)
        let pool = scope.teams
        let field = pool.count
        let need = cutoff(fieldSize: field)
        let skillsPlace = place(of: team.skillsTotal, in: pool.map(\.skillsTotal))
        let autoScore = team.programming ?? 0
        let autoPlace = place(of: autoScore, in: pool.map { $0.programming ?? 0 })
        let qualPlace = qualificationPlace(team: team, pool: pool)
        let qualMet = qualPlace <= need
        let skillsShort = pointsShort(
            score: team.skillsTotal,
            otherScores: pool.filter { $0.id != team.id }.map(\.skillsTotal),
            cutoffRank: need,
            requireAboveZero: false
        )
        let autoShort = pointsShort(
            score: autoScore,
            otherScores: pool.filter { $0.id != team.id }.map { $0.programming ?? 0 },
            cutoffRank: need,
            requireAboveZero: true
        )
        let skillsMet = skillsPlace <= need
        let autoMet = autoScore > 0 && autoPlace <= need
        let ready = qualMet && skillsMet && autoMet
        let qual = qualificationGap(team: team, teams: pool, cutoffRank: need, met: qualMet)

        let gates = [
            AwardGate(
                id: "qual",
                name: "Qualification rank",
                met: qualMet,
                pointsLine: qual.line,
                detail: "\(qual.detail) \(scope.detail) This is top \(need) of \(field), not a fixed top 9."
            ),
            AwardGate(
                id: "skills",
                name: "Robot Skills",
                met: skillsMet,
                pointsLine: skillsMet ? "0 more points" : more(skillsShort.needed, "point"),
                detail: "You have \(team.skillsTotal). The top \(need) line is \(skillsShort.target). Rank \(skillsPlace) of \(field). Skipping skills counts as zero."
            ),
            AwardGate(
                id: "auto",
                name: "Autonomous Coding Skills",
                met: autoMet,
                pointsLine: autoMet ? "0 more points" : more(autoShort.needed, "point"),
                detail: "You have \(autoScore). The top \(need) line is \(autoShort.target), and the score has to be above zero. Rank \(autoPlace) of \(field)."
            )
        ]

        let headline = ready ? "Already eligible on the scores" : "Not eligible for Excellence yet"
        let detail = ready
            ? "\(number) is already inside the top \(need) of \(field) teams at \(report.eventName) for qualifications, Robot Skills, and Autonomous Coding Skills. Finish the notebook, interview, and student-work items below."
            : "\(number) is not eligible for the Excellence Award at \(report.eventName) yet. Meet every score gate below, then finish the notebook and interview."

        let awards = withEligible(
            liveAwards(
                team: team,
                field: field,
                need: need,
                skillsPlace: skillsPlace,
                autoScore: autoScore,
                autoPlace: autoPlace,
                qualMet: qualMet,
                skillsMet: skillsMet,
                autoMet: autoMet,
                gates: gates,
                teams: report.teams,
                champions: report.championNumbers
            ),
            teams: report.teams,
            levels: report.schoolLevels,
            champions: report.championNumbers
        )

        return AwardReadout(
            teamNumber: number,
            eventName: report.eventName,
            hasEvent: true,
            inEvent: true,
            fieldSize: field,
            cutoff: need,
            gates: gates,
            awards: awards,
            scoreGatesMet: ready,
            headline: headline,
            detail: detail
        )
    }

    private static func place(of score: Int, in scores: [Int]) -> Int {
        scores.filter { $0 > score }.count + 1
    }

    /// Points still needed to tie the team on the top-40% line. Matching that score puts this team inside the cutoff.
    static func pointsShort(score: Int, otherScores: [Int], cutoffRank: Int, requireAboveZero: Bool) -> (needed: Int, target: Int) {
        let sorted = otherScores.sorted(by: >)
        let target = cutoffRank - 1 < sorted.count ? sorted[cutoffRank - 1] : 0
        var needed = max(0, target - score)
        if requireAboveZero, score + needed <= 0 {
            needed = max(1 - score, 0)
        }
        return (needed, max(target, requireAboveZero ? 1 : 0))
    }

    private static func qualificationPlace(team: TeamReport, pool: [TeamReport]) -> Int {
        let ranked = pool.filter { $0.rank > 0 }
        guard team.rank > 0 else { return ranked.count + 1 }
        return ranked.filter { $0.rank < team.rank }.count + 1
    }

    private static func excellenceScope(team: TeamReport, teams: [TeamReport], levels: [String: String]) -> (teams: [TeamReport], detail: String) {
        func level(_ team: TeamReport) -> String {
            let posted = levels[normalizedTeamNumber(team.number)] ?? ""
            if posted.isEmpty, normalizedTeamNumber(team.number) == "95070D" { return "Middle School" }
            return posted
        }
        let middle = teams.filter { level($0) == "Middle School" }
        let high = teams.filter { level($0) == "High School" }
        let mine = level(team)
        if middle.count >= 10, high.count >= 10, mine == "Middle School" || mine == "High School" {
            var group = mine == "Middle School" ? middle : high
            if !group.contains(where: { $0.id == team.id }) { group.append(team) }
            let name = mine == "Middle School" ? "middle school" : "high school"
            return (group, "Compared with \(name) only. Both grades have at least 10 teams, so Excellence is split.")
        }
        if middle.isEmpty, high.isEmpty {
            return (teams, "Grades are not in this download yet, so this is the whole field. Refresh after the event loads. Excellence uses middle school only when both grades have at least 10 teams.")
        }
        return (teams, "This is the whole field. Middle school has \(middle.count) and high school has \(high.count). Excellence stays one list until both grades have at least 10 teams.")
    }

    private static func qualificationGap(team: TeamReport, teams: [TeamReport], cutoffRank: Int, met: Bool) -> (line: String, detail: String) {
        let ordered = teams.filter { $0.rank > 0 }.sorted { $0.rank < $1.rank }
        let here = qualificationPlace(team: team, pool: teams)
        let edge = cutoffRank > 0 && cutoffRank - 1 < ordered.count ? ordered[cutoffRank - 1] : nil
        if met {
            return ("0 more win points", "Place \(here) of \(teams.count) with \(team.wp) win points. Already inside the top \(cutoffRank).")
        }
        guard let edge else {
            return ("No line yet", "No qualification rank to chase yet. Need a finish inside the top \(cutoffRank).")
        }
        let gap = edge.wp - team.wp
        if team.rank <= 0 {
            return (more(max(gap, 0), "win point"), "No rank yet. Place \(here) of \(teams.count). The last eligible team has \(edge.wp) win points.")
        }
        if gap > 0 {
            return (more(gap, "win point"), "Place \(here) of \(teams.count) with \(team.wp) win points. The top \(cutoffRank) line is \(edge.wp) win points.")
        }
        if team.ap < edge.ap {
            let apGap = edge.ap - team.ap
            return (more(apGap, "autonomous point"), "Win points are tied at \(team.wp). Need more autonomous points than \(edge.ap) to pass the cutoff team.")
        }
        if team.sp < edge.sp {
            let spGap = edge.sp - team.sp
            return (more(spGap, "strength point"), "Win points and autonomous points are tied. Need more strength points than \(edge.sp).")
        }
        return ("Tiebreak", "Rank \(team.rank) with \(team.wp) win points. The cutoff team is tied on points, so the next match decides it.")
    }

    private static func withEligible(
        _ awards: [AwardCard],
        teams: [TeamReport],
        levels: [String: String],
        champions: [String]
    ) -> [AwardCard] {
        let excellence = teams.filter { passesExcellence($0, teams: teams, levels: levels) }
            .sorted { qualificationPlace(team: $0, pool: teams) < qualificationPlace(team: $1, pool: teams) }
        let leaderScore = teams.map(\.skillsTotal).max() ?? 0
        let leaders = teams.filter { leaderScore > 0 && $0.skillsTotal == leaderScore }
            .sorted { $0.number < $1.number }
        let winners = teams.filter { team in
            champions.contains { normalizedTeamNumber($0) == normalizedTeamNumber(team.number) }
        }
        return awards.map { award in
            var copy = award
            switch award.id {
            case "excellence":
                copy.eligible = excellence.map { row($0, "Qual \(qualificationPlace(team: $0, pool: teams)) · skills \($0.skillsTotal) · auto \($0.programming ?? 0)") }
                copy.eligibleNote = excellence.isEmpty
                    ? "Nobody at this event is inside all three Excellence score gates yet."
                    : "These teams are inside the Excellence score gates. Judges still have to accept the notebook and interview."
            case "skills-champion":
                copy.eligible = leaders.map { row($0, "\($0.skillsTotal) combined skills") }
                copy.eligibleNote = leaders.isEmpty
                    ? "Nobody has a skills score yet."
                    : (leaders.count == 1 ? "This team has the highest combined skills score." : "These teams are tied for the highest skills score.")
            case "tournament":
                copy.eligible = winners.map { row($0, "Won the finals") }
                copy.eligibleNote = winners.isEmpty ? "The finals are not finished, so nobody is the champion yet." : "This alliance won the elimination finals."
            case "think":
                let listed = teams.filter { ($0.programming ?? 0) > 0 }.sorted { ($0.programming ?? 0) > ($1.programming ?? 0) }
                copy.eligible = listed.map { row($0, "Auto \($0.programming ?? 0)") }
                copy.eligibleNote = "These teams have an autonomous score above zero. Judges still pick the Think Award."
            case "amaze":
                let listed = teams.filter { $0.wins > 0 && ($0.driver ?? 0) > 0 && ($0.programming ?? 0) > 0 }
                    .sorted { $0.rank > 0 && $1.rank > 0 ? $0.rank < $1.rank : $0.wins > $1.wins }
                copy.eligible = listed.map { row($0, "\($0.record) · driver \($0.driver ?? 0) · auto \($0.programming ?? 0)") }
                copy.eligibleNote = "These teams have a win plus driver and autonomous scores. Judges still pick the Amaze Award."
            case "states":
                copy.eligible = pathwayRows(excellence: excellence, leaders: leaders, winners: winners, teams: teams)
                copy.eligibleNote = "Rankings can name the Excellence score group, the skills leader, and the finals winners. Design and the other judged spots are not in the download."
            case "worlds":
                copy.eligible = pathwayRows(excellence: excellence, leaders: leaders, winners: winners, teams: teams)
                copy.eligibleNote = "These finishes qualify for Worlds at the Region 2 championship or a signature event. A regular local event does not hand out Worlds spots."
            default:
                copy.eligibleNote = "Judges pick this award at the event. Rankings do not show who is eligible."
            }
            return copy
        }
    }

    private static func pathwayRows(excellence: [TeamReport], leaders: [TeamReport], winners: [TeamReport], teams: [TeamReport]) -> [EligibleTeam] {
        var lines: [String: (TeamReport, [String])] = [:]
        func add(_ team: TeamReport, _ reason: String) {
            let key = normalizedTeamNumber(team.number)
            var entry = lines[key] ?? (team, [])
            if !entry.1.contains(reason) { entry.1.append(reason) }
            lines[key] = entry
        }
        excellence.forEach { add($0, "Excellence scores") }
        leaders.forEach { add($0, "Skills leader") }
        winners.forEach { add($0, "Finals winner") }
        return lines.values
            .sorted { qualificationPlace(team: $0.0, pool: teams) < qualificationPlace(team: $1.0, pool: teams) }
            .map { row($0.0, $0.1.joined(separator: " · ")) }
    }

    private static func passesExcellence(_ team: TeamReport, teams: [TeamReport], levels: [String: String]) -> Bool {
        let pool = excellenceScope(team: team, teams: teams, levels: levels).teams
        let need = cutoff(fieldSize: pool.count)
        guard need > 0, team.rank > 0 else { return false }
        let auto = team.programming ?? 0
        let skillsPlace = place(of: team.skillsTotal, in: pool.map(\.skillsTotal))
        let autoPlace = place(of: auto, in: pool.map { $0.programming ?? 0 })
        return qualificationPlace(team: team, pool: pool) <= need && skillsPlace <= need && auto > 0 && autoPlace <= need
    }

    private static func row(_ team: TeamReport, _ line: String) -> EligibleTeam {
        EligibleTeam(number: team.number, name: team.name, line: line)
    }

    private static func more(_ count: Int, _ unit: String) -> String {
        count == 1 ? "1 more \(unit)" : "\(count) more \(unit)s"
    }

    private static func waitingAwards() -> [AwardCard] {
        pathwayCards() + [
            ("excellence", "Excellence"),
            ("skills-champion", "Robot Skills Champion"),
            ("tournament", "Tournament Champion"),
            ("design", "Design"),
            ("innovate", "Innovate"),
            ("think", "Think"),
            ("amaze", "Amaze"),
            ("build", "Build"),
            ("create", "Create"),
            ("judges", "Judges"),
            ("inspire", "Inspire"),
            ("sportsmanship", "Sportsmanship"),
            ("energy", "Energy")
        ].map { id, name in
            AwardCard(
                id: id,
                name: name,
                qualified: false,
                criteria: [
                    AwardGate(
                        id: "\(id)-wait",
                        name: "Live results",
                        met: false,
                        pointsLine: "Not qualified yet",
                        detail: "Tap Refresh after 95070D’s event loads."
                    )
                ]
            )
        }
    }

    private static func liveAwards(
        team: TeamReport,
        field: Int,
        need: Int,
        skillsPlace: Int,
        autoScore: Int,
        autoPlace: Int,
        qualMet: Bool,
        skillsMet: Bool,
        autoMet: Bool,
        gates: [AwardGate],
        teams: [TeamReport],
        champions: [String]
    ) -> [AwardCard] {
        let leader = teams.map(\.skillsTotal).max() ?? 0
        let skillsBehind = max(0, leader - team.skillsTotal)
        let leaders = teams.filter { $0.skillsTotal == leader && leader > 0 }
        let skillsChampion = team.skillsTotal > 0 && team.skillsTotal == leader && leaders.count == 1
        let wonFinals = champions.contains { normalizedTeamNumber($0) == normalizedTeamNumber(team.number) }
        var excellence = gates
        excellence.append(contentsOf: [
            eventGate("notebook", "Fully Developed Engineering Notebook"),
            eventGate("interview", "Team interview"),
            eventGate("other", "Candidate for another judged award"),
            eventGate("conduct", "Student-centered work and sportsmanship")
        ])

        return pathwayCards() + [
            AwardCard(id: "excellence", name: "Excellence", qualified: qualMet && skillsMet && autoMet, criteria: excellence),
            AwardCard(
                id: "skills-champion",
                name: "Robot Skills Champion",
                qualified: skillsChampion,
                criteria: [
                    AwardGate(
                        id: "skills-lead",
                        name: "Highest combined skills score",
                        met: skillsChampion,
                        pointsLine: skillsChampion ? "0 more points" : (team.skillsTotal == leader && leader > 0 ? "1 more point" : more(max(skillsBehind, 1), "point")),
                        detail: skillsChampion ? "Leading at \(team.skillsTotal)." : (team.skillsTotal == leader && leader > 0 ? "Tied at \(leader). One more point takes the lead alone." : "The leader has \(leader). You have \(team.skillsTotal). Rank \(skillsPlace) of \(field).")
                    )
                ]
            ),
            AwardCard(
                id: "tournament",
                name: "Tournament Champion",
                qualified: wonFinals,
                criteria: [
                    AwardGate(
                        id: "finals",
                        name: "Win the elimination finals",
                        met: wonFinals,
                        pointsLine: wonFinals ? "Finals won" : "Finals not won",
                        detail: wonFinals ? "This alliance won the finals." : "This stays not qualified until the finals series is over."
                    )
                ]
            ),
            judged("design", "Design", [
                "Fully Developed Engineering Notebook",
                "Interview shows the design from the first idea through the robot",
                "Notebook, interview, and robot match"
            ]),
            judged("innovate", "Innovate", [
                "A unique design or strategy used on the robot at this event",
                "Documented from the idea through the robot",
                "Meets the Design Award criteria"
            ]),
            AwardCard(
                id: "think",
                name: "Think",
                qualified: autoScore > 0,
                criteria: [
                    AwardGate(
                        id: "think-auto",
                        name: "Autonomous Coding Skills above zero",
                        met: autoScore > 0,
                        pointsLine: autoScore > 0 ? "0 more points" : "1 more point",
                        detail: "You have \(autoScore). Rank \(autoPlace) of \(field)."
                    ),
                    eventGate("think-code", "Students wrote the code and can explain it")
                ]
            ),
            AwardCard(
                id: "amaze",
                name: "Amaze",
                qualified: team.wins > 0 && (team.driver ?? 0) > 0 && autoScore > 0,
                criteria: [
                    AwardGate(
                        id: "amaze-wins",
                        name: "Qualification wins",
                        met: team.wins > 0,
                        pointsLine: team.wins > 0 ? "\(team.wins) wins" : "Need a win",
                        detail: "Record \(team.record)."
                    ),
                    AwardGate(
                        id: "amaze-driver",
                        name: "Driver skills",
                        met: (team.driver ?? 0) > 0,
                        pointsLine: (team.driver ?? 0) > 0 ? "\(team.driver ?? 0) points" : "No driver score",
                        detail: "A skipped driver run counts as zero."
                    ),
                    AwardGate(
                        id: "amaze-auto",
                        name: "Autonomous skills",
                        met: autoScore > 0,
                        pointsLine: autoScore > 0 ? "\(autoScore) points" : "No autonomous score",
                        detail: "Programming skills are \(autoScore)."
                    )
                ]
            ),
            judged("build", "Build", [
                "Robot is durable, safe, and carefully built",
                "Students can explain the construction"
            ]),
            judged("create", "Create", [
                "A creative solution to a game problem",
                "Students can explain how it was developed"
            ]),
            judged("judges", "Judges", [
                "Team completes an interview",
                "Judges see effort or teamwork worth recognizing"
            ]),
            judged("inspire", "Inspire", [
                "Student-led passion and professionalism",
                "The team makes the event better for other people"
            ]),
            judged("sportsmanship", "Sportsmanship", [
                "Nominated for respectful, fair conduct all day"
            ]),
            judged("energy", "Energy", [
                "Nominated for enthusiasm that helps the event"
            ])
        ]
    }

    private static func pathwayCards() -> [AwardCard] {
        [
            AwardCard(
                id: "states",
                name: "States",
                qualified: false,
                criteria: [
                    path("states-award", "Win a qualifying award in California Region 2", "Next round", "That championship is the middle school Region 2 event. Spots go in this order: Excellence, Tournament Champions, Design, Robot Skills Champion, Innovate, Tournament Finalists, then Think, Amaze, Build, and Create. The event page says how far down the list it goes."),
                    path("states-skills", "Region 2 middle school skills list", "If spots remain", "If awards do not fill the championship, invites go down the World Skills Standings for this region and grade after the last qualifying event is posted."),
                    path("states-wait", "Waitlist", "If a team declines", "Spots left after the skills invites can be filled from the waitlist.")
                ]
            ),
            AwardCard(
                id: "worlds",
                name: "Worlds",
                qualified: false,
                criteria: [
                    path("worlds-states", "Earn one of the Region 2 Worlds spots", "8 spots so far", "At the Region 2 middle school championship those 8 are Excellence, both Tournament Champions, Design, Robot Skills Champion, Innovate, and both Tournament Finalists. More North America spots may be added on January 15, 2027."),
                    path("worlds-signature", "Win Excellence or Tournament Champions at a signature event", "Direct to Worlds", "The UC Berkeley middle school signature event on November 22–23, 2026 gives 3 Worlds spots: both Tournament Champions and Excellence."),
                    path("worlds-double", "Be next on skills if a team wins two spots", "Extra spot", "When one team earns two qualifying awards at the same event, the extra spot goes to the next middle school team on that event’s skills list who is not already qualified."),
                    path("worlds-never", "Judges, Inspire, Energy, and Sportsmanship", "Do not qualify", "Those four awards never move a team on to states or Worlds.")
                ]
            )
        ]
    }

    private static func path(_ id: String, _ name: String, _ line: String, _ detail: String) -> AwardGate {
        AwardGate(id: id, name: name, met: false, pointsLine: line, detail: detail)
    }

    private static func eventGate(_ id: String, _ name: String) -> AwardGate {
        AwardGate(id: id, name: name, met: false, pointsLine: "Checked at the event", detail: "Rankings do not show this. It stays open until the judges see it.")
    }

    private static func judged(_ id: String, _ name: String, _ items: [String]) -> AwardCard {
        AwardCard(
            id: id,
            name: name,
            qualified: false,
            criteria: items.map { item in
                AwardGate(id: "\(id)-\(item)", name: item, met: false, pointsLine: "Checked at the event", detail: "Rankings do not show this, so this award stays not qualified here.")
            }
        )
    }
}
