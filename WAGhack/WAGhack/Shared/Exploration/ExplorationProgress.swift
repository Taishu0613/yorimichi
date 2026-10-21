import Foundation

/// 表示と集計の共通単位。SwiftDataやViewに依存しないため、集計規則を単独で検証できる。
struct ExplorationMunicipality: Identifiable {
    let code: String
    let name: String
    let prefectureCode: String
    let prefectureName: String
    let isPrefecture: Bool

    var id: String { code }
}

struct ExplorationCount {
    let visited: Int
    let total: Int

    var fraction: Double {
        guard total > 0 else { return 0 }
        return Double(visited) / Double(total)
    }

    var percentageText: String {
        fraction.formatted(.percent.precision(.fractionLength(1)))
    }

    var achievementText: String {
        guard visited > 0 else { return "旅のはじまり" }
        if visited == total { return "完全踏破" }
        if fraction >= 0.75 { return "75%達成" }
        if fraction >= 0.5 { return "50%達成" }
        if fraction >= 0.25 { return "25%達成" }
        return "初訪問達成"
    }

    /// 都道府県カード・市区町村カードの両方で使うため、単位を呼び出し側から渡す。
    func nextGoalText(unit: String) -> String {
        guard total > 0 else { return "対象の\(unit)がありません" }
        guard visited > 0 else { return "まずは1つの\(unit)を訪れよう" }
        for percentage in [25, 50, 75, 100] {
            // 切り上げて、目標の割合に実際に到達する訪問数を求める。
            let target = (total * percentage + 99) / 100
            if target > visited {
                return "あと\(target - visited)\(unit)で\(percentage)%達成"
            }
        }
        return "すべての\(unit)を訪れました！"
    }
}

struct PrefectureExploration: Identifiable {
    let code: String
    let name: String
    let municipalities: [ExplorationMunicipality]
    let visitedCodes: Set<String>
    /// 市区町村を1件も訪れていなくても、都道府県単独の記録(VisitedPrefecture)があればtrue。
    let isExplicitlyVisited: Bool

    var id: String { code }
    var progress: ExplorationCount {
        ExplorationCount(visited: visitedCodes.count, total: municipalities.count)
    }
    /// 図鑑は集める体験のため、訪問済みの市区町村だけを一覧に出す。
    var visitedMunicipalities: [ExplorationMunicipality] {
        municipalities.filter { visitedCodes.contains($0.code) }
    }
    /// 市区町村の記録・都道府県単独の記録のどちらか一方でもあれば「訪問済み」。
    var isVisited: Bool {
        !visitedCodes.isEmpty || isExplicitlyVisited
    }
    /// この都道府県にある政令指定都市。区の記録から市の訪問を求めたもので、踏破率(`progress`)には影響しない。
    var designatedCities: [DesignatedCityExploration] = []
}

/// 政令指定都市1つ分の訪問状況。記録は区で行い、区を1つでも訪れれば市も訪問済みとみなす。
/// 市の訪問は保存せず、区の記録から毎回求める(記録の正本を1つに保つため。過去の記録にもそのまま反映される)。
struct DesignatedCityExploration: Identifiable {
    /// マスタの市そのもの(例: 名古屋市 23100)の行政区域コード。
    let code: String
    let name: String
    let prefectureCode: String
    /// 区をコード順に並べたもの。
    let wards: [ExplorationMunicipality]
    let visitedWardCodes: Set<String>
    /// 区を特定できず、市そのもののコードで記録された訪問があるか。
    let isCityRecorded: Bool

    var id: String { code }
    /// 地図の境界(区の名前しか持たない)と突き合わせるためのキー。
    var key: String { DesignatedCity.key(prefectureCode: prefectureCode, cityName: name) }
    var progress: ExplorationCount {
        ExplorationCount(visited: visitedWardCodes.count, total: wards.count)
    }
    var isVisited: Bool {
        !visitedWardCodes.isEmpty || isCityRecorded
    }
    /// すべての区を訪れたか。
    var isComplete: Bool {
        !wards.isEmpty && visitedWardCodes.count == wards.count
    }
}

