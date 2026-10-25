import CoreLocation
import MapKit

/// 市区町村の詳細画面に出す「よりみちスポット」1件。地図の検索結果から作る一時的なデータで、保存しない。
nonisolated struct YorimichiSpot: Identifiable, Hashable, Sendable {
    let name: String
    let latitude: Double
    let longitude: Double
    /// 住所の短い表記(取れた場合だけ)。
    let address: String?
    /// 区域内であることを確かめた市区町村の行政区域コード(政令指定都市の詳細では市のコード)。
    let municipalityCode: String
    let experience: SpotExperience
    /// Appleマップの地点のid(`MKMapItem.Identifier`の文字列)。Appleマップで開くとき、座標ではなく施設そのものを開くために使う。
    var mapItemIdentifier: String? = nil

    /// 同じ名前の別の地点(チェーンの店舗など)を区別できるよう、座標も含める。
    var id: String { "\(name)@\(String(format: "%.4f,%.4f", latitude, longitude))" }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

/// スポットで「何ができるか」の区分。名前・地図のカテゴリから決め、行動の短い言葉とアイコンを持つ。
///
/// 営業時間・料金・混雑のような不確かなことは言わない。区分を決められないもの(`other`)は行動の言葉を持たず、
/// 画面では施設名を主に出す。
nonisolated enum SpotExperience: String, Sendable, CaseIterable {
    case shrine
    case temple
    case castle
    case history
    case museum
    case art
    case garden
    case view
    case waterfront
    case nature
    case animals
    case hotSpring
    case park
    case landmark
    case other

    /// 「神社を散策する」のような行動の言葉。決められないときはnil。
    var actionPhrase: String? {
        switch self {
        case .shrine: "神社を散策する"
        case .temple: "お寺を参拝する"
        case .castle: "城跡を歩く"
        case .history: "歴史に触れる"
        case .museum: "展示を見る"
        case .art: "アートにふれる"
        case .garden: "庭園を眺める"
        case .view: "景色を眺める"
        case .waterfront: "水辺を眺める"
        case .nature: "自然の中を歩く"
        case .animals: "生きものに会う"
        case .hotSpring: "温泉でひと休みする"
        case .park: "公園を歩く"
        case .landmark: "名所を訪ねる"
        case .other: nil
        }
    }

    var categoryLabel: String {
        switch self {
        case .shrine: "神社"
        case .temple: "寺院"
        case .castle: "城・城跡"
        case .history: "歴史・資料館"
        case .museum: "博物館"
        case .art: "美術館"
        case .garden: "庭園"
        case .view: "展望・景色"
        case .waterfront: "海・水辺"
        case .nature: "自然"
        case .animals: "動物園・水族館"
        case .hotSpring: "温泉"
        case .park: "公園"
        case .landmark: "名所"
        case .other: "スポット"
        }
    }

    /// 写真が無いときにサムネイルの代わりに出すアイコン。
    var systemImage: String {
        switch self {
        case .shrine, .temple: "hands.and.sparkles.fill"
        case .castle: "shield.lefthalf.filled"
        case .history: "scroll.fill"
        case .museum: "building.columns.fill"
        case .art: "paintpalette.fill"
        case .garden: "leaf.fill"
        case .view: "binoculars.fill"
        case .waterfront: "water.waves"
        case .nature: "mountain.2.fill"
        case .animals: "pawprint.fill"
        case .hotSpring: "bathtub.fill"
        case .park: "tree.fill"
        case .landmark: "star.fill"
        case .other: "mappin"
        }
    }

    /// 街を訪れる目的としての具体性。歴史・景色など、それ自体を目当てに寄り道できるものを高くする。
    /// 公園は近所の小さな公園も多く区別できないので低めにする。
    var baseScore: Int {
        switch self {
        case .castle, .history, .view: 5
        case .shrine, .temple, .museum, .art, .garden, .waterfront, .nature, .animals, .hotSpring: 4
        case .landmark: 3
        case .park: 2
        case .other: 1
        }
    }
}

/// 検索結果の1件(名前・カテゴリ・座標)。地図の検索から作り、選定にだけ使う。
nonisolated struct SpotCandidate: Sendable {
    let name: String
    let category: MKPointOfInterestCategory?
    let coordinate: CLLocationCoordinate2D
    let address: String?
    var mapItemIdentifier: String? = nil
}

/// 検索結果からスポットを最大3件選ぶ規則。名前とカテゴリだけを使う決定的な規則で、
/// レビュー数・人気のように地図の検索が返さない値は使わない。
nonisolated enum YorimichiSpotRanking {
    static let maximumCount = 3
    /// 表示する最低の点数。区分の決まらない施設(1点)だけでは出さない。
    static let minimumScore = 2
    /// 同じ区分は2件までにする。3件とも公園、のような並びを避ける。
    static let maximumPerExperience = 2
    /// 2件目以降の同じ区分に付ける減点。点数が十分に高ければ、多様性のために質の低い候補を選ばずに済む。
    static let repeatedExperiencePenalty = 2

    /// 寄り道の目的になりにくい施設のカテゴリ。テキスト検索の結果に混ざるものを落とす。
    static let excludedCategories: Set<MKPointOfInterestCategory> = [
        .atm, .bank, .parking, .gasStation, .evCharger, .store, .foodMarket, .restaurant, .cafe, .bakery, .nightlife,
        .hospital, .pharmacy, .school, .university, .police, .fireStation, .postOffice, .hotel, .laundry,
        .automotiveRepair, .carRental, .fitnessCenter, .beauty, .restroom, .publicTransport, .mailbox, .animalService,
    ]

    /// 名前から寄り道の目的になりにくいと分かるもの。全国チェーン・駐車場・事務所・小さな児童公園など。
    static let excludedNameKeywords = [
        "駐車場", "パーキング", "銀行", "信用金庫", "郵便局", "セブン-イレブン", "セブンイレブン", "ローソン", "ファミリーマート",
        "ミニストップ", "マクドナルド", "スターバックス", "事務所", "営業所", "株式会社", "(株)", "（株）", "児童遊園",
        "ちびっこ", "児童公園", "街区公園", "ポケットパーク", "マンション", "病院", "クリニック", "役所", "役場", "支所", "出張所",
        "美容", "セレモ", "斎場", "葬", "ホール", "会館", "刑務所", "拘置所", "観光情報", "観光案内", "店",
    ]

    /// 名前に含まれる語で区分を決める規則。上から順に当てはめる。
    /// `suffixOnly`の語は名前の末尾にあるときだけ当てはめる(「千葉寺駅」「城南」のように、地名に寺・城の字が入ることが多いため)。
    private static let nameRules: [(experience: SpotExperience, keywords: [String], suffixOnly: Bool)] = [
        // 記念碑・看板のような小さな名所は、それ自体を目当てに寄り道しにくいので区分を付けない(表示の点数に届かない)。
        (.other, ["記念碑", "碑", "モニュメント", "看板"], false),
        (.shrine, ["神社", "神宮", "大社", "八幡宮", "天満宮", "稲荷"], false),
        (.castle, ["城跡", "城址"], false),
        (.castle, ["城"], true),
        (.temple, ["寺", "院", "観音", "大師", "不動尊"], true),
        (.art, ["美術館", "ギャラリー"], false),
        (.history, ["郷土", "資料館", "歴史館", "記念館", "史跡", "遺跡", "古墳", "文学館", "旧居"], false),
        (.museum, ["博物館", "科学館", "ミュージアム", "プラネタリウム"], false),
        (.animals, ["動物園", "水族館"], false),
        (.garden, ["庭園", "植物園"], false),
        (.view, ["タワー", "展望", "眺望", "見晴"], false),
        (.hotSpring, ["温泉"], false),
        (.waterfront, ["海岸", "海浜", "ビーチ", "港", "岬", "灯台"], false),
        (.nature, ["滝", "渓谷", "峡", "湖", "高原"], false),
        (.park, ["公園", "緑地"], false),
    ]

    /// 名前から区分を決める。名前で決まらなければ地図のカテゴリ、それでも決まらなければ`other`。
    static func experience(name: String, category: MKPointOfInterestCategory?) -> SpotExperience {
        // 「〇〇公園」は公園として扱う(「寺山公園」のように地名の字が他の区分の語に当たることが多いため)。
        // ただし城跡・自然の公園は、それ自体が目的になるのでその区分にする。
        if name.hasSuffix("公園") || name.hasSuffix("緑地") {
            if name.contains("城跡") || name.contains("城址") { return .castle }
            if name.contains("自然公園") || name.contains("森林公園") { return .nature }
            return .park
        }
        let rule = nameRules.first { rule in
            rule.keywords.contains { rule.suffixOnly ? name.hasSuffix($0) : name.contains($0) }
        }
        if let rule { return rule.experience }
        switch category {
        case .castle, .fortress: return .castle
        case .museum, .planetarium: return .museum
        case .aquarium, .zoo: return .animals
        case .beach, .marina: return .waterfront
        case .nationalPark, .hiking: return .nature
        case .park: return .park
        case .landmark, .nationalMonument: return .landmark
        default: return .other
        }
    }

    static func isExcluded(_ candidate: SpotCandidate) -> Bool {
        if let category = candidate.category, excludedCategories.contains(category) { return true }
        return excludedNameKeywords.contains { candidate.name.contains($0) }
    }

    /// 区域内であることを確かめ済みの候補から、最大3件を選ぶ。
    /// 同じ名前・ほぼ同じ地点(100m以内)の重複を除き、点数の高い順に、同じ区分が続きすぎないよう選ぶ。
    /// 同点は検索結果の並び(地図の検索の関連度順)を保ち、同じ検索結果からは毎回同じスポットが選ばれるようにする。
    static func select(_ candidates: [SpotCandidate], municipalityCode: String) -> [YorimichiSpot] {
        var unique: [SpotCandidate] = []
        for candidate in candidates where !isExcluded(candidate) {
            let name = SpotNameNormalizer.core(of: candidate.name)
            let isDuplicate = unique.contains { existing in
                SpotNameNormalizer.core(of: existing.name) == name
                    || MKMapPoint(existing.coordinate).distance(to: MKMapPoint(candidate.coordinate)) < 100
            }
            if !isDuplicate { unique.append(candidate) }
        }
        var pool = unique.map { candidate in (candidate, experience(name: candidate.name, category: candidate.category)) }

        var selected: [YorimichiSpot] = []
        var counts: [SpotExperience: Int] = [:]
        while selected.count < maximumCount {
            // 既に選んだ区分には減点し、上限に達した区分は選ばない。
            let scored = pool.enumerated().compactMap { index, entry -> (index: Int, score: Int)? in
                let count = counts[entry.1, default: 0]
                guard count < maximumPerExperience else { return nil }
                return (index, entry.1.baseScore - count * repeatedExperiencePenalty)
            }
            // 同点は検索結果で先にあるものを選ぶ。
            guard let best = scored.max(by: { lhs, rhs in
                lhs.score != rhs.score ? lhs.score < rhs.score : lhs.index > rhs.index
            }), best.score >= minimumScore else { break }
            let (candidate, experience) = pool.remove(at: best.index)
            counts[experience, default: 0] += 1
            selected.append(YorimichiSpot(
                name: candidate.name,
                latitude: candidate.coordinate.latitude,
                longitude: candidate.coordinate.longitude,
                address: candidate.address,
                municipalityCode: municipalityCode,
                experience: experience,
                mapItemIdentifier: candidate.mapItemIdentifier
            ))
        }
        return selected
    }
}
