import Foundation
import Observation
import OSLog

/// シェアを誘う節目。都道府県の制覇率が25/50/75/100%に届いたとき、政令指定都市の区をすべて訪れたとき。
///
/// 制覇率が積み上がった瞬間がいちばんシェアしたくなる時なので、その時に小さな知らせ(`ShareMilestoneBanner`)で
/// シェア画面へ誘う。節目は都道府県・政令指定都市ごとに一度だけ知らせる。
struct ShareMilestone: Hashable, Sendable {
    enum Kind: Hashable, Sendable {
        /// 都道府県の制覇率(%)。`ShareMilestoneEvaluator.prefectureThresholds`のどれか。
        case prefecture(percent: Int)
        /// 政令指定都市の区をすべて訪れた。
        case designatedCityComplete
    }

    let kind: Kind
    /// 都道府県コード(2桁)、または政令指定都市そのものの行政区域コード(5桁)。
    let code: String
    let name: String

    /// 知らせ済みの記録に使うキー。名前はマスタの更新で変わりうるので含めない。
    var id: String {
        switch kind {
        case .prefecture(let percent): "prefecture-\(code)-\(percent)"
        case .designatedCityComplete: "city-\(code)-complete"
        }
    }

    /// 知らせの本文(例:「愛知県 50%達成!」「名古屋市 全区制覇!」)。
    var message: String {
        switch kind {
        case .prefecture(let percent): percent == 100 ? "\(name) 完全踏破!" : "\(name) \(percent)%達成!"
        case .designatedCityComplete: "\(name) 全区制覇!"
        }
    }

    /// 「シェアする」で開くシェア画面の範囲。
    var scope: ShareScope {
        switch kind {
        case .prefecture: .prefecture(code: code)
        case .designatedCityComplete: .designatedCity(code: code)
        }
    }
}

/// 集計から、届いている節目を求める。状態を持たない純粋な計算なので単体テストできる。
struct ShareMilestoneEvaluator: Sendable {
    static let prefectureThresholds = [25, 50, 75, 100]

    /// 今の集計で届いているすべての節目。
    func reachedMilestones(in summary: ExplorationSummary) -> [ShareMilestone] {
        var milestones: [ShareMilestone] = []
        for prefecture in summary.prefectures {
            let progress = prefecture.progress
            // 割合を浮動小数で比べると、境目ちょうど(4/16=25%など)で丸めの誤差が出うるので整数で比べる。
            for percent in Self.prefectureThresholds
            where progress.total > 0 && progress.visited > 0 && progress.visited * 100 >= progress.total * percent {
                milestones.append(ShareMilestone(kind: .prefecture(percent: percent), code: prefecture.code, name: prefecture.name))
            }
        }
        for city in summary.designatedCities where city.isComplete {
            milestones.append(ShareMilestone(kind: .designatedCityComplete, code: city.code, name: city.name))
        }
        return milestones
    }

    /// 知らせ済みの記録と突き合わせ、新しく届いた節目を知らせる順に返す。
    ///
    /// - 記録が無い(このバージョンではじめての評価)なら、今届いている節目をすべて知らせ済みにするだけで何も知らせない。
    ///   アップデート前から届いていた節目を、まとめて知らせないため。
    /// - 1回の記録で同じ都道府県の節目を複数越えた(小さな県で25%と50%を一度に越えたなど)ときは、高い方だけを知らせる。
    /// - 訪問を削除して節目を割り込み、また越えても、知らせ済みなので繰り返さない。
    func reconcile(_ ledger: ShareMilestoneLedger?, with summary: ExplorationSummary) -> (ledger: ShareMilestoneLedger, newlyReached: [ShareMilestone]) {
        let reached = reachedMilestones(in: summary)
        let reachedIDs = Set(reached.map(\.id))
        guard let ledger else {
            return (ShareMilestoneLedger(announcedIDs: reachedIDs), [])
        }
        let fresh = reached.filter { !ledger.announcedIDs.contains($0.id) }
        var highestByArea: [String: ShareMilestone] = [:]
        for milestone in fresh {
            let areaKey = milestone.scope.areaKey
            if let current = highestByArea[areaKey], current.rank >= milestone.rank { continue }
            highestByArea[areaKey] = milestone
        }
        // 完全踏破・全区制覇のような大きな節目から先に知らせる。同じ大きさなら行政区域コードの順。
        let newlyReached = highestByArea.values.sorted {
            $0.rank != $1.rank ? $0.rank > $1.rank : $0.code < $1.code
        }
        return (ShareMilestoneLedger(announcedIDs: ledger.announcedIDs.union(reachedIDs)), newlyReached)
    }
}

