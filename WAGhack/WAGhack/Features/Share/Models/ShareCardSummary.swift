import CoreGraphics
import Foundation

/// まとまり(`ShareCardPanel`)とステッカーに載せる中身の要約(1.8.0 (8))。中身を少なくするため、描く側はこれだけで描く。
///
/// - `name`: 大きく載せる名前(「名古屋市」「愛知県」「わたしの日本地図」)。
/// - `label`: 小さな見出し(「初訪問」「みどころ」「制覇率」)。
/// - `stat`: 制覇率のカードの大きな数字(%)とn/N。ほかはnil。
/// - `shape`: その範囲だけの形(「県の中の位置」はシェア画面が`ShareCardModel.locationShape`で差し替える)。
/// - `topic`: 豆知識の本文。豆知識のときだけ。
/// - `firstVisitDateText`: 初訪問の「初めて訪れた日 yyyy.MM.dd」。確かな日が分かるときだけ。
struct ShareCardSummary {
    let name: String
    let label: String
    var stat: ShareCardKeyStat? = nil
    let shape: ShareCardShape
    var topic: TriviaShareCardContent? = nil
    var firstVisitDateText: String? = nil
}

/// 制覇率のカードの数字。「55.1%」を大きく、「38 / 69 市区町村」を下に1行。
struct ShareCardKeyStat: Equatable {
    let value: String
    let detail: String
}

/// 塗った形。境界データの本物の形(`SilhouetteMap`)で、訪れた区画を塗る。ピン・座標・住所は持たない。
struct ShareCardShape {
    /// 読み込めなかったときはnilで、アイコンを代わりに出す。
    let map: SilhouetteMap?
    let filledCodes: Set<String>
    /// 強く示す区画(都道府県の「全国の都道府県」のその県)。
    var emphasizedCodes: Set<String> = []
    /// 区画の隙間を埋める縁取りの太さ。区画が細かい地図ほど細くする。
    let outlineWidth: CGFloat
    let placeholderSystemImage: String
    /// 一回り大きな範囲の中の位置を示す形か(塗っていない区画を薄く塗りつぶして描く)。
    var isLocation = false
}

extension ShareCardSubject {
    var summary: ShareCardSummary {
        switch self {
        case .japan(let content, let fill, let maps):
            return japanSummary(content, fill: fill, maps: maps)
        case .region(let content, let map):
            return regionSummary(content, map: map)
        case .firstVisit(let content, let map, let highlightedCodes):
            return ShareCardSummary(
                name: content.municipalityName,
                label: "初訪問",
                shape: ShareCardShape(map: map, filledCodes: highlightedCodes, outlineWidth: 1.2, placeholderSystemImage: "mappin.and.ellipse"),
                firstVisitDateText: content.firstVisitDate.map { "初めて訪れた日 \(FirstVisitShareCardContent.dateText(for: $0))" }
            )
        case .trivia(let content, let map, let highlightedCodes):
            return ShareCardSummary(
                name: content.municipalityName,
                label: content.title,
                shape: ShareCardShape(map: map, filledCodes: highlightedCodes, outlineWidth: 1.2, placeholderSystemImage: "mappin.and.ellipse"),
                topic: content
            )
        }
    }

    private func japanSummary(_ content: ShareCardContent, fill: ShareCardFill, maps: ShareCardMaps) -> ShareCardSummary {
        let stat: ShareCardKeyStat
        switch fill {
        case .municipalities:
            stat = ShareCardKeyStat(
                value: content.percentageText,
                detail: "\(content.visitedMunicipalityCount.formatted()) / \(content.totalMunicipalityCount.formatted()) 市区町村"
            )
        case .prefectures:
            let progress = ExplorationCount(visited: content.visitedPrefectureCount, total: content.totalPrefectureCount)
            stat = ShareCardKeyStat(
                value: progress.percentageText, detail: "\(content.visitedPrefectureCount) / \(content.totalPrefectureCount) 都道府県"
            )
        }
        return ShareCardSummary(
            name: "わたしの日本地図",
            label: "制覇率",
            stat: stat,
            shape: ShareCardShape(
                map: fill == .municipalities ? maps.municipalityMap : maps.prefectureMap,
                filledCodes: content.visitedCodes(for: fill), outlineWidth: 0.4, placeholderSystemImage: "map.fill"
            )
        )
    }

    private func regionSummary(_ content: RegionShareCardContent, map: SilhouetteMap?) -> ShareCardSummary {
        // 全国の都道府県は数えるのが全国の都道府県なので、県名だけだと県の制覇率に見える。見出し(「愛知県に来た！」)にする。
        let name = content.kind == .nationwidePrefecture ? content.headline : content.name
        return ShareCardSummary(
            name: name,
            label: "制覇率",
            stat: ShareCardKeyStat(
                value: content.percentageText,
                detail: "\(content.visitedCount.formatted()) / \(content.totalCount.formatted()) \(content.unit)"
            ),
            shape: ShareCardShape(
                map: map, filledCodes: content.visitedCodes, emphasizedCodes: content.emphasizedCodes,
                outlineWidth: content.kind == .nationwidePrefecture ? 0.4 : 0.6,
                placeholderSystemImage: content.kind == .designatedCity ? "building.columns.fill" : "map.fill"
            )
        )
    }
}
