import Foundation

enum APIError: LocalizedError {
    case missingToken
    case unauthorized
    case message(String)

    var errorDescription: String? {
        switch self {
        case .missingToken:
            return "Live rankings are off. Use Scout to record teams on this phone."
        case .unauthorized:
            return "That RobotEvents token was rejected. Paste a new one from events.vex.com/api/v2."
        case .message(let text):
            return text
        }
    }
}

struct RobotEventsAPI {
    var token: String

    func programs() async throws -> [ProgramChoice] {
        let rows: [IDBox] = try await collect("/programs", query: [URLQueryItem(name: "per_page", value: "100")])
        return rows.map { ProgramChoice(id: $0.id, name: $0.name, code: $0.code ?? "") }
    }

    func currentSeason(programID: Int) async throws -> SeasonInfo {
        let rows: [RESeason] = try await collect("/seasons", query: [
            URLQueryItem(name: "program[]", value: String(programID)),
            URLQueryItem(name: "per_page", value: "100"),
        ])
        let now = Date()
        let dated = rows.compactMap { season -> (RESeason, Date, Date)? in
            guard let start = parseDate(season.start), let end = parseDate(season.end) else { return nil }
            return (season, start, end)
        }
        let chosen = dated.first { $0.1 <= now && now <= $0.2 }
            ?? dated.filter { $0.1 <= now }.max { $0.1 < $1.1 }
            ?? dated.max { $0.1 < $1.1 }
        guard let season = chosen?.0 ?? rows.first else {
            throw APIError.message("No season was found for this program.")
        }
        return SeasonInfo(id: season.id, name: season.name)
    }

    func findTeam(number: String, programID: Int) async throws -> FoundTeam? {
        let wanted = normalizedTeamNumber(number)
        guard !wanted.isEmpty else { return nil }
        let rows: [RETeam] = try await collect("/teams", query: [
            URLQueryItem(name: "number[]", value: wanted),
            URLQueryItem(name: "program[]", value: String(programID)),
            URLQueryItem(name: "per_page", value: "25"),
        ])
        guard let team = rows.first(where: { normalizedTeamNumber($0.number) == wanted }) ?? rows.first else {
            return nil
        }
        return FoundTeam(id: team.id, number: team.number, name: team.teamName, organization: team.organization)
    }

    func events(teamID: Int, seasonID: Int) async throws -> [EventSummary] {
        let rows: [REEvent] = try await collect("/teams/\(teamID)/events", query: [
            URLQueryItem(name: "season[]", value: String(seasonID)),
            URLQueryItem(name: "per_page", value: "100"),
        ])
        return rows.map(Self.summary)
    }

    func event(sku: String) async throws -> EventSummary? {
        let cleaned = sku.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !cleaned.isEmpty else { return nil }
        let rows: [REEvent] = try await collect("/events", query: [
            URLQueryItem(name: "sku[]", value: cleaned),
            URLQueryItem(name: "per_page", value: "10"),
        ])
        let match = rows.first { $0.sku.caseInsensitiveCompare(cleaned) == .orderedSame } ?? rows.first
        return match.map(Self.summary)
    }

    func report(event: EventSummary, divisionID: Int?) async throws -> EventReport {
        let divisions = event.divisions.sorted { $0.order < $1.order }
        guard let division = divisions.first(where: { $0.id == divisionID }) ?? divisions.first else {
            return EventReport(
                eventID: event.id,
                eventName: event.name,
                sku: event.sku,
                divisionID: 0,
                divisionName: "",
                divisions: [],
                ongoing: event.isLive,
                updated: Date(),
                teams: [],
                note: "This event has no division posted yet."
            )
        }

        async let rankingRows: [RERanking] = collect(
            "/events/\(event.id)/divisions/\(division.id)/rankings",
            query: [URLQueryItem(name: "per_page", value: "100")]
        )
        async let skillRows: [RESkill] = collect(
            "/events/\(event.id)/skills",
            query: [URLQueryItem(name: "per_page", value: "100")]
        )
        async let teamRows: [RETeam] = collect(
            "/events/\(event.id)/teams",
            query: [URLQueryItem(name: "per_page", value: "100")]
        )
        async let matchRows: [REMatch] = collect(
            "/events/\(event.id)/divisions/\(division.id)/matches",
            query: [URLQueryItem(name: "per_page", value: "100")]
        )

        let rankings = try await rankingRows
        let skills = try await skillRows
        let teams = try await teamRows
        let matches = try await matchRows
        return buildReport(event: event, division: division, divisions: divisions, rankings: rankings, skills: skills, teams: teams, matches: matches)
    }

