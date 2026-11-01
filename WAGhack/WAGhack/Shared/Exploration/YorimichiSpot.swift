import Foundation

/// 市区町村の詳細画面に出す「よりみちスポット」1件。同梱のマスタ(`MunicipalitySpots.csv`)から読む値で、保存も更新もしない。
///
/// 座標は持たない。スポットはマップアプリで開くだけなので、名前と市区町村名で検索できれば足りるため。
/// 検索はマップアプリ側に任せ、Appleの検索結果やGoogleの情報をマスタに保存しないようにしている。
nonisolated struct YorimichiSpot: Identifiable, Hashable, Sendable {
    let municipalityCode: String
    /// 市区町村の中での順位(1が一番のおすすめ)。
    let rank: Int
    let name: String
    let experience: SpotExperience
    /// マスタに書かれた、そのスポットならではの行動の言葉(「港の景色を眺める」など)。無ければ区分の言葉を使う。
    let action: String?
    /// おすすめの理由の短い一文。
    let reason: String?

    var id: String { "\(municipalityCode)-\(rank)" }

    /// 主に表示する行動の言葉。区分からも決められないときはnilで、画面では施設名を主にする。
    var displayAction: String? {
        action ?? experience.actionPhrase
    }
}

/// スポットで「何ができるか」の区分。マスタの`category`列の値と一致させる(`rawValue`)。行動の言葉とアイコンを持つ。
///
/// 営業時間・料金・混雑のような不確かなことは言わない。マスタに行動の言葉が無く区分も`other`のものは、
/// 無理に体験を言い切らず施設名を主に出す。
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
    case town
    case food
    case entertainment
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
        case .town: "街を歩く"
        case .food: "土地の味を楽しむ"
        case .entertainment: "体験を楽しむ"
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
        case .town: "街歩き"
        case .food: "グルメ"
        case .entertainment: "体験・娯楽"
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
        case .town: "figure.walk"
        case .food: "fork.knife"
        case .entertainment: "ticket.fill"
        case .landmark: "star.fill"
        case .other: "mappin"
        }
    }
}