/// 知らせ済みの節目の記録。UserDefaultsにJSONで保存する。
struct ShareMilestoneLedger: Codable, Equatable, Sendable {
    var announcedIDs: Set<String>
}

private extension ShareMilestone {
    /// 知らせる順の大きさ。全区制覇は都道府県の完全踏破と同じ扱いにする。
    var rank: Int {
        switch kind {
        case .prefecture(let percent): percent
        case .designatedCityComplete: 100
        }
    }
}

private extension ShareScope {
    /// 同じ都道府県・政令指定都市の節目をまとめるためのキー。
    var areaKey: String {
        switch self {
        case .japan: "japan"
        case .prefecture(let code): "prefecture-\(code)"
        case .designatedCity(let code): "city-\(code)"
        }
    }
}

/// 節目の知らせの状態を持つ。持ち主は`MapScreen`で、`BadgeStore`と同じく集計が変わった時だけ`update`で評価し直す。
///
/// 知らせ済みの記録は、新しく届いたと分かった時点で保存する(知らせを見せる前にアプリを閉じても、次に繰り返さない)。
/// 知らせ待ちは端末のメモリにだけ持つ。見逃しても、都道府県・政令指定都市の画面からいつでもシェアできるため。
@MainActor
@Observable
final class ShareMilestoneStore {
    private static let ledgerKey = "shareMilestones.ledger"

    /// まだ見せていない知らせ。先頭から順に見せる。
    private(set) var pending: [ShareMilestone] = []

    @ObservationIgnored private var ledger: ShareMilestoneLedger?
    @ObservationIgnored private let userDefaults: UserDefaults
    @ObservationIgnored private let evaluator = ShareMilestoneEvaluator()
    @ObservationIgnored private let logger = Logger(subsystem: "com.wakasugi.yorimichi", category: "ShareMilestones")

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        ledger = Self.loadLedger(from: userDefaults)
    }

    var nextAnnouncement: ShareMilestone? { pending.first }

    func update(summary: ExplorationSummary) {
        // マスタの読み込み前(対象の市区町村が0件)に評価すると、記録があっても何も届いていないように見え、
        // そこで「はじめての評価」を済ませてしまう。マスタが揃うまでは評価しない(`BadgeStore`と同じ)。
        guard !summary.eligibleCodes.isEmpty else { return }
        let result = evaluator.reconcile(ledger, with: summary)
        if result.ledger != ledger {
            ledger = result.ledger
            save(result.ledger)
        }
        let pendingIDs = Set(pending.map(\.id))
        pending += result.newlyReached.filter { !pendingIDs.contains($0.id) }
    }

    /// 知らせを見せ始めたら呼ぶ。
    func markAnnounced(_ milestone: ShareMilestone) {
        pending.removeAll { $0.id == milestone.id }
    }

    private func save(_ ledger: ShareMilestoneLedger) {
        do {
            userDefaults.set(try JSONEncoder().encode(ledger), forKey: Self.ledgerKey)
        } catch {
            // 失われるのは知らせ済みかどうかだけ。次の起動で「はじめての評価」になり、何も知らせずに記録し直す。
            logger.error("節目の知らせの記録を保存できませんでした: \(error.localizedDescription)")
        }
    }

    private static func loadLedger(from userDefaults: UserDefaults) -> ShareMilestoneLedger? {
        guard let data = userDefaults.data(forKey: ledgerKey) else { return nil }
        do {
            return try JSONDecoder().decode(ShareMilestoneLedger.self, from: data)
        } catch {
            Logger(subsystem: "com.wakasugi.yorimichi", category: "ShareMilestones")
                .error("節目の知らせの記録を読み込めませんでした: \(error.localizedDescription)")
            return nil
        }
    }
}
