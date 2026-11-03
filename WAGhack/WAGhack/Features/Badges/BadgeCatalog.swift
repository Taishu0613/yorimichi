import SwiftUI

/// 全バッジの定義と、判定に使う対象地域のデータ。閾値・対象は製品として確定していない(暫定)ため、ここだけを変えれば済むようにする。
///
/// Phase 1で判定するのは、既存の訪問履歴から判定できる5種(はじめの足あと・足あとコレクター・県またぎの旅人・地元の探検家・東京23区の旅)。
/// 残りの5種は`comingSoon`にして、一覧では絵柄と名前だけを見せる(獲得済みと誤認させない)。
enum BadgeCatalog {
    /// 東京23特別区の行政区域コード(千代田区13101〜江戸川区13123)。
    static let tokyoSpecialWardCodes: [String] = (101...123).map { "13\($0)" }

    /// 東京23区の真ん中あたり。詳細の「地図で未訪問の街を探す」で23区全体を見せるのに使う。
    static let tokyoSpecialWardsCenter = (latitude: 35.685, longitude: 139.735)
    /// 23区全体(東西・南北とも約35km)が収まる表示範囲。
    static let tokyoSpecialWardsSpanMeters: Double = 36_000

    static let all: [BadgeDefinition] = [
        BadgeDefinition(
            id: .firstStep,
            name: "はじめの足あと",
            summary: "最初の一歩を記念しよう",
            category: "はじめて",
            criterion: .visitedMunicipalityCount,
            tiers: [1],
            unit: "市区町村",
            artwork: BadgeArtwork(symbolName: "shoeprints.fill", primary: .teal, accent: .mint),
            conditionText: { _ in "市区町村をひとつ訪れる" }
        ),
        BadgeDefinition(
            id: .footprintCollector,
            name: "足あとコレクター",
            summary: "全国に足あとを増やそう",
            category: "コレクション",
            criterion: .visitedMunicipalityCount,
            tiers: [10, 50, 100, 500],
            unit: "市区町村",
            artwork: BadgeArtwork(symbolName: "map.fill", primary: Color(red: 0.16, green: 0.60, blue: 0.62), accent: BadgeRank.gold.ringColor),
            conditionText: { "市区町村を\($0)か所訪れる" }
        ),
        BadgeDefinition(
            id: .prefectureTraveler,
            name: "県またぎの旅人",
            summary: "県境を越えて旅を広げよう",
            category: "広域探索",
            criterion: .visitedPrefectureCount,
            tiers: [2, 5, 10, 47],
            unit: "都道府県",
            artwork: BadgeArtwork(
                symbolName: "point.bottomleft.forward.to.point.topright.scurvepath.fill",
                primary: Color(red: 0.35, green: 0.66, blue: 0.90), accent: .orange
            ),
            conditionText: { $0 == 47 ? "47都道府県すべてを訪れる" : "\($0)つの都道府県を訪れる" }
        ),
        BadgeDefinition(
            id: .localExplorer,
            name: "地元の探検家",
            summary: "ひとつの地域を深掘りしよう",
            category: "地域探索",
            criterion: .municipalitiesInOnePrefecture,
            tiers: [10],
            unit: "市区町村",
            artwork: BadgeArtwork(symbolName: "magnifyingglass", primary: Color(red: 0.36, green: 0.66, blue: 0.36), accent: Color(red: 0.98, green: 0.94, blue: 0.82)),
            conditionText: { "同じ都道府県の市区町村を\($0)か所訪れる" }
        ),
        BadgeDefinition(
            id: .helloMetropolis,
            name: "都会にこんにちは",
            summary: "東京の3つの副都心を歩こう",
            category: "地域探索",
            criterion: .comingSoon,
            tiers: [3],
            unit: "区",
            artwork: BadgeArtwork(symbolName: "building.2.fill", primary: Color(red: 0.16, green: 0.24, blue: 0.48), accent: Pop.yellow),
            conditionText: { _ in "新宿区・渋谷区・豊島区をすべて訪れる" }
        ),
        BadgeDefinition(
            id: .tokyo23,
            name: "東京23区の旅",
            summary: "東京の区をひとつずつ集めよう",
            category: "地域制覇",
            criterion: .visitedTargets(codes: tokyoSpecialWardCodes),
            tiers: [5, 10, 23],
            unit: "区",
            artwork: BadgeArtwork(symbolName: "puzzlepiece.fill", primary: Color(red: 0.20, green: 0.42, blue: 0.80), accent: BadgeRank.gold.ringColor),
            conditionText: { $0 == 23 ? "東京23区をすべて訪れる" : "東京23区のうち\($0)区を訪れる" }
        ),
        BadgeDefinition(
            id: .twinTowns,
            name: "ふたごのまち",
            summary: "離れた土地の同じ名前を探そう",
            category: "発見",
            criterion: .comingSoon,
            tiers: [1],
            unit: "組",
            artwork: BadgeArtwork(symbolName: "rectangle.portrait.on.rectangle.portrait.fill", primary: Color(red: 0.62, green: 0.56, blue: 0.86), accent: Color(red: 0.35, green: 0.55, blue: 0.90)),
            conditionText: { _ in "ちがう都道府県にある同じ名前の市区町村を1組訪れる" }
        ),
        BadgeDefinition(
            id: .numberTraveler,
            name: "数字の旅人",
            summary: "地名に隠れた数字を集めよう",
            category: "発見",
            criterion: .comingSoon,
            tiers: [3],
            unit: "市区町村",
            artwork: BadgeArtwork(symbolName: "number", primary: Color(red: 0.90, green: 0.36, blue: 0.24), accent: Color(red: 0.98, green: 0.94, blue: 0.82)),
            conditionText: { "数字にちなむ市区町村を\($0)か所訪れる" }
        ),
        BadgeDefinition(
            id: .tripleBoundary,
            name: "超・境目！",
            summary: "3つの街の交点に立とう",
            category: "特殊探索",
            criterion: .comingSoon,
            tiers: [1],
            unit: "地点",
            artwork: BadgeArtwork(symbolName: "point.3.connected.trianglepath.dotted", primary: Color(red: 0.92, green: 0.72, blue: 0.10), accent: .teal),
            conditionText: { _ in "3つの市区町村が接する地点の近くまで行く" }
        ),
        BadgeDefinition(
            id: .threeCapitals,
            name: "三都物語",
            summary: "3つの都市をつなぐ旅をしよう",
            category: "周遊",
            criterion: .comingSoon,
            tiers: [3],
            unit: "都市",
            artwork: BadgeArtwork(symbolName: "point.3.filled.connected.trianglepath.dotted", primary: Color(red: 0.50, green: 0.30, blue: 0.70), accent: BadgeRank.gold.ringColor),
            conditionText: { _ in "東京23区・京都市・大阪市をそれぞれ訪れる" }
        ),
    ]

    static func definition(for id: BadgeID) -> BadgeDefinition? {
        all.first { $0.id == id }
    }
}
