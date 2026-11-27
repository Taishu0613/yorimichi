import Foundation

/// 都道府県・政令指定都市のシェア用カードに載せる数字と文言。
///
/// 都道府県は市区町村、政令指定都市は区を単位に数える。どちらも「区画を塗った地図＋制覇率」の同じ形のカードにするので、
/// 1つの型にまとめて単位の言葉(`unit`)だけを変える。
/// 全国のカード(`ShareCardContent`)と同じく、ピン・座標・住所・訪問日時は持たせない(塗る区画のコードと件数だけ)。
struct RegionShareCardContent: Equatable {
    enum Kind: Equatable {
        case prefecture
        case designatedCity
    }

    let kind: Kind
    /// 都道府県コード(2桁)、または政令指定都市そのものの行政区域コード(5桁)。
    let code: String
    let name: String
    let visitedCount: Int
    let totalCount: Int
    let percentageText: String
    let fraction: Double
    /// 制覇率の称号(`ExplorationCount.achievementText`。「50%達成」「完全踏破」など)。
    let achievementText: String
    /// 次の節目までの残り(`ExplorationCount.nextGoalText`。「あと3市区町村で75%達成」など)。
    let nextGoalText: String
    /// 塗る区画の行政区域コード(都道府県は市区町村、政令指定都市は区)。
    let visitedCodes: Set<String>
    /// カードに入れる日付(作った日)。訪問日ではない。
    let dateText: String

    init(prefecture: PrefectureExploration, date: Date, calendar: Calendar = .current) {
        self.init(
            kind: .prefecture, code: prefecture.code, name: prefecture.name,
            progress: prefecture.progress, visitedCodes: prefecture.visitedCodes, date: date, calendar: calendar
        )
    }

    init(city: DesignatedCityExploration, date: Date, calendar: Calendar = .current) {
        self.init(
            kind: .designatedCity, code: city.code, name: city.name,
            progress: city.progress, visitedCodes: city.visitedWardCodes, date: date, calendar: calendar
        )
    }

    private init(kind: Kind, code: String, name: String, progress: ExplorationCount, visitedCodes: Set<String>, date: Date, calendar: Calendar) {
        self.kind = kind
        self.code = code
        self.name = name
        visitedCount = progress.visited
        totalCount = progress.total
        percentageText = progress.percentageText
        fraction = progress.fraction
        achievementText = progress.achievementText
        nextGoalText = progress.nextGoalText(unit: kind.unit)
        self.visitedCodes = visitedCodes
        dateText = ShareCardContent.dateText(for: date, calendar: calendar)
    }

    var unit: String { kind.unit }

    /// カードの見出し。
    var headline: String {
        switch kind {
        case .prefecture: "わたしの\(name)"
        case .designatedCity: "\(name)の区めぐり"
        }
    }

    /// 画像と一緒に共有する文。全国のカードと同じく、ハッシュタグとApp Storeのリンクを添える。
    var shareText: String {
        let headline = visitedCount > 0
            ? "\(name)の\(visitedCount)/\(totalCount)\(unit)を訪れました(\(percentageText)) #よりみち"
            // 都道府県単独の記録だけで市区町村が0件のときは、「0/54」と書かず旅のはじまりとして書く。
            : "よりみちで\(name)の\(unit)めぐりをはじめました #よりみち"
        return "\(headline)\n\(ShareCardContent.appStoreURL.absoluteString)"
    }
}

private extension RegionShareCardContent.Kind {
    var unit: String {
        switch self {
        case .prefecture: "市区町村"
        case .designatedCity: "区"
        }
    }
}