/// 政令指定都市と区の名前の規則。マスタも境界データも「名古屋市中区」のように市名＋区名で持つ。
nonisolated enum DesignatedCity {
    /// 区の名前から市の名前(例: 「名古屋市中区」→「名古屋市」)を返す。政令指定都市の区でなければnil。
    /// 東京都の特別区(「千代田区」)は「市」を含まないので対象外になる。
    static func cityName(ofWard name: String) -> String? {
        guard name.hasSuffix("区"), let cityEnd = name.firstIndex(of: "市") else { return nil }
        return String(name[...cityEnd])
    }

    static func key(prefectureCode: String, cityName: String) -> String {
        "\(prefectureCode)/\(cityName)"
    }
}

struct ExplorationSummary {
    let prefectures: [PrefectureExploration]
    let eligibleCodes: Set<String>

    var progress: ExplorationCount {
        ExplorationCount(
            visited: prefectures.reduce(0) { $0 + $1.progress.visited },
            total: eligibleCodes.count
        )
    }

    var visitedPrefectureCount: Int {
        prefectures.filter(\.isVisited).count
    }

    var prefectureProgress: ExplorationCount {
        ExplorationCount(visited: visitedPrefectureCount, total: prefectures.count)
    }

    /// 図鑑は集める体験のため、訪問済みの都道府県だけを一覧に出す。
    var visitedPrefectures: [PrefectureExploration] {
        prefectures.filter(\.isVisited)
    }

    var designatedCities: [DesignatedCityExploration] {
        prefectures.flatMap(\.designatedCities)
    }

    var designatedCityProgress: ExplorationCount {
        let cities = designatedCities
        return ExplorationCount(visited: cities.filter(\.isVisited).count, total: cities.count)
    }
}

struct ExplorationProgressCalculator {
    func summarize(
        municipalities: [ExplorationMunicipality],
        visitedCodes: Set<String>,
        explicitlyVisitedPrefectureCodes: Set<String> = []
    ) -> ExplorationSummary {
        let candidates = municipalities.filter { !$0.isPrefecture && !$0.name.isEmpty }
        let grouped = Dictionary(grouping: candidates, by: \.prefectureCode)
        var prefectures: [PrefectureExploration] = []
        var eligibleCodes: Set<String> = []

        for code in grouped.keys.sorted() {
            guard let members = grouped[code] else { continue }
            // マスタには政令指定都市とその区が併存する。区を持つ市は分母から除き、
            // 市の訪問だけで全区を訪問扱いにしない。東京都の特別区はそのまま対象。
            let citiesWithWards = Set(members.compactMap { DesignatedCity.cityName(ofWard: $0.name) })
            let eligible = members.filter { !citiesWithWards.contains($0.name) }
            // 同じ行政区域コードの重複は進捗へ影響させない。
            var unique: [String: ExplorationMunicipality] = [:]
            for municipality in eligible where unique[municipality.code] == nil {
                unique[municipality.code] = municipality
            }
            let sorted = unique.values.sorted { $0.code < $1.code }
            guard let first = sorted.first else { continue }
            let codes = Set(sorted.map(\.code))
            eligibleCodes.formUnion(codes)
            let designatedCities = members
                .filter { citiesWithWards.contains($0.name) }
                .sorted { $0.code < $1.code }
                .map { city in
                    let wards = sorted.filter { DesignatedCity.cityName(ofWard: $0.name) == city.name }
                    return DesignatedCityExploration(
                        code: city.code, name: city.name, prefectureCode: code, wards: wards,
                        visitedWardCodes: visitedCodes.intersection(wards.map(\.code)),
                        isCityRecorded: visitedCodes.contains(city.code)
                    )
                }
            prefectures.append(PrefectureExploration(
                code: code,
                name: first.prefectureName,
                municipalities: sorted,
                visitedCodes: visitedCodes.intersection(codes),
                isExplicitlyVisited: explicitlyVisitedPrefectureCodes.contains(code),
                designatedCities: designatedCities
            ))
        }
        return ExplorationSummary(prefectures: prefectures, eligibleCodes: eligibleCodes)
    }
}
