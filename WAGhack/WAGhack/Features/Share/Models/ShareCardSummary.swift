import CoreGraphics
import Foundation

/// どのレイアウトでも使う、カードの中身の要約(1.8.0 (7))。中身を少なくするため、レイアウトはこれだけで描く。
///
/// - `name`: 帯・余白・ステッカーに載せる短い名前(「名古屋市」「愛知県」「わたしの日本地図」)。
/// - `headline`: 数字・地図の見出し(「わたしの愛知県」「愛知県に来た！」)。
/// - `label`: フォトの帯に添える短い一言(「初訪問」「制覇率 55.1%」「みどころ」)。
/// - `stat`: 主役の数字1つ(豆知識はnil)。
/// - `shape`: 塗った形。
/// - `topic`: 豆知識の本文(読み物・フォトの一文に使う)。豆知識のときだけ。
struct ShareCardSummary {
    let name: String
    let headline: String
    let label: String
    let stat: ShareCardKeyStat?
    let shape: ShareCardShape
    var topic: TriviaShareCardContent? = nil
}

/// カードの主役の数字。「55.1%」を大きく、「制覇率」を見出しに、「38 / 69 市区町村」を補足の1行にする。
struct ShareCardKeyStat: Equatable {
    let value: String
    let caption: String
    var detail: String? = nil
}

/// 塗った形。境界データの本物の形(`SilhouetteMap`)で、訪れた区画を塗る。ピン・座標・住所は持たない。
struct ShareCardShape {
    /// 読み込めなかったときはnilで、アイコンを代わりに出す。
    let map: SilhouetteMap?
    let filledCodes: Set<String>
    /// 強く示す区画(都道府県の「全国の都道府県」のその県)。
    var emphasizedCodes: Set<String> = []
    /// 区画の隙間を埋める縁取りの太さ(大きく描くとき)。区画が細かい地図ほど細くする。
    let outlineWidth: CGFloat
    let placeholderSystemImage: String
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
                headline: "\(content.municipalityName) 初訪問",
                label: "初訪問",
                stat: ShareCardKeyStat(
                    value: content.visitedMunicipalityCount.formatted(), caption: "訪れた市区町村",
                    detail: "/ \(content.totalMunicipalityCount.formatted())"
                ),
                shape: ShareCardShape(map: map, filledCodes: highlightedCodes, outlineWidth: 1.2, placeholderSystemImage: "mappin.and.ellipse")
            )
        case .trivia(let content, let map, let highlightedCodes):
            return ShareCardSummary(
                name: content.municipalityName,
                headline: content.municipalityName,
                label: content.title,
                stat: nil,
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
                value: content.visitedMunicipalityCount.formatted(), caption: "訪れた市区町村",
                detail: "/ \(content.totalMunicipalityCount.formatted())　\(content.percentageText)"
            )
        case .prefectures:
            let progress = ExplorationCount(visited: content.visitedPrefectureCount, total: content.totalPrefectureCount)
            stat = ShareCardKeyStat(
                value: "\(content.visitedPrefectureCount)/\(content.totalPrefectureCount)", caption: "訪れた都道府県",
                detail: "制覇率 \(progress.percentageText)"
            )
        }
        return ShareCardSummary(
            name: "わたしの日本地図",
            headline: "わたしの日本地図",
            label: "\(stat.value) \(fill == .municipalities ? "市区町村" : "都道府県")",
            stat: stat,
            shape: ShareCardShape(
                map: fill == .municipalities ? maps.municipalityMap : maps.prefectureMap,
                filledCodes: content.visitedCodes(for: fill), outlineWidth: 0.4, placeholderSystemImage: "map.fill"
            )
        )
    }

    private func regionSummary(_ content: RegionShareCardContent, map: SilhouetteMap?) -> ShareCardSummary {
        let stat: ShareCardKeyStat
        switch content.kind {
        case .prefecture, .designatedCity:
            stat = ShareCardKeyStat(
                value: content.percentageText, caption: "制覇率",
                detail: "\(content.visitedCount.formatted()) / \(content.totalCount.formatted()) \(content.unit)"
            )
        case .nationwidePrefecture:
            stat = ShareCardKeyStat(
                value: "\(content.visitedCount)/\(content.totalCount)", caption: "訪れた都道府県",
                detail: "制覇率 \(content.percentageText)"
            )
        }
        let label = switch content.kind {
        case .prefecture, .designatedCity: "制覇率 \(content.percentageText)"
        case .nationwidePrefecture: "\(content.totalCount)都道府県中 \(content.visitedCount)"
        }
        return ShareCardSummary(
            name: content.name,
            headline: content.headline,
            label: label,
            stat: stat,
            shape: ShareCardShape(
                map: map, filledCodes: content.visitedCodes, emphasizedCodes: content.emphasizedCodes,
                outlineWidth: content.kind == .nationwidePrefecture ? 0.4 : 0.6,
                placeholderSystemImage: content.kind == .designatedCity ? "building.columns.fill" : "map.fill"
            )
        )
    }
}
