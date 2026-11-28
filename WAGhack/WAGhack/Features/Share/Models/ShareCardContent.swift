import Foundation

/// シェア用カードに載せる数字と文言。
///
/// 旅の記録の集計(`ExplorationSummary`)から作る。プライバシーのため、ピン・座標・住所・訪問日時は持たせない
/// (塗る区画のコードと件数だけ)。カードの日付は「この画像を作った日」で、訪問日ではない。
struct ShareCardContent: Equatable {
    let visitedMunicipalityCount: Int
    let totalMunicipalityCount: Int
    let visitedPrefectureCount: Int
    let totalPrefectureCount: Int
    /// 市区町村をすべて訪れた都道府県の数(地図の塗りの「完全踏破」と同じ基準)。
    let completedPrefectureCount: Int
    /// 全国の市区町村踏破率の称号(`ExplorationCount.achievementText`)。
    let achievementText: String
    let percentageText: String
    let fraction: Double
    /// 塗る市区町村の行政区域コード(踏破率に数える市区町村だけ。政令指定都市は区)。
    let visitedMunicipalityCodes: Set<String>
    /// 塗る都道府県のコード(2桁)。都道府県単独の記録も含む。
    let visitedPrefectureCodes: Set<String>
    /// カードに入れる日付の文字列(作った日)。
    let dateText: String

    init(summary: ExplorationSummary, date: Date, calendar: Calendar = .current) {
        let progress = summary.progress
        visitedMunicipalityCount = progress.visited
        totalMunicipalityCount = progress.total
        visitedPrefectureCount = summary.prefectureProgress.visited
        totalPrefectureCount = summary.prefectureProgress.total
        completedPrefectureCount = summary.prefectures.filter { PrefectureConquestLevel($0) == .complete }.count
        achievementText = progress.achievementText
        percentageText = progress.percentageText
        fraction = progress.fraction
        visitedMunicipalityCodes = summary.prefectures.reduce(into: Set<String>()) { $0.formUnion($1.visitedCodes) }
        visitedPrefectureCodes = Set(summary.visitedPrefectures.map(\.code))
        dateText = Self.dateText(for: date, calendar: calendar)
    }

    /// 選んだ塗りで塗る区画のコード。
    func visitedCodes(for fill: ShareCardFill) -> Set<String> {
        switch fill {
        case .municipalities: visitedMunicipalityCodes
        case .prefectures: visitedPrefectureCodes
        }
    }

    /// 画像と一緒に共有する文。ハッシュタグとApp Storeのリンクを添えて、見た人がアプリに辿り着けるようにする。
    var shareText: String {
        let headline = visitedMunicipalityCount > 0
            ? "日本の\(visitedMunicipalityCount)市区町村を訪れました #よりみち"
            // 0件で「0市区町村を訪れました」と出すと寂しいので、旅のはじまりとして書く。
            : "よりみちで日本の市区町村めぐりをはじめました #よりみち"
        return "\(headline)\n\(Self.appStoreURL.absoluteString)"
    }

    /// よりみちのApp Storeのページ。
    static let appStoreURL = URL(string: "https://apps.apple.com/jp/app/id6805073599")!

    /// 「2026年11月27日」の形。端末の言語設定によらず、カードの他の文言と同じ日本語にする。
    static func dateText(for date: Date, calendar: Calendar) -> String {
        var style = Date.FormatStyle(date: .long, time: .omitted, locale: Locale(identifier: "ja_JP"), calendar: Calendar(identifier: .gregorian))
        style.timeZone = calendar.timeZone
        return date.formatted(style)
    }
}
