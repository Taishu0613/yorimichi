import CoreLocation
import Foundation

/// 記録した場所1つ。市区町村ごとに最後に記録した場所と日時(再訪すると上書きされる`SavedPlace`の値)。
struct BadgeVisitPoint {
    let code: String
    let latitude: Double
    let longitude: Double
    let recordedAt: Date
}

/// チェックリストの1行(対象の市区町村と、訪れたかどうか)。
struct BadgeChecklistItem: Identifiable, Hashable {
    let code: String
    let name: String
    let prefectureCode: String
    let prefectureName: String
    let isVisited: Bool
    /// 最後に記録した日時。訪れていなければnil。
    var recordedAt: Date? = nil

    var id: String { code }
}

/// 数字の旅人の、数字1種類の集まり具合。
struct BadgeNumeralProgress: Identifiable {
    let symbol: String
    let items: [BadgeChecklistItem]

    var id: String { symbol }
    var isCollected: Bool { items.contains(where: \.isVisited) }
}

/// テーマで巡る目的地1つの訪問状況。
struct BadgeThemeSpotProgress: Identifiable {
    let label: String
    let item: BadgeChecklistItem

    var id: String { label }
}

/// まとまりで判定する対象(三都物語の1都市、ふたごのまちの1組)。
struct BadgeChecklistGroup: Identifiable {
    let name: String
    let items: [BadgeChecklistItem]
    /// このまとまりが条件を満たしたか(都市なら1つ以上、組ならちがう都道府県で2つ以上)。
    let isSatisfied: Bool
    /// 地図で見せる地域。都市のまとまりだけが持つ。
    var area: BadgeArea? = nil

    var id: String { name + (items.first?.code ?? "") }
    var visitedCount: Int { items.filter(\.isVisited).count }
}

/// 都道府県ごとの訪問数。「地元の探検家」で、どの県がいちばん進んでいるかを見せるために使う。
struct BadgePrefectureCount: Identifiable, Equatable {
    let code: String
    let name: String
    let visited: Int

    var id: String { code }
}

/// バッジ1種類の、訪問記録から求めた今の進み具合。保存はせず、記録が変わるたびに求め直す(記録の正本はSwiftDataだけに保つ)。
struct BadgeProgress {
    let definition: BadgeDefinition
    /// 数えた値。判定がまだ無いバッジ(準備中)はnil。
    let value: Int?
    var checklist: [BadgeChecklistItem] = []
    /// まとまりごとの訪問状況(三都物語・ふたごのまち)。
    var groups: [BadgeChecklistGroup] = []
    /// 訪問数の多い順。訪れていない都道府県は含めない。
    var prefectureCounts: [BadgePrefectureCount] = []
    /// 数字の旅人の、数字ごとの集まり具合(定義の順)。
    var numerals: [BadgeNumeralProgress] = []
    /// テーマで巡る目的地ごとの訪問状況(定義の順)。
    var themeSpots: [BadgeThemeSpotProgress] = []
    /// 超・境目！で、記録した場所がおたがい近い市区町村の、いちばん大きな組(最大3つ)。
    var nearbyCluster: [BadgeChecklistItem] = []
    /// `nearbyCluster`の記録した場所のまわり。地図で「もう1つの街」を探すときに見せる範囲。
    var nearbyArea: BadgeArea? = nil
    /// 獲得したときに残す証跡。記録の更新で失われる情報(記録した場所の座標)を、獲得した時点の値で保存するために渡す。
    var evidence: BadgeEvidence? = nil

    /// 今の記録で届いている段階の数。
    var reachedTierCount: Int {
        guard let value else { return 0 }
        return definition.tiers.filter { value >= $0 }.count
    }
}

/// 訪問記録の集計(`ExplorationSummary`)から、全バッジの進み具合を求める。副作用を持たないので単独で検証できる。
///
/// 数え方は旅の記録の踏破率と同じ集計をそのまま使う。政令指定都市は区で数え、市そのものの記録(区を特定できない記録)は
/// 数えない。東京23区はそれぞれ1つの市区町村として数える。同じ市区町村の再訪は1回として数える。
struct BadgeRuleEvaluator {
    /// - Parameter visitPoints: 記録した場所。距離で判定するバッジ(超・境目！)と、記録した日の表示にだけ使う。
    func evaluate(
        _ summary: ExplorationSummary,
        visitPoints: [BadgeVisitPoint] = [],
        definitions: [BadgeDefinition] = BadgeCatalog.all
    ) -> [BadgeProgress] {
        let lookup = MunicipalityLookup(summary, visitPoints: visitPoints)
        return definitions.map { evaluate($0, summary: summary, lookup: lookup, visitPoints: visitPoints) }
    }

