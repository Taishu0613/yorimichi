import SwiftUI

/// 全バッジの定義と、判定に使う対象地域のデータ。閾値・対象は製品として確定していない(暫定)ため、ここだけを変えれば済むようにする。
///
/// 対象の長いリスト(同じ名前の組・数字ごとの街・京都市と大阪市の区)は`BadgeCatalogData.swift`にある。
enum BadgeCatalog {
    /// 東京23特別区の行政区域コード(千代田区13101〜江戸川区13123)。
    static let tokyoSpecialWardCodes: [String] = (101...123).map { "13\($0)" }

    /// 東京23区。23区全体(東西・南北とも約35km)が収まる範囲。
    static let tokyoSpecialWards = BadgeArea(
        name: "東京23区", codes: tokyoSpecialWardCodes, latitude: 35.685, longitude: 139.735, spanMeters: 36_000
    )
    /// 東京の三大副都心。池袋・新宿・渋谷は市区町村ではないので、暫定でそれぞれ豊島区・新宿区・渋谷区のどこかを記録すれば訪れたことにする。
    /// 駅の周りだけで判定するには、記録した場所の座標と範囲を持つ必要がある(未決定)。
    static let subcenterSpots = [
        BadgeThemeSpot(label: "池袋", code: "13116"),
        BadgeThemeSpot(label: "新宿", code: "13104"),
        BadgeThemeSpot(label: "渋谷", code: "13113"),
    ]
    static let subcenters = BadgeArea(
        name: "東京の副都心", codes: subcenterSpots.map(\.code), latitude: 35.700, longitude: 139.705, spanMeters: 10_000
    )
    /// 超・境目！で、記録した場所どうしの距離の上限。GPSの誤差(数十m)より十分に大きくしてある(暫定)。
    static let nearbyMunicipalityDistanceMeters: Double = 1_000
    static let kyotoCity = BadgeArea(
        name: "京都市", codes: kyotoWardCodes, latitude: 35.010, longitude: 135.755, spanMeters: 22_000
    )
    static let osakaCity = BadgeArea(
        name: "大阪市", codes: osakaWardCodes, latitude: 34.675, longitude: 135.500, spanMeters: 20_000
    )

