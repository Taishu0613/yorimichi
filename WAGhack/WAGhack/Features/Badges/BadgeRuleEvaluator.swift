import Foundation

/// チェックリストの1行(対象の市区町村と、訪れたかどうか)。
struct BadgeChecklistItem: Identifiable, Equatable {
    let code: String
    let name: String
    let isVisited: Bool

    var id: String { code }
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
            var names: [String: String] = [:]
            var visitedCodes: Set<String> = []
            for prefecture in summary.prefectures {
                for municipality in prefecture.municipalities {
                    names[municipality.code] = municipality.name
                }
                visitedCodes.formUnion(prefecture.visitedCodes)
            }
            let checklist = codes.map { code in
                BadgeChecklistItem(code: code, name: names[code] ?? code, isVisited: visitedCodes.contains(code))
            }
            return BadgeProgress(
                definition: definition, value: checklist.filter(\.isVisited).count, checklist: checklist
            )
        case .comingSoon:
            return BadgeProgress(definition: definition, value: nil)
        }
    }
}