    private func evaluate(
        _ definition: BadgeDefinition,
        summary: ExplorationSummary,
        lookup: MunicipalityLookup,
        visitPoints: [BadgeVisitPoint]
    ) -> BadgeProgress {
        switch definition.criterion {
        case .visitedMunicipalityCount:
            return BadgeProgress(definition: definition, value: summary.progress.visited)
        case .visitedPrefectureCount:
            return BadgeProgress(definition: definition, value: summary.visitedPrefectureCount)
        case .municipalitiesInOnePrefecture:
            // 同数なら都道府県コード順(summaryの並び)を保つため、安定した並べ替えにする。
            let counts = summary.prefectures
                .filter { !$0.visitedCodes.isEmpty }
                .map { BadgePrefectureCount(code: $0.code, name: $0.name, visited: $0.visitedCodes.count) }
                .enumerated()
                .sorted { ($0.element.visited, -$0.offset) > ($1.element.visited, -$1.offset) }
                .map(\.element)
            return BadgeProgress(definition: definition, value: counts.first?.visited ?? 0, prefectureCounts: counts)
        case .visitedTargets(let codes):
            let checklist = codes.map(lookup.item(for:))
            return BadgeProgress(
                definition: definition, value: checklist.filter(\.isVisited).count, checklist: checklist
            )
        case .visitedAreas(let areas):
            let groups = areas.map { area in
                let items = area.codes.map(lookup.item(for:))
                return BadgeChecklistGroup(name: area.name, items: items, isSatisfied: items.contains(where: \.isVisited), area: area)
            }
            return BadgeProgress(definition: definition, value: groups.filter(\.isSatisfied).count, groups: groups)
        case .sameNameGroups(let codeGroups):
            let groups = codeGroups.map { codes in
                let items = codes.map(lookup.item(for:))
                let visitedPrefectures = Set(items.filter(\.isVisited).map(\.prefectureCode))
                return BadgeChecklistGroup(name: items.first?.name ?? "", items: items, isSatisfied: visitedPrefectures.count >= 2)
            }
            // 達成した組、あと1つの組、まだの組の順にする。「次に訪れるとよい組」を上に出すため。同数なら定義の順。
            let sorted = groups.enumerated()
                .sorted { ($0.element.visitedCount, -$0.offset) > ($1.element.visitedCount, -$1.offset) }
                .map(\.element)
            return BadgeProgress(definition: definition, value: groups.filter(\.isSatisfied).count, groups: sorted)
        case .numeralCollection(let numerals):
            let progresses = numerals.map { numeral in
                BadgeNumeralProgress(symbol: numeral.symbol, items: numeral.codes.map(lookup.item(for:)))
            }
            return BadgeProgress(definition: definition, value: progresses.filter(\.isCollected).count, numerals: progresses)
        case .themeSpots(let spots):
            let progresses = spots.map { BadgeThemeSpotProgress(label: $0.label, item: lookup.item(for: $0.code)) }
            return BadgeProgress(
                definition: definition, value: progresses.filter(\.item.isVisited).count, themeSpots: progresses
            )
        case .nearbyMunicipalities(let maxDistanceMeters):
            // 踏破率に含まれる市区町村の記録だけを使う(区を特定できない市の記録などは除く)。
            let points = visitPoints.filter { summary.eligibleCodes.contains($0.code) }
            let targetCount = definition.tiers.last ?? 3
            let cluster = NearbyClusterFinder(maxDistanceMeters: maxDistanceMeters)
                .largestCluster(in: points, maxSize: targetCount)
            let items = cluster.map { lookup.item(for: $0.code) }
            let evidence = cluster.count >= targetCount ? BadgeEvidence(places: zip(cluster, items).map { point, item in
                BadgeEvidence.Place(code: point.code, name: item.name, latitude: point.latitude, longitude: point.longitude)
            }) : nil
            // 組の真ん中を中心に、境目の集まる場所を探せる程度(数km)の範囲を見せる。
            let area = cluster.isEmpty ? nil : BadgeArea(
                name: "記録した場所のまわり", codes: cluster.map(\.code),
                latitude: cluster.map(\.latitude).reduce(0, +) / Double(cluster.count),
                longitude: cluster.map(\.longitude).reduce(0, +) / Double(cluster.count),
                spanMeters: maxDistanceMeters * 4
            )
            return BadgeProgress(
                definition: definition, value: cluster.count, nearbyCluster: items, nearbyArea: area, evidence: evidence
            )
        case .comingSoon:
            return BadgeProgress(definition: definition, value: nil)
        }
    }
}

