import Foundation

struct ProgramChoice: Codable, Identifiable, Hashable {
    var id: Int
    var name: String
    var code: String
}

struct DivisionInfo: Codable, Identifiable, Hashable {
    var id: Int
    var name: String
    var order: Int
}

struct EventSummary: Codable, Identifiable, Hashable {
    var id: Int
    var sku: String
    var name: String
    var start: Date?
    var end: Date?
    var city: String
    var region: String
    var ongoing: Bool
    var divisions: [DivisionInfo]

    var isLive: Bool {
        let now = Date()
        if let end, now > end.addingTimeInterval(24 * 60 * 60) { return false }
        if ongoing { return true }
        guard let start, let end else { return false }
        return start <= now && now <= end.addingTimeInterval(24 * 60 * 60)
    }

    var place: String {
        [city, region].filter { !$0.isEmpty }.joined(separator: ", ")
    }

    var when: String {
        switch (start, end) {
        case let (start?, end?):
            let a = start.formatted(.dateTime.month(.abbreviated).day())
            let b = end.formatted(.dateTime.month(.abbreviated).day())
            return a == b ? a : "\(a)–\(b)"
        case let (start?, nil):
            return start.formatted(.dateTime.month(.abbreviated).day())
        default:
            return ""
        }
    }
}

struct ScoreComponent: Codable, Equatable, Identifiable {
    var name: String
    var percent: Int
    var id: String { name }
}

struct RecentMatch: Codable, Equatable, Identifiable {
    var id: String
    var label: String
    var result: String
    var scoreline: String
    var detail: String
    var color: String

    init(id: String, label: String, result: String, scoreline: String, detail: String, color: String = "") {
        self.id = id
        self.label = label
        self.result = result
        self.scoreline = scoreline
        self.detail = detail
        self.color = color
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        label = try container.decode(String.self, forKey: .label)
        result = try container.decode(String.self, forKey: .result)
        scoreline = try container.decode(String.self, forKey: .scoreline)
        detail = try container.decode(String.self, forKey: .detail)
        color = try container.decodeIfPresent(String.self, forKey: .color) ?? ""
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(label, forKey: .label)
        try container.encode(result, forKey: .result)
        try container.encode(scoreline, forKey: .scoreline)
        try container.encode(detail, forKey: .detail)
        try container.encode(color, forKey: .color)
    }

    private enum CodingKeys: String, CodingKey {
        case id, label, result, scoreline, detail, color
    }
}

struct TeamReport: Codable, Identifiable, Equatable {
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
    var opr: Double?
    var overall: Int
    var grade: String
    var abilities: [String]
    var components: [ScoreComponent]
    var recent: [RecentMatch]

    var record: String { "\(wins)-\(losses)-\(ties)" }

    var placeLabel: String {
        rank > 0 ? rank.ordinal : "Unranked"
    }

    var skillsTotal: Int {
        (driver ?? 0) + (programming ?? 0)
    }
}

struct BracketSide: Codable, Equatable, Identifiable {
    var color: String
    var teams: [String]
    var score: Int
    var winner: Bool
    var id: String { "\(color)-\(teams.joined(separator: "-"))-\(score)" }
}

struct BracketMatch: Codable, Equatable, Identifiable {
    var id: String
    var round: Int
    var instance: Int
    var matchnum: Int
    var name: String
    var scored: Bool
    var sides: [BracketSide]
}

struct EventAward: Codable, Equatable, Identifiable {
    var id: Int
    var title: String
    var order: Int
    var winners: [String]
    var qualifies: Bool

    init(id: Int, title: String, order: Int, winners: [String], qualifies: Bool = false) {
        self.id = id
        self.title = title
        self.order = order
        self.winners = winners
        self.qualifies = qualifies
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(Int.self, forKey: .id) ?? 0
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
        order = try container.decodeIfPresent(Int.self, forKey: .order) ?? 0
        winners = try container.decodeIfPresent([String].self, forKey: .winners) ?? []
        qualifies = try container.decodeIfPresent(Bool.self, forKey: .qualifies) ?? false
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(order, forKey: .order)
        try container.encode(winners, forKey: .winners)
        try container.encode(qualifies, forKey: .qualifies)
    }

    private enum CodingKeys: String, CodingKey { case id, title, order, winners, qualifies }
}

struct EventReport: Codable, Identifiable, Equatable {
    var eventID: Int
    var eventName: String
    var sku: String
    var divisionID: Int
    var divisionName: String
    var divisions: [DivisionInfo]
    var ongoing: Bool
    var updated: Date
    var teams: [TeamReport]
    var note: String
    var championNumbers: [String]
    var schoolLevels: [String: String]
    var bracket: [BracketMatch]
    var awards: [EventAward]

    var id: Int { eventID }

