import MapKit
import os

/// 市区町村の詳細画面で開く対象。地図・記録の一覧・将来の道中一覧など、どこから開いても同じ形で渡す。
nonisolated struct MunicipalityDetailTarget: Hashable, Sendable {
    /// 表示している市区町村の行政区域コード(政令指定都市なら市のコード)。
    let code: String
    /// 区域を引く行政区域コード。普通の市区町村は自分自身、政令指定都市は区のコードの一覧(市そのものの形は境界データに無いため)。
    let areaCodes: [String]
    let prefectureName: String
    let municipalityName: String
}

/// 市区町村の中の「よりみちスポット」を、Apple MapKitの検索で表示のたびに探す。全国分のマスタは持たない。
///
/// 1. 同梱の境界データから区域を引き、その外接矩形で検索する(`MunicipalityBoundaryLookup`)。
/// 2. 「観光」「博物館」「神社」「寺」の語で順に検索し、それ自体が目的になる候補が揃った時点で打ち切る(`MKLocalSearch`)。
/// 3. それでも3件に満たなければ、公園のカテゴリで足りない分を探す(`MKLocalPointsOfInterestRequest`)。
/// 4. 検索結果のうち、実際の区域ポリゴンの中にあるものだけを`YorimichiSpotRanking`で最大3件選ぶ。
///
/// カテゴリだけの検索(`MKLocalPointsOfInterestRequest`)は、日本では博物館・名所にカテゴリが付いていないことが多く
/// (千葉市中央区で試すと、見どころのカテゴリでは記念碑1件しか返らなかった)、語の検索の方が名所を関連度順に返すため、語を主にしている。
///
/// 現在地の権限は使わない(区域から検索範囲を決めるため)。同じ市区町村の結果はアプリの実行中だけ覚える。
final class MunicipalitySpotSearchService {
    static let shared = MunicipalitySpotSearchService()

    enum SearchError: Error {
        /// 境界データに区域が見つからない。推定で探さず、見つからなかったものとして扱う。
        case areaUnavailable
    }

    /// 名所を探す検索語。上から順に、それ自体が目的になる候補が足りないときだけ使う。
    /// 「観光」は城・タワーなどの名所を関連度順に返す。寺社・博物館はそれぞれの語で補う。
    private static let queries = ["観光", "博物館", "神社", "寺"]
    /// これ以上の点数(歴史・景色・寺社など、それ自体が目的になる区分)の候補がこの数あれば、補助の検索をしない。
    private static let enoughStrongSpots = 3
    private static let strongScore = 4
    /// 1回の検索を待つ上限。応答が遅いときは打ち切って、得られた分だけで選ぶ。
    private static let searchTimeout: Duration = .seconds(8)

    private var cache: [MunicipalityDetailTarget: [YorimichiSpot]] = [:]
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "WAGhack", category: "SpotSearch")

    func spots(for target: MunicipalityDetailTarget) async throws -> [YorimichiSpot] {
        if let cached = cache[target] { return cached }
        guard let area = try await MunicipalityBoundaryLookup.shared.area(codes: target.areaCodes),
              let region = area.searchRegion else {
            throw SearchError.areaUnavailable
        }

        var candidates: [SpotCandidate] = []
        var lastError: Error?
        var hasSucceeded = false
        // 検索を1回行い、失敗しても他の検索の結果で選べるよう、エラーは覚えておくだけにする。
        func run(_ request: MKLocalSearch, label: String) async throws {
            do {
                candidates += try await search(request, in: area)
                hasSucceeded = true
            } catch {
                try Task.checkCancellation()
                lastError = error
                logger.error("\(target.municipalityName, privacy: .public): \(label, privacy: .public)の検索に失敗 \(error.localizedDescription, privacy: .public)")
            }
        }
        func selected() -> [YorimichiSpot] {
            YorimichiSpotRanking.select(candidates, municipalityCode: target.code)
        }

        // 1〜2. 名所を語で探す。範囲の外(隣の市など)の有名な施設が優先されないよう範囲内に限り、最終的な判定はポリゴンで行う。
        for query in Self.queries {
            let strongCount = selected().filter { $0.experience.baseScore >= Self.strongScore }.count
            guard strongCount < Self.enoughStrongSpots else { break }
            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = query
            request.region = region
            request.resultTypes = .pointOfInterest
            request.regionPriority = .required
            try await run(MKLocalSearch(request: request), label: query)
        }

        // 3. それでも3件に満たなければ公園で埋める。
        if selected().count < YorimichiSpotRanking.maximumCount {
            let request = MKLocalPointsOfInterestRequest(coordinateRegion: region)
            request.pointOfInterestFilter = MKPointOfInterestFilter(including: [.park])
            try await run(MKLocalSearch(request: request), label: "公園")
        }

        // 1回も検索できなかったときは失敗として伝える(0件と区別し、次に開いたときに取り直せるようキャッシュしない)。
        if !hasSucceeded, let lastError { throw lastError }
        let spots = selected()
        cache[target] = spots
        logger.info("\(target.municipalityName, privacy: .public): 候補\(candidates.count)件から\(spots.count)件")
        return spots
    }

    /// 検索して、区域の中にある結果だけを候補にする。`searchTimeout`を過ぎたら検索を取り消す。
    private func search(_ search: MKLocalSearch, in area: MunicipalityArea) async throws -> [SpotCandidate] {
        let timeout = Task {
            try await Task.sleep(for: Self.searchTimeout)
            search.cancel()
        }
        defer { timeout.cancel() }
        // 取り消された検索はエラーで返る。呼び出し側は他の検索の結果だけで選ぶ。
        let response = try await search.start()
        try Task.checkCancellation()
        return response.mapItems.compactMap { item in
            guard let name = item.name, area.contains(item.location.coordinate) else { return nil }
            return SpotCandidate(
                name: name,
                category: item.pointOfInterestCategory,
                coordinate: item.location.coordinate,
                address: item.address?.shortAddress,
                mapItemIdentifier: item.identifier?.rawValue
            )
        }
    }
}