    private func buildReport(
        event: EventSummary,
        division: DivisionInfo,
        divisions: [DivisionInfo],
        rankings: [RERanking],
        skills: [RESkill],
        teams: [RETeam],
        matches: [REMatch]
    ) -> EventReport {
        var roster: [Int: RETeam] = [:]
        for team in teams { roster[team.id] = team }

        var skillBook: [Int: SkillBest] = [:]
        for skill in skills {
            var best = skillBook[skill.teamID] ?? SkillBest()
            let type = skill.type.lowercased()
            if type == "driver" {
                if best.driver == nil || skill.score >= (best.driver ?? 0) {
                    best.driver = skill.score
                    best.driverRank = skill.rank
                }
            } else if type == "programming" {
                if best.programming == nil || skill.score >= (best.programming ?? 0) {
                    best.programming = skill.score
                    best.programmingRank = skill.rank
                }
            }
            skillBook[skill.teamID] = best
        }

        var numbers: [Int: String] = [:]
        for team in teams { numbers[team.id] = team.number }
        for ranking in rankings where numbers[ranking.teamID] == nil {
            numbers[ranking.teamID] = ranking.teamLabel
        }

        let powerMatches: [PowerMatch] = matches.compactMap { match in
            guard match.scored, match.round == 2 else { return nil }
            let alliances = match.alliances.map { alliance in
                PowerAlliance(
                    teamIDs: alliance.teams.filter { !$0.sitting }.map(\.teamID),
                    score: alliance.score
                )
            }
            return PowerMatch(alliances: alliances)
        }
        let opr = ScoutMath.offensivePower(powerMatches)

        let source: [RawTeam]
        if rankings.isEmpty {
            let ids = Set(skillBook.keys).union(roster.keys)
            source = ids.map { id in
                rawTeam(id: id, ranking: nil, roster: roster, skills: skillBook, numbers: numbers, matches: matches)
            }
        } else {
            source = rankings.map { ranking in
                rawTeam(id: ranking.teamID, ranking: ranking, roster: roster, skills: skillBook, numbers: numbers, matches: matches)
            }
        }

        let rated = ScoutMath.rate(source, opr: opr)
        let note = rated.isEmpty
            ? "No public results for this event yet."
            : "Percents compare the \(rated.count) teams in this division only."
        return EventReport(
            eventID: event.id,
            eventName: event.name,
            sku: event.sku,
            divisionID: division.id,
            divisionName: division.name,
            divisions: divisions,
            ongoing: event.isLive,
            updated: Date(),
            teams: rated,
            note: note,
            championNumbers: championNumbers(matches: matches, numbers: numbers, eventFinished: !event.isLive),
            schoolLevels: schoolLevels(teams)
        )
    }

