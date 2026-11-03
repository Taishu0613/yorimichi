import Testing
import Foundation
@testable import WAGhack

struct BadgeTests {
    private let calculator = ExplorationProgressCalculator()
    private let evaluator = BadgeRuleEvaluator()
    private let reconciler = BadgeAchievementReconciler()

    @Test func 訪問0件ではどのバッジも獲得せず最初のおすすめは最初の一歩() {
        let statuses = statuses(visitedCodes: [])
        #expect(statuses.earnedCount == 0)
        let recommendations = statuses.recommendations(currentPrefectureCode: nil)
        #expect(recommendations.count == 3)
        #expect(recommendations.first?.id == .firstStep)
        #expect(recommendations.first?.headline == "最初の街を訪れてみよう")
    }

    @Test func 次のよりみちはあと少しのバッジと今いる都道府県のバッジを先に出す() {
        // 府中市(東京)だけ訪れた状態。はじめの足あとは獲得済みなので候補から外れる。
        let statuses = statuses(visitedCodes: ["13206"])
        let ids = statuses.recommendations(currentPrefectureCode: "34").map(\.id)
        // あと1つの「ふたごのまち」(広島の府中市)と、あと1つの「県またぎの旅人」が先に来る。
        #expect(Set(ids.prefix(2)) == [.twinTowns, .prefectureTraveler])
        #expect(statuses.recommendations(currentPrefectureCode: nil).allSatisfy { $0.nextThreshold != nil })
    }

    @Test func 超・境目は記録した場所がおたがい1km以内の3つの街で獲得し証跡を残す() throws {
        // 新宿区・渋谷区・豊島区の記録した場所を、おたがい1km以内に置く。
        let near = [
            point("13104", 35.6900, 139.7000), point("13113", 35.6930, 139.7030), point("13116", 35.6870, 139.7040),
        ]
        let codes: Set<String> = ["13104", "13113", "13116"]
        let earned = status(.tripleBoundary, in: statuses(visitedCodes: codes, points: near))
        #expect(earned.isEarned)
        let ledger = reconciler.reconcile(
            BadgeLedger(hasCompletedInitialSync: true, evaluatedBadgeIDs: Set(BadgeID.allCases.map(\.rawValue))),
            with: progresses(visitedCodes: codes, points: near), now: .now
        )
        let evidence = try #require(ledger.achievement(for: .tripleBoundary)?.evidence)
        #expect(Set(evidence.places.map(\.code)) == codes)

        // 1つだけ遠くに記録した場所があると、近い2つまで。
        let far = [near[0], near[1], point("13116", 35.7300, 139.7100)]
        let partial = status(.tripleBoundary, in: statuses(visitedCodes: codes, points: far))
        #expect(partial.currentValue == 2)
        #expect(partial.headline == "新宿区と渋谷区の近くで、もう1つの街を記録しよう")
    }

    @Test func 都会にこんにちはは3つの副都心をすべて訪れて獲得() {
        #expect(status(.helloMetropolis, in: statuses(visitedCodes: ["13104", "13113"])).headline == "残り：池袋")
        #expect(status(.helloMetropolis, in: statuses(visitedCodes: ["13104", "13113", "13116"])).isEarned)
    }

    @Test func ふたごのまちはちがう県の同じ名前を両方訪れて獲得() {
        let one = status(.twinTowns, in: statuses(visitedCodes: ["13206"]))
        #expect(!one.isEarned)
        #expect(one.headline == "府中市をもう1つ訪れよう")
        #expect(one.progress.groups.first?.name == "府中市")
        #expect(status(.twinTowns, in: statuses(visitedCodes: ["13206", "34208"])).isEarned)
    }

    @Test func 数字の旅人は名前に入っている数字の種類を集める() {
        // 八王子市(八)・三鷹市(三)。同じ数字の街を重ねても種類は増えない。
        let partial = status(.numberTraveler, in: statuses(visitedCodes: ["13201", "13204"]))
        #expect(partial.currentValue == 2)
        #expect(partial.progress.numerals.filter(\.isCollected).map(\.symbol) == ["三", "八"])
        // 一宮市(一)で3種類になり、ブロンズ。
        let bronze = status(.numberTraveler, in: statuses(visitedCodes: ["13201", "13204", "23203"]))
        #expect(bronze.rank == .bronze)
        #expect(bronze.nextThreshold == 6)
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
            entry("13204", "三鷹市", prefecture: "13", prefectureName: "東京都"),
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

    private func progresses(visitedCodes: Set<String>, points: [BadgeVisitPoint] = []) -> [BadgeProgress] {
        evaluator.evaluate(calculator.summarize(municipalities: municipalities, visitedCodes: visitedCodes), visitPoints: points)
    }

    private func statuses(visitedCodes: Set<String>, points: [BadgeVisitPoint] = []) -> [BadgeStatus] {
        progresses(visitedCodes: visitedCodes, points: points).map { BadgeStatus(progress: $0, achievement: nil) }
    }

    private func point(_ code: String, _ latitude: Double, _ longitude: Double) -> BadgeVisitPoint {
        BadgeVisitPoint(code: code, latitude: latitude, longitude: longitude, recordedAt: .now)
    }

    private func status(_ id: BadgeID, in statuses: [BadgeStatus]) -> BadgeStatus {
        statuses.first { $0.id == id }!
    }
}
