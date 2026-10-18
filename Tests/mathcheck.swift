import Foundation

@main
struct MathCheck {
    static func main() {
        var failed = 0
        func check(_ name: String, _ condition: Bool) {
            if condition {
                print("ok \(name)")
            } else {
                failed += 1
                print("FAIL \(name)")
            }
        }
        func near(_ value: Double?, _ expected: Double, tolerance: Double = 0.001) -> Bool {
            guard let value else { return false }
            return abs(value - expected) < tolerance
        }

        check("percentile high", near(ScoutMath.percentile(30, among: [10, 20, 30]), 100))
        check("percentile low", near(ScoutMath.percentile(10, among: [10, 20, 30]), 0))
        check("percentile mid", near(ScoutMath.percentile(20, among: [10, 20, 30]), 50))
        check("grade 85", ScoutMath.grade(85) == "Elite")
        check("grade 84", ScoutMath.grade(84) == "Strong")
        check("grade 70", ScoutMath.grade(70) == "Strong")
        check("grade 69", ScoutMath.grade(69) == "Good")
        check("grade 55", ScoutMath.grade(55) == "Good")
        check("grade 54", ScoutMath.grade(54) == "Average")
        check("grade 40", ScoutMath.grade(40) == "Average")
        check("grade 39", ScoutMath.grade(39) == "Developing")

        let bare = ScoutMath.rate([
            sample(id: 1, rank: 1),
            sample(id: 2, rank: 2)
        ], opr: [:])
        check("missing pieces stay 100", bare.first?.overall == 100)
        check("missing pieces can be 0", bare.last?.overall == 0)
        check("elite grade", bare.first?.grade == "Elite")
        check("developing grade", bare.last?.grade == "Developing")

        let quals = [
            PowerMatch(alliances: [
                PowerAlliance(teamIDs: [1, 2], score: 30),
                PowerAlliance(teamIDs: [3, 4], score: 12)
            ]),
            PowerMatch(alliances: [
                PowerAlliance(teamIDs: [1, 3], score: 28),
                PowerAlliance(teamIDs: [2, 4], score: 14)
            ]),
            PowerMatch(alliances: [
                PowerAlliance(teamIDs: [1, 4], score: 24),
                PowerAlliance(teamIDs: [2, 3], score: 18)
            ])
        ]
        let power = ScoutMath.offensivePower(quals)
        check("opr order", (power[1] ?? 0) > (power[2] ?? 0) && (power[2] ?? 0) > (power[3] ?? 0) && (power[3] ?? 0) > (power[4] ?? 0))
        check("opr near 20", near(power[1], 20, tolerance: 2))
        check("opr near 10", near(power[2], 10, tolerance: 2))
        check("opr near 8", near(power[3], 8, tolerance: 2))
        check("opr near 4", near(power[4], 4, tolerance: 2))
        check("absent team has no opr", power[9] == nil)
        let home = allianceTeam(id: 1, number: "95070D", opr: 20)
        let partners = [
            home,
            allianceTeam(id: 2, number: "A", opr: 25),
            allianceTeam(id: 3, number: "B", opr: 30),
            allianceTeam(id: 4, number: "C", opr: 10),
            allianceTeam(id: 5, number: "D", opr: 5)
        ]
        let outlook = ScoutMath.allianceChances(home: home, teams: partners)
        check("best partner is A", outlook.picks.first?.number == "A")
        check("A wins every other alliance", outlook.picks.first { $0.number == "A" }?.chance == 100)
        check("C wins about one in six", outlook.picks.first { $0.number == "C" }?.chance == 17)

        if let problem = ScoutMath.selfCheck() {
            failed += 1
            print("FAIL selfCheck \(problem)")
        } else {
            print("ok selfCheck")
        }

        if failed > 0 {
            print("\(failed) failed")
            exit(1)
        }
        print("all math checks passed")
    }

    static func allianceTeam(id: Int, number: String, opr: Double) -> TeamReport {
        TeamReport(
            id: id,
            number: number,
            name: number,
            organization: "",
            rank: id,
            wins: 1,
            losses: 0,
            ties: 0,
            wp: 2,
            ap: 0,
            sp: 0,
            highScore: 40,
            averagePoints: 20,
            driver: nil,
            programming: nil,
            driverRank: nil,
            programmingRank: nil,
            opr: opr,
            overall: 50,
            grade: "Good",
            abilities: [],
            components: [],
            recent: []
        )
    }

    static func sample(id: Int, rank: Int) -> RawTeam {
        RawTeam(
            id: id,
            number: "\(id)A",
            name: "",
            organization: "",
            rank: rank,
            wins: 0,
            losses: 0,
            ties: 0,
            wp: 0,
            ap: 0,
            sp: 0,
            highScore: 0,
            averagePoints: 0,
            driver: nil,
            programming: nil,
            driverRank: nil,
            programmingRank: nil,
            recent: []
        )
    }
}