    private func rawTeam(
        id: Int,
        ranking: RERanking?,
        roster: [Int: RETeam],
        skills: [Int: SkillBest],
        numbers: [Int: String],
        matches: [REMatch]
    ) -> RawTeam {
        let team = roster[id]
        let skill = skills[id]
        let number = team?.number ?? numbers[id] ?? "\(id)"
        let name = team?.teamName.trimmingCharacters(in: .whitespacesAndNewlines)
        return RawTeam(
            id: id,
            number: number,
            name: (name?.isEmpty == false ? name! : number),
            organization: team?.organization ?? "",
            rank: ranking?.rank ?? 0,
            wins: ranking?.wins ?? 0,
            losses: ranking?.losses ?? 0,
            ties: ranking?.ties ?? 0,
            wp: ranking?.wp ?? 0,
            ap: ranking?.ap ?? 0,
            sp: ranking?.sp ?? 0,
            highScore: ranking?.highScore ?? 0,
            averagePoints: ranking?.averagePoints ?? 0,
            driver: skill?.driver,
            programming: skill?.programming,
            driverRank: skill?.driverRank,
            programmingRank: skill?.programmingRank,
            recent: recentMatches(for: id, matches: matches, numbers: numbers)
        )
    }

    private func schoolLevels(_ teams: [RETeam]) -> [String: String] {
        var levels: [String: String] = [:]
        for team in teams {
            let number = normalizedTeamNumber(team.number)
            let grade = team.grade.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !number.isEmpty, !grade.isEmpty else { continue }
            levels[number] = grade
        }
        return levels
    }

    private func championNumbers(matches: [REMatch], numbers: [Int: String], eventFinished: Bool) -> [String] {
        let elims = matches.filter { $0.scored && $0.round >= 3 }
        guard let finalRound = elims.map(\.round).max() else { return [] }
        let stillPlaying = matches.contains { $0.round == finalRound && !$0.scored }
        if stillPlaying { return [] }

        var wins: [String: Int] = [:]
        var labels: [String: [String]] = [:]
        for match in elims where match.round == finalRound {
            let scores = match.alliances.map(\.score)
            guard let best = scores.max(), scores.filter({ $0 == best }).count == 1,
                  let winner = match.alliances.first(where: { $0.score == best }) else { continue }
            let ids = winner.teams.filter { !$0.sitting }.map(\.teamID).sorted()
            guard !ids.isEmpty else { continue }
            let key = ids.map(String.init).joined(separator: "-")
            wins[key, default: 0] += 1
            labels[key] = ids.compactMap { numbers[$0] }
        }
        guard let bestWins = wins.values.max(),
              wins.filter({ $0.value == bestWins }).count == 1,
              let key = wins.first(where: { $0.value == bestWins })?.key else { return [] }
        let otherBest = wins.filter { $0.key != key }.values.max() ?? 0
        let clinched = bestWins >= 2 || (eventFinished && bestWins >= 1)
        guard clinched, bestWins > otherBest else { return [] }
        return (labels[key] ?? []).map(normalizedTeamNumber)
    }

    private func recentMatches(for teamID: Int, matches: [REMatch], numbers: [Int: String]) -> [RecentMatch] {
        let played = matches
            .filter { $0.scored && $0.round != 1 }
            .sorted { lhs, rhs in
                let left = lhs.round * 10_000 + lhs.instance * 100 + lhs.matchnum
                let right = rhs.round * 10_000 + rhs.instance * 100 + rhs.matchnum
                return left > right
            }
        var rows: [RecentMatch] = []
        for match in played {
            guard let ours = match.alliances.first(where: { alliance in
                alliance.teams.contains { $0.teamID == teamID && !$0.sitting }
            }) else { continue }
            guard let theirs = match.alliances.first(where: { $0.color != ours.color }) ?? match.alliances.first(where: { $0.score != ours.score || $0.color != ours.color }) else {
                continue
            }
            let partners = ours.teams.filter { !$0.sitting && $0.teamID != teamID }.map { numbers[$0.teamID] ?? "\($0.teamID)" }
            let opponents = theirs.teams.filter { !$0.sitting }.map { numbers[$0.teamID] ?? "\($0.teamID)" }
            let result: String
            if ours.score > theirs.score {
                result = "W"
            } else if ours.score < theirs.score {
                result = "L"
            } else {
                result = "T"
            }
            let label = match.name.isEmpty ? "Match \(match.matchnum)" : match.name
            var detail = ""
            if !partners.isEmpty { detail += "with \(partners.joined(separator: " "))" }
            if !opponents.isEmpty {
                if !detail.isEmpty { detail += " " }
                detail += "vs \(opponents.joined(separator: " "))"
            }
            rows.append(RecentMatch(
                id: "\(match.round)-\(match.instance)-\(match.matchnum)",
                label: label,
                result: result,
                scoreline: "\(ours.score)–\(theirs.score)",
                detail: detail,
                color: ours.color
            ))
            if rows.count == 5 { break }
        }
        return rows
    }

