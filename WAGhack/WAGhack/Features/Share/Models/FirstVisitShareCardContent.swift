import Foundation

/// 初訪問のシェア用カードに載せるもの。「〇〇市」「初めて訪れた日」と、共有する文に入れる全国で訪れた市区町村の数。
///
/// 初めて訪れた日(`firstVisitDate`)は、確かな日が分かるときだけ渡す(1.8.0 (8))。訪問記録(`SavedPlace.savedAt`)は
/// 訪れ直すたびに書き換わるため、初訪問の日としては使えない。分かるのは記録した直後(初訪問のお祝い)だけで、
/// それ以外(図鑑から開いたとき)はnilにして日付を出さず「初訪問」とだけ書く。作った日は載せない(訪問日に見えるため)。
struct FirstVisitShareCardContent: Hashable {
    let municipalityName: String
    let prefectureName: String
    let visitedMunicipalityCount: Int
    let totalMunicipalityCount: Int
    let percentageText: String
    let firstVisitDate: Date?

    init(municipalityName: String, prefectureName: String, progress: ExplorationCount, firstVisitDate: Date? = nil) {
        self.municipalityName = municipalityName
        self.prefectureName = prefectureName
        visitedMunicipalityCount = progress.visited
        totalMunicipalityCount = progress.total
        percentageText = progress.percentageText
        self.firstVisitDate = firstVisitDate
    }

    /// カードに載せる日付(「2026.11.28」)。端末の暦や言語によらず西暦で書く。
    static func dateText(for date: Date, timeZone: TimeZone = .current) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy.MM.dd"
        return formatter.string(from: date)
    }

    /// 小さい箱(1.8.0 (10))で名前の下に1行にまとめる記録。「初訪問 · 愛知県 · 2026.11.28 · 全国 124/1,918 (6.5%)」。
    /// 箱を小さくしても情報は減らさず、並べ方で詰める(標準の箱に載せるものと同じ)。都道府県・日付は分かるときだけ。
    func compactSummaryText(timeZone: TimeZone = .current) -> String {
        var parts = ["初訪問"]
        if !prefectureName.isEmpty { parts.append(prefectureName) }
        if let firstVisitDate { parts.append(Self.dateText(for: firstVisitDate, timeZone: timeZone)) }
        parts.append("全国 \(visitedMunicipalityCount.formatted())/\(totalMunicipalityCount.formatted()) (\(percentageText))")
        return parts.joined(separator: " · ")
    }

    /// 画像と一緒に共有する文。
    var shareText: String {
        let headline = visitedMunicipalityCount > 0
            ? "\(municipalityName)に初訪問！ これで全国\(visitedMunicipalityCount)市区町村 #よりみち"
            : "\(municipalityName)に初訪問！ #よりみち"
        return "\(headline)\n\(ShareCardContent.appStoreURL.absoluteString)"
    }
}
