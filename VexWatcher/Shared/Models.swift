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
        if ongoing { return true }
        let now = Date()
        guard let start, let end else { return false }
        return start <= now && now <= end.addingTimeInterval(20 * 60 * 60)
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

    var id: Int { eventID }
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