    private static func summary(_ event: REEvent) -> EventSummary {
        EventSummary(
            id: event.id,
            sku: event.sku,
            name: event.name,
            start: parseDate(event.start),
            end: parseDate(event.end),
            city: event.city,
            region: event.region,
            ongoing: event.ongoing,
            divisions: event.divisions.sorted { $0.order < $1.order }
        )
    }

    private func collect<T: Decodable>(_ path: String, query: [URLQueryItem]) async throws -> [T] {
        var items: [T] = []
        var next: URL? = try makeURL(path: path, query: query)
        var pages = 0
        while let url = next {
            pages += 1
            if pages > 12 { break }
            let page: Page<T> = try await fetch(url)
            items.append(contentsOf: page.data)
            if let link = page.next, let url = URL(string: link) {
                next = url
            } else {
                next = nil
            }
        }
        return items
    }

    private func fetch<T: Decodable>(_ url: URL) async throws -> T {
        var request = URLRequest(url: url, timeoutInterval: 30)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("VexWatcher/1.0", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        if status == 401 { throw APIError.unauthorized }
        guard (200...299).contains(status) else {
            let message = (try? JSONDecoder().decode(APIMessage.self, from: data))?.message
            throw APIError.message(message ?? "RobotEvents returned \(status).")
        }
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch let error as DecodingError {
            throw APIError.message("Couldn't read RobotEvents data: \(error.vexSummary)")
        } catch {
            throw APIError.message("Couldn't read RobotEvents data.")
        }
    }

    private func makeURL(path: String, query: [URLQueryItem]) throws -> URL {
        guard var components = URLComponents(string: "https://events.vex.com/api/v2" + path) else {
            throw APIError.message("Bad RobotEvents address.")
        }
        if !query.isEmpty { components.queryItems = query }
        guard let url = components.url else { throw APIError.message("Bad RobotEvents address.") }
        return url
    }
}

struct FoundTeam {
    var id: Int
    var number: String
    var name: String
    var organization: String
}

private struct SkillBest {
    var driver: Int?
    var driverRank: Int?
    var programming: Int?
    var programmingRank: Int?
}

private struct APIMessage: Decodable {
    var message: String?
}

private struct Page<T: Decodable>: Decodable {
    var data: [T]
    var next: String?

    struct Meta: Decodable {
        var nextPageURL: String?
        enum CodingKeys: String, CodingKey { case nextPageURL = "next_page_url" }
    }

    enum CodingKeys: String, CodingKey { case data, meta }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        data = try container.decodeIfPresent([T].self, forKey: .data) ?? []
        next = try container.decodeIfPresent(Meta.self, forKey: .meta)?.nextPageURL
    }
}

private struct IDBox: Decodable {
    var id: Int
    var name: String
    var code: String?

    enum CodingKeys: String, CodingKey { case id, name, code }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(FlexInt.self, forKey: .id)?.value ?? 0
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        code = try container.decodeIfPresent(String.self, forKey: .code)
    }
}

private struct RESeason: Decodable {
    var id: Int
    var name: String
    var start: String
    var end: String

    enum CodingKeys: String, CodingKey { case id, name, start, end }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(FlexInt.self, forKey: .id)?.value ?? 0
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? "Season"
        start = try container.decodeIfPresent(String.self, forKey: .start) ?? ""
        end = try container.decodeIfPresent(String.self, forKey: .end) ?? ""
    }
}

private struct REEvent: Decodable {
    var id: Int
    var sku: String
    var name: String
    var start: String
    var end: String
    var ongoing: Bool
    var city: String
    var region: String
    var divisions: [DivisionInfo]

