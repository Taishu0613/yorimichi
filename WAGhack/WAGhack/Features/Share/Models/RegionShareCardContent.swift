import Foundation

/// 都道府県・政令指定都市のシェア用カードに載せる数字と文言。
///
/// 都道府県は市区町村、政令指定都市は区を単位に数える。どちらも「区画を塗った地図＋制覇率」の同じ形のカードにするので、
/// 1つの型にまとめて単位の言葉(`unit`)だけを変える。
/// 1.8.0 (7)で、都道府県を「全国の都道府県」で見せる版(`nationwidePrefecture`)も足した。
/// 「県の中の市区町村ではなく、その県に来たことを自慢したい」という声から。日本地図の都道府県を塗り、その県を強く示す。
/// 全国のカード(`ShareCardContent`)と同じく、ピン・座標・住所・訪問日時は持たせない(塗る区画のコードと件数だけ)。
struct RegionShareCardContent: Equatable {
    enum Kind: Equatable {
        /// 県内の市区町村を塗る。
        case prefecture
        /// 政令指定都市の区を塗る。
        case designatedCity
        /// 全国の都道府県を塗り、`code`の県を強く示す。数えるのは都道府県。
        case nationwidePrefecture
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
    /// 塗る区画の行政区域コード(都道府県は市区町村、政令指定都市は区、全国の都道府県は都道府県コード)。
    let visitedCodes: Set<String>
    /// 強く示す区画(全国の都道府県のときのその県)。ほかは空。
    let emphasizedCodes: Set<String>
    /// 全国の都道府県のとき、その県を訪れたか(都道府県単独の記録を含む)。ほかはtrue扱い(見出しを変えない)。
    let isEmphasizedVisited: Bool
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

    /// 全国の都道府県の中での`prefecture`。数は都道府県の数(`summary.prefectureProgress`)、塗るのは訪れた都道府県。
    init(nationwide prefecture: PrefectureExploration, summary: ExplorationSummary, date: Date, calendar: Calendar = .current) {
        self.init(
            kind: .nationwidePrefecture, code: prefecture.code, name: prefecture.name,
            progress: summary.prefectureProgress, visitedCodes: Set(summary.visitedPrefectures.map(\.code)),
            emphasizedCodes: [prefecture.code], isEmphasizedVisited: prefecture.isVisited, date: date, calendar: calendar
        )
    }

    private init(
        kind: Kind, code: String, name: String, progress: ExplorationCount, visitedCodes: Set<String>,
        emphasizedCodes: Set<String> = [], isEmphasizedVisited: Bool = true, date: Date, calendar: Calendar
    ) {
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
        self.emphasizedCodes = emphasizedCodes
        self.isEmphasizedVisited = isEmphasizedVisited
        dateText = ShareCardContent.dateText(for: date, calendar: calendar)
    }

    var unit: String { kind.unit }

    /// カードの見出し。
    var headline: String {
        switch kind {
        case .prefecture: "わたしの\(name)"
        case .designatedCity: "\(name)の区めぐり"
        // まだ訪れていない県(この街の県として開いた場合など)に「来た！」とは書かない。
        case .nationwidePrefecture: isEmphasizedVisited ? "\(name)に来た！" : "次は\(name)へ"
        }
    }

    /// 画像と一緒に共有する文。全国のカードと同じく、ハッシュタグとApp Storeのリンクを添える。
    var shareText: String {
        "\(shareHeadline)\n\(ShareCardContent.appStoreURL.absoluteString)"
    }

    private var shareHeadline: String {
        guard visitedCount > 0 else {
            // 都道府県単独の記録だけで市区町村が0件のときは、「0/54」と書かず旅のはじまりとして書く。
            return kind == .nationwidePrefecture
                ? "よりみちで都道府県めぐりをはじめました #よりみち"
                : "よりみちで\(name)の\(unit)めぐりをはじめました #よりみち"
        }
        switch kind {
        case .prefecture, .designatedCity:
            return "\(name)の\(visitedCount)/\(totalCount)\(unit)を訪れました(\(percentageText)) #よりみち"
        case .nationwidePrefecture:
            let mention = isEmphasizedVisited ? "(\(name)も制覇)" : ""
            return "\(visitedCount)/\(totalCount)都道府県を訪れました\(mention) #よりみち"
        }
    }
}

private extension RegionShareCardContent.Kind {
    var unit: String {
        switch self {
        case .prefecture: "市区町村"
        case .designatedCity: "区"
        case .nationwidePrefecture: "都道府県"
        }
    }
}

/// 都道府県のカードで、何を数えるか(1.8.0 (7))。シェア画面の「県内の市区町村 / 全国の都道府県」。
/// シェア画面を開いている間だけ持つ(覚えておかない)。
nonisolated enum PrefectureShareFocus: String, CaseIterable, Identifiable, Hashable {
    case municipalities
    case nationwide

    var id: Self { self }

    var title: String {
        switch self {
        case .municipalities: "県内の市区町村"
        case .nationwide: "全国の都道府県"
        }
    }
}