    static let all: [BadgeDefinition] = [
        BadgeDefinition(
            id: .firstStep,
            name: "はじめの足あと",
            summary: "最初の一歩を記念しよう",
            category: .footprints,
            criterion: .visitedMunicipalityCount,
            tiers: [1],
            unit: "市区町村",
            artwork: BadgeArtwork(symbolName: "shoeprints.fill", secondarySymbolName: "signpost.right.fill", primary: .teal, accent: .mint),
            conditionText: { _ in "市区町村をひとつ訪れる" },
            hint: "地図の下の「この場所を記録する」から、今いる街を記録してみよう。"
        ),
        BadgeDefinition(
            id: .footprintCollector,
            name: "足あとコレクター",
            summary: "全国に足あとを増やそう",
            category: .footprints,
            criterion: .visitedMunicipalityCount,
            tiers: [10, 50, 100, 500],
            unit: "市区町村",
            artwork: BadgeArtwork(symbolName: "map.fill", secondarySymbolName: "shoeprints.fill", primary: Color(red: 0.16, green: 0.60, blue: 0.62), accent: BadgeRank.gold.ringColor),
            conditionText: { "市区町村を\($0)か所訪れる" },
            hint: "通勤や買い物の途中で、となりの市区町村に寄り道するだけでも数が増えます。"
        ),
        BadgeDefinition(
            id: .prefectureTraveler,
            name: "県またぎの旅人",
            summary: "県境を越えて旅を広げよう",
            category: .footprints,
            criterion: .visitedPrefectureCount,
            tiers: [2, 5, 10, 47],
            unit: "都道府県",
            artwork: BadgeArtwork(
                symbolName: "point.bottomleft.forward.to.point.topright.scurvepath.fill",
                secondarySymbolName: "figure.walk",
                primary: Color(red: 0.35, green: 0.66, blue: 0.90), accent: .orange
            ),
            conditionText: { $0 == 47 ? "47都道府県すべてを訪れる" : "\($0)つの都道府県を訪れる" },
            hint: "県境の近くでは、橋をひとつ渡るだけで別の県に入れることもあります。"
        ),
        BadgeDefinition(
            id: .localExplorer,
            name: "地元の探検家",
            summary: "ひとつの地域を深掘りしよう",
            category: .footprints,
            criterion: .municipalitiesInOnePrefecture,
            tiers: [10],
            unit: "市区町村",
            artwork: BadgeArtwork(symbolName: "magnifyingglass", secondarySymbolName: "house.fill", primary: Color(red: 0.36, green: 0.66, blue: 0.36), accent: Color(red: 0.98, green: 0.94, blue: 0.82)),
            conditionText: { "同じ都道府県の市区町村を\($0)か所訪れる" },
            hint: "いちばん記録の多い県で、まだ塗られていない市区町村を地図で探してみよう。"
        ),
        BadgeDefinition(
            id: .helloMetropolis,
            name: "都会にこんにちは",
            summary: "池袋・新宿・渋谷、東京の三大副都心を歩こう",
            category: .geography,
            criterion: .themeSpots(subcenterSpots),
            tiers: [3],
            unit: "か所",
            artwork: BadgeArtwork(symbolName: "building.2.fill", secondarySymbolName: "hand.wave.fill", primary: Color(red: 0.16, green: 0.24, blue: 0.48), accent: Pop.yellow),
            conditionText: { _ in "池袋(豊島区)・新宿(新宿区)・渋谷(渋谷区)の3か所を訪れる。それぞれの区のどこかを記録すれば訪れたことになります" },
            mapArea: subcenters,
            hint: "3つの副都心はJR山手線でつながっています。1日で巡ることもできます。"
        ),
        BadgeDefinition(
            id: .tokyo23,
            name: "東京23区の旅",
            summary: "東京の区をひとつずつ集めよう",
            category: .geography,
            criterion: .visitedTargets(codes: tokyoSpecialWardCodes),
            tiers: [5, 10, 23],
            unit: "区",
            artwork: BadgeArtwork(symbolName: "puzzlepiece.fill", secondarySymbolName: "building.fill", primary: Color(red: 0.20, green: 0.42, blue: 0.80), accent: BadgeRank.gold.ringColor),
            conditionText: { $0 == 23 ? "東京23区をすべて訪れる" : "東京23区のうち\($0)区を訪れる" },
            mapArea: tokyoSpecialWards,
            hint: "区の境目は道1本のことも。となりの区まで歩いてみると、思ったより近く感じます。"
        ),
        BadgeDefinition(
            id: .twinTowns,
            name: "ふたごのまち",
            summary: "離れた土地の同じ名前を探そう",
            category: .placeNames,
            criterion: .sameNameGroups(twinTownGroups),
            tiers: [1],
            unit: "組",
            artwork: BadgeArtwork(symbolName: "rectangle.portrait.on.rectangle.portrait.fill", secondarySymbolName: "sparkles", primary: Color(red: 0.62, green: 0.56, blue: 0.86), accent: Color(red: 0.35, green: 0.55, blue: 0.90)),
            conditionText: { _ in "ちがう都道府県にある同じ名前の市区町村を1組訪れる" },
            hint: "府中市は東京と広島に、伊達市は北海道と福島にあります。名前は同じでも、街の顔はまったくちがいます。"
        ),
        BadgeDefinition(
            id: .numberTraveler,
            name: "数字の旅人",
            summary: "日本の街の名前に隠れた数字を探せ",
            category: .placeNames,
            criterion: .numeralCollection(numerals),
            tiers: [3, 6, 12],
            unit: "種類",
            artwork: BadgeArtwork(symbolName: "signpost.right.fill", secondarySymbolName: "number", primary: Color(red: 0.90, green: 0.36, blue: 0.24), accent: Color(red: 0.98, green: 0.94, blue: 0.82)),
            conditionText: { $0 == 12 ? "一〜十・廿・九十九の12種類をすべて集める" : "名前に入っている数字を\($0)種類集める" },
            hint: "「廿」(にじゅう)は広島県の廿日市市、「九十九」は千葉県の九十九里町だけ。いちばんの難関です。"
        ),
        BadgeDefinition(
            id: .tripleBoundary,
            name: "超・境目！",
            summary: "3つの街がぎゅっと集まる場所へ",
            category: .geography,
            criterion: .nearbyMunicipalities(maxDistanceMeters: nearbyMunicipalityDistanceMeters),
            tiers: [3],
            unit: "市区町村",
            artwork: BadgeArtwork(symbolName: "point.3.connected.trianglepath.dotted", secondarySymbolName: "mappin", primary: Color(red: 0.92, green: 0.72, blue: 0.10), accent: .teal),
            conditionText: { _ in "記録した場所がおたがい1km以内にある、3つの市区町村を訪れる" },
            hint: "市区町村の境目が集まる場所を地図で探し、境目をまたぐように歩きながら記録してみよう。同じ街を記録し直すと、記録した場所も新しい場所に変わります。"
        ),
        BadgeDefinition(
            id: .quadrupleBoundary,
            name: "超超・境目！",
            summary: "4つの街がひしめく場所へ",
            category: .geography,
            criterion: .nearbyMunicipalities(maxDistanceMeters: nearbyMunicipalityDistanceMeters),
            tiers: [4],
            unit: "市区町村",
            artwork: BadgeArtwork(symbolName: "circle.grid.2x2.fill", secondarySymbolName: "mappin", primary: Color(red: 0.93, green: 0.45, blue: 0.20), accent: .teal),
            conditionText: { _ in "記録した場所がおたがい1km以内にある、4つの市区町村を訪れる" },
            hint: "4つの市区町村が1km以内にひしめく場所は、大きな街の区の境目などに隠れています。超・境目！の3つの街の近くで、4つ目を探してみよう。"
        ),
        BadgeDefinition(
            id: .threeCapitals,
            name: "三都物語",
            summary: "3つの都市をつなぐ旅をしよう",
            category: .geography,
            criterion: .visitedAreas([tokyoSpecialWards, kyotoCity, osakaCity]),
            tiers: [3],
            unit: "都市",
            artwork: BadgeArtwork(symbolName: "point.3.filled.connected.trianglepath.dotted", secondarySymbolName: "building.columns.fill", primary: Color(red: 0.50, green: 0.30, blue: 0.70), accent: BadgeRank.gold.ringColor),
            conditionText: { _ in "東京23区・京都市・大阪市の区を、それぞれ1つ以上訪れる" },
            hint: "東京・京都・大阪は新幹線でつながっています。旅の途中で区をひとつ記録するだけで達成できます。"
        ),
    ]

    static func definition(for id: BadgeID) -> BadgeDefinition? {
        all.first { $0.id == id }
    }
}