    enum CodingKeys: String, CodingKey {
        case id, sku, name, start, end, ongoing, location, divisions
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(FlexInt.self, forKey: .id)?.value ?? 0
        sku = try container.decodeIfPresent(String.self, forKey: .sku) ?? ""
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? "Event"
        start = try container.decodeIfPresent(String.self, forKey: .start) ?? ""
        end = try container.decodeIfPresent(String.self, forKey: .end) ?? ""
        ongoing = try container.decodeIfPresent(Bool.self, forKey: .ongoing) ?? false
        if let location = try? container.decode(RELocation.self, forKey: .location) {
            city = location.city ?? ""
            region = location.region ?? ""
        } else {
            city = ""
            region = ""
        }
        let decoded = (try? container.decode([REDivision].self, forKey: .divisions)) ?? []
        divisions = decoded.map { DivisionInfo(id: $0.id, name: $0.name, order: $0.order) }
    }
}

private struct RELocation: Decodable {
    var city: String?
    var region: String?
}

private struct REDivision: Decodable {
    var id: Int
    var name: String
    var order: Int

    enum CodingKeys: String, CodingKey { case id, name, order }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(FlexInt.self, forKey: .id)?.value ?? 0
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? "Division"
        order = try container.decodeIfPresent(FlexInt.self, forKey: .order)?.value ?? 0
    }
}

private struct RETeam: Decodable {
    var id: Int
    var number: String
    var teamName: String
    var organization: String
    var grade: String

    enum CodingKeys: String, CodingKey {
        case id, number, organization, grade
        case teamName = "team_name"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(FlexInt.self, forKey: .id)?.value ?? 0
        number = try container.decodeIfPresent(String.self, forKey: .number) ?? ""
        teamName = try container.decodeIfPresent(String.self, forKey: .teamName) ?? ""
        organization = try container.decodeIfPresent(String.self, forKey: .organization) ?? ""
        grade = try container.decodeIfPresent(String.self, forKey: .grade) ?? ""
    }
}

private struct RERanking: Decodable {
    var rank: Int
    var teamID: Int
    var teamLabel: String
    var wins: Int
    var losses: Int
    var ties: Int
    var wp: Int
    var ap: Int
    var sp: Int
    var highScore: Int
    var averagePoints: Double

    enum CodingKeys: String, CodingKey {
        case rank, team, wins, losses, ties, wp, ap, sp
        case highScore = "high_score"
        case averagePoints = "average_points"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        rank = try container.decodeIfPresent(FlexInt.self, forKey: .rank)?.value ?? 0
        wins = try container.decodeIfPresent(FlexInt.self, forKey: .wins)?.value ?? 0
        losses = try container.decodeIfPresent(FlexInt.self, forKey: .losses)?.value ?? 0
        ties = try container.decodeIfPresent(FlexInt.self, forKey: .ties)?.value ?? 0
        wp = try container.decodeIfPresent(FlexInt.self, forKey: .wp)?.value ?? 0
        ap = try container.decodeIfPresent(FlexInt.self, forKey: .ap)?.value ?? 0
        sp = try container.decodeIfPresent(FlexInt.self, forKey: .sp)?.value ?? 0
        highScore = try container.decodeIfPresent(FlexInt.self, forKey: .highScore)?.value ?? 0
        averagePoints = try container.decodeIfPresent(FlexDouble.self, forKey: .averagePoints)?.value ?? 0
        let team = try container.decodeIfPresent(IDBox.self, forKey: .team)
        teamID = team?.id ?? 0
        let code = team?.code ?? ""
        let name = team?.name ?? ""
        if code.range(of: #"\d"#, options: .regularExpression) != nil {
            teamLabel = code
        } else if name.range(of: #"\d"#, options: .regularExpression) != nil {
            teamLabel = name
        } else {
            teamLabel = code.isEmpty ? name : code
        }
    }
}

