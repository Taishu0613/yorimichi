import Foundation

/// 初訪問のシェア用カードに載せるもの。「〇〇市 初訪問」と、全国で訪れた市区町村の数。
///
/// 訪れた日は載せない(カードの日付も入れない)。後から図鑑で開いても作れるため、作った日を載せると訪問日に見えてしまう。
struct FirstVisitShareCardContent: Hashable {
    let municipalityName: String
    let prefectureName: String
    let visitedMunicipalityCount: Int
    let totalMunicipalityCount: Int
    let percentageText: String

    init(municipalityName: String, prefectureName: String, progress: ExplorationCount) {
        self.municipalityName = municipalityName
        self.prefectureName = prefectureName
        visitedMunicipalityCount = progress.visited
        totalMunicipalityCount = progress.total
        percentageText = progress.percentageText
    }

    /// 画像と一緒に共有する文。
    var shareText: String {
        let headline = visitedMunicipalityCount > 0
            ? "\(municipalityName)に初訪問！ これで全国\(visitedMunicipalityCount)市区町村 #よりみち"
            : "\(municipalityName)に初訪問！ #よりみち"
        return "\(headline)\n\(ShareCardContent.appStoreURL.absoluteString)"
    }
}
