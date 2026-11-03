import Foundation
import Observation
import OSLog

/// バッジの状態を唯一持つ。持ち主は`MapScreen`で、訪問記録の集計(`ExplorationSummary`)が変わった時だけ`update`で評価し直す
/// (地図の再描画や位置の更新のたびには評価しない)。
///
/// 獲得記録はSwiftDataではなくUserDefaultsにJSONで保存する。保存するのは10件ほどの小さな値で訪問記録とのつながりも無く、
/// 訪問記録のストアにエンティティを足す(スキーマを変える)ほどの理由が無いため。訪問記録の正本はSwiftDataのまま変えない。
@MainActor
@Observable
final class BadgeStore {
    private static let ledgerKey = "badges.ledger"

    /// 定義の順(コレクション帳の並び)。訪問記録を評価するまでは空。
    private(set) var statuses: [BadgeStatus] = []
    private(set) var pendingAnnouncement: BadgeAnnouncement?

    @ObservationIgnored private var ledger: BadgeLedger
    @ObservationIgnored private let userDefaults: UserDefaults
    @ObservationIgnored private let reconciler = BadgeAchievementReconciler()
    @ObservationIgnored private let logger = Logger(subsystem: "com.wakasugi.yorimichi", category: "Badges")

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        ledger = Self.loadLedger(from: userDefaults)
        pendingAnnouncement = reconciler.pendingAnnouncement(in: ledger)
    }

    var isLoaded: Bool { !statuses.isEmpty }

    func status(for id: BadgeID) -> BadgeStatus? {
        statuses.first { $0.id == id }
    }

    func update(summary: ExplorationSummary, now: Date = .now) {
        // マスタの読み込み前(対象の市区町村が0件)に評価すると、既存の記録があっても何も獲得していないように見え、
        // その時点で「はじめての評価」を済ませてしまう。マスタが揃うまでは評価しない。
        guard !summary.eligibleCodes.isEmpty else { return }
        let progresses = BadgeRuleEvaluator().evaluate(summary)
        let reconciled = reconciler.reconcile(ledger, with: progresses, now: now)
        if reconciled != ledger {
            ledger = reconciled
            save()
        }
        statuses = progresses.map { BadgeStatus(progress: $0, achievement: ledger.achievement(for: $0.definition.id)) }
        pendingAnnouncement = reconciler.pendingAnnouncement(in: ledger)
    }

    /// 知らせを見せ始めたら呼ぶ。見せた時点で済んだことにし、アプリを閉じても同じ知らせを繰り返さない。
    func markAnnounced(_ announcement: BadgeAnnouncement) {
        ledger = reconciler.markAnnounced(announcement, in: ledger)
        save()
        pendingAnnouncement = reconciler.pendingAnnouncement(in: ledger)
    }

    private func save() {
        do {
            userDefaults.set(try JSONEncoder().encode(ledger), forKey: Self.ledgerKey)
        } catch {
            // 獲得記録は訪問記録から求め直せる(日時と演出の済み・未済みだけが失われる)ので、画面には出さずログに残す。
            logger.error("バッジの獲得記録を保存できませんでした: \(error.localizedDescription)")
        }
    }

    private static func loadLedger(from userDefaults: UserDefaults) -> BadgeLedger {
        guard let data = userDefaults.data(forKey: ledgerKey) else { return BadgeLedger() }
        do {
            return try JSONDecoder().decode(BadgeLedger.self, from: data)
        } catch {
            // 読めない場合は空から始める。次の評価が「はじめての評価」になり、獲得は日時不明として取り戻される。
            Logger(subsystem: "com.wakasugi.yorimichi", category: "Badges")
                .error("バッジの獲得記録を読み込めませんでした: \(error.localizedDescription)")
            return BadgeLedger()
        }
    }
}
