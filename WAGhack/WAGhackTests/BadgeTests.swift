import Testing
import Foundation
@testable import WAGhack

struct BadgeTests {
    private let calculator = ExplorationProgressCalculator()
    private let evaluator = BadgeRuleEvaluator()
    private let reconciler = BadgeAchievementReconciler()

    @Test func 訪問0件ではどのバッジも獲得せず最初のチャレンジは最初の一歩() {
        let statuses = statuses(visitedCodes: [])
        #expect(statuses.earnedCount == 0)
        #expect(statuses.nextChallenge?.id == .firstStep)
        #expect(statuses.nextChallenge?.headline == "最初の街を訪れてみよう")
    }

    @Test func 準備中のバッジは獲得済みにならない() {
        let status = status(.tripleBoundary, in: statuses(visitedCodes: Set(BadgeCatalog.tokyoSpecialWardCodes)))
        #expect(!status.isEarned)
        #expect(status.shortStatusText == "準備中")
    }

    @Test func 都会にこんにちはは3つの副都心をすべて訪れて獲得() {
        #expect(status(.helloMetropolis, in: statuses(visitedCodes: ["13104", "13113"])).headline == "あと1区で獲得")
        #expect(status(.helloMetropolis, in: statuses(visitedCodes: ["13104", "13113", "13116"])).isEarned)
    }

    @Test func ふたごのまちはちがう県の同じ名前を両方訪れて獲得() {
        let one = status(.twinTowns, in: statuses(visitedCodes: ["13206"]))
        #expect(!one.isEarned)
        #expect(one.headline == "府中市をもう1つ訪れよう")
        #expect(one.progress.groups.first?.name == "府中市")
        #expect(status(.twinTowns, in: statuses(visitedCodes: ["13206", "34208"])).isEarned)
    }

    @Test func 数字の旅人は漢数字で始まる市区町村を数える() {
        let partial = status(.numberTraveler, in: statuses(visitedCodes: ["13101", "13201"]))
        #expect(partial.currentValue == 2)
        #expect(status(.numberTraveler, in: statuses(visitedCodes: ["13101", "13201", "23203"])).isEarned)
    }

    @Test func 三都物語は3都市でそれぞれ1区以上訪れて獲得() {
        let partial = status(.threeCapitals, in: statuses(visitedCodes: ["13101", "26101"]))
        #expect(partial.currentValue == 2)
        #expect(partial.progress.groups.map(\.isSatisfied) == [true, true, false])
        #expect(status(.threeCapitals, in: statuses(visitedCodes: ["13101", "26101", "27102"])).isEarned)
    }

    @Test func アップデートで判定できるようになったバッジは過去の分として反映する() {
        // Phase 1の版の記録(evaluatedBadgeIDsが無い)に、Phase 2で判定できるようになったバッジの条件を満たす訪問がある。
        let ledger = BadgeLedger(hasCompletedInitialSync: true)
        let updated = reconciler.reconcile(ledger, with: progresses(visitedCodes: ["13104", "13113", "13116"]), now: .now)
        #expect(updated.achievement(for: .helloMetropolis)?.achievedAt == nil)
        // はじめの足あと(Phase 1で判定済み)は新しい訪問として日時が付くが、まとめの知らせが優先される。
        #expect(updated.achievement(for: .firstStep)?.achievedAt != nil)
        #expect(reconciler.pendingAnnouncement(in: updated) == .initialSummary(earnedCount: 2))
    }

    @Test func 複数県の訪問で県またぎと地元の探検家を数える() {
        let codes = (1...10).map { "14\(String(format: "%03d", $0))" } + ["13101"]
        let statuses = statuses(visitedCodes: Set(codes))
        #expect(status(.prefectureTraveler, in: statuses).currentValue == 2)
        #expect(status(.prefectureTraveler, in: statuses).rank == .bronze)
        let local = status(.localExplorer, in: statuses)
        #expect(local.isEarned)
        #expect(local.progress.prefectureCounts.first?.code == "14")
    }

    @Test func 東京23区は特別区のコードで数え段階を保持する() {
        let visited = Array(BadgeCatalog.tokyoSpecialWardCodes.prefix(7))
        let tokyo = status(.tokyo23, in: statuses(visitedCodes: Set(visited)))
        #expect(tokyo.currentValue == 7)
        #expect(tokyo.rank == .bronze)
        #expect(tokyo.nextThreshold == 10)
        #expect(tokyo.headline == "あと3区でシルバー")
        #expect(tokyo.progress.checklist.count == 23)
        #expect(tokyo.progress.checklist.first?.name == "千代田区")
    }

    @Test func 政令指定都市は区で数え市そのものの記録は数えない() {
        // 横浜市(14100)そのものの記録は踏破率に含まれず、区だけを数える。
        let statuses = statuses(visitedCodes: ["14100", "14101"])
        #expect(status(.footprintCollector, in: statuses).currentValue == 1)
        #expect(status(.firstStep, in: statuses).isEarned)
    }

