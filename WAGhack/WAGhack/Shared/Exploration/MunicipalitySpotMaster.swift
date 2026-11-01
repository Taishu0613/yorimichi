import Foundation
import os

/// アプリに同梱した「みどころ」のマスタ(`MunicipalitySpots.csv`)を読む。
///
/// 中身はAIがさまざまな情報源から総合評価した結果を、市区町村ごとに最大10件にまとめたもの(作り方は`SpotMaster/README.md`)。
/// 表示のたびに検索すると待たされるため、事前に作ったものを読むだけにしている。アプリの中でAIも検索も動かない。
///
/// 豆知識のマスタと違いSwiftDataへは取り込まない。読み取り専用で、データを差し替えるのもアプリの更新のときだけなので、
/// 初回に1回だけ読んでメモリに持てば足りる(取り込むと同期の仕組みとスキーマの変更が要る)。
actor MunicipalitySpotMaster {
    static let shared = MunicipalitySpotMaster()

    static let resourceName = "MunicipalitySpots"
    /// 1つの市区町村に載せる上限。
    static let maximumSpotCount = 10

    private var spotsByCode: [String: [YorimichiSpot]]?
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "WAGhack", category: "SpotMaster")

    /// 市区町村のスポットを順位の順に返す。政令指定都市は市そのものの行が無ければ、各区の行を順位の順に混ぜて返す。
    /// `wardCodes`は政令指定都市のときだけ渡す。マスタを読めないときは空(画面は0件の案内になる)。
    func spots(code: String, wardCodes: [String] = []) -> [YorimichiSpot] {
        let spotsByCode = loadedSpots()
        if let spots = spotsByCode[code] { return spots }
        let wardSpots = wardCodes.flatMap { spotsByCode[$0] ?? [] }
        return Array(wardSpots.sorted { $0.rank < $1.rank }.prefix(Self.maximumSpotCount))
    }

    private func loadedSpots() -> [String: [YorimichiSpot]] {
        if let spotsByCode { return spotsByCode }
        var loaded: [String: [YorimichiSpot]] = [:]
        do {
            guard let url = Bundle.main.url(forResource: Self.resourceName, withExtension: "csv") else {
                throw URLError(.fileDoesNotExist)
            }
            let source = try String(contentsOf: url, encoding: .utf8)
            loaded = try Self.parse(source)
            logger.info("みどころマスタ: \(loaded.count)市区町村")
        } catch {
            // 利用者には0件の案内を見せるだけで画面は使えるので、原因は開発者向けのログに残す。
            logger.error("みどころマスタを読めません: \(String(describing: error), privacy: .public)")
        }
        spotsByCode = loaded
        return loaded
    }

    /// CSVを市区町村ごとの一覧にする。列は`code,rank,name,category,action,reason`。
    /// 読めない行があっても他の行まで道連れにしないよう、その行だけ飛ばす(行の正しさは`SpotMaster/scripts`で事前に確かめる)。
    nonisolated static func parse(_ source: String) throws -> [String: [YorimichiSpot]] {
        var result: [String: [YorimichiSpot]] = [:]
        for row in try CSVParser().parse(source).dropFirst() where row.count == 6 {
            guard let rank = Int(row[1]), !row[0].isEmpty, !row[2].isEmpty else { continue }
            let spot = YorimichiSpot(
                municipalityCode: row[0],
                rank: rank,
                name: row[2],
                // 新しい区分がマスタに増えても古いアプリで落ちないよう、知らない値は`other`にする。
                experience: SpotExperience(rawValue: row[3]) ?? .other,
                action: row[4].isEmpty ? nil : row[4],
                reason: row[5].isEmpty ? nil : row[5]
            )
            result[spot.municipalityCode, default: []].append(spot)
        }
        return result.mapValues { spots in
            Array(spots.sorted { $0.rank < $1.rank }.prefix(maximumSpotCount))
        }
    }
}
