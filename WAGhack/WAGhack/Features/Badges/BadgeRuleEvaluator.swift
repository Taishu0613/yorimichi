import Foundation

/// チェックリストの1行(対象の市区町村と、訪れたかどうか)。
struct BadgeChecklistItem: Identifiable, Equatable {
    let code: String
    let name: String
    let prefectureCode: String
    let prefectureName: String
    let isVisited: Bool

    var id: String { code }
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
    func evaluate(_ summary: ExplorationSummary, definitions: [BadgeDefinition] = BadgeCatalog.all) -> [BadgeProgress] {
        definitions.map { evaluate($0, summary: summary) }
    }

    private func evaluate(_ definition: BadgeDefinition, summary: ExplorationSummary) -> BadgeProgress {
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
            let lookup = MunicipalityLookup(summary)
            let checklist = codes.map(lookup.item(for:))
            return BadgeProgress(
                definition: definition, value: checklist.filter(\.isVisited).count, checklist: checklist
            )
        case .visitedAreas(let areas):
            let lookup = MunicipalityLookup(summary)
            let groups = areas.map { area in
                let items = area.codes.map(lookup.item(for:))
                return BadgeChecklistGroup(name: area.name, items: items, isSatisfied: items.contains(where: \.isVisited), area: area)
            }
            return BadgeProgress(definition: definition, value: groups.filter(\.isSatisfied).count, groups: groups)
        case .sameNameGroups(let codeGroups):
            let lookup = MunicipalityLookup(summary)
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
        case .comingSoon:
            return BadgeProgress(definition: definition, value: nil)
        }
    }
}

/// 行政区域コードから、名前と訪問済みかどうかを引く。対象リストはコードだけを持つので、表示の名前はマスタから引く。
private struct MunicipalityLookup {
    private var municipalities: [String: ExplorationMunicipality] = [:]
    private var visitedCodes: Set<String> = []

    init(_ summary: ExplorationSummary) {
        for prefecture in summary.prefectures {
            for municipality in prefecture.municipalities {
                municipalities[municipality.code] = municipality
            }
            visitedCodes.formUnion(prefecture.visitedCodes)
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
            isVisited: visitedCodes.contains(code)
        )
    }
}