    @Test func 段階が上がると新しい獲得として知らせる() throws {
        var ledger = BadgeLedger(hasCompletedInitialSync: true)
        let first = Array(BadgeCatalog.tokyoSpecialWardCodes.prefix(5))
        ledger = reconciler.reconcile(ledger, with: progresses(visitedCodes: Set(first)), now: .now)
        ledger = reconciler.markAnnounced(try #require(reconciler.pendingAnnouncement(in: ledger)), in: ledger)

        let more = Array(BadgeCatalog.tokyoSpecialWardCodes.prefix(10))
        ledger = reconciler.reconcile(ledger, with: progresses(visitedCodes: Set(more)), now: .now)
        // 10区で東京23区の旅がシルバーに上がり、同時に足あとコレクター・地元の探検家(どちらも10か所)も獲得する。
        // まとめて1回で知らせる。
        #expect(reconciler.pendingAnnouncement(in: ledger) == .newlyEarned([
            BadgeUnlock(id: .footprintCollector, tierCount: 1),
            BadgeUnlock(id: .localExplorer, tierCount: 1),
            BadgeUnlock(id: .tokyo23, tierCount: 2),
        ]))
        #expect(ledger.achievement(for: .tokyo23)?.achievedAt != nil)
    }

    @Test func 既存の訪問履歴は初回にまとめて反映し日時不明にする() {
        let codes = Set(BadgeCatalog.tokyoSpecialWardCodes.prefix(5))
        let ledger = reconciler.reconcile(BadgeLedger(), with: progresses(visitedCodes: codes), now: .now)
        // はじめの足あと・東京23区の旅(ブロンズ)
        #expect(reconciler.pendingAnnouncement(in: ledger) == .initialSummary(earnedCount: 2))
        #expect(ledger.achievement(for: .firstStep)?.achievedAt == nil)
        let afterSummary = reconciler.markAnnounced(.initialSummary(earnedCount: 2), in: ledger)
        #expect(reconciler.pendingAnnouncement(in: afterSummary) == nil)
    }

    @Test func 記録を消しても獲得済みの段階は保つ() throws {
        let codes = Set(BadgeCatalog.tokyoSpecialWardCodes.prefix(5))
        let ledger = reconciler.reconcile(BadgeLedger(), with: progresses(visitedCodes: codes), now: .now)
        let progress = progresses(visitedCodes: [])
        let tokyo = try #require(progress.first { $0.definition.id == .tokyo23 })
        let status = BadgeStatus(progress: tokyo, achievement: ledger.achievement(for: .tokyo23))
        #expect(status.rank == .bronze)
        #expect(status.nextThreshold == 10)
    }

    // MARK: - 補助

    /// 東京23区・横浜市・神奈川県のほかの市町村10件と、Phase 2の対象(府中市・一宮市・京都市・大阪市など)だけの小さなマスタ。
    private var municipalities: [ExplorationMunicipality] {
        let tokyo = zip(BadgeCatalog.tokyoSpecialWardCodes, wardNames).map { entry($0, $1, prefecture: "13", prefectureName: "東京都") }
        let kanagawa = (1...10).map { entry("14\(String(format: "%03d", $0))", "神奈川\($0)", prefecture: "14", prefectureName: "神奈川県") }
        return tokyo + kanagawa + [
            entry("14100", "横浜市", prefecture: "14", prefectureName: "神奈川県"),
            entry("14101", "横浜市鶴見区", prefecture: "14", prefectureName: "神奈川県"),
            entry("13201", "八王子市", prefecture: "13", prefectureName: "東京都"),
            entry("13206", "府中市", prefecture: "13", prefectureName: "東京都"),
            entry("23203", "一宮市", prefecture: "23", prefectureName: "愛知県"),
            entry("26100", "京都市", prefecture: "26", prefectureName: "京都府"),
            entry("26101", "京都市北区", prefecture: "26", prefectureName: "京都府"),
            entry("34208", "府中市", prefecture: "34", prefectureName: "広島県"),
            entry("27100", "大阪市", prefecture: "27", prefectureName: "大阪府"),
            entry("27102", "大阪市都島区", prefecture: "27", prefectureName: "大阪府"),
        ]
    }

    private let wardNames = [
        "千代田区", "中央区", "港区", "新宿区", "文京区", "台東区", "墨田区", "江東区", "品川区", "目黒区", "大田区", "世田谷区",
        "渋谷区", "中野区", "杉並区", "豊島区", "北区", "荒川区", "板橋区", "練馬区", "足立区", "葛飾区", "江戸川区",
    ]

    private func entry(_ code: String, _ name: String, prefecture: String, prefectureName: String) -> ExplorationMunicipality {
        ExplorationMunicipality(code: code, name: name, prefectureCode: prefecture, prefectureName: prefectureName, isPrefecture: false)
    }

    private func progresses(visitedCodes: Set<String>) -> [BadgeProgress] {
        evaluator.evaluate(calculator.summarize(municipalities: municipalities, visitedCodes: visitedCodes))
    }

    private func statuses(visitedCodes: Set<String>) -> [BadgeStatus] {
        progresses(visitedCodes: visitedCodes).map { BadgeStatus(progress: $0, achievement: nil) }
    }

    private func status(_ id: BadgeID, in statuses: [BadgeStatus]) -> BadgeStatus {
        statuses.first { $0.id == id }!
    }
}