private struct RESkill: Decodable {
    var teamID: Int
    var type: String
    var score: Int
    var rank: Int

    enum CodingKeys: String, CodingKey { case team, type, score, rank }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        teamID = try container.decodeIfPresent(IDBox.self, forKey: .team)?.id ?? 0
        type = try container.decodeIfPresent(String.self, forKey: .type) ?? ""
        score = try container.decodeIfPresent(FlexInt.self, forKey: .score)?.value ?? 0
        rank = try container.decodeIfPresent(FlexInt.self, forKey: .rank)?.value ?? 0
    }
}

private struct REMatch: Decodable {
    var round: Int
    var instance: Int
    var matchnum: Int
    var name: String
    var scored: Bool
    var alliances: [REAlliance]

    enum CodingKeys: String, CodingKey {
        case round, instance, matchnum, name, scored, alliances
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        round = try container.decodeIfPresent(FlexInt.self, forKey: .round)?.value ?? 0
        instance = try container.decodeIfPresent(FlexInt.self, forKey: .instance)?.value ?? 0
        matchnum = try container.decodeIfPresent(FlexInt.self, forKey: .matchnum)?.value ?? 0
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        scored = try container.decodeIfPresent(Bool.self, forKey: .scored) ?? false
        alliances = try container.decodeIfPresent([REAlliance].self, forKey: .alliances) ?? []
    }
}

private struct REAlliance: Decodable {
    var color: String
    var score: Int
    var teams: [REAllianceTeam]

    enum CodingKeys: String, CodingKey { case color, score, teams }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        color = (try container.decodeIfPresent(String.self, forKey: .color) ?? "").lowercased()
        score = try container.decodeIfPresent(FlexInt.self, forKey: .score)?.value ?? 0
        teams = try container.decodeIfPresent([REAllianceTeam].self, forKey: .teams) ?? []
    }
}

private struct REAllianceTeam: Decodable {
    var teamID: Int
    var sitting: Bool

    enum CodingKeys: String, CodingKey { case team, sitting }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        teamID = try container.decodeIfPresent(IDBox.self, forKey: .team)?.id ?? 0
        sitting = try container.decodeIfPresent(Bool.self, forKey: .sitting) ?? false
    }
}

private struct FlexInt: Decodable {
    var value: Int
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = Int(double)
        } else if let string = try? container.decode(String.self), let int = Int(string) {
            value = int
        } else {
            value = 0
        }
    }
}

private struct FlexDouble: Decodable {
    var value: Double
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let double = try? container.decode(Double.self) {
            value = double
        } else if let int = try? container.decode(Int.self) {
            value = Double(int)
        } else if let string = try? container.decode(String.self), let double = Double(string) {
            value = double
        } else {
            value = 0
        }
    }
}

private func parseDate(_ string: String) -> Date? {
    let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return nil }
    let iso = ISO8601DateFormatter()
    iso.formatOptions = [.withInternetDateTime]
    if let date = iso.date(from: trimmed) { return date }
    iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let date = iso.date(from: trimmed) { return date }
    let day = DateFormatter()
    day.calendar = Calendar(identifier: .gregorian)
    day.locale = Locale(identifier: "en_US_POSIX")
    day.timeZone = TimeZone(secondsFromGMT: 0)
    day.dateFormat = "yyyy-MM-dd"
    return day.date(from: String(trimmed.prefix(10)))
}

private extension DecodingError {
    var vexSummary: String {
        switch self {
        case .keyNotFound(let key, let context):
            return "missing \(context.codingPath.map(\.stringValue).joined(separator: ".")) \(key.stringValue)"
        case .typeMismatch(_, let context):
            return "unexpected type at \(context.codingPath.map(\.stringValue).joined(separator: "."))"
        case .valueNotFound(_, let context):
            return "empty value at \(context.codingPath.map(\.stringValue).joined(separator: "."))"
        case .dataCorrupted(let context):
            return context.debugDescription
        @unknown default:
            return "unexpected data"
        }
    }
}