    init(
        eventID: Int,
        eventName: String,
        sku: String,
        divisionID: Int,
        divisionName: String,
        divisions: [DivisionInfo],
        ongoing: Bool,
        updated: Date,
        teams: [TeamReport],
        note: String,
        championNumbers: [String] = [],
        schoolLevels: [String: String] = [:],
        bracket: [BracketMatch] = [],
        awards: [EventAward] = []
    ) {
        self.eventID = eventID
        self.eventName = eventName
        self.sku = sku
        self.divisionID = divisionID
        self.divisionName = divisionName
        self.divisions = divisions
        self.ongoing = ongoing
        self.updated = updated
        self.teams = teams
        self.note = note
        self.championNumbers = championNumbers
        self.schoolLevels = schoolLevels
        self.bracket = bracket
        self.awards = awards
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        eventID = try container.decode(Int.self, forKey: .eventID)
        eventName = try container.decode(String.self, forKey: .eventName)
        sku = try container.decode(String.self, forKey: .sku)
        divisionID = try container.decode(Int.self, forKey: .divisionID)
        divisionName = try container.decode(String.self, forKey: .divisionName)
        divisions = try container.decode([DivisionInfo].self, forKey: .divisions)
        ongoing = try container.decode(Bool.self, forKey: .ongoing)
        updated = try container.decode(Date.self, forKey: .updated)
        teams = try container.decode([TeamReport].self, forKey: .teams)
        note = try container.decode(String.self, forKey: .note)
        championNumbers = try container.decodeIfPresent([String].self, forKey: .championNumbers) ?? []
        schoolLevels = try container.decodeIfPresent([String: String].self, forKey: .schoolLevels) ?? [:]
        bracket = try container.decodeIfPresent([BracketMatch].self, forKey: .bracket) ?? []
        awards = try container.decodeIfPresent([EventAward].self, forKey: .awards) ?? []
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(eventID, forKey: .eventID)
        try container.encode(eventName, forKey: .eventName)
        try container.encode(sku, forKey: .sku)
        try container.encode(divisionID, forKey: .divisionID)
        try container.encode(divisionName, forKey: .divisionName)
        try container.encode(divisions, forKey: .divisions)
        try container.encode(ongoing, forKey: .ongoing)
        try container.encode(updated, forKey: .updated)
        try container.encode(teams, forKey: .teams)
        try container.encode(note, forKey: .note)
        try container.encode(championNumbers, forKey: .championNumbers)
        try container.encode(schoolLevels, forKey: .schoolLevels)
        try container.encode(bracket, forKey: .bracket)
        try container.encode(awards, forKey: .awards)
    }

    private enum CodingKeys: String, CodingKey {
        case eventID, eventName, sku, divisionID, divisionName, divisions, ongoing, updated, teams, note, championNumbers, schoolLevels, bracket, awards
    }
}

struct WatchSnapshot: Codable, Equatable {
    var updated: Date
    var seasonName: String
    var eventName: String
    var divisionName: String
    var note: String
    var myNumber: String
    var teams: [TeamReport]

    var myTeam: TeamReport? {
        let wanted = normalizedTeamNumber(myNumber)
        guard !wanted.isEmpty else { return nil }
        return teams.first { normalizedTeamNumber($0.number) == wanted }
    }

    var ranked: [TeamReport] {
        teams.ranked()
    }
}

struct SeasonInfo: Codable, Equatable {
    var id: Int
    var name: String
}

enum SnapshotCoding {
    static func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

func normalizedTeamNumber(_ raw: String) -> String {
    raw.uppercased().filter { $0.isNumber || $0.isLetter }
}

func preferredProgramID(in programs: [ProgramChoice]) -> Int? {
    let v5 = programs.first { program in
        let blob = "\(program.code) \(program.name)".uppercased()
        let isV5 = blob.contains("V5") || blob.contains("VRC")
        return isV5 && !blob.contains("IQ")
    }
    return v5?.id ?? programs.first?.id
}

extension Array where Element == TeamReport {
    func ranked() -> [TeamReport] {
        sorted { a, b in
            switch (a.rank > 0, b.rank > 0) {
            case (true, false):
                return true
            case (false, true):
                return false
            case (true, true) where a.rank != b.rank:
                return a.rank < b.rank
            default:
                return a.overall > b.overall
            }
        }
    }

    func byPercent() -> [TeamReport] {
        sorted { a, b in
            if a.overall != b.overall { return a.overall > b.overall }
            if a.rank == 0 { return false }
            if b.rank == 0 { return true }
            return a.rank < b.rank
        }
    }

    func bySkills() -> [TeamReport] {
        sorted { a, b in
            if a.skillsTotal != b.skillsTotal { return a.skillsTotal > b.skillsTotal }
            return a.overall > b.overall
        }
    }
}

extension Int {
    var ordinal: String {
        let tens = self % 100
        if (11...13).contains(tens) { return "\(self)th" }
        switch self % 10 {
        case 1: return "\(self)st"
        case 2: return "\(self)nd"
        case 3: return "\(self)rd"
        default: return "\(self)th"
        }
    }
}
