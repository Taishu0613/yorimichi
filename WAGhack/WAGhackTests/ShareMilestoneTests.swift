import Foundation
import Testing
@testable import WAGhack

/// 節目(都道府県の25/50/75/100%・政令指定都市の全区制覇)の知らせの規則。
struct ShareMilestoneTests {
    private let evaluator = ShareMilestoneEvaluator()

    /// 愛知県: 名古屋市の2区＋6市(合わせて8市区町村)。
    private func summary(visited: Set<String>) -> ExplorationSummary {
        let entries = [
            entry("23100", "名古屋市"), entry("23101", "名古屋市千種区"), entry("23102", "名古屋市東区"),
            entry("23201", "豊橋市"), entry("23202", "岡崎市"), entry("23203", "一宮市"),
            entry("23204", "瀬戸市"), entry("23205", "半田市"), entry("23206", "春日井市"),
        ]
        return ExplorationProgressCalculator().summarize(municipalities: entries, visitedCodes: visited)
    }

    @Test func はじめての評価ではすでに届いている節目を知らせずに記録だけする() {
        let result = evaluator.reconcile(nil, with: summary(visited: ["23201", "23202", "23203", "23204"]))

        #expect(result.newlyReached.isEmpty)
        #expect(result.ledger.announcedIDs == ["prefecture-23-25", "prefecture-23-50"])
    }

    @Test func 新しく越えた節目だけを知らせる() {
        let seeded = evaluator.reconcile(nil, with: summary(visited: ["23201"])).ledger

        // 1/8 → 2/8 で25%に届く。
        let result = evaluator.reconcile(seeded, with: summary(visited: ["23201", "23202"]))

        #expect(result.newlyReached.map(\.id) == ["prefecture-23-25"])
        #expect(result.newlyReached.first?.message == "愛知県 25%達成!")
        #expect(result.newlyReached.first?.scope == .prefecture(code: "23"))
    }

    @Test func 節目に届いていなければ何も知らせない() {
        let seeded = evaluator.reconcile(nil, with: summary(visited: [])).ledger

        let result = evaluator.reconcile(seeded, with: summary(visited: ["23201"]))

        // 1/8 = 12.5%
        #expect(result.newlyReached.isEmpty)
    }

    @Test func 同じ節目は一度しか知らせない() {
        let seeded = evaluator.reconcile(nil, with: summary(visited: ["23201"])).ledger
        let first = evaluator.reconcile(seeded, with: summary(visited: ["23201", "23202"]))

        // 同じ集計でもう一度評価しても、訪問を消してまた越えても繰り返さない。
        let again = evaluator.reconcile(first.ledger, with: summary(visited: ["23201", "23202"]))
        let dropped = evaluator.reconcile(again.ledger, with: summary(visited: ["23201"]))
        let regained = evaluator.reconcile(dropped.ledger, with: summary(visited: ["23201", "23203"]))

        #expect(first.newlyReached.count == 1)
        #expect(again.newlyReached.isEmpty)
        #expect(regained.newlyReached.isEmpty)
    }

    @Test func 一度に複数の節目を越えたら高い方だけを知らせる() {
        let seeded = evaluator.reconcile(nil, with: summary(visited: ["23201"])).ledger

        // 1/8 → 4/8 で25%と50%を一度に越える。
        let result = evaluator.reconcile(seeded, with: summary(visited: ["23201", "23202", "23203", "23204"]))

        #expect(result.newlyReached.map(\.id) == ["prefecture-23-50"])
        // 低い方も知らせ済みにして、後から知らせない。
        #expect(result.ledger.announcedIDs.contains("prefecture-23-25"))
    }

    @Test func 政令指定都市の区をすべて訪れたら全区制覇を知らせる() {
        let seeded = evaluator.reconcile(nil, with: summary(visited: ["23101"])).ledger

        let result = evaluator.reconcile(seeded, with: summary(visited: ["23101", "23102"]))

        // 2/8 で愛知県の25%にも届く。全区制覇を先に知らせる。
        #expect(result.newlyReached.map(\.id) == ["city-23100-complete", "prefecture-23-25"])
        #expect(result.newlyReached.first?.message == "名古屋市 全区制覇!")
        #expect(result.newlyReached.first?.scope == .designatedCity(code: "23100"))
    }

    @Test func 都道府県のすべてを訪れたら完全踏破として知らせる() {
        let all: Set<String> = ["23101", "23102", "23201", "23202", "23203", "23204", "23205", "23206"]
        let seeded = evaluator.reconcile(nil, with: summary(visited: all.subtracting(["23206"]))).ledger

        let result = evaluator.reconcile(seeded, with: summary(visited: all))

        #expect(result.newlyReached.map(\.id) == ["prefecture-23-100"])
        #expect(result.newlyReached.first?.message == "愛知県 完全踏破!")
    }

    @MainActor
    @Test func 知らせ済みの記録は端末に残り次の起動でも繰り返さない() throws {
        let suiteName = "ShareMilestoneTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let firstLaunch = ShareMilestoneStore(userDefaults: defaults)
        firstLaunch.update(summary: summary(visited: ["23201", "23202"]))
        #expect(firstLaunch.nextAnnouncement == nil)

        firstLaunch.update(summary: summary(visited: ["23201", "23202", "23203", "23204"]))
        let milestone = try #require(firstLaunch.nextAnnouncement)
        #expect(milestone.id == "prefecture-23-50")
        firstLaunch.markAnnounced(milestone)
        #expect(firstLaunch.nextAnnouncement == nil)

        let nextLaunch = ShareMilestoneStore(userDefaults: defaults)
        nextLaunch.update(summary: summary(visited: ["23201", "23202", "23203", "23204"]))
        #expect(nextLaunch.nextAnnouncement == nil)
    }

    private func entry(_ code: String, _ name: String) -> ExplorationMunicipality {
        ExplorationMunicipality(code: code, name: name, prefectureCode: "23", prefectureName: "愛知県", isPrefecture: false)
    }
}