/// 記録した場所がおたがい一定の距離以内にある市区町村の組を探す。
///
/// 見つけたい数(超・境目！は3、超超・境目！は4)までしか探さない。全組み合わせを比べると記録が多い人(約2,000件)で
/// 重くなるため、緯度で並べて、距離の上限より緯度が離れた相手は比べずに打ち切る。1kmの中に入る記録は多くても数件なので、
/// その中から組を探す部分は総当たりで足りる。
private struct NearbyClusterFinder {
    let maxDistanceMeters: Double

    /// おたがい近い記録のうち最も大きな組(最大`maxSize`個、緯度の順)を返す。2つしか無ければいちばん近い2つ、
    /// それも無ければ記録1つ(記録が無ければ空)。
    func largestCluster(in points: [BadgeVisitPoint], maxSize: Int) -> [BadgeVisitPoint] {
        let sorted = points.sorted { $0.latitude < $1.latitude }
        let locations = sorted.map { CLLocation(latitude: $0.latitude, longitude: $0.longitude) }
        // 緯度1度は約111km。少し余裕を持たせて打ち切る。
        let latitudeWindow = maxDistanceMeters / 110_000
        // 自分より緯度が大きい(後ろの)近い記録。おたがいの組は、いちばん前の記録から見た近い記録の中で探す。
        var neighbors: [[Int]] = Array(repeating: [], count: sorted.count)
        var closestPair: (Int, Int, Double)?
        for i in sorted.indices {
            var j = i + 1
            while j < sorted.count, sorted[j].latitude - sorted[i].latitude <= latitudeWindow {
                let distance = locations[i].distance(from: locations[j])
                if distance <= maxDistanceMeters {
                    neighbors[i].append(j)
                    if closestPair.map({ distance < $0.2 }) ?? true {
                        closestPair = (i, j, distance)
                    }
                }
                j += 1
            }
        }
        let neighborSets = neighbors.map(Set.init)
        func isNear(_ a: Int, _ b: Int) -> Bool {
            neighborSets[min(a, b)].contains(max(a, b))
        }
        /// `clique`(おたがい近い組)に、`candidates`(組の全員と近い記録)を足して広げられるだけ広げる。
        func extend(_ clique: [Int], candidates: [Int]) -> [Int] {
            guard clique.count < maxSize else { return clique }
            var best = clique
            for (index, candidate) in candidates.enumerated() {
                let rest = candidates[(index + 1)...].filter { isNear(candidate, $0) }
                let found = extend(clique + [candidate], candidates: rest)
                if found.count > best.count {
                    best = found
                    if best.count == maxSize { return best }
                }
            }
            return best
        }
        var best: [Int] = []
        for i in sorted.indices where !neighbors[i].isEmpty {
            let found = extend([i], candidates: neighbors[i])
            if found.count > best.count {
                best = found
                if best.count == maxSize { break }
            }
        }
        if best.count >= 3 {
            return best.map { sorted[$0] }
        }
        // 3つ以上の組が無いときは、どの2つでもよいので、いちばん近い2つを見せる。
        if let closestPair {
            return [sorted[closestPair.0], sorted[closestPair.1]]
        }
        return sorted.isEmpty ? [] : [sorted[0]]
    }
}

/// 行政区域コードから、名前と訪問済みかどうかを引く。対象リストはコードだけを持つので、表示の名前はマスタから引く。
private struct MunicipalityLookup {
    private var municipalities: [String: ExplorationMunicipality] = [:]
    private var visitedCodes: Set<String> = []

    private var recordedDates: [String: Date] = [:]

    init(_ summary: ExplorationSummary, visitPoints: [BadgeVisitPoint]) {
        for prefecture in summary.prefectures {
            for municipality in prefecture.municipalities {
                municipalities[municipality.code] = municipality
            }
            visitedCodes.formUnion(prefecture.visitedCodes)
        }
        for point in visitPoints {
            recordedDates[point.code] = point.recordedAt
        }
    }

    /// マスタに無いコード(マスタの更新で無くなった等)は、コードをそのまま名前にして未訪問として出す。
    func item(for code: String) -> BadgeChecklistItem {
        let municipality = municipalities[code]
        return BadgeChecklistItem(
            code: code,
            name: municipality?.name ?? code,
            prefectureCode: municipality?.prefectureCode ?? String(code.prefix(2)),
            prefectureName: municipality?.prefectureName ?? "",
            isVisited: visitedCodes.contains(code),
            recordedAt: visitedCodes.contains(code) ? recordedDates[code] : nil
        )
    }
}
